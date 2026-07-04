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
  bool isLocked;

  MergedImageState({
    required this.file,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.isHidden = false,
    this.isLocked = false,
  });
}

class _MergeScreenState extends State<MergeScreen> {
  // 1. Thumbnail selection (Last photo default select hogi)
  int? _selectedImageIndex;
  late List<MergedImageState> _imageStates;

  // 2. Har image ki positions (X, Y) track karne ke liye
  late List<Offset> _imagePositions;

  bool isResizeMode = false;
  String _selectedPageSize = "A4 (P)"; // Default page size

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
                      aspectRatio: _getPageAspectRatio(),
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
                                    // 🚨 FIX 1: Agar locked hai toh preview canvas par click ya drag puri tarah disable
                                    onTap: imgState.isLocked ? null : () {
                                      setState(() {
                                        _selectedImageIndex = index;
                                      });
                                    },
                                    onPanUpdate: imgState.isLocked ? null : (details) {
                                      setState(() {
                                        _selectedImageIndex = index;
                                        _imageStates[index].position += Offset(details.delta.dx, -details.delta.dy);
                                      });
                                    },
                                    child: Transform.rotate(
                                      angle: imgState.rotation,
                                      child: Container(
                                        width: baseWidth * imgState.scale,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            // 🚨 FIX 2: Agar locked hai, toh preview me KOI BORDER nahi aayega, chahe thumbnail se select kiya ho
                                            color: (isSelected && !imgState.isLocked)
                                                ? Colors.blueAccent
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                        child: Image.file(imgState.file, fit: BoxFit.contain),
                                      ),
                                    ),
                                  ),

                                  // --- CORNER CONTROLS (Sirf tab dikhenge jab select ho) ---
                                  if (isSelected && !imgState.isLocked) ...[

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

                          // 🚨 CHANGE 3: Lock Icon (Agar photo locked hai)
                          if (_imageStates[index].isLocked)
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(2), // Circle ka size adjust karne ke liye
                                decoration: const BoxDecoration(
                                  color: Colors.white, // White background
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.lock_rounded,
                                  color: Colors.redAccent,
                                  size: 14, // Icon thoda chhota kiya taaki circle me fit aaye
                                ),
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

    Container(
    height: 68,
    color: const Color(0xFF151515),
    child: ClipRect(
            child: Stack(
              children: [

                // --- A. MAIN TOOLBAR (Animated Slide Down) ---
                AnimatedSlide(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  // 🚨 FIX: Agar resize mode on hai, toh isko niche (1.0) bhej do
                  offset: isResizeMode ? const Offset(0, 1.0) : Offset.zero,
                  child: _buildNormalTools(), // Yahan function call ho gaya
                ),

                // --- B. TOP LAYER: RESIZE SUB-TOOLS (Animated Slide Up) ---
                AnimatedSlide(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  // Agar resize mode on hai, toh isko upar (0) le aao
                  offset: isResizeMode ? Offset.zero : const Offset(0, 1.0),
                  child: _buildPageSizeSubTools(),
                ),

              ],
            ),
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
        ], // Column Children Ends
      ), // Column Ends
    ); // Scaffold Ends
  }




  // --- TOOLBAR ITEM BUILDER (Editor jaisa) ---
  Widget _buildToolItem({
    required String label,
    required IconData icon,
    VoidCallback? onTap,
    bool isSelected = false,
    bool isDisabled = false,
    String? tooltipMessage,
  }) {
    //return GestureDetector(
      //onTap: onTap,
    return Tooltip(
        // Agar custom tooltipMessage nahi diya hai, toh default button ka 'label' hi dikhayega
        message: tooltipMessage ?? label,
        waitDuration: const Duration(milliseconds: 500), // 0.5 sec hold karne par tooltip aayega
    preferBelow: false, // Tooltip button ke upar dikhega taaki ungli se chhupe na
    child: GestureDetector(
      onTap: isDisabled ? null : onTap,
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
              //Icon(icon, color: Colors.white, size: 22),
              Icon(
                  icon,
                  // Disabled hone par icon dhundhla (grey) ho jayega
                  color: isDisabled ? Colors.white24 : Colors.white,
                  size: 22
              ),
              const SizedBox(height: 6),
              Text(
                label,
                //style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                style: TextStyle(
                  // Disabled hone par text bhi dhundhla (grey) ho jayega
                    color: isDisabled ? Colors.white24 : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }


  // --- 🚨 NAYA BLOCK: MAIN NORMAL TOOLS ---
  Widget _buildNormalTools() {
    return Container(
      height: 75,
      width: double.infinity,
      color: const Color(0xFF151515),
      child: Row(
        children: [
          // 1. Lock/Unlock
          Padding(
            padding: const EdgeInsets.only(left: 8.0, right: 4.0),
            child: _buildToolItem(
              label: (_selectedImageIndex != null && _imageStates[_selectedImageIndex!].isLocked) ? "Unlock" : "Lock",
              icon: (_selectedImageIndex != null && _imageStates[_selectedImageIndex!].isLocked) ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
              isDisabled: _selectedImageIndex == null,
              onTap: () {
                if (_selectedImageIndex != null) {
                  setState(() {
                    _imageStates[_selectedImageIndex!].isLocked = !_imageStates[_selectedImageIndex!].isLocked;
                    if (_imageStates[_selectedImageIndex!].isLocked) _selectedImageIndex = null;
                  });
                }
              },
            ),
          ),

          Container(width: 1, height: 40, color: Colors.white24),

          // 2. Scrollable List (Main Tools)
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              children: [
                _buildToolItem(
                    label: "Page Size",
                    icon: Icons.aspect_ratio_rounded,
                    isDisabled: false,
                    onTap: () => setState(() => isResizeMode = true)
                ),
                _buildToolItem(
                    label: (_selectedImageIndex != null && _imageStates[_selectedImageIndex!].isHidden) ? "Unhide" : "Hide",
                    icon: (_selectedImageIndex != null && _imageStates[_selectedImageIndex!].isHidden) ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    isDisabled: _selectedImageIndex == null,
                    onTap: () {
                      if (_selectedImageIndex != null) {
                        setState(() {
                          _imageStates[_selectedImageIndex!].isHidden = !_imageStates[_selectedImageIndex!].isHidden;
                        });
                      }
                    }
                ),
                _buildToolItem(label: "Position", icon: Icons.control_camera_rounded, isDisabled: _selectedImageIndex == null || _imageStates[_selectedImageIndex!].isLocked || _imageStates[_selectedImageIndex!].isHidden),
                _buildToolItem(label: "Rotate", icon: Icons.rotate_right_rounded, isDisabled: _selectedImageIndex == null || _imageStates[_selectedImageIndex!].isLocked || _imageStates[_selectedImageIndex!].isHidden),
                _buildToolItem(label: "Size", icon: Icons.photo_size_select_large_rounded, isDisabled: _selectedImageIndex == null || _imageStates[_selectedImageIndex!].isLocked || _imageStates[_selectedImageIndex!].isHidden),
                _buildToolItem(label: "Opacity", icon: Icons.opacity_rounded, isDisabled: _selectedImageIndex == null || _imageStates[_selectedImageIndex!].isLocked || _imageStates[_selectedImageIndex!].isHidden),
                _buildToolItem(label: "Collage", icon: Icons.auto_awesome_mosaic_rounded, isDisabled: false),
                _buildToolItem(label: "Grid Line", icon: Icons.grid_on_rounded, isDisabled: false),
                _buildToolItem(
                    label: "Delete",
                    icon: Icons.delete_outline_rounded,
                    isDisabled: _selectedImageIndex == null || _imageStates[_selectedImageIndex!].isLocked,
                    onTap: () {
                      if (_selectedImageIndex != null && !_imageStates[_selectedImageIndex!].isLocked) {
                        setState(() {
                          _imageStates.removeAt(_selectedImageIndex!);
                          _selectedImageIndex = null;
                        });
                      }
                    }
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 🚨 NAYA BLOCK: RESIZE SUB TOOLS (Fixed Close Button) ---
  Widget _buildPageSizeSubTools() {
    // 🚨 FIX 1: Check karo ki custom size apply hua hai ya original 'Auto Fit' par hai
    bool hasCustomSize = _selectedPageSize != "Auto Fit";

    return SizedBox(
      key: const ValueKey("ResizeSubTools"),
      height: 75,
      width: double.infinity,

      // 🚨 FIX: Row ka use kiya taaki Close button fixed rahe
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: _buildToolItem(
              // 🚨 FIX 2: Condition ke hisaab se label, icon aur tooltip change hoga
              label: hasCustomSize ? "Done" : "Close",
              icon: hasCustomSize ? Icons.check_rounded : Icons.close_rounded,
              tooltipMessage: hasCustomSize ? "Apply changes" : "Close resize options",

              // 🚨 MAGIC: isSelected true hote hi icon aur text automatically BLUE ho jayega!
              isSelected: hasCustomSize,

              onTap: () {
                setState(() {
                  isResizeMode = false;
                  //isThumbnailVisible = true;
                });
              },
            ),
          ),

          // Divider (Optional: Ek patli line Close aur options ke beech)
          Container(height: 30, width: 1, color: Colors.white10, margin: const EdgeInsets.symmetric(horizontal: 4)),

          // --- 2. SCROLLABLE OPTIONS (Expanded taaki baki jagah le sake) ---
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              children: [
                // 1. Auto Fit
                _buildToolItem(
                  label: "Auto Fit",
                  icon: Icons.fit_screen_rounded,
                  tooltipMessage: "Auto fit to image size",
                  //onTap: () => showToast("Auto fit applied"),
                  isSelected: _selectedPageSize == "Auto Fit",
                  // 🚨 NAYA: Highlight hoga
                  onTap: () => setState(() => _selectedPageSize = "Auto Fit"),
                ),

                // 2. US Letter
                _buildToolItem(
                  label: "Letter (P)",
                  icon: Icons.crop_portrait_rounded,
                  tooltipMessage: "US Letter Portrait",
                  //onTap: () => showToast("US Letter Portrait applied"),
                  isSelected: _selectedPageSize == "Letter (P)",
                  onTap: () => setState(() => _selectedPageSize = "Letter (P)"),
                ),
                _buildToolItem(
                  label: "Letter (L)",
                  icon: Icons.crop_landscape_rounded,
                  tooltipMessage: "US Letter Landscape",
                  //onTap: () => showToast("US Letter Landscape applied"),
                  isSelected: _selectedPageSize == "Letter (L)",
                  onTap: () => setState(() => _selectedPageSize = "Letter (L)"),
                ),

                // 3. US Legal
                _buildToolItem(
                  label: "Legal (P)",
                  icon: Icons.crop_portrait_rounded,
                  tooltipMessage: "US Legal Portrait",
                  //onTap: () => showToast("US Legal Portrait applied"),
                  isSelected: _selectedPageSize == "Legal (P)",
                  onTap: () => setState(() => _selectedPageSize = "Legal (P)"),
                ),
                _buildToolItem(
                  label: "Legal (L)",
                  icon: Icons.crop_landscape_rounded,
                  tooltipMessage: "US Legal Landscape",
                  //onTap: () => showToast("US Legal Landscape applied"),
                  isSelected: _selectedPageSize == "Legal (L)",
                  onTap: () => setState(() => _selectedPageSize = "Legal (L)"),
                ),

                // 4. A4 Size
                _buildToolItem(
                  label: "A4 (P)",
                  icon: Icons.crop_portrait_rounded,
                  tooltipMessage: "A4 Portrait",
                  //onTap: () => showToast("A4 Portrait applied"),
                  isSelected: _selectedPageSize == "A4 (P)",
                  onTap: () => setState(() => _selectedPageSize = "A4 (P)"),
                ),
                _buildToolItem(
                  label: "A4 (L)",
                  icon: Icons.crop_landscape_rounded,
                  tooltipMessage: "A4 Landscape",
                  //onTap: () => showToast("A4 Landscape applied"),
                  isSelected: _selectedPageSize == "A4 (L)",
                  onTap: () => setState(() => _selectedPageSize = "A4 (L)"),
                ),

                // 5. A3 Size
                _buildToolItem(
                  label: "A3 (P)",
                  icon: Icons.crop_portrait_rounded,
                  tooltipMessage: "A3 Portrait",
                  //onTap: () => showToast("A3 Portrait applied"),
                  isSelected: _selectedPageSize == "A3 (P)",
                  onTap: () => setState(() => _selectedPageSize = "A3 (P)"),
                ),
                _buildToolItem(
                  label: "A3 (L)",
                  icon: Icons.crop_landscape_rounded,
                  tooltipMessage: "A3 Landscape",
                  //onTap: () => showToast("A3 Landscape applied"),
                  isSelected: _selectedPageSize == "A3 (L)",
                  onTap: () => setState(() => _selectedPageSize = "A3 (L)"),
                ),

                // 6. A5 Size
                _buildToolItem(
                  label: "A5 (P)",
                  icon: Icons.crop_portrait_rounded,
                  tooltipMessage: "A5 Portrait",
                  //onTap: () => showToast("A5 Portrait applied"),
                  isSelected: _selectedPageSize == "A5 (P)",
                  onTap: () => setState(() => _selectedPageSize = "A5 (P)"),
                ),
                _buildToolItem(
                  label: "A5 (L)",
                  icon: Icons.crop_landscape_rounded,
                  tooltipMessage: "A5 Landscape",
                  //onTap: () => showToast("A5 Landscape applied"),
                  isSelected: _selectedPageSize == "A5 (L)",
                  onTap: () => setState(() => _selectedPageSize = "A5 (L)"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  // 🚨 NAYA: Dynamic aspect ratio calculator
  double _getPageAspectRatio() {
    switch (_selectedPageSize) {
      case "Letter (P)": return 8.5 / 11.0;
      case "Letter (L)": return 11.0 / 8.5;
      case "Legal (P)": return 8.5 / 14.0;
      case "Legal (L)": return 14.0 / 8.5;
      case "A4 (P)": return 210 / 297;
      case "A4 (L)": return 297 / 210;
      case "A3 (P)": return 297 / 420;
      case "A3 (L)": return 420 / 297;
      case "A5 (P)": return 148 / 210;
      case "A5 (L)": return 210 / 148;
      case "4x6 Photo (P)": return 4.0 / 6.0;
      case "4x6 Photo (L)": return 6.0 / 4.0;
      case "Square (1:1)": return 1.0;
      case "Auto Fit":
        return 210 / 297; // NOTE: Auto-fit ka actual math (bounding box) hum baad me likhenge, abhi default A4 rakha hai
      default: return 210 / 297;
    }
  }



}