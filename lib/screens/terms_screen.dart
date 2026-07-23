// 🚨 NAYA WIDGET: Terms and Conditions Screen
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Terms & Conditions",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Last Updated: July 2026",
              style: TextStyle(color: Colors.white54, fontSize: 13, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 24),

            _buildSectionTitle("1. Introduction"),
            _buildSectionText(
              "Welcome to PDF Scanner Pro. By using this application, you agree to comply with and be bound by the following terms and conditions of use. This app is developed and maintained by SP Tech Studios.",
            ),

            _buildSectionTitle("2. Offline Processing & Privacy"),
            _buildSectionText(
              "Privacy is our top priority. PDF Scanner Pro processes all files, images, and documents locally on your device. We do not upload, share, or store your personal documents on any external servers. Your data remains 100% on your device.",
            ),

            _buildSectionTitle("3. User Responsibilities"),
            _buildSectionText(
              "You are solely responsible for the documents you create, scan, merge, and share using this app. Do not use this application for any illegal, unauthorized, or fraudulent purposes.",
            ),

            _buildSectionTitle("4. Device Permissions"),
            _buildSectionText(
              "To function properly, this app requires access to your device's camera (for scanning) and storage (for saving and managing PDFs). We strictly use these permissions only for the core functionality of the app.",
            ),

            _buildSectionTitle("5. Changes to Terms"),
            _buildSectionText(
              "SP Tech Studios reserves the right to modify these terms at any time. Your continued use of the app following any changes signifies your acceptance of those changes.",
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  // T&C ke normal text ke liye design
  Widget _buildSectionText(String text) {
    return Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5));
  }
}
