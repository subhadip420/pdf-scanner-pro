import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' hide PdfDocument;
import 'package:pdf_scanner_pro/screens/pdf_compress_screen.dart';
import 'package:pdf_scanner_pro/screens/scanner_screen.dart';
import 'package:pdf_scanner_pro/screens/settings_screen.dart';
import 'package:pdfx/pdfx.dart';
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_storage/shared_storage.dart' as saf;
import 'custom_dialog.dart';
import 'custom_gallery_screen.dart'; // Apni gallery wali screen
import 'document_editor_screen.dart'; // Apna editor
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; // 0 for Home, 1 for Files
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  List<File> _pdfFiles = [];
  bool _isLoadingFiles = true;
  bool _isFabMenuOpen = false;
  List<String> _savedFilePaths = [];
  String _sortBy = 'Date';
  bool _isAscending = false;
  bool _isSelectionMode = false;
  Set<String> _selectedFiles = {};
  List<File> _allDevicePdfFiles = [];
  bool _isLoadingDeviceFiles = true;
  RewardedAd? _rewardedAd;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _loadPdfFiles();
    _loadSavedFiles();
    _loadAllDevicePdfFiles();
    _loadRewardedAd();
  }

  // Load Banner Ad
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      // TODO Test Banner ID
      //adUnitId: 'ca-app-pub-3940256099942544/6300978111', // test id
      adUnitId: 'ca-app-pub-5454466291921987/4849035367', // real id
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

  void _loadRewardedAd() {
    RewardedAd.load(
      //adUnitId: 'ca-app-pub-3940256099942544/5224354917', //test id
      adUnitId: 'ca-app-pub-5454466291921987/5787187877', //real id
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          print('Rewarded ad loaded successfully.');
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('Rewarded ad failed to load: $error');
          _rewardedAd = null;
        },
      ),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  List<File> get _getAllKnownFiles {
    final Set<String> uniquePaths = {};
    final List<File> combinedList = [];

    for (var f in _pdfFiles) {
      if (uniquePaths.add(f.path)) {
        combinedList.add(f);
      }
    }
    for (var f in _allDevicePdfFiles) {
      if (uniquePaths.add(f.path)) {
        combinedList.add(f);
      }
    }
    return combinedList;
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

  Future<void> _loadPdfFiles() async {
    try {
      // 🚨 Yahan Permission.manageExternalStorage ki zaroorat nahi hai
      // App ke private folder (safe zone) ka path direct get karo
      final directory = await getApplicationDocumentsDirectory();

      if (await directory.exists()) {
        List<FileSystemEntity> entities = directory.listSync();

        // Sirf PDF files filter karo
        List<File> files = entities
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.pdf'))
            .toList();

        // Sorting logic (Name, Size, Date)
        files.sort((a, b) {
          int result;
          if (_sortBy == 'Name') {
            result = a.path.split('/').last.toLowerCase().compareTo(b.path.split('/').last.toLowerCase());
          } else if (_sortBy == 'Size') {
            result = a.statSync().size.compareTo(b.statSync().size);
          } else {
            result = a.lastModifiedSync().compareTo(b.lastModifiedSync());
          }
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

  Future<void> _loadAllDevicePdfFiles() async {
    setState(() => _isLoadingDeviceFiles = true);
    try {
      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }

      List<String> paths = await compute(searchAllPdfsInBackground, '/storage/emulated/0');

      List<File> allPdfs = paths.map((path) => File(path)).toList();

      allPdfs.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      if (mounted) {
        setState(() {
          _allDevicePdfFiles = allPdfs;
          _isLoadingDeviceFiles = false;
        });
      }
    } catch (e) {
      print("Device PDF Search Error: $e");
      if (mounted) setState(() => _isLoadingDeviceFiles = false);
    }
  }

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
      await prefs.setStringList('saved_pdf_paths', _savedFilePaths);
    } catch (e) {
      print("SharedPreferences Save Error: $e");
      showToast("Error updating save status");
    }
  }

  String _truncateFileName(String name) {
    if (name.length <= 26) return name;

    String extension = name.split('.').last;
    String baseName = name.substring(0, name.lastIndexOf('.'));

    if (baseName.length <= 16) return name;
    return "${baseName.substring(0, 16)}...${baseName.substring(baseName.length - 10)}.$extension";
  }

  String _getFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

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
      if (!mounted) return;
      final List<File>? selectedFiles = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CustomGalleryScreen()),
      );

      if (selectedFiles == null || selectedFiles.isEmpty) return;
      List<Map<String, File>> imagesToEdit = [];
      for (var file in selectedFiles) {
        imagesToEdit.add({'original': file, 'cropped': file});
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DocumentEditorScreen(imageFiles: imagesToEdit, isFromGallery: true)),
      );
    } catch (e) {
      print("Home Screen Gallery Error: $e");
      showToast("Error opening gallery");
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        if (_isSelectionMode) {
          setState(() {
            _isSelectionMode = false;
            _selectedFiles.clear();
          });
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),

        /// 1. APP BAR
        appBar: _isSelectionMode
            ? AppBar(
                backgroundColor: const Color(0xFF1E1E1E),
                leadingWidth: 80,
                leading: TextButton(
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = false;
                      _selectedFiles.clear();
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
                centerTitle: true,
                actions: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_selectedFiles.length == _pdfFiles.length && _pdfFiles.isNotEmpty) {
                          _selectedFiles.clear();
                        } else {
                          _selectedFiles = _pdfFiles.map((file) => file.path).toSet();
                        }
                      });
                    },
                    child: Text(
                      _selectedFiles.length == _pdfFiles.length && _pdfFiles.isNotEmpty ? "Deselect" : "Select All",
                      style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              )
            : AppBar(
                backgroundColor: Color(0xFF1E1E1E),
                title: const Text("PDF Scanner Pro", style: TextStyle(color: Colors.white, fontSize: 18)),
                actions: [
                  Tooltip(
                    message: "Saved documents",
                    child: IconButton(
                      icon: const Icon(Icons.bookmark_rounded, color: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                SavedPdfScreen(allFiles: _getAllKnownFiles, savedPaths: _savedFilePaths),
                          ),
                        ).then((_) {
                          setState(() {});
                        });
                      },
                    ),
                  ),

                  Tooltip(
                    message: "Search documents",
                    child: IconButton(
                      icon: const Icon(Icons.search, color: Colors.white),
                      onPressed: () {
                        showSearch(context: context, delegate: PdfSearchDelegate(_getAllKnownFiles));
                      },
                    ),
                  ),
                  _buildMainAppBarMenu(),
                ],
              ),

        body: Stack(
          children: [
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
                    children: [_buildHomeTabContent(), _buildFilesTabContent()],
                  ),
                ),
              ],
            ),

            if (_isFabMenuOpen)
              GestureDetector(
                onTap: () {
                  setState(() => _isFabMenuOpen = false);
                },
                child: Container(
                  color: Colors.black.withOpacity(0.85),
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),

            if (_isFabMenuOpen)
              Positioned(
                bottom: 90,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMenuPill("Create from photos", Icons.photo_library_outlined, () {
                      showToast("Gallery opening...");
                      setState(() => _isFabMenuOpen = false);
                      _openGalleryForPdf();
                    }),
                    const SizedBox(height: 12),
                    _buildMenuPill("Create scan", Icons.add_a_photo_outlined, () {
                      setState(() => _isFabMenuOpen = false);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ScannerScreen(isOpenedFromEditor: false)),
                      );
                    }),
                  ],
                ),
              ),
          ],
        ),

        floatingActionButton: _isSelectionMode
            ? null
            : FloatingActionButton(
                onPressed: () {
                  setState(() {
                    _isFabMenuOpen = !_isFabMenuOpen;
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

        floatingActionButtonLocation: _isFabMenuOpen
            ? FloatingActionButtonLocation.centerFloat
            : FloatingActionButtonLocation.centerDocked,

        /// BOTTOM TAB BAR (Flicker-Free Smooth Slide-Up Animation)
        bottomNavigationBar: SizedBox(
          height: 70,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
              return Stack(
                alignment: Alignment.bottomCenter,
                children: <Widget>[...previousChildren, if (currentChild != null) currentChild],
              );
            },
            transitionBuilder: (Widget child, Animation<double> animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 1.2),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCirc)),
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
                          padding: EdgeInsets.zero,
                          child: SizedBox(
                            height: 70,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                /// HOME OPTION
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
                                        mainAxisSize: MainAxisSize.min,
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

                                const SizedBox(width: 40),

                                /// FILES OPTION
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

  // Files Tab Content (Poore phone ka PDF list)
  Widget _buildFilesTabContent() {
    if (_isLoadingDeviceFiles) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.lightBlueAccent),
            SizedBox(height: 16),
            Text("Scanning device for PDFs...", style: TextStyle(color: Colors.white54, fontSize: 15)),
          ],
        ),
      );
    }

    if (_allDevicePdfFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_open_rounded, color: Colors.white24, size: 80),
            const SizedBox(height: 16),
            const Text("No PDF files found on device.", style: TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllDevicePdfFiles,
      color: Colors.blueAccent,
      backgroundColor: const Color(0xFF1E1E1E),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 100, top: 10),
        itemCount: _allDevicePdfFiles.length,
        itemBuilder: (context, index) {
          final file = _allDevicePdfFiles[index];
          final fileStat = file.statSync();

          return GestureDetector(
            onTap: () {
              if (_isSelectionMode) {
                setState(() {
                  if (_selectedFiles.contains(file.path)) {
                    _selectedFiles.remove(file.path);
                  } else {
                    _selectedFiles.add(file.path);
                  }
                });
              } else {
                OpenFile.open(file.path);
              }
            },
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
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              padding: const EdgeInsets.only(left: 8, top: 8, right: 12, bottom: 8),
              decoration: BoxDecoration(
                color: _selectedFiles.contains(file.path) ? const Color(0xFF2A3A4A) : const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedFiles.contains(file.path) ? Colors.lightBlueAccent.withOpacity(0.5) : Colors.white12,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 70,
                    height: 95,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white12),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: PdfThumbnailView(key: ValueKey(file.path), filePath: file.path),
                  ),
                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _truncateFileName(file.path.split('/').last),
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                          maxLines: 1,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          DateFormat('MM/dd/yy  •  hh:mm a').format(fileStat.modified),
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(_getFileSize(fileStat.size), style: const TextStyle(color: Colors.white54, fontSize: 13)),
                        const SizedBox(height: 8),

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
                                  () {
                                    final bool isSaved = _savedFilePaths.contains(file.path);
                                    return Tooltip(
                                      message: isSaved ? "Unsave document" : "Save document",
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
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
                                  const SizedBox(width: 16),
                                  Tooltip(
                                    message: "Share",
                                    child: InkWell(
                                      onTap: () => _sharePdfFile(file),
                                      child: const Icon(Icons.share_outlined, color: Colors.white70, size: 22),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
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
          );
        },
      ),
    );
  }

  Widget _buildMainAppBarMenu() {
    return PopupMenuButton<String>(
      color: const Color(0xFF2C2C2C),
      surfaceTintColor: Colors.transparent,
      icon: const Icon(Icons.more_vert, color: Colors.white),
      tooltip: "More options",
      offset: const Offset(0, 45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      constraints: const BoxConstraints(maxWidth: 180),

      onSelected: (String value) {
        if (value == 'Select Files') {
          setState(() {
            _isSelectionMode = true;
            _selectedFiles.clear();
          });
        } else if (value == 'Settings') {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
        }
      },

      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'Select Files',
          child: Row(
            children: [
              Icon(Icons.checklist_rounded, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Select Files', style: TextStyle(color: Colors.white, fontSize: 15)),
            ],
          ),
        ),
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
      ],
    );
  }

  Widget _buildMenuPill(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
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

  Widget _buildHomeTabContent() {
    if (_isLoadingFiles) {
      return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
    }

    if (_pdfFiles.isEmpty) {
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

    String? lastCategory;
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
          bool isAdIndex = (index == 3);

          if (isAdIndex) {
            return const NativeAdCard();
          }
          int fileIndex = index > 3 ? index - 1 : index;

          final file = _pdfFiles[fileIndex];
          final fileStat = file.statSync();
          final dateCategory = _getDateCategory(fileStat.modified);

          bool showHeader = lastCategory != dateCategory;
          bool isFirstHeader = lastCategory == null;
          lastCategory = dateCategory;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeader)
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dateCategory,
                        style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                      ),

                      if (isFirstHeader) _buildSortMenu(),
                    ],
                  ),
                ),

              // PDF File Card
              GestureDetector(
                onTap: () {
                  if (_isSelectionMode) {
                    setState(() {
                      if (_selectedFiles.contains(file.path)) {
                        _selectedFiles.remove(file.path);
                      } else {
                        _selectedFiles.add(file.path);
                      }
                    });
                  } else {
                    OpenFile.open(file.path);
                  }
                },
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
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),

                  padding: const EdgeInsets.only(left: 8, top: 8, right: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: _selectedFiles.contains(file.path) ? const Color(0xFF2A3A4A) : const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedFiles.contains(file.path)
                          ? Colors.lightBlueAccent.withOpacity(0.5)
                          : Colors.white12,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 70,
                        height: 95,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white12),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: PdfThumbnailView(key: ValueKey(file.path), filePath: file.path),
                      ),
                      const SizedBox(width: 16),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _truncateFileName(file.path.split('/').last),
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
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
                                      () {
                                        final bool isSaved = _savedFilePaths.contains(file.path);
                                        return Tooltip(
                                          message: isSaved ? "Unsave document" : "Save document",
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(20),
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
                                      const SizedBox(width: 16),
                                      Tooltip(
                                        message: "Download to Phone",
                                        child: InkWell(
                                          onTap: () => savePdfToDownloads(file, context),
                                          child: const Icon(Icons.download_rounded, color: Colors.white70, size: 22),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Tooltip(
                                        message: "Share",
                                        child: InkWell(
                                          onTap: () => _sharePdfFile(file),
                                          child: const Icon(Icons.share_outlined, color: Colors.white70, size: 22),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
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

  Widget _buildSortMenu() {
    return PopupMenuButton<String>(
      color: const Color(0xFF2C2C2C),
      // Dark theme
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      offset: const Offset(0, 40),
      constraints: const BoxConstraints(maxWidth: 180),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort_rounded, color: Colors.lightBlueAccent, size: 18),
            SizedBox(width: 4),
            Text(
              "Sort",
              style: TextStyle(color: Colors.lightBlueAccent, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      onSelected: (String value) {
        setState(() {
          if (_sortBy == value) {
            _isAscending = !_isAscending;
          } else {
            _sortBy = value;
            if (value == 'Name') {
              _isAscending = true;
            } else {
              _isAscending = false;
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

  PopupMenuItem<String> _buildSortMenuItem(String value, IconData icon) {
    final bool isSelected = _sortBy == value;

    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: isSelected ? Colors.lightBlueAccent : Colors.white70, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isSelected ? Colors.lightBlueAccent : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),

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

  void _showFileOptionsBottomSheet(BuildContext context, File file) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      elevation: 10,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
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

              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -1),
                        leading: const Icon(Icons.info_outline, color: Colors.white, size: 20),
                        title: const Text('Details', style: TextStyle(color: Colors.white, fontSize: 15)),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _showPdfDetails(context, file);
                        },
                      ),
                      ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -1),
                        leading: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
                        title: const Text('Share', style: TextStyle(color: Colors.white, fontSize: 15)),
                        onTap: () {
                          Navigator.pop(sheetContext); // 🚨 sheetContext use kiya
                          _sharePdfFile(file);
                        },
                      ),
                      ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -1),
                        leading: const Icon(Icons.file_copy_outlined, color: Colors.white, size: 20),
                        title: const Text('Copy', style: TextStyle(color: Colors.white, fontSize: 15)),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _copyPdfFile(file);
                        },
                      ),

                      ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -1),
                        leading: const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                        title: const Text('Download to Phone', style: TextStyle(color: Colors.white, fontSize: 15)),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          savePdfToDownloads(file, context);
                        },
                      ),

                      ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -1),
                        leading: const Icon(Icons.edit_document, color: Colors.white, size: 20),
                        title: const Text('Open in Editor', style: TextStyle(color: Colors.white, fontSize: 15)),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _openInEditor(file);
                        },
                      ),

                      ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -1),
                        leading: const Icon(Icons.image_outlined, color: Colors.white, size: 20),
                        title: const Text('Save pages as JPEG', style: TextStyle(color: Colors.white, fontSize: 15)),
                        onTap: () {
                          Navigator.pop(sheetContext); // Bottom sheet close ho jayegi
                          // 🚨 Main screen ka zinda 'context' pass kiya
                          _showSavePagesAsJpegConfirmDialog(context, file);
                        },
                      ),

                      ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -1),
                        leading: const Icon(Icons.compress_rounded, color: Colors.white, size: 20),
                        title: const Text('Compress PDF', style: TextStyle(color: Colors.white, fontSize: 15)),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => PdfCompressScreen(pdfFile: file)),
                          );
                        },
                      ),

                      // ListTile(
                      //   dense: true,
                      //   visualDensity: const VisualDensity(vertical: -3),
                      //   leading: const Icon(Icons.text_snippet_outlined, color: Colors.white, size: 22),
                      //   title: const Text('Convert to Word', style: TextStyle(color: Colors.white, fontSize: 16)),
                      //   onTap: () {
                      //     Navigator.pop(sheetContext); // Bottom sheet band karo
                      //     _showConvertToWordConfirmDialog(context, file); // Naya function call hoga
                      //   },
                      // ),

                      ListTile(
                        leading: const Icon(Icons.text_snippet, color: Colors.white),
                        title: const Text("Extract Text (OCR)", style: TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(context); // Bottom sheet ko pehle band karo
                          _processAndShowExtractedText(context, file); // Naya logic start
                        },
                      ),

                      ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -1),
                        leading: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
                        title: const Text('Rename', style: TextStyle(color: Colors.white, fontSize: 15)),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _renamePdfFile(context, file);
                        },
                      ),
                      () {
                        final bool isSaved = _savedFilePaths.contains(file.path);
                        return ListTile(
                          dense: true,
                          visualDensity: const VisualDensity(vertical: -1),
                          leading: Icon(
                            isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            color: isSaved ? Colors.lightBlueAccent : Colors.white,
                            size: 20,
                          ),
                          title: Text(
                            isSaved ? 'Remove from saved' : 'Save document',
                            style: TextStyle(color: isSaved ? Colors.lightBlueAccent : Colors.white, fontSize: 15),
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _toggleSaveFile(file.path);
                          },
                        );
                      }(),
                      ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -1),
                        leading: const Icon(Icons.print_outlined, color: Colors.white, size: 20),
                        title: const Text('Print', style: TextStyle(color: Colors.white, fontSize: 15)),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _printPdfFile(file);
                        },
                      ),
                      const Divider(color: Colors.white12, height: 16),
                      ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -1),
                        leading: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        title: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.redAccent, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          bool shouldDelete = await showCustomConfirmDialog(
                            context,
                            title: "Delete Document",
                            message:
                                "Are you sure you want to permanently delete \"${file.path.split('/').last}\"? This action cannot be undone.",
                            positiveBtnText: "Delete",
                            negativeBtnText: "Cancel",
                            positiveBtnColor: Colors.redAccent,
                          );
                          if (shouldDelete) {
                            await _deletePdfFile(file);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
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

  Widget _buildSelectionBottomBar({Key? key}) {
    return BottomAppBar(
      key: key,
      color: const Color(0xFF1E1E1E),
      padding: EdgeInsets.zero,
      height: 70,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildToolIcon(Icons.share_outlined, "Share", Colors.white, () {
            _shareSelectedFiles();
          }),
          _buildToolIcon(Icons.bookmark_border_rounded, "Tag", Colors.white, () {
            _bulkToggleSaveFiles();
          }),
          _buildToolIcon(Icons.merge_type_rounded, "Merge", Colors.white, () {
            _mergeSelectedFiles();
          }),
          _buildToolIcon(Icons.delete_outline, "Delete", Colors.redAccent, () {
            _confirmBulkDelete();
          }),
        ],
      ),
    );
  }

  // Future<void> _mergeSelectedFiles() async {
  //   if (_selectedFiles.length < 2) {
  //     showToast("Please select at least 2 files to merge");
  //     return;
  //   }
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         backgroundColor: const Color(0xFF2C2C2C),
  //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //         content: const Row(
  //           children: [
  //             CircularProgressIndicator(color: Colors.lightBlueAccent),
  //             SizedBox(width: 20),
  //             Text(
  //               "Merging PDFs... Please wait",
  //               style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
  //             ),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  //
  //   try {
  //     List<String> filesToMerge = _selectedFiles.toList();
  //     String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  //     String newFileName = "Merged_PDF_$timestamp.pdf";
  //     String outputDirectory = filesToMerge.first.substring(0, filesToMerge.first.lastIndexOf('/'));
  //     String finalOutputPath = "$outputDirectory/$newFileName";
  //     syncfusion.PdfDocument newDocument = syncfusion.PdfDocument();
  //
  //     for (String filePath in filesToMerge) {
  //       final Uint8List bytes = await File(filePath).readAsBytes();
  //
  //       syncfusion.PdfDocument loadedDocument = syncfusion.PdfDocument(inputBytes: bytes);
  //
  //       for (int i = 0; i < loadedDocument.pages.count; i++) {
  //         syncfusion.PdfPage loadedPage = loadedDocument.pages[i];
  //         syncfusion.PdfTemplate template = loadedPage.createTemplate();
  //
  //         syncfusion.PdfSection section = newDocument.sections!.add();
  //         section.pageSettings.size = template.size;
  //         section.pageSettings.margins.all = 0;
  //
  //         syncfusion.PdfPage newPage = section.pages.add();
  //         newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
  //       }
  //       loadedDocument.dispose();
  //     }
  //
  //     final List<int> mergedBytes = await newDocument.save();
  //     newDocument.dispose();
  //     File finalFile = File(finalOutputPath);
  //     await finalFile.writeAsBytes(mergedBytes, flush: true);
  //     Navigator.pop(context);
  //     showToast("PDF Merged Successfully!");
  //     setState(() {
  //       _isSelectionMode = false;
  //       _selectedFiles.clear();
  //     });
  //     _loadPdfFiles();
  //   } catch (e) {
  //     Navigator.pop(context);
  //     print("Syncfusion Merge Error: $e");
  //     showToast("Something went wrong while merging");
  //   }
  // }

  Future<void> _mergeSelectedFiles() async {
    if (_selectedFiles.length < 2) {
      showToast("Please select at least 2 files to merge");
      return;
    }

    // Tumhara original merge logic ek function ke andar taaki code duplicate na ho
    Future<void> performMerge() async {
      try {
        List<String> filesToMerge = _selectedFiles.toList();
        String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        String newFileName = "Merged_PDF_$timestamp.pdf";
        String outputDirectory = filesToMerge.first.substring(0, filesToMerge.first.lastIndexOf('/'));
        String finalOutputPath = "$outputDirectory/$newFileName";
        syncfusion.PdfDocument newDocument = syncfusion.PdfDocument();

        for (String filePath in filesToMerge) {
          final Uint8List bytes = await File(filePath).readAsBytes();

          syncfusion.PdfDocument loadedDocument = syncfusion.PdfDocument(inputBytes: bytes);

          // for (int i = 0; i < loadedDocument.pages.count; i++) {
          //   syncfusion.PdfPage loadedPage = loadedDocument.pages[i];
          //   syncfusion.PdfTemplate template = loadedPage.createTemplate();
          //
          //   syncfusion.PdfSection section = newDocument.sections!.add();
          //   section.pageSettings.size = template.size;
          //   section.pageSettings.margins.all = 0;
          //
          //   syncfusion.PdfPage newPage = section.pages.add();
          //   newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
          // }
          for (int i = 0; i < loadedDocument.pages.count; i++) {
            syncfusion.PdfPage loadedPage = loadedDocument.pages[i];

            // 1. Original page ka ekdum sateek size aur rotation nikaalo
            Size pageSize = loadedPage.size;
            syncfusion.PdfTemplate template = loadedPage.createTemplate();

            syncfusion.PdfSection section = newDocument.sections!.add();

            // 🌟 FIX 1: Orientation dynamically set karo! (Sabse zaroori)
            // Agar width height se zyada hai, toh page ko Landscape mode mein rakho
            section.pageSettings.orientation = (pageSize.width > pageSize.height)
                ? syncfusion.PdfPageOrientation.landscape
                : syncfusion.PdfPageOrientation.portrait;

            // 🌟 FIX 2: Original page ka Size aur Rotation angle same to same copy karo
            section.pageSettings.size = pageSize;
            section.pageSettings.margins.all = 0;
            section.pageSettings.rotate = loadedPage.rotation;

            syncfusion.PdfPage newPage = section.pages.add();

            // 3. Template draw karo original size ke sath
            newPage.graphics.drawPdfTemplate(template, const Offset(0, 0), pageSize);
          }
          loadedDocument.dispose();
        }

        final List<int> mergedBytes = await newDocument.save();
        newDocument.dispose();
        File finalFile = File(finalOutputPath);
        await finalFile.writeAsBytes(mergedBytes, flush: true);

        Navigator.pop(context); // Merge complete hone par dialog hide karega
        showToast("PDF Merged Successfully!");
        setState(() {
          _isSelectionMode = false;
          _selectedFiles.clear();
        });
        _loadPdfFiles();
      } catch (e) {
        Navigator.pop(context); // Error aane par bhi dialog hide karega
        print("Syncfusion Merge Error: $e");
        showToast("Something went wrong while merging");
      }
    }

    // 1. Sabse pehle simple loading spinner dikhao
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(
            color: Colors.lightBlueAccent,
          ),
        );
      },
    );

    // 2. Check karo agar Rewarded Ad ready hai
    if (_rewardedAd != null) {
      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          // Reward mil gaya
        },
      );

      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (Ad ad) {
          ad.dispose();
          _rewardedAd = null;
          _loadRewardedAd(); // Ad close hone par next ad load ke liye request (agar function banaya hai to)
          performMerge(); // Ad dekhne ke baad merge shuru karo
        },
        onAdFailedToShowFullScreenContent: (Ad ad, AdError error) {
          ad.dispose();
          _rewardedAd = null;
          _loadRewardedAd();
          performMerge(); // Agar ad load hone ke baad show hone mein fail ho jaye, to bhi user ka kaam rukna nahi chahiye
        },
      );
    } else {
      // 3. Agar ad load nahi hua, to Internet check karo
      bool hasInternet = false;
      try {
        final result = await InternetAddress.lookup('google.com');
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          hasInternet = true;
        }
      } catch (_) {
        hasInternet = false;
      }

      if (!hasInternet) {
        // Internet nahi hai -> Dialog hide karo aur Toast dikhao
        Navigator.pop(context);
        showToast("No internet, try again");
      } else {
        // Internet hai par Ad abhi tak ready nahi hua -> User ko wait mat karao, direct merge kar do
        performMerge();
      }
    }
  }

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
            Text(
              label,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sharePdfFile(File file) async {
    try {
      final xFile = XFile(file.path);
      await SharePlus.instance.share(ShareParams(files: [xFile], text: 'Document shared from PDF Scanner Pro'));
    } catch (e) {
      showToast("Error sharing file");
      print("Share Error: $e");
    }
  }

  Future<void> _bulkToggleSaveFiles() async {
    if (_selectedFiles.isEmpty) return;

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      bool areAllSaved = _selectedFiles.every((path) => _savedFilePaths.contains(path));
      setState(() {
        if (areAllSaved) {
          for (String path in _selectedFiles) {
            _savedFilePaths.remove(path);
          }
          showToast("${_selectedFiles.length} files removed from saved");
        } else {
          for (String path in _selectedFiles) {
            if (!_savedFilePaths.contains(path)) {
              _savedFilePaths.add(path);
            }
          }
          showToast("${_selectedFiles.length} files added to saved");
        }
        _isSelectionMode = false;
        _selectedFiles.clear();
      });
      await prefs.setStringList('saved_pdf_paths', _savedFilePaths);
    } catch (e) {
      print("Bulk Tag Error: $e");
      showToast("Error updating tags");
    }
  }

  Future<void> _confirmBulkDelete() async {
    if (_selectedFiles.isEmpty) {
      showToast("Please select files to delete");
      return;
    }
    bool shouldDelete = await showCustomConfirmDialog(
      context,
      title: "Delete Files",
      message:
          "Are you sure you want to permanently delete ${_selectedFiles.length} selected files? This action cannot be undone.",
      positiveBtnText: "Delete",
      negativeBtnText: "Cancel",
      positiveBtnColor: Colors.redAccent,
    );

    if (shouldDelete) {
      await _executeBulkDelete();
    }
  }

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

  Future<void> _copyPdfFile(File originalFile) async {
    try {
      String originalPath = originalFile.path;

      String dir = originalPath.substring(0, originalPath.lastIndexOf('/'));
      String fileName = originalPath.substring(originalPath.lastIndexOf('/') + 1);
      String baseName = fileName.substring(0, fileName.lastIndexOf('.'));
      String extension = fileName.substring(fileName.lastIndexOf('.'));
      String newPath = '$dir/${baseName}_copy$extension';
      File newFile = File(newPath);

      int counter = 1;
      while (await newFile.exists()) {
        newPath = '$dir/${baseName}_copy($counter)$extension';
        newFile = File(newPath);
        counter++;
      }
      await originalFile.copy(newPath);
      await _loadPdfFiles();
      showToast("File copied successfully");
    } catch (e) {
      print("Copy Error: $e");
      showToast("Error copying file");
    }
  }

  // Tumhari bottom sheet wali class ke andar ye function aayega
  Future<void> _openInEditor(File file) async {
    // 1. Loading Indicator dikhao
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
      },
    );

    try {
      // 2. PDF load karo
      final document = await PdfDocument.openFile(file.path);
      final tempDir = await getTemporaryDirectory();

      // 🚨 NAYA: List of Map banayenge tumhare DocumentEditorScreen ke liye
      List<Map<String, dynamic>> formattedImages = [];

      // 3. Har page ko convert karo
      for (int i = 1; i <= document.pagesCount; i++) {
        final page = await document.getPage(i);

        final pageImage = await page.render(
          width: page.width * 2, // High quality ke liye 2x kiya hai
          height: page.height * 2,
          format: PdfPageImageFormat.jpeg,
        );

        if (pageImage != null) {
          final imagePath = '${tempDir.path}/page_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          final imageFile = File(imagePath);
          await imageFile.writeAsBytes(pageImage.bytes);

          formattedImages.add({
            'original': imageFile,
            'cropped': imageFile,
            'path': imageFile.path,
            'image': imageFile,
            'file': imageFile,
            'originalPath': imageFile.path,
          });
        }
        await page.close();
      }
      await document.close();

      if (!mounted) return;
      Navigator.pop(context);

      if (formattedImages.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DocumentEditorScreen(imageFiles: formattedImages, isFromGallery: true),
          ),
        );
      } else {
        print("Failed to extract images.");
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
      print("Error parsing PDF to images: $e");
    }
  }

  void _renamePdfFile(BuildContext context, File originalFile) {
    String originalPath = originalFile.path;
    String dir = originalPath.substring(0, originalPath.lastIndexOf('/'));
    String fileName = originalPath.substring(originalPath.lastIndexOf('/') + 1);
    String baseName = fileName.substring(0, fileName.lastIndexOf('.'));

    TextEditingController nameController = TextEditingController(text: baseName);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Rename File',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: nameController,
            style: const TextStyle(color: Colors.white),
            autofocus: true,
            decoration: const InputDecoration(
              hintText: "Enter new name",
              hintStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.lightBlueAccent)),
              suffixText: '.pdf',
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

                if (newName.isEmpty) {
                  showToast("Name cannot be empty");
                  return;
                }

                String newPath = '$dir/$newName.pdf';
                File newFile = File(newPath);

                if (newPath == originalPath) {
                  Navigator.pop(context);
                  return;
                }

                if (await newFile.exists()) {
                  showToast("A file with this name already exists");
                  return;
                }

                try {
                  await originalFile.rename(newPath);
                  if (_savedFilePaths.contains(originalPath)) {
                    final SharedPreferences prefs = await SharedPreferences.getInstance();
                    setState(() {
                      _savedFilePaths.remove(originalPath); // Purana path hatao
                      _savedFilePaths.add(newPath); // Naya path daalo
                    });
                    await prefs.setStringList('saved_pdf_paths', _savedFilePaths);
                  }

                  Navigator.pop(context);
                  await _loadPdfFiles();
                  showToast("File renamed successfully");
                } catch (e) {
                  print("Rename Error: $e");
                  showToast("Error renaming file");
                }
              },
              child: const Text(
                'Rename',
                style: TextStyle(color: Colors.lightBlueAccent, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPdfDetails(BuildContext context, File file) {
    final stat = file.statSync();
    final String fileName = file.path.split('/').last;
    final String fileSize = _getFileSize(stat.size);
    final String modifiedDate = DateFormat('dd MMM yyyy, hh:mm a').format(stat.modified);
    final String filePath = file.path;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'File Details',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.lightBlueAccent, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

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

  Future<void> _shareSelectedFiles() async {
    if (_selectedFiles.isEmpty) {
      showToast("Please select at least one file to share");
      return;
    }

    try {
      showToast("Preparing ${_selectedFiles.length} files...");
      List<XFile> filesToShare = _selectedFiles.map((path) => XFile(path)).toList();
      await SharePlus.instance.share(ShareParams(files: filesToShare, text: 'Documents shared from PDF Scanner Pro'));
      setState(() {
        _isSelectionMode = false;
        _selectedFiles.clear();
      });
    } catch (e) {
      print("Bulk Share Error: $e");
      showToast("Error sharing files");
    }
  }

  Future<void> _printPdfFile(File file) async {
    try {
      final String fileName = file.path.split('/').last;

      await Printing.layoutPdf(
        name: fileName,
        onLayout: (PdfPageFormat format) async {
          return await file.readAsBytes();
        },
      );
    } catch (e) {
      print("Print Error: $e");
      showToast("Error printing file");
    }
  }

  Future<void> _deletePdfFile(File file) async {
    try {
      if (await file.exists()) {
        if (await Permission.manageExternalStorage.isDenied) {
          await Permission.manageExternalStorage.request();
        }

        try {
          file.writeAsBytesSync([]);
        } catch (_) {
          print("Warning: Could not overwrite file before deleting. Error: $e");
        }

        await file.delete();
        await _loadPdfFiles();

        showToast("File deleted successfully");
      } else {
        showToast("File already deleted or not found");
      }
    } catch (e) {
      print("Delete Error: $e");
      showToast("Error: Permission denied by Android System.");
    }
  }

  Future<void> _showSavePagesAsJpegConfirmDialog(BuildContext context, File pdfFile) async {
    // 🚨 SharedPreferences aur hardcoded Download path hata diya
    // Ab dialog me user ko saaf batao ki images Phone Gallery me save hongi
    bool isConfirmed = await showCustomConfirmDialog(
      context,
      title: "Save as JPEG",
      message: "Do you want to extract all pages of this PDF as images?\n\nSave Location:\nPhone Gallery (Photos)",
      positiveBtnText: "Confirm",
      negativeBtnText: "Cancel",
      positiveBtnColor: Colors.lightBlueAccent,
    );

    if (isConfirmed) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return const AlertDialog(
            backgroundColor: Color(0xFF2C2C2C),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
            content: Row(
              children: [
                CircularProgressIndicator(color: Colors.lightBlueAccent),
                SizedBox(width: 20),
                Expanded(
                  child: Text(
                    "Extracting pages... Please wait",
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          );
        },
      );

      // 🚨 Naye function signature ke mutabiq sirf `pdfFile` pass karo
      await _savePagesAsJpeg(pdfFile);

      if (context.mounted) {
        Navigator.pop(context); // Loading dialog ko close karne ke liye
      }
    }
  }

  // 1. MAIN FUNCTION: Yeh button click par call hoga aur Ad handle karega
  Future<void> _savePagesAsJpeg(File pdfFile) async {
    // Sirf Android ke liye Interstitial Test Ad ID
    //final String interstitialTestId = 'ca-app-pub-3940256099942544/1033173712'; // test ad id
    final String interstitialTestId = 'ca-app-pub-5454466291921987/6893752966'; //real ad id

    showToast("Preparing file...");

    InterstitialAd.load(
      adUnitId: interstitialTestId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          // Ad successully load ho gaya
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              // Jab user 'X' dabakar ad cut karega -> Save function call karo
              ad.dispose();
              _executeSaveJpeg(pdfFile);
            },
            onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
              // Agar ad screen par aane mein fail ho jaye -> Direct save karo
              print('Ad failed to show: $error');
              ad.dispose();
              _executeSaveJpeg(pdfFile);
            },
          );

          // Ad ko screen par dikhao
          ad.show();
        },
        onAdFailedToLoad: (LoadAdError error) {
          // Agar internet slow hai ya ad load hi nahi hua -> Direct save karo
          print('Interstitial ad failed to load: $error');
          _executeSaveJpeg(pdfFile);
        },
      ),
    );
  }

// 2. SAVE FUNCTION: Yeh function actual mein file save karne ka logic handle karega
  Future<void> _executeSaveJpeg(File pdfFile) async {
    try {
      final directory = await getTemporaryDirectory();
      final String imagesFolderPath = directory.path;

      final document = await PdfDocument.openFile(pdfFile.path);
      int pageCount = document.pagesCount;
      String baseName = pdfFile.path.split('/').last.replaceAll('.pdf', '');

      for (int i = 1; i <= pageCount; i++) {
        final page = await document.getPage(i);
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: PdfPageImageFormat.jpeg,
        );

        if (pageImage != null) {
          String newImagePath = "$imagesFolderPath/${baseName}_page_$i.jpg";
          File newFile = File(newImagePath);

          await newFile.writeAsBytes(pageImage.bytes);

          try {
            await Gal.putImage(newImagePath);
          } catch (e) {
            print("Gallery Sync Error: $e");
          }
        }

        await page.close();
      }

      await document.close();
      showToast("Success! Saved $pageCount pages to Gallery");
    } catch (e) {
      print("Save JPEG Error: $e");
      showToast("Failed to extract pages.");
    }
  }

  // Future<void> _showConvertToWordConfirmDialog(BuildContext context, File pdfFile) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   String baseSavePath = prefs.getString('pref_storage_location') ?? "/storage/emulated/0/Download";
  //
  //   String wordFolderPath = "$baseSavePath/Word Files";
  //
  //   bool isConfirmed = await showCustomConfirmDialog(
  //     context,
  //     title: "Convert to Word",
  //     message: "Do you want to convert this PDF into a Word document?\n\nSave Location:\n$wordFolderPath",
  //     positiveBtnText: "Convert",
  //     negativeBtnText: "Cancel",
  //     positiveBtnColor: Colors.blueAccent,
  //   );
  //
  //   if (isConfirmed) {
  //     showDialog(
  //       context: context,
  //       barrierDismissible: false,
  //       builder: (BuildContext dialogContext) {
  //         return const AlertDialog(
  //           backgroundColor: Color(0xFF2C2C2C),
  //           shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
  //           content: Row(
  //             children: [
  //               CircularProgressIndicator(color: Colors.blueAccent),
  //               SizedBox(width: 20),
  //               Expanded(
  //                 child: Text(
  //                   "Converting to Word... Please wait",
  //                   style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         );
  //       },
  //     );
  //
  //     await _convertPdfToWord(pdfFile, wordFolderPath);
  //
  //     if (context.mounted) {
  //       Navigator.pop(context);
  //     }
  //   }
  // }
  //
  // Future<void> _convertPdfToWord(File pdfFile, String saveDirectory) async {
  //   try {
  //     final dir = Directory(saveDirectory);
  //     if (!await dir.exists()) {
  //       await dir.create(recursive: true);
  //     }
  //
  //     String fileName = pdfFile.path.split('/').last.replaceAll('.pdf', '.doc');
  //     String savePath = "${dir.path}/$fileName";
  //
  //     final document = await PdfDocument.openFile(pdfFile.path);
  //     final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  //
  //     // 4. Word File ka boilerplate structure (Jadu yahin hai!)
  //     StringBuffer wordContent = StringBuffer();
  //     wordContent.writeln('<html xmlns:w="urn:schemas-microsoft-com:office:word">');
  //     wordContent.writeln('<head><meta charset="utf-8"><title>Scanner Pro Document</title></head><body>');
  //
  //     for (int i = 1; i <= document.pagesCount; i++) {
  //       final page = await document.getPage(i);
  //
  //       final pageImage = await page.render(
  //         width: page.width * 2,
  //         height: page.height * 2,
  //         format: PdfPageImageFormat.jpeg,
  //       );
  //
  //       if (pageImage != null) {
  //         final tempDir = await getTemporaryDirectory();
  //         final tempFile = File('${tempDir.path}/temp_ocr_page_$i.jpg');
  //         await tempFile.writeAsBytes(pageImage.bytes);
  //
  //         final inputImage = InputImage.fromFile(tempFile);
  //         final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
  //
  //         String pageText = recognizedText.text.trim();
  //
  //         if (pageText.isNotEmpty) {
  //           String formattedText = pageText.replaceAll('\n', '<br>');
  //           wordContent.writeln('<p style="font-family: Arial, sans-serif; font-size: 14pt;">$formattedText</p>');
  //         } else {
  //           wordContent.writeln('<p style="color: grey;"><i>[Image Only / No Text Found on Page $i]</i></p>');
  //         }
  //
  //         if (i < document.pagesCount) {
  //           wordContent.writeln('<br clear="all" style="page-break-before:always" />');
  //         }
  //
  //         if (await tempFile.exists()) await tempFile.delete();
  //       }
  //       await page.close();
  //     }
  //
  //     wordContent.writeln('</body></html>');
  //
  //     textRecognizer.close();
  //     await document.close();
  //
  //     File wordFile = File(savePath);
  //     await wordFile.writeAsString(wordContent.toString());
  //
  //     showToast("Converted successfully! Saved in Word Files");
  //   } catch (e) {
  //     showToast("Error converting to Word: $e");
  //     print("Convert Error: $e");
  //   }
  // }


// 1. Button pe click hone par yeh function call karna
  // 1. ENTRY POINT: Jab user Extract Text par click karega
  Future<void> _processAndShowExtractedText(BuildContext context, File pdfFile) async {
    // Sirf Android Test Rewarded Ad ID
    //final String rewardedTestId = 'ca-app-pub-3940256099942544/5224354917'; // test ad id
    final String rewardedTestId = 'ca-app-pub-5454466291921987/8538007121'; //real ad id

    // Step A: Ad Load hone tak Loading Dialog dikhao
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.blueAccent),
        );
      },
    );

    // Step B: Ad Load karne ki koshish karo
    RewardedAd.load(
      adUnitId: rewardedTestId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          // 1. Ad mil gaya -> Pehle Loading Dialog band karo
          if (context.mounted) Navigator.pop(context);

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (RewardedAd ad) {
              // User ne Ad close kar diya -> Ab OCR start karo
              ad.dispose();
              _executeOcrAndShowDialog(context, pdfFile);
            },
            onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
              // Ad screen par show nahi ho paya -> Tab bhi direct OCR start karo
              ad.dispose();
              _executeOcrAndShowDialog(context, pdfFile);
            },
          );

          // 2. Ad Screen par dikhao
          ad.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
            // Reward logic yahan handle ho gaya
          });
        },
        onAdFailedToLoad: (LoadAdError error) {
          // Ad load nahi hua (Network issue etc.) -> Loading Dialog band karo aur direct OCR chalao
          print('Rewarded ad failed to load: $error');
          if (context.mounted) Navigator.pop(context);
          _executeOcrAndShowDialog(context, pdfFile);
        },
      ),
    );
  }

// 2. ACTUAL OCR EXECUTION: Yeh OCR ka Progress Dialog aur Result Dialog Sambhalega
  Future<void> _executeOcrAndShowDialog(BuildContext context, File pdfFile) async {
    // Step 1: OCR Loading Dialog dikhao
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return const AlertDialog(
            backgroundColor: Color(0xFF2C2C2C),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
            content: Row(
              children: [
                CircularProgressIndicator(color: Colors.blueAccent),
                SizedBox(width: 20),
                Expanded(
                  child: Text(
                    "Extracting Text (OCR)... Please wait",
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    // Step 2: Background Engine se Text Extract karo
    String extractedText = await _extractTextFromPdf(pdfFile);

    // Step 3: Extraction complete hone par OCR Loading Dialog band karo
    if (context.mounted) {
      Navigator.pop(context);
    }

    // Step 4: Final Result Dialog (Jo tumne banaya hai) Show karo
    if (context.mounted) {
      if (extractedText.trim().isEmpty) {
        showToast("No text found in this PDF.");
      } else {
        _showExtractedTextDialog(context, extractedText);
      }
    }
  }

// 2. Background Engine: Jo PDF se actually text nikalega
  Future<String> _extractTextFromPdf(File pdfFile) async {
    StringBuffer allText = StringBuffer();
    try {
      final document = await PdfDocument.openFile(pdfFile.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

      for (int i = 1; i <= document.pagesCount; i++) {
        final page = await document.getPage(i);
        final pageImage = await page.render(
          width: page.width * 2, // High resolution for better OCR
          height: page.height * 2,
          format: PdfPageImageFormat.jpeg,
        );

        if (pageImage != null) {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/temp_ocr_page_$i.jpg');
          await tempFile.writeAsBytes(pageImage.bytes);

          final inputImage = InputImage.fromFile(tempFile);
          final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

          String pageText = recognizedText.text.trim();
          if (pageText.isNotEmpty) {
            allText.writeln("--- Page $i ---"); // Page divider for neat look
            allText.writeln(pageText);
            allText.writeln(); // Extra space
          }

          if (await tempFile.exists()) await tempFile.delete();
        }
        await page.close();
      }
      textRecognizer.close();
      await document.close();
    } catch (e) {
      print("OCR Error: $e");
    }
    return allText.toString();
  }

  void _showExtractedTextDialog(BuildContext context, String extractedText) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          // TITLE KO UPDATE KIYA HAI - ROW USE KARKE
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // Ek left, ek right
            children: [
              const Text(
                "Extracted Text",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white), // Close (X) Icon
                onPressed: () {
                  Navigator.pop(context); // Dialog close karne ka function
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(), // Extra space kam karne ke liye
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ConstrainedBox(
              // Dialog screen se bahar na jaye isliye height limit ki hai
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: SingleChildScrollView(
                // SelectableText use kiya taaki user thoda sa text bhi manually copy kar sake
                child: SelectableText(
                  extractedText,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            // COPY BUTTON
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: extractedText));
                showToast("Text copied to clipboard!");
                Navigator.pop(context); // Copy karne ke baad bhi dialog close hoga
              },
              icon: const Icon(Icons.copy, color: Colors.blueAccent),
              label: const Text("Copy", style: TextStyle(color: Colors.blueAccent)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.blueAccent, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),

            // SHARE BUTTON
            TextButton.icon(
              onPressed: () {
                Share.share(extractedText, subject: 'Extracted Text from Scanner Pro');
                Navigator.pop(context); // Share pe click karne ke baad dialog close hoga
              },
              icon: const Icon(Icons.share, color: Colors.greenAccent),
              label: const Text("Share", style: TextStyle(color: Colors.greenAccent)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.greenAccent, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> savePdfToDownloads(File pdfFile, BuildContext context) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // 1. Phone memory se purana saved folder path check karo
      String? savedUriString = prefs.getString('pdf_save_folder');
      Uri? folderUri;
      saf.DocumentFile? savedPdf;

      final String uniqueFileName = 'PDF_Scanner_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final Uint8List bytes = await pdfFile.readAsBytes();

      // 2. Agar path pehle se saved hai, toh bina pooche SILENT SAVE karne ki koshish karo
      if (savedUriString != null) {
        folderUri = Uri.parse(savedUriString);
        try {
          savedPdf = await saf.createFile(
            folderUri,
            mimeType: 'application/pdf',
            displayName: uniqueFileName,
            bytes: bytes,
          );
        } catch (e) {
          // Agar user ne file manager se wo folder delete kar diya hai, toh path reset kar do
          folderUri = null;
        }
      }

      // 3. Agar pehli baar app use ho rahi hai (ya purana folder delete ho gaya)
      if (folderUri == null) {
        // User ko ek chota message dikhao
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Select a folder once. Next time PDFs will save automatically here!")),
        );

        // Native folder picker kholo (Sirf 1 baar khulega)
        folderUri = await saf.openDocumentTree();

        if (folderUri == null) {
          return; // Agar user ne back daba diya toh cancel kar do
        }

        // JADOO YAHAN HAI: Folder ka path hamesha ke liye memory mein save kar lo!
        await prefs.setString('pdf_save_folder', folderUri.toString());

        // Naye select kiye hue folder mein PDF save karo
        savedPdf = await saf.createFile(
          folderUri,
          mimeType: 'application/pdf',
          displayName: uniqueFileName,
          bytes: bytes,
        );
      }

      // 4. Success Message (Yeh batane ke liye ki background mein save ho gaya)
      if (savedPdf != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text("PDF Saved Successfully!"),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

    } catch (e) {
      print("PDF Save Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
      );
    }
  }

} //end main class
///end main class///////////////////////////////////////////////////////////////////
///

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
      final document = await PdfDocument.openFile(widget.filePath);
      final page = await document.getPage(1);

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
    if (_hasError) {
      return const Center(child: Icon(Icons.picture_as_pdf_rounded, color: Colors.white54, size: 30));
    }
    if (_imageBytes == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white30));
    }
    return Image.memory(_imageBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
  }
}

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
      // TODO Google's Test Native Ad ID
      //adUnitId: 'ca-app-pub-3940256099942544/2247696110', // test id
      adUnitId: 'ca-app-pub-5454466291921987/9147373025', // real id
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
      return const SizedBox.shrink();
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
        child: SizedBox(height: 91, child: AdWidget(ad: _nativeAd!)),
      ),
    );
  }
}

class PdfSearchDelegate extends SearchDelegate {
  final List<File> pdfFiles;

  PdfSearchDelegate(this.pdfFiles);

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData.dark().copyWith(
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1E1E1E), elevation: 0),
      scaffoldBackgroundColor: const Color(0xFF121212),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.white54),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear, color: Colors.white70),
          onPressed: () {
            query = ''; // Text clear karega
          },
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.white70),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults();

  Widget _buildSearchResults() {
    final lowercaseQuery = query.toLowerCase();

    final results = pdfFiles.where((file) {
      final fileName = file.path.split('/').last.toLowerCase();
      return fileName.contains(lowercaseQuery);
    }).toList();

    if (lowercaseQuery.isNotEmpty) {
      results.sort((a, b) {
        final nameA = a.path.split('/').last.toLowerCase();
        final nameB = b.path.split('/').last.toLowerCase();

        final startsWithA = nameA.startsWith(lowercaseQuery);
        final startsWithB = nameB.startsWith(lowercaseQuery);

        if (startsWithA && !startsWithB) {
          return -1;
        } else if (!startsWithA && startsWithB) {
          return 1;
        } else {
          return 0;
        }
      });
    }

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

class SavedPdfScreen extends StatefulWidget {
  final List<File> allFiles;
  final List<String> savedPaths;

  const SavedPdfScreen({super.key, required this.allFiles, required this.savedPaths});

  @override
  State<SavedPdfScreen> createState() => _SavedPdfScreenState();
}

class _SavedPdfScreenState extends State<SavedPdfScreen> {
  late List<File> _savedFilesList;

  @override
  void initState() {
    super.initState();
    _savedFilesList = widget.allFiles.where((file) => widget.savedPaths.contains(file.path)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Saved Documents", style: TextStyle(color: Colors.white, fontSize: 18)),
      ),
      body: _savedFilesList.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bookmark_border_rounded, color: Colors.white24, size: 60),
                  const SizedBox(height: 12),
                  const Text("No saved documents yet", style: TextStyle(color: Colors.white54, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 10),
              itemCount: _savedFilesList.length,
              itemBuilder: (context, index) {
                final file = _savedFilesList[index];
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
                    // Click karne par file direct open ho jayegi
                    OpenFile.open(file.path);
                  },
                );
              },
            ),
    );
  }
}

List<String> searchAllPdfsInBackground(String rootPath) {
  List<String> pdfPaths = [];
  try {
    Directory rootDir = Directory(rootPath);
    if (!rootDir.existsSync()) return pdfPaths;

    List<Directory> dirsToSearch = [rootDir];

    while (dirsToSearch.isNotEmpty) {
      Directory currentDir = dirsToSearch.removeLast();
      try {
        List<FileSystemEntity> entities = currentDir.listSync(recursive: false);
        for (var entity in entities) {
          if (entity is File) {
            if (entity.path.toLowerCase().endsWith('.pdf')) {
              pdfPaths.add(entity.path);
            }
          } else if (entity is Directory) {
            String dirName = entity.path.split('/').last;
            if (!dirName.startsWith('.') && dirName != 'Android') {
              dirsToSearch.add(entity);
            }
          }
        }
      } catch (e) {
        // Skip restricted folders
      }
    }
  } catch (e) {
    print("Background search error: $e");
  }
  return pdfPaths;
}
