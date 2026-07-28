// 🚨 NAYA WIDGET: Terms and Conditions Screen
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF1F0F0),
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black87),
        title: Text(
          "Terms & Conditions",
          style: TextStyle(color: isDarkMode ?  Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Last Updated: August 2026",
              style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54, fontSize: 13, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 24),

            _buildSectionTitle("1. Introduction", isDarkMode),
            _buildSectionText(
              "Welcome to PDF Scanner Pro. By using this application, you agree to comply with and be bound by the following terms and conditions of use. This app is developed and maintained by SP Tech Studios.", isDarkMode
            ),

            _buildSectionTitle("2. Offline Processing & Privacy", isDarkMode),
            _buildSectionText(
              "Privacy is our top priority. PDF Scanner Pro processes all files, images, and documents locally on your device. We do not upload, share, or store your personal documents on any external servers. Your data remains 100% on your device.", isDarkMode
            ),

            _buildSectionTitle("3. User Responsibilities", isDarkMode),
            _buildSectionText(
              "You are solely responsible for the documents you create, scan, merge, and share using this app. Do not use this application for any illegal, unauthorized, or fraudulent purposes.", isDarkMode
            ),

            _buildSectionTitle("4. Device Permissions", isDarkMode),
            _buildSectionText(
              "To function properly, this app requires access to your device's camera (for scanning) and storage (for saving and managing PDFs). We strictly use these permissions only for the core functionality of the app.", isDarkMode
            ),

            _buildSectionTitle("5. Changes to Terms", isDarkMode),
            _buildSectionText(
              "SP Tech Studios reserves the right to modify these terms at any time. Your continued use of the app following any changes signifies your acceptance of those changes.", isDarkMode
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(color: isDarkMode ? Colors.lightBlueAccent : Colors.blue, fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  // T&C ke normal text ke liye design
  Widget _buildSectionText(String text, bool isDarkMode) {
    return Text(text, style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontSize: 14, height: 1.5));
  }
}
