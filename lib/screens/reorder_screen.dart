import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// 🚨 NEW: Markup structures aur DrawingPainter use karne ke liye import add kiya
import 'markup_screen.dart';

class ReorderScreen extends StatefulWidget {
  final List<Map<String, dynamic>> imageFiles;

  const ReorderScreen({Key? key, required this.imageFiles}) : super(key: key);

  @override
  State<ReorderScreen> createState() => _ReorderScreenState();
}

class _ReorderScreenState extends State<ReorderScreen> {
  late List<Map<String, dynamic>> _items;
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _items = List.from(widget.imageFiles);
  }

  @override
  void dispose() {
    _bannerAd?.dispose(); // 🚨 Zaroori: Screen close hone par ad ko memory se hatao
    super.dispose();
  }

  // --- BANNER AD FUNCTION ---
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // Test ID
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          print("Reorder Screen Banner failed: $error");
          ad.dispose();
        },
      ),
    )..load();
  }

  // --- REORDER SCREEN COLOR FILTER LOGIC ---
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cellWidth = (screenWidth - 32 - 20) / 2;
    final cellHeight = cellWidth / 0.65;

    return Scaffold(
      backgroundColor: const Color(0xFF333333),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151515),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          "Reorder",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, color: Colors.blueAccent, size: 30),
            onPressed: () {
              Navigator.pop(context, _items);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),

      // 🚨 NAYA: Bottom bar me Banner Ad lagaya (Agar ready ho)
      bottomNavigationBar: _isBannerAdLoaded && _bannerAd != null
          ? Container(
        color: const Color(0xFF151515), // AppBar se match karta hua dark color
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      )
          : const SizedBox.shrink(), // Agar Ad load nahi hua, toh jagah nahi gherega

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: GridView.builder(
          itemCount: _items.length,
          physics: const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 30,
            crossAxisSpacing: 20,
            childAspectRatio: 0.65,
          ),
          itemBuilder: (context, index) {
            final currentItem = _items[index];

            return DragTarget<Map<String, dynamic>>(
              onWillAccept: (draggedItem) => draggedItem != null && draggedItem != currentItem,
              onAccept: (draggedItem) {
                final fromIndex = _items.indexOf(draggedItem);
                if (fromIndex != -1) {
                  setState(() {
                    final item = _items.removeAt(fromIndex);
                    _items.insert(index, item);
                  });
                }
              },
              builder: (context, candidateData, rejectedData) {
                bool isTargeted = candidateData.isNotEmpty;

                return LongPressDraggable<Map<String, dynamic>>(
                  data: currentItem,
                  delay: const Duration(milliseconds: 150),
                  hapticFeedbackOnStart: true,

                  feedback: Material(
                    color: Colors.transparent,
                    child: SizedBox(
                      width: cellWidth,
                      height: cellHeight,
                      child: Transform.scale(scale: 1.05, child: _buildGridItem(currentItem, index, isDragging: true)),
                    ),
                  ),

                  childWhenDragging: Opacity(opacity: 0.3, child: _buildGridItem(currentItem, index)),

                  child: Container(
                    decoration: isTargeted
                        ? BoxDecoration(
                            border: Border.all(color: Colors.blueAccent, width: 3.0),
                            borderRadius: BorderRadius.circular(6),
                          )
                        : const BoxDecoration(
                            border: Border.fromBorderSide(BorderSide(color: Colors.transparent, width: 3.0)),
                          ),
                    child: _buildGridItem(currentItem, index),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildGridItem(Map<String, dynamic> item, int index, {bool isDragging = false}) {
    File imageFile = item['cropped'] as File;

    int turns = item['rotation'] ?? 0;
    String filterName = item['filter'] ?? "Original color";
    double brightness = item['brightness'] ?? 0.0;
    double contrast = item['contrast'] ?? 0.0;

    // 🚨 NEW: Map se markups vector data nikal rahe hain
    final markupData = item['markups'];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(4),
              boxShadow: isDragging
                  ? [const BoxShadow(color: Colors.black54, blurRadius: 12, spreadRadius: 3)]
                  : [const BoxShadow(color: Colors.black26, blurRadius: 4, spreadRadius: 1)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: RotatedBox(
                quarterTurns: turns,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // --- Layer 1: Base Image with Filters ---
                      ColorFiltered(
                        colorFilter: _getAdjustColorFilter(brightness, contrast),
                        child: ColorFiltered(
                          colorFilter:
                              _getColorFilter(filterName) ??
                              const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                          child: Image.file(
                            imageFile,
                            fit: BoxFit.contain,
                            //width: double.infinity,
                          ),
                        ),
                      ),

                      // --- 🚨 NEW: Layer 2 & 3: Vector Markups (Drawings, Texts, Shapes) ---
                      if (markupData != null && markupData is MarkupExportData) ...[
                        // A. DRAWING STROKES (Pen/Eraser lines)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: DrawingPainter(
                              paths: markupData.paths,
                              currentPoints: [],
                              currentColor: Colors.transparent,
                              currentStrokeWidth: 0,
                              currentOpacity: 0,
                              isEraser: false,
                            ),
                          ),
                        ),

                        // B. TEXTS & SHAPES OVERLAYS
                        Positioned.fill(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              double canvasW = constraints.maxWidth;
                              double canvasH = constraints.maxHeight;
                              double scaleRatio = canvasW / 400.0;

                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // TEXTS LOOP
                                  ...markupData.texts.map((textItem) {
                                    double scaledFontSize = textItem.fontSize * scaleRatio;
                                    Color textColor = textItem.appearance == 0
                                        ? textItem.color
                                        : (textItem.appearance == 1 || textItem.appearance == 2)
                                        ? (textItem.color.computeLuminance() > 0.5 ? Colors.black : Colors.white)
                                        : Colors.white;
                                    Color bgColor = textItem.appearance == 1
                                        ? textItem.color
                                        : textItem.appearance == 2
                                        ? textItem.color.withOpacity(0.5)
                                        : Colors.transparent;

                                    TextDecoration decoration = TextDecoration.none;
                                    if (textItem.isUnderline && textItem.isStrikethrough) {
                                      decoration = TextDecoration.combine([
                                        TextDecoration.underline,
                                        TextDecoration.lineThrough,
                                      ]);
                                    } else if (textItem.isUnderline) {
                                      decoration = TextDecoration.underline;
                                    } else if (textItem.isStrikethrough) {
                                      decoration = TextDecoration.lineThrough;
                                    }

                                    return Positioned(
                                      left: textItem.offset.dx * canvasW,
                                      top: textItem.offset.dy * canvasH,
                                      child: FractionalTranslation(
                                        translation: const Offset(-0.5, -0.5),
                                        child: Transform.rotate(
                                          angle: textItem.rotation,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 16 * scaleRatio,
                                              vertical: 8 * scaleRatio,
                                            ),
                                            decoration: BoxDecoration(
                                              color: bgColor,
                                              borderRadius: BorderRadius.circular(8 * scaleRatio),
                                            ),
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                if (textItem.appearance == 3)
                                                  Text(
                                                    textItem.text,
                                                    textAlign: textItem.alignment,
                                                    style: TextStyle(
                                                      fontSize: scaledFontSize,
                                                      fontFamily: textItem.font,
                                                      fontWeight: textItem.isBold ? FontWeight.bold : FontWeight.normal,
                                                      fontStyle: textItem.isItalic
                                                          ? FontStyle.italic
                                                          : FontStyle.normal,
                                                      decoration: decoration,
                                                      foreground: Paint()
                                                        ..style = PaintingStyle.stroke
                                                        ..strokeWidth = scaledFontSize * 0.25
                                                        ..strokeJoin = StrokeJoin.round
                                                        ..strokeCap = StrokeCap.round
                                                        ..color = textItem.color,
                                                    ),
                                                  ),
                                                Text(
                                                  textItem.text,
                                                  textAlign: textItem.alignment,
                                                  style: TextStyle(
                                                    color: textColor,
                                                    fontSize: scaledFontSize,
                                                    fontFamily: textItem.font,
                                                    fontWeight: textItem.isBold ? FontWeight.bold : FontWeight.normal,
                                                    fontStyle: textItem.isItalic ? FontStyle.italic : FontStyle.normal,
                                                    decoration: decoration,
                                                    decorationColor: textColor,
                                                    shadows: textItem.appearance == 0
                                                        ? const [
                                                            Shadow(
                                                              color: Colors.black54,
                                                              blurRadius: 4,
                                                              offset: Offset(1, 1),
                                                            ),
                                                          ]
                                                        : null,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),

                                  // SHAPES LOOP
                                  ...markupData.shapes.map((shape) {
                                    return Positioned(
                                      left: shape.offset.dx * canvasW,
                                      top: shape.offset.dy * canvasH,
                                      child: FractionalTranslation(
                                        translation: const Offset(-0.5, -0.5),
                                        child: Transform.rotate(
                                          angle: shape.rotation,
                                          child: Container(
                                            padding: const EdgeInsets.all(24),
                                            child: SizedBox(
                                              width: (shape.size * shape.scaleX.abs()) * scaleRatio,
                                              height: (shape.size * shape.scaleY.abs()) * scaleRatio,
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "${index + 1}",
          style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
