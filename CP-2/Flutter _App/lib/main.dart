import 'package:eye/view/camera_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'controller/scan_controller.dart';
import 'views/camera_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations(
    [DeviceOrientation.portraitUp],
  );

  // Transparent status bar for full-screen
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Initialize ScanController before running the app
  Get.put(ScanController());

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

/// Re-applies the portrait orientation lock whenever the system reports
/// a metrics change.  This is a belt-and-braces guard for devices (some
/// Samsungs, certain MIUI builds) that occasionally ignore the initial
/// `setPreferredOrientations` call after the app resumes from background.
class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Object Detection',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const CameraView(),
    );
  }
}