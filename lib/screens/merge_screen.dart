import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';

import 'custom_dialog.dart';

class MergeScreen extends StatefulWidget {
  //  Editor screen se selected files yahan receive karenge
  final List<File> selectedImages;

  const MergeScreen({Key? key, required this.selectedImages}) : super(key: key);

  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

// Photo ki saari state (position, size, rotation) store karne ke liye
class MergedImageState {
  File file;
  Offset position;
  double scale;
  double rotation;
  bool isHidden;
  bool isLocked;
  double opacity = 1.0;

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
  //Thumbnail selection (Last photo default select hogi)
  int? _selectedImageIndex;
  late List<MergedImageState> _imageStates;

  // Har image ki positions (X, Y) track karne ke liye
  late List<Offset> _imagePositions;

  bool isPageSizeMode = false;
  String _selectedPageSize = "A4 (P)"; // Default page size
  bool isPositionMode = false;
  bool isRotateMode = false;
  bool isSizeMode = false;
  bool isOpacityMode = false;
// State Variables
  bool isGridVisible = false; // Grid dikhane ke liye variable

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

    //Naye format me initialize karo
    _imageStates = List.generate(
      widget.selectedImages.length,
      (index) => MergedImageState(file: widget.selectedImages[index], position: Offset(20.0 * index, 20.0 * index)),
    );
  }

  // --- 🚨 NAYA: Exit Confirmation Handle Karne Ke Liye ---
  Future<bool> _onWillPop() async {
    // Tumhara custom dialog popup hoga
    bool confirm = await showCustomConfirmDialog(
      context,
      title: "Exit Editor?",
      message: "Are you sure you want to exit? Any unsaved changes will be lost.",
      positiveBtnText: "Exit",
      positiveBtnColor: Colors.redAccent,
    );

    return confirm; // Agar true aaya, toh screen band ho jayegi
  }

  @override
  Widget build(BuildContext context) {

   // return Scaffold(
    return PopScope(
      canPop: false,

      // 🚨 FIX: Yahan 'Object? result' add kiya gaya hai deprecation warning hatane ke liye
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }

        // Apni custom exit dialog call karo
        bool shouldExit = await _onWillPop();

        // Agar user ne 'Exit' (true) press kiya hai, tab screen ko manually band karo
        if (shouldExit && context.mounted) {
          Navigator.pop(context);
        }
      },
        child: Scaffold(
      backgroundColor: const Color(0xFF2C2C2C), // Dark theme
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
          //onPressed: () => Navigator.pop(context),
          onPressed: () async {
            // 🚨 NAYA: Cross icon dabane par pehle dialog khulega
            bool shouldExit = await _onWillPop();
            if (shouldExit && context.mounted) {
              Navigator.pop(context); // Agar user ne 'Exit' dabaya, tabhi pop hoga
            }
          },
        ),

        //centerTitle false kar diya taaki title left me aa jaye
        title: const Text(
          "Merge Pages",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: false,

        actions: [
          // Undo Button (Tick se pehle)
          IconButton(
            icon: const Icon(Icons.undo_rounded, color: Colors.white, size: 24),
            tooltip: "Undo",
            onPressed: () {
              // Undo logic baad me aayega
            },
          ),

          //  Redo Button (Undo ke theek baad)
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
          // Expanded(
          //   child: ClipRect(
          //     child: GestureDetector(
          //       onTap: () {
          //         setState(() {
          //           _closeAllSubTools(); // Sabhi sub-tools ek sath band
          //           _selectedImageIndex = null; // Image deselect kardo
          //         });
          //       },
          //       child: InteractiveViewer(
          //         minScale: 1.0,
          //         maxScale: 4.0,
          //         boundaryMargin: EdgeInsets.zero,
          //         child: Center(
          //           child: Padding(
          //             padding: const EdgeInsets.all(40.0),
          //             child: AspectRatio(
          //               aspectRatio: _getPageAspectRatio(),
          //               child: Container(
          //                 decoration: BoxDecoration(
          //                   color: Colors.white, // Paper Color
          //                   boxShadow: [
          //                     BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, spreadRadius: 2),
          //                   ],
          //                 ),
          //                 // PHOTO STACK WITH CONTROLS
          //                 child: Stack(
          //                   clipBehavior: Clip.none,
          //                     children: [ ...List.generate (_imageStates.length, (index) {
          //                     bool isSelected = _selectedImageIndex == index;
          //                     var imgState = _imageStates[index];
          //                     //  Agar image hidden hai, toh usko canvas par draw hi mat karo
          //                     if (imgState.isHidden) {
          //                       return const SizedBox.shrink(); // Empty space return karega
          //                     }
          //
          //                     double baseWidth = 150.0; // Initial fixed width
          //
          //                     return Positioned(
          //                       left: imgState.position.dx,
          //                       bottom: imgState.position.dy,
          //
          //                       child: Transform.rotate(
          //                         angle: imgState.rotation,
          //                         child: Stack(
          //                           clipBehavior: Clip.none,
          //                           children: [
          //                             // --- MAIN IMAGE CONTAINER ---
          //                             GestureDetector(
          //                               // Agar locked hai toh preview canvas par click ya drag puri tarah disable
          //                               onTap: imgState.isLocked
          //                                   ? null
          //                                   : () {
          //                                       setState(() {
          //                                         //_closeAllSubTools();
          //                                         _selectedImageIndex = index;
          //                                       });
          //                                     },
          //                               onPanUpdate: imgState.isLocked
          //                                   ? null
          //                                   : (details) {
          //                                       setState(() {
          //                                         //_closeAllSubTools();
          //                                         _selectedImageIndex = index;
          //                                         // Drag direction ko rotation ke hisaab se adjust karna
          //                                         double angle = imgState.rotation;
          //                                         double cosA = math.cos(angle);
          //                                         double sinA = math.sin(angle);
          //
          //                                         // Local rotated movement ko Real screen movement me convert kiya
          //                                         double adjustedDx = (details.delta.dx * cosA) - (details.delta.dy * sinA);
          //                                         double adjustedDy = (details.delta.dx * sinA) + (details.delta.dy * cosA);
          //
          //                                         // Ab hum adjusted value lagayenge
          //                                         _imageStates[index].position += Offset(adjustedDx, -adjustedDy);
          //                                       });
          //                                     },
          //                               // child: Transform.rotate(
          //                               //   angle: imgState.rotation,
          //                                 child: Container(
          //                                   width: baseWidth * imgState.scale,
          //                                   decoration: BoxDecoration(
          //                                     border: Border.all(
          //                                       //Agar locked hai, toh preview me KOI BORDER nahi aayega, chahe thumbnail se select kiya ho
          //                                       color: (isSelected && !imgState.isLocked)
          //                                           ? Colors.blueAccent
          //                                           : Colors.transparent,
          //                                       width: 2,
          //                                     ),
          //                                   ),
          //                                   // Image ko Opacity widget ke andar daala
          //                                   child: Opacity(
          //                                     opacity: imgState.opacity, // Yahan se value apply hogi
          //                                     child: Image.file(imgState.file, fit: BoxFit.contain),
          //                                   ),
          //                                 // ),
          //                               ),
          //                             ),
          //
          //                             // --- CORNER CONTROLS (Sirf tab dikhenge jab select ho) ---
          //                             if (isSelected && !imgState.isLocked) ...[
          //                               // 1. TOP-LEFT: DELETE ICON
          //                               Positioned(
          //                                 top: -12,
          //                                 left: -12,
          //                                 child: GestureDetector(
          //                                   onTap: () => setState(() {
          //                                     // Image hide kardo aur deselect kardo
          //                                     _imageStates[index].isHidden = true;
          //                                     _selectedImageIndex = null;
          //                                   }),
          //                                   child: Container(
          //                                     padding: const EdgeInsets.all(4),
          //                                     decoration: const BoxDecoration(
          //                                       color: Colors.redAccent,
          //                                       shape: BoxShape.circle,
          //                                     ),
          //                                     child: const Icon(
          //                                       Icons.visibility_off_rounded,
          //                                       color: Colors.white,
          //                                       size: 16,
          //                                     ),
          //                                   ),
          //                                 ),
          //                               ),
          //
          //                               // 2. TOP-RIGHT: SCALE ICON
          //                               Positioned(
          //                                 top: -12,
          //                                 right: -12,
          //                                 child: GestureDetector(
          //                                   onPanUpdate: (details) {
          //                                     setState(() {
          //                                       double sensitivity = 0.003;
          //                                       double scaleChange =
          //                                           (details.delta.dx - details.delta.dy) * sensitivity;
          //                                       _imageStates[index].scale = (_imageStates[index].scale + scaleChange)
          //                                           .clamp(0.2, 5.0);
          //                                     });
          //                                   },
          //                                   child: Container(
          //                                     padding: const EdgeInsets.all(4),
          //                                     decoration: const BoxDecoration(
          //                                       color: Colors.blueAccent,
          //                                       shape: BoxShape.circle,
          //                                     ),
          //                                     child: const Icon(
          //                                       Icons.open_in_full_rounded,
          //                                       color: Colors.white,
          //                                       size: 16,
          //                                     ),
          //                                   ),
          //                                 ),
          //                               ),
          //
          //                               // BOTTOM-RIGHT: ROTATE ICON
          //                               Positioned(
          //                                 bottom: -12,
          //                                 right: -12,
          //                                 child: GestureDetector(
          //                                   onPanUpdate: (details) {
          //                                     setState(() {
          //                                       _imageStates[index].rotation += details.delta.dx * 0.02;
          //                                     });
          //                                   },
          //                                   child: Container(
          //                                     padding: const EdgeInsets.all(4),
          //                                     decoration: const BoxDecoration(
          //                                       color: Colors.amber,
          //                                       shape: BoxShape.circle,
          //                                     ),
          //                                     child: const Icon(
          //                                       Icons.rotate_right_rounded,
          //                                       color: Colors.black,
          //                                       size: 16,
          //                                     ),
          //                                   ),
          //                                 ),
          //                               ),
          //                             ],
          //
          //
          //                           ],
          //                         ),
          //                       ),
          //                     );
          //                   }),
          //
          //                     // YAHAN RAKHNA HAI GRID KO
          //                     if (isGridVisible)
          //                         Positioned.fill(
          //                       child: IgnorePointer(
          //                       ignoring: true, // Yeh touch event ko block nahi karega
          //                         child: CustomPaint(
          //                           painter: GraphPaperPainter(),
          //                         ),
          //                       ),
          //                     ),
          //                     ]
          //                 ),
          //               ),
          //             ),
          //           ),
          //         ),
          //       ),
          //     ),
          //   ),
          // ),
          // ==========================================
          // 2. THUMBNAILS LIST
          // ==========================================

          Expanded(
            child: ClipRect(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _closeAllSubTools(); // Sabhi sub-tools ek sath band
                    _selectedImageIndex = null; // Image deselect kardo
                  });
                },
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  boundaryMargin: EdgeInsets.zero, // 🚨 NAYA: Isse page apni jagah par lock rahega, hilega nahi

                  // 🚨 FIX: LayoutBuilder ka use kiya taaki touch area poore screen tak fail jaye!
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // 1. Calculate Available Space (40px padding = 80px dono taraf se)
                      double availableW = constraints.maxWidth - 80;
                      double availableH = constraints.maxHeight - 80;
                      double ratio = _getPageAspectRatio();

                      // 2. Mathematically exact Paper Size nikalo (AspectRatio jaisa kaam)
                      double paperW = availableW;
                      double paperH = paperW / ratio;
                      if (paperH > availableH) {
                        paperH = availableH;
                        paperW = paperH * ratio;
                      }

                      // 3. Center me rakhne ke liye Offset nikalna (Taaki purani positioning kharab na ho)
                      double offsetX = (constraints.maxWidth - paperW) / 2;
                      double offsetY = (constraints.maxHeight - paperH) / 2;

                      return Container(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        color: Colors.transparent, // 🚨 MAGIC: Ab poori screen par touch detect hoga
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [

                            // --- LAYER 1: WHITE PAPER (Apni jagah par fixed) ---
                            if (_selectedPageSize != "Auto Fit")
                            Positioned(
                              left: offsetX,
                              bottom: offsetY,
                              width: paperW,
                              height: paperH,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, spreadRadius: 2),
                                  ],
                                ),
                              ),
                            ),

                            // --- LAYER 2: PHOTO STACK WITH CONTROLS ---
                            ...List.generate(_imageStates.length, (index) {
                              bool isSelected = _selectedImageIndex == index;
                              var imgState = _imageStates[index];

                              // Agar image hidden hai, toh usko canvas par draw hi mat karo
                              if (imgState.isHidden) {
                                return const SizedBox.shrink();
                              }

                              double baseWidth = 150.0;

                              return Positioned(
                                // 🚨 FIX: Purani position me offsetX aur offsetY add kar diya, taaki logic same rahe
                                left: offsetX + imgState.position.dx,
                                bottom: offsetY + imgState.position.dy,
                                child: Transform.rotate(
                                  angle: imgState.rotation,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      // --- MAIN IMAGE CONTAINER ---
                                      GestureDetector(
                                        onTap: imgState.isLocked
                                            ? null
                                            : () {
                                          setState(() {
                                            _selectedImageIndex = index;
                                          });
                                        },
                                        onPanUpdate: imgState.isLocked
                                            ? null
                                            : (details) {
                                          setState(() {
                                            _selectedImageIndex = index;

                                            double angle = imgState.rotation;
                                            double cosA = math.cos(angle);
                                            double sinA = math.sin(angle);

                                            double adjustedDx = (details.delta.dx * cosA) - (details.delta.dy * sinA);
                                            double adjustedDy = (details.delta.dx * sinA) + (details.delta.dy * cosA);

                                            _imageStates[index].position += Offset(adjustedDx, -adjustedDy);
                                          });
                                        },
                                        child: Container(
                                          width: baseWidth * imgState.scale,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: (isSelected && !imgState.isLocked)
                                                  ? Colors.blueAccent
                                                  : Colors.transparent,
                                              width: 2,
                                            ),
                                          ),
                                          child: Opacity(
                                            opacity: imgState.opacity,
                                            child: Image.file(imgState.file, fit: BoxFit.contain),
                                          ),
                                        ),
                                      ),

                                      // --- CORNER CONTROLS ---
                                      if (isSelected && !imgState.isLocked) ...[
                                        // 1. DELETE ICON
                                        Positioned(
                                          top: -12, left: -12,
                                          child: GestureDetector(
                                            onTap: () => _handleDeletePhoto(index),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                              child: const Icon(Icons.delete_rounded, color: Colors.white, size: 16),
                                            ),
                                          ),
                                        ),

                                        // 2. SCALE ICON
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

                                        // 3. ROTATE ICON
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

                            // --- LAYER 3: GRID LINES (Sabse upar, taaki paper par dikhe) ---
                            if (isGridVisible)
                              Positioned(
                                left: offsetX,
                                bottom: offsetY, // Grid ko bhi theek paper ke upar rakha
                                width: paperW,
                                height: paperH,
                                child: IgnorePointer(
                                  ignoring: true, // Yeh touch event ko block nahi karega
                                  child: CustomPaint(
                                    painter: GraphPaperPainter(),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
            GestureDetector(
            //Ye line ensure karegi ki khali space par bhi click kaam kare
            behavior: HitTestBehavior.opaque,
            onTap: () {
            setState(() {
            _closeAllSubTools(); // Khali space tap karte hi sub-tools close honge
            // Agar tum chahte ho ki khali space par click karne se image bhi deselect ho jaye,
            // toh niche wali line ka comment hata dena:
            // _selectedImageIndex = null;
            });
            },
            child: Container(
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
                      // Agar image hidden thi aur user ne uske thumbnail pe click kiya, toh use wapas unhide kardo
                      // if (_imageStates[index].isHidden) {
                      //   _imageStates[index].isHidden = false;
                      // }
                      //_closeAllSubTools();
                      _selectedImageIndex = index;
                    });
                  },
                  child: Container(
                    width: 60,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: isSelected ? Colors.blueAccent : Colors.transparent, width: 3),
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
                            child: Image.file(_imageStates[index].file, fit: BoxFit.cover),
                          ),
                          // Overlay Icon (Sirf tab dikhega jab hidden hogi)
                          if (isHidden)
                            Container(
                              color: Colors.black45, // Thoda dark shade photo ke upar
                              child: const Icon(Icons.visibility_off_rounded, color: Colors.white, size: 24),
                            ),

                          // Lock Icon (Agar photo locked hai)
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
                    offset: (isPageSizeMode || isPositionMode || isRotateMode || isSizeMode || isOpacityMode) ? const Offset(0, 1.0) : Offset.zero,
                    child: _buildNormalTools(), // Yahan function call ho gaya
                  ),

                  // --- B. TOP LAYER: RESIZE SUB-TOOLS (Animated Slide Up) ---
                  AnimatedSlide(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    offset: isPageSizeMode ? Offset.zero : const Offset(0, 1.0),
                    child: _buildPageSizeSubTools(),
                  ),

                  // --- C. POSITION SUB-TOOLS (Animated Slide Up) ---
                  AnimatedSlide(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    offset: isPositionMode ? Offset.zero : const Offset(0, 1.0),
                    child: _buildPositionSubTools(),
                  ),

                  // --- D. ROTATE SUB-TOOLS (Animated Slide Up) ---
                  AnimatedSlide(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    offset: isRotateMode ? Offset.zero : const Offset(0, 1.0),
                    child: _buildRotateSubTools(),
                  ),

                  // --- E. SIZE SUB-TOOLS (Animated Slide Up) ---
                  AnimatedSlide(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    offset: isSizeMode ? Offset.zero : const Offset(0, 1.0),
                    child: _buildSizeSubTools(),
                  ),

                  // --- F. OPACITY SUB-TOOLS (Animated Slide Up) ---
                  AnimatedSlide(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    offset: isOpacityMode ? Offset.zero : const Offset(0, 1.0),
                    child: _buildOpacitySubTools(),
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
              height: 50,
              // Standard banner ad ki height
              width: double.infinity,
              color: Colors.black,
              // Dark background Ad ke peeche
              alignment: Alignment.center,
              child: const Text("Banner Ad Space", style: TextStyle(color: Colors.white38, fontSize: 14)),
            ),
          ),
        ], // Column Children Ends
      ),
        ),// Column Ends
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
                  size: 22,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  //style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                  style: TextStyle(
                    // Disabled hone par text bhi dhundhla (grey) ho jayega
                    color: isDisabled ? Colors.white24 : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- MAIN NORMAL TOOLS ---
  Widget _buildNormalTools() {
    return Container(
      height: 75,
      width: double.infinity,
      color: const Color(0xFF151515),
      child: Row(
        children: [
          // 1. Lock/Unlock
          Padding(
            padding: const EdgeInsets.only(left: 4.0, right: 2.0),
            child: _buildToolItem(
              label: (_selectedImageIndex != null && _imageStates[_selectedImageIndex!].isLocked) ? "Unlock" : "Lock",
              icon: (_selectedImageIndex != null && _imageStates[_selectedImageIndex!].isLocked)
                  ? Icons.lock_open_rounded
                  : Icons.lock_outline_rounded,
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
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 0),
              children: [
                _buildToolItem(
                  label: "Page Size",
                  icon: Icons.aspect_ratio_rounded,
                  isDisabled: false,
                  onTap: () => setState(() => isPageSizeMode = true),
                ),
                _buildToolItem(
                  label: (_selectedImageIndex != null && _imageStates[_selectedImageIndex!].isHidden)
                      ? "Unhide"
                      : "Hide",
                  icon: (_selectedImageIndex != null && _imageStates[_selectedImageIndex!].isHidden)
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  isDisabled: _selectedImageIndex == null,
                  onTap: () {
                    if (_selectedImageIndex != null) {
                      setState(() {
                        _imageStates[_selectedImageIndex!].isHidden = !_imageStates[_selectedImageIndex!].isHidden;
                      });
                    }
                  },
                ),
                _buildToolItem(
                  label: "Position",
                  icon: Icons.control_camera_rounded,
                  isDisabled:
                      _selectedImageIndex == null ||
                      _imageStates[_selectedImageIndex!].isLocked ||
                      _imageStates[_selectedImageIndex!].isHidden,
                    onTap: () {
                      setState(() {
                        isPositionMode = true; // 🚨 ISKO TRUE KARNE SE ANIMATION TRIGGER HOGA
                      });
                    }
                ),
                _buildToolItem(
                  label: "Rotate",
                  icon: Icons.rotate_right_rounded,
                  isDisabled:
                      _selectedImageIndex == null ||
                      _imageStates[_selectedImageIndex!].isLocked ||
                      _imageStates[_selectedImageIndex!].isHidden,
                    onTap: () {
                      setState(() {
                        isRotateMode = true; // 🚨 ROTATE ANIMATION TRIGGER KAREGA
                        if (_selectedImageIndex != null) {
                          // 45 degrees = 0.785398 radians
                          //_imageStates[_selectedImageIndex!].rotation += 0.78539816;
                          //_imageStates[_selectedImageIndex!].rotation += 1.57079633;
                        }
                      });
                      // Click karte hi direct 45 degree right ghuma do

                    }
                ),
                _buildToolItem(
                  label: "Size",
                  icon: Icons.photo_size_select_large_rounded,
                  isDisabled:
                      _selectedImageIndex == null ||
                      _imageStates[_selectedImageIndex!].isLocked ||
                      _imageStates[_selectedImageIndex!].isHidden,
                    onTap: () {
                      setState(() {
                        isSizeMode = true; // 🚨 SIZE ANIMATION TRIGGER KAREGA
                      });
                    }
                ),
                _buildToolItem(
                  label: "Opacity",
                  icon: Icons.opacity_rounded,
                  isDisabled:
                      _selectedImageIndex == null ||
                      _imageStates[_selectedImageIndex!].isLocked ||
                      _imageStates[_selectedImageIndex!].isHidden,
                    onTap: () {
                      setState(() {
                        isOpacityMode = true; // 🚨 OPACITY ANIMATION TRIGGER KAREGA
                      });
                    }
                ),
                //_buildToolItem(label: "Collage", icon: Icons.auto_awesome_mosaic_rounded, isDisabled: false),
               // _buildToolItem(label: "Grid Line", icon: Icons.grid_on_rounded, isDisabled: false),
                _buildToolItem(
                    label: "Grid",
                    icon: isGridVisible ? Icons.grid_on_rounded : Icons.grid_off_rounded,
                    isSelected: isGridVisible, // ON hone par blue highlight hoga
                    onTap: () {
                      setState(() {
                        isGridVisible = !isGridVisible; // Grid ko toggle karega
                      });
                    }
                ),
                _buildToolItem(
                  label: "Delete",
                  icon: Icons.delete_outline_rounded,
                  isDisabled: _selectedImageIndex == null || _imageStates[_selectedImageIndex!].isLocked,
                  // onTap: () {
                  //   if (_selectedImageIndex != null && !_imageStates[_selectedImageIndex!].isLocked) {
                  //     setState(() {
                  //       _imageStates.removeAt(_selectedImageIndex!);
                  //       _selectedImageIndex = null;
                  //     });
                  //   }
                  // },
                  onTap: () {
                    if (_selectedImageIndex != null && !_imageStates[_selectedImageIndex!].isLocked) {
                      // 🚨 TUMHARA FUNCTION CALL HOGA
                      _handleDeletePhoto(_selectedImageIndex!);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- RESIZE SUB TOOLS (Fixed Close Button) ---
  Widget _buildPageSizeSubTools() {
    // Check karo ki custom size apply hua hai ya original 'Auto Fit' par hai
    //bool hasCustomSize = _selectedPageSize != "Auto Fit";
    bool isChanged = _selectedPageSize != "A4 (P)";

    return SizedBox(
      key: const ValueKey("ResizeSubTools"),
      height: 75,
      width: double.infinity,

      // Row ka use kiya taaki Close button fixed rahe
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: _buildToolItem(
              // Condition ke hisaab se label, icon aur tooltip change hoga
              label: isChanged ? "Done" : "Close",
              icon: isChanged ? Icons.check_rounded : Icons.close_rounded,
              tooltipMessage: isChanged ? "Apply changes" : "Close resize options",

              // isSelected true hote hi icon aur text automatically BLUE ho jayega!
              isSelected: isChanged,

              onTap: () {
                setState(() {
                  isPageSizeMode = false;
                  //isThumbnailVisible = true;
                });
              },
            ),
          ),

          // Divider (Optional: Ek patli line Close aur options ke beech)
          Container(height: 30, width: 1, color: Colors.white10, margin: const EdgeInsets.symmetric(horizontal: 4)),

          // --- SCROLLABLE OPTIONS (Expanded taaki baki jagah le sake) ---
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

  // --- POSITION SUB-TOOLS ---
  Widget _buildPositionSubTools() {
    return SizedBox(
      height: 75,
      width: double.infinity,
      child: Row(
        children: [
          // 1. Tick Button (Done)
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: _buildToolItem(
              label: "Done",
              icon: Icons.check_rounded,
              tooltipMessage: "Apply Position",
              isSelected: true,
              onTap: () {
                setState(() {
                  _closeAllSubTools();
                });
              },
            ),
          ),

          // Divider
          Container(height: 30, width: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 4)),

          // 2. Direction Buttons (Expanded taaki evenly space le sake)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildToolItem(
                    label: "Up",
                    icon: Icons.arrow_upward_rounded,
                    isDisabled: _selectedImageIndex == null,
                    onTap: () {
                      if (_selectedImageIndex != null) {
                        setState(() {
                          // 🚨 bottom offset +5 karne se image upar jayegi
                          _imageStates[_selectedImageIndex!].position += const Offset(0, 5);
                        });
                      }
                    }
                ),
                _buildToolItem(
                    label: "Down",
                    icon: Icons.arrow_downward_rounded,
                    isDisabled: _selectedImageIndex == null,
                    onTap: () {
                      if (_selectedImageIndex != null) {
                        setState(() {
                          // 🚨 bottom offset -5 karne se image niche jayegi
                          _imageStates[_selectedImageIndex!].position += const Offset(0, -5);
                        });
                      }
                    }
                ),
                _buildToolItem(
                    label: "Left",
                    icon: Icons.arrow_back_rounded,
                    isDisabled: _selectedImageIndex == null,
                    onTap: () {
                      if (_selectedImageIndex != null) {
                        setState(() {
                          // 🚨 left offset -5 karne se image left jayegi
                          _imageStates[_selectedImageIndex!].position += const Offset(-5, 0);
                        });
                      }
                    }
                ),
                _buildToolItem(
                    label: "Right",
                    icon: Icons.arrow_forward_rounded,
                    isDisabled: _selectedImageIndex == null,
                    onTap: () {
                      if (_selectedImageIndex != null) {
                        setState(() {
                          //  left offset +5 karne se image right jayegi
                          _imageStates[_selectedImageIndex!].position += const Offset(5, 0);
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

  // --- ROTATE SUB-TOOLS ---
  Widget _buildRotateSubTools() {
    // Slider ke liye current rotation ko 0 se 360 degree (0 se 2*Pi Radians) me normalize karna zaroori hai
    double currentRotation = 0.0;
    if (_selectedImageIndex != null) {
      currentRotation = _imageStates[_selectedImageIndex!].rotation % (2 * 3.14159265);
      if (currentRotation < 0) currentRotation += (2 * 3.14159265);
    }

    return Container(
      height: 75,
      width: double.infinity,
      child: Row(
        children: [
          //Tick Button (Done)
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: _buildToolItem(
              label: "Done",
              icon: Icons.check_rounded,
              tooltipMessage: "Apply Rotation",
              isSelected: true,
              onTap: () {
                setState(() {
                  _closeAllSubTools();
                });
              },
            ),
          ),

          Container(height: 30, width: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 0)),

          //Rotate Left (-90 degrees)
          _buildToolItem(
              label: "Left",
              icon: Icons.rotate_left_rounded,
              isDisabled: _selectedImageIndex == null,
              onTap: () {
                if (_selectedImageIndex != null) {
                  setState(() {
                    _imageStates[_selectedImageIndex!].rotation -= 0.78539816;
                  });
                }
              }
          ),

          //Rotate Right (+90 degrees)
          _buildToolItem(
              label: "Right",
              icon: Icons.rotate_right_rounded,
              isDisabled: _selectedImageIndex == null,
              onTap: () {
                if (_selectedImageIndex != null) {
                  setState(() {
                    _imageStates[_selectedImageIndex!].rotation += 0.78539816;
                  });
                }
              }
          ),

          //Slider for Fine Degree Adjustment
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 0.0, left: 0.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    // Current angle ko wapas degree me convert karke dikhane ke liye
                      "Angle: ${(currentRotation * (180 / 3.14159265)).toStringAsFixed(0)}°",
                      style: const TextStyle(color: Colors.white70, fontSize: 11)
                  ),
                  SizedBox(
                    height: 24, // Slider ki height kam ki taaki fit ho jaye
                    child: Slider(
                      value: currentRotation,
                      min: 0.0,
                      max: 2 * 3.14159265, // 360 degrees
                      activeColor: Colors.blueAccent,
                      inactiveColor: Colors.white24,
                      onChanged: _selectedImageIndex == null ? null : (value) {
                        setState(() {
                          // Direct slider ki value lagao
                          _imageStates[_selectedImageIndex!].rotation = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

// --- PERFECT SIZE SUB-TOOLS ---
  // --- MULTI-DOT PREMIUM SIZE SUB-TOOLS ---
  Widget _buildSizeSubTools() {
    double currentScale = 1.0;
    if (_selectedImageIndex != null) {
      currentScale = _imageStates[_selectedImageIndex!].scale;
    }

    bool isChanged = currentScale != 1.0;

    //Jin values par dot aur magnet (snap) chahiye unki list
    final List<double> snapValues = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0];

    return Container(
      height: 75,
      width: double.infinity,
      child: Row(
        children: [
          // Dynamic Tick/Close Button
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: _buildToolItem(
              label: isChanged ? "Done" : "Close",
              icon: isChanged ? Icons.check_rounded : Icons.close_rounded,
              tooltipMessage: isChanged ? "Apply Size" : "Close Tool",
              isSelected: isChanged,
              onTap: () {
                setState(() {
                  _closeAllSubTools();
                });
              },
            ),
          ),

          Container(height: 30, width: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 4)),

          // Slider with Multiple Dots and Snapping
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0, left: 8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                      "Scale: ${currentScale.toStringAsFixed(2)}x",
                      style: const TextStyle(color: Colors.white70, fontSize: 11)
                  ),
                  SizedBox(
                    height: 30,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const double overlayRadius = 16.0;
                        double trackWidth = constraints.maxWidth - (overlayRadius * 2);

                        // Slider ki nayi range: 0.0 se 5.0 tak
                        double minVal = 0.0;
                        double maxVal = 5.0;

                        return Stack(
                          alignment: Alignment.centerLeft,
                          children: [

                            // --- BACKGROUND SLIDER ---
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4.0,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: overlayRadius),
                              ),
                              child: Slider(
                                value: currentScale,
                                min: minVal,
                                max: maxVal,
                                activeColor: Colors.blueAccent,
                                inactiveColor: Colors.white24,
                                onChanged: _selectedImageIndex == null ? null : (value) {
                                  double newVal = value;
                                  bool snapped = false;

                                  // MULTI-SNAP LOGIC
                                  for (double snap in snapValues) {
                                    // Scale badi range hai, isliye gap 0.15 rakha hai
                                    if ((newVal - snap).abs() < 0.15) {
                                      newVal = snap;
                                      snapped = true;
                                      break;
                                    }
                                  }

                                  //VIBRATION LOGIC
                                  if (snapped && _imageStates[_selectedImageIndex!].scale != newVal) {
                                    HapticFeedback.lightImpact();
                                  }

                                  setState(() {
                                    _imageStates[_selectedImageIndex!].scale = newVal;
                                  });
                                },
                              ),
                            ),

                            // ---MULTIPLE DOT MARKERS (Loop se) ---
                            ...snapValues.map((val) {
                              double percentage = (val - minVal) / (maxVal - minVal);
                              double dotPosition = overlayRadius + (trackWidth * percentage);

                              // Thumb jab kisi dot ke paas ho toh usko hide kardo
                              bool showDot = (currentScale - val).abs() > 0.15;

                              if (!showDot) return const SizedBox.shrink();

                              return Positioned(
                                left: dotPosition - 3,
                                child: IgnorePointer(
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      // 1x (Original Size) wala dot blue dikhega, baaki safed
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              );
                            }),

                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- MULTI-DOT PREMIUM OPACITY SUB-TOOLS ---
  Widget _buildOpacitySubTools() {
    double currentOpacity = 1.0;
    if (_selectedImageIndex != null) {
      currentOpacity = _imageStates[_selectedImageIndex!].opacity;
    }

    bool isChanged = currentOpacity != 1.0;

    //Jin values par dot aur magnet (snap) chahiye unki list
    final List<double> snapValues = [0.0, 0.25, 0.50, 0.75, 1.0];

    return Container(
      height: 75,
      width: double.infinity,
      child: Row(
        children: [
          //Dynamic Tick/Close Button
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: _buildToolItem(
              label: isChanged ? "Done" : "Close",
              icon: isChanged ? Icons.check_rounded : Icons.close_rounded,
              tooltipMessage: isChanged ? "Apply Opacity" : "Close Tool",
              isSelected: isChanged,
              onTap: () {
                setState(() {
                  _closeAllSubTools();
                });
              },
            ),
          ),

          Container(height: 30, width: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 4)),

          // Slider with Multiple Dots and Snapping
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0, left: 8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                      "Opacity: ${(currentOpacity * 100).toInt()}%",
                      style: const TextStyle(color: Colors.white70, fontSize: 11)
                  ),
                  SizedBox(
                    height: 30,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const double overlayRadius = 16.0;
                        double trackWidth = constraints.maxWidth - (overlayRadius * 2);

                        double minVal = 0.0;
                        double maxVal = 1.0;

                        return Stack(
                          alignment: Alignment.centerLeft,
                          children: [

                            // --- BACKGROUND SLIDER ---
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4.0,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: overlayRadius),
                              ),
                              child: Slider(
                                value: currentOpacity,
                                min: minVal,
                                max: maxVal,
                                activeColor: Colors.blueAccent,
                                inactiveColor: Colors.white24,
                                onChanged: _selectedImageIndex == null ? null : (value) {
                                  double newVal = value;
                                  bool snapped = false;

                                  // MULTI-SNAP LOGIC: Har dot ke paas magnet effect
                                  for (double snap in snapValues) {
                                    // Agar slider snap value ke +/- 4% range me hai
                                    if ((newVal - snap).abs() < 0.04) {
                                      newVal = snap;
                                      snapped = true;
                                      break;
                                    }
                                  }

                                  // VIBRATION LOGIC: Agar naye dot par snap hua
                                  if (snapped && _imageStates[_selectedImageIndex!].opacity != newVal) {
                                    HapticFeedback.lightImpact();
                                  }

                                  setState(() {
                                    _imageStates[_selectedImageIndex!].opacity = newVal;
                                  });
                                },
                              ),
                            ),

                            // --- MULTIPLE DOT MARKERS (Loop se banaye gaye) ---
                            ...snapValues.map((val) {
                              double percentage = (val - minVal) / (maxVal - minVal);
                              double dotPosition = overlayRadius + (trackWidth * percentage);

                              // Jab thumb kisi bhi dot ke paas ho, sirf us dot ko hide kar do
                              bool showDot = (currentOpacity - val).abs() > 0.04;

                              if (!showDot) return const SizedBox.shrink();

                              return Positioned(
                                left: dotPosition - 3,
                                child: IgnorePointer(
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              );
                            }),

                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Universal Sub-tool closer function
  void _closeAllSubTools() {
    isPageSizeMode = false;
    isSizeMode = false;
    // Future ke liye jab tum naye tools add karoge:
    isPositionMode = false;
    isRotateMode = false;
    isOpacityMode = false;
    // isCollageMode = false;
    // isLayerMode = false;
  }

  // --- 🚨 NAYA: Delete handle karne ka async function ---
  void _handleDeletePhoto(int index) async {
    // Tumhara custom dialog call kiya
    bool confirm = await showCustomConfirmDialog(
      context,
      title: "Delete Photo?",
      message: "Are you sure you want to remove this photo from the canvas? This action cannot be undone.",
      positiveBtnText: "Delete",
      positiveBtnColor: Colors.redAccent, // Delete ke liye red color
    );

    // Agar user ne 'Delete' (true) press kiya hai, tabhi state update hogi
    if (confirm) {
      setState(() {
        _imageStates.removeAt(index);
        _selectedImageIndex = null;
      });
      HapticFeedback.mediumImpact(); // Delete hone par vibration
    }
  }

  // Dynamic aspect ratio calculator
  double _getPageAspectRatio() {
    switch (_selectedPageSize) {
      case "Letter (P)":
        return 8.5 / 11.0;
      case "Letter (L)":
        return 11.0 / 8.5;
      case "Legal (P)":
        return 8.5 / 14.0;
      case "Legal (L)":
        return 14.0 / 8.5;
      case "A4 (P)":
        return 210 / 297;
      case "A4 (L)":
        return 297 / 210;
      case "A3 (P)":
        return 297 / 420;
      case "A3 (L)":
        return 420 / 297;
      case "A5 (P)":
        return 148 / 210;
      case "A5 (L)":
        return 210 / 148;
      case "4x6 Photo (P)":
        return 4.0 / 6.0;
      case "4x6 Photo (L)":
        return 6.0 / 4.0;
      case "Square (1:1)":
        return 1.0;
      case "Auto Fit":
        return 210 /
            297; // NOTE: Auto-fit ka actual math (bounding box) hum baad me likhenge, abhi default A4 rakha hai
      default:
        return 210 / 297;
    }
  }
}

// --- NAYA: GRAPH PAPER PAINTER CLASS ---
class GraphPaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black12 // Ekdum halki premium lines
      ..strokeWidth = 1.0; // Patli lines

    const double step = 25.0; // Graph paper ke dabbo ka size (25px)

    // 1. Vertical Lines (Khadi lines)
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // 2. Horizontal Lines (Aadi lines)
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}