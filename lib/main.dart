import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:pdf_scanner_pro/screens/splash_screen.dart';


late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  cameras = await availableCameras();

  runApp(const PdfScannerPro());
}

class PdfScannerPro extends StatelessWidget {
  const PdfScannerPro({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}