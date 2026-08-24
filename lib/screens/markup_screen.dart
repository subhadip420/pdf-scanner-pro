import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

import 'custom_dialog.dart';

class MarkupExportData {
  final List<DrawnPath> paths;
  final List<TextOverlayItem> texts;
  final List<ShapeItem> shapes;

  MarkupExportData({required this.paths, required this.texts, required this.shapes});
}

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

class TextOverlayItem {
  String text;
  Offset offset;
  Color color;
  double fontSize;
  double rotation;
  int appearance;
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

  TextOverlayItem clone() {
    return TextOverlayItem(
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
  IconData icon;
  Offset offset;
  Color color;
  double size;

  double rotation;
  double scaleX = 1.0;
  double scaleY = 1.0;

  ShapeItem({
    required this.icon,
    this.offset = const Offset(0.5, 0.5),
    required this.color,
    this.size = 100.0,
    this.rotation = 0.0,
    this.scaleX = 1.0,
    this.scaleY = 1.0,
  });
}

class MarkupScreen extends StatefulWidget {
  final File imageFile;

  final int rotationTurns;
  final String filterName;
  final double brightness;
  final double contrast;
  final dynamic existingMarkups;

  const MarkupScreen({
    Key? key,
    required this.imageFile,
    this.rotationTurns = 0,
    this.filterName = "Original color",
    this.brightness = 0.0,
    this.contrast = 0.0,
    this.existingMarkups,
  }) : super(key: key);

  @override
  State<MarkupScreen> createState() => _MarkupScreenState();
}

class _MarkupScreenState extends State<MarkupScreen> {
  final GlobalKey _globalKey = GlobalKey();
  final GlobalKey _canvasKey = GlobalKey();

  List<DrawnPath> _paths = [];
  List<DrawnPath> _undonePaths = [];
  List<Offset?> _currentPoints = [];

  Color _selectedColor = Colors.blue;
  double _strokeWidth = 12.0;
  double _opacity = 1.0;

  String _activeTab = "Drawing";
  String _selectedShape = "Triangle";

  bool _isEraserMode = false;
  int _pointerCount = 0;

  List<Color> _recentColors = [];
  bool _isPanelHidden = false;

  List<TextOverlayItem> _textItems = [];
  TextOverlayItem? _activeTextItem;
  bool isHapticEnabled = true;
  TextOverlayItem _draftTextItem = TextOverlayItem(text: "", offset: const Offset(0.5, 0.5), color: Colors.white);
  final TextEditingController _textEditorController = TextEditingController();
  final List<String> _fonts = ['Roboto', 'Serif', 'Monospace', 'Cursive'];

  List<ShapeItem> _shapeItems = [];
  ShapeItem? _activeShapeItem;

  InterstitialAd? _interstitialAd;

  /// TODO Google's Test
  //final String _adUnitId = 'ca-app-pub-3940256099942544/1033173712'; // test ad id
  final String _adUnitId = 'ca-app-pub-5454466291921987/6535973397'; // real ad id

  @override
  void initState() {
    super.initState();
    _loadInterstitialAd();
    _loadRecentColors();
    _loadHapticSetting();
    if (widget.existingMarkups != null && widget.existingMarkups is MarkupExportData) {
      MarkupExportData data = widget.existingMarkups;
      _paths = List.from(data.paths);
      _textItems = List.from(data.texts);
      _shapeItems = List.from(data.shapes);
    }
  }

  @override
  void dispose() {
    _textEditorController.dispose();
    super.dispose();
  }

  Future<void> _loadHapticSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isHapticEnabled = prefs.getBool('pref_haptic') ?? true;
    });
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _finalizeSave();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              _finalizeSave();
            },
          );
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
        },
      ),
    );
  }

  ColorFilter? _getColorFilter(String filterName) {
    switch (filterName) {
      case "Grayscale":
        return const ColorFilter.matrix([
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case "Whiteboard":
        return const ColorFilter.matrix([1.5, 0, 0, 0, 20, 0, 1.5, 0, 0, 20, 0, 0, 1.5, 0, 20, 0, 0, 0, 1, 0]);
      case "Light text":
        return const ColorFilter.matrix([1.2, 0, 0, 0, 10, 0, 1.2, 0, 0, 10, 0, 0, 1.2, 0, 10, 0, 0, 0, 1, 0]);
      case "Auto-color":
        return const ColorFilter.matrix([
          1.2,
          -0.1,
          -0.1,
          0,
          10,
          -0.1,
          1.2,
          -0.1,
          0,
          10,
          -0.1,
          -0.1,
          1.2,
          0,
          10,
          0,
          0,
          0,
          1,
          0,
        ]);
      case "Original color":
      default:
        return null;
    }
  }

  ColorFilter _getAdjustColorFilter(double brightness, double contrast) {
    double b = brightness * 2.55;
    double c = 1.0 + (contrast / 100.0);
    double t = (1.0 - c) * 127.5;
    return ColorFilter.matrix([c, 0, 0, 0, t + b, 0, c, 0, 0, t + b, 0, 0, c, 0, t + b, 0, 0, 0, 1, 0]);
  }

  void _unfocusAll() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _activeTextItem = null;
      _activeShapeItem = null;
    });
  }

  /// ---  SHARED PREFERENCES LOGIC ---
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
    _recentColors.remove(color);
    _recentColors.insert(0, color);

    if (_recentColors.length > 5) {
      _recentColors = _recentColors.sublist(0, 5);
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    //List<String> colorsToSave = _recentColors.map((c) => c.value.toString()).toList();
    List<String> colorsToSave = _recentColors.map((c) => c.toARGB32().toString()).toList();
    await prefs.setStringList('markup_recent_colors', colorsToSave);

    setState(() {});
  }

  Future<bool> _onWillPop() async {
    if (_paths.isEmpty && _textItems.isEmpty && _shapeItems.isEmpty) return true;

    bool discard = await showCustomConfirmDialog(
      context,
      title: "Discard changes",
      message: "Changes you have made with the Markup tool will be discarded.",
      positiveBtnText: "OK",
      negativeBtnText: "Cancel",
      positiveBtnColor: Colors.redAccent,
    );

    return discard;
  }

  Future<void> _handleSaveClick() async {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_interstitialAd != null) {
      _interstitialAd!.show();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator(color: isDarkMode ? Colors.blueAccent : Colors.blue,)),
    );

    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (_interstitialAd != null) break;
    }

    if (mounted) Navigator.pop(context);

    if (_interstitialAd != null) {
      _interstitialAd!.show();
    } else {
      _finalizeSave();
    }
  }

  void _finalizeSave() {
    setState(() {
      _activeTextItem = null;
      _activeShapeItem = null;
      _textItems.removeWhere((item) => item.text.trim().isEmpty);
    });

    final exportData = MarkupExportData(
      paths: List.from(_paths),
      texts: List.from(_textItems),
      shapes: List.from(_shapeItems),
    );

    if (mounted) {
      Navigator.pop(context, exportData);
    }
  }

  Future<void> _openColorPicker() async {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDarkMode ?  const Color(0xFF2C2C2C) :  Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ColorPicker(
                pickerColor: _selectedColor,
                onColorChanged: (color) {
                  setState(() {
                    _selectedColor = color;
                    if (_activeShapeItem != null) {
                      _activeShapeItem!.color = color;
                    }
                  });
                },
                colorPickerWidth: 280,
                pickerAreaHeightPercent: 0.8,
                enableAlpha: false,
                displayThumbColor: true,
                paletteType: PaletteType.hsvWithHue,
                pickerAreaBorderRadius: const BorderRadius.all(Radius.circular(6)),
                hexInputBar: false,
                labelTypes: const [],
              ),
              const SizedBox(height: 5),

              if (_recentColors.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _recentColors
                      .map(
                        (c) => GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedColor = c;
                              if (_activeShapeItem != null) {
                                _activeShapeItem!.color = c;
                              }
                            });
                            Navigator.pop(context);
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: c,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade400, width: 1.5),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                )
              else
                SizedBox(
                  height: 38,
                  child: Center(
                    child: Text("No recent colors", style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54, fontSize: 12)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    _saveRecentColor(_selectedColor);
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // return WillPopScope(
    //   onWillPop: _onWillPop,
    //   child: GestureDetector(
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;

        final bool shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context, result);
        }
      },
      child: GestureDetector(
        onTap: _unfocusAll,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          //backgroundColor: const Color(0xFF1E1E1E),
          backgroundColor: isDarkMode ? const Color(0xFF100F0F) : Colors.white,
          appBar: AppBar(
            //backgroundColor: const Color(0xFF1E1E1E),
            backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFE3E2E2),
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.close_rounded, color: isDarkMode ?  Colors.white : Colors.black, size: 28),
              onPressed: () async {
                if (isHapticEnabled) HapticFeedback.mediumImpact();
                if (await _onWillPop()) {
                  Navigator.pop(context);
                }
              },
            ),
            title: Text(
              "Markup",
              style: TextStyle(color: isDarkMode ?  Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.w500),
            ),
            actions: [
              if (_activeTab == "Drawing") ...[
                Tooltip(
                  message: "Undo",
                  child: IconButton(
                    icon: Icon(Icons.undo_rounded, color: _paths.isNotEmpty
                        ? (isDarkMode ? Colors.white : Colors.black87)
                        : (isDarkMode ? Colors.white38 : Colors.black26)
                    ),
                    onPressed: () {
                      if (isHapticEnabled) HapticFeedback.selectionClick();
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
                    icon: Icon(Icons.redo_rounded, color: _undonePaths.isNotEmpty
                        ? (isDarkMode ? Colors.white : Colors.black87)
                        : (isDarkMode ? Colors.white38 : Colors.black26),
                    ),
                    onPressed: () {
                      if (isHapticEnabled) HapticFeedback.selectionClick();
                      if (isHapticEnabled) HapticFeedback.lightImpact();
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
                icon: Icon(Icons.check_rounded, color: isDarkMode ? Colors.blueAccent : Colors.blue, size: 30),
                //onPressed: _saveMarkup,
                onPressed: _handleSaveClick,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              /// --- MAIN PREVIEW AREA (With Zoom & Draw) ---
              Expanded(
                child: Container(
                  color:  isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 8.0,
                    clipBehavior: Clip.none,
                    panEnabled: true,
                    scaleEnabled: true,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 20),

                        child: RepaintBoundary(
                          key: _globalKey,
                          child: RotatedBox(
                            quarterTurns: widget.rotationTurns,
                            child: Stack(
                              key: _canvasKey,
                              clipBehavior: Clip.none,
                              children: [
                                /// BASE IMAGE (Filters applied)
                                ColorFiltered(
                                  colorFilter: _getAdjustColorFilter(widget.brightness, widget.contrast),
                                  child: ColorFiltered(
                                    colorFilter:
                                        _getColorFilter(widget.filterName) ??
                                        const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                                    child: Image.file(widget.imageFile),
                                  ),
                                ),

                                /// DRAWING LAYER
                                Positioned.fill(
                                  child: Listener(
                                    onPointerDown: (_) {
                                      setState(() {
                                        _pointerCount++;
                                        if (_pointerCount > 1 && _currentPoints.isNotEmpty) {
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
                                    onPointerUp: (_) => setState(() => _pointerCount--),
                                    onPointerCancel: (_) => setState(() => _pointerCount--),
                                    child: GestureDetector(
                                      onPanStart: _pointerCount > 1
                                          ? null
                                          : (details) {
                                              if (_activeTab == "Drawing") {
                                                setState(() {
                                                  RenderBox renderBox =
                                                      _canvasKey.currentContext!.findRenderObject() as RenderBox;
                                                  Offset localPos = renderBox.globalToLocal(details.globalPosition);
                                                  _currentPoints = [
                                                    Offset(
                                                      localPos.dx / renderBox.size.width,
                                                      localPos.dy / renderBox.size.height,
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
                                                      _canvasKey.currentContext!.findRenderObject() as RenderBox;
                                                  Offset localPos = renderBox.globalToLocal(details.globalPosition);
                                                  _currentPoints.add(
                                                    Offset(
                                                      localPos.dx / renderBox.size.width,
                                                      localPos.dy / renderBox.size.height,
                                                    ),
                                                  );
                                                });
                                              }
                                            },
                                      onPanEnd: _pointerCount > 1
                                          ? null
                                          : (details) {
                                              if (_activeTab == "Drawing") {
                                                if (_currentPoints.isEmpty) return;
                                                setState(() {
                                                  _currentPoints.add(null);
                                                  _paths.add(
                                                    DrawnPath(
                                                      points: List.from(_currentPoints),
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

                                /// TEXT LAYER (Auto Scale & Attached to Center)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    ignoring: _activeTab != "Text",
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      double canvasW = constraints.maxWidth;
                                      double canvasH = constraints.maxHeight;
                                      double scaleRatio = canvasW / 400.0;

                                      return Stack(
                                        clipBehavior: Clip.none,
                                        children: _textItems.map((item) {
                                          bool isActive = _activeTextItem == item;
                                          double scaledFontSize = item.fontSize * scaleRatio;

                                          Color textColor = item.appearance == 0
                                              ? item.color
                                              : (item.appearance == 1 || item.appearance == 2)
                                              ? (item.color.computeLuminance() > 0.5 ? Colors.black : Colors.white)
                                              : Colors.white;
                                          Color bgColor = item.appearance == 1
                                              ? item.color
                                              : item.appearance == 2
                                              ? item.color.withValues(alpha:0.5)
                                              : Colors.transparent;

                                          TextDecoration decoration = TextDecoration.none;
                                          if (item.isUnderline && item.isStrikethrough) {
                                            decoration = TextDecoration.combine([
                                              TextDecoration.underline,
                                              TextDecoration.lineThrough,
                                            ]);
                                          } else if (item.isUnderline) {
                                            decoration = TextDecoration.underline;
                                          } else if (item.isStrikethrough) {
                                            decoration = TextDecoration.lineThrough;
                                          }

                                          return Positioned(
                                            left: item.offset.dx * canvasW,
                                            top: item.offset.dy * canvasH,
                                            child: FractionalTranslation(
                                              translation: const Offset(-0.5, -0.5),
                                              child: Transform.rotate(
                                                angle: item.rotation,
                                                child: GestureDetector(
                                                  onPanUpdate: (details) {
                                                    if (_activeTab == "Text") {
                                                      setState(() {
                                                        RenderBox renderBox =
                                                            _canvasKey.currentContext!.findRenderObject() as RenderBox;
                                                        double c = math.cos(item.rotation);
                                                        double s = math.sin(item.rotation);

                                                        double dx = details.delta.dx * c - details.delta.dy * s;
                                                        double dy = details.delta.dx * s + details.delta.dy * c;

                                                        item.offset += Offset(
                                                          dx / renderBox.size.width,
                                                          dy / renderBox.size.height,
                                                        );
                                                      });
                                                    }
                                                  },
                                                  onTap: () {
                                                    if (_activeTab == "Text") {
                                                      setState(() {
                                                        _activeTextItem = item;
                                                        _textEditorController.text = item.text;
                                                      });
                                                    }
                                                  },
                                                  child: Stack(
                                                    clipBehavior: Clip.none,
                                                    alignment: Alignment.center,
                                                    children: [
                                                      Container(
                                                        padding: EdgeInsets.symmetric(
                                                          horizontal: 16 * scaleRatio,
                                                          vertical: 8 * scaleRatio,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: bgColor,
                                                          borderRadius: BorderRadius.circular(8 * scaleRatio),
                                                          border: isActive
                                                              ? Border.all(color: Colors.white, width: 2)
                                                              : Border.all(color: Colors.transparent, width: 2),
                                                        ),
                                                        child: IntrinsicWidth(
                                                          child: Stack(
                                                            alignment: Alignment.center,
                                                            children: [
                                                              if (item.appearance == 3)
                                                                Text(
                                                                  item.text.isEmpty ? "Text" : item.text,
                                                                  textAlign: item.alignment,
                                                                  style: TextStyle(
                                                                    fontSize: scaledFontSize,
                                                                    fontFamily: item.font,
                                                                    fontWeight: item.isBold
                                                                        ? FontWeight.bold
                                                                        : FontWeight.normal,
                                                                    fontStyle: item.isItalic
                                                                        ? FontStyle.italic
                                                                        : FontStyle.normal,
                                                                    decoration: decoration,
                                                                    foreground: Paint()
                                                                      ..style = PaintingStyle.stroke
                                                                      ..strokeWidth = scaledFontSize * 0.25
                                                                      ..strokeJoin = StrokeJoin.round
                                                                      ..strokeCap = StrokeCap.round
                                                                      ..color = item.color,
                                                                  ),
                                                                ),
                                                              TextField(
                                                                controller: isActive
                                                                    ? _textEditorController
                                                                    : TextEditingController(text: item.text),
                                                                enabled: isActive,
                                                                autofocus: isActive,
                                                                textAlign: item.alignment,
                                                                maxLines: null,
                                                                cursorColor: textColor,
                                                                onChanged: (val) => setState(() => item.text = val),
                                                                style: TextStyle(
                                                                  color: textColor,
                                                                  fontSize: scaledFontSize,
                                                                  fontFamily: item.font,
                                                                  fontWeight: item.isBold
                                                                      ? FontWeight.bold
                                                                      : FontWeight.normal,
                                                                  fontStyle: item.isItalic
                                                                      ? FontStyle.italic
                                                                      : FontStyle.normal,
                                                                  decoration: decoration,
                                                                  decorationColor: textColor,
                                                                  shadows: item.appearance == 0
                                                                      ? [
                                                                          Shadow(
                                                                            color: Colors.black54,
                                                                            blurRadius: 4,
                                                                            offset: Offset(1, 1),
                                                                          ),
                                                                        ]
                                                                      : null,
                                                                ),
                                                                decoration: InputDecoration(
                                                                  isDense: true,
                                                                  contentPadding: EdgeInsets.zero,
                                                                  border: InputBorder.none,
                                                                  hintText: isActive ? "Text" : "",
                                                                  hintStyle: TextStyle(
                                                                    color: item.appearance == 3
                                                                        ? Colors.transparent
                                                                        : Colors.white54,
                                                                    fontSize: scaledFontSize,
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
                                                                item.rotation += details.delta.dx * 0.015;
                                                              });
                                                            },
                                                            child: Transform.rotate(
                                                              angle: -item.rotation,
                                                              child: Container(
                                                                width: 28,
                                                                height: 28,
                                                                decoration: BoxDecoration(
                                                                  color: Colors.white,
                                                                  shape: BoxShape.circle,
                                                                  border: Border.all(
                                                                    color: Colors.blueAccent,
                                                                    width: 2,
                                                                  ),
                                                                  boxShadow: const [
                                                                    BoxShadow(color: Colors.black26, blurRadius: 4),
                                                                  ],
                                                                ),
                                                                child: const Icon(
                                                                  Icons.rotate_right_rounded,
                                                                  color: Colors.blueAccent,
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
                                                              if (isHapticEnabled) HapticFeedback.lightImpact();
                                                              setState(() {
                                                                _textItems.remove(item);
                                                                _activeTextItem = null;
                                                              });
                                                            },
                                                            child: Transform.rotate(
                                                              angle: -item.rotation,
                                                              child: Container(
                                                                width: 25,
                                                                height: 25,
                                                                decoration: BoxDecoration(
                                                                  color: Colors.redAccent,
                                                                  shape: BoxShape.circle,
                                                                  border: Border.all(color: Colors.white, width: 2),
                                                                  boxShadow: const [
                                                                    BoxShadow(color: Colors.black26, blurRadius: 4),
                                                                  ],
                                                                ),
                                                                child: const Icon(
                                                                  Icons.close_rounded,
                                                                  color: Colors.white,
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
                                ),

                                /// SHAPE LAYER (FIXED FOR DYNAMIC SCALING)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    ignoring: _activeTab != "Shapes",
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      double canvasW = constraints.maxWidth;
                                      double canvasH = constraints.maxHeight;
                                      //double scaleRatio = canvasW / 400.0;

                                      return Stack(
                                        clipBehavior: Clip.none,
                                        children: _shapeItems.map((shape) {
                                          bool isActive = _activeShapeItem == shape;
                                          //double scaledIconSize = shape.size * scaleRatio;

                                          return Positioned(
                                            left: shape.offset.dx * canvasW,
                                            top: shape.offset.dy * canvasH,
                                            child: FractionalTranslation(
                                              translation: const Offset(-0.5, -0.5),
                                              child: Transform.rotate(
                                                angle: shape.rotation,
                                                child: GestureDetector(
                                                  behavior: HitTestBehavior.translucent,
                                                  onPanUpdate: (details) {
                                                    if (_activeTab == "Shapes") {
                                                      setState(() {
                                                        double angle = -widget.rotationTurns * (math.pi / 2);
                                                        double dx =
                                                            details.delta.dx * math.cos(angle) -
                                                            details.delta.dy * math.sin(angle);
                                                        double dy =
                                                            details.delta.dx * math.sin(angle) +
                                                            details.delta.dy * math.cos(angle);

                                                        shape.offset += Offset(dx / canvasW, dy / canvasH);
                                                      });
                                                    }
                                                  },
                                                  onTap: () {
                                                    if (_activeTab == "Shapes") {
                                                      setState(() {
                                                        _activeShapeItem = shape;
                                                        _activeTextItem = null;
                                                      });
                                                    }
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.all(24),
                                                    child: Stack(
                                                      clipBehavior: Clip.none,
                                                      alignment: Alignment.center,
                                                      children: [
                                                        // Border aur Shape
                                                        Container(
                                                          padding: const EdgeInsets.all(8),
                                                          decoration: isActive
                                                              ? BoxDecoration(
                                                                  border: Border.all(color: Colors.white, width: 2),
                                                                )
                                                              : null,
                                                          child: SizedBox(
                                                            width:
                                                                (shape.size * shape.scaleX.abs()) * (canvasW / 400.0),
                                                            height:
                                                                (shape.size * shape.scaleY.abs()) * (canvasW / 400.0),
                                                            child: FittedBox(
                                                              fit: BoxFit.fill,
                                                              child: Transform.scale(
                                                                scaleX: shape.scaleX < 0 ? -1.0 : 1.0,
                                                                scaleY: shape.scaleY < 0 ? -1.0 : 1.0,
                                                                child: Icon(shape.icon, color: shape.color),
                                                              ),
                                                            ),
                                                          ),
                                                        ),

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
                                                                  border: Border.all(color: Colors.black, width: 1),
                                                                ),
                                                                child: const Icon(
                                                                  Icons.rotate_right_rounded,
                                                                  color: Colors.blueAccent,
                                                                  size: 18,
                                                                ),
                                                              ),
                                                            ),
                                                          ),

                                                        if (isActive)
                                                          Positioned(
                                                            top: -10,
                                                            left: -10,
                                                            child: GestureDetector(
                                                              behavior: HitTestBehavior.opaque,
                                                              onTap: () {
                                                                if (isHapticEnabled) HapticFeedback.lightImpact();
                                                                setState(() {
                                                                  _shapeItems.remove(shape);
                                                                  _activeShapeItem = null;
                                                                });
                                                              },
                                                              child: Container(
                                                                width: 24,
                                                                height: 24,
                                                                decoration: BoxDecoration(
                                                                  color: Colors.redAccent,
                                                                  shape: BoxShape.circle,
                                                                  border: Border.all(color: Colors.white, width: 1),
                                                                ),
                                                                child: const Icon(
                                                                  Icons.close_rounded,
                                                                  color: Colors.white,
                                                                  size: 16,
                                                                ),
                                                              ),
                                                            ),
                                                          ),

                                                        /// --- STRETCH / SHRINK / MIRROR HANDLE (Bottom-Left) ---
                                                        if (isActive)
                                                          Positioned(
                                                            left: -12,
                                                            bottom: -12,
                                                            child: GestureDetector(
                                                              behavior: HitTestBehavior.opaque,
                                                              onPanUpdate: (details) {
                                                                setState(() {
                                                                  double sensitivity = 0.01;

                                                                  double totalAngle =
                                                                      (widget.rotationTurns * (math.pi / 2)) +
                                                                      shape.rotation;
                                                                  double angle = -totalAngle;

                                                                  double dx =
                                                                      details.delta.dx * math.cos(angle) -
                                                                      details.delta.dy * math.sin(angle);
                                                                  double dy =
                                                                      details.delta.dx * math.sin(angle) +
                                                                      details.delta.dy * math.cos(angle);

                                                                  double newScaleX = shape.scaleX - (dx * sensitivity);
                                                                  double newScaleY = shape.scaleY + (dy * sensitivity);

                                                                  if (newScaleX.abs() < 0.1)
                                                                    newScaleX = newScaleX < 0 ? -0.1 : 0.1;
                                                                  if (newScaleY.abs() < 0.1)
                                                                    newScaleY = newScaleY < 0 ? -0.1 : 0.1;

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
                                                                child: const Icon(
                                                                  Icons.open_in_full_rounded,
                                                                  color: Colors.blueAccent,
                                                                  size: 14,
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
                                          );
                                        }).toList(),
                                      );
                                    },
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
              ),

              /// --- SETTINGS PANEL (Animated Hide/Show) ---
              Container(
                color: isDarkMode ? const Color(0xFF2C2C2C) :  Colors.white,
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFEFEBEB),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    padding: _isPanelHidden
                        ? const EdgeInsets.only(top: 8, bottom: 6)
                        : const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (isHapticEnabled) HapticFeedback.lightImpact();
                            setState(() => _isPanelHidden = !_isPanelHidden);
                          },
                          onVerticalDragEnd: (details) {
                            if (details.primaryVelocity! > 0) {
                              setState(() => _isPanelHidden = true);
                            } else if (details.primaryVelocity! < 0) {
                              setState(() => _isPanelHidden = false);
                            }
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: double.infinity,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.only(bottom: 12, top: 8),
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(color: isDarkMode ? Colors.white30 : Colors.black26, borderRadius: BorderRadius.circular(2)),
                            ),
                          ),
                        ),
                        if (!_isPanelHidden) _buildSettingsPanel(),
                      ],
                    ),
                  ),
                ),
              ),

              /// --- BOTTOM TABS ---
              Container(
                height: 65,
                color: isDarkMode ? Colors.black : const Color(0xFFE3E2E2),
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
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    bool isSelected = _activeTab == title;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (isHapticEnabled) HapticFeedback.selectionClick();
        _unfocusAll();
        setState(() => _activeTab = title);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected
                ? (isDarkMode ? Colors.blueAccent : Colors.blue.shade700)
                : (isDarkMode ? Colors.white54 : Colors.black), size: 24),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: isSelected
                ? (isDarkMode ? Colors.blueAccent : Colors.blue.shade700)
                : (isDarkMode ? Colors.white54 : Colors.black), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  /// --- BASE PANEL MANAGER ---
  Widget _buildSettingsPanel() {
    if (_activeTab == "Drawing") {
      return _buildDrawingPanel();
    } else if (_activeTab == "Text") {
      return _buildTextPanel();
    } else if (_activeTab == "Shapes") {
      return _buildShapesPanel();
    }
    return const SizedBox.shrink();
  }

  /// --- DRAWING WIDGET PANEL ---
  Widget _buildDrawingPanel() {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    bool canEraseOrClear = _paths.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        /// --- TOP ROW: Color Picker & Tools ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (!_isEraserMode)
              Row(
                children: [
                  Text("Color", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontSize: 14)),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      if (isHapticEnabled) HapticFeedback.lightImpact();
                      _openColorPicker();
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: _selectedColor, borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              )
            else
              Text("Eraser Mode", style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black, fontSize: 14)),

            Row(
              children: [
                Tooltip(
                  message: "Pen",
                  child: GestureDetector(
                    onTap: () {
                      if (isHapticEnabled) HapticFeedback.selectionClick();
                      setState(() => _isEraserMode = false);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: !_isEraserMode ? Colors.blueAccent.withValues(alpha:0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.draw_rounded,
                        color: !_isEraserMode
                            ? (isDarkMode ? Colors.blueAccent : Colors.blue.shade700)
                            : (isDarkMode ? Colors.white70 : Colors.black54),
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: "Eraser",
                  child: GestureDetector(
                    onTap: canEraseOrClear ? () {
                      if (isHapticEnabled) HapticFeedback.selectionClick();
                      setState(() => _isEraserMode = true);
                    } : null,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _isEraserMode ? Colors.blueAccent.withValues(alpha:0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Symbols.ink_eraser_rounded,
                        color: canEraseOrClear
                            ? (_isEraserMode
                            ? (isDarkMode ? Colors.blueAccent : Colors.blue.shade700)
                            : (isDarkMode ? Colors.white70 : Colors.black54))
                            : (isDarkMode ? Colors.white38 : Colors.black26),
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
                      if (isHapticEnabled) HapticFeedback.selectionClick();
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
                            : (isDarkMode ? Colors.white38 : Colors.black26),
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

        /// --- SLIDERS ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Stroke width", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontSize: 14)),
            Text("${_strokeWidth.toInt()}", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontSize: 14)),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            activeTrackColor: isDarkMode ? Colors.grey.shade400 : Colors.blue.shade700,
            inactiveTrackColor: isDarkMode ? Colors.grey.shade800 : Colors.grey,
            thumbColor: isDarkMode ? Colors.white : Colors.blue,
          ),
          child: Slider(
              value: _strokeWidth, min: 1, max: 50,
            onChanged: (val) {
              if (isHapticEnabled) HapticFeedback.lightImpact();
              setState(() => _strokeWidth = val);
            },
          ),
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Opacity", style: TextStyle(color: _isEraserMode
                ? (isDarkMode ? Colors.white38 : Colors.black26)
                : (isDarkMode ? Colors.white : Colors.black87),
                fontSize: 14)),
            Text(
              "${(_opacity * 100).toInt()}%",
              style: TextStyle(color: _isEraserMode
                  ? (isDarkMode ? Colors.white38 : Colors.black26)
                  : (isDarkMode ? Colors.white : Colors.black87),
                  fontSize: 14),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            activeTrackColor: isDarkMode ? Colors.grey.shade400 : Colors.blue.shade700,
            inactiveTrackColor: isDarkMode ? Colors.grey.shade800 : Colors.grey,
            thumbColor: isDarkMode ? Colors.white : Colors.blue,
            disabledThumbColor: Colors.grey.shade600,
            disabledActiveTrackColor: Colors.grey.shade500,
          ),
          child: Slider(
            value: _opacity,
            min: 0.1,
            max: 1.0,
            onChanged: _isEraserMode ? null : (val) {
              if (isHapticEnabled) HapticFeedback.lightImpact();
              setState(() => _opacity = val);
            },
          ),
        ),
      ],
    );
  }

  /// --- TEXT WIDGET PANEL ---
  Widget _buildTextPanel() {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    TextOverlayItem activeItem = _activeTextItem ?? _draftTextItem;
    bool hasActiveText = _activeTextItem != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => setState(() {
                if (isHapticEnabled) HapticFeedback.selectionClick();
                int idx = _fonts.indexOf(activeItem.font);
                activeItem.font = _fonts[(idx + 1) % _fonts.length];
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  activeItem.font,
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () {
                if (isHapticEnabled) HapticFeedback.lightImpact();
                setState(() {
                  final newItem = activeItem.clone();
                  newItem.text = "";
                  newItem.offset = const Offset(0.5, 0.5);
                  newItem.rotation = -widget.rotationTurns * (math.pi / 2);

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

        /// --- 2ND ROW: Size Slider ---
        Row(
          children: [
            Text("T", style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black, fontSize: 14)),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  thumbColor: isDarkMode ? Colors.white : Colors.blue,
                  activeTrackColor: isDarkMode ? Colors.grey.shade400 : Colors.blue.shade700,
                  inactiveTrackColor: isDarkMode ? Colors.grey.shade800 : Colors.grey,
                ),
                child: Slider(
                  value: activeItem.fontSize,
                  min: 12,
                  max: 100,
                  onChanged: (val) {
                    if (isHapticEnabled) HapticFeedback.lightImpact();
                    setState(() => activeItem.fontSize = val);
                  },
                ),
              ),
            ),
            Text(
              "T",
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),

        /// --- 3RD ROW: Scrollable Tools (A, Bold, Underline, Italic, Strike, Duplicate) ---
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              Tooltip(
                message: "Text Appearance",
                child: GestureDetector(
                  onTap: () {
                    if (isHapticEnabled) HapticFeedback.selectionClick();
                    setState(() => activeItem.appearance = (activeItem.appearance + 1) % 4);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: activeItem.appearance == 1
                          ? (isDarkMode ? Colors.white : Colors.black87)
                          : (activeItem.appearance == 2
                          ? (isDarkMode ? Colors.white38 : Colors.black26)
                          : Colors.transparent),
                      border: Border.all(color: isDarkMode ? Colors.white : Colors.black),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (activeItem.appearance == 3)
                          Text(
                            "T",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              foreground: Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth = 2.5
                                ..color = activeItem.color,
                            ),
                          ),
                        Text(
                          "T",
                          style: TextStyle(
                          color: (activeItem.appearance == 1 || activeItem.appearance == 2)
                              ? (isDarkMode ? Colors.black : Colors.white)
                              : (isDarkMode ? Colors.white : Colors.black),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),

              Tooltip(
                message: "Bold Text",
                child: GestureDetector(
                  onTap: () {
                    if (isHapticEnabled) HapticFeedback.lightImpact();
                    setState(() => activeItem.isBold = !activeItem.isBold);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: activeItem.isBold ? Colors.blueAccent.withValues(alpha:0.3) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.format_bold_rounded,
                        color: activeItem.isBold
                        ? (isDarkMode ? Colors.blueAccent : Colors.blue.shade700)
                        : (isDarkMode ? Colors.white : Colors.black)
                    ),
                  ),
                ),
              ),

              Tooltip(
                message: "Underline Text",
                child: GestureDetector(
                  onTap: () {
                    if (isHapticEnabled) HapticFeedback.lightImpact();
                    setState(() => activeItem.isUnderline = !activeItem.isUnderline);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: activeItem.isUnderline ? Colors.blueAccent.withValues(alpha:0.3) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.format_underlined_rounded,
                      color: activeItem.isUnderline ? (isDarkMode ? Colors.blueAccent : Colors.blue.shade700)
                          : (isDarkMode ? Colors.white : Colors.black),
                    ),
                  ),
                ),
              ),

              Tooltip(
                message: "Italic",
                child: GestureDetector(
                  onTap: () {
                    if (isHapticEnabled) HapticFeedback.lightImpact();
                    setState(() => activeItem.isItalic = !activeItem.isItalic);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: activeItem.isItalic ? Colors.blueAccent.withValues(alpha:0.3) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.format_italic_rounded,
                      color: activeItem.isItalic ? (isDarkMode ? Colors.blueAccent : Colors.blue.shade700)
                          : (isDarkMode ? Colors.white : Colors.black),
                    ),
                  ),
                ),
              ),

              Tooltip(
                message: "Strikethrough",
                child: GestureDetector(
                  onTap: () {
                    if (isHapticEnabled) HapticFeedback.lightImpact();
                    setState(() => activeItem.isStrikethrough = !activeItem.isStrikethrough);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: activeItem.isStrikethrough ? Colors.blueAccent.withValues(alpha:0.3) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.format_strikethrough_rounded,
                      color: activeItem.isStrikethrough ? (isDarkMode ? Colors.blueAccent : Colors.blue.shade700)
                          : (isDarkMode ? Colors.white : Colors.black),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 4),

              Tooltip(
                message: "Rotate 90°",
                child: GestureDetector(
                  onTap: hasActiveText
                      ? () {
                    if (isHapticEnabled) HapticFeedback.lightImpact();
                    setState(() {
                      _activeTextItem!.rotation += (math.pi / 2);
                    });
                  }
                      : null,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 36,
                    height: 36,
                    child: Icon(
                      Icons.rotate_right_rounded,
                      color: hasActiveText
                          ? (isDarkMode ? Colors.white : Colors.black)
                          : (isDarkMode ? Colors.white38 : Colors.black26),
                    )
                  ),
                ),
              ),
              Tooltip(
                message: "Duplicate Text",
                child: GestureDetector(
                  onTap: hasActiveText
                      ? () {
                    if (isHapticEnabled) HapticFeedback.lightImpact();
                    setState(() {
                      TextOverlayItem duplicateItem = _activeTextItem!.clone();
                      _textItems.add(duplicateItem);
                      _activeTextItem = duplicateItem;
                      _textEditorController.text = duplicateItem.text;
                    });
                  }
                      : null,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 36,
                    height: 36,
                    child: Icon(
                      Icons.content_copy_rounded,
                      color: hasActiveText
                          ? (isDarkMode ? Colors.white : Colors.black)
                          : (isDarkMode ? Colors.white38 : Colors.black26),
                    )
                  ),
                ),
              ),

              Tooltip(
                message: "Delete Text",
                child: GestureDetector(
                  onTap: hasActiveText
                      ? () {
                    if (isHapticEnabled) HapticFeedback.lightImpact();
                    setState(() {
                      _textItems.remove(_activeTextItem);
                      _activeTextItem = null;
                    });
                  }
                      : null,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 36,
                    height: 36,
                    child: Icon(Icons.delete_forever_rounded, color: hasActiveText
                        ? Colors.redAccent
                        : (isDarkMode ? Colors.white38 : Colors.black26),),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
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
                        Color iconColor = c.computeLuminance() > 0.5 ? Colors.black : Colors.white;

                        return GestureDetector(
                          onTap: () {
                            if (isHapticEnabled) HapticFeedback.lightImpact();
                            setState(() => activeItem.color = c);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: isSelected ? 34 : 28,
                            height: isSelected ? 34 : 28,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(color: isDarkMode ? Colors.white : Colors.black26, width: isSelected ? 2.5 : 1.5),
                            ),
                            child: isSelected ? Icon(Icons.check_rounded, color: iconColor, size: 20) : null,
                          ),
                        );
                      }).toList(),
                ),
              ),
            ),

            Container(margin: const EdgeInsets.symmetric(horizontal: 8), width: 1.5, height: 28, color: Colors.white24),
            GestureDetector(
              onTap: () async {
                if (isHapticEnabled) HapticFeedback.lightImpact();
                await _openColorPicker();
                setState(() {
                  activeItem.color = _selectedColor;
                });
              },
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: isDarkMode ? Colors.white : Colors.black26, width: 1.5),
                  gradient: const SweepGradient(
                    colors: [
                      Colors.red,
                      Colors.orange,
                      Colors.yellow,
                      Colors.green,
                      Colors.blue,
                      Colors.indigo,
                      Colors.purple,
                      Colors.red,
                    ],
                  ),
                ),
                child: const Icon(Icons.colorize_rounded, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShapesPanel() {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final active = _activeShapeItem;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text("Color", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 14)),
                const SizedBox(width: 16),
                GestureDetector(
                  // onTap: _openColorPicker,
                  onTap: () {
                    if (isHapticEnabled) HapticFeedback.lightImpact();
                    _openColorPicker();
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: _selectedColor, borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                /// --- COPY BUTTON ---
                IconButton(
                  icon: Icon(
                    Icons.content_copy_rounded,
                    color: _activeShapeItem != null
                        ? (isDarkMode ? Colors.white : Colors.black87)
                        : (isDarkMode ? Colors.white38 : Colors.black26),
                  ),
                  onPressed: _activeShapeItem != null
                      ? () {
                          if (isHapticEnabled) HapticFeedback.lightImpact();
                          setState(() {
                            /// Duplicate shape create karo
                            final copy = ShapeItem(
                              icon: _activeShapeItem!.icon,
                              color: _activeShapeItem!.color,
                              size: _activeShapeItem!.size,
                              rotation: _activeShapeItem!.rotation,
                              offset: _activeShapeItem!.offset + const Offset(0.05, 0.05),
                              scaleX: _activeShapeItem!.scaleX,
                              scaleY: _activeShapeItem!.scaleY,
                            );
                            _shapeItems.add(copy);
                            _activeShapeItem = copy;
                          });
                        }
                      : null,
                ),

                /// --- DELETE BUTTON ---
                IconButton(
                  icon: Icon(
                    Icons.delete_forever_rounded,
                    color: _activeShapeItem != null
                        ? Colors.redAccent
                        : (isDarkMode ? Colors.white38 : Colors.black26),
                  ),
                  onPressed: _activeShapeItem != null
                      ? () {
                    if (isHapticEnabled) HapticFeedback.lightImpact();
                          setState(() {
                            _shapeItems.remove(_activeShapeItem);
                            _activeShapeItem = null;
                          });
                        }
                      : null,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 0),

        /// Opacity Slider
        //_buildSlider("Opacity", active?.color.opacity ?? 1.0, 0.1, 1.0, (val) {
        _buildSlider("Opacity", active?.color.a ?? 1.0, 0.1, 1.0, (val) {
          setState(() {
            if (active != null) {
              active.color = active.color.withValues(alpha:val);
            }
          });
        }),

        const SizedBox(height: 0),

        _buildSlider("Size", active?.size ?? 100.0, 20, 500, (val) {
          setState(() {
            if (active != null) active.size = val;
          });
        }),

        const SizedBox(height: 0),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              /// --- Basic Geometry ---
              _buildShapeIcon(Icons.rectangle_outlined),
              _buildShapeIcon(Icons.crop_square_rounded),
              // Square
              _buildShapeIcon(Icons.circle_outlined),
              _buildShapeIcon(Icons.change_history_rounded),
              // Triangle
              _buildShapeIcon(Icons.pentagon_outlined),
              _buildShapeIcon(Icons.hexagon_outlined),

              // --- Arrows ---
              _buildShapeIcon(Icons.arrow_forward_rounded),
              // Right Arrow
              _buildShapeIcon(Icons.arrow_back_rounded),
              // Left Arrow
              _buildShapeIcon(Icons.arrow_upward_rounded),
              // Up Arrow
              _buildShapeIcon(Icons.sync_alt_rounded),
              // Double Arrow (Left-Right)

              /// --- Objects & Symbols ---
              _buildShapeIcon(Icons.star_border_rounded),
              // Star
              _buildShapeIcon(Icons.favorite_border_rounded),
              // Heart
              _buildShapeIcon(Icons.shield_outlined),
              // Shield
              _buildShapeIcon(Icons.cloud_queue_rounded),
              // Cloud

              /// --- Markup / Annotation ---
              _buildShapeIcon(Icons.chat_bubble_outline_rounded),
              // Speech Bubble / Callout
              _buildShapeIcon(Icons.check_rounded),
              // Tick / Right mark
              _buildShapeIcon(Icons.close_rounded),
              // Cross / Wrong mark
            ],
          ),
        ),
        const SizedBox(height: 5),
      ],
    );
  }

  Widget _buildSlider(String label, double val, double min, double max, Function(double) onChanged) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Text(label, style: TextStyle(color: isDarkMode ? Colors.white70  : Colors.black, fontSize: 14)),
        const SizedBox(width: 10),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbColor: isDarkMode ? Colors.white : Colors.blue,
              activeTrackColor: isDarkMode ? Colors.grey.shade400 : Colors.blue.shade700,
              inactiveTrackColor: isDarkMode ? Colors.grey.shade800 : Colors.grey,
            ),
            child: Slider(
              value: val.clamp(min, max),
              min: min,
              max: max,
              onChanged: (newVal) {
                if (isHapticEnabled) HapticFeedback.selectionClick();
                onChanged(newVal);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShapeIcon(IconData icon) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    bool isSelected = _selectedShape == icon.toString();
    return GestureDetector(
      onTap: () {
        if (isHapticEnabled) HapticFeedback.lightImpact();
        setState(() {
          final newShape = ShapeItem(
            icon: icon,
            color: _selectedColor,
            offset: const Offset(0.5, 0.5),
            rotation: -widget.rotationTurns * (math.pi / 2),
          );
          _shapeItems.add(newShape);
          _activeShapeItem = newShape;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent.withValues(alpha:0.2) : Colors.transparent,
          border: Border.all(color: isDarkMode ? Colors.white70 : Colors.black),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: isDarkMode ?  Colors.white : Colors.black54, size: 28),
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

    double strokeScale = size.width / 400.0;

    for (var path in paths) {
      if (path.isClear) {
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..blendMode = BlendMode.clear);
        continue;
      }

      Paint p = Paint()
        ..color = path.isEraser ? Colors.transparent : path.color.withValues(alpha:path.opacity)
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
        ..color = isEraser ? Colors.transparent : currentColor.withValues(alpha:currentOpacity)
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
