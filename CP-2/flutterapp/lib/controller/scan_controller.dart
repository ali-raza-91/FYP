/// scan_controller.dart

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// ───────────────── FRAME DATA ─────────────────
class FrameData {
  final Uint8List y;
  final Uint8List u;
  final Uint8List v;

  final int width;
  final int height;

  final int yRowStride;
  final int uvRowStride;
  final int uvPixelStride;

  FrameData({
    required this.y,
    required this.u,
    required this.v,
    required this.width,
    required this.height,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
  });

  factory FrameData.fromCameraImage(CameraImage img) {
    return FrameData(
      y: img.planes[0].bytes,
      u: img.planes[1].bytes,
      v: img.planes[2].bytes,
      width: img.width,
      height: img.height,
      yRowStride: img.planes[0].bytesPerRow,
      uvRowStride: img.planes[1].bytesPerRow,
      uvPixelStride: img.planes[1].bytesPerPixel ?? 1,
    );
  }
}

/// ───────────────── INPUT ARGUMENT ─────────────────
class InputTensorArgs {
  final FrameData frame;
  final int rotation;

  InputTensorArgs({
    required this.frame,
    required this.rotation,
  });
}

/// ───────────────── IMAGE → TENSOR ─────────────────
Float32List buildInputTensor(InputTensorArgs args) {
  final data = args.frame;
  final rotation = args.rotation;

  const int size = 416;

  final double widthScale = data.width / size;
  final double heightScale = data.height / size;

  final out = Float32List(1 * size * size * 3);

  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      int srcX;
      int srcY;

      switch (rotation) {
        case 90:
          srcX = (y * widthScale).toInt();
          srcY = ((size - x) * heightScale).toInt();
          break;

        case 270:
          srcX = ((size - y) * widthScale).toInt();
          srcY = (x * heightScale).toInt();
          break;

        case 180:
          srcX = ((size - x) * widthScale).toInt();
          srcY = ((size - y) * heightScale).toInt();
          break;

        default:
          srcX = (x * widthScale).toInt();
          srcY = (y * heightScale).toInt();
      }

      if (srcX < 0) {
        srcX = 0;
      } else if (srcX >= data.width) {
        srcX = data.width - 1;
      }
      if (srcY < 0) {
        srcY = 0;
      } else if (srcY >= data.height) {
        srcY = data.height - 1;
      }

      final yIndex = srcY * data.yRowStride + srcX;

      final uvIndex =
          (srcY >> 1) * data.uvRowStride +
              (srcX >> 1) * data.uvPixelStride;

      final Y = data.y[yIndex];
      final U = data.u[uvIndex];
      final V = data.v[uvIndex];

      int r =
      (Y + 1.402 * (V - 128)).round().clamp(0, 255);

      int g = (Y -
          0.344 * (U - 128) -
          0.714 * (V - 128))
          .round()
          .clamp(0, 255);

      int b =
      (Y + 1.772 * (U - 128)).round().clamp(0, 255);

      final dst = (y * size + x) * 3;
      out[dst] = r / 255.0;
      out[dst + 1] = g / 255.0;
      out[dst + 2] = b / 255.0;
    }
  }

  return out;
}

/// ───────────────── CONTROLLER ─────────────────
class ScanController extends GetxController {
  CameraController? cameraController;
  Interpreter? interpreter;

  var isReady = false.obs;
  var detections = <Map<String, dynamic>>[].obs;

  final FlutterTts tts = FlutterTts();

  bool _isProcessing = false;
  bool _isStreaming = false;

  int _lastInferenceTime = 0;

  String? _lastSpokenSig;
  int _lastSpokenAt = 0;

  String? _candidateSig;
  int _stableHits = 0;

  int _streamStartedAt = 0;
  static const int _warmupMs = 1200;

  static const int _anchors = 3549;

  /// ───────── PHYSICAL ORIENTATION TRACKING ─────────
  ///
  /// Even though the manifest locks the activity to portrait, the user
  /// can still physically rotate the phone — and when they do, the
  /// camera sensor records the world from a tilted angle.  If we don't
  /// compensate, the model receives an upright image of a sideways
  /// world, and the detections look "wrong."
  ///
  /// We listen to the accelerometer to learn how the user is HOLDING
  /// the phone, then add an extra rotation step to keep the world
  /// upright in the model's view.
  ///
  ///   _physicalQuarterTurns:
  ///     0 = portrait (phone vertical, normal hold)
  ///     1 = landscape, phone rotated 90° clockwise (left side down)
  ///     2 = upside down
  ///     3 = landscape, phone rotated 90° counter-clockwise
  int _physicalQuarterTurns = 0;
  StreamSubscription<AccelerometerEvent>? _accelSub;

  /// Per-class confidence thresholds.
  static const Map<String, double> _classConfThresh = {
    'bag':     0.70,
    'car':     0.60,
    'chair':   0.55,
    'door':    0.55,
    'person':  0.50,
    'stair':   0.60,
    'tree':    0.60,
  };
  static const double _defaultConfThresh = 0.65;

  static const double _marginThresh = 0.20;

  static const int _maxDetections = 3;

  static const double _iouThresh = 0.45;

  static const int _gapMs = 150;
  static const int _ttsCooldownMs = 2000;

  static const int _freshStabilityFrames = 1;
  static const int _changeStabilityFrames = 2;

  /// Per-class distance thresholds.
  static const Map<String, List<double>> _distanceThresholds = {
    'bag':       [0.45,  0.18],
    'car':       [0.55,  0.20],
    'chair':     [0.50,  0.18],
    'door':      [0.65,  0.30],
    'person':    [0.60,  0.22],
    'stair':     [0.55,  0.22],
    'tree':      [0.65,  0.25],
  };
  static const double _defaultNear = 0.50;
  static const double _defaultFar = 0.20;

  static const List<String> _labels = [
    'bag',
    'car',
    'chair',
    'door',
    'person',
    'stair',
    'tree'
  ];

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  Future<void> _init() async {
    await _initModel();
    await _initCamera();

    _startOrientationListener();

    await tts.setLanguage("en-US");
    await tts.setSpeechRate(0.5);

    await tts.setVolume(0.0);
    await tts.speak(' ');
    await Future.delayed(const Duration(milliseconds: 200));
    await tts.setVolume(1.0);
  }

  /// ───────────────── ORIENTATION LISTENER ─────────────────
  /// Listens to the accelerometer to figure out which way the user
  /// is holding the phone, regardless of activity rotation locks.
  ///
  /// Gravity is roughly (0, 9.8, 0) when the phone is upright in
  /// portrait.  We translate gravity direction into a quarter-turn
  /// count that buildInputTensor can compensate for.
  void _startOrientationListener() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 200),
    ).listen((e) {
      // Only update when the phone is held roughly vertical
      // (ignore reads when face-up on a table — z dominates).
      if (e.z.abs() > 7.5) return;

      // Compare horizontal vs vertical gravity components.
      final ax = e.x;
      final ay = e.y;

      int q;
      if (ay.abs() > ax.abs()) {
        // Phone is more vertical than horizontal
        q = (ay > 0) ? 0 : 2;          // 0 = portrait, 2 = upside down
      } else {
        // Phone is on its side
        q = (ax > 0) ? 3 : 1;          // 1 = rotated CW, 3 = rotated CCW
      }

      if (q != _physicalQuarterTurns) {
        _physicalQuarterTurns = q;
        debugPrint('Phone physical orientation → $q quarter turns');
      }
    });
  }

  /// ───────────────── MODEL ─────────────────
  Future<void> _initModel() async {
    interpreter = await Interpreter.fromAsset(
      'assets/best_int8.tflite',
      options: InterpreterOptions()..threads = 4,
    );

    print(
        "INPUT: ${interpreter!.getInputTensor(0).shape}");

    print(
        "OUTPUT: ${interpreter!.getOutputTensor(0).shape}");
  }

  /// ───────────────── CAMERA ─────────────────
  Future<void> _initCamera() async {
    final cams = await availableCameras();

    cameraController = CameraController(
      cams.first,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await cameraController!.initialize();

    try {
      await cameraController!.lockCaptureOrientation(
        DeviceOrientation.portraitUp,
      );
    } catch (_) {}

    await Future.delayed(
      const Duration(milliseconds: 300),
    );

    if (!cameraController!.value.isInitialized) {
      return;
    }

    isReady.value = true;

    if (!_isStreaming) {
      _isStreaming = true;

      _streamStartedAt =
          DateTime.now().millisecondsSinceEpoch;

      try {
        await cameraController!
            .startImageStream((image) {
          if (image.planes.isEmpty) return;

          _processFrame(image);
        });
      } catch (e) {
        print("STREAM ERROR: $e");
      }
    }
  }

  /// Computes the rotation (0/90/180/270) that buildInputTensor needs
  /// so the model sees an UPRIGHT view of the world, regardless of
  /// how the user is physically holding the phone.
  int _effectiveRotation() {
    final sensor =
        cameraController!.description.sensorOrientation;

    // Each quarter-turn of the phone adds 90° we need to undo.
    final adjusted =
        (sensor + _physicalQuarterTurns * 90) % 360;
    return adjusted;
  }

  /// ───────────────── PROCESS FRAME ─────────────────
  Future<void> _processFrame(
      CameraImage image) async {
    if (_isProcessing || interpreter == null) {
      return;
    }

    final now =
        DateTime.now().millisecondsSinceEpoch;

    if (now - _streamStartedAt < _warmupMs) {
      return;
    }

    if (now - _lastInferenceTime < _gapMs) {
      return;
    }

    _lastInferenceTime = now;

    _isProcessing = true;

    try {
      final rotation = _effectiveRotation();

      final flatInput = await compute(
        buildInputTensor,
        InputTensorArgs(
          frame: FrameData.fromCameraImage(image),
          rotation: rotation,
        ),
      );

      final input = flatInput.reshape([1, 416, 416, 3]);

      final output = List.generate(
        1,
            (_) => List.generate(
          11,
              (_) => List.filled(_anchors, 0.0),
        ),
      );

      interpreter!.run(input, output);

      final parsed = _parse(output[0]);

      detections.value = parsed;

      _speakIfStable(parsed, now);
    } catch (e) {
      print("ERROR: $e");
    }

    _isProcessing = false;
  }

  /// ───────────────── POSITION + DISTANCE HELPERS ─────────────────
  static String positionFor(double cx) {
    if (cx < 0.34) return 'left';
    if (cx > 0.66) return 'right';
    return 'center';
  }

  static String distanceFor(String label, double w, double h) {
    final size = math.max(w, h);
    final thresholds =
        _distanceThresholds[label] ?? [_defaultNear, _defaultFar];
    if (size > thresholds[0]) return 'near';
    if (size < thresholds[1]) return 'far';
    return 'medium';
  }

  /// ───────────────── ANNOUNCEMENT ─────────────────
  String _buildAnnouncement(
      List<Map<String, dynamic>> dets) {
    if (dets.isEmpty) return '';

    final parts = <String>[];

    for (final d in dets) {
      final label = d['label'] as String;
      final pos = d['position'] as String;
      final dist = d['distance'] as String;

      String prefix = '';
      if (dist == 'near') prefix = 'near ';
      else if (dist == 'far') prefix = 'far ';

      if (pos == 'center') {
        parts.add('$prefix$label in the center');
      } else {
        parts.add('$prefix$label on the $pos');
      }
    }

    return '${parts.join(', ')}.';
  }

  /// ───────────────── STABLE TTS GATE ─────────────────
  void _speakIfStable(
      List<Map<String, dynamic>> dets, int now) {
    if (dets.isEmpty) {
      _candidateSig = null;
      _stableHits = 0;
      _lastSpokenSig = null;
      return;
    }

    final sig = dets
        .map((d) =>
    '${d['label']}@${d['position']}@${d['distance']}')
        .join('|');

    if (sig == _candidateSig) {
      _stableHits++;
    } else {
      _candidateSig = sig;
      _stableHits = 1;
    }

    final required = (_lastSpokenSig == null)
        ? _freshStabilityFrames
        : _changeStabilityFrames;

    if (_stableHits < required) return;

    final changed = sig != _lastSpokenSig;
    final cooledOff =
        (now - _lastSpokenAt) > _ttsCooldownMs;

    if (changed || cooledOff) {
      _lastSpokenSig = sig;
      _lastSpokenAt = now;

      tts.stop();
      tts.speak(_buildAnnouncement(dets));
    }
  }

  /// ───────────────── PARSER ─────────────────
  List<Map<String, dynamic>> _parse(
      List<List<double>> out) {
    final raw = <Map<String, dynamic>>[];

    final result = <Map<String, dynamic>>[];

    final int classes = _labels.length;

    for (int i = 0; i < _anchors; i++) {
      double bestScore = 0;
      double secondScore = 0;
      int classIndex = 0;

      for (int c = 0; c < classes; c++) {
        final score = out[4 + c][i];

        if (score > bestScore) {
          secondScore = bestScore;
          bestScore = score;
          classIndex = c;
        } else if (score > secondScore) {
          secondScore = score;
        }
      }

      final classLabel = _labels[classIndex];
      final classThresh =
          _classConfThresh[classLabel] ?? _defaultConfThresh;
      if (bestScore < classThresh) {
        continue;
      }

      if ((bestScore - secondScore) < _marginThresh) {
        continue;
      }

      double cx = out[0][i];
      double cy = out[1][i];
      double w = out[2][i];
      double h = out[3][i];

      if (w <= 0 || h <= 0) {
        continue;
      }

      cx = cx.clamp(0.0, 1.0);
      cy = cy.clamp(0.0, 1.0);

      w = w.clamp(0.0, 1.0);
      h = h.clamp(0.0, 1.0);

      raw.add({
        'label': classLabel,
        'confidence': bestScore,
        'cx': cx,
        'cy': cy,
        'w': w,
        'h': h,
        'position': positionFor(cx),
        'distance': distanceFor(classLabel, w, h),
      });
    }

    raw.sort(
          (a, b) => (b['confidence'] as double)
          .compareTo(a['confidence'] as double),
    );

    for (var box in raw) {
      if (result.every(
              (r) => _iou(box, r) < _iouThresh)) {
        result.add(box);
        if (result.length >= _maxDetections) break;
      }
    }

    return result;
  }

  /// ───────────────── IOU ─────────────────
  double _iou(a, b) {
    final ax1 = a['cx'] - a['w'] / 2;
    final ay1 = a['cy'] - a['h'] / 2;

    final ax2 = a['cx'] + a['w'] / 2;
    final ay2 = a['cy'] + a['h'] / 2;

    final bx1 = b['cx'] - b['w'] / 2;
    final by1 = b['cy'] - b['h'] / 2;

    final bx2 = b['cx'] + b['w'] / 2;
    final by2 = b['cy'] + b['h'] / 2;

    final w =
        (ax2 < bx2 ? ax2 : bx2) -
            (ax1 > bx1 ? ax1 : bx1);

    final h =
        (ay2 < by2 ? ay2 : by2) -
            (ay1 > by1 ? ay1 : by1);

    if (w <= 0 || h <= 0) {
      return 0;
    }

    final inter = w * h;

    final union =
        (ax2 - ax1) * (ay2 - ay1) +
            (bx2 - bx1) * (by2 - by1) -
            inter;

    return inter / union;
  }

  /// ───────────────── CLEANUP ─────────────────
  @override
  void onClose() {
    try {
      _accelSub?.cancel();
    } catch (_) {}

    try {
      cameraController?.stopImageStream();
    } catch (_) {}

    cameraController?.dispose();

    interpreter?.close();

    tts.stop();

    super.onClose();
  }
}