import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path_provider/path_provider.dart';

class DrawnPath {
  final List<Offset?> points;
  final Color color;
  final double strokeWidth;
  final double opacity;
  final bool isEraser;
  final bool isClear;

  DrawnPath({
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.opacity,
    this.isEraser = false,
    this.isClear = false,
  });
}

class MarkupScreen extends StatefulWidget {
  final File imageFile;

  const MarkupScreen({Key? key, required this.imageFile}) : super(key: key);

  @override
  State<MarkupScreen> createState() => _MarkupScreenState();
}

class _MarkupScreenState extends State<MarkupScreen> {
  final GlobalKey _globalKey = GlobalKey();
  final GlobalKey _canvasKey = GlobalKey(); // 🚨 FIX 1: Drawing coordinate offsets ko ekdum sahi karne ke liye key

  List<DrawnPath> _paths = [];
  List<DrawnPath> _undonePaths = [];
  List<Offset?> _currentPoints = [];

  Color _selectedColor = Colors.blue;
  double _strokeWidth = 12.0;
  double _opacity = 1.0;

  String _activeTab = "Drawing"; // Drawing, Eraser, Text, Shapes
  String _selectedShape = "Triangle";

  bool _isEraserMode = false;
  int _pointerCount = 0; // Tracks number of fingers on screen

  final List<Color> _recentColors = [
    Colors.blue, Colors.green, Colors.teal, Colors.amber, Colors.greenAccent
  ];

  // Discard Dialog
  Future<bool> _onWillPop() async {
    if (_paths.isEmpty) return true;

    bool? discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text("Discard changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          "Changes you have made with the Markup tool will be discarded.",
          style: TextStyle(color: Colors.white70),
        ),
        // actions: [
        //   OutlinedButton(
        //     style: OutlinedButton.styleFrom(
        //       side: const BorderSide(color: Colors.grey),
        //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        //     ),
        //     onPressed: () => Navigator.pop(context, true),
        //     child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
        //   ),
        //   ElevatedButton(
        //     style: ElevatedButton.styleFrom(
        //       backgroundColor: Colors.blueAccent,
        //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        //     ),
        //     onPressed: () => Navigator.pop(context, false),
        //     child: const Text("OK", style: TextStyle(color: Colors.white)),
        //   ),
        // ],

        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            // 🚨 FIX: Cancel dabaane par 'false' return hoga, jisse sirf popup band hoga, screen nahi
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            // 🚨 FIX: OK dabaane par 'true' return hoga, jisse screen back chali jayegi (discard changes)
            onPressed: () => Navigator.pop(context, true),
            child: const Text("OK", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  // Save the drawn canvas as a new image file
  Future<void> _saveMarkup() async {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
    );

    try {
      RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final newFile = File('${dir.path}/markup_${DateTime.now().millisecondsSinceEpoch}.png');
      await newFile.writeAsBytes(pngBytes);

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context, newFile);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  // Color Picker Window
  void _openColorPicker() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF2C2C2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 180, width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(
                    colors: [Colors.white, Colors.blue, Colors.black],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.topRight,
                padding: const EdgeInsets.all(12),
                child: const Icon(Icons.circle_outlined, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _recentColors.map((c) => GestureDetector(
                  onTap: () {
                    setState(() => _selectedColor = c);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade600)),
                  ),
                )).toList(),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E1E1E),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
            onPressed: () async {
              if (await _onWillPop()) {
                Navigator.pop(context);
              }
            },
          ),
          title: const Text("Markup", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
          actions: [
            Tooltip(
              message: "Undo",
              child: IconButton(
                icon: Icon(Icons.undo_rounded, color: _paths.isNotEmpty ? Colors.white : Colors.white38),
                onPressed: () {
                  if (_paths.isNotEmpty) {
                    setState(() {
                      _undonePaths.add(_paths.removeLast());
                    });
                  }
                },
              ),
            ),
            Tooltip(
              message: "Redo",
              child: IconButton(
                icon: Icon(Icons.redo_rounded, color: _undonePaths.isNotEmpty ? Colors.white : Colors.white38),
                onPressed: () {
                  if (_undonePaths.isNotEmpty) {
                    setState(() {
                      _paths.add(_undonePaths.removeLast());
                    });
                  }
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.check_rounded, color: Colors.blueAccent, size: 30),
              onPressed: _saveMarkup,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            // --- 1. MAIN PREVIEW AREA (With Zoom & Draw) ---
            Expanded(
              child: Container(
                color: const Color(0xFF2C2C2C),
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 8.0,
                  clipBehavior: Clip.none,
                  panEnabled: true,   // 🚨 FIX 2: Panning hamesha true rahegi taaki zoom ke baad photo move ho sake
                  scaleEnabled: true, // 🚨 FIX 3: Zooming hamesha true rahegi
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 20),
                      child: RepaintBoundary(
                        key: _globalKey,
                        child: Stack(
                          key: _canvasKey, // 🚨 FIX 4: Canvas key yahan attach ki taaki scale hone par bhi offset ekdum ungli ke niche rahe
                          children: [
                            Image.file(widget.imageFile, fit: BoxFit.contain),

                            // Drawing Layer
                            Positioned.fill(
                              child: Listener(
                                onPointerDown: (_) {
                                  setState(() {
                                    _pointerCount++;
                                    // Safety check: Agar 1 se zyada finger aa gayi, toh current drawing line ko wahin rok do
                                    if (_pointerCount > 1 && _currentPoints.isNotEmpty) {
                                      _currentPoints.add(null);
                                      _paths.add(DrawnPath(
                                        points: List.from(_currentPoints),
                                        color: _selectedColor,
                                        strokeWidth: _strokeWidth,
                                        opacity: _opacity,
                                        isEraser: _activeTab == "Eraser",
                                      ));
                                      _currentPoints.clear();
                                    }
                                  });
                                },
                                onPointerUp: (_) => setState(() => _pointerCount--),
                                onPointerCancel: (_) => setState(() => _pointerCount--),
                                child: GestureDetector(
                                  // 🚨 FIX 5: Agar pointer 1 se bada hai (2 fingers hain), toh drawing events ko 'null' karke bypass kar do, taaki InteractiveViewer smoothly zoom le sake.
                                  // onPanStart: _pointerCount > 1 ? null : (details) {
                                  //   if (_activeTab == "Drawing" || _activeTab == "Eraser") {
                                  //     setState(() {
                                  //       RenderBox renderBox = _canvasKey.currentContext!.findRenderObject() as RenderBox;
                                  //       _currentPoints = [renderBox.globalToLocal(details.globalPosition)];
                                  //     });
                                  //   }
                                  // },
                                  // onPanUpdate: _pointerCount > 1 ? null : (details) {
                                  //   if (_activeTab == "Drawing" || _activeTab == "Eraser") {
                                  //     setState(() {
                                  //       RenderBox renderBox = _canvasKey.currentContext!.findRenderObject() as RenderBox;
                                  //       _currentPoints.add(renderBox.globalToLocal(details.globalPosition));
                                  //     });
                                  //   }
                                  // },
                                  // onPanEnd: _pointerCount > 1 ? null : (details) {
                                  //   if (_activeTab == "Drawing" || _activeTab == "Eraser") {
                                  //     if (_currentPoints.isEmpty) return;
                                  //     setState(() {
                                  //       _currentPoints.add(null);
                                  //       _paths.add(DrawnPath(
                                  //         points: List.from(_currentPoints),
                                  //         color: _selectedColor,
                                  //         strokeWidth: _strokeWidth,
                                  //         opacity: _opacity,
                                  //         isEraser: _activeTab == "Eraser",
                                  //       ));
                                  //       _currentPoints.clear();
                                  //       _undonePaths.clear();
                                  //     });
                                  //   }
                                  // },
                                  // child: CustomPaint(
                                  //   painter: DrawingPainter(
                                  //     paths: _paths,
                                  //     currentPoints: _currentPoints,
                                  //     currentColor: _selectedColor,
                                  //     currentStrokeWidth: _strokeWidth,
                                  //     currentOpacity: _opacity,
                                  //     isEraser: _activeTab == "Eraser",
                                  //   ),
                                  // ),

                                  // 🚨 FIX 3: Gestures ab sirf 'Drawing' tab mein aur '_isEraserMode' flag ke sath kaam karenge
                                  onPanStart: _pointerCount > 1 ? null : (details) {
                                    if (_activeTab == "Drawing") {
                                      setState(() {
                                        RenderBox renderBox = _canvasKey.currentContext!.findRenderObject() as RenderBox;
                                        _currentPoints = [renderBox.globalToLocal(details.globalPosition)];
                                      });
                                    }
                                  },
                                  onPanUpdate: _pointerCount > 1 ? null : (details) {
                                    if (_activeTab == "Drawing") {
                                      setState(() {
                                        RenderBox renderBox = _canvasKey.currentContext!.findRenderObject() as RenderBox;
                                        _currentPoints.add(renderBox.globalToLocal(details.globalPosition));
                                      });
                                    }
                                  },
                                  onPanEnd: _pointerCount > 1 ? null : (details) {
                                    if (_activeTab == "Drawing") {
                                      if (_currentPoints.isEmpty) return;
                                      setState(() {
                                        _currentPoints.add(null);
                                        _paths.add(DrawnPath(
                                          points: List.from(_currentPoints),
                                          color: _selectedColor,
                                          strokeWidth: _strokeWidth,
                                          opacity: _opacity,
                                          isEraser: _isEraserMode, // Yahan Flag Change
                                        ));
                                        _currentPoints.clear();
                                        _undonePaths.clear();
                                      });
                                    }
                                  },
                                  child: CustomPaint(
                                    painter: DrawingPainter(
                                      paths: _paths,
                                      currentPoints: _currentPoints,
                                      currentColor: _selectedColor,
                                      currentStrokeWidth: _strokeWidth,
                                      currentOpacity: _opacity,
                                      isEraser: _isEraserMode, // Yahan Flag Change
                                    ),
                                  ),

                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // --- 2. SETTINGS PANEL (Color, Stroke, Shapes) ---
            Container(
              color: const Color(0xFF1E1E1E),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: _buildSettingsPanel(),
            ),

            // --- 3. BOTTOM TABS ---
            Container(
              height: 60, color: Colors.black,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildBottomTab("Drawing", Icons.draw_rounded),
                  // _buildBottomTab("Eraser", Icons.cleaning_services_rounded),
                  _buildBottomTab("Text", Icons.title_rounded),
                  _buildBottomTab("Shapes", Icons.category_rounded),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomTab(String title, IconData icon) {
    bool isSelected = _activeTab == title;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = title),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isSelected ? Colors.blueAccent : Colors.white54, size: 24),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: isSelected ? Colors.blueAccent : Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  // Widget _buildSettingsPanel() {
  //   if (_activeTab == "Drawing" || _activeTab == "Eraser") {
  //     return Column(
  //       mainAxisSize: MainAxisSize.min,
  //       children: [
  //         if (_activeTab == "Drawing") ...[
  //           Row(
  //             children: [
  //               const Text("Color", style: TextStyle(color: Colors.white, fontSize: 16)),
  //               const SizedBox(width: 16),
  //               GestureDetector(
  //                 onTap: _openColorPicker,
  //                 child: Container(width: 35, height: 35, decoration: BoxDecoration(color: _selectedColor, borderRadius: BorderRadius.circular(6))),
  //               ),
  //               const SizedBox(width: 16),
  //               const Icon(Icons.colorize_rounded, color: Colors.white70),
  //             ],
  //           ),
  //           const SizedBox(height: 20),
  //         ],
  //
  //         Row(
  //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //           children: [
  //             const Text("Stroke width", style: TextStyle(color: Colors.white, fontSize: 16)),
  //             Text("${_strokeWidth.toInt()}", style: const TextStyle(color: Colors.white, fontSize: 14)),
  //           ],
  //         ),
  //         SliderTheme(
  //           data: SliderThemeData(trackHeight: 2, activeTrackColor: Colors.grey.shade400, inactiveTrackColor: Colors.grey.shade800, thumbColor: Colors.white),
  //           child: Slider(
  //             value: _strokeWidth, min: 1, max: 50,
  //             onChanged: (val) => setState(() => _strokeWidth = val),
  //           ),
  //         ),
  //
  //         if (_activeTab == "Drawing") ...[
  //           const SizedBox(height: 10),
  //           Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //             children: [
  //               const Text("Opacity", style: TextStyle(color: Colors.white, fontSize: 16)),
  //               Text("${(_opacity * 100).toInt()}%", style: const TextStyle(color: Colors.white, fontSize: 14)),
  //             ],
  //           ),
  //           SliderTheme(
  //             data: SliderThemeData(trackHeight: 2, activeTrackColor: Colors.grey.shade400, inactiveTrackColor: Colors.grey.shade800, thumbColor: Colors.white),
  //             child: Slider(
  //               value: _opacity, min: 0.1, max: 1.0,
  //               onChanged: (val) => setState(() => _opacity = val),
  //             ),
  //           ),
  //         ]
  //       ],
  //     );
  //   }
  //   else if (_activeTab == "Shapes") {
  //     List<IconData> shapeIcons = [Icons.change_history_rounded, Icons.circle_outlined, Icons.square_outlined, Icons.crop_square_rounded, Icons.hexagon_outlined];
  //     return SizedBox(
  //       height: 60,
  //       child: Row(
  //         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //         children: shapeIcons.map((icon) => Icon(icon, color: Colors.cyan, size: 40)).toList(),
  //       ),
  //     );
  //   }
  //
  //   return const Center(child: Text("Feature coming soon", style: TextStyle(color: Colors.white54)));
  // }

  Widget _buildSettingsPanel() {
    if (_activeTab == "Drawing") {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- 🚨 TOP ROW: Color Picker (Left) & Tools (Right) ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // LEFT SIDE: Color Picker (Eraser mode me hide hoga)
              if (!_isEraserMode)
                Row(
                  children: [
                    const Text("Color", style: TextStyle(color: Colors.white, fontSize: 14)),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: _openColorPicker,
                      child: Container(width: 32, height: 32, decoration: BoxDecoration(color: _selectedColor, borderRadius: BorderRadius.circular(6))),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(onTap: _openColorPicker, child: const Icon(Icons.colorize_rounded, color: Colors.white70, size: 24)),
                  ],
                )
              else
                const Text("Eraser Mode", style: TextStyle(color: Colors.white70, fontSize: 14)),

              // RIGHT SIDE: Draw, Eraser, Delete Buttons
              Row(
                children: [
                  // Draw Button
                  GestureDetector(
                    onTap: () => setState(() => _isEraserMode = false),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: !_isEraserMode ? Colors.blueAccent.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                      child: Icon(Symbols.stylus_note, color: !_isEraserMode ? Colors.blueAccent : Colors.white70, size: 24),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Eraser Button
                  GestureDetector(
                    onTap: () => setState(() => _isEraserMode = true),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: _isEraserMode ? Colors.blueAccent.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                      child: Icon(Symbols.ink_eraser_rounded, color: _isEraserMode ? Colors.blueAccent : Colors.white70, size: 24),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Delete Button
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        // 🚨 Secret: Delete action ko as a "Path" history me daal diya taaki Undo ho sake!
                        _paths.add(DrawnPath(points: [], color: Colors.transparent, strokeWidth: 0, opacity: 0, isClear: true));
                        _undonePaths.clear();
                      });
                    },
                    child: Container(padding: const EdgeInsets.all(6), child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24)),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 10),

          // --- SLIDERS ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Stroke width", style: TextStyle(color: Colors.white, fontSize: 14)),
              Text("${_strokeWidth.toInt()}", style: const TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(trackHeight: 2, activeTrackColor: Colors.grey.shade400, inactiveTrackColor: Colors.grey.shade800, thumbColor: Colors.white),
            child: Slider(value: _strokeWidth, min: 1, max: 50, onChanged: (val) => setState(() => _strokeWidth = val)),
          ),

          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Opacity", style: TextStyle(color: Colors.white, fontSize: 14)),
              Text("${(_opacity * 100).toInt()}%", style: const TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(trackHeight: 2, activeTrackColor: Colors.grey.shade400, inactiveTrackColor: Colors.grey.shade800, thumbColor: Colors.white),
            child: Slider(value: _opacity, min: 0.1, max: 1.0, onChanged: (val) => setState(() => _opacity = val)),
          )
        ],
      );
    }
    else if (_activeTab == "Shapes") {
      List<IconData> shapeIcons = [Icons.change_history_rounded, Icons.circle_outlined, Icons.square_outlined, Icons.crop_square_rounded, Icons.hexagon_outlined];
      return SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: shapeIcons.map((icon) => Icon(icon, color: Colors.cyan, size: 40)).toList(),
        ),
      );
    }
    return const Center(child: Text("Feature coming soon", style: TextStyle(color: Colors.white54)));
  }
}

class DrawingPainter extends CustomPainter {
  final List<DrawnPath> paths;
  final List<Offset?> currentPoints;
  final Color currentColor;
  final double currentStrokeWidth;
  final double currentOpacity;
  final bool isEraser;

  DrawingPainter({
    required this.paths,
    required this.currentPoints,
    required this.currentColor,
    required this.currentStrokeWidth,
    required this.currentOpacity,
    required this.isEraser,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    for (var path in paths) {

      // 🚨 FIX 6: Agar Delete click hua tha, toh is point tak ka sab clear kardo (Background image safe rahegi)
      if (path.isClear) {
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..blendMode = BlendMode.clear);
        continue; // Niche ka code skip karke agle drawing path par jao
      }

      Paint p = Paint()
        ..color = path.isEraser ? Colors.transparent : path.color.withOpacity(path.opacity)
        ..strokeWidth = path.strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..blendMode = path.isEraser ? BlendMode.clear : BlendMode.srcOver;

      for (int i = 0; i < path.points.length - 1; i++) {
        if (path.points[i] != null && path.points[i + 1] != null) {
          canvas.drawLine(path.points[i]!, path.points[i + 1]!, p);
        } else if (path.points[i] != null && path.points[i + 1] == null) {
          canvas.drawPoints(ui.PointMode.points, [path.points[i]!], p);
        }
      }
    }

    if (currentPoints.isNotEmpty) {
      Paint p = Paint()
        ..color = isEraser ? Colors.transparent : currentColor.withOpacity(currentOpacity)
        ..strokeWidth = currentStrokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..blendMode = isEraser ? BlendMode.clear : BlendMode.srcOver;

      for (int i = 0; i < currentPoints.length - 1; i++) {
        if (currentPoints[i] != null && currentPoints[i + 1] != null) {
          canvas.drawLine(currentPoints[i]!, currentPoints[i + 1]!, p);
        }
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}