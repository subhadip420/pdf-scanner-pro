import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:pdf_scanner_pro/screens/terms_screen.dart';
import 'package:pdf_scanner_pro/screens/trash_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_storage/shared_storage.dart' as saf;
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import 'custom_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key); // 🚨 FIX: Callback hata diya

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _defaultPageSize = 'Auto Fit';
  bool _saveToGallery = true;
  String _storageLocation = "/storage/emulated/0/PDF Scanner Pro"; // Default Path
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  bool isDarkMode = true;
  bool isHapticEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadBannerAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      //adUnitId: 'ca-app-pub-3940256099942544/6300978111', // Test ID
      adUnitId: 'ca-app-pub-5454466291921987/3057082758',

      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          print('Banner Ad failed to load: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _defaultPageSize = prefs.getString('pref_page_size') ?? 'A4 (P)';
      _saveToGallery = prefs.getBool('pref_save_to_gallery') ?? false;
      _storageLocation = prefs.getString('pdf_save_folder') ?? "";

      isDarkMode = prefs.getBool('pref_dark_mode') ?? true; // Default dark mode ON
      isHapticEnabled = prefs.getBool('pref_haptic') ?? true; // Default vibration ON
    });
  }

  Future<void> _saveSetting(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    //_showSettingToast("Setting updated to $value");
  }

  Future<void> _saveBoolSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _showSettingToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2C2C2C),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF100F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Settings",
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [

          if (_isBannerAdLoaded && _bannerAd != null)
            Container(
              color: Colors.transparent,
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---------------- CATEGORY 1: DOCUMENT SETTINGS ----------------
                  _buildSectionHeader("Document Settings"),

                  Card(
                    color: const Color(0xFF1A1A1A),
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const Icon(Icons.text_snippet_rounded, color: Colors.lightBlueAccent),
                      title: const Text("Default Page Size", style: TextStyle(color: Colors.white, fontSize: 15)),
                      trailing: DropdownButton<String>(
                        value: _defaultPageSize,
                        dropdownColor: const Color(0xFF2C2C2C),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                        underline: const SizedBox(),
                        items:
                            <String>[
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
                              'A5 (L)',
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

                            _saveSetting('pref_page_size', newValue);
                            _showSettingToast("Default size set to $_defaultPageSize");
                          }
                        },
                      ),
                    ),
                  ),

                  // 1. Header banayein
                  _buildSectionHeader("Appearance & Vibration"),

                  // Dark Mode Toggle
                  _buildToggleTile(
                    icon: Icons.dark_mode_outlined,
                    title: "Dark Mode",
                    subtitle: "System wide dark theme",
                    value: isDarkMode,
                    onChanged: (value) {
                      setState(() {
                        isDarkMode = value;
                      });
                      isDarkModeNotifier.value = value;
                      _saveBoolSetting('pref_dark_mode', value);
                    },
                  ),

                  // Haptic Toggle
                  _buildToggleTile(
                    icon: Icons.vibration,
                    title: "System Vibration",
                    subtitle: "Vibrate when tapping buttons",
                    value: isHapticEnabled,
                    onChanged: (value) {
                      setState(() {
                        isHapticEnabled = value;
                      });
                      _saveBoolSetting('pref_haptic', value);
                    },
                  ),

                  _buildSectionHeader("Storage & Data"),

                  _buildSettingTile(
                    icon: Icons.folder_open_rounded,
                    title: "Download Location",
                    subtitle: _storageLocation.isEmpty ? "Not set" : "Custom Folder Set",
                    onTap: _changeStorageLocation,
                  ),

                  _buildSettingTile(
                    icon: Icons.delete_sweep_rounded,
                    title: "Clear App Cache",
                    subtitle: "Free up space by deleting temp files",
                    onTap: _clearAppCache,
                  ),

                  _buildSettingTile(
                    icon: Icons.restore_from_trash_rounded,
                    title: "Recently Deleted",
                    subtitle: "Recover files (30 days backup)",
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const TrashScreen()));
                    },
                  ),

                  _buildSectionHeader("Support & Feedback"),

                  // Share App
                  _buildSettingTile(
                    icon: Icons.share_rounded,
                    title: "Share App",
                    subtitle: "Share PDF Scanner Pro with friends",
                    onTap: () {
                      _shareApp();
                    },
                  ),

                  // Rate Us
                  _buildSettingTile(
                    icon: Icons.star_rate_rounded,
                    title: "Rate Us",
                    subtitle: "Support us on Google Play Store",
                    onTap: () {
                      _handleRateUs();
                    },
                  ),

                  // Customer Help
                  _buildSettingTile(
                    icon: Icons.support_agent_rounded,
                    title: "Customer Help",
                    subtitle: "Get help or report a problem",
                    onTap: () {
                      showSupportDialog(context);
                    },
                  ),

                  _buildSectionHeader("About & Legal"),

                  //  Terms & Conditions
                  _buildSettingTile(
                    icon: Icons.gavel_rounded,
                    title: "Terms & Conditions",
                    subtitle: "Read our usage policy and legal terms",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const TermsAndConditionsScreen()),
                      );
                    },
                  ),

                  // About App
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
          ),
        ],
      ),
    );
  }

  // FUNCTION: Custom Dialog ke sath Cache Clear Logic
  Future<void> _clearAppCache() async {
    bool confirmClear = await showCustomConfirmDialog(
      context,
      title: "Clear Cache",
      message:
          "Are you sure you want to clear temporary app files? This will free up storage and will not delete your saved PDFs.",
      positiveBtnText: "Clear Cache",
      negativeBtnText: "Cancel",
      positiveBtnColor: Colors.redAccent,
    );

    if (!confirmClear) return;
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 20, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.lightBlueAccent,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

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
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 16),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      color: const Color(0xFF1A1A1A),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.lightBlueAccent),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: Switch(
          value: value,
          onChanged: (newValue) {
            if (isHapticEnabled) HapticFeedback.lightImpact(); // Haptic setting check
            onChanged(newValue);
          },
          activeThumbColor: Colors.lightBlueAccent,
          activeTrackColor: Colors.lightBlueAccent.withOpacity(0.4),
        ),
        onTap: () {
          if (isHapticEnabled) HapticFeedback.lightImpact();
          onChanged(!value); // Pura tile click karne pe bhi toggle ho jayega
        },
      ),
    );
  }

  //  FUNCTION: Native In-App Review
  Future<void> _handleRateUs() async {
    final InAppReview inAppReview = InAppReview.instance;

    try {
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
      } else {
        await inAppReview.openStoreListing(appStoreId: 'com.sptechstudios.pdfscannerpro');
        //TODO: change to original link
      }
    } catch (e) {
      print("Rate Us Error: $e");
      _showSettingToast("Unable to open rating dialog.");
    }
  }

  Future<void> _shareApp() async {
    const String playStoreLink = "https://play.google.com/store/apps/details?id=com.sptechstudios.pdf_scanner_pro";

    const String shareMessage =
        "Hey! Check out PDF Scanner Pro by SP Tech Studios. "
        "It's a fast, secure, and 100% offline PDF creator & document scanner. "
        "Download it here: $playStoreLink";

    try {
      await SharePlus.instance.share(ShareParams(text: shareMessage, subject: "Download PDF Scanner Pro"));
    } catch (e) {
      print("Share error: $e");
    }
  }

  //  GLOBAL FUNCTION: Customer Support Dialog
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

              // Clickable Email Box
              Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    // Email open karne ka logic
                    const String supportEmail = "support.sptechstudios@gmail.com";
                    final Uri emailUri = Uri.parse("mailto:$supportEmail?subject=Support Request: PDF Scanner Pro");

                    try {
                      await launchUrl(emailUri);
                    } catch (e) {
                      print("Email Error: $e");
                    }
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
                        Text(
                          "support.sptechstudios@gmail.com",
                          style: TextStyle(color: Colors.lightBlueAccent, fontSize: 13, fontWeight: FontWeight.bold),
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

  // GLOBAL FUNCTION: Premium About Dialog
  void showAboutAppDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App Name & Version
              const Text(
                "PDF Scanner Pro",
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text("Version 1.0.0", style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 20),

              const Divider(color: Colors.white12, thickness: 1),
              const SizedBox(height: 16),

              // Description
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
                  const SizedBox(width: 8),
                  const Text(
                    "Developed by SP Tech Studios",
                    style: TextStyle(color: Colors.white54, fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Close Button
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlueAccent,
                    foregroundColor: Colors.black,
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

  // FUNCTION: Folder Picker (Using SAF to sync with Downloads)
  Future<void> _changeStorageLocation() async {
    try {
      Uri? folderUri = await saf.openDocumentTree();
      if (folderUri != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pdf_save_folder', folderUri.toString());
        setState(() {
          _storageLocation = folderUri.toString();
        });

        _showSettingToast("Download location updated successfully!");
      }
    } catch (e) {
      print("Folder Picker Error: $e");
      _showSettingToast("Failed to pick folder.");
    }
  }
} // end main
