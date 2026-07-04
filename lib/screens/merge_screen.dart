import 'dart:io';
import 'package:flutter/material.dart';

class MergeScreen extends StatefulWidget {
  // 🚨 Editor screen se selected files yahan receive karenge
  final List<File> selectedImages;

  const MergeScreen({Key? key, required this.selectedImages}) : super(key: key);

  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

// 🚨 NAYI CLASS: Photo ki saari state (position, size, rotation) store karne ke liye
class MergedImageState {
  File file;
  Offset position;
  double scale;
  double rotation;
  bool isHidden;

  MergedImageState({
    required this.file,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.isHidden = false,
  });
}

class _MergeScreenState extends State<MergeScreen> {
  // 1. Thumbnail selection (Last photo default select hogi)
  int? _selectedImageIndex;
  late List<MergedImageState> _imageStates;

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

    // 🚨 FIX: Naye format me initialize karo
    _imageStates = List.generate(
      widget.selectedImages.length,
          (index) => MergedImageState(
        file: widget.selectedImages[index],
        position: Offset(20.0 * index, 20.0 * index),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2C2C), // Dark theme

      // appBar: AppBar(
      //   backgroundColor: const Color(0xFF1E1E1E),
      //   elevation: 0,
      //   leading: IconButton(
      //     icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
      //     onPressed: () => Navigator.pop(context),
      //   ),
      //   title: const Text(
      //     "Merge Pages",
      //     style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
      //   ),
      //   centerTitle: true,
      //   actions: [
      //     IconButton(
      //       icon: const Icon(Icons.check_rounded, color: Colors.blueAccent, size: 28),
      //       onPressed: () {
      //         // Final merge aur save ka logic baad me aayega
      //         Navigator.pop(context);
      //       },
      //     ),
      //     const SizedBox(width: 8),
      //   ],
      // ),

      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
          onPressed: () => Navigator.pop(context),
        ),

        // 🚨 CHANGE 1: centerTitle false kar diya taaki title left me aa jaye
        title: const Text(
          "Merge Pages",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: false,

        actions: [
          // 🚨 CHANGE 2: Undo Button (Tick se pehle)
          IconButton(
            icon: const Icon(Icons.undo_rounded, color: Colors.white, size: 24),
            tooltip: "Undo",
            onPressed: () {
              // Undo logic baad me aayega
            },
          ),

          // 🚨 CHANGE 3: Redo Button (Undo ke theek baad)
          IconButton(
            icon: const Icon(Icons.redo_rounded, color: Colors.white, size: 24),
            tooltip: "Redo",
            onPressed: () {
              // Redo logic baad me aayega
            },
          ),

          // Tick Button (Done) - Apni purani jagah par
          IconButton(
            icon: const Icon(Icons.check_rounded, color: Colors.blueAccent, size: 28),
            tooltip: "Save",
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),

      body: Column(
        children: [
          Expanded(
            child: ClipRect(
              child: GestureDetector(
                // 🚨 FIX: Paper ke bahar click karne par deselect ho jaye
                onTap: () => setState(() => _selectedImageIndex = null),
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  boundaryMargin: EdgeInsets.zero,
                  child: Center(
                  child: Padding(
                  padding: const EdgeInsets.all(40.0),
                    child: AspectRatio(
                      aspectRatio: 210 / 297, // A4 Default Size
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white, // Paper Color
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)],
                        ),
                        // 🚨 4. PHOTO STACK WITH CONTROLS
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: List.generate(_imageStates.length, (index) {
                            bool isSelected = _selectedImageIndex == index;
                            var imgState = _imageStates[index];
                            // 🚨 CHANGE 2: Agar image hidden hai, toh usko canvas par draw hi mat karo
                            if (imgState.isHidden) {
                              return const SizedBox.shrink(); // Empty space return karega
                            }

                            double baseWidth = 150.0; // Initial fixed width

                            return Positioned(
                              left: imgState.position.dx,
                              bottom: imgState.position.dy,

                                child: Transform.rotate(
                                angle: imgState.rotation,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // --- MAIN IMAGE CONTAINER ---
                                  GestureDetector(
                                    onTap: () => setState(() => _selectedImageIndex = index),
                                    onPanUpdate: (details) {
                                      setState(() {
                                        _selectedImageIndex = index;
                                        //_imageStates[index].position += details.delta;
                                        _imageStates[index].position += Offset(details.delta.dx, -details.delta.dy);
                                      });
                                    },

                                      child: Container(
                                        width: baseWidth * imgState.scale,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: isSelected ? Colors.blueAccent : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                        child: Image.file(imgState.file, fit: BoxFit.contain),
                                      ),
                                  ),

                                  // --- CORNER CONTROLS (Sirf tab dikhenge jab select ho) ---
                                  if (isSelected) ...[

                                    // 1. TOP-LEFT: DELETE ICON
                                    Positioned(
                                      top: -12, left: -12,
                                      child: GestureDetector(
                                        onTap: () => setState(() {
                                          // Image hide kardo aur deselect kardo
                                          _imageStates[index].isHidden = true;
                                          _selectedImageIndex = null;
                                        }),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                          child: const Icon(Icons.visibility_off_rounded, color: Colors.white, size: 16),
                                        ),
                                      ),
                                    ),

                                    // 2. TOP-RIGHT: SCALE ICON
                                    Positioned(
                                      top: -12, right: -12,
                                      child: GestureDetector(
                                        onPanUpdate: (details) {
                                          setState(() {
                                            double sensitivity = 0.003;
                                            double scaleChange = (details.delta.dx - details.delta.dy) * sensitivity;
                                            _imageStates[index].scale = (_imageStates[index].scale + scaleChange).clamp(0.2, 5.0);
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                                          child: const Icon(Icons.open_in_full_rounded, color: Colors.white, size: 16),
                                        ),
                                      ),
                                    ),

                                    // 3. BOTTOM-RIGHT: ROTATE ICON
                                    Positioned(
                                      bottom: -12, right: -12,
                                      child: GestureDetector(
                                        onPanUpdate: (details) {
                                          setState(() {
                                            _imageStates[index].rotation += details.delta.dx * 0.02;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                                          child: const Icon(Icons.rotate_right_rounded, color: Colors.black, size: 16),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
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
            ),
          ),

          // ==========================================
          // 2. THUMBNAILS LIST (Bilkul Editor jaisa)
          // ==========================================
          // Container(
          //   height: 90,
          //   color: const Color(0xFF1E1E1E),
          //   child: ListView.builder(
          //     scrollDirection: Axis.horizontal,
          //     //itemCount: widget.selectedImages.length,
          //     itemCount: _imageStates.length,
          //     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          //     itemBuilder: (context, index) {
          //       bool isSelected = _selectedImageIndex == index;
          //       return GestureDetector(
          //         onTap: () {
          //           setState(() {
          //             _selectedImageIndex = index;
          //           });
          //         },
          //         child: Container(
          //           width: 60,
          //           margin: const EdgeInsets.only(right: 12),
          //           decoration: BoxDecoration(
          //             border: Border.all(
          //               color: isSelected ? Colors.blueAccent : Colors.transparent,
          //               width: 3,
          //             ),
          //             borderRadius: BorderRadius.circular(4),
          //           ),
          //           child: ClipRRect(
          //             borderRadius: BorderRadius.circular(2),
          //             // child: Image.file(
          //             //   widget.selectedImages[index],
          //             //   fit: BoxFit.cover,
          //             // ),
          //             child: Image.file(
          //               _imageStates[index].file, // Yahan pehle widget.selectedImages[index] tha
          //               fit: BoxFit.cover,
          //             ),
          //           ),
          //         ),
          //       );
          //     },
          //   ),
          // ),

          // ==========================================
          // 2. THUMBNAILS LIST
          // ==========================================
          Container(
            height: 90,
            color: const Color(0xFF1E1E1E),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _imageStates.length,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemBuilder: (context, index) {
                bool isSelected = _selectedImageIndex == index;
                bool isHidden = _imageStates[index].isHidden; // Check if hidden

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      // 🚨 CHANGE 4: Agar image hidden thi aur user ne uske thumbnail pe click kiya, toh use wapas unhide kardo
                      // if (_imageStates[index].isHidden) {
                      //   _imageStates[index].isHidden = false;
                      // }
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
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Base Image (Hidden hone par 30% opacity)
                          Opacity(
                            opacity: isHidden ? 0.3 : 1.0,
                            child: Image.file(
                              _imageStates[index].file,
                              fit: BoxFit.cover,
                            ),
                          ),
                          // Overlay Icon (Sirf tab dikhega jab hidden hogi)
                          if (isHidden)
                            Container(
                              color: Colors.black45, // Thoda dark shade photo ke upar
                              child: const Icon(
                                Icons.visibility_off_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                        ],
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
          // Container(
          //   height: 75,
          //   width: double.infinity,
          //   color: const Color(0xFF151515),
          //   child: ListView(
          //     scrollDirection: Axis.horizontal,
          //     padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          //     children: [
          //       _buildToolItem(label: "Lock/Unlock", icon: Icons.lock_outline_rounded),
          //       _buildToolItem(label: "Position", icon: Icons.control_camera_rounded),
          //       _buildToolItem(label: "Rotate", icon: Icons.rotate_right_rounded),
          //       _buildToolItem(label: "Size", icon: Icons.photo_size_select_large_rounded),
          //       _buildToolItem(label: "Opacity", icon: Icons.opacity_rounded),
          //       _buildToolItem(label: "Collage", icon: Icons.auto_awesome_mosaic_rounded),
          //       _buildToolItem(label: "Grid Line", icon: Icons.grid_on_rounded),
          //       _buildToolItem(label: "Page Size", icon: Icons.aspect_ratio_rounded),
          //       _buildToolItem(label: "Delete", icon: Icons.delete_outline_rounded),
          //     ],
          //   ),
          // ),

          // ==========================================
          // 3. MAIN TOOLS ITEM BAR
          // ==========================================
          Container(
            height: 75,
            width: double.infinity,
            color: const Color(0xFF151515),
            child: Row(
              children: [
                // 🚨 FIX 1: Lock/Unlock button ko left me FIXED rakha
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, right: 4.0),
                  child: _buildToolItem(
                    label: "Lock",
                    icon: Icons.lock_outline_rounded,
                  ),
                ),

                // Ek choti si line (Divider) taaki fixed aur scrollable alag dikhe
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white24,
                ),

                // 🚨 FIX 2: Baki tools ko Expanded ke andar scrollable ListView me daala
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                    children: [
                      _buildToolItem(label: "Layer", icon: Icons.layers_rounded),
                      _buildToolItem(label: "Hide", icon: Icons.visibility_off_rounded),
                      _buildToolItem(label: "Position", icon: Icons.control_camera_rounded),
                      _buildToolItem(label: "Rotate", icon: Icons.rotate_right_rounded),
                      _buildToolItem(label: "Size", icon: Icons.photo_size_select_large_rounded),
                      _buildToolItem(label: "Opacity", icon: Icons.opacity_rounded),
                      _buildToolItem(label: "Page Size", icon: Icons.aspect_ratio_rounded),
                      _buildToolItem(label: "Collage", icon: Icons.auto_awesome_mosaic_rounded),
                      _buildToolItem(label: "Grid Line", icon: Icons.grid_on_rounded),

                      _buildToolItem(label: "Delete", icon: Icons.delete_outline_rounded),
                    ],
                  ),
                ),
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



}