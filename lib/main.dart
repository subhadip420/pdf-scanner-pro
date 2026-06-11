import 'package:flutter/material.dart';

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
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('PDF Scanner Pro'),
        ),
      ),
    );
  }
}