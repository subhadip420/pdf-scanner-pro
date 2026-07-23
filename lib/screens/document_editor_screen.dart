import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:material_symbols_icons/symbols.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_scanner_pro/screens/reorder_screen.dart';
import 'package:pdf_scanner_pro/screens/scanner_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'custom_dialog.dart';
import 'home_screen.dart';
import 'markup_screen.dart';

import 'dart:ui' as ui;
import 'dart:typed_data';

import 'merge_screen.dart';

class DocumentEditorScreen extends StatefulWidget {
  final List<Map<String, dynamic>> imageFiles;
  final bool isFromGallery;

  const DocumentEditorScreen({Key? key, required this.imageFiles, required this.isFromGallery}) : super(key: key);

  @override
  State<DocumentEditorScreen> createState() => _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends State<DocumentEditorScreen> {
  late String documentName;
  late PageController _pageController;
  int currentPage = 0;
  bool isThumbnailVisible = true;
  RewardedAd? _rewardedAd;
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  // --- CROP TOOL VARIABLES ---
  bool isCroppingMode = false;
  double cropTopRatio = 0.0;
  double cropBottomRatio = 0.0;
  double cropLeftRatio = 0.0;
  double cropRightRatio = 0.0;
  double _cropAreaWidth = 1.0;
  double _cropAreaHeight = 1.0;
  double _origWidth = 1.0;
  double _origHeight = 1.0;

  late List<Map<String, double>?> _savedCropPositions;
  late List<Map<String, double>?> _autoCropPositions;
  double _iconRotationTurns = 0.0;
  late List<int> _imageQuarterTurns;

  int _currentPageIndex = 0;

  // Filter Menu State Variables
  bool _showFilterMenu = false;
  bool _applyToAllPages = false;
  late List<String> _pageFilters;

  final List<String> _filterOptions = ["Original color", "Auto-color", "Light text", "Grayscale", "Whiteboard"];
  String _defaultFilter = "Original color";

  bool _showAdjustMenu = false;
  late List<double> _pageBrightness;
  late List<double> _pageContrast;
  String _activeAdjustTab = "Brightness";

  late List<dynamic> _pageMarkups;

  bool isSelectionMode = false;
  late List<bool> selectedPagesList;
  bool isResizeMode = false;
  String _defaultPageSize = "Auto Fit";
  String _selectedPageSize = "Auto Fit";
  bool isProcessing = false;

  // --- OCR Variables ---
  bool _isDetectingText = false;
  String? _extractedText;
  bool _showCopyBanner = false;

  late List<Map<String, dynamic>> docFiles;

  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _loadDefaultFilter();
    _loadSavedPageSize();
    documentName = _generateDefaultName();

    docFiles = widget.imageFiles.map((e) => Map<String, dynamic>.from(e)).toList();

    currentPage = docFiles.length - 1;
    _pageController = PageController(initialPage: currentPage);

    _savedCropPositions = List.generate(docFiles.length, (index) => null);
    _autoCropPositions = List.generate(docFiles.length, (index) => null);

    _loadRewardedAd();
    _loadBannerAd();
    _imageQuarterTurns = List.filled(docFiles.length, 0);
    _pageFilters = List.filled(docFiles.length, "Original color");
    _pageBrightness = List.filled(docFiles.length, 0.0); // Default 0
    _pageContrast = List.filled(docFiles.length, 0.0); // Default 0

    _pageMarkups = List.filled(docFiles.length, null);

    selectedPagesList = List.filled(docFiles.length, false);
    _loadEditsFromMemory();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPageSize() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _defaultPageSize = prefs.getString('pref_page_size') ?? 'Auto Fit';
      _selectedPageSize = _defaultPageSize;
    });
  }

  Future<void> _loadDefaultFilter() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String savedFilter = prefs.getString('default_filter') ?? "Original color";

    setState(() {
      _defaultFilter = savedFilter;

      for (int i = 0; i < docFiles.length; i++) {
        if (docFiles[i]['filter'] == null || docFiles[i]['filter'] == "Original color") {
          docFiles[i]['filter'] = savedFilter; // Map me save karo

          if (_pageFilters.isNotEmpty) {
            _pageFilters[i] = savedFilter;
          }
        }
      }
    });
  }

  double? _getPreviewAspectRatio(String size) {
    switch (size) {
      case "Letter (P)":
        return 8.5 / 11;
      case "Letter (L)":
        return 11 / 8.5;
      case "Legal (P)":
        return 8.5 / 14;
      case "Legal (L)":
        return 14 / 8.5;
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
      default:
        return null;
    }
  }

  PdfPageFormat? _getPdfPageFormat(String size) {
    switch (size) {
      case "Letter (P)":
        return PdfPageFormat.letter;
      case "Letter (L)":
        return PdfPageFormat.letter.landscape;
      case "Legal (P)":
        return PdfPageFormat.legal;
      case "Legal (L)":
        return PdfPageFormat.legal.landscape;
      case "A4 (P)":
        return PdfPageFormat.a4;
      case "A4 (L)":
        return PdfPageFormat.a4.landscape;
      case "A3 (P)":
        return PdfPageFormat.a3;
      case "A3 (L)":
        return PdfPageFormat.a3.landscape;
      case "A5 (P)":
        return PdfPageFormat.a5;
      case "A5 (L)":
        return PdfPageFormat.a5.landscape;
      default:
        return null; // Auto Fit
    }
  }

  Future<void> _promptDiscard() async {
    bool discard = await showCustomConfirmDialog(
      context,
      title: "Discard this scan?",
      message: "This will discard the scan you have captured. Are you sure?",
      positiveBtnText: "Discard",
      negativeBtnText: "Cancel",
      positiveBtnColor: Colors.redAccent,
    );

    if (discard) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    }
  }

  void _loadEditsFromMemory() {
    setState(() {
      _savedCropPositions = List.generate(docFiles.length, (i) => docFiles[i]['cropPosition']);
      _autoCropPositions = List.generate(docFiles.length, (i) => docFiles[i]['autoCropPosition']);
      _imageQuarterTurns = List.generate(docFiles.length, (i) => docFiles[i]['rotation'] ?? 0);
      _pageFilters = List.generate(docFiles.length, (i) => docFiles[i]['filter'] ?? "Original color");
      _pageBrightness = List.generate(docFiles.length, (i) => docFiles[i]['brightness'] ?? 0.0);
      _pageContrast = List.generate(docFiles.length, (i) => docFiles[i]['contrast'] ?? 0.0);
      _pageMarkups = List.generate(docFiles.length, (i) => docFiles[i]['markups']);

      if (currentPage >= docFiles.length) {
        currentPage = 0;
      }
    });
  }

  void _saveEditsToMemory() {
    for (int i = 0; i < docFiles.length; i++) {
      docFiles[i]['rotation'] = _imageQuarterTurns[i];
      docFiles[i]['filter'] = _pageFilters[i];
      docFiles[i]['brightness'] = _pageBrightness[i];
      docFiles[i]['contrast'] = _pageContrast[i];
      docFiles[i]['markups'] = _pageMarkups[i];
      docFiles[i]['cropPosition'] = _savedCropPositions[i];
      docFiles[i]['autoCropPosition'] = _autoCropPositions[i];
    }
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
    double t = (1.0 - c) * 127.5; // Offset for contrast centering

    return ColorFilter.matrix([c, 0, 0, 0, t + b, 0, c, 0, 0, t + b, 0, 0, c, 0, t + b, 0, 0, 0, 1, 0]);
  }

  void _applyColorMatrix(img.Image image, List<double> m) {
    for (final p in image) {
      final num r = p.r;
      final num g = p.g;
      final num b = p.b;
      final num a = p.a;

      p.r = (r * m[0] + g * m[1] + b * m[2] + a * m[3] + m[4]).clamp(0, 255);
      p.g = (r * m[5] + g * m[6] + b * m[7] + a * m[8] + m[9]).clamp(0, 255);
      p.b = (r * m[10] + g * m[11] + b * m[12] + a * m[13] + m[14]).clamp(0, 255);
      p.a = (r * m[15] + g * m[16] + b * m[17] + a * m[18] + m[19]).clamp(0, 255);
    }
  }

  img.Image _processImageSync(
    img.Image decodedImage,
    int turns,
    String activeFilter,
    double activeBright,
    double activeContrast,
  ) {
    if (turns != 0) {
      decodedImage = img.copyRotate(decodedImage, angle: turns * 90);
    }

    if (activeFilter != "Original color") {
      List<double>? filterMatrix;
      switch (activeFilter) {
        case "Grayscale":
          filterMatrix = [
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
          ];
          break;
        case "Whiteboard":
          filterMatrix = [1.5, 0, 0, 0, 20, 0, 1.5, 0, 0, 20, 0, 0, 1.5, 0, 20, 0, 0, 0, 1, 0];
          break;
        case "Light text":
          filterMatrix = [1.2, 0, 0, 0, 10, 0, 1.2, 0, 0, 10, 0, 0, 1.2, 0, 10, 0, 0, 0, 1, 0];
          break;
        case "Auto-color":
          filterMatrix = [1.2, -0.1, -0.1, 0, 10, -0.1, 1.2, -0.1, 0, 10, -0.1, -0.1, 1.2, 0, 10, 0, 0, 0, 1, 0];
          break;
      }
      if (filterMatrix != null) {
        _applyColorMatrix(decodedImage, filterMatrix);
      }
    }

    if (activeBright != 0.0 || activeContrast != 0.0) {
      double b = activeBright * 2.55;
      double c = 1.0 + (activeContrast / 100.0);
      double t = (1.0 - c) * 127.5;
      double offset = t + b;
      List<double> adjustMatrix = [c, 0, 0, 0, offset, 0, c, 0, 0, offset, 0, 0, c, 0, offset, 0, 0, 0, 1, 0];
      _applyColorMatrix(decodedImage, adjustMatrix);
    }

    return decodedImage;
  }

  /// --- EXTRACT TEXT FUNCTION (OCR) ---
  Future<void> _extractTextFromCurrentImage() async {
    setState(() {
      _isDetectingText = true;
      _showCopyBanner = false;
    });

    try {
      File currentFile = docFiles[currentPage]['cropped'] as File;

      final inputImage = InputImage.fromFile(currentFile);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      String text = recognizedText.text.trim();

      if (text.isNotEmpty) {
        setState(() {
          _extractedText = text;
          _showCopyBanner = true;
          _isDetectingText = false;
        });
      } else {
        setState(() => _isDetectingText = false);
        showToast("No text found in this image");
      }
      textRecognizer.close();
    } catch (e) {
      setState(() => _isDetectingText = false);
      showToast("Failed to extract text");
    }
  }

  Future<void> _toggleCropMode() async {
    if (isCroppingMode) {
      await _saveNewCrop();
    } else {
      final originalFile = docFiles[currentPage]['original'] as File?;
      final croppedFile = docFiles[currentPage]['cropped'] as File?;

      if (originalFile == null || croppedFile == null) {
        showToast("Error: Image data not found");
        return;
      }

      setState(() {
        isProcessing = true;
        _showFilterMenu = false;
        _showAdjustMenu = false;
      });

      await Future.delayed(const Duration(milliseconds: 150));

      try {
        final origBytes = await originalFile.readAsBytes();
        final cropBytes = await croppedFile.readAsBytes();

        final decodedOrig = img.decodeImage(origBytes);
        final decodedCrop = img.decodeImage(cropBytes);

        if (decodedOrig != null && decodedCrop != null) {
          setState(() {
            _origWidth = decodedOrig.width.toDouble();
            _origHeight = decodedOrig.height.toDouble();

            double percentW = decodedCrop.width / decodedOrig.width;
            double percentH = decodedCrop.height / decodedOrig.height;
            double autoTop = (1.0 - percentH) / 2;
            double autoBottom = (1.0 - percentH) / 2;
            double autoLeft = (1.0 - percentW) / 2;
            double autoRight = (1.0 - percentW) / 2;

            if (percentW >= 0.99 && percentH >= 0.99) {
              autoTop = 0.05;
              autoBottom = 0.05;
              autoLeft = 0.05;
              autoRight = 0.05;
            }

            if (docFiles[currentPage]['crop_ratios'] != null) {
              final ratios = docFiles[currentPage]['crop_ratios'];
              autoTop = (ratios['top'] as num).toDouble();
              autoBottom = (ratios['bottom'] as num).toDouble();
              autoLeft = (ratios['left'] as num).toDouble();
              autoRight = (ratios['right'] as num).toDouble();
            }

            _autoCropPositions[currentPage] ??= {
              'top': autoTop,
              'bottom': autoBottom,
              'left': autoLeft,
              'right': autoRight,
            };

            if (_savedCropPositions[currentPage] != null) {
              cropTopRatio = _savedCropPositions[currentPage]!['top']!;
              cropBottomRatio = _savedCropPositions[currentPage]!['bottom']!;
              cropLeftRatio = _savedCropPositions[currentPage]!['left']!;
              cropRightRatio = _savedCropPositions[currentPage]!['right']!;
            } else {
              cropTopRatio = autoTop;
              cropBottomRatio = autoBottom;
              cropLeftRatio = autoLeft;
              cropRightRatio = autoRight;
            }

            isCroppingMode = true;
            isThumbnailVisible = false;
            isProcessing = false;
          });
        } else {
          setState(() => isProcessing = false);
          showToast("Could not process image");
        }
      } catch (e) {
        setState(() => isProcessing = false);
        showToast("Error: $e");
      }
    }
  }

  void _resetToAutoCrop() {
    setState(() {
      if (_autoCropPositions[currentPage] != null) {
        cropTopRatio = _autoCropPositions[currentPage]!['top']!;
        cropBottomRatio = _autoCropPositions[currentPage]!['bottom']!;
        cropLeftRatio = _autoCropPositions[currentPage]!['left']!;
        cropRightRatio = _autoCropPositions[currentPage]!['right']!;
      }
    });
  }

  Future<void> _openReorderScreen() async {
    if (docFiles.length <= 1) {
      showToast("Only one page available");
      return;
    }

    if (_showFilterMenu || _showAdjustMenu) {
      setState(() {
        _showFilterMenu = false;
        _showAdjustMenu = false;
      });
      await Future.delayed(const Duration(milliseconds: 200));
    }
    _saveEditsToMemory();

    final reorderedList = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ReorderScreen(imageFiles: List.from(docFiles))),
    );

    if (reorderedList != null && reorderedList is List<Map<String, dynamic>>) {
      docFiles.clear();
      docFiles.addAll(reorderedList);
      _loadEditsFromMemory();
      _pageController.jumpToPage(0);
      showToast("Pages reordered successfully");
    }
  }

  String _generateDefaultName() {
    final now = DateTime.now();
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return "PDF Scanner Pro ${months[now.month - 1]} ${now.day}, ${now.year}";
  }

  void _loadRewardedAd() {
    print("AdMob: Loading ad...");

    RewardedAd.load(
      /// TODO Google's Test AD ID
      //adUnitId: 'ca-app-pub-3940256099942544/5224354917', // test ad id
      adUnitId: 'ca-app-pub-5454466291921987/2609884833', // real ad id
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          print("AdMob: Ad loaded successfully!");
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (RewardedAd ad) {
              ad.dispose();
              _rewardedAd = null;
              _loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
              ad.dispose();
              _rewardedAd = null;
            },
          );

          _rewardedAd = ad;
        },
        onAdFailedToLoad: (LoadAdError error) {
          print("AdMob: Ad failed to load: ${error.message}");
          _rewardedAd = null;
        },
      ),
    );
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      //TODO Google's Test AD ID
      //adUnitId: 'ca-app-pub-3940256099942544/6300978111', // test ad id
      adUnitId: 'ca-app-pub-5454466291921987/6221826783', // real ad id
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          print("Banner Ad failed to load: $error");
          ad.dispose();
        },
      ),
    )..load();
  }

  Future<void> _handleSaveClick() async {
    if (_rewardedAd != null) {
      _showRewardAd();
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
    );

    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (_rewardedAd != null) break;
    }

    if (mounted) Navigator.pop(context);

    if (_rewardedAd != null) {
      _showRewardAd();
    } else {
      showToast("Saving PDF...");
      _generateAndSavePdf();
    }
  }

  void _showRewardAd() {
    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        _generateAndSavePdf();
      },
    );
  }

  Future<void> _generateAndSavePdf() async {
    showToast("Generating PDF...");

    final pdf = pw.Document();
    for (int i = 0; i < docFiles.length; i++) {
      var map = docFiles[i];
      final File file = map['cropped'] as File;

      var imageBytes = await file.readAsBytes();

      int turns = _imageQuarterTurns[i];
      String activeFilter = _pageFilters[i];
      double activeBright = _pageBrightness[i];
      double activeContrast = _pageContrast[i];
      if (activeFilter != "Original color" || activeBright != 0.0 || activeContrast != 0.0) {
        img.Image? decodedImage = img.decodeImage(imageBytes);
        if (decodedImage != null) {
          decodedImage = _processImageSync(decodedImage, 0, activeFilter, activeBright, activeContrast);
          imageBytes = img.encodeJpg(decodedImage, quality: 100);
        }
      }

      if (_pageMarkups[i] != null && _pageMarkups[i] is MarkupExportData) {
        MarkupExportData exportData = _pageMarkups[i];

        ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
        ui.FrameInfo frameInfo = await codec.getNextFrame();
        ui.Image uiImg = frameInfo.image;

        final ui.PictureRecorder recorder = ui.PictureRecorder();
        final Canvas canvas = Canvas(recorder);
        final Size size = Size(uiImg.width.toDouble(), uiImg.height.toDouble());
        double scaleRatio = size.width / 400.0;

        canvas.drawImage(uiImg, Offset.zero, Paint());

        DrawingPainter painter = DrawingPainter(
          paths: exportData.paths,
          currentPoints: [],
          currentColor: Colors.transparent,
          currentStrokeWidth: 0,
          currentOpacity: 0,
          isEraser: false,
        );
        painter.paint(canvas, size);

        for (var shape in exportData.shapes) {
          canvas.save();
          canvas.translate(shape.offset.dx * size.width, shape.offset.dy * size.height);
          canvas.rotate(shape.rotation);
          canvas.scale(shape.scaleX < 0 ? -1.0 : 1.0, shape.scaleY < 0 ? -1.0 : 1.0);

          TextPainter tp = TextPainter(
            text: TextSpan(
              text: String.fromCharCode(shape.icon.codePoint),
              style: TextStyle(
                fontSize: shape.size * scaleRatio,
                color: shape.color,
                fontFamily: shape.icon.fontFamily,
                package: shape.icon.fontPackage,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          tp.layout();
          tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
          canvas.restore();
        }

        for (var item in exportData.texts) {
          canvas.save();
          canvas.translate(item.offset.dx * size.width, item.offset.dy * size.height);
          canvas.rotate(item.rotation);

          double fontSize = item.fontSize * scaleRatio;
          Color textColor = item.appearance == 0
              ? item.color
              : (item.appearance == 1 || item.appearance == 2)
              ? (item.color.computeLuminance() > 0.5 ? Colors.black : Colors.white)
              : Colors.white;
          Color bgColor = item.appearance == 1
              ? item.color
              : item.appearance == 2
              ? item.color.withOpacity(0.5)
              : Colors.transparent;

          TextDecoration decoration = TextDecoration.none;
          if (item.isUnderline && item.isStrikethrough) {
            decoration = TextDecoration.combine([TextDecoration.underline, TextDecoration.lineThrough]);
          } else if (item.isUnderline) {
            decoration = TextDecoration.underline;
          } else if (item.isStrikethrough) {
            decoration = TextDecoration.lineThrough;
          }

          TextStyle style = TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontFamily: item.font,
            fontWeight: item.isBold ? FontWeight.bold : FontWeight.normal,
            fontStyle: item.isItalic ? FontStyle.italic : FontStyle.normal,
            decoration: decoration,
            decorationColor: textColor,
            shadows: item.appearance == 0
                ? [const Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(1, 1))]
                : null,
          );

          TextPainter tp = TextPainter(
            text: TextSpan(text: item.text, style: style),
            textAlign: item.alignment,
            textDirection: TextDirection.ltr,
          );
          tp.layout();

          Rect bgRect = Rect.fromCenter(
            center: Offset.zero,
            width: tp.width + (32 * scaleRatio),
            height: tp.height + (16 * scaleRatio),
          );
          if (bgColor != Colors.transparent) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(bgRect, Radius.circular(8 * scaleRatio)),
              Paint()..color = bgColor,
            );
          }

          if (item.appearance == 3) {
            TextPainter strokeTp = TextPainter(
              text: TextSpan(
                text: item.text,
                style: style.copyWith(
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = fontSize * 0.25
                    ..strokeJoin = StrokeJoin.round
                    ..strokeCap = StrokeCap.round
                    ..color = item.color,
                ),
              ),
              textAlign: item.alignment,
              textDirection: TextDirection.ltr,
            );
            strokeTp.layout();
            strokeTp.paint(canvas, Offset(-strokeTp.width / 2, -strokeTp.height / 2));
          }

          // Main text paint
          tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
          canvas.restore();
        }

        final ui.Picture picture = recorder.endRecording();
        final ui.Image finalUiImg = await picture.toImage(uiImg.width, uiImg.height);
        final ByteData? byteData = await finalUiImg.toByteData(format: ui.ImageByteFormat.png);

        if (byteData != null) {
          imageBytes = byteData.buffer.asUint8List(); // Data replace kar do
        }
      }

      if (turns != 0) {
        img.Image? decodedStampedImage = img.decodeImage(imageBytes);
        if (decodedStampedImage != null) {
          decodedStampedImage = img.copyRotate(decodedStampedImage, angle: turns * 90);
          imageBytes = img.encodeJpg(decodedStampedImage, quality: 90);
        }
      }

      final image = pw.MemoryImage(imageBytes);

      PdfPageFormat? selectedFormat = _getPdfPageFormat(_selectedPageSize);

      PdfPageFormat finalPageFormat;

      if (selectedFormat != null) {
        finalPageFormat = selectedFormat;
      } else {
        double imgWidth = image.width!.toDouble();
        double imgHeight = image.height!.toDouble();

        double maxDimension = 842.0;

        if (imgWidth > maxDimension || imgHeight > maxDimension) {
          double scale = math.min(maxDimension / imgWidth, maxDimension / imgHeight);
          imgWidth *= scale;
          imgHeight *= scale;
        }

        finalPageFormat = PdfPageFormat(imgWidth, imgHeight);
      }

      pdf.addPage(
        pw.Page(
          margin: pw.EdgeInsets.zero,
          pageFormat: finalPageFormat,
          build: (context) {
            return pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain));
          },
        ),
      );
    }

    try {
      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }

      if (!await Permission.manageExternalStorage.isGranted) {
        showToast("Storage permission is required to save PDF");
        return;
      }

      final Directory publicDir = Directory('/storage/emulated/0/Documents/PDF Scanner Pro');

      if (!await publicDir.exists()) {
        await publicDir.create(recursive: true);
      }

      String baseFilePath = "${publicDir.path}/$documentName";
      String finalFilePath = "$baseFilePath.pdf";
      File file = File(finalFilePath);

      int counter = 1;
      while (await file.exists()) {
        finalFilePath = "$baseFilePath ($counter).pdf";
        file = File(finalFilePath);
        counter++;
      }

      await file.writeAsBytes(await pdf.save());
      showToast("Saved in Documents/PDF Scanner Pro");

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      showToast("Error saving PDF: $e");
      print("Save Error: $e");
    }
  }

  void showToast(String msg) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.white,
      textColor: Colors.black,
    );
  }

  void _previousPage() {
    if (currentPage > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      showToast("First page");
    }
  }

  void _nextPage() {
    if (currentPage < docFiles.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      showToast("Last page");
    }
  }

  void _rotateImage() {
    setState(() {
      _iconRotationTurns += 0.25;
      _imageQuarterTurns[currentPage] = (_imageQuarterTurns[currentPage] + 1) % 4;
    });
  }

  Future<void> _retakeImage() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ScannerScreen(isRetakeMode: true, isOpenedFromEditor: false)),
      );

      if (result != null && result is File) {
        setState(() {
          docFiles[currentPage] = {'original': result, 'cropped': result};

          _imageQuarterTurns[currentPage] = 0;
          _savedCropPositions[currentPage] = null;
          _autoCropPositions[currentPage] = null;
          _pageFilters[currentPage] = "Original color";
          _pageBrightness[currentPage] = 0.0;
          _pageContrast[currentPage] = 0.0;
        });

        showToast("Page ${currentPage + 1} replaced successfully!");
      }
    } catch (e) {
      showToast("Error replacing photo: $e");
      print("Retake Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAnyToolActive = isCroppingMode || _showFilterMenu || _showAdjustMenu || isResizeMode || isSelectionMode;
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) {
          return;
        }

        await _promptDiscard();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF2C2C2C),
        resizeToAvoidBottomInset: false,

        appBar: AppBar(
          backgroundColor: const Color(0xFF1E1E1E),
          elevation: 0,
          automaticallyImplyLeading: false,

          ///  LEFT ICON (HOME): Crop, Selection, ya Resize mode active hone par HIDE ho jayega
          leading: (isCroppingMode || isSelectionMode || isResizeMode)
              ? null
              : Tooltip(
                  message: "Home",
                  child: IconButton(
                    icon: const Icon(Icons.home, color: Colors.white, size: 28),
                    onPressed: () {
                      _promptDiscard();
                    },
                  ),
                ),

          ///  MIDDLE (TITLE / BANNER AD): Teeno modes me Ad dikhayega, warna Rename Title
          title: (isCroppingMode || isSelectionMode || isResizeMode)
              ? (_isBannerAdLoaded && _bannerAd != null
                    // 1. Agar Ad ready hai toh Banner Ad dikhao
                    ? SizedBox(
                        width: _bannerAd!.size.width.toDouble(),
                        height: _bannerAd!.size.height.toDouble(),
                        child: AdWidget(ad: _bannerAd!),
                      )
                    : Text(
                        isCroppingMode
                            ? "Adjust Borders"
                            : isSelectionMode
                            ? "Select Pages"
                            : "Resize Layout",
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ))
              : Tooltip(
                  message: "Rename document",
                  child: GestureDetector(
                    onTap: () {
                      _showRenameDialog(context);
                    },
                    child: IntrinsicWidth(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            documentName,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            height: 1.5,
                            child: CustomPaint(painter: DottedLinePainter()),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          centerTitle: true,

          /// RIGHT ICON (EXTRACT TEXT): Teeno modes me HIDE ho jayega
          actions: (isCroppingMode || isSelectionMode || isResizeMode)
              ? []
              : [
                  Tooltip(
                    message: "Extract Text",
                    child: IconButton(
                      icon: _isDetectingText
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 24),
                      onPressed: _isDetectingText ? null : _extractTextFromCurrentImage,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
        ),

        body: Column(
          children: [
            /// Taaki Filter Menu peechhe se nikle aur uske clicks properly detect hon!
            Expanded(
              child: ClipRect(
                child: Stack(
                  children: [
                    /// --- LAYER 1: Preview & Thumbnails ---
                    Column(
                      children: [
                        // MAIN PREVIEW AREA
                        Expanded(
                          child: Stack(
                            children: [
                              // Swipeable & Zoomable Images
                              PageView.builder(
                                controller: _pageController,
                                physics: isCroppingMode
                                    ? const NeverScrollableScrollPhysics()
                                    : const BouncingScrollPhysics(),
                                onPageChanged: (index) {
                                  setState(() {
                                    currentPage = index;
                                  });
                                  _transformationController.value = Matrix4.identity();
                                },
                                itemCount: docFiles.length,
                                allowImplicitScrolling: true,

                                itemBuilder: (context, index) {
                                  if (isCroppingMode && index == currentPage) {
                                    return _buildInPlaceCropView();
                                  }
                                  return GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onTap: () {
                                      if (_showFilterMenu) setState(() => _showFilterMenu = false);
                                      if (_showAdjustMenu) setState(() => _showAdjustMenu = false);

                                      if (isResizeMode) {
                                        setState(() {
                                          isResizeMode = false;
                                          isThumbnailVisible = true;
                                          if (_showAdjustMenu) _showFilterMenu = false;
                                          if (_showFilterMenu) _showAdjustMenu = false;
                                        });
                                      }
                                    },
                                    onDoubleTapDown: (details) {
                                      _doubleTapDetails = details;
                                    },

                                    onDoubleTap: () {
                                      if (isCroppingMode || isSelectionMode || isResizeMode) return;

                                      final double currentScale = _transformationController.value.getMaxScaleOnAxis();

                                      if (currentScale <= 1.05) {
                                        final position = _doubleTapDetails?.localPosition ?? Offset.zero;

                                        _transformationController.value = Matrix4.identity()
                                          ..setTranslationRaw(
                                            -position.dx * 1.5,
                                            -position.dy * 1.5,
                                            0.0,
                                          ) // X aur Y ko translate kiya
                                          ..setEntry(0, 0, 2.5) // X-Axis par 2.5x Zoom
                                          ..setEntry(1, 1, 2.5) // Y-Axis par 2.5x Zoom
                                          ..setEntry(2, 2, 1.0); // Z-Axis (Normal)
                                      } else {
                                        _transformationController.value = Matrix4.identity(); // Zoom Out
                                      }
                                    },

                                    child: InteractiveViewer(
                                      transformationController: _transformationController,
                                      minScale: 1.0,
                                      maxScale: 5.0,
                                      clipBehavior: Clip.none,
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 80),

                                          child: LayoutBuilder(
                                            builder: (context, constraints) {
                                              Widget pagePreviewContent = RepaintBoundary(
                                                child: RotatedBox(
                                                  quarterTurns: _imageQuarterTurns[index],
                                                  child: Stack(
                                                    alignment: Alignment.center,
                                                    children: [
                                                      ColorFiltered(
                                                        colorFilter: _getAdjustColorFilter(
                                                          _pageBrightness[index],
                                                          _pageContrast[index],
                                                        ),
                                                        child: ColorFiltered(
                                                          colorFilter:
                                                              _getColorFilter(_pageFilters[index]) ??
                                                              const ColorFilter.mode(
                                                                Colors.transparent,
                                                                BlendMode.multiply,
                                                              ),
                                                          child: Image.file(
                                                            docFiles[index]['cropped'] as File,
                                                            fit: BoxFit.contain,
                                                            gaplessPlayback: true,

                                                            filterQuality: FilterQuality.low,
                                                          ),
                                                        ),
                                                      ),

                                                      if (_pageMarkups[index] != null &&
                                                          _pageMarkups[index] is MarkupExportData) ...[
                                                        /// --- DRAWING STROKES ---
                                                        Positioned.fill(
                                                          child: CustomPaint(
                                                            painter: DrawingPainter(
                                                              paths: (_pageMarkups[index] as MarkupExportData).paths,
                                                              currentPoints: [],
                                                              currentColor: Colors.transparent,
                                                              currentStrokeWidth: 0,
                                                              currentOpacity: 0,
                                                              isEraser: false,
                                                            ),
                                                          ),
                                                        ),

                                                        /// --- TEXTS & SHAPES ---
                                                        Positioned.fill(
                                                          child: LayoutBuilder(
                                                            builder: (context, constraints) {
                                                              double canvasW = constraints.maxWidth;
                                                              double canvasH = constraints.maxHeight;
                                                              double scaleRatio = canvasW / 400.0;
                                                              MarkupExportData data = _pageMarkups[index];

                                                              return Stack(
                                                                clipBehavior: Clip.none,
                                                                children: [
                                                                  /// TEXTS LOOP
                                                                  ...data.texts.map((item) {
                                                                    double scaledFontSize = item.fontSize * scaleRatio;
                                                                    Color textColor = item.appearance == 0
                                                                        ? item.color
                                                                        : (item.appearance == 1 || item.appearance == 2)
                                                                        ? (item.color.computeLuminance() > 0.5
                                                                              ? Colors.black
                                                                              : Colors.white)
                                                                        : Colors.white;
                                                                    Color bgColor = item.appearance == 1
                                                                        ? item.color
                                                                        : item.appearance == 2
                                                                        ? item.color.withOpacity(0.5)
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
                                                                          child: Container(
                                                                            padding: EdgeInsets.symmetric(
                                                                              horizontal: 16 * scaleRatio,
                                                                              vertical: 8 * scaleRatio,
                                                                            ),
                                                                            decoration: BoxDecoration(
                                                                              color: bgColor,
                                                                              borderRadius: BorderRadius.circular(
                                                                                8 * scaleRatio,
                                                                              ),
                                                                            ),
                                                                            child: Stack(
                                                                              alignment: Alignment.center,
                                                                              children: [
                                                                                if (item.appearance == 3)
                                                                                  Text(
                                                                                    item.text,
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
                                                                                        ..strokeWidth =
                                                                                            scaledFontSize * 0.25
                                                                                        ..strokeJoin = StrokeJoin.round
                                                                                        ..strokeCap = StrokeCap.round
                                                                                        ..color = item.color,
                                                                                    ),
                                                                                  ),
                                                                                Text(
                                                                                  item.text,
                                                                                  textAlign: item.alignment,
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

                                                                  /// SHAPES LOOP
                                                                  ...data.shapes.map((shape) {
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
                                                                              width:
                                                                                  (shape.size * shape.scaleX.abs()) *
                                                                                  scaleRatio,
                                                                              height:
                                                                                  (shape.size * shape.scaleY.abs()) *
                                                                                  scaleRatio,
                                                                              child: FittedBox(
                                                                                fit: BoxFit.fill,
                                                                                child: Transform.scale(
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
                                              );

                                              double? targetRatio = _getPreviewAspectRatio(_selectedPageSize);

                                              if (targetRatio != null) {
                                                return Center(
                                                  child: AspectRatio(
                                                    aspectRatio: targetRatio,
                                                    child: Container(
                                                      color: Colors.white, // Paper ka white background
                                                      //child: pagePreviewContent,
                                                      child: Center(child: pagePreviewContent),
                                                    ),
                                                  ),
                                                );
                                              }
                                              return pagePreviewContent;
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),

                              /// Overlay Controls (Arrows and Page Count)
                              if (!isCroppingMode)
                                Positioned(
                                  bottom: 20,
                                  left: 16,
                                  right: 16,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Tooltip(
                                        message: "Previous Page",
                                        child: GestureDetector(
                                          onTap: currentPage > 0 ? _previousPage : null,
                                          child: Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: currentPage > 0 ? Colors.black87 : Colors.black38,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.arrow_back_ios_new_rounded,
                                              color: currentPage > 0 ? Colors.white : Colors.white30,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Tooltip(
                                            message: isSelectionMode ? "Cancel Selection" : "Select Page",
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  isSelectionMode = !isSelectionMode;
                                                  if (!isSelectionMode) {
                                                    selectedPagesList.fillRange(0, selectedPagesList.length, false);
                                                  }
                                                  isResizeMode = false;
                                                  isThumbnailVisible = true;
                                                });
                                              },
                                              child: Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: isSelectionMode ? Colors.blueAccent : Colors.black87,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.library_add_check_rounded,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Tooltip(
                                            message: "Pages",
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  isThumbnailVisible = !isThumbnailVisible;
                                                });
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                decoration: BoxDecoration(
                                                  color: Colors.black87,
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Text(
                                                      isSelectionMode
                                                          ? "${selectedPagesList.where((e) => e == true).length} selected"
                                                          : "Page ${currentPage + 1} of ${docFiles.length}",
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Icon(
                                                      isThumbnailVisible
                                                          ? Icons.keyboard_arrow_down_rounded
                                                          : Icons.keyboard_arrow_up_rounded,
                                                      color: Colors.white,
                                                      size: 18,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Tooltip(
                                        message: "Next Page",
                                        child: GestureDetector(
                                          onTap: currentPage < docFiles.length - 1 ? _nextPage : null,
                                          child: Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: currentPage < docFiles.length - 1
                                                  ? Colors.black87
                                                  : Colors.black38,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              color: currentPage < docFiles.length - 1 ? Colors.white : Colors.white30,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),

                        /// --- THUMBNAILS LIST ---
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          height: isThumbnailVisible ? 90.0 : 0.0,
                          child: ClipRect(
                            child: Container(
                              height: 90,
                              color: const Color(0xFF1E1E1E),
                              child: ReorderableListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: docFiles.length,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                onReorderStart: (int index) {
                                  _saveEditsToMemory(); // Memory me save kardo
                                  HapticFeedback.mediumImpact(); // Solid vibration feel
                                  if (!isSelectionMode) {
                                    setState(() {
                                      isSelectionMode = true;
                                      _showFilterMenu = false;
                                      _showAdjustMenu = false;
                                      isResizeMode = false;
                                    });
                                  }
                                },
                                onReorder: (int oldIndex, int newIndex) {
                                  setState(() {
                                    if (oldIndex < newIndex) {
                                      newIndex -= 1;
                                    }

                                    if (oldIndex == newIndex) return;
                                    final Map<String, dynamic> item = docFiles.removeAt(oldIndex);
                                    docFiles.insert(newIndex, item);
                                    List<bool> growableSelection = List<bool>.from(selectedPagesList);
                                    final bool selItem = growableSelection.removeAt(oldIndex);
                                    growableSelection.insert(newIndex, selItem);
                                    selectedPagesList = growableSelection;
                                    if (currentPage == oldIndex) {
                                      currentPage = newIndex;
                                    } else if (currentPage > oldIndex && currentPage <= newIndex) {
                                      currentPage -= 1;
                                    } else if (currentPage < oldIndex && currentPage >= newIndex) {
                                      currentPage += 1;
                                    }
                                  });
                                  _loadEditsFromMemory();

                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (_pageController.hasClients) {
                                      _pageController.jumpToPage(currentPage);
                                    }
                                  });

                                  HapticFeedback.lightImpact();
                                },

                                proxyDecorator: (Widget child, int index, Animation<double> animation) {
                                  return Material(
                                    color: Colors.transparent,
                                    elevation: 10,
                                    shadowColor: Colors.black54,
                                    child: child,
                                  );
                                },

                                itemBuilder: (context, index) {
                                  bool isSelected = currentPage == index;
                                  bool isChecked = selectedPagesList[index];

                                  return GestureDetector(
                                    key: ObjectKey(docFiles[index]),

                                    onTap: () {
                                      _pageController.animateToPage(
                                        index,
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      );
                                    },
                                    child: Container(
                                      width: 60,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: isSelected ? Colors.blue : Colors.transparent,
                                          width: 3,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),

                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(2),
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: Builder(
                                                builder: (context) {
                                                  Widget thumbnailContent = RotatedBox(
                                                    quarterTurns: _imageQuarterTurns[index],
                                                    child: Stack(
                                                      alignment: Alignment.center,
                                                      children: [
                                                        ColorFiltered(
                                                          colorFilter: _getAdjustColorFilter(
                                                            _pageBrightness[index],
                                                            _pageContrast[index],
                                                          ),
                                                          child: ColorFiltered(
                                                            colorFilter:
                                                                _getColorFilter(_pageFilters[index]) ??
                                                                const ColorFilter.mode(
                                                                  Colors.transparent,
                                                                  BlendMode.multiply,
                                                                ),
                                                            child: Image.file(
                                                              docFiles[index]['cropped'] as File,
                                                              fit: BoxFit.contain,
                                                            ),
                                                          ),
                                                        ),

                                                        if (_pageMarkups[index] != null &&
                                                            _pageMarkups[index] is MarkupExportData) ...[
                                                          /// --- DRAWING STROKES ---
                                                          Positioned.fill(
                                                            child: CustomPaint(
                                                              painter: DrawingPainter(
                                                                paths: (_pageMarkups[index] as MarkupExportData).paths,
                                                                currentPoints: [],
                                                                currentColor: Colors.transparent,
                                                                currentStrokeWidth: 0,
                                                                currentOpacity: 0,
                                                                isEraser: false,
                                                              ),
                                                            ),
                                                          ),

                                                          /// --- TEXTS & SHAPES ---
                                                          Positioned.fill(
                                                            child: LayoutBuilder(
                                                              builder: (context, constraints) {
                                                                double canvasW = constraints.maxWidth;
                                                                double canvasH = constraints.maxHeight;
                                                                double scaleRatio = canvasW / 400.0;
                                                                MarkupExportData data = _pageMarkups[index];

                                                                return Stack(
                                                                  clipBehavior: Clip.none,
                                                                  children: [
                                                                    /// TEXTS LOOP
                                                                    ...data.texts.map((item) {
                                                                      double scaledFontSize =
                                                                          item.fontSize * scaleRatio;
                                                                      Color textColor = item.appearance == 0
                                                                          ? item.color
                                                                          : (item.appearance == 1 ||
                                                                                item.appearance == 2)
                                                                          ? (item.color.computeLuminance() > 0.5
                                                                                ? Colors.black
                                                                                : Colors.white)
                                                                          : Colors.white;
                                                                      Color bgColor = item.appearance == 1
                                                                          ? item.color
                                                                          : item.appearance == 2
                                                                          ? item.color.withOpacity(0.5)
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
                                                                            child: Container(
                                                                              padding: EdgeInsets.symmetric(
                                                                                horizontal: 16 * scaleRatio,
                                                                                vertical: 8 * scaleRatio,
                                                                              ),
                                                                              decoration: BoxDecoration(
                                                                                color: bgColor,
                                                                                borderRadius: BorderRadius.circular(
                                                                                  8 * scaleRatio,
                                                                                ),
                                                                              ),
                                                                              child: Stack(
                                                                                alignment: Alignment.center,
                                                                                children: [
                                                                                  if (item.appearance == 3)
                                                                                    Text(
                                                                                      item.text,
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
                                                                                          ..strokeWidth =
                                                                                              scaledFontSize * 0.25
                                                                                          ..strokeJoin =
                                                                                              StrokeJoin.round
                                                                                          ..strokeCap = StrokeCap.round
                                                                                          ..color = item.color,
                                                                                      ),
                                                                                    ),
                                                                                  Text(
                                                                                    item.text,
                                                                                    textAlign: item.alignment,
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
                                                                    ...data.shapes.map((shape) {
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
                                                                                width:
                                                                                    (shape.size * shape.scaleX.abs()) *
                                                                                    scaleRatio,
                                                                                height:
                                                                                    (shape.size * shape.scaleY.abs()) *
                                                                                    scaleRatio,
                                                                                child: FittedBox(
                                                                                  fit: BoxFit.fill,
                                                                                  child: Transform.scale(
                                                                                    scaleX: shape.scaleX < 0
                                                                                        ? -1.0
                                                                                        : 1.0,
                                                                                    scaleY: shape.scaleY < 0
                                                                                        ? -1.0
                                                                                        : 1.0,
                                                                                    child: Icon(
                                                                                      shape.icon,
                                                                                      color: shape.color,
                                                                                    ),
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
                                                  );

                                                  ///  WHITE PAPER CANVAS LOGIC (Thumbnail me bhi apply hoga)
                                                  double? targetRatio = _getPreviewAspectRatio(_selectedPageSize);

                                                  if (targetRatio != null) {
                                                    return Center(
                                                      child: AspectRatio(
                                                        aspectRatio: targetRatio,
                                                        child: Container(
                                                          color: Colors.white,
                                                          child: Center(child: thumbnailContent),
                                                        ),
                                                      ),
                                                    );
                                                  }

                                                  // Auto Fit Logic
                                                  return Center(child: thumbnailContent);
                                                },
                                              ),
                                            ),

                                            // Top-Left Corner Checkbox
                                            if (isSelectionMode)
                                              Positioned(
                                                top: 2,
                                                left: 2,
                                                child: GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      selectedPagesList[index] = !selectedPagesList[index];
                                                    });
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.all(2),
                                                    decoration: BoxDecoration(
                                                      color: isChecked ? Colors.blueAccent : Colors.black45,
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: Colors.white, width: 1.5),
                                                    ),
                                                    child: Icon(
                                                      Icons.check_rounded,
                                                      size: 14,
                                                      color: isChecked ? Colors.white : Colors.transparent,
                                                    ),
                                                  ),
                                                ),
                                              ),

                                            Align(
                                              alignment: Alignment.bottomCenter,
                                              child: Container(
                                                margin: const EdgeInsets.all(4),
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.6),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '${index + 1}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
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
                        ),
                      ],
                    ),

                    /// --- LAYER 2: FILTER MENU ---
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      bottom: _showFilterMenu ? 0 : -200,
                      left: 0,
                      right: 0,
                      child: _buildFilterMenuWidget(),
                    ),

                    /// ---  LAYER 3: ADJUST MENU ---
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      bottom: _showAdjustMenu ? 0 : -200,
                      left: 0,
                      right: 0,
                      child: _buildAdjustMenuWidget(), // Naya adjust menu call kiya
                    ),

                    if (isProcessing)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black54, // Peeche ka thoda dark karne ke liye
                          child: const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
                        ),
                      ),

                    /// OCR Copy Banner
                    if (_showCopyBanner && _extractedText != null)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () => setState(() => _showCopyBanner = false),
                          child: Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 16, right: 16),
                              child: GestureDetector(
                                onTap: () {},
                                child: Material(
                                  color: Colors.transparent,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2C2C2C),
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 1.5),
                                      boxShadow: const [
                                        BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 5)),
                                      ],
                                    ),

                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        /// Copy Button
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: _extractedText!));
                                            showToast("Text copied to clipboard!");
                                            setState(() => _showCopyBanner = false);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blueAccent,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                          ),
                                          icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white),
                                          label: const Text(
                                            "Copy Text",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),

                                        const SizedBox(width: 12),

                                        /// 'X' Close Icon
                                        GestureDetector(
                                          onTap: () => setState(() => _showCopyBanner = false),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.white10,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
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
                  ],
                ),
              ),
            ),

            /// NEW ACTION TOOLS BAR (Guaranteed Slide Up/Down Animation)
            Container(
              height: 68,
              color: const Color(0xFF151515),
              child: ClipRect(
                child: Stack(
                  children: [
                    // NORMAL TOOLS:
                    AnimatedSlide(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      //offset: isCroppingMode ? const Offset(0, 1.0) : Offset.zero,
                      offset: (isCroppingMode || isSelectionMode || isResizeMode) ? const Offset(0, 1.0) : Offset.zero,
                      child: _buildNormalTools(),
                    ),

                    // CROP OPTIONS:
                    AnimatedSlide(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      offset: isCroppingMode ? Offset.zero : const Offset(0, 1.0),
                      child: _buildCropSubTools(),
                    ),

                    // Jab isSelectionMode true hoga, tab ye upar aayega
                    AnimatedSlide(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      offset: isSelectionMode ? Offset.zero : const Offset(0, 1.0),
                      child: _buildSelectedSubTools(),
                    ),

                    // NEW: RESIZE OPTIONS:
                    AnimatedSlide(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      offset: isResizeMode ? Offset.zero : const Offset(0, 1.0),
                      child: _buildResizeSubTools(),
                    ),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.black,
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Opacity(
                      opacity: isAnyToolActive ? 0.4 : 1.0,
                      child: TextButton(
                        onPressed: isAnyToolActive
                            ? null
                            : () {
                                _saveEditsToMemory();
                                showToast("Opening scanner...");

                                if (widget.isFromGallery) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ScannerScreen(initialImages: docFiles, isOpenedFromEditor: true),
                                    ),
                                  );
                                } else {
                                  widget.imageFiles.clear();
                                  widget.imageFiles.addAll(docFiles);
                                  Navigator.pop(context);
                                }
                              },
                        child: Text(
                          "Keep scanning",
                          style: TextStyle(
                            color: isAnyToolActive ? Colors.white70 : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    // Save PDF Button
                    Opacity(
                      opacity: isAnyToolActive ? 0.4 : 1.0,
                      child: ElevatedButton(
                        onPressed: isAnyToolActive ? null : _handleSaveClick,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.blueAccent.withOpacity(0.3),
                          disabledForegroundColor: Colors.white60,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Row(
                          children: [
                            Text("Save PDF", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            SizedBox(width: 4),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// --- RENAME DIALOG ---
  Future<void> _showRenameDialog(BuildContext context) async {
    TextEditingController nameController = TextEditingController(text: documentName);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2C2C2C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.only(top: 20, left: 24, right: 24, bottom: 12),
              title: const Text(
                "Rename",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              contentPadding: const EdgeInsets.only(left: 24, right: 24, bottom: 8),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 20),

                  // Text Box
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    autofocus: true,
                    cursorColor: Colors.blueAccent,
                    onChanged: (val) {
                      setDialogState(() {});
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black26,
                      hintText: "Enter document name",
                      hintStyle: const TextStyle(color: Colors.white38),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),

                      /// 'X' Clear Icon
                      suffixIcon: nameController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.white54, size: 20),
                              onPressed: () {
                                nameController.clear();
                                setDialogState(() {});
                              },
                            )
                          : null,

                      // Borders
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.only(right: 16, bottom: 16, top: 8),
              actions: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.white70, fontSize: 15)),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.blueAccent, width: 1.5), // Colored Border
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  onPressed: () {
                    String newName = nameController.text.trim();
                    if (newName.isNotEmpty) {
                      setState(() {
                        documentName = newName;
                      });
                      Navigator.pop(context);
                    } else {
                      showToast("Name cannot be empty");
                    }
                  },
                  child: const Text(
                    "Rename",
                    style: TextStyle(
                      color: Colors.blueAccent, // Colored Text
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// FILTER MENU WIDGET UI ---
  Widget _buildFilterMenuWidget() {
    String currentFilter = _pageFilters[currentPage];

    return GestureDetector(
      onTap: () {},
      onHorizontalDragUpdate: (_) {},
      onVerticalDragUpdate: (_) {},

      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.only(top: 16, bottom: 8),

        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thumbnails Options
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filterOptions.length,
                itemBuilder: (context, index) {
                  String filterName = _filterOptions[index];
                  bool isSelected = currentFilter == filterName;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelectionMode) {
                          for (int i = 0; i < _pageFilters.length; i++) {
                            if (selectedPagesList[i] == true) {
                              _pageFilters[i] = filterName;
                            }
                          }
                        } else {
                          if (_applyToAllPages) {
                            for (int i = 0; i < _pageFilters.length; i++) {
                              _pageFilters[i] = filterName;
                            }
                          } else {
                            _pageFilters[currentPage] = filterName;
                          }
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Column(
                        children: [
                          Container(
                            width: 65,
                            height: 65,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelected ? Colors.blueAccent : Colors.transparent,
                                width: 2.5,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: ColorFiltered(
                                colorFilter:
                                    _getColorFilter(filterName) ??
                                    const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                                child: Image.file(docFiles[currentPage]['cropped'] as File, fit: BoxFit.cover),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            filterName,
                            style: TextStyle(
                              color: isSelected ? Colors.blueAccent : Colors.white70,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: isSelectionMode
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
                      child: Row(
                        children: [
                          Transform.scale(
                            scale: 0.85,
                            child: Switch(
                              value: _applyToAllPages,
                              onChanged: (val) {
                                setState(() {
                                  _applyToAllPages = val;
                                  if (val) {
                                    String activeFilter = _pageFilters[currentPage];
                                    for (int i = 0; i < _pageFilters.length; i++) {
                                      _pageFilters[i] = activeFilter;
                                    }
                                  }
                                });
                              },
                              activeColor: Colors.white,
                              activeTrackColor: Colors.blueAccent,
                              inactiveThumbColor: const Color(0xFFC0C0C0),
                              inactiveTrackColor: const Color(0xFF505050),
                              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text("Apply to all pages", style: TextStyle(color: Colors.white, fontSize: 14)),

                          const Spacer(),

                          // Settings Icon
                          Tooltip(
                            message: "Settings Filter",
                            child: IconButton(
                              icon: const Icon(Icons.settings, color: Colors.white, size: 24),
                              onPressed: () {
                                _showDefaultFilterDialog(context);
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// --- DEFAULT FILTER DIALOG ---
  Future<void> _showDefaultFilterDialog(BuildContext context) async {
    // Ye temporary variable user ki selection track karega dialog ke andar
    String tempSelectedFilter = _defaultFilter;

    // 5 filter options
    final List<String> filters = ["Original color", "Auto-color", "Grayscale", "Whiteboard", "Light text"];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2C2C2C),
              // Dark Theme
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.only(top: 20, left: 24, right: 24, bottom: 0),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Set default filter",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24, thickness: 1, height: 1), // Divider Line
                ],
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              // Radio Buttons (Select Boxes)
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: filters.map((filter) {
                  return RadioListTile<String>(
                    title: Text(filter, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                    value: filter,
                    groupValue: tempSelectedFilter,
                    activeColor: Colors.blueAccent,
                    // Select hone par blue
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          tempSelectedFilter = val;
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              actionsPadding: const EdgeInsets.only(right: 16, bottom: 16, top: 0),
              actions: [
                // Cancel Button
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.white70, fontSize: 15)),
                ),

                // Save Button
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.blueAccent, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  onPressed: () async {
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await prefs.setString('default_filter', tempSelectedFilter);

                    setState(() {
                      _defaultFilter = tempSelectedFilter; // Main state update
                    });

                    Navigator.pop(context); // Close dialog
                    showToast("Default filter set to $tempSelectedFilter");
                  },
                  child: const Text(
                    "Save",
                    style: TextStyle(color: Colors.blueAccent, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// --- ADJUST MENU WIDGET UI ---
  Widget _buildAdjustMenuWidget() {
    bool isBrightness = _activeAdjustTab == "Brightness";
    double currentValue = isBrightness ? _pageBrightness[currentPage] : _pageContrast[currentPage];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      onHorizontalDragUpdate: (_) {},
      onVerticalDragUpdate: (_) {},
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// --- TOP TABS (Brightness | Contrast) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _activeAdjustTab = "Brightness"),
                  child: Row(
                    children: [
                      Icon(
                        Icons.light_mode_outlined,
                        color: isBrightness ? Colors.blueAccent : Colors.white70,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Brightness",
                        style: TextStyle(color: isBrightness ? Colors.blueAccent : Colors.white70, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _activeAdjustTab = "Contrast"),
                  child: Row(
                    children: [
                      Icon(
                        Icons.contrast_outlined,
                        color: !isBrightness ? Colors.blueAccent : Colors.white70,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Contrast",
                        style: TextStyle(color: !isBrightness ? Colors.blueAccent : Colors.white70, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            /// --- VALUE TEXT ROW ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_activeAdjustTab, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  Text("${currentValue.toInt()}", style: const TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ),

            /// --- MAIN SLIDER ---
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 2.5,
                activeTrackColor: Colors.grey.shade500,
                inactiveTrackColor: Colors.grey.shade800,
                thumbColor: Colors.grey.shade400,
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: currentValue,
                min: -100,
                max: 100,
                onChanged: (val) {
                  setState(() {
                    // Bulk Adjust Logic for Selection Mode
                    if (isSelectionMode) {
                      for (int i = 0; i < docFiles.length; i++) {
                        if (selectedPagesList[i] == true) {
                          if (isBrightness) {
                            _pageBrightness[i] = val;
                          } else {
                            _pageContrast[i] = val;
                          }
                        }
                      }
                    } else {
                      // Normal Mode
                      if (isBrightness) {
                        if (_applyToAllPages) {
                          for (int i = 0; i < _pageBrightness.length; i++) _pageBrightness[i] = val;
                        } else {
                          _pageBrightness[currentPage] = val;
                        }
                      } else {
                        if (_applyToAllPages) {
                          for (int i = 0; i < _pageContrast.length; i++) _pageContrast[i] = val;
                        } else {
                          _pageContrast[currentPage] = val;
                        }
                      }
                    }
                  });
                },
              ),
            ),

            const SizedBox(height: 12),

            /// --- BOTTOM TOGGLE & RESET ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: isSelectionMode ? MainAxisAlignment.end : MainAxisAlignment.spaceBetween,
                children: [
                  if (!isSelectionMode)
                    Row(
                      children: [
                        Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: _applyToAllPages,
                            onChanged: (val) {
                              setState(() {
                                _applyToAllPages = val;
                                if (val) {
                                  double b = _pageBrightness[currentPage];
                                  double c = _pageContrast[currentPage];
                                  for (int i = 0; i < _pageBrightness.length; i++) {
                                    _pageBrightness[i] = b;
                                    _pageContrast[i] = c;
                                  }
                                }
                              });
                            },
                            activeColor: Colors.white,
                            activeTrackColor: Colors.blueAccent,
                            inactiveThumbColor: const Color(0xFFC0C0C0),
                            inactiveTrackColor: const Color(0xFF505050),
                            trackOutlineColor: MaterialStateProperty.all(Colors.transparent),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text("Apply to all pages", style: TextStyle(color: Colors.white, fontSize: 14)),
                      ],
                    ),

                  /// RESET BUTTON (Bulk logic updated)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (isSelectionMode) {
                          for (int i = 0; i < docFiles.length; i++) {
                            if (selectedPagesList[i] == true) {
                              _pageBrightness[i] = 0.0;
                              _pageContrast[i] = 0.0;
                            }
                          }
                        } else {
                          // Normal mode logic
                          if (_applyToAllPages) {
                            for (int i = 0; i < _pageBrightness.length; i++) {
                              _pageBrightness[i] = 0.0;
                              _pageContrast[i] = 0.0;
                            }
                          } else {
                            _pageBrightness[currentPage] = 0.0;
                            _pageContrast[currentPage] = 0.0;
                          }
                        }
                      });
                      showToast("$_activeAdjustTab reset to 0");
                    },
                    child: const Text(
                      "Reset",
                      style: TextStyle(color: Colors.blueAccent, fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// --- TOOLBAR WIDGETS ---

  Widget _buildNormalTools() {
    return SizedBox(
      key: const ValueKey("NormalTools"),
      height: 75,
      width: double.infinity,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        children: [
          _buildToolItem(
            label: "Retake",
            //icon: Symbols.reset_image_rounded,
            icon: Icons.restart_alt_rounded,
            tooltipMessage: "Retake current photo",
            onTap: _retakeImage,
          ),
          _buildToolItem(
            label: "Crop",
            icon: Icons.crop_rounded,
            tooltipMessage: "Crop & adjust borders",
            isSelected: isCroppingMode,
            onTap: _toggleCropMode,
          ),

          _buildToolItem(
            label: "Rotate",
            icon: Icons.rotate_right_rounded,
            tooltipMessage: "Rotate 90 degrees",
            onTap: _rotateImage,
            isRotate: true,
          ),

          _buildToolItem(
            label: "Filter",
            //icon: Symbols.masked_transitions_rounded,
            icon: Icons.animation_rounded,
            tooltipMessage: "Apply color filters",
            isSelected: _showFilterMenu,
            onTap: () {
              setState(() {
                _showFilterMenu = !_showFilterMenu;
                if (_showFilterMenu) _showAdjustMenu = false;
              });
            },
          ),

          _buildToolItem(
            label: "Adjust",
            icon: Icons.tune_rounded,
            tooltipMessage: "Adjust brightness and contrast",
            isSelected: _showAdjustMenu,
            onTap: () {
              setState(() {
                _showAdjustMenu = !_showAdjustMenu;
                if (_showAdjustMenu) _showFilterMenu = false;
              });
            },
          ),

          _buildToolItem(
            label: "Markup",
            icon: Icons.border_color_rounded,
            tooltipMessage: "Draw or add text on image",
            onTap: _openMarkupScreen,
          ),

          _buildToolItem(
            label: "Page Size",
            icon: Icons.aspect_ratio_rounded,
            tooltipMessage: "Change page layout size",
            isSelected: isResizeMode,
            onTap: () {
              setState(() {
                isResizeMode = true;
                _showFilterMenu = false;
                _showAdjustMenu = false;
                isThumbnailVisible = false;
              });
            },
          ),

          _buildToolItem(
            label: "Reorder",
            icon: Icons.swap_horizontal_circle_outlined,
            tooltipMessage: "Rearrange page sequence",
            onTap: _openReorderScreen,
          ),
          _buildToolItem(
            label: "Delete",
            icon: Icons.delete_outline_rounded,
            tooltipMessage: "Delete current page",
            onTap: _promptDeletePage,
          ),
        ],
      ),
    );
  }

  Widget _buildCropSubTools() {
    return SizedBox(
      key: const ValueKey("CropSubTools"),
      height: 75,
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildToolItem(label: "Cancel", icon: Icons.close_rounded, tooltipMessage: "Cancel Crop", onTap: _cancelCrop),
          _buildToolItem(
            label: "Auto",
            icon: Icons.auto_awesome_mosaic_rounded,
            tooltipMessage: "Reset to auto detect",
            onTap: _resetToAutoCrop,
          ),
          _buildToolItem(
            label: "Done",
            icon: Icons.check_rounded,
            tooltipMessage: "Save crop",
            isSelected: true,
            onTap: () async {
              await _saveNewCrop();
            },
          ),
        ],
      ),
    );
  }

  // --- RESIZE SUB TOOLS (Fixed Close Button) ---
  Widget _buildResizeSubTools() {
    bool hasSizeChanged = _selectedPageSize != _defaultPageSize;

    return SizedBox(
      key: const ValueKey("ResizeSubTools"),
      height: 75,
      width: double.infinity,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: _buildToolItem(
              label: hasSizeChanged ? "Done" : "Close",
              icon: hasSizeChanged ? Icons.check_rounded : Icons.close_rounded,
              tooltipMessage: hasSizeChanged ? "Apply changes" : "Close resize options",
              isSelected: hasSizeChanged,

              onTap: () {
                setState(() {
                  isResizeMode = false;
                  isThumbnailVisible = true;
                });
              },
            ),
          ),

          Container(height: 30, width: 1, color: Colors.white10, margin: const EdgeInsets.symmetric(horizontal: 4)),

          /// --- SCROLLABLE OPTIONS (Expanded taaki baki jagah le sake) ---
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              children: [
                // Auto Fit
                _buildToolItem(
                  label: "Auto Fit",
                  icon: Icons.fit_screen_rounded,
                  tooltipMessage: "Auto fit to image size",
                  isSelected: _selectedPageSize == "Auto Fit",
                  onTap: () => setState(() => _selectedPageSize = "Auto Fit"),
                ),

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
                  isSelected: _selectedPageSize == "Letter (L)",
                  onTap: () => setState(() => _selectedPageSize = "Letter (L)"),
                ),

                _buildToolItem(
                  label: "Legal (P)",
                  icon: Icons.crop_portrait_rounded,
                  tooltipMessage: "US Legal Portrait",
                  isSelected: _selectedPageSize == "Legal (P)",
                  onTap: () => setState(() => _selectedPageSize = "Legal (P)"),
                ),
                _buildToolItem(
                  label: "Legal (L)",
                  icon: Icons.crop_landscape_rounded,
                  tooltipMessage: "US Legal Landscape",
                  isSelected: _selectedPageSize == "Legal (L)",
                  onTap: () => setState(() => _selectedPageSize = "Legal (L)"),
                ),

                _buildToolItem(
                  label: "A4 (P)",
                  icon: Icons.crop_portrait_rounded,
                  tooltipMessage: "A4 Portrait",
                  isSelected: _selectedPageSize == "A4 (P)",
                  onTap: () => setState(() => _selectedPageSize = "A4 (P)"),
                ),
                _buildToolItem(
                  label: "A4 (L)",
                  icon: Icons.crop_landscape_rounded,
                  tooltipMessage: "A4 Landscape",
                  isSelected: _selectedPageSize == "A4 (L)",
                  onTap: () => setState(() => _selectedPageSize = "A4 (L)"),
                ),

                _buildToolItem(
                  label: "A3 (P)",
                  icon: Icons.crop_portrait_rounded,
                  tooltipMessage: "A3 Portrait",
                  isSelected: _selectedPageSize == "A3 (P)",
                  onTap: () => setState(() => _selectedPageSize = "A3 (P)"),
                ),
                _buildToolItem(
                  label: "A3 (L)",
                  icon: Icons.crop_landscape_rounded,
                  tooltipMessage: "A3 Landscape",
                  isSelected: _selectedPageSize == "A3 (L)",
                  onTap: () => setState(() => _selectedPageSize = "A3 (L)"),
                ),

                // 6. A5 Size
                _buildToolItem(
                  label: "A5 (P)",
                  icon: Icons.crop_portrait_rounded,
                  tooltipMessage: "A5 Portrait",
                  isSelected: _selectedPageSize == "A5 (P)",
                  onTap: () => setState(() => _selectedPageSize = "A5 (P)"),
                ),
                _buildToolItem(
                  label: "A5 (L)",
                  icon: Icons.crop_landscape_rounded,
                  tooltipMessage: "A5 Landscape",
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

  /// --- SELECTION MODE TOOLS ---
  Widget _buildSelectedSubTools() {
    bool hasSelection = selectedPagesList.contains(true);
    int selectedCount = selectedPagesList.where((e) => e == true).length;
    bool allSelected = selectedPagesList.isNotEmpty && selectedPagesList.every((e) => e == true);

    return SizedBox(
      key: const ValueKey("SelectedSubTools"),
      height: 75,
      width: double.infinity,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        children: [
          _buildToolItem(
            label: allSelected ? "Deselect" : "Select All", // Text dynamic
            icon: allSelected ? Icons.deselect_rounded : Icons.select_all_rounded, // Icon dynamic
            tooltipMessage: allSelected ? "Deselect all pages" : "Select all pages",
            onTap: () {
              setState(() {
                _showFilterMenu = false;
                _showAdjustMenu = false;

                if (allSelected) {
                  selectedPagesList.fillRange(0, selectedPagesList.length, false);
                } else {
                  selectedPagesList.fillRange(0, selectedPagesList.length, true);
                }
              });
            },
          ),

          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: hasSelection ? 1.0 : 0.4,
            child: IgnorePointer(
              ignoring: !hasSelection,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: selectedCount >= 2 ? 1.0 : 0.4,
                    child: IgnorePointer(
                      ignoring: selectedCount < 2,
                      child: _buildToolItem(
                        label: "Merge",
                        //icon: Symbols.stack_group_rounded,
                        icon: Icons.layers_rounded,
                        tooltipMessage: "Merge selected photos into one page",
                        onTap: () async {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
                          );

                          List<File> filesToMerge = await _prepareImagesForMerge();

                          if (mounted) Navigator.pop(context);

                          if (filesToMerge.isNotEmpty && mounted) {
                            final mergedFile = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => MergeScreen(selectedImages: filesToMerge)),
                            );

                            if (mergedFile != null && mergedFile is File) {
                              setState(() {
                                // A. Photo ko original list me daalo
                                docFiles.add({
                                  'original': mergedFile,
                                  'cropped': mergedFile,
                                  'rotation': 0,
                                  'filter': _defaultFilter,
                                  'brightness': 0.0,
                                  'contrast': 0.0,
                                  'markups': null,
                                  'cropPosition': null,
                                  'autoCropPosition': null,
                                });

                                _savedCropPositions = List.generate(
                                  docFiles.length,
                                  (i) => docFiles[i]['cropPosition'],
                                );
                                _autoCropPositions = List.generate(
                                  docFiles.length,
                                  (i) => docFiles[i]['autoCropPosition'],
                                );
                                _imageQuarterTurns = List.generate(
                                  docFiles.length,
                                  (i) => docFiles[i]['rotation'] ?? 0,
                                );
                                _pageFilters = List.generate(
                                  docFiles.length,
                                  (i) => docFiles[i]['filter'] ?? _defaultFilter,
                                );
                                _pageBrightness = List.generate(
                                  docFiles.length,
                                  (i) => docFiles[i]['brightness'] ?? 0.0,
                                );
                                _pageContrast = List.generate(docFiles.length, (i) => docFiles[i]['contrast'] ?? 0.0);
                                _pageMarkups = List.generate(docFiles.length, (i) => docFiles[i]['markups']);

                                selectedPagesList = List.generate(docFiles.length, (i) => false);

                                isSelectionMode = false;
                                currentPage = docFiles.length - 1; // Naye page par focus
                              });

                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (_pageController.hasClients) {
                                  _pageController.jumpToPage(currentPage);
                                }
                              });

                              showToast("Merged photo added!");
                            }
                          }
                        },
                      ),
                    ),
                  ),

                  _buildToolItem(
                    label: "Rotate",
                    icon: Icons.rotate_right_rounded,
                    tooltipMessage: "Rotate selected pages",
                    //onTap: () => showToast("Bulk rotate coming soon"),
                    isRotate: true,
                    onTap: _bulkRotateImages,
                  ),
                  _buildToolItem(
                    label: "Filter",
                    //icon: Symbols.masked_transitions_rounded,
                    icon: Icons.animation_rounded,
                    tooltipMessage: "Apply filter to selected pages",
                    isSelected: _showFilterMenu,
                    onTap: () {
                      setState(() {
                        _showFilterMenu = !_showFilterMenu;
                        if (_showFilterMenu) _showAdjustMenu = false;
                      });
                    },
                  ),
                  _buildToolItem(
                    label: "Adjust",
                    icon: Icons.tune_rounded,
                    tooltipMessage: "Adjust selected pages",
                    isSelected: _showAdjustMenu,
                    onTap: () {
                      setState(() {
                        _showAdjustMenu = !_showAdjustMenu;
                        if (_showAdjustMenu) _showFilterMenu = false;
                      });
                    },
                  ),
                  _buildToolItem(
                    label: "Delete",
                    icon: Icons.delete_outline_rounded,
                    tooltipMessage: "Delete selected pages",
                    onTap: _promptBulkDelete,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<File>> _prepareImagesForMerge() async {
    List<File> bakedFiles = [];
    final tempDir = await getTemporaryDirectory();

    for (int i = 0; i < docFiles.length; i++) {
      if (selectedPagesList[i] == true) {
        var map = docFiles[i];
        final File file = map['cropped'] as File;
        final Uint8List bytes = await file.readAsBytes();

        final ui.Codec codec = await ui.instantiateImageCodec(bytes, targetWidth: 1500);
        final ui.FrameInfo frameInfo = await codec.getNextFrame();
        final ui.Image uiImg = frameInfo.image;

        int turns = _imageQuarterTurns[i];
        bool isLandscape = turns % 2 != 0;
        double targetWidth = isLandscape ? uiImg.height.toDouble() : uiImg.width.toDouble();
        double targetHeight = isLandscape ? uiImg.width.toDouble() : uiImg.height.toDouble();

        final ui.PictureRecorder recorder = ui.PictureRecorder();
        final Canvas canvas = Canvas(recorder);

        // --- ROTATION LOGIC (Instantly on GPU) ---
        canvas.translate(targetWidth / 2, targetHeight / 2);
        canvas.rotate(turns * 3.141592653589793 / 2); // 90 degree = pi/2
        canvas.translate(-uiImg.width / 2, -uiImg.height / 2);

        // ---  FILTER & ADJUST LOGIC (Instantly on GPU via saveLayer) ---
        String activeFilter = _pageFilters[i];
        double activeBright = _pageBrightness[i];
        double activeContrast = _pageContrast[i];

        ColorFilter? baseFilter = _getColorFilter(activeFilter);
        ColorFilter adjustFilter = _getAdjustColorFilter(activeBright, activeContrast);

        Rect imageRect = Rect.fromLTWH(0, 0, uiImg.width.toDouble(), uiImg.height.toDouble());

        // Apply Adjustments
        canvas.saveLayer(imageRect, Paint()..colorFilter = adjustFilter);

        // Apply Color Filter (Agar koi select kiya hai)
        if (baseFilter != null) {
          canvas.saveLayer(imageRect, Paint()..colorFilter = baseFilter);
        }

        canvas.drawImage(uiImg, Offset.zero, Paint());

        if (baseFilter != null) canvas.restore();
        canvas.restore(); // Adjust layer restore

        // --- MARKUPS (Shapes, Text, Drawing) ---
        if (_pageMarkups[i] != null && _pageMarkups[i] is MarkupExportData) {
          MarkupExportData exportData = _pageMarkups[i];
          double scaleRatio = uiImg.width / 400.0;

          //  Draw Strokes (Drawing)
          DrawingPainter painter = DrawingPainter(
            paths: exportData.paths,
            currentPoints: [],
            currentColor: Colors.transparent,
            currentStrokeWidth: 0,
            currentOpacity: 0,
            isEraser: false,
          );
          painter.paint(canvas, Size(uiImg.width.toDouble(), uiImg.height.toDouble()));

          //  Draw Shapes
          for (var shape in exportData.shapes) {
            canvas.save();
            canvas.translate(shape.offset.dx * uiImg.width, shape.offset.dy * uiImg.height);
            canvas.rotate(shape.rotation);
            canvas.scale(shape.scaleX < 0 ? -1.0 : 1.0, shape.scaleY < 0 ? -1.0 : 1.0);

            TextPainter tp = TextPainter(
              text: TextSpan(
                text: String.fromCharCode(shape.icon.codePoint),
                style: TextStyle(
                  fontSize: shape.size * scaleRatio,
                  color: shape.color,
                  fontFamily: shape.icon.fontFamily,
                  package: shape.icon.fontPackage,
                ),
              ),
              textDirection: TextDirection.ltr,
            );
            tp.layout();
            tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
            canvas.restore();
          }

          //  Draw Texts
          for (var item in exportData.texts) {
            canvas.save();
            canvas.translate(item.offset.dx * uiImg.width, item.offset.dy * uiImg.height);
            canvas.rotate(item.rotation);

            double fontSize = item.fontSize * scaleRatio;
            Color textColor = item.appearance == 0
                ? item.color
                : (item.appearance == 1 || item.appearance == 2)
                ? (item.color.computeLuminance() > 0.5 ? Colors.black : Colors.white)
                : Colors.white;
            Color bgColor = item.appearance == 1
                ? item.color
                : item.appearance == 2
                ? item.color.withOpacity(0.5)
                : Colors.transparent;

            TextDecoration decoration = TextDecoration.none;
            if (item.isUnderline && item.isStrikethrough) {
              decoration = TextDecoration.combine([TextDecoration.underline, TextDecoration.lineThrough]);
            } else if (item.isUnderline) {
              decoration = TextDecoration.underline;
            } else if (item.isStrikethrough) {
              decoration = TextDecoration.lineThrough;
            }

            TextStyle style = TextStyle(
              color: textColor,
              fontSize: fontSize,
              fontFamily: item.font,
              fontWeight: item.isBold ? FontWeight.bold : FontWeight.normal,
              fontStyle: item.isItalic ? FontStyle.italic : FontStyle.normal,
              decoration: decoration,
              decorationColor: textColor,
              shadows: item.appearance == 0
                  ? [const Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(1, 1))]
                  : null,
            );

            TextPainter tp = TextPainter(
              text: TextSpan(text: item.text, style: style),
              textAlign: item.alignment,
              textDirection: TextDirection.ltr,
            );
            tp.layout();

            Rect bgRect = Rect.fromCenter(
              center: Offset.zero,
              width: tp.width + (32 * scaleRatio),
              height: tp.height + (16 * scaleRatio),
            );
            if (bgColor != Colors.transparent) {
              canvas.drawRRect(
                RRect.fromRectAndRadius(bgRect, Radius.circular(8 * scaleRatio)),
                Paint()..color = bgColor,
              );
            }

            if (item.appearance == 3) {
              TextPainter strokeTp = TextPainter(
                text: TextSpan(
                  text: item.text,
                  style: style.copyWith(
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = fontSize * 0.25
                      ..strokeJoin = StrokeJoin.round
                      ..strokeCap = StrokeCap.round
                      ..color = item.color,
                  ),
                ),
                textAlign: item.alignment,
                textDirection: TextDirection.ltr,
              );
              strokeTp.layout();
              strokeTp.paint(canvas, Offset(-strokeTp.width / 2, -strokeTp.height / 2));
            }

            tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
            canvas.restore();
          }
        }

        // ---  EXPORT (Extremely Fast Native PNG Encoding) ---
        final ui.Picture picture = recorder.endRecording();

        // Picture se final scaled image generate kar li
        final ui.Image finalImg = await picture.toImage(targetWidth.toInt(), targetHeight.toInt());

        // PNG format fast aur lossless hota hai background canvases ke liye
        final ByteData? byteData = await finalImg.toByteData(format: ui.ImageByteFormat.png);

        if (byteData != null) {
          String tempPath = '${tempDir.path}/merge_baked_${DateTime.now().millisecondsSinceEpoch}_$i.png';
          File tempFile = File(tempPath);
          await tempFile.writeAsBytes(byteData.buffer.asUint8List());
          bakedFiles.add(tempFile);
        }
      }
    }
    return bakedFiles;
  }

  /// Bulk Rotate Logic
  void _bulkRotateImages() {
    setState(() {
      _iconRotationTurns += 0.25;
      for (int i = 0; i < docFiles.length; i++) {
        if (selectedPagesList[i] == true) {
          _imageQuarterTurns[i] = (_imageQuarterTurns[i] + 1) % 4;
        }
      }
    });

    int selectedCount = selectedPagesList.where((e) => e == true).length;
    showToast("$selectedCount page(s) rotated");
  }

  // Delete Page Logic with Memory Sync
  Future<void> _promptDeletePage() async {
    _saveEditsToMemory();

    bool confirmDelete = await showCustomConfirmDialog(
      context,
      title: "Delete page",
      message: "Are you sure you want to delete this page from your scan?",
      positiveBtnText: "Delete",
      negativeBtnText: "Cancel",
      positiveBtnColor: Colors.redAccent,
    );

    if (confirmDelete) {
      if (docFiles.length == 1) {
        showToast("Document deleted");
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      } else {
        setState(() {
          docFiles.removeAt(currentPage);
          if (currentPage >= docFiles.length) {
            currentPage = docFiles.length - 1;
          }
        });
        _loadEditsFromMemory();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(currentPage);
          }
        });

        showToast("Page deleted");
      }
    }
  }

  /// Bulk Delete Logic
  Future<void> _promptBulkDelete() async {
    // 1. Check karo kitne pages selected hain
    int selectedCount = selectedPagesList.where((e) => e == true).length;
    if (selectedCount == 0) return;
    setState(() {
      _showFilterMenu = false;
      _showAdjustMenu = false;
    });

    _saveEditsToMemory();

    String titleText = selectedCount == 1 ? "Delete page" : "Delete $selectedCount pages";
    String messageText = selectedCount == 1
        ? "Are you sure you want to delete this page from your scan?"
        : "Are you sure you want to delete these $selectedCount pages from your scan?";

    bool confirmDelete = await showCustomConfirmDialog(
      context,
      title: titleText,
      message: messageText,
      positiveBtnText: "Delete",
      negativeBtnText: "Cancel",
      positiveBtnColor: Colors.redAccent,
    );

    if (confirmDelete) {
      if (selectedCount == docFiles.length) {
        showToast("Document deleted");
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      } else {
        setState(() {
          for (int i = docFiles.length - 1; i >= 0; i--) {
            if (selectedPagesList[i] == true) {
              docFiles.removeAt(i);
            }
          }

          if (currentPage >= docFiles.length) {
            currentPage = docFiles.length - 1;
          }

          isSelectionMode = false;
          selectedPagesList = List.filled(docFiles.length, false);
        });

        _loadEditsFromMemory();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(currentPage);
          }
        });

        showToast("$selectedCount page(s) deleted");
      }
    }
  }

  /// --- MARKUP LOGIC (VECTOR APPROACH) ---
  Future<void> _openMarkupScreen() async {
    if (_showFilterMenu || _showAdjustMenu) {
      setState(() {
        _showFilterMenu = false;
        _showAdjustMenu = false;
      });
      await Future.delayed(const Duration(milliseconds: 200));
    }

    File currentImage = docFiles[currentPage]['cropped']!;

    int turns = _imageQuarterTurns[currentPage];
    String activeFilter = _pageFilters[currentPage];
    double activeBright = _pageBrightness[currentPage];
    double activeContrast = _pageContrast[currentPage];
    dynamic existingMarkups = _pageMarkups[currentPage];

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MarkupScreen(
          imageFile: currentImage,
          rotationTurns: turns,
          filterName: activeFilter,
          brightness: activeBright,
          contrast: activeContrast,
          existingMarkups: existingMarkups,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _pageMarkups[currentPage] = result;
      });
    }
  }

  Widget _buildToolItem({
    required String label,
    required IconData icon,
    required String tooltipMessage,
    VoidCallback? onTap,
    bool isSelected = false,
    bool isRotate = false,
  }) {
    return Tooltip(
      message: tooltipMessage,
      child: GestureDetector(
        onTap: onTap ?? () => showToast("$label clicked"),
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
                isRotate
                    ? AnimatedRotation(
                        turns: _iconRotationTurns,
                        duration: const Duration(milliseconds: 300),
                        child: Icon(icon, color: Colors.white, size: 22),
                      )
                    : Icon(icon, color: Colors.white, size: 22),

                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// --- REAL-TIME MAIN PREVIEW CROP UI & MATH ---

  void _updateCropBounds(double dt, double db, double dl, double dr) {
    setState(() {
      double currentTop = cropTopRatio * _cropAreaHeight;
      double currentBottom = cropBottomRatio * _cropAreaHeight;
      double currentLeft = cropLeftRatio * _cropAreaWidth;
      double currentRight = cropRightRatio * _cropAreaWidth;

      currentTop = (currentTop + dt).clamp(0.0, _cropAreaHeight - currentBottom - 40.0);
      currentBottom = (currentBottom + db).clamp(0.0, _cropAreaHeight - currentTop - 40.0);
      currentLeft = (currentLeft + dl).clamp(0.0, _cropAreaWidth - currentRight - 40.0);
      currentRight = (currentRight + dr).clamp(0.0, _cropAreaWidth - currentLeft - 40.0);

      cropTopRatio = currentTop / _cropAreaHeight;
      cropBottomRatio = currentBottom / _cropAreaHeight;
      cropLeftRatio = currentLeft / _cropAreaWidth;
      cropRightRatio = currentRight / _cropAreaWidth;
    });
  }

  Future<void> _saveNewCrop() async {
    setState(() {
      isProcessing = true;
    });

    await Future.delayed(const Duration(milliseconds: 150));

    try {
      File originalFile = docFiles[currentPage]['original']!;
      final bytes = await originalFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);

      if (originalImage != null) {
        int x = (cropLeftRatio * originalImage.width).toInt();
        int y = (cropTopRatio * originalImage.height).toInt();
        int w = ((1.0 - cropLeftRatio - cropRightRatio) * originalImage.width).toInt();
        int h = ((1.0 - cropBottomRatio - cropTopRatio) * originalImage.height).toInt();

        x = x.clamp(0, originalImage.width);
        y = y.clamp(0, originalImage.height);
        w = w.clamp(10, originalImage.width - x);
        h = h.clamp(10, originalImage.height - y);

        img.Image newlyCropped = img.copyCrop(originalImage, x: x, y: y, width: w, height: h);

        final String newPath = originalFile.path.replaceAll(
          '.jpg',
          '_recropped_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        final newFile = File(newPath);
        await newFile.writeAsBytes(img.encodeJpg(newlyCropped, quality: 100));

        setState(() {
          docFiles[currentPage]['cropped'] = newFile;
          _savedCropPositions[currentPage] = {
            'top': cropTopRatio,
            'bottom': cropBottomRatio,
            'left': cropLeftRatio,
            'right': cropRightRatio,
          };

          isCroppingMode = false;
          isThumbnailVisible = true;
          isProcessing = false;
        });
      } else {
        setState(() => isProcessing = false);
      }
    } catch (e) {
      showToast("Error saving crop");
      setState(() => isProcessing = false);
    }
  }

  void _cancelCrop() {
    setState(() {
      isCroppingMode = false;
      isThumbnailVisible = true;
      isProcessing = false;
    });
  }

  Widget _buildInPlaceCropView() {
    File originalFile = docFiles[currentPage]['original']!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        child: AspectRatio(
          aspectRatio: _origWidth / _origHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _cropAreaWidth = constraints.maxWidth;
              _cropAreaHeight = constraints.maxHeight;

              double cropTop = cropTopRatio * _cropAreaHeight;
              double cropBottom = cropBottomRatio * _cropAreaHeight;
              double cropLeft = cropLeftRatio * _cropAreaWidth;
              double cropRight = cropRightRatio * _cropAreaWidth;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. Original Blur Image background
                  SizedBox(
                    width: _cropAreaWidth,
                    height: _cropAreaHeight,
                    child: Image.file(originalFile, fit: BoxFit.fill),
                  ),
                  // 2. Dark Overlay
                  Container(color: Colors.black.withOpacity(0.6)),

                  // 3. Main Crop Box
                  Positioned(
                    top: cropTop,
                    bottom: cropBottom,
                    left: cropLeft,
                    right: cropRight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Clear Crop Area
                        Positioned(
                          top: -cropTop,
                          bottom: -cropBottom,
                          left: -cropLeft,
                          right: -cropRight,
                          child: SizedBox(
                            width: _cropAreaWidth,
                            height: _cropAreaHeight,
                            child: Image.file(originalFile, fit: BoxFit.fill),
                          ),
                        ),

                        Container(
                          decoration: BoxDecoration(border: Border.all(color: Colors.blueAccent, width: 3.5)),
                        ),

                        _buildEdgeHandle(Alignment.topCenter, (d) => _updateCropBounds(d.delta.dy, 0, 0, 0)),
                        _buildEdgeHandle(Alignment.bottomCenter, (d) => _updateCropBounds(0, -d.delta.dy, 0, 0)),
                        _buildEdgeHandle(Alignment.centerLeft, (d) => _updateCropBounds(0, 0, d.delta.dx, 0)),
                        _buildEdgeHandle(Alignment.centerRight, (d) => _updateCropBounds(0, 0, 0, -d.delta.dx)),

                        _buildDragCorner(Alignment.topLeft, (d) => _updateCropBounds(d.delta.dy, 0, d.delta.dx, 0)),
                        _buildDragCorner(Alignment.topRight, (d) => _updateCropBounds(d.delta.dy, 0, 0, -d.delta.dx)),
                        _buildDragCorner(Alignment.bottomLeft, (d) => _updateCropBounds(0, -d.delta.dy, d.delta.dx, 0)),
                        _buildDragCorner(
                          Alignment.bottomRight,
                          (d) => _updateCropBounds(0, -d.delta.dy, 0, -d.delta.dx),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEdgeHandle(Alignment alignment, Function(DragUpdateDetails) onPan) {
    bool isVertical = alignment == Alignment.centerLeft || alignment == Alignment.centerRight;

    return Align(
      alignment: alignment,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: onPan,
        child: Transform.translate(
          offset: Offset(alignment.x * 20, alignment.y * 20),
          child: Container(
            width: isVertical ? 40 : double.infinity,
            height: isVertical ? double.infinity : 40,
            color: Colors.transparent,
            // Touch area dikhega nahi par exist karega
            alignment: Alignment.center,
            child: Container(
              width: isVertical ? 8 : 40,
              height: isVertical ? 40 : 8,
              decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDragCorner(Alignment alignment, Function(DragUpdateDetails) onPan) {
    return Align(
      alignment: alignment,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: onPan,
        child: Transform.translate(
          offset: Offset(alignment.x * 20, alignment.y * 20),
          child: Container(
            width: 50,
            height: 50,
            color: Colors.transparent,
            alignment: Alignment.center,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blueAccent, width: 3.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// end main class

/// --- CUSTOM DOTTED UNDERLINE PAINTER ---
class DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    double dashWidth = 3.0;
    double dashSpace = 3.0;
    double startX = 0;

    final paint = Paint()
      ..color = Colors.white54
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + 1, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
