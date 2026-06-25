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
import 'package:pdf_scanner_pro/screens/scanner_screen.dart';
import 'package:permission_handler/permission_handler.dart';

import 'home_screen.dart';
import 'markup_screen.dart';

class DocumentEditorScreen extends StatefulWidget {
  //final List<File> imageFiles; // Real images coming from ScannerScreen
  final List<Map<String, File>> imageFiles;

  //const DocumentEditorScreen({super.key, required this.imageFiles});
  const DocumentEditorScreen({Key? key, required this.imageFiles})
    : super(key: key);

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
  final List<String> _filterOptions = [
    "Original color",
    "Auto-color",
    "Light text",
    "Grayscale",
    "Whiteboard"
  ];

  bool _showAdjustMenu = false; // 🚨 Naya Adjust menu track karne ke liye
  late List<double> _pageBrightness; // 🚨 Har page ki brightness
  late List<double> _pageContrast;   // 🚨 Har page ka contrast
  String _activeAdjustTab = "Brightness"; // "Brightness" ya "Contrast" track karega

  @override
  void initState() {
    super.initState();
    documentName = _generateDefaultName();
    // Open the latest captured photo first
    currentPage = widget.imageFiles.length - 1;
    _pageController = PageController(initialPage: currentPage);

    _savedCropPositions = List.generate(
      widget.imageFiles.length,
      (index) => null,
    );
    _autoCropPositions = List.generate(
      widget.imageFiles.length,
      (index) => null,
    ); // Auto memory init

    _loadRewardedAd(); // Screen open hote hi ad background me load hona shuru ho jayega

    _imageQuarterTurns = List.filled(widget.imageFiles.length, 0);
    _pageFilters = List.filled(widget.imageFiles.length, "Original color"); // 🚨 Default filter set kiya
    _pageBrightness = List.filled(widget.imageFiles.length, 0.0); // Default 0
    _pageContrast = List.filled(widget.imageFiles.length, 0.0);   // Default 0
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // --- FILTER LOGIC ---
  ColorFilter? _getColorFilter(String filterName) {
    switch (filterName) {
      case "Grayscale":
        return const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ]);
      case "Whiteboard":
        return const ColorFilter.matrix([
          1.5, 0, 0, 0, 20,
          0, 1.5, 0, 0, 20,
          0, 0, 1.5, 0, 20,
          0, 0, 0, 1, 0,
        ]);
      case "Light text":
        return const ColorFilter.matrix([
          1.2, 0, 0, 0, 10,
          0, 1.2, 0, 0, 10,
          0, 0, 1.2, 0, 10,
          0, 0, 0, 1, 0,
        ]);
      case "Auto-color":
        return const ColorFilter.matrix([
          1.2, -0.1, -0.1, 0, 10,
          -0.1, 1.2, -0.1, 0, 10,
          -0.1, -0.1, 1.2, 0, 10,
          0, 0, 0, 1, 0,
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

    return ColorFilter.matrix([
      c, 0, 0, 0, t + b,
      0, c, 0, 0, t + b,
      0, 0, c, 0, t + b,
      0, 0, 0, 1, 0,
    ]);
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

  img.Image _processImageSync(img.Image decodedImage, int turns, String activeFilter, double activeBright, double activeContrast) {
    // 1. Apply Rotation
    if (turns != 0) {
      decodedImage = img.copyRotate(decodedImage, angle: turns * 90);
    }

    // 2. Apply Filters (EXACT Matrix matching UI)
    if (activeFilter != "Original color") {
      List<double>? filterMatrix;
      switch (activeFilter) {
        case "Grayscale": filterMatrix = [0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, 0, 0, 0, 1, 0]; break;
        case "Whiteboard": filterMatrix = [1.5, 0, 0, 0, 20, 0, 1.5, 0, 0, 20, 0, 0, 1.5, 0, 20, 0, 0, 0, 1, 0]; break;
        case "Light text": filterMatrix = [1.2, 0, 0, 0, 10, 0, 1.2, 0, 0, 10, 0, 0, 1.2, 0, 10, 0, 0, 0, 1, 0]; break;
        case "Auto-color": filterMatrix = [1.2, -0.1, -0.1, 0, 10, -0.1, 1.2, -0.1, 0, 10, -0.1, -0.1, 1.2, 0, 10, 0, 0, 0, 1, 0]; break;
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
      List<double> adjustMatrix = [
        c, 0, 0, 0, offset,
        0, c, 0, 0, offset,
        0, 0, c, 0, offset,
        0, 0, 0, 1, 0,
      ];
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

  // Generate default file name based on current date
  String _generateDefaultName() {
    final now = DateTime.now();
    final months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
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
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.blueAccent),
      ),
    );

    // Max 2 seconds wait karna (100ms x 20 bar check karega)
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (_rewardedAd != null)
        break; // Agar wait karte time ad load ho gaya, toh loop break
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

  // 3. Main PDF generate karne ka function (With Real Image Rotation)
  Future<void> _generateAndSavePdf() async {
    showToast("Generating PDF...");

    final pdf = pw.Document();

    // 🚨 FIX: Yahan 'for in' loop ki jagah index (i) wala loop use kiya
    // taaki hum check kar sakein ki kis photo ko kitna rotate karna hai
    // for (int i = 0; i < widget.imageFiles.length; i++) {
    //   var map = widget.imageFiles[i];
    //   final File file = map['cropped']!;
    //
    //   // 1. Pehle image ki file ko bytes mein read karo
    //   var imageBytes = await file.readAsBytes();
    //
    //   // 2. 🚨 REAL ROTATION LOGIC: Check karo ki kya is page ka rotate icon click hua tha?
    //   int turns = _imageQuarterTurns[i];
    //   if (turns != 0) {
    //     // Agar photo rotate hui hai, toh real mein usko ghumao
    //     img.Image? decodedImage = img.decodeImage(imageBytes);
    //     if (decodedImage != null) {
    //       // 1 turn = 90 degrees, 2 turns = 180 degrees
    //       img.Image rotatedImage = img.copyRotate(
    //         decodedImage,
    //         angle: turns * 90,
    //       );
    //       // Ghumi hui photo ko wapas bytes mein convert karo
    //       imageBytes = img.encodeJpg(rotatedImage, quality: 90);
    //     }
    //   }
    //
    //   // 3. Ab in final (ghumi hui) bytes ko PDF me dalo
    //   final image = pw.MemoryImage(imageBytes);
    //
    //   pdf.addPage(
    //     pw.Page(
    //       margin: pw.EdgeInsets.zero,
    //       pageFormat: PdfPageFormat.a4,
    //       build: (context) {
    //         return pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain));
    //       },
    //     ),
    //   );
    // }

    for (int i = 0; i < widget.imageFiles.length; i++) {
      var map = widget.imageFiles[i];
      final File file = map['cropped']!;

      var imageBytes = await file.readAsBytes();

      int turns = _imageQuarterTurns[i];
      String activeFilter = _pageFilters[i];
      double activeBright = _pageBrightness[i];
      double activeContrast = _pageContrast[i];

      // 🚨 NAYA: Ab PDF me bhi Filter aur Adjust properly save honge!
      if (turns != 0 || activeFilter != "Original color" || activeBright != 0.0 || activeContrast != 0.0) {
        img.Image? decodedImage = img.decodeImage(imageBytes);
        if (decodedImage != null) {
          decodedImage = _processImageSync(decodedImage, turns, activeFilter, activeBright, activeContrast);
          imageBytes = img.encodeJpg(decodedImage, quality: 90);
        }
      }

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
      final Directory publicDir = Directory(
        '/storage/emulated/0/Documents/PDF Scanner Pro',
      );

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
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      showToast("First page");
    }
  }

  // Go to next page
  void _nextPage() {
    if (currentPage < widget.imageFiles.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
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
      _imageQuarterTurns[currentPage] =
          (_imageQuarterTurns[currentPage] + 1) % 4;
    });
  }

  Future<void> _retakeImage() async {
    try {
      // 1. ScannerScreen ko 'Retake' mode me open karo
      // Yeh result variable mein us File ka wait karega jo wahan se pop hogi
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ScannerScreen(isRetakeMode: true),
        ),
      );

      // 2. Agar user ne photo click ki (ya gallery se li) aur 'result' me naya File wapas aaya
      if (result != null && result is File) {
        setState(() {
          // Current page par purani photo ki jagah nayi photo set kardo
          widget.imageFiles[currentPage] = {
            'original': result,
            'cropped': result,
          };

          // 🚨 ZAROORI: Is naye page ke liye purani settings (crop/rotate) RESET kardo
          _imageQuarterTurns[currentPage] = 0;
          _savedCropPositions[currentPage] = null;
          _autoCropPositions[currentPage] = null;
          _pageFilters[currentPage] = "Original color"; // 🚨 Retake par filter wapas original hoga
          _pageBrightness[currentPage] = 0.0; // 🚨 Retake par brightness reset
          _pageContrast[currentPage] = 0.0;   // 🚨 Retake par contrast reset
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
    return Scaffold(
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
              showToast("Home tapped");
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
              icon: const Icon(
                Icons.edit_document,
                color: Colors.white,
                size: 24,
              ),
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

                                // return GestureDetector(
                                //   behavior: HitTestBehavior.translucent,
                                //   onTap: () {
                                //     if (_showFilterMenu) setState(() => _showFilterMenu = false);
                                //   },
                                //   child: Center(
                                //     child: Padding(
                                //       padding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 80),
                                //       child: RotatedBox(
                                //         quarterTurns: _imageQuarterTurns[index],
                                //         child: ColorFiltered(
                                //           colorFilter: _getColorFilter(_pageFilters[index]) ?? const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                                //           child: Image.file(
                                //             widget.imageFiles[index]['cropped']!,
                                //             fit: BoxFit.contain,
                                //           ),
                                //         ),
                                //       ),
                                //     ),
                                //   ),
                                // );

                                return GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  // onTap: () {
                                  //   if (_showFilterMenu) setState(() => _showFilterMenu = false);
                                  // },
                                  // // 🚨 FIX: InteractiveViewer ko Padding ke bahar nikala taaki poore screen me phel sake
                                  // child: InteractiveViewer(
                                  //   minScale: 1.0,
                                  //   maxScale: 5.0,
                                  //   clipBehavior: Clip.none, // Screen ke edge par photo cut nahi hogi
                                  //   child: Center(
                                  //     child: Padding(
                                  //       padding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 80),
                                  //       child: RotatedBox(
                                  //         quarterTurns: _imageQuarterTurns[index],
                                  //         child: ColorFiltered(
                                  //           colorFilter: _getColorFilter(_pageFilters[index]) ?? const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                                  //           child: Image.file(
                                  //             widget.imageFiles[index]['cropped']!,
                                  //             fit: BoxFit.contain,
                                  //           ),
                                  //         ),
                                  //       ),
                                  //     ),
                                  //   ),
                                  // ),
                                  onTap: () {
                                    if (_showFilterMenu) setState(() => _showFilterMenu = false);
                                    if (_showAdjustMenu) setState(() => _showAdjustMenu = false); // 🚨 Menu tap se close
                                  },
                                  child: InteractiveViewer(
                                    minScale: 1.0, maxScale: 5.0, clipBehavior: Clip.none,
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 80),
                                        child: RotatedBox(
                                          quarterTurns: _imageQuarterTurns[index],
                                          // 🚨 FIX: Filter aur Adjust dono ka ColorFilter ek saath chain kiya
                                          child: ColorFiltered(
                                            colorFilter: _getAdjustColorFilter(_pageBrightness[index], _pageContrast[index]),
                                            child: ColorFiltered(
                                              colorFilter: _getColorFilter(_pageFilters[index]) ?? const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                                              child: Image.file(
                                                widget.imageFiles[index]['cropped']!,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
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
                                bottom: 20, left: 16, right: 16,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Tooltip(
                                      message: "Previous Page",
                                      child: GestureDetector(
                                        onTap: currentPage > 0 ? _previousPage : null,
                                        child: Container(
                                          width: 40, height: 40,
                                          decoration: BoxDecoration(
                                            color: currentPage > 0 ? Colors.black87 : Colors.black38,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(Icons.arrow_back_ios_new_rounded, color: currentPage > 0 ? Colors.white : Colors.white30, size: 18),
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Tooltip(
                                          message: "Add New Page",
                                          child: GestureDetector(
                                            onTap: () => showToast("Add new page"),
                                            child: Container(
                                              width: 40, height: 40,
                                              decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                                              child: const Icon(Icons.post_add_rounded, color: Colors.white, size: 20),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Tooltip(
                                          message: "Jump to page",
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                isThumbnailVisible = !isThumbnailVisible;
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
                                              child: Row(
                                                children: [
                                                  Text(
                                                    "Page ${currentPage + 1} of ${widget.imageFiles.length}",
                                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Icon(
                                                    isThumbnailVisible ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                                                    color: Colors.white, size: 18,
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
                                          width: 40, height: 40,
                                          decoration: BoxDecoration(
                                            color: currentPage < widget.imageFiles.length - 1 ? Colors.black87 : Colors.black38,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(Icons.arrow_forward_ios_rounded, color: currentPage < widget.imageFiles.length - 1 ? Colors.white : Colors.white30, size: 18),
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
                            height: 90, color: const Color(0xFF1E1E1E),
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: widget.imageFiles.length,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              itemBuilder: (context, index) {
                                bool isSelected = currentPage == index;
                                return GestureDetector(
                                  onTap: () {
                                    _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                                  },
                                  child: Container(
                                    width: 60, margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      image: DecorationImage(
                                        image: FileImage(widget.imageFiles[index]['cropped']!), fit: BoxFit.cover,
                                      ),
                                      border: Border.all(color: isSelected ? Colors.blue : Colors.transparent, width: 3),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Stack(
                                      children: [
                                        Align(
                                          alignment: Alignment.bottomCenter,
                                          child: Container(
                                            margin: const EdgeInsets.all(4), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(10)),
                                            child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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
                  // Ab ye menu completely parent box ke andar hai.
                  // -200 ki wajah se ye Action bar ke theek peeche chhip jayega!
              //     AnimatedPositioned(
              //       duration: const Duration(milliseconds: 300),
              //       curve: Curves.easeInOut,
              //       bottom: _showFilterMenu ? 0 : -200,
              //       left: 0,
              //       right: 0,
              //       child: _buildFilterMenuWidget(),
              //     ),
              //   ],
              // ),

                  // --- LAYER 2: FILTER MENU ---
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300), curve: Curves.easeInOut,
                    bottom: _showFilterMenu ? 0 : -200, left: 0, right: 0,
                    child: _buildFilterMenuWidget(),
                  ),

                  // --- 🚨 LAYER 3: ADJUST MENU ---
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300), curve: Curves.easeInOut,
                    bottom: _showAdjustMenu ? 0 : -200, left: 0, right: 0,
                    child: _buildAdjustMenuWidget(), // Naya adjust menu call kiya
                  ),
                ],
              ),
            ),
          ),

          /// NEW ACTION TOOLS BAR (Guaranteed Slide Up/Down Animation)

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
                    offset: isCroppingMode ? const Offset(0, 1.0) : Offset.zero,
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
                      showToast("Keep scanning");
                      Navigator.pop(context); // Wapas camera par le jayega
                    },
                    child: const Text(
                      "Keep scanning",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  // Save PDF Button
                  ElevatedButton(
                    onPressed: _handleSaveClick,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      // Adobe scan jaisa blue
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Text(
                          "Save PDF",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
    );
  }

  // --- 🚨 NAYA BLOCK: FILTER MENU WIDGET UI ---
  Widget _buildFilterMenuWidget() {
    String currentFilter = _pageFilters[currentPage];

    // 🚨 FIX: GestureDetector lagaya taaki touches/swipes background me leak na ho
    return GestureDetector(
      onTap: () {}, // Clicks ko yahan block karega
      onHorizontalDragUpdate: (_) {}, // Horizontal swipe (PageView scroll) ko block karega
      onVerticalDragUpdate: (_) {}, // Vertical scroll ko block karega
      child: Container(
        height: 180,
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Column(
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
                        if (_applyToAllPages) {
                          for (int i = 0; i < _pageFilters.length; i++) {
                            _pageFilters[i] = filterName;
                          }
                        } else {
                          _pageFilters[currentPage] = filterName;
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Column(
                        children: [
                          Container(
                            width: 65, height: 65,
                            decoration: BoxDecoration(
                              border: Border.all(color: isSelected ? Colors.blueAccent : Colors.transparent, width: 2.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: ColorFiltered(
                                colorFilter: _getColorFilter(filterName) ?? const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                                child: Image.file(
                                  widget.imageFiles[currentPage]['cropped']!,
                                  fit: BoxFit.cover,
                                ),
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
            const Spacer(),
            // Bottom Toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // SizedBox(
                      //   height: 30,
                      //   child: Switch(
                      //     value: _applyToAllPages,
                      //     onChanged: (val) {
                      //       setState(() {
                      //         _applyToAllPages = val;
                      //         if (val) {
                      //           String activeFilter = _pageFilters[currentPage];
                      //           for (int i = 0; i < _pageFilters.length; i++) {
                      //             _pageFilters[i] = activeFilter;
                      //           }
                      //         }
                      //       });
                      //     },
                      //     activeColor: Colors.blueAccent,
                      //   ),
                      // ),
                      // 🚨 FIX: Image jaisa design aur size dene ke liye Transform.scale lagaya
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
                          // ON hone par colors
                          activeColor: Colors.white, // Gola (Thumb) white rahega
                          activeTrackColor: Colors.blueAccent, // Line blue hogi

                          // OFF hone par colors (Exactly tumhari image jaisa)
                          inactiveThumbColor: const Color(0xFFC0C0C0), // Light grey gola
                          inactiveTrackColor: const Color(0xFF505050), // Dark grey line

                          // Material 3 ka default black border hatane ke liye
                          trackOutlineColor: MaterialStateProperty.all(Colors.transparent),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text("Apply to all pages", style: TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                  Tooltip(
                    message: "Filter Settings",
                    child: IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white70, size: 24),
                      onPressed: () => showToast("Settings coming soon!"),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- 🚨 NAYA BLOCK: ADJUST MENU WIDGET UI ---
  Widget _buildAdjustMenuWidget() {
    bool isBrightness = _activeAdjustTab == "Brightness";
    double currentValue = isBrightness ? _pageBrightness[currentPage] : _pageContrast[currentPage];

    return GestureDetector(
      behavior: HitTestBehavior.opaque, // Background tap roko
      onTap: () {}, onHorizontalDragUpdate: (_) {}, onVerticalDragUpdate: (_) {},
      child: Container(
        height: 180,
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Column(
          children: [
            // --- TOP TABS (Brightness | Contrast) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _activeAdjustTab = "Brightness"),
                  child: Row(
                    children: [
                      Icon(Icons.light_mode_outlined, color: isBrightness ? Colors.blueAccent : Colors.white70, size: 22),
                      const SizedBox(width: 8),
                      Text("Brightness", style: TextStyle(color: isBrightness ? Colors.blueAccent : Colors.white70, fontSize: 15)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _activeAdjustTab = "Contrast"),
                  child: Row(
                    children: [
                      Icon(Icons.contrast_outlined, color: !isBrightness ? Colors.blueAccent : Colors.white70, size: 22),
                      const SizedBox(width: 8),
                      Text("Contrast", style: TextStyle(color: !isBrightness ? Colors.blueAccent : Colors.white70, fontSize: 15)),
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
                activeTrackColor: Colors.grey.shade500, // Screenshot jaisa grey track
                inactiveTrackColor: Colors.grey.shade800,
                thumbColor: Colors.grey.shade400, // Light grey thumb
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: currentValue,
                min: -100, max: 100,
                onChanged: (val) {
                  setState(() {
                    if (isBrightness) {
                      if (_applyToAllPages) {
                        for (int i=0; i<_pageBrightness.length; i++) _pageBrightness[i] = val;
                      } else {
                        _pageBrightness[currentPage] = val;
                      }
                    } else {
                      if (_applyToAllPages) {
                        for (int i=0; i<_pageContrast.length; i++) _pageContrast[i] = val;
                      } else {
                        _pageContrast[currentPage] = val;
                      }
                    }
                  });
                },
              ),
            ),
            const Spacer(),

            // --- BOTTOM TOGGLE & RESET ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                                // Sync current values to all pages
                                double b = _pageBrightness[currentPage];
                                double c = _pageContrast[currentPage];
                                for (int i=0; i<_pageBrightness.length; i++) {
                                  _pageBrightness[i] = b;
                                  _pageContrast[i] = c;
                                }
                              }
                            });
                          },
                          activeColor: Colors.white, activeTrackColor: Colors.blueAccent,
                          inactiveThumbColor: const Color(0xFFC0C0C0), inactiveTrackColor: const Color(0xFF505050),
                          trackOutlineColor: MaterialStateProperty.all(Colors.transparent),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text("Apply to all pages", style: TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),

                  // 🚨 RESET BUTTON
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_applyToAllPages) {
                          for (int i=0; i<_pageBrightness.length; i++) {
                            _pageBrightness[i] = 0.0;
                            _pageContrast[i] = 0.0;
                          }
                        } else {
                          _pageBrightness[currentPage] = 0.0;
                          _pageContrast[currentPage] = 0.0;
                        }
                      });
                      showToast("$_activeAdjustTab reset to 0");
                    },
                    child: const Text("Reset", style: TextStyle(color: Colors.blueAccent, fontSize: 15, fontWeight: FontWeight.w500)),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- TOOLBAR WIDGETS ---

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

          // // 🚨 FIX 3: Filter Button Click setup
          // _buildToolItem(
          //   label: "Filter",
          //   icon: Symbols.masked_transitions_rounded,
          //   tooltipMessage: "Apply color filters",
          //   isSelected: _showFilterMenu,
          //   onTap: () {
          //     setState(() => _showFilterMenu = !_showFilterMenu);
          //   },
          // ),
          //
          // _buildToolItem(
          //   label: "Adjust",
          //   icon: Icons.tune_rounded,
          //   tooltipMessage: "Adjust brightness and contrast",
          // ),

          _buildToolItem(
            label: "Filter", icon: Symbols.masked_transitions_rounded, tooltipMessage: "Apply color filters",
            isSelected: _showFilterMenu,
            onTap: () {
              setState(() {
                _showFilterMenu = !_showFilterMenu;
                if (_showFilterMenu) _showAdjustMenu = false; // Filter khule toh Adjust band ho jaye
              });
            },
          ),

          _buildToolItem(
            label: "Adjust", icon: Icons.tune_rounded, tooltipMessage: "Adjust brightness and contrast",
            isSelected: _showAdjustMenu, // Open hone par icon blue higlight hoga
            onTap: () {
              setState(() {
                _showAdjustMenu = !_showAdjustMenu;
                if (_showAdjustMenu) _showFilterMenu = false; // Adjust khule toh Filter band ho jaye
              });
            },
          ),

          // _buildToolItem(
          //   label: "Markup",
          //   icon: Icons.border_color_rounded,
          //   tooltipMessage: "Draw or add text on image",
          // ),

          _buildToolItem(
            label: "Markup",
            icon: Icons.border_color_rounded,
            tooltipMessage: "Draw or add text on image",
            onTap: _openMarkupScreen, // 🚨 Naya function yahan cleanly call ho gaya
          ),

          _buildToolItem(
            label: "Cleanup",
            icon: Icons.auto_fix_high_rounded,
            tooltipMessage: "Erase unwanted areas",
          ),
          _buildToolItem(
            label: "Resize",
            icon: Icons.aspect_ratio_rounded,
            tooltipMessage: "Change page layout size",
          ),
          _buildToolItem(
            label: "Reorder",
            icon: Icons.swap_horizontal_circle_outlined,
            tooltipMessage: "Rearrange page sequence",
          ),
          _buildToolItem(
            label: "Delete",
            icon: Icons.delete_outline_rounded,
            tooltipMessage: "Delete current page",
          ),
        ],
      ),
    );
  }

  // --- MARKUP LOGIC ---
  Future<void> _openMarkupScreen() async {
    // Current image ko nayi screen me bhejo
    File originalImage = widget.imageFiles[currentPage]['cropped']!;

    final editedFile = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MarkupScreen(imageFile: originalImage),
      ),
    );

    // Agar user ne 'OK (Tick)' dabaya, toh edited image wapas aayegi
    if (editedFile != null && editedFile is File) {
      setState(() {
        widget.imageFiles[currentPage]['cropped'] = editedFile;

        // Nayi drawing aayi hai, toh purana crop/rotate settings reset kardo
        _imageQuarterTurns[currentPage] = 0;
        _savedCropPositions[currentPage] = null;
        _autoCropPositions[currentPage] = null;
        _pageFilters[currentPage] = "Original color";
        _pageBrightness[currentPage] = 0.0;
        _pageContrast[currentPage] = 0.0;
      });
      showToast("Markup applied to Page ${currentPage + 1}");
    }
  }

  // --- MARKUP LOGIC ---
// // --- MARKUP LOGIC ---
//   Future<void> _openMarkupScreen() async {
//     File currentImage = widget.imageFiles[currentPage]['cropped']!;
//
//     // 1. Saare active changes check karo
//     int turns = _imageQuarterTurns[currentPage];
//     String activeFilter = _pageFilters[currentPage];
//     double activeBright = _pageBrightness[currentPage];
//     double activeContrast = _pageContrast[currentPage];
//
//     // 2. Conditions check karo ki kya file me sach me koi modification hua hai
//     bool hasRotation = turns != 0;
//     bool hasFilter = activeFilter != "Original color";
//     bool hasAdjust = activeBright != 0.0 || activeContrast != 0.0;
//
//     // Agar koi bhi change (Rotate/Filter/Adjust) hua hai, toh pehle file ko "Bake" (save) karo
//     if (hasRotation || hasFilter || hasAdjust) {
//
//       // Loading Indicator dikhao
//       showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (BuildContext context) {
//           return const Center(
//             child: CircularProgressIndicator(color: Colors.blueAccent),
//           );
//         },
//       );
//
//       try {
//         final imageBytes = await currentImage.readAsBytes();
//         img.Image? decodedImage = img.decodeImage(imageBytes);
//
//         if (decodedImage != null) {
//
//           // --- A. APPLY ROTATION ---
//           if (hasRotation) {
//             decodedImage = img.copyRotate(decodedImage, angle: turns * 90);
//           }
//
//           // --- B. APPLY FILTERS & ADJUSTMENTS ---
//           if (hasFilter || hasAdjust) {
//             if (activeFilter == "Grayscale" || activeFilter == "Whiteboard" || activeFilter == "Light text") {
//               decodedImage = img.grayscale(decodedImage);
//             }
//
//             double finalBrightness = 1.0 + (activeBright / 100.0);
//             double finalContrast = 1.0 + (activeContrast / 100.0);
//
//             if (activeFilter == "Whiteboard") {
//               finalBrightness += 0.2;
//               finalContrast += 0.5;
//             } else if (activeFilter == "Light text") {
//               finalBrightness += 0.1;
//               finalContrast += 0.2;
//             } else if (activeFilter == "Auto-color") {
//               finalContrast += 0.15;
//             }
//
//             if (finalBrightness != 1.0 || finalContrast != 1.0) {
//               decodedImage = img.adjustColor(
//                 decodedImage,
//                 brightness: finalBrightness,
//                 contrast: finalContrast,
//               );
//             }
//           }
//
//           // --- C. SAVE NEW PROCESSED FILE ---
//           // 🚨 FIX: Extension ka wait nahi karenge, direct parent folder nikal kar naya naam banayenge
//           final String dirPath = currentImage.parent.path;
//           final String newPath = "$dirPath/baked_${DateTime.now().millisecondsSinceEpoch}.jpg";
//           File newBakedFile = File(newPath);
//
//           await newBakedFile.writeAsBytes(img.encodeJpg(decodedImage, quality: 100));
//
//           // 🚨 FIX: Flutter Cache Clear karo taaki hamesha naya image load ho
//           await FileImage(newBakedFile).evict();
//
//           // --- D. STATE UPDATE AUR SETTINGS RESET ---
//           setState(() {
//             // Original aur cropped dono me daalo taaki Crop tool error na de
//             widget.imageFiles[currentPage]['original'] = newBakedFile;
//             widget.imageFiles[currentPage]['cropped'] = newBakedFile;
//
//             // Saari settings wapas 0 kardo
//             _imageQuarterTurns[currentPage] = 0;
//             _pageFilters[currentPage] = "Original color";
//             _pageBrightness[currentPage] = 0.0;
//             _pageContrast[currentPage] = 0.0;
//             _savedCropPositions[currentPage] = null;
//             _autoCropPositions[currentPage] = null;
//           });
//
//           // Ab Markup Screen me yahi nayi file jayegi
//           currentImage = newBakedFile;
//         }
//       } catch (e) {
//         print("Baking Error: $e");
//         showToast("Error applying edits to image");
//       } finally {
//         if (mounted) Navigator.pop(context);
//       }
//     }
//
//     // Ab tumhari properly Processed (Baked) file MarkupScreen me jayegi
//     if (!mounted) return;
//     final editedFile = await Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => MarkupScreen(imageFile: currentImage),
//       ),
//     );
//
//     // Agar user ne wahan edit kiya aur save kiya, toh UI update kardo
//     if (editedFile != null && editedFile is File) {
//
//       // 🚨 FIX: Markup se aane ke baad bhi purani cache hata do
//       await FileImage(editedFile).evict();
//
//       setState(() {
//         // Yahan bhi Original ko update karo, taaki drawn image par future edit sahi se ho
//         widget.imageFiles[currentPage]['original'] = editedFile;
//         widget.imageFiles[currentPage]['cropped'] = editedFile;
//
//         // Ek baar fir sab reset kardo strictly
//         _imageQuarterTurns[currentPage] = 0;
//         _pageFilters[currentPage] = "Original color";
//         _pageBrightness[currentPage] = 0.0;
//         _pageContrast[currentPage] = 0.0;
//       });
//       showToast("Markup applied to Page ${currentPage + 1}");
//     }
//   }

  // // --- MARKUP LOGIC ---
  // Future<void> _openMarkupScreen() async {
  //   File currentImage = widget.imageFiles[currentPage]['cropped']!;
  //   File fileToMarkup = currentImage;
  //
  //   int turns = _imageQuarterTurns[currentPage];
  //   String activeFilter = _pageFilters[currentPage];
  //   double activeBright = _pageBrightness[currentPage];
  //   double activeContrast = _pageContrast[currentPage];
  //
  //   bool hasRotation = turns != 0;
  //   bool hasFilter = activeFilter != "Original color";
  //   bool hasAdjust = activeBright != 0.0 || activeContrast != 0.0;
  //
  //   if (hasRotation || hasFilter || hasAdjust) {
  //     showDialog(
  //       context: context,
  //       barrierDismissible: false,
  //       builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
  //     );
  //
  //     try {
  //       final imageBytes = await currentImage.readAsBytes();
  //       img.Image? decodedImage = img.decodeImage(imageBytes);
  //
  //       if (decodedImage != null) {
  //         // 🚨 NAYA: Universal Sync logic chalaya! (UI ka exactly same copy hoga)
  //         decodedImage = _processImageSync(decodedImage, turns, activeFilter, activeBright, activeContrast);
  //
  //         final String dirPath = currentImage.parent.path;
  //         final String tempPath = "$dirPath/temp_markup_${DateTime.now().millisecondsSinceEpoch}.jpg";
  //         File tempBakedFile = File(tempPath);
  //         await tempBakedFile.writeAsBytes(img.encodeJpg(decodedImage, quality: 100));
  //
  //         fileToMarkup = tempBakedFile;
  //       }
  //     } catch (e) {
  //       print("Temp Baking Error: $e");
  //       showToast("Error preparing image for markup");
  //       if (mounted) Navigator.pop(context);
  //       return;
  //     }
  //
  //     if (mounted) Navigator.pop(context);
  //   }
  //
  //   if (!mounted) return;
  //   final editedFile = await Navigator.push(
  //     context,
  //     MaterialPageRoute(builder: (context) => MarkupScreen(imageFile: fileToMarkup)),
  //   );
  //
  //   if (editedFile != null && editedFile is File) {
  //     await FileImage(editedFile).evict();
  //
  //     setState(() {
  //       widget.imageFiles[currentPage]['original'] = editedFile;
  //       widget.imageFiles[currentPage]['cropped'] = editedFile;
  //
  //       _imageQuarterTurns[currentPage] = 0;
  //       _pageFilters[currentPage] = "Original color";
  //       _pageBrightness[currentPage] = 0.0;
  //       _pageContrast[currentPage] = 0.0;
  //       _savedCropPositions[currentPage] = null;
  //       _autoCropPositions[currentPage] = null;
  //     });
  //     showToast("Markup applied");
  //   } else {
  //     if (fileToMarkup.path.contains('temp_markup_')) {
  //       if (await fileToMarkup.exists()) {
  //         await fileToMarkup.delete();
  //       }
  //     }
  //   }
  // }

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
            label: "Cancel",
            icon: Icons.close_rounded,
            tooltipMessage: "Cancel Crop",
            onTap: _cancelCrop,
          ),
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
                        duration: const Duration(
                          milliseconds: 300,
                        ), // Smooth time
                        child: Icon(icon, color: Colors.white, size: 22),
                      )
                    : Icon(icon, color: Colors.white, size: 22),

                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
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

  // --- REAL-TIME MAIN PREVIEW CROP UI & MATH ---

  void _updateCropBounds(double dt, double db, double dl, double dr) {
    setState(() {
      double currentTop = cropTopRatio * _cropAreaHeight;
      double currentBottom = cropBottomRatio * _cropAreaHeight;
      double currentLeft = cropLeftRatio * _cropAreaWidth;
      double currentRight = cropRightRatio * _cropAreaWidth;

      currentTop = (currentTop + dt).clamp(
        0.0,
        _cropAreaHeight - currentBottom - 40.0,
      );
      currentBottom = (currentBottom + db).clamp(
        0.0,
        _cropAreaHeight - currentTop - 40.0,
      );
      currentLeft = (currentLeft + dl).clamp(
        0.0,
        _cropAreaWidth - currentRight - 40.0,
      );
      currentRight = (currentRight + dr).clamp(
        0.0,
        _cropAreaWidth - currentLeft - 40.0,
      );

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
        int w = ((1.0 - cropLeftRatio - cropRightRatio) * originalImage.width)
            .toInt();
        int h = ((1.0 - cropBottomRatio - cropTopRatio) * originalImage.height)
            .toInt();

        x = x.clamp(0, originalImage.width);
        y = y.clamp(0, originalImage.height);
        w = w.clamp(10, originalImage.width - x);
        h = h.clamp(10, originalImage.height - y);

        img.Image newlyCropped = img.copyCrop(
          originalImage,
          x: x,
          y: y,
          width: w,
          height: h,
        );

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
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.blueAccent,
                              width: 2.5,
                            ),
                          ),
                        ),

                        // Edge lines
                        _buildEdgeHandle(
                          Alignment.topCenter,
                          (d) => _updateCropBounds(d.delta.dy, 0, 0, 0),
                        ),
                        _buildEdgeHandle(
                          Alignment.bottomCenter,
                          (d) => _updateCropBounds(0, -d.delta.dy, 0, 0),
                        ),
                        _buildEdgeHandle(
                          Alignment.centerLeft,
                          (d) => _updateCropBounds(0, 0, d.delta.dx, 0),
                        ),
                        _buildEdgeHandle(
                          Alignment.centerRight,
                          (d) => _updateCropBounds(0, 0, 0, -d.delta.dx),
                        ),

                        // Corner Circles
                        _buildDragCorner(
                          Alignment.topLeft,
                          (d) =>
                              _updateCropBounds(d.delta.dy, 0, d.delta.dx, 0),
                        ),
                        _buildDragCorner(
                          Alignment.topRight,
                          (d) =>
                              _updateCropBounds(d.delta.dy, 0, 0, -d.delta.dx),
                        ),
                        _buildDragCorner(
                          Alignment.bottomLeft,
                          (d) =>
                              _updateCropBounds(0, -d.delta.dy, d.delta.dx, 0),
                        ),
                        _buildDragCorner(
                          Alignment.bottomRight,
                          (d) =>
                              _updateCropBounds(0, -d.delta.dy, 0, -d.delta.dx),
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

  Widget _buildEdgeHandle(
    Alignment alignment,
    Function(DragUpdateDetails) onPan,
  ) {
    bool isVertical =
        alignment == Alignment.centerLeft || alignment == Alignment.centerRight;
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
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDragCorner(
    Alignment alignment,
    Function(DragUpdateDetails) onPan,
  ) {
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
