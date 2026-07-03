import 'package:flutter/material.dart';

class MergeScreen extends StatefulWidget {
  // Baad me hum yahan wo selected photos pass karenge
  // final List<File> selectedImages;

  const MergeScreen({Key? key}) : super(key: key);

  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2C2C), // Dark theme background

      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,

        // 🚨 LEFT SIDE: Cross Button (Close)
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
          onPressed: () {
            // Wapas pichle page par jane ke liye
            Navigator.pop(context);
          },
        ),

        // 🚨 CENTER: Title
        title: const Text(
          "Merge Pages",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,

        // 🚨 RIGHT SIDE: Tick Button (Done)
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, color: Colors.blueAccent, size: 28),
            onPressed: () {
              // Baad me yahan Merge save karne ka logic aayega
              // Abhi ke liye bas screen close kar dete hain
              Navigator.pop(context);
            },
          ),
          const SizedBox(width: 8), // Thodi si padding right side me
        ],
      ),

      // Khali body (Functions baad me aayenge)
      body: const Center(
        child: Text(
          "Merge preview will appear here",
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      ),
    );
  }
}