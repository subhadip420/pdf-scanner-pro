import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CameraSettingsScreen extends StatefulWidget {
  const CameraSettingsScreen({Key? key}) : super(key: key);

  @override
  State<CameraSettingsScreen> createState() => _CameraSettingsScreenState();
}

class _CameraSettingsScreenState extends State<CameraSettingsScreen> {
  // Default Values
  bool _isGridOn = false;
  bool _isHapticFeedbackOn = true;
  bool _saveToGallery = false;
  bool _isAutoDetectAlwaysOn = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // --- Load Settings ---
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isHapticFeedbackOn = prefs.getBool('haptic_feedback') ?? true;
      _isGridOn = prefs.getBool('show_grid') ?? false;
      _saveToGallery = prefs.getBool('pref_save_to_gallery') ?? false;
      _isAutoDetectAlwaysOn = prefs.getBool('pref_auto_detect_always_on') ?? true;
    });
  }

  // --- Save Settings ---
  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  // Haptic Helper
  void _triggerHaptic() {
    if (_isHapticFeedbackOn) {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF100F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
          onPressed: () {
            _triggerHaptic();
            Navigator.pop(context);
          },
        ),
        title: const Text(
          "Camera Settings",
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        physics: const BouncingScrollPhysics(),
        children: [
          // CARD VIEW START
          Card(
            color: const Color(0xFF1A1A1A),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                _buildSwitchTile(
                  title: "Grid",
                  subtitle: "Show grid lines to align documents",
                  value: _isGridOn,
                  onChanged: (val) {
                    setState(() => _isGridOn = val);
                    _saveSetting('show_grid', val);
                    _triggerHaptic();
                  },
                ),
                _buildDivider(),

                _buildSwitchTile(
                  title: "Haptic feedback",
                  subtitle: "Vibrate when capturing photos",
                  value: _isHapticFeedbackOn,
                  onChanged: (val) {
                    setState(() => _isHapticFeedbackOn = val);
                    _saveSetting('haptic_feedback', val);

                    if (val) {
                      HapticFeedback.lightImpact();
                    }
                  },
                ),

                _buildDivider(),

                // ==========================================
                //  Save to Gallery (Camera Settings Layout)
                // ==========================================
                _buildSwitchTile(
                  title: "Save original to Gallery",
                  subtitle: "Automatically save raw scanned photos to phone gallery",
                  value: _saveToGallery,
                  onChanged: (val) {
                    setState(() => _saveToGallery = val);
                    _saveSetting('pref_save_to_gallery', val);
                  },
                ),

                _buildDivider(), // 🚨 NAYA Divider
                // ==========================================
                // Auto-detect Always On Toggle
                // ==========================================
                _buildSwitchTile(
                  title: "Auto-detect Always On",
                  subtitle: "Start camera with AI auto-capture enabled",
                  value: _isAutoDetectAlwaysOn,
                  onChanged: (val) {
                    setState(() => _isAutoDetectAlwaysOn = val);
                    _saveSetting('pref_auto_detect_always_on', val);
                    _triggerHaptic();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  // Function parameters se 'icon' hata diya
  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeColor: Colors.blueAccent,
      activeTrackColor: Colors.blueAccent.withOpacity(0.4),
      inactiveThumbColor: Colors.grey.shade400,
      inactiveTrackColor: Colors.grey.shade700,
      // Yahan se 'secondary: Icon(...)' property poori tarah hata di
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 13)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildDivider() {
    return Divider(color: Colors.white.withOpacity(0.1), height: 1, thickness: 1, indent: 16, endIndent: 16);
  }
} //end main class
