import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:pdf_scanner_pro/screens/terms_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'custom_dialog.dart';
// Agar path_provider use kar rahe ho cache ke liye toh import kar lena, abhi ke liye functional UI bana diya hai.

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key); // 🚨 FIX: Callback hata diya

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Settings ki State Variables
  String _defaultPageSize = 'Auto Fit';
  bool _saveToGallery = true;
  String _storageLocation = "/storage/emulated/0/PDF Scanner Pro"; // Default Path

  @override
  void initState() {
    super.initState();
    _loadSettings(); // Page open hote hi settings load karo
  }

  // 🚨 FUNCTION: Settings Load Karna
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _defaultPageSize = prefs.getString('pref_page_size') ?? 'A4 (P)';
      _saveToGallery = prefs.getBool('pref_save_to_gallery') ?? false;
      _storageLocation = prefs.getString('pref_storage_location') ?? "/storage/emulated/0/PDF Scanner Pro";
    });
  }

  // 🚨 FUNCTION: Settings Save Karna
  Future<void> _saveSetting(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    _showSettingToast("Setting updated to $value");
  }

  // Dummy Toast Function (Agar tumhare app me already custom toast hai toh wahi chalega)
  void _showSettingToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2C2C2C),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // // Cache Clear Karne ka Logic
  // void _clearAppCache() {
  //   // Yahan future me tum temporary directory delete karne ka code daal sakte ho
  //   _showSettingToast("Cache cleared successfully! Storage freed.");
  // }

  // // Storage Location Change karne ka Logic (Placeholder)
  // void _changeStorageLocation() {
  //   _showSettingToast("Folder picker will open in next update!");
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF100F0F), // Dark Theme
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Settings",
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------------- CATEGORY 1: DOCUMENT SETTINGS ----------------
            _buildSectionHeader("Document Settings"),

            // 1. Default Page Size Dropdown
            Card(
              color: const Color(0xFF1A1A1A),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.text_snippet_rounded, color: Colors.lightBlueAccent),
                title: const Text("Default Page Size", style: TextStyle(color: Colors.white, fontSize: 15)),
                //subtitle: Text(_defaultPageSize, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                trailing: DropdownButton<String>(
                  value: _defaultPageSize,
                  dropdownColor: const Color(0xFF2C2C2C),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  underline: const SizedBox(), // Line hatane ke liye
                  items: <String>[
                    'Auto Fit',
                    'Letter (P)',
                    'Letter (L)',
                    'Legal (P)',
                    'Legal (L)',
                    'A4 (P)',
                    'A4 (L)',
                    'A3 (P)',
                    'A3 (L)',
                    'A5 (P)',
                    'A5 (L)'
                  ].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, style: const TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    if (newValue != null) {
                      setState(() {
                        _defaultPageSize = newValue;
                      });

                      // 🚨 NAYA: Disk (SharedPreferences) mein save karne ka call
                      _saveSetting('pref_page_size', newValue);

                      _showSettingToast("Default size set to $_defaultPageSize");
                    }
                  },
                ),
              ),
            ),


            // 2. Save to Gallery Toggle
            Card(
              color: const Color(0xFF1A1A1A),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: SwitchListTile(
                secondary: const Icon(Icons.add_to_photos_rounded, color: Colors.lightBlueAccent),
                title: const Text("Save to Gallery", style: TextStyle(color: Colors.white, fontSize: 15)),
                subtitle: const Text("Automatically save scanned photos to phone gallery", style: TextStyle(color: Colors.white54, fontSize: 12)),
                value: _saveToGallery,
                activeTrackColor: Colors.lightBlueAccent.withOpacity(0.3),
                inactiveThumbColor: Colors.white54,
                inactiveTrackColor: Colors.white12,
                onChanged: (bool value) async { // 🚨 NAYA: async banaya
                  setState(() {
                    _saveToGallery = value;
                  });

                  // 🚨 NAYA: Disk me save karo taaki hamesha yaad rahe
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('pref_save_to_gallery', value);

                  _showSettingToast(value ? "Enabled: Photos will save to gallery" : "Disabled: Photos will stay in app only");
                },
              ),
            ),

            // ---------------- CATEGORY 2: STORAGE & DATA ----------------
            _buildSectionHeader("Storage & Data"),

            // 3. Storage Location Tile
            _buildSettingTile(
              icon: Icons.folder_open_rounded,
              title: "Storage Location",
              subtitle: _storageLocation,
              onTap: _changeStorageLocation,
            ),

            // 4. Clear Cache Tile
            _buildSettingTile(
              icon: Icons.delete_sweep_rounded,
              title: "Clear App Cache",
              subtitle: "Free up space by deleting temp files",
              onTap: _clearAppCache,
            ),

            // ---------------- CATEGORY 3: SUPPORT & FEEDBACK ----------------
            _buildSectionHeader("Support & Feedback"),

            // 5. Share App
            _buildSettingTile(
              icon: Icons.share_rounded,
              title: "Share App",
              subtitle: "Share PDF Scanner Pro with friends",
              onTap: () {
                _shareApp();
              },
            ),

            // 6. Rate Us
            _buildSettingTile(
              icon: Icons.star_rate_rounded,
              title: "Rate Us",
              subtitle: "Support us on Google Play Store",
              onTap: () {
                _handleRateUs();
              },
            ),

            // 7. Customer Help
            _buildSettingTile(
              icon: Icons.support_agent_rounded,
              title: "Customer Help",
              subtitle: "Get help or report a problem",
              onTap: () {
                showSupportDialog(context);
              },
            ),

            // ---------------- CATEGORY 4: ABOUT & LEGAL ----------------
            _buildSectionHeader("About & Legal"),

            // 8. Terms & Conditions
            _buildSettingTile(
              icon: Icons.gavel_rounded,
              title: "Terms & Conditions",
              subtitle: "Read our usage policy and legal terms",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TermsAndConditionsScreen(),
                  ),
                );
              },
            ),

            // 9. About App
            _buildSettingTile(
              icon: Icons.info_outline_rounded,
              title: "About",
              subtitle: "App info and developer details",
              onTap: () {
                showAboutAppDialog(context);
              },
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // 🚨 NAYA FUNCTION: Cache Clear karne ka Asli Logic
  // Future<void> _clearAppCache() async {
  //   // 1. User ko wait karne ka message dikhao (Kyunki delete me thoda time lag sakta hai)
  //   _showSettingToast("Clearing cache... Please wait.");
  //
  //   try {
  //     // 2. App ki Temporary (Cache) Directory ka path nikalo
  //     final Directory tempDir = await getTemporaryDirectory();
  //
  //     // 3. Check karo ki folder exist karta hai ya nahi
  //     if (tempDir.existsSync()) {
  //
  //       // 4. Folder ke andar ki saari files aur sub-folders ki list banao
  //       final List<FileSystemEntity> tempFiles = tempDir.listSync();
  //       int deletedFilesCount = 0;
  //
  //       for (FileSystemEntity file in tempFiles) {
  //         try {
  //           // Har file/folder ko delete karo (recursive: true se andar ke folder bhi delete honge)
  //           file.deleteSync(recursive: true);
  //           deletedFilesCount++;
  //         } catch (e) {
  //           // Kuch files locked ho sakti hain, unhe chup-chaap ignore karo
  //           print("Skipped locked cache file: $e");
  //         }
  //       }
  //
  //       // 5. Success Message
  //       _showSettingToast("Success! Freed up space from $deletedFilesCount temp files.");
  //     } else {
  //       _showSettingToast("Cache is already clean!");
  //     }
  //   } catch (e) {
  //     print("Clear Cache Error: $e");
  //     _showSettingToast("Failed to clear cache properly.");
  //   }
  // }

  // 🚨 NAYA FUNCTION: Custom Dialog ke sath Cache Clear Logic
  Future<void> _clearAppCache() async {
    // 1. Pehle Custom Dialog open karo aur user ka jawaab (true/false) lo
    bool confirmClear = await showCustomConfirmDialog(
      context,
      title: "Clear Cache",
      message: "Are you sure you want to clear temporary app files? This will free up storage and will not delete your saved PDFs.",
      positiveBtnText: "Clear Cache",
      negativeBtnText: "Cancel",
      positiveBtnColor: Colors.redAccent, // 🚨 Destructive action hai isliye Red color diya
    );

    // 2. Agar user ne 'Cancel' dabaya ya bahar click kiya, toh function wahin ruk jayega
    if (!confirmClear) return;

    // 3. Agar user ne 'Clear Cache' (true) dabaya, toh delete logic start karo
    _showSettingToast("Clearing cache... Please wait.");

    try {
      final Directory tempDir = await getTemporaryDirectory();

      if (tempDir.existsSync()) {
        final List<FileSystemEntity> tempFiles = tempDir.listSync();
        int deletedFilesCount = 0;

        for (FileSystemEntity file in tempFiles) {
          try {
            file.deleteSync(recursive: true);
            deletedFilesCount++;
          } catch (e) {
            print("Skipped locked cache file: $e");
          }
        }

        // Success Message
        _showSettingToast("Success! Freed up space from $deletedFilesCount temp files.");
      } else {
        _showSettingToast("Cache is already clean!");
      }
    } catch (e) {
      print("Clear Cache Error: $e");
      _showSettingToast("Failed to clear cache properly.");
    }
  }

  // Section Headers ke liye Widget
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 20, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2),
      ),
    );
  }

  // Tiles ko reuse karne ke liye custom helper widget
  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: const Color(0xFF1A1A1A),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.lightBlueAccent),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 16),
        onTap: () {
          HapticFeedback.lightImpact(); // Click hone par subtle tactile feel
          onTap();
        },
      ),
    );
  }

  // 🚨 NAYA FUNCTION: Native In-App Review
  Future<void> _handleRateUs() async {
    final InAppReview inAppReview = InAppReview.instance;

    try {
      // 1. Check karo ki device me Play Store services available hain ya nahi
      if (await inAppReview.isAvailable()) {
        // 2. Native Play Store pop-up app ke andar hi dikhao
        await inAppReview.requestReview();
      } else {
        // 3. Agar review popup available nahi hai, toh seedha Play Store app me open karo
        // (Jab app publish ho jaye, toh apna package name daal dena, ex: 'com.sptech.pdfscanner')
        await inAppReview.openStoreListing(appStoreId: 'com.sptechstudios.pdfscannerpro');
        //TODO: change to original link
      }
    } catch (e) {
      print("Rate Us Error: $e");
      _showSettingToast("Unable to open rating dialog.");
    }
  }

  // 🚨 CORRECT FUNCTION FOR share_plus ^13.2.0
  // void _shareApp() {
  //   const String playStoreLink = "https://play.google.com/store/apps/details?id=com.sptech.pdfscanner";
  //   //TODO: change to original link
  //   const String shareMessage =
  //       "Hey! Check out PDF Scanner Pro by SP Tech Studios. "
  //       "It's a fast, secure, and 100% offline PDF creator & document scanner. "
  //       "Download it here: $playStoreLink";
  //
  //   // 🚨 MAGIC FIX: '.instance' ka use karna hai!
  //   SharePlus.instance.share(
  //     ShareParams(
  //       text: shareMessage,
  //       subject: "Download PDF Scanner Pro",
  //     ),
  //   );
  // }

  // 🚨 CORRECT FUNCTION FOR share_plus ^12.0.2
  void _shareApp() {
    const String playStoreLink = "https://play.google.com/store/apps/details?id=com.sptech.pdfscanner";

    const String shareMessage =
        "Hey! Check out PDF Scanner Pro by SP Tech Studios. "
        "It's a fast, secure, and 100% offline PDF creator & document scanner. "
        "Download it here: $playStoreLink";

    // 🚨 FIX: v12 ke hisaab se hum wapas classic Share.share use karenge
    Share.share(shareMessage, subject: "Download PDF Scanner Pro");
  }

  // 🚨 NAYA GLOBAL FUNCTION: Customer Support Dialog
  void showSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Customer Help",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Divider(color: Colors.white24, thickness: 1, height: 1),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "If you have any questions, feedback, or need help with PDF Scanner Pro, feel free to reach out to the SP Tech Studios team at:",
                style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 24),

              // 🚨 Clickable Email Box
              Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    // 1. Email open karne ka logic
                    const String supportEmail = "support.sptechstudios@gmail.com";
                    final Uri emailUri = Uri.parse("mailto:$supportEmail?subject=Support Request: PDF Scanner Pro");

                    try {
                      await launchUrl(emailUri);
                    } catch (e) {
                      print("Email Error: $e");
                    }

                    // 2. Click karne ke baad dialog automatically close kar do
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.lightBlueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.lightBlueAccent.withOpacity(0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        //Icon(Icons.email_outlined, color: Colors.lightBlueAccent, size: 20),
                        //SizedBox(width: 10),
                        Text(
                          "support.sptechstudios@gmail.com",
                          style: TextStyle(
                            color: Colors.lightBlueAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close", style: TextStyle(color: Colors.white54)),
            ),
          ],
        );
      },
    );
  }

  // 🚨 NAYA GLOBAL FUNCTION: Premium About Dialog
  void showAboutAppDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min, // Content ke hisaab se height lega
            children: [
              // 1. App Icon with glowing effect
              // Container(
              //   padding: const EdgeInsets.all(16),
              //   decoration: BoxDecoration(
              //     color: Colors.lightBlueAccent.withOpacity(0.1),
              //     shape: BoxShape.circle,
              //   ),
              //   child: const Icon(Icons.picture_as_pdf_rounded, size: 50, color: Colors.lightBlueAccent),
              // ),
              // const SizedBox(height: 16),

              // 2. App Name & Version
              const Text(
                "PDF Scanner Pro",
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                "Version 1.0.0",
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 20),

              const Divider(color: Colors.white12, thickness: 1),
              const SizedBox(height: 16),

              // 3. Description
              const Text(
                "A fast, secure, and professional tool to manage, merge, and organize all your PDF documents offline.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 20),

              // 4. Developer Credit
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  //const Icon(Icons.code_rounded, size: 16, color: Colors.white54),
                  const SizedBox(width: 8),
                  const Text(
                    "Developed by SP Tech Studios",
                    style: TextStyle(color: Colors.white54, fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 5. Close Button
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlueAccent,
                    foregroundColor: Colors.black, // Text color black for contrast
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 🚨 NAYA FUNCTION: Folder Picker & Storage Location Logic
  // 🚨 CORRECT FUNCTION: Folder Picker (Bina dialogTitle ke)
  Future<void> _changeStorageLocation() async {
    try {
      // 1. Native folder picker open karo (Error wala parameter hata diya)
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      // 2. Agar user ne koi folder select kiya (cancel nahi kiya)
      if (selectedDirectory != null) {
        setState(() {
          _storageLocation = selectedDirectory;
        });

        // 3. Naya path disk (SharedPreferences) mein hamesha ke liye save kar lo
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pref_storage_location', selectedDirectory);

        _showSettingToast("Folder updated successfully!");
      }
    } catch (e) {
      print("Folder Picker Error: $e");
      _showSettingToast("Failed to pick folder.");
    }
  }

}// end main