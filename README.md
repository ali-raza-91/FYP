# Navisence
### AI-Powered Environment Detection System for Visually Impaired Users

![Platform](https://img.shields.io/badge/Platform-Flutter-02569B?style=flat-square&logo=flutter)
![Model](https://img.shields.io/badge/Model-YOLOv8%20Nano-FF6F00?style=flat-square)
![Inference](https://img.shields.io/badge/Inference-TFLite-FF6F00?style=flat-square)
![Status](https://img.shields.io/badge/Status-Final%20Year%20Project-green?style=flat-square)

---

## 📌 Overview

**Navisence** is a fully offline, on-device assistive technology application designed for visually impaired users. It leverages real-time object detection via the smartphone camera and provides instant audio feedback through a Text-to-Speech (TTS) engine — requiring no internet connection whatsoever.

The system detects surrounding objects, determines their position (Left / Center / Right, Near / Far), and announces them to the user through voice output such as *"Near person in center"*.

---

## 🗂️ Repository Structure

```
FYP/
├── CP-1/                          # Phase 1 — Planning & Documentation
│   ├── diagrame/                  # System & architecture diagrams
│   ├── Progress_Reports/          # Weekly progress reports (Week 1–16)
│   │   ├── Week 1.pdf
│   │   ├── Week 2.pdf
│   │   └── ... (Week 3 – Week 16)
│   ├── Project_Docs/              # Core project documents
│   │   ├── digrame/               # Detailed diagrams
│   │   ├── Proposal/              # Project proposal
│   │   ├── Software Design Specification/
│   │   └── SRS/                   # Software Requirements Specification
│   ├── Research_Materials/        # Research papers & references
│   └── Presentation.pptx          # Project presentation
│
└── CP-2/                          # Phase 2 — Development & Implementation
    ├── Data_Set/                  # Dataset used for model training
    ├── flutterapp/                # Flutter mobile application
    │   ├── android/
    │   ├── ios/
    │   ├── lib/
    │   │   ├── controller/
    │   │   │   └── scan_controller.dart   # Camera & inference logic
    │   │   └── view/
    │   │       └── camera_view.dart       # Camera UI & bounding boxes
    │   ├── assets/
    │   │   ├── best_int8.tflite           # YOLOv8 nano TFLite model
    │   │   └── label.txt                  # Detection class labels
    │   ├── linux/
    │   ├── macos/
    │   ├── web/
    │   ├── windows/
    │   ├── test/
    │   └── pubspec.yaml
    ├── Model/                     # Model training & results
    │   ├── code.ipynb             # Training notebook
    │   └── Model_Results.pdf      # Evaluation results
    └── Weekly_Reports/            # Phase 2 weekly progress reports
```

---

## 🔄 System Architecture & App Flow

### Hardware Layer
- Smartphone camera captures the live environment
- Speaker / audio output delivers voice feedback to the user

### Input Layer
- Live frame stream is fed continuously from the smartphone camera into the processing pipeline

### Core Processing Layer *(Fully Offline, On-Device)*

| Step | Component | Description |
|------|-----------|-------------|
| 1 | Flutter App | Receives live camera stream |
| 2 | Image Preprocessing | YUV → RGB conversion, resize to 416×416 |
| 3 | TFLite Inference | YOLOv8 nano model runs on-device |
| 4 | Detection Parser | Confidence filtering + NMS applied |
| 5 | Position Engine | Calculates Left/Center/Right, Near/Far |
| 6 | TTS Engine | Offline speech synthesis for voice output |

### Output Layer
- **UI Overlay** — Bounding boxes and labels displayed on screen
- **Voice Output** — Real-time audio announcement, e.g., *"Near person in center"*

---

## 🛠️ Tech Stack

| Component | Technology |
|---|---|
| Mobile Framework | Flutter (Dart) |
| Object Detection Model | YOLOv8 Nano |
| Inference Engine | TensorFlow Lite (TFLite) |
| Model Format | INT8 Quantized (`.tflite`) |
| Text-to-Speech | Offline TTS Engine |
| Model Training | Python, Jupyter Notebook |
| Target Platform | Android / iOS |

---

## 📂 Key Files Explained

### `CP-2/flutterapp/lib/controller/scan_controller.dart`
Core logic controller of the application:
- Initializes and manages the smartphone camera
- Preprocesses live frames (YUV → RGB, resize to 416×416)
- Runs TFLite inference using `best_int8.tflite`
- Parses detections with confidence filtering and NMS
- Computes object position (Left / Center / Right, Near / Far)
- Triggers TTS engine for real-time voice announcements

### `CP-2/flutterapp/lib/view/camera_view.dart`
UI layer of the application:
- Displays live camera feed to the user
- Renders bounding boxes and class labels over detected objects
- Shows real-time detection output on screen

### `CP-2/flutterapp/assets/best_int8.tflite`
YOLOv8 nano model quantized to INT8 format for fast and efficient on-device inference with minimal battery and memory usage.

### `CP-2/flutterapp/assets/label.txt`
Text file containing all object class labels recognized by the detection model.

### `CP-2/Model/code.ipynb`
Jupyter notebook used for training and evaluating the YOLOv8 model on the custom dataset.

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK installed
- Android Studio / Xcode configured
- A physical Android or iOS device (recommended for camera access)

### Run the App

```bash
# Navigate to flutter app directory
cd CP-2/flutterapp

# Install dependencies
flutter pub get

# Run on connected device
flutter run
```

---

## 📊 Project Phases

| Phase | Folder | Description |
|-------|--------|-------------|
| CP-1 | `/CP-1` | Research, planning, documentation, SRS, SDS, proposals |
| CP-2 | `/CP-2` | Dataset preparation, model training, Flutter app development |

---

## 👤 Developed By

- Ali Raza Ansari
- Muhammad Hassan 
- Muhammad Abdullah Zammad
