import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:open_file/open_file.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; // 0 for Home, 1 for Files

  // AdMob Banner Variables
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  List<File> _pdfFiles = [];
  bool _isLoadingFiles = true;


  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _loadPdfFiles(); // Screen open hote hi files load karega
  }

  // Load Banner Ad
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // Test Banner ID
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          print("Banner Ad failed to load: $error");
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  // Helper for Toasts
  void showToast(String msg) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.white,
      textColor: Colors.black,
    );
  }

  // 1. Files ko folder se read karna aur sort karna
  Future<void> _loadPdfFiles() async {
    try {
      final directory = Directory('/storage/emulated/0/Documents/PDF Scanner Pro');
      if (await directory.exists()) {
        List<FileSystemEntity> entities = directory.listSync();
        List<File> files = entities.whereType<File>().where((f) => f.path.endsWith('.pdf')).toList();

        // Sort: Latest file sabse upar (Descending order)
        files.sort((a, b) {
          return b.lastModifiedSync().compareTo(a.lastModifiedSync());
        });

        setState(() {
          _pdfFiles = files;
          _isLoadingFiles = false;
        });
      } else {
        setState(() => _isLoadingFiles = false);
      }
    } catch (e) {
      setState(() => _isLoadingFiles = false);
      print("Error loading files: $e");
    }
  }

  // 2. File name ko truncate (short) karna: start...end.pdf
  String _truncateFileName(String name) {
    if (name.length <= 25) return name; // Agar chhota hai to waise hi chhod do

    String extension = name.split('.').last;
    String baseName = name.substring(0, name.lastIndexOf('.'));

    if (baseName.length <= 15) return name;

    // First 12 chars + ... + Last 4 chars + extension
    return "${baseName.substring(0, 12)}...${baseName.substring(baseName.length - 4)}.$extension";
  }

  // 3. File size ko KB/MB mein convert karna
  String _getFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  // 4. Date ko Today / Yesterday / Date mein badalna
  String _getDateCategory(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final fileDate = DateTime(date.year, date.month, date.day);

    if (fileDate == today) {
      return "Today";
    } else if (fileDate == yesterday) {
      return "Yesterday";
    } else {
      return DateFormat('dd MMM yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Dark theme matching screenshot

      /// 1. APP BAR
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          "PDF Scanner Pro",
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        actions: [
          Tooltip(
            message: "Search documents",
            child: IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () => showToast("Search clicked"),
            ),
          ),
          Tooltip(
            message: "More options",
            child: IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: () => showToast("More options clicked"),
            ),
          ),
        ],
      ),

      /// BODY: Banner Ad + Tab View
      body: Column(
        children: [
          /// 2. BANNER AD (Top Bar ke niche)
          if (_isBannerAdLoaded && _bannerAd != null)
            Container(
              alignment: Alignment.center,
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              color: Colors.black, // Background so it blends in
              child: AdWidget(ad: _bannerAd!),
            ),

          /// 3. TAB VIEW (Ads ke niche content)
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                // View 0: Home Tab Content
                // const Center(
                //   child: Text(
                //     "Home View (List of PDFs will come here)",
                //     style: TextStyle(color: Colors.white70, fontSize: 16),
                //   ),
                // ),

                // View 0: Home Tab Content
                _buildHomeTabContent(),

                // View 1: Files Tab Content
                const Center(
                  child: Text(
                    "Files View (Folders will come here)",
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      /// 5. CENTER CAMERA BUTTON (Floating)
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showToast("Opening Camera...");
          // TODO: Yahan par aapka ScannerScreen() open hoga
          // Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen()));
        },
        backgroundColor: Colors.lightBlueAccent, // Matching the blue in screenshot
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.camera_enhance_rounded, color: Colors.black, size: 28),
      ),

      // Floating button ko bottom bar ke middle me set karne ke liye
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      /// 4. BOTTOM TAB BAR
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF1E1E1E),
        shape: const CircularNotchedRectangle(), // Camera button ke liye curve banayega
        notchMargin: 8.0,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // HOME OPTION
              Tooltip(
                message: "Home",
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      _currentIndex = 0;
                    });
                    showToast("Home Tab selected");
                  },
                  child: SizedBox(
                    width: 80,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.home_filled,
                          color: _currentIndex == 0 ? Colors.lightBlueAccent : Colors.white54,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Home",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _currentIndex == 0 ? FontWeight.bold : FontWeight.normal,
                            color: _currentIndex == 0 ? Colors.lightBlueAccent : Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 40), // Beech me Camera button ke liye space

              // FILES OPTION
              Tooltip(
                message: "Files",
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      _currentIndex = 1;
                    });
                    showToast("Files Tab selected");
                  },
                  child: SizedBox(
                    width: 80,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.insert_drive_file_outlined,
                          color: _currentIndex == 1 ? Colors.lightBlueAccent : Colors.white54,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Files",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _currentIndex == 1 ? FontWeight.bold : FontWeight.normal,
                            color: _currentIndex == 1 ? Colors.lightBlueAccent : Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Home Tab Content Builder
  Widget _buildHomeTabContent() {
    if (_isLoadingFiles) {
      return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
    }

    if (_pdfFiles.isEmpty) {
      // Empty State: Lottie Animation
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              "assets/lottie/no_files_animation.json",
              height: 220,
            ),
            const SizedBox(height: 16),
            const Text(
              "No PDF files yet.\nTap the camera to scan!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
      );
    }

    // List with Date Grouping Headers
    String? lastCategory;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80, top: 10), // Bottom padding floating button ke liye
      itemCount: _pdfFiles.length,
      itemBuilder: (context, index) {
        final file = _pdfFiles[index];
        final fileStat = file.statSync();
        final dateCategory = _getDateCategory(fileStat.modified);

        bool showHeader = lastCategory != dateCategory;
        lastCategory = dateCategory;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  dateCategory,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            // PDF File Card (Matching Screenshot)
            GestureDetector(
              onTap: () {
                OpenFile.open(file.path); // Abhi ke liye open_file use kar rahe hain
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E), // Dark grey card
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    // Left Side: Placeholder Thumbnail
                    Container(
                      width: 70,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Center(
                        child: Icon(Icons.picture_as_pdf_rounded, color: Colors.white54, size: 30),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Right Side: Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // File Name
                          Text(
                            _truncateFileName(file.path.split('/').last),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                          ),
                          const SizedBox(height: 6),

                          // Date & Time
                          Text(
                            DateFormat('MM/dd/yy  •  hh:mm a').format(fileStat.modified),
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                          const SizedBox(height: 2),

                          // File Size
                          Text(
                            _getFileSize(fileStat.size),
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                          const SizedBox(height: 8),

                          // Actions (Share & More)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Tooltip(
                                message: "Share",
                                child: InkWell(
                                  onTap: () => showToast("Share clicked"),
                                  child: const Icon(Icons.share_outlined, color: Colors.white70, size: 22),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Tooltip(
                                message: "More",
                                child: InkWell(
                                  onTap: () => showToast("More options"),
                                  child: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 22),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }


}///end main class