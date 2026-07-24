import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pdf_scanner_pro/screens/scanner_screen.dart';
import 'package:pdf_scanner_pro/screens/splash_screen.dart';
import 'package:permission_handler/permission_handler.dart';


//late List<CameraDescription> cameras;
List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //cameras = await availableCameras();
  //WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const PdfScannerPro());

}

// class PdfScannerPro extends StatelessWidget {
//   const PdfScannerPro({super.key});

class PdfScannerPro extends StatefulWidget {
  const PdfScannerPro({super.key});

  @override
  State<PdfScannerPro> createState() => _PdfScannerProState();
}

class _PdfScannerProState extends State<PdfScannerPro> {
  @override
  void initState() {
    super.initState();

    // UI render hone ke turant baad permission popups dikhane ke liye
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestAllPermissionsOnStartup();
    });
  }

  Future<void> _requestAllPermissionsOnStartup() async {
    // 1. Pehle Camera permission maango
    if (await Permission.camera.isDenied) {
      await Permission.camera.request();
    }

    // 2. Phir Storage & Gallery ki permissions (Universal check)
    if (Platform.isAndroid) {
      // Android 11+ ke liye
      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }
      // Purane Android (10 aur niche) ke liye
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }
      // Gallery se photo uthane ke liye
      if (await Permission.photos.isDenied) {
        await Permission.photos.request();
      }
    } else {
      // iOS ke liye
      await Permission.storage.request();
      await Permission.photos.request();
    }
  }

  @override
  Widget build(BuildContext context) {
    // return MaterialApp(
    //   debugShowCheckedModeBanner: false,
    //   //home: const SplashScreen(),
    //   home: const ScannerScreen(isOpenedFromEditor: false),
    // );

    return ScreenUtilInit(
      designSize: const Size(360, 800), // Standard base size (Mobile)
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          // home: const SplashScreen(),
          home: child, // 3. Yahan 'child' lagana zaroori hai optimization ke liye
        );
      },
      child: const ScannerScreen(isOpenedFromEditor: false), // 4. Tumhari screen yahan aayegi
    );
  }
}