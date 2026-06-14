import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
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

  @override
  void initState() {
    super.initState();
    documentName = _generateDefaultName();
    // Open the latest captured photo first
    currentPage = widget.imageFiles.length - 1;
    _pageController = PageController(initialPage: currentPage);

    _loadRewardedAd(); // Screen open hote hi ad background me load hona shuru ho jayega
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Generate default file name based on current date
  String _generateDefaultName() {
    final now = DateTime.now();
    final months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
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

  // 3. Main PDF generate karne ka function
  // 3. Main PDF generate karne ka function (Public Folder Logic)
  Future<void> _generateAndSavePdf() async {
    showToast("Generating PDF...");

    final pdf = pw.Document();

    // for (var file in widget.imageFiles) {
    //   //final image = pw.MemoryImage(file.readAsBytesSync());
    //   // Pehle map me se 'cropped' file nikalo
    //   final File file = item['cropped']!;
    //
    //   // Fir usko read karo
    //   final image = pw.MemoryImage(file.readAsBytesSync());
    //
    //   // pdf.addPage(
    //   //   pw.Page(
    //   //     build: (pw.Context context) {
    //   //       return pw.Center(child: pw.Image(image));
    //   //     },
    //   //   ),
    //   // );
    //   pdf.addPage(
    //     pw.Page(
    //       margin: pw.EdgeInsets.zero,
    //       pageFormat: PdfPageFormat.a4,
    //       build: (context) {
    //         return pw.Center(
    //           child: pw.Image(
    //             image,
    //             fit: pw.BoxFit.contain,
    //           ),
    //         );
    //       },
    //     ),
    //   );
    // }

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
            return pw.Center(
              child: pw.Image(
                image,
                fit: pw.BoxFit.contain,
              ),
            );
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
      final Directory publicDir = Directory('/storage/emulated/0/Documents/PDF Scanner Pro');

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
              (Route<dynamic> route) => false, // Yeh condition purane saare pages (Camera, Edit) ko stack se hata degi
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
          /// MAIN PREVIEW AREA
          Expanded(
            child: Stack(
              children: [

                // Swipeable & Zoomable Images
                // PageView.builder(
                //   controller: _pageController,
                //   onPageChanged: (index) {
                //     setState(() {
                //       currentPage = index;
                //     });
                //   },
                //   itemCount: widget.imageFiles.length,
                //   itemBuilder: (context, index) {
                //     return InteractiveViewer(
                //       minScale: 1.0,
                //       maxScale: 4.0,
                //       // FIX 1: Center use kiya taaki layout extend hone par ratio barkarar rahe
                //       child: Center(
                //         child: Container(
                //           margin: const EdgeInsets.only(left: 30, right: 30, top: 20, bottom: 80),
                //           decoration: BoxDecoration(
                //               color: Colors.black, // Image background ko black rakha hai
                //               border: Border.all(color: Colors.white24, width: 1),
                //               boxShadow: const [
                //                 BoxShadow(
                //                   color: Colors.black26,
                //                   blurRadius: 10,
                //                   offset: Offset(0, 5),
                //                 )
                //               ]
                //           ),
                //           clipBehavior: Clip.hardEdge, // Image ko border ke andar lock rakhne ke liye
                //           child: Image.file(
                //             //widget.imageFiles[index],
                //             widget.imageFiles[index]['cropped']!,
                //             // FIX 2: BoxFit.contain se height aur width dono hamesha same ratio me bade/chote honge
                //             fit: BoxFit.contain,
                //             // FIX 3: width aur height (double.infinity) hata diya, ab ye aspect ratio ke hisab se auto-size lega
                //           ),
                //         ),
                //       ),
                //     );
                //   },
                // ),

                // Swipeable & Zoomable Images
                PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      currentPage = index;
                    });
                  },
                  itemCount: widget.imageFiles.length,
                  itemBuilder: (context, index) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                        child: Image.file(
                          widget.imageFiles[index]['cropped']!,
                          // BoxFit.contain sabse important hai, yeh image ko exact uske apne free-size me dikhayega
                          fit: BoxFit.contain,
                        ),
                      ),
                    );
                  },
                ),

                // Overlay Controls (Arrows and Page Count)
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
                              color: currentPage > 0 ? Colors.black87 : Colors.black38,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                // First page par icon ka color fade (white30) ho jayega
                                color: currentPage > 0 ? Colors.white : Colors.white30,
                                size: 18
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
                                    size: 20
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
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                                        size: 18
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
                          onTap: currentPage < widget.imageFiles.length - 1 ? _nextPage : null,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              // Last page par background halka ho jayega
                              color: currentPage < widget.imageFiles.length - 1 ? Colors.black87 : Colors.black38,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                                Icons.arrow_forward_ios_rounded,
                                // Last page par icon fade ho jayega
                                color: currentPage < widget.imageFiles.length - 1 ? Colors.white : Colors.white30,
                                size: 18
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
          if (isThumbnailVisible)
            Container(
              height: 90,
              color: const Color(0xFF1E1E1E),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.imageFiles.length,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                          //image: FileImage(widget.imageFiles[index]),
                          image: FileImage(widget.imageFiles[index]['cropped']!),
                          fit: BoxFit.cover,
                        ),
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.transparent,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Stack(
                        children: [
                          // Align(
                          //   alignment: Alignment.bottomCenter,
                          //   child: Container(
                          //     height: 20,
                          //     decoration: const BoxDecoration(
                          //       gradient: LinearGradient(
                          //         begin: Alignment.bottomCenter,
                          //         end: Alignment.topCenter,
                          //         colors: [Colors.black87, Colors.transparent],
                          //       ),
                          //     ),
                          //   ),
                          // ),
                          // Align(
                          //   alignment: Alignment.bottomCenter,
                          //   child: Padding(
                          //     padding: const EdgeInsets.only(bottom: 2),
                          //     child: Text(
                          //       '${index + 1}',
                          //       style: const TextStyle(
                          //         color: Colors.white,
                          //         fontSize: 13,
                          //         fontWeight: FontWeight.bold,
                          //       ),
                          //     ),
                          //   ),
                          // ),

                          // Number with small dark background box
                          Align(
                            alignment: Alignment.bottomCenter, // Number ko thoda right side me rakha hai jo zyada accha lagta hai
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6), // Low opacity black background
                                borderRadius: BorderRadius.circular(10), // Small rounded shape
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

          /// NEW ACTION TOOLS BAR (Horizontal Scrollable)
          Container(
            height: 85,
            color: const Color(0xFF151515), // Dark background for tools section
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              children: [
                _buildToolItem(label: "Retake", icon: Icons.refresh_rounded, tooltipMessage: "Retake current photo"),
                _buildToolItem(label: "Crop", icon: Icons.crop_rounded, tooltipMessage: "Crop & adjust borders"),
                _buildToolItem(label: "Rotate", icon: Icons.rotate_right_rounded, tooltipMessage: "Rotate 90 degrees"),
                _buildToolItem(label: "Filter", icon: Icons.photo_filter_rounded, tooltipMessage: "Apply color filters"),
                _buildToolItem(label: "Adjust", icon: Icons.tune_rounded, tooltipMessage: "Adjust brightness and contrast"),
                _buildToolItem(label: "Markup", icon: Icons.border_color_rounded, tooltipMessage: "Draw or add text on image"),
                _buildToolItem(label: "Cleanup", icon: Icons.auto_fix_high_rounded, tooltipMessage: "Erase unwanted areas"),
                _buildToolItem(label: "Resize", icon: Icons.aspect_ratio_rounded, tooltipMessage: "Change page layout size"),
                _buildToolItem(label: "Reorder", icon: Icons.swap_horizontal_circle_outlined, tooltipMessage: "Rearrange page sequence"),
                _buildToolItem(label: "Delete", icon: Icons.delete_outline_rounded, tooltipMessage: "Delete current page"),
              ],
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
                      backgroundColor: Colors.blueAccent, // Adobe scan jaisa blue
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
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
    );
  }


  // Helper widget to build action tools with icon, text, tooltip, and toast
  Widget _buildToolItem({
    required String label,
    required IconData icon,
    required String tooltipMessage
  }) {
    return Tooltip(
      message: tooltipMessage,
      child: GestureDetector(
        onTap: () => showToast("$label clicked"), // Placeholder toast
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}/// end main class