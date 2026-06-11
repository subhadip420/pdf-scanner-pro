import 'package:flutter/material.dart';
import 'package:pdf_scanner_pro/screens/splash_screen.dart';


void main() {
  runApp(const PdfScannerPro());
}

class PdfScannerPro extends StatelessWidget {
  const PdfScannerPro({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PDF Scanner Pro',
      home: const SplashScreen(),
    );
  }
}