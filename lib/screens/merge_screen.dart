import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'custom_dialog.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

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
  final GlobalKey imageKey = GlobalKey();

  MergedImageState({
    required this.file,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.isHidden = false,
    this.isLocked = false,
  });

  // Undo/Redo ke liye state ki Deep Copy banane ka function
  MergedImageState clone() {
    return MergedImageState(
      file: file,
      position: Offset(position.dx, position.dy),
      scale: scale,
      rotation: rotation,
      isHidden: isHidden,
      isLocked: isLocked,
    )..opacity = opacity;
  }
}

// CLASS: Yeh canvas ka poora snapshot save karega
class EditorSnapshot {
  final List<MergedImageState> imageStates;
  final String pageSize;
  final int? selectedIndex;

  EditorSnapshot({required this.imageStates, required this.pageSize, this.selectedIndex});
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
  bool isLayerMode = false;
  int? _initialLayerIndex;

  // --- 🚨 UNDO / REDO VARIABLES ---
  List<EditorSnapshot> _undoHistory = [];
  List<EditorSnapshot> _redoHistory = [];

  final GlobalKey _canvasKey = GlobalKey();
  final GlobalKey _paperKey = GlobalKey();

  // TODO 🚨 TEST ID (Play Console ke time real ID laga dena)
  final String _adUnitId = 'ca-app-pub-3940256099942544/1033173712';

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

  // --- Exit Confirmation Handle Karne Ke Liye ---
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

  // ---  1. STATE SAVE FUNCTION (Action hone se theek pehle call hoga) ---
  void _saveStateToHistory() {
    _undoHistory.add(
      EditorSnapshot(
        // .map().clone() karna zaroori hai taaki original list modify na ho
        imageStates: _imageStates.map((e) => e.clone()).toList(),
        pageSize: _selectedPageSize,
        selectedIndex: _selectedImageIndex,
      ),
    );
    // Naya action hone par aage ki Redo history bekaar ho jati hai, so clear it
    _redoHistory.clear();
  }

  // ---  2. UNDO FUNCTION ---
  void _undo() {
    if (_undoHistory.isEmpty) return; // Agar history khali hai toh kuch mat karo
    setState(() {
      // Current state ko pehle Redo me daal do
      _redoHistory.add(
        EditorSnapshot(
          imageStates: _imageStates.map((e) => e.clone()).toList(),
          pageSize: _selectedPageSize,
          selectedIndex: _selectedImageIndex,
        ),
      );

      // Undo list se last state nikalo aur Canvas par apply kardo
      EditorSnapshot prevState = _undoHistory.removeLast();
      _imageStates = prevState.imageStates.map((e) => e.clone()).toList();
      _selectedPageSize = prevState.pageSize;
      _selectedImageIndex = prevState.selectedIndex;
    });
    HapticFeedback.mediumImpact();
  }

  // --- 🚨 3. REDO FUNCTION ---
  void _redo() {
    if (_redoHistory.isEmpty) return;
    setState(() {
      // Current state ko Undo me daal do
      _undoHistory.add(
        EditorSnapshot(
          imageStates: _imageStates.map((e) => e.clone()).toList(),
          pageSize: _selectedPageSize,
          selectedIndex: _selectedImageIndex,
        ),
      );

      // Redo list se next state nikalo aur Canvas par apply kardo
      EditorSnapshot nextState = _redoHistory.removeLast();
      _imageStates = nextState.imageStates.map((e) => e.clone()).toList();
      _selectedPageSize = nextState.pageSize;
      _selectedImageIndex = nextState.selectedIndex;
    });
    HapticFeedback.mediumImpact();
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
            // UPDATED: Undo Button
            IconButton(
              // Agar history hai tabhi white dikhega, warna grey (white24)
              icon: Icon(Icons.undo_rounded, color: _undoHistory.isNotEmpty ? Colors.white : Colors.white24, size: 24),
              tooltip: "Undo",
              onPressed: _undoHistory.isNotEmpty ? _undo : null,
            ),

            // UPDATED: Redo Button
            IconButton(
              icon: Icon(Icons.redo_rounded, color: _redoHistory.isNotEmpty ? Colors.white : Colors.white24, size: 24),
              tooltip: "Redo",
              onPressed: _redoHistory.isNotEmpty ? _redo : null,
            ),

            IconButton(
              icon: const Icon(Icons.check_rounded, color: Colors.blueAccent, size: 28),
              tooltip: "Save",
              onPressed: () {
                //Navigator.pop(context);
                _saveAndExport();
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
                  onTap: () {
                    setState(() {
                      _closeAllSubTools(); // Sabhi sub-tools ek sath band
                      _selectedImageIndex = null; // Image deselect kardo
                    });
                  },
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    boundaryMargin: EdgeInsets.zero,

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
                          color: Colors.transparent,
                          child: RepaintBoundary(
                            // 🚨 NAYA WRAP
                            key: _canvasKey,
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
                                      key: _paperKey,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.5),
                                            blurRadius: 10,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                // --- LAYER 2: PHOTO STACK WITH CONTROLS ---
                                ...List.generate(_imageStates.length, (index) {
                                  bool isSelected = _selectedImageIndex == index;
                                  var imgState = _imageStates[index];
                                  if (imgState.isHidden) {
                                    return const SizedBox.shrink();
                                  }

                                  double baseWidth = 150.0;
                                  bool isAutoFit = _selectedPageSize == "Auto Fit";

                                  // 🟩 1. AGAR SELECTED NAHI HAI YA LOCKED HAI (Normal render, No border)
                                  if (!isSelected || imgState.isLocked) {
                                    return Positioned(
                                      left: offsetX + imgState.position.dx,
                                      bottom: offsetY + imgState.position.dy,
                                      child: Transform.rotate(
                                        angle: imgState.rotation,
                                        child: GestureDetector(
                                          onTap: imgState.isLocked
                                              ? null
                                              : () {
                                                  setState(() => _selectedImageIndex = index);
                                                },
                                          onPanStart: imgState.isLocked ? null : (details) => _saveStateToHistory(),
                                          onPanUpdate: imgState.isLocked
                                              ? null
                                              : (details) {
                                                  setState(() {
                                                    _selectedImageIndex = index;
                                                    double angle = imgState.rotation;
                                                    double cosA = math.cos(angle);
                                                    double sinA = math.sin(angle);
                                                    double adjustedDx =
                                                        (details.delta.dx * cosA) - (details.delta.dy * sinA);
                                                    double adjustedDy =
                                                        (details.delta.dx * sinA) + (details.delta.dy * cosA);
                                                    _imageStates[index].position += Offset(adjustedDx, -adjustedDy);
                                                  });
                                                },
                                          child: Container(
                                            key: imgState.imageKey,
                                            width: baseWidth * imgState.scale,
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Colors.transparent, width: 2),
                                            ),
                                            child: Opacity(
                                              opacity: imgState.opacity,
                                              child: Image.file(imgState.file, fit: BoxFit.contain),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  // 🚨 2. AGAR SELECTED HAI (Dual-Border Magic Trick)
                                  return Positioned.fill(
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        // 🔴 LAYER A: UNCLIPPED (Main Image + Red Border)
                                        Positioned(
                                          left: offsetX + imgState.position.dx,
                                          bottom: offsetY + imgState.position.dy,
                                          child: Transform.rotate(
                                            angle: imgState.rotation,
                                            child: GestureDetector(
                                              onTap: () => setState(() => _selectedImageIndex = index),
                                              onPanStart: (details) => _saveStateToHistory(), // Undo Save
                                              onPanUpdate: (details) {
                                                setState(() {
                                                  _selectedImageIndex = index;
                                                  double angle = imgState.rotation;
                                                  double cosA = math.cos(angle);
                                                  double sinA = math.sin(angle);
                                                  double adjustedDx =
                                                      (details.delta.dx * cosA) - (details.delta.dy * sinA);
                                                  double adjustedDy =
                                                      (details.delta.dx * sinA) + (details.delta.dy * cosA);
                                                  _imageStates[index].position += Offset(adjustedDx, -adjustedDy);
                                                });
                                              },
                                              child: Container(
                                                key: imgState.imageKey,
                                                width: baseWidth * imgState.scale,
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color: isAutoFit ? Colors.blueAccent : Colors.redAccent,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: Opacity(
                                                  opacity: imgState.opacity,
                                                  child: Image.file(imgState.file, fit: BoxFit.contain),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                        // 🔵 LAYER B: CLIPPED TO PAGE (Blue Border)
                                        if (!isAutoFit)
                                          Positioned(
                                            left: offsetX,
                                            bottom: offsetY,
                                            width: paperW,
                                            height: paperH,
                                            child: IgnorePointer(
                                              ignoring: true, // Taps ko block nahi karega
                                              child: ClipRect(
                                                child: Stack(
                                                  clipBehavior: Clip.none,
                                                  children: [
                                                    Positioned(
                                                      left: imgState.position.dx,
                                                      bottom: imgState.position.dy,
                                                      child: Transform.rotate(
                                                        angle: imgState.rotation,
                                                        child: Container(
                                                          width: baseWidth * imgState.scale,
                                                          decoration: BoxDecoration(
                                                            border: Border.all(color: Colors.blueAccent, width: 2),
                                                          ),
                                                          // MAGIC: Image invisible
                                                          child: Opacity(
                                                            opacity: 0.0,
                                                            child: Image.file(imgState.file, fit: BoxFit.contain),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),

                                        // 🟡 LAYER C: CORNER ICONS
                                        Positioned(
                                          left: offsetX + imgState.position.dx,
                                          bottom: offsetY + imgState.position.dy,
                                          child: Transform.rotate(
                                            angle: imgState.rotation,
                                            child: Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                // 🚨 FINAL FIX: Invisible image ko IgnorePointer me wrap kiya!
                                                // Isse tumhara drag touch sidha main image par lagega.
                                                IgnorePointer(
                                                  child: SizedBox(
                                                    width: baseWidth * imgState.scale,
                                                    child: Opacity(
                                                      opacity: 0.0,
                                                      child: Image.file(imgState.file, fit: BoxFit.contain),
                                                    ),
                                                  ),
                                                ),

                                                // --- CORNER CONTROLS ---
                                                // 1. TOP-LEFT: HIDE ICON
                                                Positioned(
                                                  top: -12,
                                                  left: -12,
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      _saveStateToHistory();
                                                      setState(() {
                                                        _imageStates[index].isHidden = true;
                                                        _selectedImageIndex = null;
                                                      });
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets.all(4),
                                                      decoration: const BoxDecoration(
                                                        color: Colors.redAccent,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons.visibility_off_rounded,
                                                        color: Colors.white,
                                                        size: 16,
                                                      ),
                                                    ),
                                                  ),
                                                ),

                                                // 2. SCALE ICON
                                                Positioned(
                                                  top: -12,
                                                  right: -12,
                                                  child: GestureDetector(
                                                    onPanStart: (details) => _saveStateToHistory(),
                                                    onPanUpdate: (details) {
                                                      setState(() {
                                                        double sensitivity = 0.003;
                                                        double scaleChange =
                                                            (details.delta.dx - details.delta.dy) * sensitivity;
                                                        _imageStates[index].scale =
                                                            (_imageStates[index].scale + scaleChange).clamp(0.2, 5.0);
                                                      });
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets.all(4),
                                                      decoration: const BoxDecoration(
                                                        color: Colors.blueAccent,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons.open_in_full_rounded,
                                                        color: Colors.white,
                                                        size: 16,
                                                      ),
                                                    ),
                                                  ),
                                                ),

                                                // 3. ROTATE ICON
                                                Positioned(
                                                  bottom: -12,
                                                  right: -12,
                                                  child: GestureDetector(
                                                    onPanStart: (details) => _saveStateToHistory(),
                                                    onPanUpdate: (details) {
                                                      setState(() {
                                                        _imageStates[index].rotation += details.delta.dx * 0.02;
                                                      });
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets.all(4),
                                                      decoration: const BoxDecoration(
                                                        color: Colors.amber,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons.rotate_right_rounded,
                                                        color: Colors.black,
                                                        size: 16,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),

                                // --- LAYER 3: GRID LINES (Sabse upar, taaki paper par dikhe) ---
                                if (isGridVisible)
                                  Positioned(
                                    left: offsetX,
                                    bottom: offsetY,
                                    width: paperW,
                                    height: paperH,
                                    child: IgnorePointer(
                                      ignoring: true,
                                      child: CustomPaint(painter: GraphPaperPainter()),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            // ==========================================
            // 2. THUMBNAILS LIST
            // ==========================================
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _closeAllSubTools();
                });
              },
              child: Container(
                height: 90,
                color: const Color(0xFF1E1E1E),

                //  ListView.builder ki jagah ReorderableListView.builder lagaya
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imageStates.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),

                  onReorderStart: (int index) {
                    _saveStateToHistory();
                    HapticFeedback.mediumImpact(); // "Uthane" ka solid feel
                  },

                  // Hold and Drag karke re-arrange karne ka logic
                  onReorder: (int oldIndex, int newIndex) {
                    setState(() {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      // Photo layer change karo
                      final MergedImageState item = _imageStates.removeAt(oldIndex);
                      _imageStates.insert(newIndex, item);

                      // Selected photo ka border gayab na ho, isliye uski position bhi update ki
                      if (_selectedImageIndex == oldIndex) {
                        _selectedImageIndex = newIndex;
                      } else if (_selectedImageIndex != null) {
                        if (_selectedImageIndex! > oldIndex && _selectedImageIndex! <= newIndex) {
                          _selectedImageIndex = _selectedImageIndex! - 1;
                        } else if (_selectedImageIndex! < oldIndex && _selectedImageIndex! >= newIndex) {
                          _selectedImageIndex = _selectedImageIndex! + 1;
                        }
                      }
                    });
                    HapticFeedback.lightImpact(); // Drag karne par vibration
                  },

                  // Hawa me drag hote waqt premium UI (transparent background)
                  proxyDecorator: (Widget child, int index, Animation<double> animation) {
                    return Material(
                      color: Colors.transparent,
                      elevation: 10,
                      shadowColor: Colors.black54,
                      child: child,
                    );
                  },

                  itemBuilder: (context, index) {
                    bool isSelected = _selectedImageIndex == index;
                    bool isHidden = _imageStates[index].isHidden; // Check if hidden

                    return GestureDetector(
                      // Reorderable items ko pehchanne ke liye Key zaroori hoti hai
                      key: ObjectKey(_imageStates[index]),

                      onTap: () {
                        setState(() {
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
                      offset:
                          (isPageSizeMode ||
                              isPositionMode ||
                              isRotateMode ||
                              isSizeMode ||
                              isOpacityMode ||
                              isLayerMode)
                          ? const Offset(0, 1.0)
                          : Offset.zero,
                      child: _buildNormalTools(),
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

                    // --- G. LAYER SUB-TOOLS (Animated Slide Up) ---
                    AnimatedSlide(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      offset: isLayerMode ? Offset.zero : const Offset(0, 1.0),
                      child: _buildLayerSubTools(),
                    ),
                  ],
                ),
              ),
            ),

            // ==========================================
            // 4. BOTTOM BANNER AD PLACEHOLDER
            // ==========================================
            const CustomBannerAd(),
          ], // Column Children Ends
        ),
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
    return Tooltip(
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
                Icon(
                  icon,
                  // Disabled hone par icon dhundhla (grey) ho jayega
                  color: isDisabled ? Colors.white24 : Colors.white,
                  size: 22,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
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
                  label: "Layer",
                  icon: Icons.layers_rounded,
                  isDisabled:
                      _selectedImageIndex == null ||
                      _imageStates[_selectedImageIndex!].isLocked ||
                      _imageStates[_selectedImageIndex!].isHidden,
                  onTap: () {
                    setState(() {
                      isLayerMode = true;
                      _initialLayerIndex = _selectedImageIndex;
                    });
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
                      isPositionMode = true;
                    });
                  },
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
                      if (_selectedImageIndex != null) {}
                    });
                  },
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
                      isSizeMode = true;
                    });
                  },
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
                  },
                ),
                _buildToolItem(
                  label: "Grid",
                  icon: isGridVisible ? Icons.grid_on_rounded : Icons.grid_off_rounded,
                  isSelected: isGridVisible,
                  onTap: () {
                    setState(() {
                      isGridVisible = !isGridVisible;
                    });
                  },
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
                  label: "Delete",
                  icon: Icons.delete_outline_rounded,
                  isDisabled: _selectedImageIndex == null || _imageStates[_selectedImageIndex!].isLocked,
                  onTap: () {
                    if (_selectedImageIndex != null && !_imageStates[_selectedImageIndex!].isLocked) {
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

          Container(height: 30, width: 1, color: Colors.white10, margin: const EdgeInsets.symmetric(horizontal: 4)),

          // --- SCROLLABLE OPTIONS (Expanded taaki baki jagah le sake) ---
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              children: [
                _buildToolItem(
                  label: "Auto Fit",
                  icon: Icons.fit_screen_rounded,
                  tooltipMessage: "Auto fit to image size",
                  isSelected: _selectedPageSize == "Auto Fit",
                  onTap: () {
                    _saveStateToHistory();
                    setState(() => _selectedPageSize = "Auto Fit");
                  },
                ),

                _buildToolItem(
                  label: "A4 (P)",
                  icon: Icons.crop_portrait_rounded,
                  tooltipMessage: "A4 Portrait",
                  isSelected: _selectedPageSize == "A4 (P)",
                  onTap: () {
                    _saveStateToHistory();
                    setState(() => _selectedPageSize = "A4 (P)");
                  },
                ),
                _buildToolItem(
                  label: "A4 (L)",
                  icon: Icons.crop_landscape_rounded,
                  tooltipMessage: "A4 Landscape",
                  isSelected: _selectedPageSize == "A4 (L)",
                  onTap: () {
                    _saveStateToHistory();
                    setState(() => _selectedPageSize = "A4 (L)");
                  },
                ),

                _buildToolItem(
                  label: "Letter (P)",
                  icon: Icons.crop_portrait_rounded,
                  tooltipMessage: "US Letter Portrait",
                  isSelected: _selectedPageSize == "Letter (P)",
                  onTap: () {
                    _saveStateToHistory();
                    setState(() => _selectedPageSize = "Letter (P)");
                  },
                ),
                _buildToolItem(
                  label: "Letter (L)",
                  icon: Icons.crop_landscape_rounded,
                  tooltipMessage: "US Letter Landscape",
                  isSelected: _selectedPageSize == "Letter (L)",
                  onTap: () {
                    _saveStateToHistory();
                    setState(() => _selectedPageSize = "Letter (L)");
                  },
                ),

                _buildToolItem(
                  label: "Legal (P)",
                  icon: Icons.crop_portrait_rounded,
                  tooltipMessage: "US Legal Portrait",
                  isSelected: _selectedPageSize == "Legal (P)",
                  onTap: () {
                    _saveStateToHistory();
                    setState(() => _selectedPageSize = "Legal (P)");
                  },
                ),
                _buildToolItem(
                  label: "Legal (L)",
                  icon: Icons.crop_landscape_rounded,
                  tooltipMessage: "US Legal Landscape",
                  isSelected: _selectedPageSize == "Legal (L)",
                  onTap: () {
                    _saveStateToHistory();
                    setState(() => _selectedPageSize = "Legal (L)");
                  },
                ),

                _buildToolItem(
                  label: "A3 (P)",
                  icon: Icons.crop_portrait_rounded,
                  tooltipMessage: "A3 Portrait",
                  isSelected: _selectedPageSize == "A3 (P)",
                  onTap: () {
                    _saveStateToHistory();
                    setState(() => _selectedPageSize = "A3 (P)");
                  },
                ),
                _buildToolItem(
                  label: "A3 (L)",
                  icon: Icons.crop_landscape_rounded,
                  tooltipMessage: "A3 Landscape",
                  isSelected: _selectedPageSize == "A3 (L)",
                  onTap: () {
                    _saveStateToHistory();
                    setState(() => _selectedPageSize = "A3 (L)");
                  },
                ),

                _buildToolItem(
                  label: "A5 (P)",
                  icon: Icons.crop_portrait_rounded,
                  tooltipMessage: "A5 Portrait",
                  isSelected: _selectedPageSize == "A5 (P)",
                  onTap: () {
                    _saveStateToHistory();
                    setState(() => _selectedPageSize = "A5 (P)");
                  },
                ),
                _buildToolItem(
                  label: "A5 (L)",
                  icon: Icons.crop_landscape_rounded,
                  tooltipMessage: "A5 Landscape",
                  isSelected: _selectedPageSize == "A5 (L)",
                  onTap: () {
                    _saveStateToHistory();
                    setState(() => _selectedPageSize = "A5 (L)");
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---  UPDATED BLOCK: LAYER SUB-TOOLS (Dynamic X / Tick) ---
  Widget _buildLayerSubTools() {
    bool isTop = false;
    bool isBottom = false;
    bool isLayerChanged = false;

    if (_selectedImageIndex != null && _imageStates.isNotEmpty) {
      isTop = _selectedImageIndex == _imageStates.length - 1;
      isBottom = _selectedImageIndex == 0;

      if (_initialLayerIndex != null) {
        isLayerChanged = _selectedImageIndex != _initialLayerIndex;
      }
    }

    return SizedBox(
      height: 75,
      width: double.infinity,
      child: Row(
        children: [
          // 1. DYNAMIC Tick/Close Button
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: _buildToolItem(
              label: isLayerChanged ? "Done" : "Close",
              icon: isLayerChanged ? Icons.check_rounded : Icons.close_rounded,
              tooltipMessage: isLayerChanged ? "Apply Layer" : "Close Tool",
              isSelected: isLayerChanged,
              onTap: () {
                setState(() {
                  _closeAllSubTools();
                });
              },
            ),
          ),

          // Divider
          Container(height: 30, width: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 0)),

          // 2. LAYER OPTIONS (SCROLLABLE LIST)
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 0),
              children: [
                // A. Ekdam Upar (Bring to Front)
                _buildToolItem(
                  label: "To Front",
                  icon: Icons.vertical_align_top_rounded,
                  isDisabled: _selectedImageIndex == null || isTop,
                  onTap: () {
                    if (_selectedImageIndex != null && !isTop) {
                      _saveStateToHistory();
                      setState(() {
                        var item = _imageStates.removeAt(_selectedImageIndex!);
                        _imageStates.add(item);
                        _selectedImageIndex = _imageStates.length - 1;
                      });
                      HapticFeedback.lightImpact();
                    }
                  },
                ),

                // B. 1 Layer Upar (Bring Forward)
                _buildToolItem(
                  label: "Up",
                  icon: Icons.arrow_upward_rounded,
                  isDisabled: _selectedImageIndex == null || isTop,
                  onTap: () {
                    if (_selectedImageIndex != null && !isTop) {
                      _saveStateToHistory();
                      setState(() {
                        var item = _imageStates.removeAt(_selectedImageIndex!);
                        _imageStates.insert(_selectedImageIndex! + 1, item);
                        _selectedImageIndex = _selectedImageIndex! + 1;
                      });
                      HapticFeedback.lightImpact();
                    }
                  },
                ),

                // C. 1 Layer Niche (Send Backward)
                _buildToolItem(
                  label: "Down",
                  icon: Icons.arrow_downward_rounded,
                  isDisabled: _selectedImageIndex == null || isBottom,
                  onTap: () {
                    if (_selectedImageIndex != null && !isBottom) {
                      _saveStateToHistory();
                      setState(() {
                        var item = _imageStates.removeAt(_selectedImageIndex!);
                        _imageStates.insert(_selectedImageIndex! - 1, item);
                        _selectedImageIndex = _selectedImageIndex! - 1;
                      });
                      HapticFeedback.lightImpact();
                    }
                  },
                ),

                // D. Ekdam Niche (Send to Back)
                _buildToolItem(
                  label: "To Back",
                  icon: Icons.vertical_align_bottom_rounded,
                  isDisabled: _selectedImageIndex == null || isBottom,
                  onTap: () {
                    if (_selectedImageIndex != null && !isBottom) {
                      _saveStateToHistory();
                      setState(() {
                        var item = _imageStates.removeAt(_selectedImageIndex!);
                        _imageStates.insert(0, item);
                        _selectedImageIndex = 0;
                      });
                      HapticFeedback.lightImpact();
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
                  icon: Icons.keyboard_arrow_up,
                  isDisabled: _selectedImageIndex == null,
                  onTap: () {
                    if (_selectedImageIndex != null) {
                      _saveStateToHistory();
                      setState(() {
                        // bottom offset +5 karne se image upar jayegi
                        _imageStates[_selectedImageIndex!].position += const Offset(0, 5);
                      });
                    }
                  },
                ),
                _buildToolItem(
                  label: "Down",
                  icon: Icons.keyboard_arrow_down,
                  isDisabled: _selectedImageIndex == null,
                  onTap: () {
                    if (_selectedImageIndex != null) {
                      _saveStateToHistory();
                      setState(() {
                        // bottom offset -5 karne se image niche jayegi
                        _imageStates[_selectedImageIndex!].position += const Offset(0, -5);
                      });
                    }
                  },
                ),
                _buildToolItem(
                  label: "Left",
                  icon: Icons.keyboard_arrow_left,
                  isDisabled: _selectedImageIndex == null,
                  onTap: () {
                    if (_selectedImageIndex != null) {
                      _saveStateToHistory();
                      setState(() {
                        // left offset -5 karne se image left jayegi
                        _imageStates[_selectedImageIndex!].position += const Offset(-5, 0);
                      });
                    }
                  },
                ),
                _buildToolItem(
                  label: "Right",
                  icon: Icons.keyboard_arrow_right,
                  isDisabled: _selectedImageIndex == null,
                  onTap: () {
                    if (_selectedImageIndex != null) {
                      _saveStateToHistory();
                      setState(() {
                        //  left offset +5 karne se image right jayegi
                        _imageStates[_selectedImageIndex!].position += const Offset(5, 0);
                      });
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
                _saveStateToHistory();
                setState(() {
                  _imageStates[_selectedImageIndex!].rotation -= 0.78539816;
                });
              }
            },
          ),

          //Rotate Right (+90 degrees)
          _buildToolItem(
            label: "Right",
            icon: Icons.rotate_right_rounded,
            isDisabled: _selectedImageIndex == null,
            onTap: () {
              if (_selectedImageIndex != null) {
                _saveStateToHistory();
                setState(() {
                  _imageStates[_selectedImageIndex!].rotation += 0.78539816;
                });
              }
            },
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
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  SizedBox(
                    height: 24, // Slider ki height kam ki taaki fit ho jaye
                    child: Slider(
                      value: currentRotation,
                      min: 0.0,
                      max: 2 * 3.14159265,
                      // 360 degrees
                      activeColor: Colors.blueAccent,
                      inactiveColor: Colors.white24,
                      onChangeStart: _selectedImageIndex == null ? null : (value) => _saveStateToHistory(),
                      onChanged: _selectedImageIndex == null
                          ? null
                          : (value) {
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
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
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
                                onChangeStart: _selectedImageIndex == null ? null : (value) => _saveStateToHistory(),
                                onChanged: _selectedImageIndex == null
                                    ? null
                                    : (value) {
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
                              bool showDot = (currentScale - val).abs() > 0.15;

                              if (!showDot) return const SizedBox.shrink();

                              return Positioned(
                                left: dotPosition - 3,
                                child: IgnorePointer(
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
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
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
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
                                onChangeStart: _selectedImageIndex == null ? null : (value) => _saveStateToHistory(),
                                onChanged: _selectedImageIndex == null
                                    ? null
                                    : (value) {
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
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
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
    isPositionMode = false;
    isRotateMode = false;
    isOpacityMode = false;
    isLayerMode = false;
    _initialLayerIndex = null;
    // isCollageMode = false;
    // isLayerMode = false;
  }

  Future<void> _showAdAndNavigate(File savedFile) async {
    Completer<bool> adCompleter = Completer<bool>();
    InterstitialAd? interstitialAd;

    // 1. Ad load request bhejo (Yahan await mat lagao)
    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          interstitialAd = ad;
          if (!adCompleter.isCompleted) {
            adCompleter.complete(true); // Ad mil gaya
          }
        },
        onAdFailedToLoad: (error) {
          debugPrint('MergeScreen Ad failed to load: $error');
          if (!adCompleter.isCompleted) {
            adCompleter.complete(false); // Ad fail ho gaya
          }
        },
      ),
    );

    // 2. Ad aane ka wait karo (Max 3.5 seconds ka timeout)
    bool isAdLoaded = false;
    try {
      // Ye ad load hote hi aage badh jayega, pura 3.5s wait nahi karega
      isAdLoaded = await adCompleter.future.timeout(const Duration(milliseconds: 3500));
    } catch (e) {
      // Timeout ho gaya
      debugPrint('Ad loading timeout in MergeScreen');
      isAdLoaded = false;
    }

    // 3. Loading Dialog ko band karo
    if (mounted) {
      Navigator.pop(context);
    }

    // Pichle page par wapas jaane ka helper function
    void finishAndPop() {
      if (mounted) {
        Navigator.pop(context, savedFile);
      }
    }

    // 4. Agar ad mil gaya hai toh dikhao, warna direct jao
    if (isAdLoaded && interstitialAd != null) {
      interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          finishAndPop();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint('Failed to show ad: $error');
          ad.dispose();
          finishAndPop();
        },
      );
      interstitialAd!.show();
    } else {
      // Ad nahi aaya toh sidha navigate karo
      finishAndPop();
    }
  }

  Future<void> _saveAndExport() async {
    // 1. Loading Dialog dikhao (Is dialog ko Ad function close karega)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
    );

    // 2. Sabhi tools aur selection hata do
    bool wasGridVisible = isGridVisible;
    setState(() {
      _selectedImageIndex = null;
      isGridVisible = false;
      _closeAllSubTools();
    });

    // 3. UI ko refresh hone do
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      RenderRepaintBoundary boundary = _canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image fullImage = await boundary.toImage(pixelRatio: 3.0);

      Rect cropRect;

      if (_selectedPageSize != "Auto Fit") {
        RenderBox paperBox = _paperKey.currentContext!.findRenderObject() as RenderBox;
        Offset topLeft = paperBox.localToGlobal(Offset.zero, ancestor: boundary);
        cropRect = Rect.fromLTWH(topLeft.dx, topLeft.dy, paperBox.size.width, paperBox.size.height);
      } else {
        double minX = double.infinity, minY = double.infinity;
        double maxX = -double.infinity, maxY = -double.infinity;

        for (var img in _imageStates) {
          if (img.isHidden) continue;

          RenderBox? box = img.imageKey.currentContext?.findRenderObject() as RenderBox?;
          if (box != null) {
            Offset p1 = box.localToGlobal(Offset.zero, ancestor: boundary);
            Offset p2 = box.localToGlobal(Offset(box.size.width, 0), ancestor: boundary);
            Offset p3 = box.localToGlobal(Offset(0, box.size.height), ancestor: boundary);
            Offset p4 = box.localToGlobal(Offset(box.size.width, box.size.height), ancestor: boundary);

            double localMinX = [p1.dx, p2.dx, p3.dx, p4.dx].reduce(math.min);
            double localMaxX = [p1.dx, p2.dx, p3.dx, p4.dx].reduce(math.max);
            double localMinY = [p1.dy, p2.dy, p3.dy, p4.dy].reduce(math.min);
            double localMaxY = [p1.dy, p2.dy, p3.dy, p4.dy].reduce(math.max);

            if (localMinX < minX) minX = localMinX;
            if (localMaxX > maxX) maxX = localMaxX;
            if (localMinY < minY) minY = localMinY;
            if (localMaxY > maxY) maxY = localMaxY;
          }
        }

        if (minX == double.infinity) {
          if (context.mounted) Navigator.pop(context);
          setState(() {
            isGridVisible = wasGridVisible;
          });
          return;
        }

        cropRect = Rect.fromLTRB(minX - 5, minY - 5, maxX + 5, maxY + 5);
      }

      double pr = 3.0;
      Rect pixelCropRect = Rect.fromLTRB(
        cropRect.left * pr,
        cropRect.top * pr,
        cropRect.right * pr,
        cropRect.bottom * pr,
      ).intersect(Rect.fromLTWH(0, 0, fullImage.width.toDouble(), fullImage.height.toDouble()));

      if (pixelCropRect.width <= 0 || pixelCropRect.height <= 0) {
        if (context.mounted) Navigator.pop(context);
        setState(() {
          isGridVisible = wasGridVisible;
        });
        return;
      }

      ui.PictureRecorder recorder = ui.PictureRecorder();
      Canvas canvas = Canvas(recorder);
      Rect exactCanvasRect = Rect.fromLTWH(0, 0, pixelCropRect.width, pixelCropRect.height);
      canvas.drawImageRect(fullImage, pixelCropRect, exactCanvasRect, Paint());

      ui.Image croppedImage = await recorder.endRecording().toImage(
        pixelCropRect.width.toInt(),
        pixelCropRect.height.toInt(),
      );
      ByteData? byteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      Directory tempDir = await getTemporaryDirectory();
      File savedFile = File('${tempDir.path}/merged_page_${DateTime.now().millisecondsSinceEpoch}.png');
      await savedFile.writeAsBytes(pngBytes);

      // 🚨 YAHAN SE ALAG KIYA HUA AD FUNCTION CALL HOGA
      await _showAdAndNavigate(savedFile);
    } catch (e) {
      debugPrint("Export Error: $e");
      // Error aane par hi loading dialog yahan se pop hoga
      if (context.mounted) Navigator.pop(context);
    } finally {
      if (mounted) {
        setState(() {
          isGridVisible = wasGridVisible;
        });
      }
    }
  }

  // Delete handle karne ka async function ---
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
      _saveStateToHistory();
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
        return 210 / 297;
      default:
        return 210 / 297;
    }
  }
}

// ---GRAPH PAPER PAINTER CLASS ---
class GraphPaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors
          .black12 // Ekdum halki premium lines
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

// --- 🚨 NAYA: ADMOB BANNER AD WIDGET ---
class CustomBannerAd extends StatefulWidget {
  const CustomBannerAd({Key? key}) : super(key: key);

  @override
  State<CustomBannerAd> createState() => _CustomBannerAdState();
}

class _CustomBannerAdState extends State<CustomBannerAd> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  // TODO 🚨 Sirf Android Test Ad ID
  final String adUnitId = 'ca-app-pub-3940256099942544/6300978111';

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('Ad loaded.');
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('Ad failed to load: $err');
          ad.dispose(); // Fail hone par memory free karna zaroori hai
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose(); // Screen band hone par Ad ko hatao taaki app hang na ho
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoaded && _bannerAd != null) {
      return SafeArea(
        top: false,
        child: Container(
          color: Colors.black,
          // Dark theme se match karta background
          width: double.infinity,
          // Poori width lega
          height: _bannerAd!.size.height.toDouble(),
          // Ad ki perfect height
          alignment: Alignment.center,
          child: AdWidget(ad: _bannerAd!),
        ),
      );
    }

    // Jab tak Ad load ho raha hai, tab tak khali space dikhao
    return SafeArea(top: false, child: Container(height: 50, color: Colors.black));
  }
}
