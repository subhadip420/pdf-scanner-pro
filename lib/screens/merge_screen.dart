import 'dart:io';
import 'package:flutter/material.dart';

class MergeScreen extends StatefulWidget {
  // 🚨 Editor screen se selected files yahan receive karenge
  final List<File> selectedImages;

  const MergeScreen({Key? key, required this.selectedImages}) : super(key: key);

  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  // 1. Thumbnail selection (Last photo default select hogi)
  late int _selectedImageIndex;

  // 2. Har image ki positions (X, Y) track karne ke liye
  late List<Offset> _imagePositions;

  @override
  void initState() {
    super.initState();
    // Default selected index: Last photo
    _selectedImageIndex = widget.selectedImages.length - 1;

    // Har image ko default center-ish position pe rakhne ke liye initialize karo
    _imagePositions = List.generate(
      widget.selectedImages.length,
          (index) => Offset(20.0 * index, 20.0 * index), // Thoda offset diya taaki ek ke upar ek chhip na jaye
    );
  }

  // --- TOOLBAR ITEM BUILDER (Editor jaisa) ---
  Widget _buildToolItem({
    required String label,
    required IconData icon,
    VoidCallback? onTap,
    bool isSelected = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blueAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2C2C), // Dark theme

      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Merge Pages",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, color: Colors.blueAccent, size: 28),
            onPressed: () {
              // Final merge aur save ka logic baad me aayega
              Navigator.pop(context);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: Column(
        children: [
          // ==========================================
          // 1. PREVIEW AREA (Zoomable & Draggable Canvas)
          // ==========================================
          Expanded(
            child: ClipRect(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                boundaryMargin: const EdgeInsets.all(100), // Panning margin
                child: Center(
                  child: AspectRatio(
                    // A4 Size Default Ratio (210 / 297 = 1 / 1.414)
                    aspectRatio: 210 / 297,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white, // Paper ka color
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      // Paper ke andar Photos ka Stack
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: List.generate(widget.selectedImages.length, (index) {
                          bool isSelected = _selectedImageIndex == index;
                          return Positioned(
                            left: _imagePositions[index].dx,
                            top: _imagePositions[index].dy,
                            child: GestureDetector(
                              // Tap karne par ye photo select ho jayegi
                              onTap: () {
                                setState(() {
                                  _selectedImageIndex = index;
                                });
                              },
                              // Drag (Pan) karke move karne ka logic
                              onPanUpdate: (details) {
                                setState(() {
                                  _selectedImageIndex = index; // Move karte waqt select ho jaye
                                  _imagePositions[index] += details.delta;
                                });
                              },
                              child: Container(
                                width: 150, // Default fixed size diya hai (baad me size sub-tool se change hoga)
                                decoration: BoxDecoration(
                                  // Jo select hogi uske aas-paas blue border dikhega
                                  border: Border.all(
                                    color: isSelected ? Colors.blueAccent : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Image.file(
                                  widget.selectedImages[index],
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ==========================================
          // 2. THUMBNAILS LIST (Bilkul Editor jaisa)
          // ==========================================
          Container(
            height: 90,
            color: const Color(0xFF1E1E1E),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.selectedImages.length,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemBuilder: (context, index) {
                bool isSelected = _selectedImageIndex == index;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedImageIndex = index;
                    });
                  },
                  child: Container(
                    width: 60,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? Colors.blueAccent : Colors.transparent,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Image.file(
                        widget.selectedImages[index],
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ==========================================
          // 3. MAIN TOOLS ITEM BAR
          // ==========================================
          Container(
            height: 75,
            width: double.infinity,
            color: const Color(0xFF151515),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
              children: [
                _buildToolItem(label: "Lock/Unlock", icon: Icons.lock_outline_rounded),
                _buildToolItem(label: "Position", icon: Icons.control_camera_rounded),
                _buildToolItem(label: "Rotate", icon: Icons.rotate_right_rounded),
                _buildToolItem(label: "Size", icon: Icons.photo_size_select_large_rounded),
                _buildToolItem(label: "Opacity", icon: Icons.opacity_rounded),
                _buildToolItem(label: "Collage", icon: Icons.auto_awesome_mosaic_rounded),
                _buildToolItem(label: "Grid Line", icon: Icons.grid_on_rounded),
                _buildToolItem(label: "Page Size", icon: Icons.aspect_ratio_rounded),
                _buildToolItem(label: "Delete", icon: Icons.delete_outline_rounded),
              ],
            ),
          ),

          // ==========================================
          // 4. BOTTOM BANNER AD PLACEHOLDER
          // ==========================================
          SafeArea(
            top: false,
            child: Container(
              height: 50, // Standard banner ad ki height
              width: double.infinity,
              color: Colors.black, // Dark background Ad ke peeche
              alignment: Alignment.center,
              child: const Text(
                "Banner Ad Space",
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}