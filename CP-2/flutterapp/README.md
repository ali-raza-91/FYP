# Navisence 📱

**Environment Detection App for Visually Impaired Users**

Navisence is an offline, on-device Flutter application that helps visually impaired users detect and understand their surroundings in real time using the smartphone camera and AI-powered object detection.

---

## 📱 About the App

Navisence uses the smartphone's camera to capture live video frames, processes them locally using a YOLOv8 nano model, and provides instant voice feedback to the user — no internet connection required.

---

## 🔄 App Flow

### 1. Hardware Layer
- Smartphone camera is activated to capture the environment
- Speaker is used for audio playback of detection results

### 2. Input Layer
- Live frame stream is captured from the smartphone camera
- Frames are continuously fed into the processing pipeline

### 3. Core Processing Layer *(Fully Offline, On-Device)*
- **Flutter App** receives the live camera stream
- **Image Preprocessing** converts frames from YUV to RGB and resizes them to 416×416
- **TFLite Inference** runs YOLOv8 nano model on the preprocessed frames
- **Detection Parser** applies confidence filtering and Non-Maximum Suppression (NMS)
- **Position Engine** calculates object position: Left / Center / Right, Near / Far
- **TTS Engine** performs offline speech synthesis to generate voice output

### 4. Output Layer
- **UI Overlay** displays bounding boxes and labels on screen
- **Voice Output** announces detected objects, e.g., *"Near person in center"*

---

## 🛠️ Tech Stack

| Component | Technology |
|---|---|
| Mobile Framework | Flutter |
| Object Detection | YOLOv8 Nano |
| Inference Engine | TensorFlow Lite (TFLite) |
| Text-to-Speech | Offline TTS Engine |
| Target Platform | Android / iOS |

---

## 🚀 Getting Started

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run
```

---

## 📁 Project Structure

```
flutterapp/
├── android/
├── ios/
├── lib/
│   ├── controller/
│   │   └── scan_controller.dart      # Camera & model inference logic
│   └── view/
│       └── camera_view.dart          # Camera UI & bounding box overlay
├── assets/
│   ├── best_int8.tflite              # YOLOv8 nano TFLite model
│   └── label.txt                     # Object detection labels
├── linux/
├── macos/
├── web/
├── windows/
├── test/
├── pubspec.yaml
└── README.md
```

---

## 📂 Key Files

### `lib/controller/scan_controller.dart`
Handles the core logic of the app:
- Initializes and manages the smartphone camera
- Preprocesses live frames (YUV → RGB, resize to 416×416)
- Runs TFLite inference using `best_int8.tflite`
- Parses detection results with confidence filtering and NMS
- Calculates object position (Left/Center/Right, Near/Far)
- Triggers TTS engine for voice output

### `lib/view/camera_view.dart`
Handles the UI of the app:
- Displays live camera feed
- Renders bounding boxes and labels over detected objects
- Shows real-time detection results on screen

### `assets/best_int8.tflite`
The YOLOv8 nano model optimized with INT8 quantization for fast on-device inference.

### `assets/label.txt`
Contains the list of object class labels used by the detection model.

---

## 👤 Developed By

- Ali Raza Ansari
- Muhammad Hassan
- Muhammad Abdullah Zammad