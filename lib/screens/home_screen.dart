import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart' hide PdfDocument;
import 'package:pdf_scanner_pro/screens/scanner_screen.dart';
import 'package:pdfx/pdfx.dart';
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'custom_gallery_screen.dart'; // Apni gallery wali screen
import 'document_editor_screen.dart'; // Apna editor

import 'package:permission_handler/permission_handler.dart'; // Uint8List ke liye zaroori hai
import 'package:share_plus/share_plus.dart';



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
  bool _isFabMenuOpen = false;

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
  // 1. Files ko folder se read karna aur sort karna
  Future<void> _loadPdfFiles() async {
    try {
      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }
      final directory = Directory('/storage/emulated/0/Documents/PDF Scanner Pro');
      if (await directory.exists()) {
        List<FileSystemEntity> entities = directory.listSync();

        // YAHAN UPDATE KIYA: Hamesha check karega ki file PDF hai (case insensitive)
        List<File> files = entities.whereType<File>().where((f) => f.path.toLowerCase().endsWith('.pdf')).toList();

        // Sort: Latest file sabse upar (Descending order)
        files.sort((a, b) {
          return b.lastModifiedSync().compareTo(a.lastModifiedSync());
        });

        if (mounted) {
          setState(() {
            _pdfFiles = files;
            _isLoadingFiles = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingFiles = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingFiles = false);
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

  Future<void> _openGalleryForPdf() async {
    try {
      // 1. Permission Handle Karo
      PermissionStatus status = PermissionStatus.denied;
      if (Platform.isAndroid) {
        status = await Permission.photos.status;
        if (status.isDenied) status = await Permission.photos.request();
        if (status.isDenied || status.isRestricted) {
          status = await Permission.storage.status;
          if (status.isDenied) status = await Permission.storage.request();
        }
      } else {
        status = await Permission.photos.request();
      }

      if (status.isPermanentlyDenied) {
        showToast("Please enable Gallery permission from settings.");
        await openAppSettings();
        return;
      }
      if (!status.isGranted && !status.isLimited) {
        showToast("Gallery permission required.");
        return;
      }

      // 2. Apni Premium Custom Gallery kholo
      if (!mounted) return;
      final List<File>? selectedFiles = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CustomGalleryScreen()),
      );

      // Agar user ne cancel kar diya (bina select kiye back aagaya)
      if (selectedFiles == null || selectedFiles.isEmpty) return;

      // 3. Files ko Editor ke format (Map) mein convert karo
      List<Map<String, File>> imagesToEdit = [];
      for (var file in selectedFiles) {
        imagesToEdit.add({'original': file, 'cropped': file});
      }

      // 4. Seedha DocumentEditorScreen par navigate kar jao
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (context) => DocumentEditorScreen(imageFiles: imagesToEdit)));
    } catch (e) {
      print("Home Screen Gallery Error: $e");
      showToast("Error opening gallery");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      // Dark theme matching screenshot

      /// 1. APP BAR
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("PDF Scanner Pro", style: TextStyle(color: Colors.white, fontSize: 20)),
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

      /// BODY: Banner Ad + Tab View + Dark Overlay
      body: Stack(
        children: [
          // 1. Tumhara Purana Main Content (Banner Ad + Tabs)
          Column(
            children: [
              if (_isBannerAdLoaded && _bannerAd != null)
                Container(
                  alignment: Alignment.center,
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  color: Colors.black,
                  child: AdWidget(ad: _bannerAd!),
                ),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: [
                    _buildHomeTabContent(),
                    const Center(
                      child: Text("Files View", style: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 2. Dark Overlay (Jab button click ho)
          if (_isFabMenuOpen)
            GestureDetector(
              onTap: () {
                // Blank jagah par click karne se close ho jayega
                setState(() => _isFabMenuOpen = false);
              },
              child: Container(
                color: Colors.black.withOpacity(0.85), // Background ko dark kar dega
                width: double.infinity,
                height: double.infinity,
              ),
            ),

          // 3. Menu Options (Floating list)
          if (_isFabMenuOpen)
            Positioned(
              bottom: 90, // X button ke thik upar
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMenuPill("Create from photos", Icons.photo_library_outlined, () {
                    showToast("Gallery opening...");
                    // 1. Pehle fab menu ko close karo
                    setState(() => _isFabMenuOpen = false);

                    // 2. Fir apni gallery open karne wala function call kar do
                    _openGalleryForPdf();
                  }),
                  const SizedBox(height: 12), // Dono button ke beech ka gap
                  _buildMenuPill("Create scan", Icons.add_a_photo_outlined, () {
                    setState(() => _isFabMenuOpen = false);
                    // TODO: Yahan par aapka ScannerScreen() open hoga
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen()));
                  }),
                ],
              ),
            ),
        ],
      ),

      /// 5. CENTER CAMERA BUTTON (Dynamic X or Camera)
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _isFabMenuOpen = !_isFabMenuOpen; // Toggle Open/Close
          });
        },
        backgroundColor: Colors.lightBlueAccent,
        shape: const CircleBorder(),
        elevation: 4,
        child: Icon(
          _isFabMenuOpen ? Icons.close_rounded : Icons.camera_enhance_rounded, // Icon change hoga
          color: Colors.black,
          size: 28,
        ),
      ),

      // Floating button ki position dynamic kar di
      floatingActionButtonLocation: _isFabMenuOpen
          ? FloatingActionButtonLocation
                .centerFloat // Menu open hone par center me float karega
          : FloatingActionButtonLocation.centerDocked,
      // Normal rehne par notch me

      /// 4. BOTTOM TAB BAR (Hidden when menu is open)
      bottomNavigationBar: _isFabMenuOpen
          ? const SizedBox.shrink() // Menu open hone par bottom bar gayab!
          : BottomAppBar(
              color: const Color(0xFF1E1E1E),
              shape: const CircularNotchedRectangle(),
              notchMargin: 8.0,
              child: SizedBox(
                height: 60,
                // ... (Tumhara bacha hua BottomAppBar ka Row() wala code bilkul same rahega) ...
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

  // Floating Menu ke options banane ke liye helper widget
  Widget _buildMenuPill(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260, // Button ki fixed width taaki sab barabar dikhein
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF333333), // Dark grey Adobe Scan jaisa
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
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
            Lottie.asset("assets/lottie/no_files_animation.json", height: 220),
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

    // Total items calculate karna (Files + Ads)
    int totalItemCount;
    if (_pdfFiles.length < 5) {
      totalItemCount = _pdfFiles.length + 1; // 1 Ad at the end
    } else {
      // Har 5 item ke baad 1 ad (6th item)
      totalItemCount = _pdfFiles.length + (_pdfFiles.length ~/ 5);
    }

    return RefreshIndicator(
      onRefresh: _loadPdfFiles, // Niche swipe karne par list refresh hogi
      color: Colors.blueAccent,
      backgroundColor: const Color(0xFF1E1E1E),
      child: ListView.builder(
        // 'AlwaysScrollableScrollPhysics' add kiya taaki list chhoti hone par bhi refresh ho sake
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 80, top: 10),
        itemCount: totalItemCount,
        itemBuilder: (context, index) {
          // Logic: Decide karein ki yeh index Ad ka hai ya File ka
          bool isAdIndex;
          if (_pdfFiles.length < 5) {
            isAdIndex = (index == _pdfFiles.length); // Sabse last index ad hoga
          } else {
            isAdIndex = (index + 1) % 6 == 0; // Har 6th position par ad (index 5, 11, 17...)
          }

          // Agar yeh position Ad ki hai, toh NativeAd return karein
          if (isAdIndex) {
            return const NativeAdCard();
          }

          // Agar File hai, toh asli file index nikalein
          int fileIndex;
          if (_pdfFiles.length < 5) {
            fileIndex = index;
          } else {
            fileIndex = index - (index ~/ 6); // Ad ke index ko minus kar diya taaki list sahi chale
          }

          final file = _pdfFiles[fileIndex];
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
                    style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),

              // PDF File Card
              GestureDetector(
                onTap: () {
                  OpenFile.open(file.path);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      // Left Side: Real PDF Thumbnail
                      Container(
                        width: 70,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white12),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: PdfThumbnailView(filePath: file.path),
                      ),
                      const SizedBox(width: 16),

                      // Right Side: Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _truncateFileName(file.path.split('/').last),
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                              maxLines: 1,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateFormat('MM/dd/yy  •  hh:mm a').format(fileStat.modified),
                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _getFileSize(fileStat.size),
                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Tooltip(
                                  message: "Share",
                                  child: InkWell(
                                    //onTap: () => showToast("Share clicked"),
                                    onTap: () => _sharePdfFile(file),
                                    child: const Icon(Icons.share_outlined, color: Colors.white70, size: 22),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Tooltip(
                                //   message: "More",
                                //   child: InkWell(
                                //     onTap: () => showToast("More options"),
                                //     child: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 22),
                                //   ),
                                // ),
                                Tooltip(
                                  message: "More options",
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () => _showFileOptionsBottomSheet(context, file),
                                    child: const Padding(
                                      padding: EdgeInsets.all(6.0),
                                      child: Icon(Icons.more_vert_rounded, color: Colors.white70, size: 22),
                                    ),
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
      ),
    );
  }

// 🚨 NAYA FUNCTION: Updated with New Options & Scrollable Support
  void _showFileOptionsBottomSheet(BuildContext context, File file) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Zaroori hai taaki list badi hone par scroll ho sake
      backgroundColor: const Color(0xFF1E1E1E),
      elevation: 10,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              // Niche drag karne wala handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // File ka Real Name Header me dikhao
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  file.path.split('/').last,
                  style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(color: Colors.white12, height: 24, thickness: 1),

              // 🚨 FIX: Options ko scrollable banaya taaki chhote phones me overflow na ho
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Share Option (Tumhara asli function call karega)
                      ListTile(
                        leading: const Icon(Icons.share_outlined, color: Colors.white, size: 22),
                        title: const Text('Share', style: TextStyle(color: Colors.white, fontSize: 16)),
                        onTap: () {
                          Navigator.pop(context); // Pehle menu close karo
                          _sharePdfFile(file); // Phir file share menu kholo
                        },
                      ),

                      // 2. Open with
                      ListTile(
                        leading: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 22),
                        title: const Text('Open with', style: TextStyle(color: Colors.white, fontSize: 16)),
                        onTap: () {
                          Navigator.pop(context);
                          showToast("Open with clicked");
                        },
                      ),

                      // 3. Copy Option
                      ListTile(
                        leading: const Icon(Icons.file_copy_outlined, color: Colors.white, size: 22),
                        title: const Text('Copy', style: TextStyle(color: Colors.white, fontSize: 16)),
                        onTap: () {
                          Navigator.pop(context);
                          _copyPdfFile(file);
                          //showToast("Copy clicked");
                        },
                      ),

                      // 4. Save pages as JPEG
                      ListTile(
                        leading: const Icon(Icons.image_outlined, color: Colors.white, size: 22),
                        title: const Text('Save pages as JPEG', style: TextStyle(color: Colors.white, fontSize: 16)),
                        onTap: () {
                          Navigator.pop(context);
                          showToast("Save pages as JPEG clicked");
                        },
                      ),

                      // 5. Rename Option
                      ListTile(
                        leading: const Icon(Icons.edit_outlined, color: Colors.white, size: 22),
                        title: const Text('Rename', style: TextStyle(color: Colors.white, fontSize: 16)),
                        onTap: () {
                          Navigator.pop(context);
                          //showToast("Rename clicked");
                          _renamePdfFile(context, file);
                        },
                      ),

                      // 6. Print Option
                      ListTile(
                        leading: const Icon(Icons.print_outlined, color: Colors.white, size: 22),
                        title: const Text('Print', style: TextStyle(color: Colors.white, fontSize: 16)),
                        onTap: () {
                          Navigator.pop(context);
                          //showToast("Print clicked");
                          _printPdfFile(file);
                        },
                      ),

                      // 7. Details Option
                      ListTile(
                        leading: const Icon(Icons.info_outline, color: Colors.white, size: 22),
                        title: const Text('Details', style: TextStyle(color: Colors.white, fontSize: 16)),
                        onTap: () {
                          Navigator.pop(context);
                          //showToast("Details clicked");
                          _showPdfDetails(context, file);
                        },
                      ),

                      const Divider(color: Colors.white12, height: 16),

                      // 8. Delete Option (Danger Zone - Red)
                      ListTile(
                        leading: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                        title: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                        onTap: () {
                          Navigator.pop(context);
                          showToast("Delete clicked");
                        },
                      ),
                      const SizedBox(height: 10), // Safe spacing
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  //PDF Share karne ke liye
  // 🚨 NAYA FUNCTION: PDF Share karne ke liye (Fixed for Latest ShareParams API)
  Future<void> _sharePdfFile(File file) async {
    try {
      final xFile = XFile(file.path);

      // 🚨 FIX: 'xFiles' ki jagah sirf 'files' aayega
      await SharePlus.instance.share(
        ShareParams(
          files: [xFile], // Yahan change kiya hai
          text: 'Document shared from PDF Scanner Pro',
        ),
      );
    } catch (e) {
      showToast("Error sharing file");
      print("Share Error: $e");
    }
  }

  // 🚨 NAYA FUNCTION: PDF File ko duplicate (copy) karne ke liye
  Future<void> _copyPdfFile(File originalFile) async {
    try {
      String originalPath = originalFile.path;

      // Path ko 3 hisso me todna: Folder path, File ka naam, aur Extension (.pdf)
      String dir = originalPath.substring(0, originalPath.lastIndexOf('/'));
      String fileName = originalPath.substring(originalPath.lastIndexOf('/') + 1);
      String baseName = fileName.substring(0, fileName.lastIndexOf('.'));
      String extension = fileName.substring(fileName.lastIndexOf('.'));

      // Naya naam banayenge: "OriginalName_copy.pdf"
      String newPath = '$dir/${baseName}_copy$extension';
      File newFile = File(newPath);

      // Agar "OriginalName_copy.pdf" pehle se hai, toh aage number badhate jayenge (e.g., _copy(1), _copy(2))
      int counter = 1;
      while (await newFile.exists()) {
        newPath = '$dir/${baseName}_copy($counter)$extension';
        newFile = File(newPath);
        counter++;
      }

      // Asli magic: File ko naye path par copy kar diya
      await originalFile.copy(newPath);

      // List ko refresh karo taaki nayi file turant upar dikhe
      await _loadPdfFiles();

      showToast("File copied successfully");
    } catch (e) {
      print("Copy Error: $e");
      showToast("Error copying file");
    }
  }


  // 🚨 NAYA FUNCTION: PDF File ko Rename karne ke liye (Popup ke sath)
  void _renamePdfFile(BuildContext context, File originalFile) {
    String originalPath = originalFile.path;
    String dir = originalPath.substring(0, originalPath.lastIndexOf('/'));
    String fileName = originalPath.substring(originalPath.lastIndexOf('/') + 1);
    String baseName = fileName.substring(0, fileName.lastIndexOf('.')); // Sirf naam, '.pdf' ke bina

    // TextField me purana naam pre-fill karne ke liye controller
    TextEditingController nameController = TextEditingController(text: baseName);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C), // Premium Dark Grey
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Rename File', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: nameController,
            style: const TextStyle(color: Colors.white),
            autofocus: true, // Dialog khulte hi keyboard open ho jayega
            decoration: const InputDecoration(
              hintText: "Enter new name",
              hintStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.lightBlueAccent)),
              suffixText: '.pdf', // User ko dikhega ki yeh PDF banegi
              suffixStyle: TextStyle(color: Colors.white54),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Cancel button
              child: const Text('Cancel', style: TextStyle(color: Colors.white54, fontSize: 16)),
            ),
            TextButton(
              onPressed: () async {
                String newName = nameController.text.trim();

                // 1. Agar naam khali chhod diya
                if (newName.isEmpty) {
                  showToast("Name cannot be empty");
                  return;
                }

                String newPath = '$dir/$newName.pdf';
                File newFile = File(newPath);

                // 2. Agar naam change hi nahi kiya
                if (newPath == originalPath) {
                  Navigator.pop(context);
                  return;
                }

                // 3. Agar is naam ki file pehle se wahan hai
                if (await newFile.exists()) {
                  showToast("A file with this name already exists");
                  return;
                }

                // 4. Asli Magic: File ka naam badlo aur list refresh karo
                try {
                  await originalFile.rename(newPath);
                  Navigator.pop(context); // Dialog band karo
                  await _loadPdfFiles(); // 🚨 Naye naam ke sath list refresh!
                  showToast("File renamed successfully");
                } catch (e) {
                  print("Rename Error: $e");
                  showToast("Error renaming file");
                }
              },
              child: const Text('Rename', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // 🚨 NAYA FUNCTION: PDF File ki details dikhane ke liye
  void _showPdfDetails(BuildContext context, File file) {
    // File ki information (Size, Date) nikalna
    final stat = file.statSync();
    final String fileName = file.path.split('/').last;
    final String fileSize = _getFileSize(stat.size); // Tumhara hi banaya hua function!
    final String modifiedDate = DateFormat('dd MMM yyyy, hh:mm a').format(stat.modified);
    final String filePath = file.path;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C), // Premium Dark Grey
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('File Details', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Jitna content utni jagah lega
              children: [
                _buildDetailRow("Name", fileName),
                _buildDetailRow("Type", "PDF Document (.pdf)"),
                _buildDetailRow("Size", fileSize),
                _buildDetailRow("Modified", modifiedDate),
                _buildDetailRow("Location", filePath),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Dialog band karne ke liye
              child: const Text('Close', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // 🚨 HELPER WIDGET: Details ko sundar design me dikhane ke liye
  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 15)),
        ],
      ),
    );
  }

  // 🚨 NAYA FUNCTION: PDF File ko Print karne ke liye
  Future<void> _printPdfFile(File file) async {
    try {
      // File ka naam nikalna taaki Print menu me wahi naam dikhe
      final String fileName = file.path.split('/').last;

      // 🚨 Asli Magic: Flutter ka native print manager call karna
      await Printing.layoutPdf(
        name: fileName,
        onLayout: (PdfPageFormat format) async {
          return await file.readAsBytes(); // PDF ko bytes me convert karke printer ko de dega
        },
      );
    } catch (e) {
      print("Print Error: $e");
      showToast("Error printing file");
    }
  }

}//end main class
///end main class
///

// Custom Widget: PDF ka first page as Image render karne ke liye
class PdfThumbnailView extends StatefulWidget {
  final String filePath;

  const PdfThumbnailView({super.key, required this.filePath});

  @override
  State<PdfThumbnailView> createState() => _PdfThumbnailViewState();
}

class _PdfThumbnailViewState extends State<PdfThumbnailView> {
  Uint8List? _imageBytes;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    try {
      // PDF file open karein
      final document = await PdfDocument.openFile(widget.filePath);
      // First page (Page 1) get karein
      final page = await document.getPage(1);

      // Resolution thodi kam rakhi hai (width/3) taaki list smoothly scroll ho aur memory bache
      final pageImage = await page.render(
        width: page.width / 3,
        height: page.height / 3,
        format: PdfPageImageFormat.jpeg,
      );

      await page.close();
      await document.close();

      if (mounted && pageImage != null) {
        setState(() {
          _imageBytes = pageImage.bytes;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Agar error aayi to purana PDF icon dikhao
    if (_hasError) {
      return const Center(child: Icon(Icons.picture_as_pdf_rounded, color: Colors.white54, size: 30));
    }
    // Jab tak load ho raha hai, loader dikhao
    if (_imageBytes == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white30));
    }
    // Load hone ke baad real image dikhao
    return Image.memory(_imageBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
  }
}

// Custom Widget: Native Ad Load aur Show karne ke liye
class NativeAdCard extends StatefulWidget {
  const NativeAdCard({super.key});

  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<NativeAdCard> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadNativeAd();
  }

  void _loadNativeAd() {
    _nativeAd = NativeAd(
      adUnitId: 'ca-app-pub-3940256099942544/2247696110',
      // Google's Test Native Ad ID
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          print('Native ad failed to load: $error');
        },
      ),
      // Flutter ka built-in Native Template (Android/iOS dono me bina extra code ke chalega)
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: const Color(0xFF1E1E1E),
        cornerRadius: 12.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: Colors.blueAccent,
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: Colors.transparent,
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white70,
          backgroundColor: Colors.transparent,
          style: NativeTemplateFontStyle.normal,
          size: 14.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white54,
          backgroundColor: Colors.transparent,
          style: NativeTemplateFontStyle.normal,
          size: 14.0,
        ),
      ),
    )..load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdLoaded || _nativeAd == null) {
      return const SizedBox.shrink(); // Jab tak load na ho, kuch mat dikhao
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      height: 130,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      clipBehavior: Clip.hardEdge,
      child: Center(
        child: SizedBox(
          height: 91, // Google Small Template ki standard height 91dp hoti hai
          child: AdWidget(ad: _nativeAd!),
        ),
      ),
    );
  }
}
