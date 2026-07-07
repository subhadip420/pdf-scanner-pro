import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:shared_preferences/shared_preferences.dart';
import 'custom_dialog.dart';
import 'custom_gallery_screen.dart'; // Apni gallery wali screen
import 'document_editor_screen.dart'; // Apna editor

import 'package:permission_handler/permission_handler.dart'; // Uint8List ke liye zaroori hai
import 'package:share_plus/share_plus.dart';

import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion; // 🚨 MAGIC: Humne isko ek nick-name de diya!


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
// 🚨 NAYA: Saved (Bookmarked) files ke paths ko yaad rakhne ke liye list
  List<String> _savedFilePaths = [];
// 🚨 NAYA: Sort track karne ke liye variable (Default: Date)
  String _sortBy = 'Date';
  bool _isAscending = false;
  // 🚨 NAYA: Bulk Selection Variables
  bool _isSelectionMode = false;
  Set<String> _selectedFiles = {}; // Set use kar rahe hain taaki duplicates na aayein

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _loadPdfFiles(); // Screen open hote hi files load karega
    _loadSavedFiles();
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
        // files.sort((a, b) {
        //   return b.lastModifiedSync().compareTo(a.lastModifiedSync());
        // });

        // 🚨 NAYA SORT LOGIC: User ki pasand ke hisaab se sort hoga
        // 🚨 ULTIMATE SORT LOGIC: (Ascending / Descending dono support karega)
        files.sort((a, b) {
          int result;
          if (_sortBy == 'Name') {
            result = a.path.split('/').last.toLowerCase().compareTo(b.path.split('/').last.toLowerCase());
          } else if (_sortBy == 'Size') {
            result = a.statSync().size.compareTo(b.statSync().size);
          } else {
            result = a.lastModifiedSync().compareTo(b.lastModifiedSync());
          }

          // Agar Ascending hai toh normal order, warna Descending ke liye ulta (-result) kar do!
          return _isAscending ? result : -result;
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

  // 🚨 NAYA FUNCTION: SharedPreferences se saved files ke paths load karne ke liye
  Future<void> _loadSavedFiles() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String>? savedList = prefs.getStringList('saved_pdf_paths');
      if (savedList != null && mounted) {
        setState(() {
          _savedFilePaths = savedList;
        });
      }
    } catch (e) {
      print("SharedPreferences Load Error: $e");
    }
  }

  // 🚨 NAYA FUNCTION: File ko Save/Unsave karne aur SharedPreferences me permanently store karne ke liye
  Future<void> _toggleSaveFile(String filePath) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      setState(() {
        if (_savedFilePaths.contains(filePath)) {
          _savedFilePaths.remove(filePath);
          showToast("Removed from saved");
        } else {
          _savedFilePaths.add(filePath);
          showToast("Added to saved");
        }
      });

      // 🚨 Permanent Persistence: Nayi list ko disk par save kar do
      await prefs.setStringList('saved_pdf_paths', _savedFilePaths);
    } catch (e) {
      print("SharedPreferences Save Error: $e");
      showToast("Error updating save status");
    }
  }

  // 2. File name ko truncate (short) karna: start...end.pdf
  String _truncateFileName(String name) {
    if (name.length <= 26) return name; // Agar chhota hai to waise hi chhod do

    String extension = name.split('.').last;
    String baseName = name.substring(0, name.lastIndexOf('.'));

    if (baseName.length <= 16) return name;

    // First 12 chars + ... + Last 4 chars + extension
    return "${baseName.substring(0, 16)}...${baseName.substring(baseName.length - 6)}.$extension";
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
    // return Scaffold(

    // 🚨 MAGIC WIDGET: Back button ko intercept karne ke liye PopScope
    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (bool didPop, Object? result) { // 🚨 NAYA: result parameter add kiya
        if (didPop) {
          return; // Agar pop ho chuka hai, toh aage kuch mat karo
        }

        // Agar select mode ON tha, toh cancel karke normal mode me wapas aao
        if (_isSelectionMode) {
          setState(() {
            _isSelectionMode = false;
            _selectedFiles.clear();
          });
        }
      },
    child: Scaffold(
      backgroundColor: const Color(0xFF121212),
      // Dark theme matching screenshot

      /// 1. APP BAR
      // appBar: AppBar(
      //   backgroundColor: Colors.black,
      //   title: const Text("PDF Scanner Pro", style: TextStyle(color: Colors.white, fontSize: 20)),
      //   actions: [
      //     Tooltip(
      //       message: "Search documents",
      //       child: IconButton(
      //         icon: const Icon(Icons.search, color: Colors.white),
      //         //onPressed: () => showToast("Search clicked"),
      //         onPressed: () {
      //           // 🚨 MAGIC: Ye default search page ko animate karke open karega!
      //           showSearch(
      //             context: context,
      //             delegate: PdfSearchDelegate(_pdfFiles), // Tumhari loaded files isko de di
      //           );
      //         },
      //       ),
      //     ),
      //     // Tooltip(
      //     //   message: "More options",
      //     //   child: IconButton(
      //     //     icon: const Icon(Icons.more_vert, color: Colors.white),
      //     //     onPressed: () => showToast("More options clicked"),
      //     //   ),
      //     // ),
      //     // 🚨 MAGIC: Poora bara code gayab, ab sirf ye function call hoga!
      //     _buildMainAppBarMenu(),
      //   ],
      // ),

      /// 1. APP BAR
      appBar: _isSelectionMode
          ? AppBar(
        backgroundColor: const Color(0xFF1E1E1E), // Dark selection header
        leadingWidth: 80, // 🚨 MAGIC FIX: Text ko poori jagah dene ke liye width badhayi
        leading: TextButton(
          onPressed: () {
            setState(() {
              _isSelectionMode = false; // Mode OFF
              _selectedFiles.clear(); // Sab deselect kar do
            });
          },
          child: const Text(
            "Cancel",
            style: TextStyle(color: Colors.lightBlueAccent, fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        title: Text(
          "${_selectedFiles.length} Selected",
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true, // 🚨 NAYA: Title ko center me rakha taaki dono side ke text buttons balance lagein
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                // Agar saari files select ho chuki hain, toh clear kar do
                if (_selectedFiles.length == _pdfFiles.length && _pdfFiles.isNotEmpty) {
                  _selectedFiles.clear();
                } else {
                  // Nahi toh saari files select kar lo
                  _selectedFiles = _pdfFiles.map((file) => file.path).toSet();
                }
              });
            },
            child: Text(
              // 🚨 DYNAMIC TEXT LOGIC: Sab select hone par "Deselect" likha aayega
              _selectedFiles.length == _pdfFiles.length && _pdfFiles.isNotEmpty ? "Deselect" : "Select All",
              style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8), // Right side screen edge se thodi safe padding
        ],
      )
          : AppBar(
        // ... TUMHARA NORMAL APP BAR (PDF Scanner Pro wala) YAHAN AAYEGA ...
        backgroundColor: Colors.black,
        title: const Text("PDF Scanner Pro", style: TextStyle(color: Colors.white, fontSize: 20)),
        actions: [
          Tooltip(
            message: "Search documents",
            child: IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () {
                showSearch(
                  context: context,
                  delegate: PdfSearchDelegate(_pdfFiles),
                );
              },
            ),
          ),
          _buildMainAppBarMenu(),
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
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () {
      //     setState(() {
      //       _isFabMenuOpen = !_isFabMenuOpen; // Toggle Open/Close
      //     });
      //   },
      //   backgroundColor: Colors.lightBlueAccent,
      //   shape: const CircleBorder(),
      //   elevation: 4,
      //   child: Icon(
      //     _isFabMenuOpen ? Icons.close_rounded : Icons.camera_enhance_rounded, // Icon change hoga
      //     color: Colors.black,
      //     size: 28,
      //   ),
      // ),

      /// 5. CENTER CAMERA BUTTON (Selection mode me hide ho jayega)
      floatingActionButton: _isSelectionMode
          ? null // 🚨 MAGIC: Null dene se button smoothly gayab ho jayega!
          : FloatingActionButton(
        onPressed: () {
          setState(() {
            _isFabMenuOpen = !_isFabMenuOpen; // Toggle Open/Close
          });
        },
        backgroundColor: Colors.lightBlueAccent,
        shape: const CircleBorder(),
        elevation: 4,
        child: Icon(
          _isFabMenuOpen ? Icons.close_rounded : Icons.camera_enhance_rounded,
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
      // bottomNavigationBar: _isFabMenuOpen
      //     ? const SizedBox.shrink() // Menu open hone par bottom bar gayab!
      //     : BottomAppBar(
      //         color: const Color(0xFF1E1E1E),
      //         shape: const CircularNotchedRectangle(),
      //         notchMargin: 8.0,
      //         child: SizedBox(
      //           height: 60,
      //           // ... (Tumhara bacha hua BottomAppBar ka Row() wala code bilkul same rahega) ...
      //           child: Row(
      //             mainAxisAlignment: MainAxisAlignment.spaceAround,
      //             children: [
      //               // HOME OPTION
      //               Tooltip(
      //                 message: "Home",
      //                 child: GestureDetector(
      //                   behavior: HitTestBehavior.opaque,
      //                   onTap: () {
      //                     setState(() {
      //                       _currentIndex = 0;
      //                     });
      //                     showToast("Home Tab selected");
      //                   },
      //                   child: SizedBox(
      //                     width: 80,
      //                     child: Column(
      //                       mainAxisAlignment: MainAxisAlignment.center,
      //                       children: [
      //                         Icon(
      //                           Icons.home_filled,
      //                           color: _currentIndex == 0 ? Colors.lightBlueAccent : Colors.white54,
      //                         ),
      //                         const SizedBox(height: 4),
      //                         Text(
      //                           "Home",
      //                           style: TextStyle(
      //                             fontSize: 12,
      //                             fontWeight: _currentIndex == 0 ? FontWeight.bold : FontWeight.normal,
      //                             color: _currentIndex == 0 ? Colors.lightBlueAccent : Colors.white54,
      //                           ),
      //                         ),
      //                       ],
      //                     ),
      //                   ),
      //                 ),
      //               ),
      //
      //               const SizedBox(width: 40), // Beech me Camera button ke liye space
      //               // FILES OPTION
      //               Tooltip(
      //                 message: "Files",
      //                 child: GestureDetector(
      //                   behavior: HitTestBehavior.opaque,
      //                   onTap: () {
      //                     setState(() {
      //                       _currentIndex = 1;
      //                     });
      //                     showToast("Files Tab selected");
      //                   },
      //                   child: SizedBox(
      //                     width: 80,
      //                     child: Column(
      //                       mainAxisAlignment: MainAxisAlignment.center,
      //                       children: [
      //                         Icon(
      //                           Icons.insert_drive_file_outlined,
      //                           color: _currentIndex == 1 ? Colors.lightBlueAccent : Colors.white54,
      //                         ),
      //                         const SizedBox(height: 4),
      //                         Text(
      //                           "Files",
      //                           style: TextStyle(
      //                             fontSize: 12,
      //                             fontWeight: _currentIndex == 1 ? FontWeight.bold : FontWeight.normal,
      //                             color: _currentIndex == 1 ? Colors.lightBlueAccent : Colors.white54,
      //                           ),
      //                         ),
      //                       ],
      //                     ),
      //                   ),
      //                 ),
      //               ),
      //             ],
      //           ),
      //         ),
      //       ),

      /// 4. BOTTOM TAB BAR (With Slide-Up Animation)
      // bottomNavigationBar: AnimatedSwitcher(
      //   duration: const Duration(milliseconds: 300), // Smooth animation speed
      //   transitionBuilder: (Widget child, Animation<double> animation) {
      //     return SlideTransition(
      //       position: Tween<Offset>(
      //         begin: const Offset(0.0, 1.0), // 1.0 ka matlab bottom se bahar
      //         end: Offset.zero, // Zero ka matlab screen par
      //       ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      //       child: child,
      //     );
      //   },
      //   // 🚨 LOGIC: Kaunsa bar dikhana hai?
      //   child: _isSelectionMode
      //       ? _buildSelectionBottomBar(key: const ValueKey('selectionModeBar'))
      //       : (_isFabMenuOpen
      //       ? const SizedBox.shrink(key: ValueKey('emptyBar'))
      //       : BottomAppBar(
      //     key: const ValueKey('normalModeBar'),
      //     color: const Color(0xFF1E1E1E),
      //     shape: const CircularNotchedRectangle(),
      //     notchMargin: 8.0,
      //     child: SizedBox(
      //       height: 60,
      //       child: Row(
      //         mainAxisAlignment: MainAxisAlignment.spaceAround,
      //         children: [
      //           // HOME OPTION
      //           Tooltip(
      //             message: "Home",
      //             child: GestureDetector(
      //               behavior: HitTestBehavior.opaque,
      //               onTap: () {
      //                 setState(() => _currentIndex = 0);
      //               },
      //               child: SizedBox(
      //                 width: 80,
      //                 child: Column(
      //                   mainAxisAlignment: MainAxisAlignment.center,
      //                   children: [
      //                     Icon(
      //                       Icons.home_filled,
      //                       color: _currentIndex == 0 ? Colors.lightBlueAccent : Colors.white54,
      //                     ),
      //                     const SizedBox(height: 4),
      //                     Text(
      //                       "Home",
      //                       style: TextStyle(
      //                         fontSize: 12,
      //                         fontWeight: _currentIndex == 0 ? FontWeight.bold : FontWeight.normal,
      //                         color: _currentIndex == 0 ? Colors.lightBlueAccent : Colors.white54,
      //                       ),
      //                     ),
      //                   ],
      //                 ),
      //               ),
      //             ),
      //           ),
      //
      //           const SizedBox(width: 40), // Beech me Camera button ke liye space
      //
      //           // FILES OPTION
      //           Tooltip(
      //             message: "Files",
      //             child: GestureDetector(
      //               behavior: HitTestBehavior.opaque,
      //               onTap: () {
      //                 setState(() => _currentIndex = 1);
      //               },
      //               child: SizedBox(
      //                 width: 80,
      //                 child: Column(
      //                   mainAxisAlignment: MainAxisAlignment.center,
      //                   children: [
      //                     Icon(
      //                       Icons.insert_drive_file_outlined,
      //                       color: _currentIndex == 1 ? Colors.lightBlueAccent : Colors.white54,
      //                     ),
      //                     const SizedBox(height: 4),
      //                     Text(
      //                       "Files",
      //                       style: TextStyle(
      //                         fontSize: 12,
      //                         fontWeight: _currentIndex == 1 ? FontWeight.bold : FontWeight.normal,
      //                         color: _currentIndex == 1 ? Colors.lightBlueAccent : Colors.white54,
      //                       ),
      //                     ),
      //                   ],
      //                 ),
      //               ),
      //             ),
      //           ),
      //         ],
      //       ),
      //     ),
      //   )),
      // ),

      /// 4. BOTTOM TAB BAR (Flicker-Free Smooth Slide-Up Animation)
      bottomNavigationBar: SizedBox(
        height: 70, // 🚨 FIX: Scaffold ko bata diya ki bottom space hamesha 60 hi rahega
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350), // Thoda aur smooth kiya
          // 🚨 FIX: LayoutBuilder lagane se flicker chala jata hai kyunki ye previous widget ko overlap karta hai
          layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
            return Stack(
              alignment: Alignment.bottomCenter,
              children: <Widget>[
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            );
          },
          transitionBuilder: (Widget child, Animation<double> animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 1.2), // 1.2 taaki ekdum bahar se smoothly aaye
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCirc, // 🚨 FIX: easeOutCubic se easeOutCirc zyada smooth lagta hai UI transitions me
              )),
              child: child,
            );
          },

          child: _isSelectionMode
              ? _buildSelectionBottomBar(key: const ValueKey('selectionModeBar'))
              : (_isFabMenuOpen
              ? const SizedBox.shrink(key: ValueKey('emptyBar'))
              : BottomAppBar(
            key: const ValueKey('normalModeBar'),
            color: const Color(0xFF1E1E1E),
            shape: const CircularNotchedRectangle(),
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
                        setState(() => _currentIndex = 0);
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
                        setState(() => _currentIndex = 1);
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
          )),
        ),
      ),
    ),
    );
  }

  // 🚨 APP BAR MENU WIDGET FUNCTION: Code ko saaf rakhne ke liye alag kiya
  Widget _buildMainAppBarMenu() {
    return PopupMenuButton<String>(
      color: const Color(0xFF2C2C2C), // Dark Premium Background
      surfaceTintColor: Colors.transparent, // Material 3 White Tint Fix
      icon: const Icon(Icons.more_vert, color: Colors.white),
      tooltip: "More options",
      offset: const Offset(0, 45), // Menu ko thoda neeche se open karne ke liye
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      constraints: const BoxConstraints(
        maxWidth: 180, // Isko apne hisaab se kam ya zyada kar sakte ho (e.g., 150 ya 200)
      ),
      // onSelected: (String value) {
      //   showToast("$value clicked");
      // },

      onSelected: (String value) {
        // 🚨 UPDATED LOGIC: Har value ke liye alag-alag dynamic actions aur toasts
        if (value == 'Select') {
          setState(() {
            _isSelectionMode = true;
            _selectedFiles.clear(); // Purani koi selection ho to clear ho jayegi
          });
          //showToast("Selection mode enabled");
        }
        else if (value == 'Settings') {
          // TODO: Future me yahan Settings screen open karne ka code aayega
          showToast("Opening Settings...");
        }
        else if (value == 'Help & Feedback') {
          // TODO: Future me yahan Support email ya helper page open hoga
          showToast("Opening Help & Support...");
        }
        else if (value == 'About') {
          // TODO: Future me yahan App Info ya Privacy Policy dialog dikhayenge
          showToast("PDF Scanner Pro v1.0.0");
        }
      },

      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        // 1. Select Option
        const PopupMenuItem<String>(
          value: 'Select',
          child: Row(
            children: [
              Icon(Icons.checklist_rounded, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Select', style: TextStyle(color: Colors.white, fontSize: 15)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1), // Divider

        // 2. Settings Option
        const PopupMenuItem<String>(
          value: 'Settings',
          child: Row(
            children: [
              Icon(Icons.settings_outlined, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Settings', style: TextStyle(color: Colors.white, fontSize: 15)),
            ],
          ),
        ),

        // 3. Help & Feedback Option
        const PopupMenuItem<String>(
          value: 'Help & Feedback',
          child: Row(
            children: [
              Icon(Icons.help_outline_rounded, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Help & Feedback', style: TextStyle(color: Colors.white, fontSize: 15)),
            ],
          ),
        ),

        // 4. About Option
        const PopupMenuItem<String>(
          value: 'About',
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('About', style: TextStyle(color: Colors.white, fontSize: 15)),
            ],
          ),
        ),
      ],
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

    // // Total items calculate karna (Files + Ads)
    // int totalItemCount;
    // if (_pdfFiles.length < 5) {
    //   totalItemCount = _pdfFiles.length + 1; // 1 Ad at the end
    // } else {
    //   // Har 5 item ke baad 1 ad (6th item)
    //   totalItemCount = _pdfFiles.length + (_pdfFiles.length ~/ 5);
    // }
    //
    // return RefreshIndicator(
    //   onRefresh: _loadPdfFiles, // Niche swipe karne par list refresh hogi
    //   color: Colors.blueAccent,
    //   backgroundColor: const Color(0xFF1E1E1E),
    //   child: ListView.builder(
    //     // 'AlwaysScrollableScrollPhysics' add kiya taaki list chhoti hone par bhi refresh ho sake
    //     physics: const AlwaysScrollableScrollPhysics(),
    //     padding: const EdgeInsets.only(bottom: 80, top: 10),
    //     itemCount: totalItemCount,
    //     itemBuilder: (context, index) {
    //       // Logic: Decide karein ki yeh index Ad ka hai ya File ka
    //       bool isAdIndex;
    //       if (_pdfFiles.length < 5) {
    //         isAdIndex = (index == _pdfFiles.length); // Sabse last index ad hoga
    //       } else {
    //         isAdIndex = (index + 1) % 6 == 0; // Har 6th position par ad (index 5, 11, 17...)
    //       }
    //
    //       // Agar yeh position Ad ki hai, toh NativeAd return karein
    //       if (isAdIndex) {
    //         return const NativeAdCard();
    //       }
    //
    //       // Agar File hai, toh asli file index nikalein
    //       int fileIndex;
    //       if (_pdfFiles.length < 5) {
    //         fileIndex = index;
    //       } else {
    //         fileIndex = index - (index ~/ 6); // Ad ke index ko minus kar diya taaki list sahi chale
    //       }
    //
    //       final file = _pdfFiles[fileIndex];

    // 🚨 NAYA LOGIC: Sirf ek Ad dikhega 3rd position par (Index 3 par)
    // Agar files 3 ya usse zyada hain, toh total items me 1 Ad jud jayega.
    int totalItemCount = _pdfFiles.length >= 3 ? _pdfFiles.length + 1 : _pdfFiles.length;

    return RefreshIndicator(
      onRefresh: _loadPdfFiles,
      color: Colors.blueAccent,
      backgroundColor: const Color(0xFF1E1E1E),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 80, top: 10),
        itemCount: totalItemCount,
        itemBuilder: (context, index) {

          // 🚨 Sirf 3rd index par Ad dikhega (Yaani shuru ki 3 files ke thik baad)
          bool isAdIndex = (index == 3);

          if (isAdIndex) {
            return const NativeAdCard(); // Yahan Ad show hoga
          }

          // 🚨 Asli file index nikalna (Kyunki ek ad index 3 pe aa gaya, toh aage ki files minus 1 hongi)
          int fileIndex = index > 3 ? index - 1 : index;

          final file = _pdfFiles[fileIndex];

          final fileStat = file.statSync();
          final dateCategory = _getDateCategory(fileStat.modified);

          // bool showHeader = lastCategory != dateCategory;
          // lastCategory = dateCategory;
          //
          // return Column(
          //   crossAxisAlignment: CrossAxisAlignment.start,
          //   children: [
          //     if (showHeader)
          //       Padding(
          //         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          //         child: Text(
          //           dateCategory,
          //           style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
          //         ),
          //       ),

          bool showHeader = lastCategory != dateCategory;
          bool isFirstHeader = lastCategory == null; // 🚨 MAGIC: Check karega ki kya ye pehla header hai
          lastCategory = dateCategory;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeader)
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, // Text Left me, Icon Right me
                    children: [
                      Text(
                        dateCategory,
                        style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                      ),

                      // 🚨 Sirf pehle (top) header me Sort menu dikhega!
                      if (isFirstHeader)
                        _buildSortMenu(),
                    ],
                  ),
                ),

              // PDF File Card
              GestureDetector(
                // onTap: () {
                //   OpenFile.open(file.path);
                // },
                onTap: () {
                  // 🚨 NAYA LOGIC: Mode ke hisaab se tap handle karo
                  if (_isSelectionMode) {
                    setState(() {
                      if (_selectedFiles.contains(file.path)) {
                        _selectedFiles.remove(file.path);
                      } else {
                        _selectedFiles.add(file.path);
                      }
                    });
                  } else {
                    OpenFile.open(file.path); // Normal tap pe open hogi
                  }
                },
                // 🚨 PRO FEATURE: Kisi bhi file ko Long Press karke direct select mode chalu karo
                onLongPress: () {
                  if (!_isSelectionMode) {
                    HapticFeedback.heavyImpact();
                    setState(() {
                      _isSelectionMode = true;
                      _selectedFiles.add(file.path);
                    });
                  }
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  padding: const EdgeInsets.all(12),
                  //decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
                  decoration: BoxDecoration(
                    color: _selectedFiles.contains(file.path) ? const Color(0xFF2A3A4A) : const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedFiles.contains(file.path) ? Colors.lightBlueAccent.withOpacity(0.5) : Colors.white12,
                    ),
                  ),
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
                        //child: PdfThumbnailView(filePath: file.path),
                        child: PdfThumbnailView(
                          key: ValueKey(file.path),
                          filePath: file.path,
                        ),
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
                            //Row(

                            // 🚨 NAYA: Mode check karke ya toh Checkbox dikhao, ya phir Tools dikhao
                            _isSelectionMode
                                ? Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: Checkbox(
                                    value: _selectedFiles.contains(file.path),
                                    activeColor: Colors.lightBlueAccent,
                                    checkColor: Colors.black,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    side: const BorderSide(color: Colors.white54, width: 1.5),
                                    onChanged: (bool? value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedFiles.add(file.path);
                                        } else {
                                          _selectedFiles.remove(file.path);
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ),
                            )
                                : Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // 🚨 UPDATED FEATURE: Alag function ke sath integrated
                                    () {
                                  final bool isSaved = _savedFilePaths.contains(file.path);
                                  return Tooltip(
                                    message: isSaved ? "Unsave document" : "Save document",
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      // 🚨 MAGIC CALL: Ab direct naya function call ho raha hai
                                      onTap: () => _toggleSaveFile(file.path),
                                      child: Padding(
                                        padding: const EdgeInsets.all(6.0),
                                        child: Icon(
                                          isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                          color: isSaved ? Colors.lightBlueAccent : Colors.white70,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  );
                                }(),
                                const SizedBox(width: 16), // Beech ka safe gap
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

  // 🚨 UPGRADED FUNCTION: Professional Sort Menu (With Ascending/Descending Toggle)
  Widget _buildSortMenu() {
    return PopupMenuButton<String>(
      color: const Color(0xFF2C2C2C), // Dark theme
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      offset: const Offset(0, 40),
      constraints: const BoxConstraints(
        maxWidth: 180, // Isko 160 rakha hai, Arrow aur Text dono perfectly fit aayenge
      ),
      // 🚨 MAGIC FIX: Padding laga di taaki click area bada ho jaye
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Left/Right 12px aur Top/Bottom 8px extra click area
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort_rounded, color: Colors.lightBlueAccent, size: 18),
            SizedBox(width: 4),
            Text("Sort", style: TextStyle(color: Colors.lightBlueAccent, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      onSelected: (String value) {
        setState(() {
          if (_sortBy == value) {
            // 🚨 MAGIC 1: Agar same option dubara click kiya, toh direction ulta (toggle) kar do
            _isAscending = !_isAscending;
          } else {
            // 🚨 MAGIC 2: Agar naya option click kiya, toh default direction set karo
            _sortBy = value;
            if (value == 'Name') {
              _isAscending = true; // Name A-Z se start achha lagta hai
            } else {
              _isAscending = false; // Date/Size bado/naye se shuru achha lagta hai
            }
          }
          _isLoadingFiles = true;
        });

        _loadPdfFiles(); // List refresh karo

        String orderText = _isAscending ? "Ascending" : "Descending";
        showToast("Sorted by $_sortBy ($orderText)");
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        _buildSortMenuItem('Date', Icons.calendar_today_rounded),
        const PopupMenuDivider(height: 1),
        _buildSortMenuItem('Name', Icons.sort_by_alpha_rounded),
        const PopupMenuDivider(height: 1),
        _buildSortMenuItem('Size', Icons.data_usage_rounded),
      ],
    );
  }

  // 🚨 UPGRADED WIDGET: Sort Menu me Arrows dikhane ke liye
  PopupMenuItem<String> _buildSortMenuItem(String value, IconData icon) {
    final bool isSelected = _sortBy == value; // Pata chalega ki current konsa active hai

    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: isSelected ? Colors.lightBlueAccent : Colors.white70, size: 20),
          const SizedBox(width: 12),
          Expanded( // Text ko failayega taaki arrow ekdum right me jaye
            child: Text(
              value,
              style: TextStyle(
                color: isSelected ? Colors.lightBlueAccent : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),

          // 🚨 ARROW LOGIC: Agar yeh item active (selected) hai, tabhi right side me arrow dikhega
          if (isSelected)
            Icon(
              _isAscending ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: Colors.lightBlueAccent,
              size: 20, // Same size ka icon
            ),
        ],
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

                      // 🚨 NAYA FEATURE: Dynamic Save / Unsave Option
                          () {
                        final bool isSaved = _savedFilePaths.contains(file.path);
                        return ListTile(
                          leading: Icon(
                            isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            color: isSaved ? Colors.lightBlueAccent : Colors.white,
                            size: 22,
                          ),
                          title: Text(
                            isSaved ? 'Remove from saved' : 'Save document',
                            style: TextStyle(
                              color: isSaved ? Colors.lightBlueAccent : Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context); // Pehle bottom sheet band karo
                            _toggleSaveFile(file.path); // Fir save/unsave ka function chalao
                          },
                        );
                      }(),

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
                        onTap: () async {
                          Navigator.pop(context);
                          //showToast("Delete clicked");
                          // 2. 🚨 Tumhara apna Global Custom Dialog Call!
                          bool shouldDelete = await showCustomConfirmDialog(
                            context,
                            title: "Delete Document",
                            message: "Are you sure you want to permanently delete \"${file.path.split('/').last}\"? This action cannot be undone.",
                            positiveBtnText: "Delete",
                            negativeBtnText: "Cancel",
                            positiveBtnColor: Colors.redAccent, // Danger actions ke liye Lal rang
                          );

                          // 3. Agar user ne tumhare dialog me 'Delete' (true) press kiya hai
                          if (shouldDelete) {
                            await _deletePdfFile(file); // 🚨 File delete kar do aur list refresh karo
                          }
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

  // 🚨 NAYA FUNCTION: Bulk Selection Mode ka Bottom Bar
  Widget _buildSelectionBottomBar({Key? key}) {
    return BottomAppBar(
      key: key,
      color: const Color(0xFF1E1E1E), // Dark Premium Background
      padding: EdgeInsets.zero,
      height: 70, // Thoda sleek rakha hai
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildToolIcon(Icons.share_outlined, "Share", Colors.white, () {
            // TODO: Bulk Share function
            //showToast("Share ${_selectedFiles.length} files");
            _shareSelectedFiles();
          }),
          _buildToolIcon(Icons.bookmark_border_rounded, "Tag", Colors.white, () {
            // TODO: Bulk Save/Tag function
            //showToast("Tag ${_selectedFiles.length} files");
            _bulkToggleSaveFiles();
          }),
          _buildToolIcon(Icons.merge_type_rounded, "Merge", Colors.white, () {
            // TODO: Merge function
            //showToast("Merge ${_selectedFiles.length} files");
            _mergeSelectedFiles();
          }),
          _buildToolIcon(Icons.delete_outline, "Delete", Colors.redAccent, () {
            // TODO: Bulk Delete function
            //showToast("Delete ${_selectedFiles.length} files");
            _confirmBulkDelete();
          }),
        ],
      ),
    );
  }

  // 🚨 NAYA FUNCTION: Syncfusion Flutter PDF Merge (100% Bug-Free Dart Logic)
  Future<void> _mergeSelectedFiles() async {
    if (_selectedFiles.length < 2) {
      showToast("Please select at least 2 files to merge");
      return;
    }

    // 1. SCREEN PAR LOADING DIALOG DIKHAO
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Row(
            children: [
              CircularProgressIndicator(color: Colors.lightBlueAccent),
              SizedBox(width: 20),
              Text(
                "Merging PDFs... Please wait",
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
    );

    try {
      // Order maintain rakhte hue file paths lena
      List<String> filesToMerge = _selectedFiles.toList();
      String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      String newFileName = "Merged_PDF_$timestamp.pdf";

      String outputDirectory = filesToMerge.first.substring(0, filesToMerge.first.lastIndexOf('/'));
      String finalOutputPath = "$outputDirectory/$newFileName";

      // 🚨 2. SYNCFUSION MERGE LOGIC
      // 🚨 2. SYNCFUSION MERGE LOGIC (Prefix ke sath)
      // Jahan jahan Pdf tha, wahan syncfusion.Pdf kar diya hai
      syncfusion.PdfDocument newDocument = syncfusion.PdfDocument();

      for (String filePath in filesToMerge) {
        final Uint8List bytes = await File(filePath).readAsBytes();

        // Syncfusion wala document
        syncfusion.PdfDocument loadedDocument = syncfusion.PdfDocument(inputBytes: bytes);

        for (int i = 0; i < loadedDocument.pages.count; i++) {
          syncfusion.PdfPage loadedPage = loadedDocument.pages[i];
          syncfusion.PdfTemplate template = loadedPage.createTemplate();

          syncfusion.PdfSection section = newDocument.sections!.add();
          section.pageSettings.size = template.size;
          section.pageSettings.margins.all = 0;

          syncfusion.PdfPage newPage = section.pages.add();
          newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
        }
        loadedDocument.dispose();
      }

      // 3. FINAL FILE DISK PAR SAVE KARO
      final List<int> mergedBytes = await newDocument.save();
      newDocument.dispose();

      File finalFile = File(finalOutputPath);
      await finalFile.writeAsBytes(mergedBytes, flush: true);
      // 4. LOADING DIALOG BAND KARO
      Navigator.pop(context);

      showToast("PDF Merged Successfully!");

      // UI Reset aur list update
      setState(() {
        _isSelectionMode = false;
        _selectedFiles.clear();
      });

      _loadPdfFiles();

    } catch (e) {
      Navigator.pop(context);
      print("Syncfusion Merge Error: $e");
      showToast("Something went wrong while merging");
    }
  }

  // 🚨 HELPER WIDGET: Tool buttons ko sundar dikhane ke liye
  Widget _buildToolIcon(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
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

  // 🚨 NAYA FUNCTION: Bulk Tag (Save/Unsave) Logic
  Future<void> _bulkToggleSaveFiles() async {
    if (_selectedFiles.isEmpty) return;

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      // SMART LOGIC: Check karo ki kya saari selected files pehle se hi saved hain?
      bool areAllSaved = _selectedFiles.every((path) => _savedFilePaths.contains(path));

      setState(() {
        if (areAllSaved) {
          // Agar saari pehle se saved hain, toh sabko Unsave (remove) kar do
          for (String path in _selectedFiles) {
            _savedFilePaths.remove(path);
          }
          showToast("${_selectedFiles.length} files removed from saved");
        } else {
          // Agar kuch unsaved hain, toh sabko Save (add) kar do
          for (String path in _selectedFiles) {
            if (!_savedFilePaths.contains(path)) {
              _savedFilePaths.add(path);
            }
          }
          showToast("${_selectedFiles.length} files added to saved");
        }

        // Action hone ke baad Selection Mode ko OFF kar do
        _isSelectionMode = false;
        _selectedFiles.clear();
      });

      // 🚨 Permanent Persistence: Disk par nayi list save kar do
      await prefs.setStringList('saved_pdf_paths', _savedFilePaths);

    } catch (e) {
      print("Bulk Tag Error: $e");
      showToast("Error updating tags");
    }
  }

  // 🚨 NAYA FUNCTION: Bulk Delete Confirmation & Execution
  // 🚨 NAYA FUNCTION: Bulk Delete Confirmation (Custom Dialog ke sath)
  Future<void> _confirmBulkDelete() async {
    if (_selectedFiles.isEmpty) {
      showToast("Please select files to delete");
      return;
    }

    // Tumhara apna Custom Dialog reuse kiya!
    bool shouldDelete = await showCustomConfirmDialog(
      context,
      title: "Delete Files",
      message: "Are you sure you want to permanently delete ${_selectedFiles.length} selected files? This action cannot be undone.",
      positiveBtnText: "Delete",
      negativeBtnText: "Cancel",
      positiveBtnColor: Colors.redAccent, // Danger action
    );

    // Agar user ne 'Delete' dabaya hai, tabhi asli delete logic chalega
    if (shouldDelete) {
      await _executeBulkDelete();
    }
  }

  // 🚨 ASLI DELETE LOGIC: Jo storage se files udhayega
  Future<void> _executeBulkDelete() async {
    try {
      int count = _selectedFiles.length;

      for (String path in _selectedFiles) {
        final file = File(path);
        if (file.existsSync()) {
          file.deleteSync();
        }
        if (_savedFilePaths.contains(path)) {
          _toggleSaveFile(path);
        }
      }

      showToast("$count files deleted");

      setState(() {
        _isSelectionMode = false;
        _selectedFiles.clear();
      });

      _loadPdfFiles();

    } catch (e) {
      print("Bulk Delete Error: $e");
      showToast("Error deleting some files");
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

  // 🚨 NAYA FUNCTION: Ek saath bahut saari files Share karne ke liye
  Future<void> _shareSelectedFiles() async {
    // Safety check: Agar galti se 0 files par click ho jaye
    if (_selectedFiles.isEmpty) {
      showToast("Please select at least one file to share");
      return;
    }

    try {
      showToast("Preparing ${_selectedFiles.length} files...");

      // 1. Saare selected paths ko 'XFile' objects ki list me convert karo
      List<XFile> filesToShare = _selectedFiles.map((path) => XFile(path)).toList();

      // 2. Tumhara purana share logic (Multiple files ke sath)
      // Note: Tumhare purane function ka ShareParams wala syntax use kar raha hoon
      await SharePlus.instance.share(
        ShareParams(
          files: filesToShare, // 🚨 MAGIC: Yahan ab ek file ki jagah poori list pass ho gayi!
          text: 'Documents shared from PDF Scanner Pro',
        ),
      );

      // (Optional) Agar tum chahte ho ki share hone ke baad Select Mode apne aap band ho jaye,
      // toh is line ko uncomment kar dena:
      setState(() { _isSelectionMode = false; _selectedFiles.clear(); });

    } catch (e) {
      print("Bulk Share Error: $e");
      showToast("Error sharing files");
    }
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

  // 🚨 HELPER FUNCTION: Storage se file delete aur list refresh karne ke liye
  // 🚨 NAYA FUNCTION: Scoped Storage ko bypass karke file delete karna
  Future<void> _deletePdfFile(File file) async {
    try {
      if (await file.exists()) {

        // 1. Storage Permission Double Check (Zaroori hai Scoped Storage me)
        if (await Permission.manageExternalStorage.isDenied) {
          await Permission.manageExternalStorage.request();
        }

        // 2. Android ka naya "File.writeAsBytesSync([])" hack
        // Direct .delete() kabhi-kabhi crash/ignore ho jata hai Android 13/14 me.
        // Isliye pehle file ko khali (0 bytes) karte hain, fir delete marte hain.
        try {
          file.writeAsBytesSync([]); // File data mitao pehle
        } catch (_) {
          // Agar permission issue aaya yahan, to pakka system block kar raha hai
        }

        // 3. Final Delete Call
        await file.delete();

        // 4. List turant update hogi
        await _loadPdfFiles();

        showToast("File deleted successfully");
      } else {
        showToast("File already deleted or not found");
      }
    } catch (e) {
      print("Delete Error: $e");

      // Agar catch me aata hai, matlab Android 11+ ne block kiya hai.
      // Iska sabse aasaan fix user ko File Manager se delete karne bolna hai,
      // Ya MediaStore API (Jo complex hai) use karna. Par 99% time upar wala hack kaam kar jayega.
      showToast("Error: Permission denied by Android System.");
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

// 🚨 NAYA CLASS: Professional Search Feature ke liye
class PdfSearchDelegate extends SearchDelegate {
  final List<File> pdfFiles;

  PdfSearchDelegate(this.pdfFiles);

  // 1. Search Bar ka Theme (Tumhare Dark Theme se match karne ke liye)
  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData.dark().copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E), // Dark Premium Header
        elevation: 0,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212), // Dark Background
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none, // Clean search text area
        hintStyle: TextStyle(color: Colors.white54),
      ),
    );
  }

  // 2. Right side me 'Clear (X)' button
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear, color: Colors.white70),
          onPressed: () {
            query = ''; // Text clear karega
          },
        )
    ];
  }

  // 3. Left side me 'Back' button
  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.white70),
      onPressed: () => close(context, null), // Search close karega
    );
  }

  // 4. Asli Search Logic aur Results Dikhana
  @override
  Widget buildResults(BuildContext context) => _buildSearchResults();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults();

  Widget _buildSearchResults() {
    final lowercaseQuery = query.toLowerCase();

    // 1. Pehle saari files filter karo jisme search letter kahin bhi ho
    final results = pdfFiles.where((file) {
      final fileName = file.path.split('/').last.toLowerCase();
      return fileName.contains(lowercaseQuery);
    }).toList();

    // 2. 🚨 MAGIC LOGIC: Relevance Sorting
    if (lowercaseQuery.isNotEmpty) {
      results.sort((a, b) {
        final nameA = a.path.split('/').last.toLowerCase();
        final nameB = b.path.split('/').last.toLowerCase();

        final startsWithA = nameA.startsWith(lowercaseQuery);
        final startsWithB = nameB.startsWith(lowercaseQuery);

        if (startsWithA && !startsWithB) {
          return -1; // Agar 'a' match word se shuru hota hai, toh usko UP (top) push karo
        } else if (!startsWithA && startsWithB) {
          return 1;  // Agar 'b' shuru hota hai, toh usko UP push karo
        } else {
          return 0;  // Agar dono same hain, toh default order (Date wise) hi rakho
        }
      });
    }

    // 3. Agar koi file nahi mili
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, color: Colors.white24, size: 60),
            const SizedBox(height: 12),
            Text("No document found for '$query'", style: const TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      );
    }

    // 4. Sorted Result List dikhao
    return ListView.builder(
      padding: const EdgeInsets.only(top: 10),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final file = results[index];
        final fileName = file.path.split('/').last;

        return ListTile(
          leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 30),
          title: Text(
            fileName,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            DateFormat('dd MMM yyyy').format(file.statSync().modified),
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          onTap: () {
            // Click karne par file open ho jayegi
            OpenFile.open(file.path);
          },
        );
      },
    );
  }
}
