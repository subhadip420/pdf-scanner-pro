import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

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

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
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
                const Center(
                  child: Text(
                    "Home View (List of PDFs will come here)",
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),

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
}