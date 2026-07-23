import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pdf_scanner_pro/screens/scanner_screen.dart';
import 'package:pdf_scanner_pro/screens/splash_screen.dart';


//late List<CameraDescription> cameras;
List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //cameras = await availableCameras();
  //WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const PdfScannerPro());

}

class PdfScannerPro extends StatelessWidget {
  const PdfScannerPro({super.key});

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