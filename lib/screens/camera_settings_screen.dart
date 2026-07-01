import 'package:flutter/material.dart';

class CameraSettingsScreen extends StatelessWidget {
  const CameraSettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2C2C), // Dark theme background
      appBar: AppBar(
        backgroundColor: const Color(0xFF151515), // AppBar ka dark color
        elevation: 0,
        // 🚨 Back Button
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
          onPressed: () {
            Navigator.pop(context); // Wapas Scanner Screen par bhej dega
          },
        ),
        // 🚨 Title
        title: const Text(
          "Camera Settings",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
      ),
      body: const Center(
        // Temporary placeholder text jab tak baaki UI nahi banta
        child: Text(
          "Settings options will be added here.",
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      ),
    );
  }
}