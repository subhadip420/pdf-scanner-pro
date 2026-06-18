import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

import 'home_screen.dart';

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
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Future<void> _toggleCropMode() async {
  //   if (isCroppingMode) {
  //     await _saveNewCrop();
  //   } else {
  //     showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.blueAccent)));
  //
  //     File origFile = widget.imageFiles[currentPage]['original']!;
  //     File cropFile = widget.imageFiles[currentPage]['cropped']!;
  //
  //     final origBytes = await origFile.readAsBytes();
  //     final cropBytes = await cropFile.readAsBytes();
  //
  //     final decodedOrig = img.decodeImage(origBytes);
  //     final decodedCrop = img.decodeImage(cropBytes);
  //
  //     if (mounted) Navigator.pop(context); // Loading hatao
  //
  //     if (decodedOrig != null && decodedCrop != null) {
  //       setState(() {
  //         isCroppingMode = true;
  //         isThumbnailVisible = false; // Thumbnail hide
  //         _origWidth = decodedOrig.width.toDouble();
  //         _origHeight = decodedOrig.height.toDouble();
  //
  //         // FIX 3: Check karo ki kya is page ki position pehle se save hai?
  //         if (_savedCropPositions[currentPage] != null) {
  //           // Agar save hai toh purani exact position load karo!
  //           cropTopRatio = _savedCropPositions[currentPage]!['top']!;
  //           cropBottomRatio = _savedCropPositions[currentPage]!['bottom']!;
  //           cropLeftRatio = _savedCropPositions[currentPage]!['left']!;
  //           cropRightRatio = _savedCropPositions[currentPage]!['right']!;
  //         } else {
  //           // Agar pehli baar hai toh midle wala normal calculation karo
  //           double percentW = decodedCrop.width / decodedOrig.width;
  //           double percentH = decodedCrop.height / decodedOrig.height;
  //           cropTopRatio = (1.0 - percentH) / 2;
  //           cropBottomRatio = (1.0 - percentH) / 2;
  //           cropLeftRatio = (1.0 - percentW) / 2;
  //           cropRightRatio = (1.0 - percentW) / 2;
  //         }
  //       });
  //     }
  //   }
  // }

  // --- CROP TOOL FUNCTIONS ---

  // --- CROP TOOL FUNCTIONS ---

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

  // 3. Main PDF generate karne ka function
  // 3. Main PDF generate karne ka function (Public Folder Logic)
  Future<void> _generateAndSavePdf() async {
    showToast("Generating PDF...");

    final pdf = pw.Document();

    for (var map in widget.imageFiles) {
      // 1. Map me se cropped file ko nikala
      final File file = map['cropped']!;

      // 2. Us file ke bytes ko read kiya
      final image = pw.MemoryImage(file.readAsBytesSync());

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
      // 1. Storage Permission Manage Karo (Android 11+ ke liye ekdum sahi tarika)
      if (await Permission.manageExternalStorage.isDenied) {
        // Yeh user ke samne system setting page open karega permission dene ke liye
        await Permission.manageExternalStorage.request();
      }

      // Agar user ne setting se permission nahi di, toh check karke block karo
      if (!await Permission.manageExternalStorage.isGranted) {
        showToast("Storage permission is required to save PDF");
        return; // Aage ka code nahi chalega jab tak permission na mile
      }

      // 2. Public Documents folder ka path set karein
      final Directory publicDir = Directory(
        '/storage/emulated/0/Documents/PDF Scanner Pro',
      );

      // 3. Agar folder nahi hai, toh naya banao
      if (!await publicDir.exists()) {
        await publicDir.create(recursive: true);
      }

      // 4. File save karein
      // 4. Unique File Name Generator
      String baseFilePath = "${publicDir.path}/$documentName";
      String finalFilePath = "$baseFilePath.pdf";
      File file = File(finalFilePath);

      int counter = 1;
      // Jab tak is naam ki file milti rahegi, counter badhta jayega (1), (2)...
      while (await file.exists()) {
        finalFilePath = "$baseFilePath ($counter).pdf";
        file = File(finalFilePath);
        counter++;
      }

      // Ab safely save karein naye unique naam ke sath
      await file.writeAsBytes(await pdf.save());

      showToast("Saved in Documents/PDF Scanner Pro");

      // 5. UPDATE: File open karne ka code hata diya hai
      // Aur seedhe Home Screen par redirect kar diya (Sare purane pages pop ho jayenge)
      // 5. UPDATE: Seedhe Home Screen par redirect aur baaki sab close
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (Route<dynamic> route) =>
              false, // Yeh condition purane saare pages (Camera, Edit) ko stack se hata degi
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
          /// MAIN PREVIEW AREA
          Expanded(
            child: Stack(
              children: [
                // Swipeable & Zoomable Images
                PageView.builder(
                  controller: _pageController,
                  // Jab crop chal raha ho toh page swipe disable kar denge
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
                    // Agar crop mode ON hai aur yehi current page hai, toh Crop UI dikhao
                    if (isCroppingMode && index == currentPage) {
                      return _buildInPlaceCropView();
                    }

                    // Warna normal image preview dikhao
                    // return Center(
                    //   child: Padding(
                    //     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                    //     child: Image.file(
                    //       widget.imageFiles[index]['cropped']!,
                    //       fit: BoxFit.contain,
                    //     ),
                    //   ),
                    // );

                    // Warna normal image preview dikhao
                    return Center(
                      child: Padding(
                        // FIX: symmetric hata kar only lagaya aur bottom padding ko 90 kar diya
                        // Isse photo niche se upar chali jayegi aur controls se nahi takrayegi
                        padding: const EdgeInsets.only(
                          left: 24,
                          right: 24,
                          top: 20,
                          bottom: 80,
                        ),
                        child: Image.file(
                          widget.imageFiles[index]['cropped']!,
                          fit: BoxFit.contain,
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
                        /// Left Arrow
                        Tooltip(
                          message: "Previous Page",
                          child: GestureDetector(
                            // Agar first page hai (0), to null (disable), warna _previousPage call hoga
                            onTap: currentPage > 0 ? _previousPage : null,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                // First page par background halka (black38) ho jayega
                                color: currentPage > 0
                                    ? Colors.black87
                                    : Colors.black38,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                // First page par icon ka color fade (white30) ho jayega
                                color: currentPage > 0
                                    ? Colors.white
                                    : Colors.white30,
                                size: 18,
                              ),
                            ),
                          ),
                        ),

                        /// Middle Controls (Add Icon + Page Count)
                        Row(
                          children: [
                            Tooltip(
                              message: "Add New Page",
                              child: GestureDetector(
                                onTap: () => showToast("Add new page"),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: Colors.black87,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.post_add_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        "Page ${currentPage + 1} of ${widget.imageFiles.length}",
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

                        /// Right Arrow
                        Tooltip(
                          message: "Next Page",
                          child: GestureDetector(
                            // Agar last page hai, to null (disable), warna _nextPage call hoga
                            onTap: currentPage < widget.imageFiles.length - 1
                                ? _nextPage
                                : null,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                // Last page par background halka ho jayega
                                color:
                                    currentPage < widget.imageFiles.length - 1
                                    ? Colors.black87
                                    : Colors.black38,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.arrow_forward_ios_rounded,
                                // Last page par icon fade ho jayega
                                color:
                                    currentPage < widget.imageFiles.length - 1
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

          /// BOTTOM HORIZONTAL THUMBNAIL LIST
          // if (isThumbnailVisible)
          //   Container(
          //     height: 90,
          //     color: const Color(0xFF1E1E1E),
          //     child: ListView.builder(
          //       scrollDirection: Axis.horizontal,
          //       itemCount: widget.imageFiles.length,
          //       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          //       itemBuilder: (context, index) {
          //         bool isSelected = currentPage == index;
          //         return GestureDetector(
          //           onTap: () {
          //             _pageController.animateToPage(
          //               index,
          //               duration: const Duration(milliseconds: 300),
          //               curve: Curves.easeInOut,
          //             );
          //           },
          //           child: Container(
          //             width: 60,
          //             margin: const EdgeInsets.only(right: 12),
          //             decoration: BoxDecoration(
          //               image: DecorationImage(
          //                 //image: FileImage(widget.imageFiles[index]),
          //                 image: FileImage(widget.imageFiles[index]['cropped']!),
          //                 fit: BoxFit.cover,
          //               ),
          //               border: Border.all(
          //                 color: isSelected ? Colors.blue : Colors.transparent,
          //                 width: 3,
          //               ),
          //               borderRadius: BorderRadius.circular(4),
          //             ),
          //             child: Stack(
          //               children: [
          //
          //                 // Number with small dark background box
          //                 Align(
          //                   alignment: Alignment.bottomCenter, // Number ko thoda right side me rakha hai jo zyada accha lagta hai
          //                   child: Container(
          //                     margin: const EdgeInsets.all(4),
          //                     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          //                     decoration: BoxDecoration(
          //                       color: Colors.black.withOpacity(0.6), // Low opacity black background
          //                       borderRadius: BorderRadius.circular(10), // Small rounded shape
          //                     ),
          //                     child: Text(
          //                       '${index + 1}',
          //                       style: const TextStyle(
          //                         color: Colors.white,
          //                         fontSize: 11,
          //                         fontWeight: FontWeight.bold,
          //                       ),
          //                     ),
          //                   ),
          //                 ),
          //               ],
          //             ),
          //           ),
          //         );
          //       },
          //     ),
          //   ),

          /// BOTTOM HORIZONTAL THUMBNAIL LIST (Smooth Hide/Show Animation)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            // Same duration as Toolbar animation
            curve: Curves.easeInOut,
            height: isThumbnailVisible ? 90.0 : 0.0,
            // Achanak gayab hone ke bajaye shrink hoga
            child: ClipRect(
              // ClipRect zaroori hai taaki shrink hote waqt image bahar na nikle
              child: Container(
                height: 90,
                color: const Color(0xFF1E1E1E),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.imageFiles.length,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  itemBuilder: (context, index) {
                    bool isSelected = currentPage == index;
                    return GestureDetector(
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
                          image: DecorationImage(
                            image: FileImage(
                              widget.imageFiles[index]['cropped']!,
                            ),
                            fit: BoxFit.cover,
                          ),
                          border: Border.all(
                            color: isSelected
                                ? Colors.blue
                                : Colors.transparent,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Stack(
                          children: [
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                margin: const EdgeInsets.all(4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
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

          /// NEW ACTION TOOLS BAR (Horizontal Scrollable)
          // Container(
          //   height: 75,
          //   color: const Color(0xFF151515), // Dark background for tools section
          //   child: ListView(
          //     scrollDirection: Axis.horizontal,
          //     padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
          //     children: [
          //       _buildToolItem(label: "Retake",
          //           icon: Icons.refresh_rounded,
          //           tooltipMessage: "Retake current photo"),
          //       // _buildToolItem(label: "Crop",
          //       //     icon: Icons.crop_rounded,
          //       //     tooltipMessage: "Crop & adjust borders"),
          //
          //       _buildToolItem(
          //         label: "Crop",
          //         icon: Icons.crop_rounded,
          //         tooltipMessage: "Crop & adjust borders",
          //         isSelected: isCroppingMode, // Mode ON hone par blue hoga
          //         onTap: _toggleCropMode,     // Naya function call hoga
          //       ),
          //       _buildToolItem(label: "Rotate",
          //           icon: Icons.rotate_right_rounded,
          //           tooltipMessage: "Rotate 90 degrees"),
          //       _buildToolItem(label: "Filter",
          //           icon: Icons.photo_filter_rounded,
          //           tooltipMessage: "Apply color filters"),
          //       _buildToolItem(label: "Adjust",
          //           icon: Icons.tune_rounded,
          //           tooltipMessage: "Adjust brightness and contrast"),
          //       _buildToolItem(label: "Markup",
          //           icon: Icons.border_color_rounded,
          //           tooltipMessage: "Draw or add text on image"),
          //       _buildToolItem(label: "Cleanup",
          //           icon: Icons.auto_fix_high_rounded,
          //           tooltipMessage: "Erase unwanted areas"),
          //       _buildToolItem(label: "Resize",
          //           icon: Icons.aspect_ratio_rounded,
          //           tooltipMessage: "Change page layout size"),
          //       _buildToolItem(label: "Reorder",
          //           icon: Icons.swap_horizontal_circle_outlined,
          //           tooltipMessage: "Rearrange page sequence"),
          //       _buildToolItem(label: "Delete",
          //           icon: Icons.delete_outline_rounded,
          //           tooltipMessage: "Delete current page"),
          //     ],
          //   ),
          // ),

          /// NEW ACTION TOOLS BAR (With Slide Animation)
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
            icon: Icons.refresh_rounded,
            tooltipMessage: "Retake current photo",
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
          ),
          _buildToolItem(
            label: "Filter",
            icon: Icons.photo_filter_rounded,
            tooltipMessage: "Apply color filters",
          ),
          _buildToolItem(
            label: "Adjust",
            icon: Icons.tune_rounded,
            tooltipMessage: "Adjust brightness and contrast",
          ),
          _buildToolItem(
            label: "Markup",
            icon: Icons.border_color_rounded,
            tooltipMessage: "Draw or add text on image",
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
                Icon(icon, color: Colors.white, size: 22),
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
