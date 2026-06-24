import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

// 🚨 NAYA CLASS: Text overlays ko track karne ke liye
class TextOverlayItem {
  String text;
  Offset offset;
  Color color;
  double fontSize;
  double rotation;
  int appearance; // 0=Normal, 1=Solid Box, 2=Transparent Box, 3=Stroke
  bool isBold;
  bool isItalic;
  bool isUnderline;
  bool isStrikethrough;
  TextAlign alignment;
  String font;

  TextOverlayItem({
    required this.text,
    required this.offset,
    required this.color,
    this.fontSize = 32.0,
    this.rotation = 0.0,
    this.appearance = 0,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrikethrough = false,
    this.alignment = TextAlign.center,
    this.font = 'Roboto',
  });

  // Duplicate karne ka function
  TextOverlayItem clone() {
    return TextOverlayItem(
      // 🚨 FIX: Duplicate offset ko ab percentage mein (5%) shift kiya hai
      text: text,
      offset: offset + const Offset(0.05, 0.05),
      color: color,
      fontSize: fontSize,
      rotation: rotation,
      appearance: appearance,
      isBold: isBold,
      isItalic: isItalic,
      isUnderline: isUnderline,
      isStrikethrough: isStrikethrough,
      alignment: alignment,
      font: font,
    );
  }
}

class ShapeItem {
  IconData icon; // Shape ka icon
  Offset offset;
  Color color;
  double size;

  //double strokeWidth;
  double rotation;
  double scaleX = 1.0; // 🚨 Direct initialize kiya
  double scaleY = 1.0; // 🚨 Direct initialize kiya

  ShapeItem({
    required this.icon,
    this.offset = const Offset(0.5, 0.5),
    required this.color,
    this.size = 100.0,
    //this.strokeWidth = 2.0,
    this.rotation = 0.0,
    this.scaleX = 1.0, // Default 1.0 (Normal size)
    this.scaleY = 1.0, // Default 1.0 (Normal size)
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
  final GlobalKey _canvasKey =
      GlobalKey(); // 🚨 FIX 1: Drawing coordinate offsets ko ekdum sahi karne ke liye key

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

  // final List<Color> _recentColors = [
  //   Colors.blue, Colors.green, Colors.teal, Colors.amber, Colors.greenAccent
  // ];
  List<Color> _recentColors = []; // 🚨 Default empty list, ab memory se aayegi
  bool _isPanelHidden =
      false; // 🚨 NAYA VARIABLE: Panel hide/show track karne ke liye

  // 🚨 TEXT WIDGET VARIABLES
  List<TextOverlayItem> _textItems = [];
  TextOverlayItem? _activeTextItem;

  // 🚨 NAYA VARIABLE: Jab screen par koi text select nahi hoga, toh UI is draft ki settings dikhayega
  //TextOverlayItem _draftTextItem = TextOverlayItem(text: "", offset: const Offset(150, 150), color: Colors.white);
  TextOverlayItem _draftTextItem = TextOverlayItem(
    text: "",
    offset: const Offset(0.5, 0.5),
    color: Colors.white,
  );
  final TextEditingController _textEditorController = TextEditingController();
  final List<String> _fonts = ['Roboto', 'Serif', 'Monospace', 'Cursive'];

  List<ShapeItem> _shapeItems = [];
  ShapeItem? _activeShapeItem;

  @override
  void initState() {
    super.initState();
    _loadRecentColors();
  }

  @override
  void dispose() {
    _textEditorController.dispose();
    super.dispose();
  }

  void _unfocusAll() {
    FocusManager.instance.primaryFocus?.unfocus(); // Keyboard band hoga
    setState(() {
      _activeTextItem = null; // Text box ka border hat jayega
      _activeShapeItem = null; // 🚨 Shape selection bhi hatao
    });
  }

  // --- 🚨 SHARED PREFERENCES LOGIC ---
  Future<void> _loadRecentColors() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedColors = prefs.getStringList('markup_recent_colors');
    if (savedColors != null) {
      setState(() {
        _recentColors = savedColors.map((c) => Color(int.parse(c))).toList();
        _selectedColor = _recentColors.first;
      });
    }
  }

  Future<void> _saveRecentColor(Color color) async {
    // Agar color pehle se hai toh hatao, aur ekdum start (left) me add karo
    _recentColors.remove(color);
    _recentColors.insert(0, color);

    // Sirf last 5 colors rakho
    if (_recentColors.length > 5) {
      _recentColors = _recentColors.sublist(0, 5);
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> colorsToSave = _recentColors
        .map((c) => c.value.toString())
        .toList();
    await prefs.setStringList('markup_recent_colors', colorsToSave);

    setState(() {}); // UI Update
  }

  // Discard Dialog
  // Discard Dialog
  Future<bool> _onWillPop() async {
    if (_paths.isEmpty) return true;

    bool? discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text(
          "Discard changes",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Changes you have made with the Markup tool will be discarded.",
          style: TextStyle(color: Colors.white70),
        ),

        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            // 🚨 FIX: Cancel dabaane par 'false' return hoga, jisse sirf popup band hoga, screen nahi
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
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
    setState(() {
      _activeTextItem = null; // Text se selection border hatao
      _activeShapeItem = null;
      _textItems.removeWhere(
        (item) => item.text.trim().isEmpty,
      ); // Khali text ko list se delete karo
    });

    // 🚨 MAIN FIX: Flutter ko screen update karne ke liye thoda time do (100ms)
    // Warna UI refresh hone se pehle hi purani photo save ho jayegi!
    await Future.delayed(const Duration(milliseconds: 100));

    // Yahan loading indicator dikhana shuru hoga (Screen freeze hone se rokne ke liye wait use kiya)
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.blueAccent),
      ),
    );

    try {
      RenderRepaintBoundary boundary =
          _globalKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final newFile = File(
        '${dir.path}/markup_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await newFile.writeAsBytes(pngBytes);

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context, newFile);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  // Color Picker Window (No Opacity, Auto-Select, Exact Screenshot Design)
  Future<void> _openColorPicker() async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF2C2C2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🚨 FIX: Alpha (Opacity) disabled. Exact screenshot look.
              ColorPicker(
                pickerColor: _selectedColor,
                // Alpha link hata diya
                onColorChanged: (color) {
                  setState(() {
                    _selectedColor =
                        color; // Sirf color change hoga, Opacity apni jagah wahi rahegi
                    if (_activeShapeItem != null) {
                      _activeShapeItem!.color = color;
                    }
                  });
                },
                colorPickerWidth: 280,
                pickerAreaHeightPercent: 0.8,
                // Thoda square look dene ke liye
                enableAlpha: false,
                // 🚨 Opacity slider gayab
                displayThumbColor: true,
                paletteType: PaletteType.hsvWithHue,
                pickerAreaBorderRadius: const BorderRadius.all(
                  Radius.circular(6),
                ),
                hexInputBar: false,
                labelTypes: const [], // Faltu labels hide kiye
              ),
              const SizedBox(height: 5),

              // 🚨 FIX: Recent Colors Exact Screenshot Design (Square, light grey border)
              if (_recentColors.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  // Evenly spread karega
                  children: _recentColors
                      .map(
                        (c) => GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedColor = c;
                              if (_activeShapeItem != null) {
                                _activeShapeItem!.color = c; // Shape ka color yahan update hua
                              }
                            });
                            Navigator.pop(context); // Click karte hi close
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            width: 38,
                            height: 38, // Square design
                            decoration: BoxDecoration(
                              color: c,
                              borderRadius: BorderRadius.circular(6),
                              // Halka rounded corner
                              border: Border.all(
                                color: Colors.grey.shade400,
                                width: 1.5,
                              ), // Light grey exact border
                            ),
                          ),
                        ),
                      )
                      .toList(),
                )
              else
                const SizedBox(
                  height: 38,
                  child: Center(
                    child: Text(
                      "No recent colors",
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    // Jab bahar click karke popup band hoga, naya color save ho jayega
    _saveRecentColor(_selectedColor);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      // 🚨 FIX: Poori screen wrap ki, taaki kahin bhi click ho to focus hat jaye
      child: GestureDetector(
        onTap: _unfocusAll,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: const Color(0xFF1E1E1E),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E1E1E),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 28,
              ),
              onPressed: () async {
                if (await _onWillPop()) {
                  Navigator.pop(context);
                }
              },
            ),
            title: const Text(
              "Markup",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            actions: [
              if (_activeTab == "Drawing") ...[
                Tooltip(
                  message: "Undo",
                  child: IconButton(
                    icon: Icon(
                      Icons.undo_rounded,
                      color: _paths.isNotEmpty ? Colors.white : Colors.white38,
                    ),
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
                    icon: Icon(
                      Icons.redo_rounded,
                      color: _undonePaths.isNotEmpty
                          ? Colors.white
                          : Colors.white38,
                    ),
                    onPressed: () {
                      if (_undonePaths.isNotEmpty) {
                        setState(() {
                          _paths.add(_undonePaths.removeLast());
                        });
                      }
                    },
                  ),
                ),
              ],
              IconButton(
                icon: const Icon(
                  Icons.check_rounded,
                  color: Colors.blueAccent,
                  size: 30,
                ),
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
                    panEnabled: true,
                    scaleEnabled: true,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 24,
                          right: 24,
                          top: 20,
                          bottom: 20,
                        ),
                        child: RepaintBoundary(
                          key: _globalKey,
                          // 🚨 FEVICOL FIX 1: Ab Canvas EXACTLY Image ke size ka banega. No empty letterbox space!
                          child: Stack(
                            key: _canvasKey,
                            clipBehavior: Clip.none,
                            children: [
                              // 1. BASE IMAGE (Bina 'BoxFit' ke, ye khudko exact ratio me set karega)
                              Image.file(widget.imageFile),

                              // 2. DRAWING LAYER
                              Positioned.fill(
                                child: Listener(
                                  onPointerDown: (_) {
                                    setState(() {
                                      _pointerCount++;
                                      if (_pointerCount > 1 &&
                                          _currentPoints.isNotEmpty) {
                                        _currentPoints.add(null);
                                        _paths.add(
                                          DrawnPath(
                                            points: List.from(_currentPoints),
                                            color: _selectedColor,
                                            strokeWidth: _strokeWidth,
                                            opacity: _opacity,
                                            isEraser: _activeTab == "Eraser",
                                          ),
                                        );
                                        _currentPoints.clear();
                                      }
                                    });
                                  },
                                  onPointerUp: (_) =>
                                      setState(() => _pointerCount--),
                                  onPointerCancel: (_) =>
                                      setState(() => _pointerCount--),
                                  child: GestureDetector(
                                    onPanStart: _pointerCount > 1
                                        ? null
                                        : (details) {
                                            if (_activeTab == "Drawing") {
                                              setState(() {
                                                RenderBox renderBox =
                                                    _canvasKey.currentContext!
                                                            .findRenderObject()
                                                        as RenderBox;
                                                Offset localPos = renderBox
                                                    .globalToLocal(
                                                      details.globalPosition,
                                                    );
                                                _currentPoints = [
                                                  Offset(
                                                    localPos.dx /
                                                        renderBox.size.width,
                                                    localPos.dy /
                                                        renderBox.size.height,
                                                  ),
                                                ];
                                              });
                                            }
                                          },
                                    onPanUpdate: _pointerCount > 1
                                        ? null
                                        : (details) {
                                            if (_activeTab == "Drawing") {
                                              setState(() {
                                                RenderBox renderBox =
                                                    _canvasKey.currentContext!
                                                            .findRenderObject()
                                                        as RenderBox;
                                                Offset localPos = renderBox
                                                    .globalToLocal(
                                                      details.globalPosition,
                                                    );
                                                _currentPoints.add(
                                                  Offset(
                                                    localPos.dx /
                                                        renderBox.size.width,
                                                    localPos.dy /
                                                        renderBox.size.height,
                                                  ),
                                                );
                                              });
                                            }
                                          },
                                    onPanEnd: _pointerCount > 1
                                        ? null
                                        : (details) {
                                            if (_activeTab == "Drawing") {
                                              if (_currentPoints.isEmpty)
                                                return;
                                              setState(() {
                                                _currentPoints.add(null);
                                                _paths.add(
                                                  DrawnPath(
                                                    points: List.from(
                                                      _currentPoints,
                                                    ),
                                                    color: _selectedColor,
                                                    strokeWidth: _strokeWidth,
                                                    opacity: _opacity,
                                                    isEraser: _isEraserMode,
                                                  ),
                                                );
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
                                        isEraser: _isEraserMode,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // 3. TEXT LAYER (Auto Scale & Attached to Center)
                              Positioned.fill(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    // Yahan canvas/image ka exact width & height aayega
                                    double canvasW = constraints.maxWidth;
                                    double canvasH = constraints.maxHeight;

                                    // 🚨 FEVICOL FIX 2: Text ki size Image ki size ke sath badi-choti hogi!
                                    double scaleRatio = canvasW / 400.0;

                                    return Stack(
                                      clipBehavior: Clip.none,
                                      children: _textItems.map((item) {
                                        bool isActive = _activeTextItem == item;
                                        // Text size automatically image ke mutabik scale hogi
                                        double scaledFontSize =
                                            item.fontSize * scaleRatio;

                                        Color textColor = item.appearance == 0
                                            ? item.color
                                            : (item.appearance == 1 ||
                                                  item.appearance == 2)
                                            ? (item.color.computeLuminance() >
                                                      0.5
                                                  ? Colors.black
                                                  : Colors.white)
                                            : Colors.white;
                                        Color bgColor = item.appearance == 1
                                            ? item.color
                                            : item.appearance == 2
                                            ? item.color.withOpacity(0.5)
                                            : Colors.transparent;

                                        TextDecoration decoration =
                                            TextDecoration.none;
                                        if (item.isUnderline &&
                                            item.isStrikethrough) {
                                          decoration = TextDecoration.combine([
                                            TextDecoration.underline,
                                            TextDecoration.lineThrough,
                                          ]);
                                        } else if (item.isUnderline) {
                                          decoration = TextDecoration.underline;
                                        } else if (item.isStrikethrough) {
                                          decoration =
                                              TextDecoration.lineThrough;
                                        }

                                        return Positioned(
                                          // Offset image size ke percentage par multiply hua
                                          left: item.offset.dx * canvasW,
                                          top: item.offset.dy * canvasH,
                                          // 🚨 FEVICOL FIX 3: FractionalTranslation hamesha 'Center' point ko pin karta hai!
                                          child: FractionalTranslation(
                                            translation: const Offset(
                                              -0.5,
                                              -0.5,
                                            ),
                                            child: Transform.rotate(
                                              angle: item.rotation,
                                              child: GestureDetector(
                                                onPanUpdate: (details) {
                                                  if (_activeTab == "Text") {
                                                    setState(() {
                                                      RenderBox renderBox =
                                                          _canvasKey
                                                                  .currentContext!
                                                                  .findRenderObject()
                                                              as RenderBox;
                                                      Offset localDelta =
                                                          renderBox.globalToLocal(
                                                            details
                                                                .globalPosition,
                                                          ) -
                                                          renderBox.globalToLocal(
                                                            details.globalPosition -
                                                                details.delta,
                                                          );
                                                      item.offset += Offset(
                                                        localDelta.dx /
                                                            renderBox
                                                                .size
                                                                .width,
                                                        localDelta.dy /
                                                            renderBox
                                                                .size
                                                                .height,
                                                      );
                                                    });
                                                  }
                                                },
                                                onTap: () {
                                                  if (_activeTab == "Text") {
                                                    setState(() {
                                                      _activeTextItem = item;
                                                      _textEditorController
                                                              .text =
                                                          item.text;
                                                    });
                                                  }
                                                },
                                                child: Stack(
                                                  clipBehavior: Clip.none,
                                                  alignment: Alignment.center,
                                                  children: [
                                                    Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            horizontal:
                                                                16 * scaleRatio,
                                                            vertical:
                                                                8 * scaleRatio,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: bgColor,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8 * scaleRatio,
                                                            ),
                                                        border: isActive
                                                            ? Border.all(
                                                                color: Colors
                                                                    .white,
                                                                width: 2,
                                                              )
                                                            : Border.all(
                                                                color: Colors
                                                                    .transparent,
                                                                width: 2,
                                                              ),
                                                      ),
                                                      child: IntrinsicWidth(
                                                        child: Stack(
                                                          alignment:
                                                              Alignment.center,
                                                          children: [
                                                            if (item.appearance ==
                                                                3)
                                                              Text(
                                                                item
                                                                        .text
                                                                        .isEmpty
                                                                    ? "Text"
                                                                    : item.text,
                                                                textAlign: item
                                                                    .alignment,
                                                                style: TextStyle(
                                                                  fontSize:
                                                                      scaledFontSize,
                                                                  fontFamily:
                                                                      item.font,
                                                                  fontWeight:
                                                                      item.isBold
                                                                      ? FontWeight
                                                                            .bold
                                                                      : FontWeight
                                                                            .normal,
                                                                  fontStyle:
                                                                      item.isItalic
                                                                      ? FontStyle
                                                                            .italic
                                                                      : FontStyle
                                                                            .normal,
                                                                  decoration:
                                                                      decoration,
                                                                  foreground: Paint()
                                                                    ..style =
                                                                        PaintingStyle
                                                                            .stroke
                                                                    ..strokeWidth =
                                                                        scaledFontSize *
                                                                        0.25
                                                                    ..strokeJoin =
                                                                        StrokeJoin
                                                                            .round
                                                                    ..strokeCap =
                                                                        StrokeCap
                                                                            .round
                                                                    ..color = item
                                                                        .color,
                                                                ),
                                                              ),
                                                            TextField(
                                                              controller:
                                                                  isActive
                                                                  ? _textEditorController
                                                                  : TextEditingController(
                                                                      text: item
                                                                          .text,
                                                                    ),
                                                              enabled: isActive,
                                                              autofocus:
                                                                  isActive,
                                                              textAlign: item
                                                                  .alignment,
                                                              maxLines: null,
                                                              cursorColor:
                                                                  textColor,
                                                              onChanged:
                                                                  (
                                                                    val,
                                                                  ) => setState(
                                                                    () =>
                                                                        item.text =
                                                                            val,
                                                                  ),
                                                              style: TextStyle(
                                                                color:
                                                                    textColor,
                                                                fontSize:
                                                                    scaledFontSize,
                                                                fontFamily:
                                                                    item.font,
                                                                fontWeight:
                                                                    item.isBold
                                                                    ? FontWeight
                                                                          .bold
                                                                    : FontWeight
                                                                          .normal,
                                                                fontStyle:
                                                                    item.isItalic
                                                                    ? FontStyle
                                                                          .italic
                                                                    : FontStyle
                                                                          .normal,
                                                                decoration:
                                                                    decoration,
                                                                decorationColor:
                                                                    textColor,
                                                                shadows:
                                                                    item.appearance ==
                                                                        0
                                                                    ? [
                                                                        Shadow(
                                                                          color:
                                                                              Colors.black54,
                                                                          blurRadius:
                                                                              4,
                                                                          offset: Offset(
                                                                            1,
                                                                            1,
                                                                          ),
                                                                        ),
                                                                      ]
                                                                    : null,
                                                              ),
                                                              decoration: InputDecoration(
                                                                isDense: true,
                                                                contentPadding:
                                                                    EdgeInsets
                                                                        .zero,
                                                                border:
                                                                    InputBorder
                                                                        .none,
                                                                hintText:
                                                                    isActive
                                                                    ? "Text"
                                                                    : "",
                                                                hintStyle: TextStyle(
                                                                  color:
                                                                      item.appearance ==
                                                                          3
                                                                      ? Colors
                                                                            .transparent
                                                                      : Colors
                                                                            .white54,
                                                                  fontSize:
                                                                      scaledFontSize,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    if (isActive)
                                                      Positioned(
                                                        bottom: -10,
                                                        right: -10,
                                                        child: GestureDetector(
                                                          onPanUpdate: (details) {
                                                            setState(() {
                                                              item.rotation +=
                                                                  details
                                                                      .delta
                                                                      .dx *
                                                                  0.015;
                                                            });
                                                          },
                                                          child: Transform.rotate(
                                                            angle:
                                                                -item.rotation,
                                                            child: Container(
                                                              width: 28,
                                                              height: 28,
                                                              decoration: BoxDecoration(
                                                                color: Colors
                                                                    .white,
                                                                shape: BoxShape
                                                                    .circle,
                                                                border: Border.all(
                                                                  color: Colors
                                                                      .blueAccent,
                                                                  width: 2,
                                                                ),
                                                                boxShadow: const [
                                                                  BoxShadow(
                                                                    color: Colors
                                                                        .black26,
                                                                    blurRadius:
                                                                        4,
                                                                  ),
                                                                ],
                                                              ),
                                                              child: const Icon(
                                                                Icons
                                                                    .rotate_right_rounded,
                                                                color: Colors
                                                                    .blueAccent,
                                                                size: 18,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    if (isActive)
                                                      Positioned(
                                                        top: -10,
                                                        left: -10,
                                                        child: GestureDetector(
                                                          onTap: () {
                                                            setState(() {
                                                              _textItems.remove(
                                                                item,
                                                              );
                                                              _activeTextItem =
                                                                  null;
                                                            });
                                                          },
                                                          child: Transform.rotate(
                                                            angle:
                                                                -item.rotation,
                                                            child: Container(
                                                              width: 25,
                                                              height: 25,
                                                              decoration: BoxDecoration(
                                                                color: Colors
                                                                    .redAccent,
                                                                shape: BoxShape
                                                                    .circle,
                                                                border: Border.all(
                                                                  color: Colors
                                                                      .white,
                                                                  width: 2,
                                                                ),
                                                                boxShadow: const [
                                                                  BoxShadow(
                                                                    color: Colors
                                                                        .black26,
                                                                    blurRadius:
                                                                        4,
                                                                  ),
                                                                ],
                                                              ),
                                                              child: const Icon(
                                                                Icons
                                                                    .close_rounded,
                                                                color: Colors
                                                                    .white,
                                                                size: 16,
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
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                              ),

                              // 🚨 4. SHAPE LAYER (FIXED FOR DYNAMIC SCALING)
                              Positioned.fill(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    double canvasW = constraints.maxWidth;
                                    double canvasH = constraints.maxHeight;

                                    // 🚨 FIX: Text ke jaisa hi scale ratio calculate karo (400.0 tumhara base reference hai)
                                    double scaleRatio = canvasW / 400.0;

                                    return Stack(
                                      clipBehavior: Clip.none,
                                      children: _shapeItems.map((shape) {
                                        bool isActive =
                                            _activeShapeItem == shape;

                                        // 🚨 FIX: Icon size ko scaleRatio se multiply karo
                                        double scaledIconSize =
                                            shape.size * scaleRatio;

                                        return Positioned(
                                          left: shape.offset.dx * canvasW,
                                          top: shape.offset.dy * canvasH,
                                          child: FractionalTranslation(
                                            translation: const Offset(
                                              -0.5,
                                              -0.5,
                                            ),
                                            child: Transform.rotate(
                                              angle: shape.rotation,
                                              child: GestureDetector(
                                                behavior:
                                                    HitTestBehavior.translucent,
                                                onPanUpdate: (details) {
                                                  setState(() {
                                                    shape.offset += Offset(
                                                      details.delta.dx /
                                                          canvasW,
                                                      details.delta.dy /
                                                          canvasH,
                                                    );
                                                  });
                                                },
                                                onTap: () => setState(() {
                                                  _activeShapeItem = shape;
                                                  _activeTextItem = null;
                                                }),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    24,
                                                  ),
                                                  child: Stack(
                                                    clipBehavior: Clip.none,
                                                    alignment: Alignment.center,
                                                    children: [
                                                      // Border aur Shape
                                                      // Container(
                                                      //   padding:
                                                      //       const EdgeInsets.all(
                                                      //         8,
                                                      //       ),
                                                      //   decoration: isActive
                                                      //       ? BoxDecoration(
                                                      //           border: Border.all(
                                                      //             color: Colors
                                                      //                 .white,
                                                      //             width: 2,
                                                      //           ),
                                                      //         )
                                                      //       : null,
                                                      //   // 🚨 FIX: scaledIconSize ab variable ke roop mein yahan active hai
                                                      //   child: Icon(
                                                      //     shape.icon,
                                                      //     color: shape.color,
                                                      //     size:
                                                      //         shape.size *
                                                      //         (canvasW /
                                                      //             400.0), // ScaleRatio yahi apply kar diya
                                                      //   ),
                                                      // ),

                                                      // Border aur Shape
                                                      Container(
                                                        padding: const EdgeInsets.all(8),
                                                        decoration: isActive
                                                            ? BoxDecoration(
                                                          border: Border.all(color: Colors.white, width: 2),
                                                        )
                                                            : null,
                                                        // 🚨 NAYA TAREKA (Shrink, Stretch, Mirror ke liye)
                                                        child: SizedBox(
                                                          // Canvas ke scale ratio ke saath height/width set kiya
                                                          width: (shape.size * shape.scaleX.abs()) * (canvasW / 400.0),
                                                          height: (shape.size * shape.scaleY.abs()) * (canvasW / 400.0),
                                                          child: FittedBox(
                                                            fit: BoxFit.fill, // Icon ko is box ke hisaab se stretch karega
                                                            child: Transform.scale(
                                                              // Agar negative hui width/height toh flip (mirror) ho jayega
                                                              scaleX: shape.scaleX < 0 ? -1.0 : 1.0,
                                                              scaleY: shape.scaleY < 0 ? -1.0 : 1.0,
                                                              child: Icon(
                                                                shape.icon,
                                                                color: shape.color,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),

                                                      // Rotate Handle
                                                      // if (isActive)
                                                      //   Positioned(
                                                      //     bottom: -10,
                                                      //     right: -10,
                                                      //     child: GestureDetector(
                                                      //       behavior:
                                                      //           HitTestBehavior
                                                      //               .opaque,
                                                      //       onPanUpdate:
                                                      //           (
                                                      //             details,
                                                      //           ) => setState(
                                                      //             () => shape.rotation +=
                                                      //                 details
                                                      //                     .delta
                                                      //                     .dx *
                                                      //                 0.015,
                                                      //           ),
                                                      //       child: const CircleAvatar(
                                                      //         radius: 14,
                                                      //         backgroundColor:
                                                      //             Colors.white,
                                                      //         child: Icon(
                                                      //           Icons
                                                      //               .rotate_right_rounded,
                                                      //           color: Colors
                                                      //               .blueAccent,
                                                      //           size: 18,
                                                      //         ),
                                                      //       ),
                                                      //     ),
                                                      //   ),
                                                      if (isActive)
                                                        Positioned(
                                                          bottom: -10,
                                                          right: -10,
                                                          child: GestureDetector(
                                                            behavior: HitTestBehavior.opaque,
                                                            onPanUpdate: (details) => setState(
                                                                  () => shape.rotation += details.delta.dx * 0.015,
                                                            ),
                                                            child: Container(
                                                              width: 28,
                                                              height: 28,
                                                              decoration: BoxDecoration(
                                                                color: Colors.white,
                                                                shape: BoxShape.circle,
                                                                border: Border.all(
                                                                  color: Colors.black,
                                                                  width: 1,
                                                                ),
                                                              ),
                                                              child: const Icon(
                                                                Icons.rotate_right_rounded,
                                                                color: Colors.blueAccent,
                                                                size: 18,
                                                              ),
                                                            ),
                                                          ),
                                                        ),

                                                      // Delete Handle
                                                      // if (isActive)
                                                      //   Positioned(
                                                      //     top: -10,
                                                      //     left: -10,
                                                      //     child: GestureDetector(
                                                      //       behavior:
                                                      //           HitTestBehavior
                                                      //               .opaque,
                                                      //       onTap: () =>
                                                      //           setState(() {
                                                      //             _shapeItems
                                                      //                 .remove(
                                                      //                   shape,
                                                      //                 );
                                                      //             _activeShapeItem =
                                                      //                 null;
                                                      //           }),
                                                      //       child: const CircleAvatar(
                                                      //         radius: 12,
                                                      //         backgroundColor:
                                                      //             Colors
                                                      //                 .redAccent,
                                                      //         child: Icon(
                                                      //           Icons
                                                      //               .close_rounded,
                                                      //           color: Colors
                                                      //               .white,
                                                      //           size: 16,
                                                      //         ),
                                                      //       ),
                                                      //     ),
                                                      //   ),

                                                      if (isActive)
                                                        Positioned(
                                                          top: -10,
                                                          left: -10,
                                                          child: GestureDetector(
                                                            behavior: HitTestBehavior.opaque,
                                                            onTap: () => setState(() {
                                                              _shapeItems.remove(shape);
                                                              _activeShapeItem = null;
                                                            }),
                                                            child: Container(
                                                              width: 24,
                                                              height: 24,
                                                              decoration: BoxDecoration(
                                                                color: Colors.redAccent,
                                                                shape: BoxShape.circle,
                                                                border: Border.all(
                                                                  color: Colors.white,
                                                                  width: 1,
                                                                ),
                                                              ),
                                                              child: const Icon(
                                                                Icons.close_rounded,
                                                                color: Colors.white,
                                                                size: 16,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      // --- STRETCH / SHRINK / MIRROR HANDLE (Bottom-Left) ---
                                                      if (isActive)
                                                        Positioned(
                                                          left: -12,
                                                          bottom: -12,
                                                          child: GestureDetector(
                                                            behavior: HitTestBehavior.opaque,
                                                            onPanUpdate: (details) {
                                                              setState(() {
                                                                double sensitivity = 0.01;

                                                                double newScaleX = shape.scaleX - (details.delta.dx * sensitivity);
                                                                double newScaleY = shape.scaleY + (details.delta.dy * sensitivity);

                                                                // 🚨 FIX: Shape ko exactly 0 (invisible) hone se roko
                                                                if (newScaleX.abs() < 0.1) newScaleX = newScaleX < 0 ? -0.1 : 0.1;
                                                                if (newScaleY.abs() < 0.1) newScaleY = newScaleY < 0 ? -0.1 : 0.1;

                                                                shape.scaleX = newScaleX;
                                                                shape.scaleY = newScaleY;
                                                              });
                                                            },
                                                            child: Container(
                                                              padding: const EdgeInsets.all(5),
                                                              decoration: BoxDecoration(
                                                                  color: Colors.white,
                                                                  shape: BoxShape.circle,
                                                                  border: Border.all(color: Colors.black, width: 1),
                                                              ),
                                                              child: const Icon(Icons.open_in_full_rounded, color: Colors.blueAccent, size: 14),
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  },
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

              // --- 2. SETTINGS PANEL (Animated Hide/Show) ---
              Container(
                color: const Color(0xFF2C2C2C),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E1E1E), // Panel ka color
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(
                          24,
                        ), // Ab ye rounded corners ekdum clear dikhenge!
                      ),
                    ),
                    // Agar hidden hai, toh padding hata do
                    padding: _isPanelHidden
                        ? const EdgeInsets.only(top: 8, bottom: 6)
                        : const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 6,
                          ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 🚨 DRAG/TAP HANDLE: Ise drag ya tap karne se panel khulega/band hoga
                        GestureDetector(
                          onTap: () =>
                              setState(() => _isPanelHidden = !_isPanelHidden),
                          onVerticalDragEnd: (details) {
                            if (details.primaryVelocity! > 0) {
                              // Niche drag kiya (Hide)
                              setState(() => _isPanelHidden = true);
                            } else if (details.primaryVelocity! < 0) {
                              // Upar drag kiya (Show)
                              setState(() => _isPanelHidden = false);
                            }
                          },
                          // Invisible touch area bada karne ke liye
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: double.infinity,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.only(bottom: 12, top: 8),
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white30,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),

                        // Agar hidden nahi hai, toh baaki panel dikhao
                        if (!_isPanelHidden) _buildSettingsPanel(),
                      ],
                    ),
                  ),
                ),
              ),

              // --- 3. BOTTOM TABS ---
              Container(
                height: 60,
                color: Colors.black,
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
      ),
    );
  }

  Widget _buildBottomTab(String title, IconData icon) {
    bool isSelected = _activeTab == title;
    return GestureDetector(
      // 🚨 FIX 1: Opaque lagane se icon/text ke beech ki khaali jagah par bhi click kaam karega
      behavior: HitTestBehavior.opaque,
      //onTap: () => setState(() => _activeTab = title),
      onTap: () {
        _unfocusAll(); // 🚨 Jab bhi tab switch ho, saara focus clear karo
        setState(() => _activeTab = title);
      },
      // 🚨 FIX 2: Padding lagakar invisible touch area bada kar diya
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blueAccent : Colors.white54,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.blueAccent : Colors.white54,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 🚨 BASE PANEL MANAGER ---
  Widget _buildSettingsPanel() {
    if (_activeTab == "Drawing") {
      return _buildDrawingPanel(); // Drawing widget load hoga
    } else if (_activeTab == "Text") {
      return _buildTextPanel(); // Text widget load hoga (Blank)
    } else if (_activeTab == "Shapes") {
      return _buildShapesPanel(); // Shapes widget load hoga (Blank)
    }
    return const SizedBox.shrink();
  }

  // --- 1. DRAWING WIDGET PANEL ---
  Widget _buildDrawingPanel() {
    bool canEraseOrClear = _paths.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- TOP ROW: Color Picker & Tools ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (!_isEraserMode)
              Row(
                children: [
                  const Text(
                    "Color",
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _openColorPicker,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _selectedColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  // const SizedBox(width: 16),
                  // GestureDetector(
                  //   onTap: _openColorPicker,
                  //   child: const Icon(
                  //     Icons.colorize_rounded,
                  //     color: Colors.white70,
                  //     size: 24,
                  //   ),
                  // ),
                ],
              )
            else
              const Text(
                "Eraser Mode",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),

            Row(
              children: [
                Tooltip(
                  message: "Pen",
                  child: GestureDetector(
                    onTap: () => setState(() => _isEraserMode = false),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: !_isEraserMode
                            ? Colors.blueAccent.withOpacity(0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Symbols.stylus_note,
                        color: !_isEraserMode
                            ? Colors.blueAccent
                            : Colors.white70,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: "Eraser",
                  child: GestureDetector(
                    onTap: canEraseOrClear
                        ? () => setState(() => _isEraserMode = true)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _isEraserMode
                            ? Colors.blueAccent.withOpacity(0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Symbols.ink_eraser_rounded,
                        color: canEraseOrClear
                            ? (_isEraserMode
                                  ? Colors.blueAccent
                                  : Colors.white70)
                            : Colors.white38,
                        size: 24,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 4),
                Tooltip(
                  message: "Clear All",
                  child: GestureDetector(
                    onTap: canEraseOrClear
                        ? () {
                            setState(() {
                              _paths.add(
                                DrawnPath(
                                  points: [],
                                  color: Colors.transparent,
                                  strokeWidth: 0,
                                  opacity: 0,
                                  isClear: true,
                                ),
                              );
                            });
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: canEraseOrClear
                            ? Colors.redAccent
                            : Colors.white38,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        // --- SLIDERS ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Stroke width",
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            Text(
              "${_strokeWidth.toInt()}",
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            activeTrackColor: Colors.grey.shade400,
            inactiveTrackColor: Colors.grey.shade800,
            thumbColor: Colors.white,
          ),
          child: Slider(
            value: _strokeWidth,
            min: 1,
            max: 50,
            onChanged: (val) => setState(() => _strokeWidth = val),
          ),
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Opacity",
              style: TextStyle(
                color: _isEraserMode ? Colors.white38 : Colors.white,
                fontSize: 14,
              ),
            ),
            Text(
              "${(_opacity * 100).toInt()}%",
              style: TextStyle(
                color: _isEraserMode ? Colors.white38 : Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            activeTrackColor: Colors.grey.shade400,
            inactiveTrackColor: Colors.grey.shade800,
            thumbColor: Colors.white,
            disabledThumbColor: Colors.grey.shade800,
            disabledActiveTrackColor: Colors.grey.shade800,
          ),
          child: Slider(
            value: _opacity,
            min: 0.1,
            max: 1.0,
            onChanged: _isEraserMode
                ? null
                : (val) => setState(() => _opacity = val),
          ),
        ),
      ],
    );
  }

  // --- 2. TEXT WIDGET PANEL ---
  Widget _buildTextPanel() {
    // 🚨 FIX: Agar koi text select hai toh use lo, warna humara naya '_draftTextItem' use karo
    TextOverlayItem activeItem = _activeTextItem ?? _draftTextItem;
    bool hasActiveText =
        _activeTextItem !=
        null; // Yeh check karne ke liye ki text asli mein select hai ya nahi

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- 1ST ROW: Delete (Left) | Font (Middle) | Add Text (Right) ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => setState(() {
                int idx = _fonts.indexOf(activeItem.font);
                activeItem.font = _fonts[(idx + 1) % _fonts.length];
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white54),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  activeItem.font,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () {
                setState(() {
                  final newItem = activeItem.clone();
                  newItem.text = "";
                  // 🚨 MAIN FIX: Ab offset sirf percentage (0.5 = center) use karega
                  newItem.offset = const Offset(0.5, 0.5);
                  _textItems.add(newItem);
                  _activeTextItem = newItem;
                  _textEditorController.text = newItem.text;
                });
              },
              icon: const Icon(Icons.add, color: Colors.white, size: 16),
              label: const Text("Add", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // --- 2ND ROW: Size Slider ---
        Row(
          children: [
            const Text(
              "T",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  thumbColor: Colors.white,
                  activeTrackColor: Colors.grey.shade400,
                  inactiveTrackColor: Colors.grey.shade800,
                ),
                child: Slider(
                  value: activeItem.fontSize,
                  min: 12,
                  max: 100,
                  onChanged: (val) => setState(() => activeItem.fontSize = val),
                ),
              ),
            ),
            const Text(
              "T",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // --- 3RD ROW: Scrollable Tools (A, Bold, Underline, Italic, Strike, Duplicate) ---
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              // Appearance (A) - 4 Modes
              GestureDetector(
                onTap: () => setState(
                  () => activeItem.appearance = (activeItem.appearance + 1) % 4,
                ),
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: activeItem.appearance == 1
                        ? Colors.white
                        : (activeItem.appearance == 2
                              ? Colors.white38
                              : Colors.transparent),
                    border: Border.all(color: Colors.white),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (activeItem.appearance == 3)
                        Text(
                          "A",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            foreground: Paint()
                              ..style = PaintingStyle.stroke
                              ..strokeWidth = 2.5
                              ..color = Colors.white,
                          ),
                        ),
                      Text(
                        "A",
                        style: TextStyle(
                          color:
                              (activeItem.appearance == 1 ||
                                  activeItem.appearance == 2)
                              ? Colors.black
                              : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () =>
                    setState(() => activeItem.isBold = !activeItem.isBold),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: activeItem.isBold
                        ? Colors.blueAccent.withOpacity(0.3)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.format_bold_rounded,
                    color: activeItem.isBold ? Colors.blueAccent : Colors.white,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(
                  () => activeItem.isUnderline = !activeItem.isUnderline,
                ),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: activeItem.isUnderline
                        ? Colors.blueAccent.withOpacity(0.3)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.format_underlined_rounded,
                    color: activeItem.isUnderline
                        ? Colors.blueAccent
                        : Colors.white,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () =>
                    setState(() => activeItem.isItalic = !activeItem.isItalic),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: activeItem.isItalic
                        ? Colors.blueAccent.withOpacity(0.3)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.format_italic_rounded,
                    color: activeItem.isItalic
                        ? Colors.blueAccent
                        : Colors.white,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(
                  () =>
                      activeItem.isStrikethrough = !activeItem.isStrikethrough,
                ),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: activeItem.isStrikethrough
                        ? Colors.blueAccent.withOpacity(0.3)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.format_strikethrough_rounded,
                    color: activeItem.isStrikethrough
                        ? Colors.blueAccent
                        : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Duplicate (Agar text select nahi hai, toh disable rahega)
              GestureDetector(
                onTap: hasActiveText
                    ? () => setState(() {
                        TextOverlayItem duplicateItem = _activeTextItem!
                            .clone();
                        _textItems.add(duplicateItem);
                        _activeTextItem = duplicateItem;
                        _textEditorController.text = duplicateItem.text;
                      })
                    : null,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 36,
                  height: 36,
                  child: Icon(
                    Icons.content_copy_rounded,
                    color: hasActiveText ? Colors.white : Colors.white38,
                  ),
                ),
              ),

              GestureDetector(
                onTap: hasActiveText
                    ? () => setState(() {
                        _textItems.remove(_activeTextItem);
                        _activeTextItem = null;
                      })
                    : null,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 36,
                  height: 36,
                  child: Icon(
                    Icons.delete_forever_rounded, // 🚨 Delete icon
                    color: hasActiveText ? Colors.redAccent : Colors.white38,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // --- 4TH ROW: Colors Array ---
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children:
                [
                  Colors.white,
                  Colors.black,
                  Colors.grey.shade400,
                  Colors.redAccent,
                  Colors.pinkAccent,
                  Colors.purpleAccent,
                  Colors.blueAccent,
                  Colors.lightBlueAccent,
                  Colors.cyanAccent,
                  Colors.tealAccent,
                  Colors.greenAccent,
                  Colors.yellowAccent,
                  Colors.amberAccent,
                  Colors.orangeAccent,
                  Colors.brown,
                ].map((c) {
                  bool isSelected = activeItem.color == c;
                  Color iconColor = c.computeLuminance() > 0.5
                      ? Colors.black
                      : Colors.white;

                  return GestureDetector(
                    onTap: () => setState(() => activeItem.color = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: isSelected ? 34 : 26,
                      height: isSelected ? 34 : 26,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: isSelected ? 2.5 : 1.5,
                        ),
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check_rounded,
                              color: iconColor,
                              size: 20,
                            )
                          : null,
                    ),
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildShapesPanel() {
    // Shape ke liye temporary state variables (tum inhe class-level pe move kar sakte ho)
    // Abhi ke liye hum generic variables use kar rahe hain

    final active = _activeShapeItem;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Top Row: Color Picker (Left) | Copy & Delete (Right)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  "Color",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _openColorPicker,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _selectedColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
            // Row(
            //   children: [
            //     IconButton(
            //       icon: const Icon(
            //         Icons.content_copy_rounded,
            //         color: Colors.white,
            //       ),
            //       onPressed: () {
            //         /* Copy logic */
            //       },
            //     ),
            //     IconButton(
            //       icon: const Icon(
            //         Icons.delete_forever_rounded,
            //         color: Colors.redAccent,
            //       ),
            //       onPressed: () {
            //         /* Delete logic */
            //       },
            //     ),
            //   ],
            // ),
            Row(
              children: [
                // --- COPY BUTTON ---
                IconButton(
                  icon: Icon(
                    Icons.content_copy_rounded,
                    // 🚨 Shape select nahi hai toh icon dull dikhega
                    color: _activeShapeItem != null ? Colors.white : Colors.white38,
                  ),
                  onPressed: _activeShapeItem != null
                      ? () {
                    setState(() {
                      // 🚨 Duplicate shape create karo
                      final copy = ShapeItem(
                        icon: _activeShapeItem!.icon,
                        color: _activeShapeItem!.color,
                        size: _activeShapeItem!.size,
                        rotation: _activeShapeItem!.rotation,
                        // Original shape se thoda side mein add karo (offset)
                        offset: _activeShapeItem!.offset + const Offset(0.05, 0.05),
                        scaleX: _activeShapeItem!.scaleX, // 🚨 NAYA ADD KIYA
                        scaleY: _activeShapeItem!.scaleY, // 🚨 NAYA ADD KIYA
                      );
                      _shapeItems.add(copy);
                      _activeShapeItem = copy; // Naya copy select ho jayega
                    });
                  }
                      : null, // Shape select nahi hai toh tap disable
                ),

                // --- DELETE BUTTON ---
                IconButton(
                  icon: Icon(
                    Icons.delete_forever_rounded,
                    // 🚨 Shape select nahi hai toh icon dull dikhega
                    color: _activeShapeItem != null ? Colors.redAccent : Colors.white38,
                  ),
                  onPressed: _activeShapeItem != null
                      ? () {
                    setState(() {
                      // 🚨 Selected shape delete karo
                      _shapeItems.remove(_activeShapeItem);
                      _activeShapeItem = null;
                    });
                  }
                      : null, // Shape select nahi hai toh tap disable
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        _buildSlider("Size", active?.size ?? 100.0, 20, 200, (val) {
          setState(() {
            if (active != null) active.size = val;
          });
        }),

        const SizedBox(height: 10),
        // 4. 4th Row: Scrollable Shapes
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              // --- Basic Geometry ---
              _buildShapeIcon(Icons.rectangle_outlined),
              _buildShapeIcon(Icons.crop_square_rounded), // Square
              _buildShapeIcon(Icons.circle_outlined),
              _buildShapeIcon(Icons.change_history_rounded), // Triangle
              _buildShapeIcon(Icons.pentagon_outlined),
              _buildShapeIcon(Icons.hexagon_outlined),

              // --- Arrows ---
              _buildShapeIcon(Icons.arrow_forward_rounded), // Right Arrow
              _buildShapeIcon(Icons.arrow_back_rounded), // Left Arrow
              _buildShapeIcon(Icons.arrow_upward_rounded), // Up Arrow
              _buildShapeIcon(Icons.sync_alt_rounded), // Double Arrow (Left-Right)

              // --- Objects & Symbols ---
              _buildShapeIcon(Icons.star_border_rounded), // Star
              _buildShapeIcon(Icons.favorite_border_rounded), // Heart
              _buildShapeIcon(Icons.shield_outlined), // Shield
              _buildShapeIcon(Icons.cloud_queue_rounded), // Cloud

              // --- Markup / Annotation ---
              _buildShapeIcon(Icons.chat_bubble_outline_rounded), // Speech Bubble / Callout
              _buildShapeIcon(Icons.check_rounded), // Tick / Right mark
              _buildShapeIcon(Icons.close_rounded), // Cross / Wrong mark
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildSlider(
    String label,
    double val,
    double min,
    double max,
    Function(double) onChanged,
  ) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbColor: Colors.white,
              activeTrackColor: Colors.grey.shade400,
              inactiveTrackColor: Colors.grey.shade800,
            ),
            child: Slider(
              value: val.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // Shape Icon Helper
  Widget _buildShapeIcon(IconData icon) {
    bool isSelected =
        _selectedShape == icon.toString(); // Tumhara shape state variable
    return GestureDetector(
      // onTap: () {
      //   setState(() {
      //     final newShape = ShapeItem(icon: icon, color: _selectedColor);
      //     _shapeItems.add(newShape);
      //     _activeShapeItem = newShape; // Isse shape select ho jayegi
      //   });
      // },
      onTap: () {
        setState(() {
          // 🚨 FIX: Nayi shape banate waqt center offset ensure karo
          final newShape = ShapeItem(
            icon: icon,
            color: _selectedColor,
            offset: const Offset(0.5, 0.5), // Explicitly center
          );
          _shapeItems.add(newShape);
          _activeShapeItem = newShape;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blueAccent.withOpacity(0.2)
              : Colors.transparent,
          border: Border.all(color: Colors.white70),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}

/// end main class

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

    Offset? toPixels(Offset? normalized) {
      if (normalized == null) return null;
      return Offset(normalized.dx * size.width, normalized.dy * size.height);
    }

    // 🚨 FEVICOL FIX 4: Drawing Stroke ki motai (thickness) bhi image ke sath scale hogi
    double strokeScale = size.width / 400.0;

    for (var path in paths) {
      if (path.isClear) {
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..blendMode = BlendMode.clear,
        );
        continue;
      }

      Paint p = Paint()
        ..color = path.isEraser
            ? Colors.transparent
            : path.color.withOpacity(path.opacity)
        ..strokeWidth =
            path.strokeWidth *
            strokeScale // Scaling applied
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..blendMode = path.isEraser ? BlendMode.clear : BlendMode.srcOver;

      for (int i = 0; i < path.points.length - 1; i++) {
        Offset? p1 = toPixels(path.points[i]);
        Offset? p2 = toPixels(path.points[i + 1]);

        if (p1 != null && p2 != null) {
          canvas.drawLine(p1, p2, p);
        } else if (p1 != null && p2 == null) {
          canvas.drawPoints(ui.PointMode.points, [p1], p);
        }
      }
    }

    if (currentPoints.isNotEmpty) {
      Paint p = Paint()
        ..color = isEraser
            ? Colors.transparent
            : currentColor.withOpacity(currentOpacity)
        ..strokeWidth =
            currentStrokeWidth *
            strokeScale // Scaling applied
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..blendMode = isEraser ? BlendMode.clear : BlendMode.srcOver;

      for (int i = 0; i < currentPoints.length - 1; i++) {
        Offset? p1 = toPixels(currentPoints[i]);
        Offset? p2 = toPixels(currentPoints[i + 1]);
        if (p1 != null && p2 != null) {
          canvas.drawLine(p1, p2, p);
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
