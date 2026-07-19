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
  bool _isShutterSoundOn = false;
  bool _isMirrorSelfieOn = true;
  bool _isHapticFeedbackOn = true;
  bool _saveToGallery = false;
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
      // Jo key set ki hai wahi exact name yahan use kiya hai
      _isGridOn = prefs.getBool('show_grid') ?? false;
      _saveToGallery = prefs.getBool('pref_save_to_gallery') ?? false;
      //_isShutterSoundOn = prefs.getBool('shutter_sound') ?? false;
      //_isMirrorSelfieOn = prefs.getBool('mirror_selfie') ?? true;
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
            _triggerHaptic(); // Back aane par bhi haptic feel
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // 🚨 FIX: Sabhi options se 'icon' hata diya gaya hai
                _buildSwitchTile(
                  title: "Grid",
                  subtitle: "Show grid lines to align documents",
                  value: _isGridOn,
                  //onChanged: (val) => setState(() => _isGridOn = val),
                  onChanged: (val) {
                    setState(() => _isGridOn = val);
                    _saveSetting('show_grid', val); // Memory me save
                    _triggerHaptic();
                  },
                ),
                _buildDivider(),

                // _buildSwitchTile(
                //   title: "Shutter sound",
                //   subtitle: "Play a sound when taking a photo",
                //   value: _isShutterSoundOn,
                //   //onChanged: (val) => setState(() => _isShutterSoundOn = val),
                //   onChanged: (val) {
                //     setState(() => _isShutterSoundOn = val);
                //     _saveSetting('shutter_sound', val); // Memory me save
                //     _triggerHaptic();
                //   },
                // ),
                // _buildDivider(),
                //
                // _buildSwitchTile(
                //   title: "Mirror selfie",
                //   subtitle: "Save front camera photos as they appear",
                //   value: _isMirrorSelfieOn,
                //   //onChanged: (val) => setState(() => _isMirrorSelfieOn = val),
                //   onChanged: (val) {
                //     setState(() => _isMirrorSelfieOn = val);
                //     _saveSetting('mirror_selfie', val); // Memory me save
                //     _triggerHaptic();
                //   },
                // ),
                // _buildDivider(),

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
                // 🚨 NAYA: Save to Gallery (Camera Settings Layout)
                // ==========================================
                _buildSwitchTile(
                  title: "Save original to Gallery",
                  subtitle: "Automatically save raw scanned photos to phone gallery",
                  value: _saveToGallery, // Make sure tumne upar variables me `bool _saveToGallery = false;` define kiya ho
                  onChanged: (val) {
                    setState(() => _saveToGallery = val);

                    // Yahan tumhara setting save karne ka custom function use kiya hai
                    _saveSetting('pref_save_to_gallery', val);

                    // Toast dikhane ke liye
                    // Fluttertoast.showToast(
                    //   msg: val ? "Raw photos will save to gallery" : "Photos will stay in app only",
                    //   toastLength: Toast.LENGTH_SHORT,
                    //   gravity: ToastGravity.BOTTOM,
                    // );
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

  // 🚨 FIX: Function parameters se 'icon' hata diya
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
      // 🚨 FIX: Yahan se 'secondary: Icon(...)' property poori tarah hata di
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.white54, fontSize: 13),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: Colors.white.withOpacity(0.1),
      height: 1,
      thickness: 1,
      // 🚨 FIX: Indent ko 60 se 16 kar diya taaki divider line text ke ekdum neeche se shuru ho
      indent: 16,
      endIndent: 16,
    );
  }
}//end main class