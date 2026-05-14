import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import '../controller/scan_controller.dart';

class CameraView extends StatelessWidget {
  const CameraView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ScanController>();

    final mq = MediaQuery.of(context);

    /// Rotation-immune sizing — even if MediaQuery briefly reports
    /// landscape during a rotation event, layout stays portrait-shaped.
    final rawW = mq.size.width;
    final rawH = mq.size.height;
    final screenW = math.min(rawW, rawH);
    final screenH = math.max(rawW, rawH);

    final contentH = screenH -
        kToolbarHeight -
        mq.padding.top -
        mq.padding.bottom;

    final cameraH = contentH * 0.65;
    final panelH  = contentH * 0.35;

    return Scaffold(
      appBar: AppBar(title: const Text('Object Detection')),
      body: Obx(() {
        if (!controller.isReady.value) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final dets = controller.detections;

        // ── Compute the actual rendered preview rect ──────────────────────
        final camValue   = controller.cameraController!.value;
        final camAspect  = camValue.aspectRatio;

        double previewW, previewH, offsetX, offsetY;

        if (screenW / cameraH >= camAspect) {
          previewH = cameraH;
          previewW = cameraH * camAspect;
        } else {
          previewW = screenW;
          previewH = screenW / camAspect;
        }

        offsetX = (screenW - previewW) / 2;
        offsetY = (cameraH - previewH) / 2;

        return Column(
          children: [
            // ───────── CAMERA ─────────
            SizedBox(
              width: screenW,
              height: cameraH,
              child: ClipRect(
                child: Stack(
                  children: [
                    SizedBox.expand(
                      child: CameraPreview(controller.cameraController!),
                    ),

                    for (final det in dets)
                      _BoundingBox(
                        det: det,
                        previewW: previewW,
                        previewH: previewH,
                        offsetX: offsetX,
                        offsetY: offsetY,
                      ),
                  ],
                ),
              ),
            ),

            // ───────── PANEL ─────────
            SizedBox(
              width: screenW,
              height: panelH,
              child: dets.isEmpty
                  ? const Center(
                child: Text(
                  'Scanning...',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 15,
                  ),
                ),
              )
                  : _DetectionPanel(dets: dets),
            ),
          ],
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Bounding Box
// ─────────────────────────────────────────────────────────────────────────────
class _BoundingBox extends StatelessWidget {
  final Map<String, dynamic> det;
  final double previewW, previewH;
  final double offsetX, offsetY;

  const _BoundingBox({
    required this.det,
    required this.previewW,
    required this.previewH,
    required this.offsetX,
    required this.offsetY,
  });

  @override
  Widget build(BuildContext context) {
    final cx    = det['cx'] as double;
    final cy    = det['cy'] as double;
    final w     = det['w']  as double;
    final h     = det['h']  as double;
    final label = det['label'] as String;
    final conf  = ((det['confidence'] as double) * 100).round();

    final boxW = w * previewW;
    final boxH = h * previewH;
    final left = offsetX + cx * previewW - boxW / 2;
    final top  = offsetY + cy * previewH - boxH / 2;

    final clampedLeft = left.clamp(offsetX, offsetX + previewW - boxW);
    final clampedTop  = top .clamp(offsetY, offsetY + previewH - boxH);

    return Positioned(
      left:   clampedLeft,
      top:    clampedTop,
      width:  boxW,
      height: boxH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red, width: 2),
            ),
          ),
          Positioned(
            top:  -24,
            left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: Colors.red,
              child: Text(
                '${label.toUpperCase()} $conf%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────────────────────
String _cap(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

// ─────────────────────────────────────────────────────────────────────────────
//  Detection Panel
// ─────────────────────────────────────────────────────────────────────────────
class _DetectionPanel extends StatelessWidget {
  final List<Map<String, dynamic>> dets;
  const _DetectionPanel({required this.dets});

  @override
  Widget build(BuildContext context) {
    final first  = dets.first;
    final label  = first['label']    as String;
    final pos    = first['position'] as String;
    final dist   = first['distance'] as String;
    final cap    = _cap(label);
    final capPos = _cap(pos);
    final capDist = _cap(dist);
    final conf   = ((first['confidence'] as double) * 100).round();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...dets.map((d) {
            final l    = d['label']    as String;
            final p    = d['position'] as String;
            final dt   = d['distance'] as String;
            final c    = ((d['confidence'] as double) * 100).round();
            final name =
                '${_cap(l)} · ${_cap(dt)} · ${_cap(p)}';

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$c%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 10),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 10),

          Container(
            width: double.infinity,
            padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detection:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Distance · Position:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$cap  ($conf%)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$capDist · $capPos',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}