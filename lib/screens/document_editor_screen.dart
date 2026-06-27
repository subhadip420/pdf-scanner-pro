import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
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

import 'custom_dialog.dart';
import 'home_screen.dart';
import 'markup_screen.dart';

import 'dart:ui' as ui;
import 'dart:typed_data';

class DocumentEditorScreen extends StatefulWidget {
  //final List<File> imageFiles; // Real images coming from ScannerScreen
  //final List<Map<String, File>> imageFiles;
  // 🚨 FIX 1: 'File' ko hata kar 'dynamic' likho
  final List<Map<String, dynamic>> imageFiles;

  //const DocumentEditorScreen({super.key, required this.imageFiles});
  const DocumentEditorScreen({Key? key, required this.imageFiles}) : super(key: key);

  @override
  State<DocumentEditorScreen> createState() => _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends State<DocumentEditorScreen> {
  late String documentName;
  late PageController _pageController;
  int currentPage = 0;
  bool isThumbnailVisible = true; // By default thumbnails dikhenge
  RewardedAd? _rewardedAd; // Ad store karne ke liye

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

  // FIX 1: Har image ka original AI (Auto) crop save rakhne ke liye
  late List<Map<String, double>?> _autoCropPositions;

  // Icon ki animation track karne ke liye (0.25 matlab 90 degree)
  double _iconRotationTurns = 0.0;

  // Har image kitni baar rotate hui hai (0, 1, 2, ya 3) uski list
  late List<int> _imageQuarterTurns;

  // PageView ka current index (Agar tumhare paas pehle se 'currentIndex' ya 'currentPage' name ka variable hai, toh use hi use karna)
  int _currentPageIndex = 0;

  // Filter Menu State Variables
  bool _showFilterMenu = false;
  bool _applyToAllPages = false;
  late List<String> _pageFilters; // 🚨 Har page ka alag filter track karega
  // 🚨 FIX: Filter ke saare options ki list define kardo
  final List<String> _filterOptions = ["Original color", "Auto-color", "Light text", "Grayscale", "Whiteboard"];

  bool _showAdjustMenu = false; // 🚨 Naya Adjust menu track karne ke liye
  late List<double> _pageBrightness; // 🚨 Har page ki brightness
  late List<double> _pageContrast; // 🚨 Har page ka contrast
  String _activeAdjustTab = "Brightness"; // "Brightness" ya "Contrast" track karega

  // Har image kitni baar rotate hui hai (0, 1, 2, ya 3) uski list
  //late List<int> _imageQuarterTurns;

  // 🚨 NAYA VARIABLE: Vector (Drawing/Shapes/Text) data store karne ke liye
  late List<dynamic> _pageMarkups;

  // 🚨 NEW: Selection tracking variables
  bool isSelectionMode = false;
  late List<bool> selectedPagesList;

  @override
  void initState() {
    super.initState();
    documentName = _generateDefaultName();
    // Open the latest captured photo first
    currentPage = widget.imageFiles.length - 1;
    _pageController = PageController(initialPage: currentPage);

    _savedCropPositions = List.generate(widget.imageFiles.length, (index) => null);
    _autoCropPositions = List.generate(widget.imageFiles.length, (index) => null); // Auto memory init

    _loadRewardedAd(); // Screen open hote hi ad background me load hona shuru ho jayega

    _imageQuarterTurns = List.filled(widget.imageFiles.length, 0);
    _pageFilters = List.filled(widget.imageFiles.length, "Original color"); // 🚨 Default filter set kiya
    _pageBrightness = List.filled(widget.imageFiles.length, 0.0); // Default 0
    _pageContrast = List.filled(widget.imageFiles.length, 0.0); // Default 0

    // 🚨 NAYA: Empty markups list init
    _pageMarkups = List.filled(widget.imageFiles.length, null);

    selectedPagesList = List.filled(widget.imageFiles.length, false);

    _loadEditsFromMemory();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 🚨 NEW: Discard Scan Logic (For PopScope)
  Future<void> _promptDiscard() async {
    bool discard = await showCustomConfirmDialog(
      context,
      title: "Discard this scan?",
      message: "This will discard the scan you have captured. Are you sure?",
      positiveBtnText: "Discard",
      negativeBtnText: "Cancel",
      positiveBtnColor: Colors.redAccent,
    );

    // Agar user Discard confirm kare, tabhi Home par jao
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

  // 🚨 NEW: State reload helper (Init aur Reorder dono me kaam aayega)
  void _loadEditsFromMemory() {
    setState(() {
      _savedCropPositions = List.generate(widget.imageFiles.length, (i) => widget.imageFiles[i]['cropPosition']);
      _autoCropPositions = List.generate(widget.imageFiles.length, (i) => widget.imageFiles[i]['autoCropPosition']);
      _imageQuarterTurns = List.generate(widget.imageFiles.length, (i) => widget.imageFiles[i]['rotation'] ?? 0);
      _pageFilters = List.generate(widget.imageFiles.length, (i) => widget.imageFiles[i]['filter'] ?? "Original color");
      _pageBrightness = List.generate(widget.imageFiles.length, (i) => widget.imageFiles[i]['brightness'] ?? 0.0);
      _pageContrast = List.generate(widget.imageFiles.length, (i) => widget.imageFiles[i]['contrast'] ?? 0.0);
      _pageMarkups = List.generate(widget.imageFiles.length, (i) => widget.imageFiles[i]['markups']);

      // Safety check: Agar current page bounds se bahar ho jaye toh 0 pe set kar do
      if (currentPage >= widget.imageFiles.length) {
        currentPage = 0;
      }
    });
  }

  // 🚨 FIX 2: Back jaane se pehle saari settings ko map me save karne ka function
  void _saveEditsToMemory() {
    for (int i = 0; i < widget.imageFiles.length; i++) {
      widget.imageFiles[i]['rotation'] = _imageQuarterTurns[i];
      widget.imageFiles[i]['filter'] = _pageFilters[i];
      widget.imageFiles[i]['brightness'] = _pageBrightness[i];
      widget.imageFiles[i]['contrast'] = _pageContrast[i];
      widget.imageFiles[i]['markups'] = _pageMarkups[i];
      widget.imageFiles[i]['cropPosition'] = _savedCropPositions[i];
      widget.imageFiles[i]['autoCropPosition'] = _autoCropPositions[i];
    }
  }

  // --- FILTER LOGIC ---
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

  // --- 🚨 ADJUST LOGIC (Brightness & Contrast) ---
  ColorFilter _getAdjustColorFilter(double brightness, double contrast) {
    // Brightness range: -100 to 100 -> maps to -255 to 255
    double b = brightness * 2.55;

    // Contrast range: -100 to 100 -> maps to 0.0 to 2.0 (e.g., -100=0.0, 0=1.0, 100=2.0)
    double c = 1.0 + (contrast / 100.0);
    double t = (1.0 - c) * 127.5; // Offset for contrast centering

    return ColorFilter.matrix([c, 0, 0, 0, t + b, 0, c, 0, 0, t + b, 0, 0, c, 0, t + b, 0, 0, 0, 1, 0]);
  }

  // --- 🚨 NAYE HELPER FUNCTIONS (Exact UI Math Sync) ---
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
    // 1. Apply Rotation
    if (turns != 0) {
      decodedImage = img.copyRotate(decodedImage, angle: turns * 90);
    }

    // 2. Apply Filters (EXACT Matrix matching UI)
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

    // 3. Apply Adjustments (EXACT Matrix matching UI)
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

  // --- CROP TOOL FUNCTIONS ---

  Future<void> _toggleCropMode() async {
    if (isCroppingMode) {
      await _saveNewCrop();
    } else {
      // 1. STATE CHANGE: Toolbar ko "Hide Down" aur Crop Option ko "Hide Up" karega
      setState(() {
        isCroppingMode = true;
        isThumbnailVisible = false;
      });

      // 2. WAIT: Animation poora hone ke liye exactly 300ms rukenge
      await Future.delayed(const Duration(milliseconds: 300));

      // 3. HEAVY WORK: Ab photo read aur decode hogi (UI freeze nahi hoga)
      File origFile = widget.imageFiles[currentPage]['original']!;
      File cropFile = widget.imageFiles[currentPage]['cropped']!;

      final origBytes = await origFile.readAsBytes();
      final cropBytes = await cropFile.readAsBytes();

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
        });
      }
    }
  }

  // FIX 3: Wapas Auto-Crop wali AI position par reset karna
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

  // 🚨 NEW: Reorder logic
  Future<void> _openReorderScreen() async {
    if (widget.imageFiles.length <= 1) {
      showToast("Only one page available");
      return;
    }

    // Wahan jaane se pehle current changes memory me save karo
    _saveEditsToMemory();

    // Reorder screen kholo aur nai list ka wait karo
    final reorderedList = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReorderScreen(
          // List ki copy bhej rahe hain taaki original safe rahe
          imageFiles: List.from(widget.imageFiles),
        ),
      ),
    );

    // Jab user OK (Checkmark) dabayega toh nai list yahan aayegi
    if (reorderedList != null && reorderedList is List<Map<String, dynamic>>) {
      widget.imageFiles.clear();
      widget.imageFiles.addAll(reorderedList);

      // Naye order ke hisab se memory wapas load karo
      _loadEditsFromMemory();

      // PageView ko naye order ki first image pe bhej do
      _pageController.jumpToPage(0);
      showToast("Pages reordered successfully");
    }
  }

  // Generate default file name based on current date
  String _generateDefaultName() {
    final now = DateTime.now();
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return "Scanner Pro ${months[now.month - 1]} ${now.day}, ${now.year}";
  }

  // 1. Ad load karne ka function (With Memory Management)
  void _loadRewardedAd() {
    print("AdMob: Loading ad...");

    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          print("AdMob: Ad loaded successfully!");

          // Memory leak rokne aur agla ad ready rakhne ke liye callback
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (RewardedAd ad) {
              ad.dispose();
              _rewardedAd = null;
              _loadRewardedAd(); // User ke ad close karte hi naya ad background me load kardo
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

  // 2. Smart Save Click Handler (With 2 Sec Wait Logic)
  Future<void> _handleSaveClick() async {
    // Agar ad pehle se ready hai, toh direct show kardo
    if (_rewardedAd != null) {
      _showRewardAd();
      return;
    }

    // Agar ad ready nahi hai, toh Loading Dialog dikhao
    showDialog(
      context: context,
      barrierDismissible: false, // User screen touch karke band na kar paye
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
    );

    // Max 2 seconds wait karna (100ms x 20 bar check karega)
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (_rewardedAd != null) break; // Agar wait karte time ad load ho gaya, toh loop break
    }

    // Wait khatam, Loading Dialog close karo
    if (mounted) Navigator.pop(context);

    // Check karo ad aaya ya nahi
    if (_rewardedAd != null) {
      _showRewardAd(); // Ad aagaya to dikhao
    } else {
      // 2 sec baad bhi no ad? Direct save kardo bina user ko block kiye
      showToast("Saving PDF...");
      _generateAndSavePdf();
    }
  }

  // 3. Ad dikhane aur PDF save karne ka helper function
  void _showRewardAd() {
    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        // User ne ad dekh liya, ab PDF save kardo
        _generateAndSavePdf();
      },
    );
  }

  // 3. Main PDF generate karne ka function (With Real Image Rotation & Markups)
  Future<void> _generateAndSavePdf() async {
    showToast("Generating PDF...");

    final pdf = pw.Document();
    for (int i = 0; i < widget.imageFiles.length; i++) {
      var map = widget.imageFiles[i];
      //final File file = map['cropped']!;
      // PDF function me yaha update karna:
      final File file = map['cropped'] as File;

      var imageBytes = await file.readAsBytes();

      int turns = _imageQuarterTurns[i];
      String activeFilter = _pageFilters[i];
      double activeBright = _pageBrightness[i];
      double activeContrast = _pageContrast[i];

      // --- STEP 1: APPLY FILTERS ONLY (Bina Rotate Kiye) ---
      if (activeFilter != "Original color" || activeBright != 0.0 || activeContrast != 0.0) {
        img.Image? decodedImage = img.decodeImage(imageBytes);
        if (decodedImage != null) {
          // 🚨 FIX: Yahan 'turns' ko 0 pass kar rahe hain taaki abhi photo na ghume
          decodedImage = _processImageSync(decodedImage, 0, activeFilter, activeBright, activeContrast);
          imageBytes = img.encodeJpg(decodedImage, quality: 100);
        }
      }

      // --- STEP 2: STAMP VECTOR DRAWINGS (Bina Ghumi hui photo par) ---
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

        // A. Draw Strokes (Pen/Eraser)
        DrawingPainter painter = DrawingPainter(
          paths: exportData.paths,
          currentPoints: [],
          currentColor: Colors.transparent,
          currentStrokeWidth: 0,
          currentOpacity: 0,
          isEraser: false,
        );
        painter.paint(canvas, size);

        // B. Draw Shapes (Icons)
        for (var shape in exportData.shapes) {
          canvas.save();
          canvas.translate(shape.offset.dx * size.width, shape.offset.dy * size.height);
          canvas.rotate(shape.rotation);
          canvas.scale(shape.scaleX < 0 ? -1.0 : 1.0, shape.scaleY < 0 ? -1.0 : 1.0);

          // Icon ko TextPainter ke through Canvas par draw karne ka hack
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

        // C. Draw Texts
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

          // Background box (Agar solid/transparent ho)
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

          // Stroke text effect
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

      // --- STEP 3: APPLY ROTATION LAST MEIN (Drawing lagne ke baad) ---
      if (turns != 0) {
        img.Image? decodedStampedImage = img.decodeImage(imageBytes);
        if (decodedStampedImage != null) {
          // 🚨 FIX: Ab photo aur drawing ek sath perfectly ghum jayenge (UI jaisa exact match)
          decodedStampedImage = img.copyRotate(decodedStampedImage, angle: turns * 90);
          imageBytes = img.encodeJpg(decodedStampedImage, quality: 90);
        }
      }

      // --- STEP 4: ADD TO PDF ---
      final image = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          margin: pw.EdgeInsets.zero,
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain));
          },
        ),
      );
    }

    try {
      // 1. Storage Permission Manage Karo
      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }

      if (!await Permission.manageExternalStorage.isGranted) {
        showToast("Storage permission is required to save PDF");
        return;
      }

      // 2. Public Documents folder ka path set karein
      final Directory publicDir = Directory('/storage/emulated/0/Documents/PDF Scanner Pro');

      // 3. Agar folder nahi hai, toh naya banao
      if (!await publicDir.exists()) {
        await publicDir.create(recursive: true);
      }

      // 4. Unique File Name Generator
      String baseFilePath = "${publicDir.path}/$documentName";
      String finalFilePath = "$baseFilePath.pdf";
      File file = File(finalFilePath);

      int counter = 1;
      while (await file.exists()) {
        finalFilePath = "$baseFilePath ($counter).pdf";
        file = File(finalFilePath);
        counter++;
      }

      // Safely save karein naye unique naam ke sath
      await file.writeAsBytes(await pdf.save());

      showToast("Saved in Documents/PDF Scanner Pro");

      // 5. Seedhe Home Screen par redirect aur baaki sab close
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

  // Show toast notification
  void showToast(String msg) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.white,
      textColor: Colors.black,
    );
  }

  // Go to previous page
  void _previousPage() {
    if (currentPage > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      showToast("First page");
    }
  }

  // Go to next page
  void _nextPage() {
    if (currentPage < widget.imageFiles.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      showToast("Last page");
    }
  }

  void _rotateImage() {
    setState(() {
      // 1. Icon ko smoothly 90 degree ghumane ke liye (0.25 turns)
      _iconRotationTurns += 0.25;

      // 2. Jo page abhi screen par hai, uska rotation 1 step badha do
      // % 4 isliye lagaya taaki 4 baar ghumne par wapas 0 (normal) ho jaye
      //_imageQuarterTurns[_currentPageIndex] = (_imageQuarterTurns[_currentPageIndex] + 1) % 4;
      _imageQuarterTurns[currentPage] = (_imageQuarterTurns[currentPage] + 1) % 4;
    });
  }

  Future<void> _retakeImage() async {
    try {
      // 1. ScannerScreen ko 'Retake' mode me open karo
      // Yeh result variable mein us File ka wait karega jo wahan se pop hogi
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ScannerScreen(isRetakeMode: true)),
      );

      // 2. Agar user ne photo click ki (ya gallery se li) aur 'result' me naya File wapas aaya
      if (result != null && result is File) {
        setState(() {
          // Current page par purani photo ki jagah nayi photo set kardo
          widget.imageFiles[currentPage] = {'original': result, 'cropped': result};

          // 🚨 ZAROORI: Is naye page ke liye purani settings (crop/rotate) RESET kardo
          _imageQuarterTurns[currentPage] = 0;
          _savedCropPositions[currentPage] = null;
          _autoCropPositions[currentPage] = null;
          _pageFilters[currentPage] = "Original color"; // 🚨 Retake par filter wapas original hoga
          _pageBrightness[currentPage] = 0.0; // 🚨 Retake par brightness reset
          _pageContrast[currentPage] = 0.0; // 🚨 Retake par contrast reset
        });

        showToast("Page ${currentPage + 1} replaced successfully!");
      }
      // 3. Agar result null hai (user ne back button daba diya bina photo liye),
      // toh purani photo waisi ki waisi hi rahegi (koi change nahi hoga).
    } catch (e) {
      showToast("Error replacing photo: $e");
      print("Retake Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    //return Scaffold(

    return PopScope(
      canPop: false, // False ka matlab hai ki back button direct pop nahi karega
      onPopInvoked: (bool didPop) async {
        // Agar system ne naturally pop kar diya hai toh kuch mat karo
        if (didPop) {
          return;
        }
        // Warna humara discard dialog dikhao
        await _promptDiscard();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF2C2C2C),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E1E1E),
          elevation: 0,

          /// Left Icon (Home)
          leading: Tooltip(
            message: "Home",
            child: IconButton(
              icon: const Icon(Icons.home, color: Colors.white, size: 28),
              onPressed: () {
                //showToast("Home tapped");
                _promptDiscard();
              },
            ),
          ),

          /// Middle: Clickable Auto-generated Name
          title: Tooltip(
            message: "Rename document",
            child: GestureDetector(
              onTap: () {
                showToast("Rename document tapped");
              },
              child: Text(
                documentName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                  decorationStyle: TextDecorationStyle.dotted,
                  decorationColor: Colors.white54,
                ),
              ),
            ),
          ),
          centerTitle: true,

          /// Right Icon
          actions: [
            Tooltip(
              message: "Document Options",
              child: IconButton(
                icon: const Icon(Icons.edit_document, color: Colors.white, size: 24),
                onPressed: () {
                  showToast("Options tapped");
                },
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),

        body: Column(
          children: [
            /// 🚨 FIX 1: MAIN PREVIEW AUR THUMBNAILS KO EK CLIP-RECT STACK ME RAKHA
            /// Taaki Filter Menu peechhe se nikle aur uske clicks properly detect hon!
            Expanded(
              child: ClipRect(
                child: Stack(
                  children: [
                    // --- LAYER 1: Preview & Thumbnails ---
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
                                },
                                itemCount: widget.imageFiles.length,
                                itemBuilder: (context, index) {
                                  if (isCroppingMode && index == currentPage) {
                                    return _buildInPlaceCropView();
                                  }
                                  return GestureDetector(
                                    behavior: HitTestBehavior.translucent,

                                    onTap: () {
                                      if (_showFilterMenu) setState(() => _showFilterMenu = false);
                                      if (_showAdjustMenu) {
                                        setState(() => _showAdjustMenu = false); // 🚨 Menu tap se close
                                      }
                                    },

                                    child: InteractiveViewer(
                                      minScale: 1.0,
                                      maxScale: 5.0,
                                      clipBehavior: Clip.none,
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 80),
                                          child: RotatedBox(
                                            quarterTurns: _imageQuarterTurns[index],
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                // Layer 1: Base Image with Filters
                                                ColorFiltered(
                                                  colorFilter: _getAdjustColorFilter(
                                                    _pageBrightness[index],
                                                    _pageContrast[index],
                                                  ),
                                                  child: ColorFiltered(
                                                    colorFilter:
                                                        _getColorFilter(_pageFilters[index]) ??
                                                        const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                                                    child: Image.file(
                                                      widget.imageFiles[index]['cropped'] as File,
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ),
                                                ),

                                                // Layer 2 & 3: Vector Markups (Drawings, Texts, Shapes)
                                                if (_pageMarkups[index] != null &&
                                                    _pageMarkups[index] is MarkupExportData) ...[
                                                  // --- DRAWING STROKES ---
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

                                                  // --- TEXTS & SHAPES ---
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
                                                            // TEXTS LOOP
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
                                                                                  ..strokeWidth = scaledFontSize * 0.25
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
                                                  // Agar selection mode band kiya, toh saare checkboxes clear kar do
                                                  if (!isSelectionMode) {
                                                    selectedPagesList.fillRange(0, selectedPagesList.length, false);
                                                  }
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
                                                    // Text(
                                                    //   "Page ${currentPage + 1} of ${widget.imageFiles.length}",
                                                    //   style: const TextStyle(
                                                    //     color: Colors.white,
                                                    //     fontSize: 14,
                                                    //     fontWeight: FontWeight.w500,
                                                    //   ),
                                                    // ),
                                                    Text(
                                                      isSelectionMode
                                                          ? "${selectedPagesList.where((e) => e == true).length} selected"
                                                          : "Page ${currentPage + 1} of ${widget.imageFiles.length}",
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
                                          onTap: currentPage < widget.imageFiles.length - 1 ? _nextPage : null,
                                          child: Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: currentPage < widget.imageFiles.length - 1
                                                  ? Colors.black87
                                                  : Colors.black38,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              color: currentPage < widget.imageFiles.length - 1
                                                  ? Colors.white
                                                  : Colors.white30,
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

                        // --- THUMBNAILS LIST ---
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          height: isThumbnailVisible ? 90.0 : 0.0,
                          child: ClipRect(
                            child: Container(
                              height: 90,
                              color: const Color(0xFF1E1E1E),
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: widget.imageFiles.length,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                itemBuilder: (context, index) {
                                  bool isSelected = currentPage == index;
                                  bool isChecked = selectedPagesList[index];
                                  return GestureDetector(
                                    onTap: () {
                                      _pageController.animateToPage(
                                        index,
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      );
                                    },

                                    // onTap: () {
                                    //   if (isSelectionMode) {
                                    //     // 🚨 Agar selection mode ON hai, toh tick/untick karo
                                    //     setState(() {
                                    //       selectedPagesList[index] = !selectedPagesList[index];
                                    //     });
                                    //
                                    //     _pageController.animateToPage(
                                    //       index,
                                    //       duration: const Duration(milliseconds: 300),
                                    //       curve: Curves.easeInOut,
                                    //     );
                                    //   } else {
                                    //     // Normal mode me page swipe karo
                                    //     _pageController.animateToPage(
                                    //       index,
                                    //       duration: const Duration(milliseconds: 300),
                                    //       curve: Curves.easeInOut,
                                    //     );
                                    //   }
                                    // },

                                    child: Container(
                                      width: 60,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        image: DecorationImage(
                                          image: FileImage(widget.imageFiles[index]['cropped']!),
                                          fit: BoxFit.cover,
                                        ),
                                        border: Border.all(
                                          color: isSelected ? Colors.blue : Colors.transparent,
                                          width: 3,
                                        ),
                                        // border: Border.all(
                                        //   // Selection mode me main blue border hide rahega taaki sirf checkbox dikhe
                                        //   color: isSelected && !isSelectionMode ? Colors.blue : Colors.transparent,
                                        //   width: 3,
                                        // ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Stack(
                                        children: [

                                          // 🚨 FIX 2: Top-Left Corner Checkbox (Sirf tab dikhega jab Selection Mode ON ho)
                                          if (isSelectionMode)
                                            Positioned(
                                              top: 0,
                                              left: 0,
                                      child: GestureDetector(
                                        onTap: () {
                                          // Sirf yahan click karne se tick/untick hoga
                                          setState(() {
                                            selectedPagesList[index] = !selectedPagesList[index];
                                          });
                                        },
                                              child: Container(
                                                padding: const EdgeInsets.all(2),
                                                decoration: BoxDecoration(
                                                  color: isChecked ? Colors.blueAccent : Colors.black45,
                                                  borderRadius: BorderRadius.circular(2),
                                                  border: Border.all(color: Colors.white, width: 1.5),
                                                ),
                                                child: Icon(
                                                  Icons.check_rounded,
                                                  size: 16,
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
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // --- LAYER 2: FILTER MENU ---
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      bottom: _showFilterMenu ? 0 : -200,
                      left: 0,
                      right: 0,
                      child: _buildFilterMenuWidget(),
                    ),

                    // --- 🚨 LAYER 3: ADJUST MENU ---
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      bottom: _showAdjustMenu ? 0 : -200,
                      left: 0,
                      right: 0,
                      child: _buildAdjustMenuWidget(), // Naya adjust menu call kiya
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
                    // Jab crop chalega, toh yeh (0, 1.0) matlab 100% niche jayega
                    // Jab crop band hoga, toh (0, 0) matlab wapas original position par aayega
                    AnimatedSlide(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      //offset: isCroppingMode ? const Offset(0, 1.0) : Offset.zero,
                      offset: (isCroppingMode || isSelectionMode) ? const Offset(0, 1.0) : Offset.zero,
                      child: _buildNormalTools(),
                    ),

                    // CROP OPTIONS:
                    // Jab crop chalega, toh yeh (0, 0) matlab upar original position par aayega
                    // Jab crop band hoga, toh (0, 1.0) matlab wapas niche chhip jayega
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

                  ],
                ),
              ),
            ),

            /// NAYA BOTTOM BAR: Keep Scanning & Save PDF
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.black, // Ekdum dark background
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Keep Scanning Text Button
                    TextButton(
                      onPressed: () {
                        _saveEditsToMemory(); // 🚨 YAHAN SAVE HOGA
                        showToast("Keep scanning");
                        Navigator.pop(context); // Wapas camera par le jayega
                      },
                      child: const Text(
                        "Keep scanning",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),

                    // Save PDF Button
                    ElevatedButton(
                      onPressed: _handleSaveClick,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        // Adobe scan jaisa blue
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Row(
                        children: [
                          Text("Save PDF", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(width: 4),
                          // Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                        ],
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

  // // --- 🚨 NAYA BLOCK: FILTER MENU WIDGET UI ---
  // Widget _buildFilterMenuWidget() {
  //   String currentFilter = _pageFilters[currentPage];
  //
  //   // 🚨 FIX: GestureDetector lagaya taaki touches/swipes background me leak na ho
  //   return GestureDetector(
  //     onTap: () {}, // Clicks ko yahan block karega
  //     onHorizontalDragUpdate: (_) {}, // Horizontal swipe (PageView scroll) ko block karega
  //     onVerticalDragUpdate: (_) {}, // Vertical scroll ko block karega
  //     child: Container(
  //       height: 180,
  //       decoration: const BoxDecoration(
  //         color: Color(0xFF1E1E1E),
  //         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  //       ),
  //       padding: const EdgeInsets.only(top: 16, bottom: 8),
  //       child: Column(
  //         children: [
  //           // Thumbnails Options
  //           SizedBox(
  //             height: 100,
  //             child: ListView.builder(
  //               scrollDirection: Axis.horizontal,
  //               padding: const EdgeInsets.symmetric(horizontal: 16),
  //               itemCount: _filterOptions.length,
  //               itemBuilder: (context, index) {
  //                 String filterName = _filterOptions[index];
  //                 bool isSelected = currentFilter == filterName;
  //
  //                 return GestureDetector(
  //                   onTap: () {
  //                     setState(() {
  //                       if (_applyToAllPages) {
  //                         for (int i = 0; i < _pageFilters.length; i++) {
  //                           _pageFilters[i] = filterName;
  //                         }
  //                       } else {
  //                         _pageFilters[currentPage] = filterName;
  //                       }
  //                     });
  //                   },
  //                   child: Padding(
  //                     padding: const EdgeInsets.only(right: 16),
  //                     child: Column(
  //                       children: [
  //                         Container(
  //                           width: 65,
  //                           height: 65,
  //                           decoration: BoxDecoration(
  //                             border: Border.all(
  //                               color: isSelected ? Colors.blueAccent : Colors.transparent,
  //                               width: 2.5,
  //                             ),
  //                             borderRadius: BorderRadius.circular(8),
  //                           ),
  //                           child: ClipRRect(
  //                             borderRadius: BorderRadius.circular(5),
  //                             child: ColorFiltered(
  //                               colorFilter:
  //                                   _getColorFilter(filterName) ??
  //                                   const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
  //                               //child: Image.file(widget.imageFiles[currentPage]['cropped']!, fit: BoxFit.cover),
  //                               child: Image.file(widget.imageFiles[currentPage]['cropped'] as File, fit: BoxFit.cover),
  //                             ),
  //                           ),
  //                         ),
  //                         const SizedBox(height: 8),
  //                         Text(
  //                           filterName,
  //                           style: TextStyle(
  //                             color: isSelected ? Colors.blueAccent : Colors.white70,
  //                             fontSize: 11,
  //                             fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
  //                           ),
  //                         ),
  //                       ],
  //                     ),
  //                   ),
  //                 );
  //               },
  //             ),
  //           ),
  //           const Spacer(),
  //           // Bottom Toggle
  //           Padding(
  //             padding: const EdgeInsets.symmetric(horizontal: 16),
  //             child: Row(
  //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //               children: [
  //                 Row(
  //                   children: [
  //                     // 🚨 FIX: Image jaisa design aur size dene ke liye Transform.scale lagaya
  //                     Transform.scale(
  //                       scale: 0.85,
  //                       child: Switch(
  //                         value: _applyToAllPages,
  //                         onChanged: (val) {
  //                           setState(() {
  //                             _applyToAllPages = val;
  //                             if (val) {
  //                               String activeFilter = _pageFilters[currentPage];
  //                               for (int i = 0; i < _pageFilters.length; i++) {
  //                                 _pageFilters[i] = activeFilter;
  //                               }
  //                             }
  //                           });
  //                         },
  //                         // ON hone par colors
  //                         activeColor: Colors.white,
  //                         // Gola (Thumb) white rahega
  //                         activeTrackColor: Colors.blueAccent,
  //                         // Line blue hogi
  //
  //                         // OFF hone par colors (Exactly tumhari image jaisa)
  //                         inactiveThumbColor: const Color(0xFFC0C0C0),
  //                         // Light grey gola
  //                         inactiveTrackColor: const Color(0xFF505050),
  //                         // Dark grey line
  //
  //                         // Material 3 ka default black border hatane ke liye
  //                         trackOutlineColor: MaterialStateProperty.all(Colors.transparent),
  //                       ),
  //                     ),
  //                     const SizedBox(width: 8),
  //                     const Text("Apply to all pages", style: TextStyle(color: Colors.white, fontSize: 14)),
  //                   ],
  //                 ),
  //                 Tooltip(
  //                   message: "Filter Settings",
  //                   child: IconButton(
  //                     icon: const Icon(Icons.settings, color: Colors.white70, size: 24),
  //                     onPressed: () => showToast("Settings coming soon!"),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

// // --- 🚨 NAYA BLOCK: FILTER MENU WIDGET UI ---
//   Widget _buildFilterMenuWidget() {
//     String currentFilter = _pageFilters[currentPage];
//
//     return GestureDetector(
//       onTap: () {},
//       onHorizontalDragUpdate: (_) {},
//       onVerticalDragUpdate: (_) {},
//       // 🚨 FIX 1: Container ki jagah AnimatedContainer use kiya taaki height smoothly choti ho
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 300),
//         curve: Curves.easeInOut,
//         // 🚨 FIX 2: Selection mode me height sirf 124 hogi, warna 180
//         height: isSelectionMode ? 124.0 : 180.0,
//         decoration: const BoxDecoration(
//           color: Color(0xFF1E1E1E),
//           borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//         ),
//         padding: const EdgeInsets.only(top: 16, bottom: 8),
//         child: Column(
//           children: [
//             // Thumbnails Options
//             SizedBox(
//               height: 100,
//               child: ListView.builder(
//                 scrollDirection: Axis.horizontal,
//                 padding: const EdgeInsets.symmetric(horizontal: 16),
//                 itemCount: _filterOptions.length,
//                 itemBuilder: (context, index) {
//                   String filterName = _filterOptions[index];
//                   bool isSelected = currentFilter == filterName;
//
//                   return GestureDetector(
//                     onTap: () {
//                       setState(() {
//                         if (isSelectionMode) {
//                           for (int i = 0; i < _pageFilters.length; i++) {
//                             if (selectedPagesList[i] == true) {
//                               _pageFilters[i] = filterName;
//                             }
//                           }
//                         } else {
//                           if (_applyToAllPages) {
//                             for (int i = 0; i < _pageFilters.length; i++) {
//                               _pageFilters[i] = filterName;
//                             }
//                           } else {
//                             _pageFilters[currentPage] = filterName;
//                           }
//                         }
//                       });
//                     },
//                     child: Padding(
//                       padding: const EdgeInsets.only(right: 16),
//                       child: Column(
//                         children: [
//                           Container(
//                             width: 65,
//                             height: 65,
//                             decoration: BoxDecoration(
//                               border: Border.all(
//                                 color: isSelected ? Colors.blueAccent : Colors.transparent,
//                                 width: 2.5,
//                               ),
//                               borderRadius: BorderRadius.circular(8),
//                             ),
//                             child: ClipRRect(
//                               borderRadius: BorderRadius.circular(5),
//                               child: ColorFiltered(
//                                 colorFilter:
//                                 _getColorFilter(filterName) ??
//                                     const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
//                                 child: Image.file(widget.imageFiles[currentPage]['cropped'] as File, fit: BoxFit.cover),
//                               ),
//                             ),
//                           ),
//                           const SizedBox(height: 8),
//                           Text(
//                             filterName,
//                             style: TextStyle(
//                               color: isSelected ? Colors.blueAccent : Colors.white70,
//                               fontSize: 11,
//                               fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//
//             // 🚨 FIX 3: Agar selection mode ON hai, toh Spacer aur bottom toggle poori tarah hide ho jayenge
//             if (!isSelectionMode) ...[
//               const Spacer(),
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 16),
//                 child: Row(
//                   children: [
//                     Transform.scale(
//                       scale: 0.85,
//                       child: Switch(
//                         value: _applyToAllPages,
//                         onChanged: (val) {
//                           setState(() {
//                             _applyToAllPages = val;
//                             if (val) {
//                               String activeFilter = _pageFilters[currentPage];
//                               for (int i = 0; i < _pageFilters.length; i++) {
//                                 _pageFilters[i] = activeFilter;
//                               }
//                             }
//                           });
//                         },
//                         activeColor: Colors.white,
//                         activeTrackColor: Colors.blueAccent,
//                         inactiveThumbColor: const Color(0xFFC0C0C0),
//                         inactiveTrackColor: const Color(0xFF505050),
//                         trackOutlineColor: MaterialStateProperty.all(Colors.transparent),
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     const Text("Apply to all pages", style: TextStyle(color: Colors.white, fontSize: 14)),
//                   ],
//                 ),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }

  // --- 🚨 NAYA BLOCK: FILTER MENU WIDGET UI ---
  Widget _buildFilterMenuWidget() {
    String currentFilter = _pageFilters[currentPage];

    return GestureDetector(
      onTap: () {},
      onHorizontalDragUpdate: (_) {},
      onVerticalDragUpdate: (_) {},

      // 🚨 FIX 1: AnimatedContainer ki jagah normal Container lagaya aur height hata di
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.only(top: 16, bottom: 8),

        // 🚨 FIX 2: Column ko 'min' size diya taaki ye content ke hisaab se shrink/grow ho
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
                                child: Image.file(widget.imageFiles[currentPage]['cropped'] as File, fit: BoxFit.cover),
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

            // 🚨 FIX 3: Spacer hata kar yahan AnimatedSize lagaya.
            // Ye bina crash kare smooth height transition dega!
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: isSelectionMode
                  ? const SizedBox(width: double.infinity) // Jab selection ON, toh ye height 0 kar lega
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 🚨 NAYA BLOCK: ADJUST MENU WIDGET UI ---
  // Widget _buildAdjustMenuWidget() {
  //   bool isBrightness = _activeAdjustTab == "Brightness";
  //   double currentValue = isBrightness ? _pageBrightness[currentPage] : _pageContrast[currentPage];
  //
  //   return GestureDetector(
  //     behavior: HitTestBehavior.opaque,
  //     // Background tap roko
  //     onTap: () {},
  //     onHorizontalDragUpdate: (_) {},
  //     onVerticalDragUpdate: (_) {},
  //     child: Container(
  //       height: 180,
  //       decoration: const BoxDecoration(
  //         color: Color(0xFF1E1E1E),
  //         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  //       ),
  //       padding: const EdgeInsets.only(top: 16, bottom: 8),
  //       child: Column(
  //         children: [
  //           // --- TOP TABS (Brightness | Contrast) ---
  //           Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //             children: [
  //               GestureDetector(
  //                 onTap: () => setState(() => _activeAdjustTab = "Brightness"),
  //                 child: Row(
  //                   children: [
  //                     Icon(
  //                       Icons.light_mode_outlined,
  //                       color: isBrightness ? Colors.blueAccent : Colors.white70,
  //                       size: 22,
  //                     ),
  //                     const SizedBox(width: 8),
  //                     Text(
  //                       "Brightness",
  //                       style: TextStyle(color: isBrightness ? Colors.blueAccent : Colors.white70, fontSize: 15),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //               GestureDetector(
  //                 onTap: () => setState(() => _activeAdjustTab = "Contrast"),
  //                 child: Row(
  //                   children: [
  //                     Icon(
  //                       Icons.contrast_outlined,
  //                       color: !isBrightness ? Colors.blueAccent : Colors.white70,
  //                       size: 22,
  //                     ),
  //                     const SizedBox(width: 8),
  //                     Text(
  //                       "Contrast",
  //                       style: TextStyle(color: !isBrightness ? Colors.blueAccent : Colors.white70, fontSize: 15),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             ],
  //           ),
  //           const SizedBox(height: 16),
  //
  //           // --- VALUE TEXT ROW ---
  //           Padding(
  //             padding: const EdgeInsets.symmetric(horizontal: 24),
  //             child: Row(
  //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //               children: [
  //                 Text(_activeAdjustTab, style: const TextStyle(color: Colors.white, fontSize: 14)),
  //                 Text("${currentValue.toInt()}", style: const TextStyle(color: Colors.white, fontSize: 14)),
  //               ],
  //             ),
  //           ),
  //
  //           // --- MAIN SLIDER ---
  //           SliderTheme(
  //             data: SliderThemeData(
  //               trackHeight: 2.5,
  //               activeTrackColor: Colors.grey.shade500,
  //               // Screenshot jaisa grey track
  //               inactiveTrackColor: Colors.grey.shade800,
  //               thumbColor: Colors.grey.shade400,
  //               // Light grey thumb
  //               overlayShape: SliderComponentShape.noOverlay,
  //             ),
  //             child: Slider(
  //               value: currentValue,
  //               min: -100,
  //               max: 100,
  //               onChanged: (val) {
  //                 setState(() {
  //                   if (isBrightness) {
  //                     if (_applyToAllPages) {
  //                       for (int i = 0; i < _pageBrightness.length; i++) _pageBrightness[i] = val;
  //                     } else {
  //                       _pageBrightness[currentPage] = val;
  //                     }
  //                   } else {
  //                     if (_applyToAllPages) {
  //                       for (int i = 0; i < _pageContrast.length; i++) _pageContrast[i] = val;
  //                     } else {
  //                       _pageContrast[currentPage] = val;
  //                     }
  //                   }
  //                 });
  //               },
  //             ),
  //           ),
  //           const Spacer(),
  //
  //           // --- BOTTOM TOGGLE & RESET ---
  //           Padding(
  //             padding: const EdgeInsets.symmetric(horizontal: 16),
  //             child: Row(
  //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //               children: [
  //                 Row(
  //                   children: [
  //                     Transform.scale(
  //                       scale: 0.85,
  //                       child: Switch(
  //                         value: _applyToAllPages,
  //                         onChanged: (val) {
  //                           setState(() {
  //                             _applyToAllPages = val;
  //                             if (val) {
  //                               // Sync current values to all pages
  //                               double b = _pageBrightness[currentPage];
  //                               double c = _pageContrast[currentPage];
  //                               for (int i = 0; i < _pageBrightness.length; i++) {
  //                                 _pageBrightness[i] = b;
  //                                 _pageContrast[i] = c;
  //                               }
  //                             }
  //                           });
  //                         },
  //                         activeColor: Colors.white,
  //                         activeTrackColor: Colors.blueAccent,
  //                         inactiveThumbColor: const Color(0xFFC0C0C0),
  //                         inactiveTrackColor: const Color(0xFF505050),
  //                         trackOutlineColor: MaterialStateProperty.all(Colors.transparent),
  //                       ),
  //                     ),
  //                     const SizedBox(width: 8),
  //                     const Text("Apply to all pages", style: TextStyle(color: Colors.white, fontSize: 14)),
  //                   ],
  //                 ),
  //
  //                 // 🚨 RESET BUTTON
  //                 TextButton(
  //                   onPressed: () {
  //                     setState(() {
  //                       if (_applyToAllPages) {
  //                         for (int i = 0; i < _pageBrightness.length; i++) {
  //                           _pageBrightness[i] = 0.0;
  //                           _pageContrast[i] = 0.0;
  //                         }
  //                       } else {
  //                         _pageBrightness[currentPage] = 0.0;
  //                         _pageContrast[currentPage] = 0.0;
  //                       }
  //                     });
  //                     showToast("$_activeAdjustTab reset to 0");
  //                   },
  //                   child: const Text(
  //                     "Reset",
  //                     style: TextStyle(color: Colors.blueAccent, fontSize: 15, fontWeight: FontWeight.w500),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // --- 🚨 NAYA BLOCK: ADJUST MENU WIDGET UI ---
  Widget _buildAdjustMenuWidget() {
    bool isBrightness = _activeAdjustTab == "Brightness";
    double currentValue = isBrightness ? _pageBrightness[currentPage] : _pageContrast[currentPage];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      onHorizontalDragUpdate: (_) {},
      onVerticalDragUpdate: (_) {},
      child: Container(
        // 🚨 FIX 1: Fixed height (180) hata di taaki overflow na ho
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        // 🚨 FIX 2: Column ka size 'min' rakha taaki content ke hisaab se adjust ho jaye
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- TOP TABS (Brightness | Contrast) ---
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

            // --- VALUE TEXT ROW ---
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

            // --- MAIN SLIDER ---
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
                    // 🚨 FIX 3: Bulk Adjust Logic for Selection Mode
                    if (isSelectionMode) {
                      for (int i = 0; i < widget.imageFiles.length; i++) {
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

            // 🚨 FIX 4: Spacer hata kar SizedBox lagaya taaki ui collapse na ho
            const SizedBox(height: 12),

            // --- BOTTOM TOGGLE & RESET ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                // 🚨 FIX 5: Agar selection ON hai, toh Reset button ko end me right-align kardo
                mainAxisAlignment: isSelectionMode ? MainAxisAlignment.end : MainAxisAlignment.spaceBetween,
                children: [
                  // 🚨 FIX 6: Selection Mode me Apply to all switch hide ho jayega
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

                  // 🚨 RESET BUTTON (Bulk logic updated)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (isSelectionMode) {
                          // Agar selection mode ON hai, toh sirf selected ko reset karo
                          for (int i = 0; i < widget.imageFiles.length; i++) {
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

  // --- TOOLBAR WIDGETS ---

  Widget _buildNormalTools() {
    // FIX: SizedBox lagana zaroori hai taaki sliding ke time height collapse na ho
    return SizedBox(
      key: const ValueKey("NormalTools"),
      // Animation Engine ko pata chalega ki ye alag widget hai
      height: 75,
      width: double.infinity,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        children: [
          _buildToolItem(
            label: "Retake",
            icon: Symbols.reset_image_rounded,
            tooltipMessage: "Retake current photo",
            onTap: _retakeImage, // 👈 YEH NAYI LINE ADD KARNI HAI
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
            // Tumhara upar banaya function
            isRotate: true, // 🚨 Isko true pass karna zaroori hai tabhi ghumega
          ),

          _buildToolItem(
            label: "Filter",
            icon: Symbols.masked_transitions_rounded,
            tooltipMessage: "Apply color filters",
            isSelected: _showFilterMenu,
            onTap: () {
              setState(() {
                _showFilterMenu = !_showFilterMenu;
                if (_showFilterMenu) _showAdjustMenu = false; // Filter khule toh Adjust band ho jaye
              });
            },
          ),

          _buildToolItem(
            label: "Adjust",
            icon: Icons.tune_rounded,
            tooltipMessage: "Adjust brightness and contrast",
            isSelected: _showAdjustMenu,
            // Open hone par icon blue higlight hoga
            onTap: () {
              setState(() {
                _showAdjustMenu = !_showAdjustMenu;
                if (_showAdjustMenu) _showFilterMenu = false; // Adjust khule toh Filter band ho jaye
              });
            },
          ),

          _buildToolItem(
            label: "Markup",
            icon: Icons.border_color_rounded,
            tooltipMessage: "Draw or add text on image",
            onTap: _openMarkupScreen, // 🚨 Naya function yahan cleanly call ho gaya
          ),

          // _buildToolItem(label: "Cleanup", icon: Icons.auto_fix_high_rounded, tooltipMessage: "Erase unwanted areas"),
          // _buildToolItem(label: "Resize", icon: Icons.aspect_ratio_rounded, tooltipMessage: "Change page layout size"),
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
            onTap: _promptDeletePage, // 🚨 FIX: Yahan function attach kiya
          ),
        ],
      ),
    );
  }

  Widget _buildCropSubTools() {
    // FIX: Same size ka SizedBox taaki switcher me smooth transition ho
    return SizedBox(
      key: const ValueKey("CropSubTools"),
      height: 75,
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildToolItem(
            label: "Cancel", icon: Icons.close_rounded, tooltipMessage: "Cancel Crop", onTap: _cancelCrop,),
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

  // --- 🚨 NAYA BLOCK: SELECTION MODE TOOLS ---
  // Widget _buildSelectedSubTools() {
  //   return SizedBox(
  //     key: const ValueKey("SelectedSubTools"),
  //     height: 75,
  //     width: double.infinity,
  //     child: Row(
  //       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //       children: [
  //         _buildToolItem(
  //           label: "Rotate",
  //           icon: Icons.rotate_right_rounded,
  //           tooltipMessage: "Rotate selected pages",
  //           // Abhi ke liye Toast lagaya hai, bulk rotate logic next step me add karenge
  //           onTap: () => showToast("Bulk rotate coming soon"),
  //         ),
  //         _buildToolItem(
  //           label: "Filter",
  //           icon: Symbols.masked_transitions_rounded,
  //           tooltipMessage: "Apply filter to selected pages",
  //           isSelected: _showFilterMenu,
  //           onTap: () {
  //             setState(() {
  //               _showFilterMenu = !_showFilterMenu;
  //               if (_showFilterMenu) _showAdjustMenu = false; // Adjust menu band kardo
  //             });
  //           },
  //         ),
  //         _buildToolItem(
  //           label: "Adjust",
  //           icon: Icons.tune_rounded,
  //           tooltipMessage: "Adjust selected pages",
  //           isSelected: _showAdjustMenu,
  //           onTap: () {
  //             setState(() {
  //               _showAdjustMenu = !_showAdjustMenu;
  //               if (_showAdjustMenu) _showFilterMenu = false; // Filter menu band kardo
  //             });
  //           },
  //         ),
  //         _buildToolItem(
  //           label: "Delete",
  //           icon: Icons.delete_outline_rounded,
  //           tooltipMessage: "Delete selected pages",
  //           // Abhi ke liye Toast lagaya hai, bulk delete logic next step me add karenge
  //           onTap: () => showToast("Bulk delete coming soon"),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // --- 🚨 NAYA BLOCK: SELECTION MODE TOOLS ---
  Widget _buildSelectedSubTools() {
    // Check karo ki list me ek bhi page selected hai ya nahi
    bool hasSelection = selectedPagesList.contains(true);

    // Check karo ki kya saare ke saare pages selected hain?
    bool allSelected = selectedPagesList.isNotEmpty && selectedPagesList.every((e) => e == true);

    return SizedBox(
      key: const ValueKey("SelectedSubTools"),
      height: 75,
      width: double.infinity,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        children: [

          // 🚨 FIX 1: 1st Option (Select All / Deselect All) - Ye hamesha ACTIVE rahega
          _buildToolItem(
            label: allSelected ? "Deselect" : "Select All", // Text dynamic
            icon: allSelected ? Icons.deselect_rounded : Icons.select_all_rounded, // Icon dynamic
            tooltipMessage: allSelected ? "Deselect all pages" : "Select all pages",
            onTap: () {
              setState(() {

                _showFilterMenu = false;
                _showAdjustMenu = false;

                if (allSelected) {
                  // Agar sab selected hain, toh sabko false (untick) kar do
                  selectedPagesList.fillRange(0, selectedPagesList.length, false);
                } else {
                  // Agar sab selected nahi hain, toh sabko true (tick) kar do
                  selectedPagesList.fillRange(0, selectedPagesList.length, true);
                }
              });
            },
          ),

          // 🚨 FIX 2: Baaki ke tools ko ek Row me wrap karke sirf un par Fade/Disable lagaya
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: hasSelection ? 1.0 : 0.4,
            child: IgnorePointer(
              ignoring: !hasSelection,
              child: Row(
                mainAxisSize: MainAxisSize.min, // Taaki UI kharab na ho
                children: [
                  _buildToolItem(
                    label: "Rotate",
                    icon: Icons.rotate_right_rounded,
                    tooltipMessage: "Rotate selected pages",
                    onTap: () => showToast("Bulk rotate coming soon"),
                  ),
                  _buildToolItem(
                    label: "Filter",
                    icon: Symbols.masked_transitions_rounded,
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

  // 🚨 FIXED: Delete Page Logic with Memory Sync
  Future<void> _promptDeletePage() async {
    // 🚨 FIX: Delete karne se pehle sabhi pages ki current settings ko map me save karo
    _saveEditsToMemory();

    // 1. Custom Dialog Dikhayenge
    bool confirmDelete = await showCustomConfirmDialog(
      context,
      title: "Delete page",
      message: "Are you sure you want to delete this page from your scan?",
      positiveBtnText: "Delete",
      negativeBtnText: "Cancel",
      positiveBtnColor: Colors.redAccent,
    );

    // 2. Agar user ne 'Delete' confirm kiya
    if (confirmDelete) {
      if (widget.imageFiles.length == 1) {
        // CASE A: Agar sirf 1 hi page tha aur usko delete kar diya
        showToast("Document deleted");
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      } else {
        // CASE B: Agar 1 se zyada pages hain
        setState(() {
          // Main list se wo specific page hata do
          widget.imageFiles.removeAt(currentPage);
          //selectedPagesList.removeAt(currentPage);
          // Agar user aakhri page pe tha, toh current page ko 1 step peeche kar do
          if (currentPage >= widget.imageFiles.length) {
            currentPage = widget.imageFiles.length - 1;
          }
        });

        // Nayi list ke hisaab se memory wapas load karo (Ab baaki pages ka data safe rahega)
        _loadEditsFromMemory();

        // PageView UI ko naye index par set karne ke liye
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(currentPage);
          }
        });

        showToast("Page deleted");
      }
    }
  }

  // 🚨 NAYA: Bulk Delete Logic
  Future<void> _promptBulkDelete() async {
    // 1. Check karo kitne pages selected hain
    int selectedCount = selectedPagesList.where((e) => e == true).length;
    if (selectedCount == 0) return;

    // 🚨 FIX: Delete button dabate hi pehle khule hue menus band kar do
    setState(() {
      _showFilterMenu = false;
      _showAdjustMenu = false;
    });

    // 2. Pehle memory save karo
    _saveEditsToMemory();

    // 3. Dynamic text (1 page ke liye alag, multiple ke liye alag)
    String titleText = selectedCount == 1 ? "Delete page" : "Delete $selectedCount pages";
    String messageText = selectedCount == 1
        ? "Are you sure you want to delete this page from your scan?"
        : "Are you sure you want to delete these $selectedCount pages from your scan?";

    // 4. Custom Dialog
    bool confirmDelete = await showCustomConfirmDialog(
      context,
      title: titleText,
      message: messageText,
      positiveBtnText: "Delete",
      negativeBtnText: "Cancel",
      positiveBtnColor: Colors.redAccent,
    );

    if (confirmDelete) {
      if (selectedCount == widget.imageFiles.length) {
        // CASE A: Agar saare hi select karke delete kar diye
        showToast("Document deleted");
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
          );
        }
      } else {
        // CASE B: Agar kuch pages bache hain
        setState(() {
          // 🚨 MAGIC: Hamesha pichhe se (reverse) delete karna chahiye taaki index shift na ho
          for (int i = widget.imageFiles.length - 1; i >= 0; i--) {
            if (selectedPagesList[i] == true) {
              widget.imageFiles.removeAt(i);
            }
          }

          // Agar current page out of bounds ho gaya, toh usko adjust karo
          if (currentPage >= widget.imageFiles.length) {
            currentPage = widget.imageFiles.length - 1;
          }

          // Delete hone ke baad selection mode band kar do aur list clear kar do
          isSelectionMode = false;
          selectedPagesList = List.filled(widget.imageFiles.length, false);
        });

        // Nayi list ke hisaab se memory wapas load karo
        _loadEditsFromMemory();

        // PageView UI ko naye index par bhejo
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(currentPage);
          }
        });

        showToast("$selectedCount page(s) deleted");
      }
    }
  }

  // --- MARKUP LOGIC (VECTOR APPROACH) ---
  Future<void> _openMarkupScreen() async {
    File currentImage = widget.imageFiles[currentPage]['cropped']!;

    // 1. Saari current settings variables me save karo
    int turns = _imageQuarterTurns[currentPage];
    String activeFilter = _pageFilters[currentPage];
    double activeBright = _pageBrightness[currentPage];
    double activeContrast = _pageContrast[currentPage];
    dynamic existingMarkups = _pageMarkups[currentPage];

    // 2. INSTANT NAVIGATION: Bina kisi delay ke direct push karo aur parameters bhej do
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MarkupScreen(
          imageFile: currentImage,
          rotationTurns: turns,
          // 🚨 Naye parameters jo Markup me UI sync karenge
          filterName: activeFilter,
          brightness: activeBright,
          contrast: activeContrast,
          existingMarkups: existingMarkups,
        ),
      ),
    );

    // 3. RESULT: Jab user Save karke wapas aayega, toh Image nahi, Vectors aayenge!
    if (result != null) {
      setState(() {
        // Naye drawing/text vectors ko save kar lo. (Photo me koi pixel change nahi hua hai)
        _pageMarkups[currentPage] = result;
      });
      showToast("Markup applied to Page ${currentPage + 1}");
    }
  }


  Widget _buildToolItem({
    required String label,
    required IconData icon,
    required String tooltipMessage,
    VoidCallback? onTap,
    bool isSelected = false,
    bool isRotate = false, // 🚨 NAYA PARAMETER: Animation on karne ke liye
  }) {
    return Tooltip(
      message: tooltipMessage,
      child: GestureDetector(
        onTap: onTap ?? () => showToast("$label clicked"),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Container(
            // Agar selected hai toh Adobe Scan jaisa solid blue color aayega
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blueAccent : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🚨 FIX: Yahan par Icon ko check kiya ki usko ghumana hai ya nahi
                isRotate
                    ? AnimatedRotation(
                        turns: _iconRotationTurns, // Animation variable
                        duration: const Duration(milliseconds: 300), // Smooth time
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

  // --- REAL-TIME MAIN PREVIEW CROP UI & MATH ---

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
    // 1. STATE CHANGE: Crop options "Hide Down" aur Normal tools "Hide Up" honge
    setState(() {
      isCroppingMode = false;
      isThumbnailVisible = true;
    });

    // 2. WAIT: Animation poora hone do 300ms
    await Future.delayed(const Duration(milliseconds: 300));

    // 3. HEAVY WORK: Crop save logic chalega
    try {
      File originalFile = widget.imageFiles[currentPage]['original']!;
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
          widget.imageFiles[currentPage]['cropped'] = newFile;
          // Crop position save hogi agle baar ke liye
          _savedCropPositions[currentPage] = {
            'top': cropTopRatio,
            'bottom': cropBottomRatio,
            'left': cropLeftRatio,
            'right': cropRightRatio,
          };
        });
      }
    } catch (e) {
      showToast("Error saving crop");
    }
  }

  // Cancel logic bhi perfect slide down dega
  void _cancelCrop() {
    setState(() {
      isCroppingMode = false;
      isThumbnailVisible = true;
    });
  }

  Widget _buildInPlaceCropView() {
    File originalFile = widget.imageFiles[currentPage]['original']!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        // AspectRatio lagane se box screen par exactly main photo ke upar perfectly lock ho jayega
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
                        // Border
                        Container(
                          decoration: BoxDecoration(border: Border.all(color: Colors.blueAccent, width: 2.5)),
                        ),

                        // Edge lines
                        _buildEdgeHandle(Alignment.topCenter, (d) => _updateCropBounds(d.delta.dy, 0, 0, 0)),
                        _buildEdgeHandle(Alignment.bottomCenter, (d) => _updateCropBounds(0, -d.delta.dy, 0, 0)),
                        _buildEdgeHandle(Alignment.centerLeft, (d) => _updateCropBounds(0, 0, d.delta.dx, 0)),
                        _buildEdgeHandle(Alignment.centerRight, (d) => _updateCropBounds(0, 0, 0, -d.delta.dx)),

                        // Corner Circles
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
        onPanUpdate: onPan,
        child: Transform.translate(
          offset: Offset(alignment.x * 12, alignment.y * 12),
          child: Container(
            width: isVertical ? 30 : 50,
            height: isVertical ? 50 : 30,
            color: Colors.transparent,
            alignment: Alignment.center,
            child: Container(
              width: isVertical ? 6 : 24,
              height: isVertical ? 24 : 6,
              decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(3)),
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
        onPanUpdate: onPan,
        child: Transform.translate(
          offset: Offset(alignment.x * 15, alignment.y * 15),
          child: Container(
            width: 40,
            height: 40,
            color: Colors.transparent,
            alignment: Alignment.center,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blueAccent, width: 2.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// end main class
