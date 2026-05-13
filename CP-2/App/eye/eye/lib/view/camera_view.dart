import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import '../controller/scan_controller.dart';

class CameraView extends StatelessWidget {
  const CameraView({super.key});

  @override
  Widget build(BuildContext context) {

    // ScanController access karta hai
    final controller = Get.find<ScanController>();

    // Screen ki information leta hai
    final mq = MediaQuery.of(context);

    /// Agar device rotate bhi ho jaye
    /// tab bhi layout portrait shape me rahega
    final rawW = mq.size.width;
    final rawH = mq.size.height;

    final screenW = math.min(rawW, rawH);
    final screenH = math.max(rawW, rawH);

    // AppBar aur padding remove kar ke actual content height nikalta hai
    final contentH = screenH -
        kToolbarHeight -
        mq.padding.top -
        mq.padding.bottom;

    // Screen ka 65% camera ke liye
    final cameraH = contentH * 0.65;

    // Screen ka 35% detection panel ke liye
    final panelH  = contentH * 0.35;

    return Scaffold(

      // Top app bar
      appBar: AppBar(title: const Text('Object Detection')),

      // Obx realtime UI update karta hai
      body: Obx(() {

        // Jab tak camera ready nahi hota loading show hoti hai
        if (!controller.isReady.value) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        // Current detections
        final dets = controller.detections;

        // Camera preview ka aspect ratio
        final camValue   = controller.cameraController!.value;
        final camAspect  = camValue.aspectRatio;

        double previewW, previewH, offsetX, offsetY;

        // Preview ka proper size calculate karta hai
        if (screenW / cameraH >= camAspect) {
          previewH = cameraH;
          previewW = cameraH * camAspect;
        } else {
          previewW = screenW;
          previewH = screenW / camAspect;
        }

        // Preview center align karta hai
        offsetX = (screenW - previewW) / 2;
        offsetY = (cameraH - previewH) / 2;

        return Column(
          children: [

            // ================= CAMERA AREA =================
            SizedBox(
              width: screenW,
              height: cameraH,

              child: ClipRect(
                child: Stack(
                  children: [

                    // Live camera preview
                    SizedBox.expand(
                      child: CameraPreview(controller.cameraController!),
                    ),

                    // Har detection ke liye bounding box draw karta hai
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

            // ================= DETECTION PANEL =================
            SizedBox(
              width: screenW,
              height: panelH,

              child: dets.isEmpty

                  // Agar object detect na ho
                  ? const Center(
                child: Text(
                  'Scanning...',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 15,
                  ),
                ),
              )

                  // Agar detections available hon
                  : _DetectionPanel(dets: dets),
            ),
          ],
        );
      }),
    );
  }
}