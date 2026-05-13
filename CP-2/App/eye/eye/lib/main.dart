import 'package:eye/view/camera_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'controller/scan_controller.dart';
import 'views/camera_view.dart';

void main() async {

  // Flutter engine ko initialize karta hai
  WidgetsFlutterBinding.ensureInitialized();

  // App ki orientation sirf portrait mode me lock karta hai
  await SystemChrome.setPreferredOrientations(
    [DeviceOrientation.portraitUp],
  );

  // Status bar ko transparent aur icons ko white karta hai
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // ScanController ko app start se pehle initialize karta hai
  Get.put(ScanController());

  // Main app run karta hai
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

/// Ye class ensure karti hai ke app hamesha portrait mode me rahe
/// Kuch devices resume hone ke baad orientation ignore kar dete hain
class _MyAppState extends State<MyApp> with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();

    // App lifecycle observer add karta hai
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {

    // Observer remove karta hai
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();

    // Agar screen metrics change hon to orientation dubara portrait karta hai
    SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // App resume hone par orientation lock dubara apply karta hai
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp],
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    // GetX Material App
    return GetMaterialApp(
      title: 'Object Detection',

      // Debug banner hide karta hai
      debugShowCheckedModeBanner: false,

      // Dark theme apply karta hai
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

      // App ka home screen CameraView hai
      home: const CameraView(),
    );
  }
}