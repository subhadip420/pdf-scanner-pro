import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_compressor/pdf_compressor.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:share_plus/share_plus.dart';
import 'custom_dialog.dart';
import 'home_screen.dart';

class PdfCompressScreen extends StatefulWidget {
  final File pdfFile;

  const PdfCompressScreen({super.key, required this.pdfFile});

  @override
  State<PdfCompressScreen> createState() => _PdfCompressScreenState();
}

class _PdfCompressScreenState extends State<PdfCompressScreen> {
  double _compressionLevel = 60.0; // Default 60%
  bool _isCompressing = false;
  String? _newSize;

  late String _fileName;
  late String _originalSize;
  String? _tempCompressedFilePath;
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  // TODO Test Ad Unit ID
  //final String _bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111'; // test ad id
  final String _bannerAdUnitId = 'ca-app-pub-5454466291921987/1268883000'; // real ad id

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoaded = false;

  RewardedAd? _rewardedAd;

  // TODO Test ID
  //final String _interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712'; // test ad id
  //final String _interstitialAdUnitId = 'ca-app-pub-5454466291921987/9394785031'; // real ad id

  // TODO Google's Test AD ID
// final String _rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917'; // test ad id
  final String _rewardedAdUnitId = 'ca-app-pub-5454466291921987/2609884833'; // real ad id

  @override
  void initState() {
    super.initState();
    _fileName = widget.pdfFile.path.split('/').last;
    _originalSize = _formatBytes(widget.pdfFile.lengthSync());
    _loadBannerAd();
    //_loadInterstitialAd();
    _loadRewardedAd();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCompression();
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();

    super.dispose();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isBannerAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          print('Compress Screen Banner Ad failed to load: $error');
        },
      ),
    )..load();
  }

  // void _loadInterstitialAd() {
  //   InterstitialAd.load(
  //     adUnitId: _interstitialAdUnitId,
  //     request: const AdRequest(),
  //     adLoadCallback: InterstitialAdLoadCallback(
  //       onAdLoaded: (ad) {
  //         _interstitialAd = ad;
  //         _isInterstitialAdLoaded = true;
  //       },
  //       onAdFailedToLoad: (error) {
  //         print('Interstitial ad failed to load: $error');
  //         _isInterstitialAdLoaded = false;
  //       },
  //     ),
  //   );
  // }

  // initState mein isko call kar lena
  void _loadRewardedAd() {
    print("AdMob: Loading Rewarded ad...");
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          print("AdMob: Rewarded Ad loaded successfully!");
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (RewardedAd ad) {
              ad.dispose();
              _rewardedAd = null;
              _loadRewardedAd(); // Agli baar ke liye naya ad load karo
            },
            onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
              ad.dispose();
              _rewardedAd = null;
            },
          );
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (LoadAdError error) {
          print("AdMob: Rewarded Ad failed to load: ${error.message}");
          _rewardedAd = null;
        },
      ),
    );
  }

  void showToast(String message) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color:  isDarkMode ? Colors.white : Colors.black45)),
        backgroundColor:  isDarkMode ?  Colors.grey.shade900 : Colors.grey.shade300,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleBackButton() async {
    bool shouldDiscard = await showCustomConfirmDialog(
      context,
      title: "Discard changes?",
      message: "Are you sure you want to go back? The compressed file won't be saved.",
      positiveBtnText: "Discard",
      negativeBtnText: "Cancel",
      positiveBtnColor: Colors.redAccent,
    );

    if (shouldDiscard) {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    if (bytes < 1024 * 1024) {
      return "${(bytes / 1024).toStringAsFixed(2)} KB";
    }
    return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
  }

  void _showInfoDialog() {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          //backgroundColor: const Color(0xFF2C2C2C),
          backgroundColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: isDarkMode ? Colors.blueAccent : Colors.blue,),
              const SizedBox(width: 10),
              Text('Compression Info', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87,)),
            ],
          ),
          content: Text(
            "Higher percentage will reduce the PDF size more, but might lower image quality slightly.",
            style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54, fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Got it', style: TextStyle(color: isDarkMode ? Colors.blueAccent : Colors.blue, fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startCompression() async {
    if (!mounted) return;

    setState(() {
      _isCompressing = true;
      _newSize = null;
      _tempCompressedFilePath = null;
    });

    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = "${tempDir.path}/temp_compress_${DateTime.now().millisecondsSinceEpoch}.pdf";

      CompressQuality quality;
      if (_compressionLevel >= 80) {
        quality = CompressQuality.LOW;
      } else if (_compressionLevel >= 40) {
        quality = CompressQuality.MEDIUM;
      } else {
        quality = CompressQuality.HIGH;
      }

      await PdfCompressor.compressPdfFile(widget.pdfFile.path, tempPath, quality);

      File compressedFile = File(tempPath);
      if (compressedFile.existsSync()) {
        int newBytes = compressedFile.lengthSync();

        if (mounted) {
          setState(() {
            _tempCompressedFilePath = tempPath;
            _newSize = _formatBytes(newBytes);
            _isCompressing = false;
          });
        }
      }
    } catch (e) {
      print("Real Compression Error: $e");
      if (mounted) {
        setState(() {
          _isCompressing = false;
          _newSize = "Error!";
        });
      }
      showToast("Failed to compress PDF. File might be protected or too complex.");
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: false, // Direct back hone se rokega
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;

        await _handleBackButton();
      },
      child: Scaffold(
        backgroundColor: isDarkMode ?  const Color(0xFF121212) : Colors.white,
        appBar: AppBar(
          backgroundColor: isDarkMode ?  const Color(0xFF1E1E1E) : Colors.grey.shade300,
          elevation: 0,
          leading: Tooltip(
            message: "Back",
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
              onPressed: () => _handleBackButton(),
            ),
          ),
          title: Text("Compress PDF", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 20)),
        ),

        // 1. Scrollable Body
        //body: SingleChildScrollView(
        body: Column(
          children: [
            // Banner Ad Container
            if (_isBannerAdLoaded && _bannerAd != null)
              Container(
                width: double.infinity,
                color:isDarkMode ?  const Color(0xFF121212) : Colors.white,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: SizedBox(
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          "Compression Level",
                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 4), // Text aur icon ke beech halka sa space
                        IconButton(
                          icon: Icon(Icons.info_outline, color: isDarkMode ?  Colors.white54 : Colors.black, size: 20),
                          onPressed: _showInfoDialog,
                          tooltip: "Info",
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),

                    /// Slider Area
                    Row(
                      children: [
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              //activeTrackColor: Colors.blueAccent,
                              activeTrackColor: isDarkMode ? Colors.grey.shade400 : Colors.blue.shade700,
                              //inactiveTrackColor: Colors.white12,
                              inactiveTrackColor: isDarkMode ? Colors.grey.shade800 : Colors.grey,
                              //thumbColor: Colors.blueAccent,
                              thumbColor: isDarkMode ? Colors.white : Colors.blue,
                              overlayColor: isDarkMode ?  Colors.blueAccent.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                              valueIndicatorTextStyle: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                            ),
                            child: Slider(
                              value: _compressionLevel,
                              min: 10,
                              max: 100,
                              divisions: 90,
                              label: "${_compressionLevel.toInt()}%",
                              onChanged: (value) {
                                setState(() {
                                  _compressionLevel = value;
                                  _newSize = null;
                                });
                              },
                            ),
                          ),
                        ),
                        Text(
                          "${_compressionLevel.toInt()}%",
                          style: TextStyle(color: isDarkMode ?  Colors.blueAccent : Colors.blue, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    /// Compress Button
                    ElevatedButton(
                      onPressed: _isCompressing ? null : _startCompression,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkMode ? Colors.blueAccent : Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isCompressing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              "COMPRESS",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                    const SizedBox(height: 15),

                    /// Card View
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          /// File Name
                          Text(
                            _fileName,
                            style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),

                          /// Original Size
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Original Size: ", style: TextStyle(color: isDarkMode ?Colors.white54 : Colors.black, fontSize: 14)),
                              Text(
                                _originalSize,
                                style: TextStyle(
                                  color: isDarkMode ?  Colors.white54 : Colors.black,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          /// PDF Preview (using your existing PdfThumbnailView)
                          Container(
                            height: 180,
                            width: 130,
                            decoration: BoxDecoration(
                              //color: Colors.grey.shade800,
                              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade400,),
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: PdfThumbnailView(key: ValueKey(widget.pdfFile.path), filePath: widget.pdfFile.path),
                          ),
                          const SizedBox(height: 16),

                          /// New Size
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("New Size: ", style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black, fontSize: 15)),
                              Text(
                                _newSize ?? "Pending...",
                                style: TextStyle(
                                  color: _newSize != null
                                      ? (isDarkMode ? Colors.greenAccent : Colors.green.shade700) // Active/Success state
                                      : (isDarkMode ? Colors.white54 : Colors.black54),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),

                    /// Action Row (Download ZIP & Share)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _newSize == null ? null : () => _saveAsZip(),
                            icon: Icon(Icons.folder_zip_outlined, size: 20, color: isDarkMode ? Colors.white : Colors.black),
                            label: Text("Save as ZIP", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: isDarkMode ? Colors.white24 : Colors.black45),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _newSize == null ? null : () => _shareCompressedPdf(),
                            icon: Icon(Icons.share_outlined, size: 20, color: isDarkMode ? Colors.blueAccent : Colors.blue),
                            label: Text("Share PDF", style: TextStyle(color: isDarkMode ? Colors.blueAccent : Colors.blue)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: isDarkMode ? Colors.blueAccent : Colors.blue),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    /// Download PDF Button
                    ElevatedButton.icon(
                      onPressed: _newSize == null ? null : () => _saveCompressedPdf(),
                      icon: const Icon(Icons.download_rounded, color: Colors.white),
                      label: const Text(
                        "SAVE COMPRESSED PDF",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkMode ? Colors.green : Colors.green.shade600,
                        disabledBackgroundColor: isDarkMode ? Colors.white12 : Colors.black45,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  // Future<void> _saveAsZip() async {
  //   if (_tempCompressedFilePath == null) return;
  //   Future<void> performZipSave() async {
  //     try {
  //       final String nameWithoutExt = _fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
  //       final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
  //       final String zipFileName = "zip_${nameWithoutExt}_$timestamp.zip";
  //
  //       final Directory baseDir = Directory('/storage/emulated/0/Documents/PDF Scanner Pro');
  //       final Directory zipFolder = Directory('${baseDir.path}/ZIP Files');
  //
  //       if (!await zipFolder.exists()) {
  //         await zipFolder.create(recursive: true);
  //       }
  //
  //       final String zipPath = "${zipFolder.path}/$zipFileName";
  //
  //       File compressedFile = File(_tempCompressedFilePath!);
  //       List<int> fileBytes = await compressedFile.readAsBytes();
  //
  //       final archive = Archive();
  //       archive.addFile(ArchiveFile(_fileName, fileBytes.length, fileBytes));
  //
  //       final zipEncoder = ZipEncoder();
  //       final zipData = zipEncoder.encode(archive);
  //
  //       if (zipData != null) {
  //         File zipFile = File(zipPath);
  //         await zipFile.writeAsBytes(zipData);
  //
  //         showToast("Saved in ZIP Files folder");
  //
  //         // Screen close karke pichhe jao
  //         if (mounted) {
  //           Navigator.pop(context);
  //         }
  //       }
  //     } catch (e) {
  //       print("Zip Error: $e");
  //       showToast("Failed to create ZIP!");
  //     }
  //   }
  //
  //   if (_isInterstitialAdLoaded && _interstitialAd != null) {
  //     _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
  //       onAdDismissedFullScreenContent: (ad) {
  //         ad.dispose();
  //         _loadInterstitialAd();
  //         performZipSave();
  //       },
  //       onAdFailedToShowFullScreenContent: (ad, error) {
  //         ad.dispose();
  //         _loadInterstitialAd();
  //         performZipSave();
  //       },
  //     );
  //
  //     _interstitialAd!.show();
  //     _isInterstitialAdLoaded = false;
  //   } else {
  //     performZipSave();
  //   }
  // }

  Future<void> _saveAsZip() async {
    if (_tempCompressedFilePath == null) return;

    Future<void> performZipSave() async {
      try {
        final String nameWithoutExt = _fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
        final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final String zipFileName = "zip_${nameWithoutExt}_$timestamp.zip";

        final Directory baseDir = Directory('/storage/emulated/0/Documents/PDF Scanner Pro');
        final Directory zipFolder = Directory('${baseDir.path}/ZIP Files');

        if (!await zipFolder.exists()) {
          await zipFolder.create(recursive: true);
        }

        final String zipPath = "${zipFolder.path}/$zipFileName";

        File compressedFile = File(_tempCompressedFilePath!);
        List<int> fileBytes = await compressedFile.readAsBytes();

        final archive = Archive();
        archive.addFile(ArchiveFile(_fileName, fileBytes.length, fileBytes));

        final zipEncoder = ZipEncoder();
        final zipData = zipEncoder.encode(archive);

        if (zipData != null) {
          File zipFile = File(zipPath);
          await zipFile.writeAsBytes(zipData);

          showToast("Saved in ZIP Files folder");

          if (mounted) {
            Navigator.pop(context);
          }
        }
      } catch (e) {
        print("Zip Error: $e");
        showToast("Failed to create ZIP!");
      }
    }

    // YAHAN BHI REWARDED AD KA LOGIC LAGA DIYA
    if (_rewardedAd != null) {
      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          performZipSave();
        },
      );
    } else {
      performZipSave();
    }
  }

  Future<void> _shareCompressedPdf() async {
    if (_tempCompressedFilePath == null) return;

    try {
      final String nameWithoutExt = _fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String newFileName = "compressed_${nameWithoutExt}_$timestamp.pdf";

      final Directory tempDir = await getTemporaryDirectory();
      final String renamedTempPath = "${tempDir.path}/$newFileName";

      File originalTempFile = File(_tempCompressedFilePath!);
      File renamedTempFile = await originalTempFile.copy(renamedTempPath);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(renamedTempFile.path)], text: 'Here is the compressed PDF: $newFileName'),
      );
    } catch (e) {
      print("Share Error: $e");
      showToast("Failed to share PDF!");
    }
  }

  // Future<void> _saveCompressedPdf() async {
  //   if (_tempCompressedFilePath == null) return;
  //
  //   Future<void> performSave() async {
  //     try {
  //       // 🚨 Puraane parent.path ki jagah, apna safe Private Folder use karo
  //       final directory = await getApplicationDocumentsDirectory();
  //       final String dirPath = directory.path;
  //
  //       final String nameWithoutExt = _fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
  //       final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
  //
  //       // Naya file name aur path
  //       final String newFileName = "compressed_${nameWithoutExt}_$timestamp.pdf";
  //       final String savePath = "$dirPath/$newFileName";
  //
  //       // Temp folder se Private folder mein file copy karo
  //       File tempFile = File(_tempCompressedFilePath!);
  //       await tempFile.copy(savePath);
  //
  //       showToast("Saved as: $newFileName");
  //
  //       if (mounted) {
  //         //Navigator.pop(context);
  //         Navigator.pushAndRemoveUntil(
  //           context,
  //           MaterialPageRoute(builder: (context) => const HomeScreen()), // Apna Home Screen ka actual naam yahan likhna
  //               (Route<dynamic> route) => false,
  //         );
  //       }
  //     } catch (e) {
  //       print("Save Error: $e");
  //       showToast("Failed to save PDF!");
  //     }
  //   }
  //
  //   // Tumhara Ad logic ekdum sahi hai, isme maine koi chhed-chhad nahi ki hai
  //   if (_isInterstitialAdLoaded && _interstitialAd != null) {
  //     _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
  //       onAdDismissedFullScreenContent: (ad) {
  //         ad.dispose();
  //         _loadInterstitialAd();
  //         performSave();
  //       },
  //       onAdFailedToShowFullScreenContent: (ad, error) {
  //         ad.dispose();
  //         _loadInterstitialAd();
  //         performSave();
  //       },
  //     );
  //
  //     _interstitialAd!.show();
  //     _isInterstitialAdLoaded = false;
  //   } else {
  //     performSave();
  //   }
  // }

  Future<void> _saveCompressedPdf() async {
    if (_tempCompressedFilePath == null) return;

    Future<void> performSave() async {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final String dirPath = directory.path;

        final String nameWithoutExt = _fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
        final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

        final String newFileName = "compressed_${nameWithoutExt}_$timestamp.pdf";
        final String savePath = "$dirPath/$newFileName";

        File tempFile = File(_tempCompressedFilePath!);
        await tempFile.copy(savePath);

        showToast("Saved as: $newFileName");

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
                (Route<dynamic> route) => false,
          );
        }
      } catch (e) {
        print("Save Error: $e");
        showToast("Failed to save PDF!");
      }
    }

    // YAHAN FIX KIYA HAI: Interstitial ki jagah RewardedAd check kar rahe hain
    if (_rewardedAd != null) {
      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          // Jab user pura ad dekh lega, tabhi yeh line chalegi aur save hoga
          print("AdMob: Reward earned! Saving PDF...");
          performSave();
        },
      );
    } else {
      // Agar ad load nahi hua hai (jaise no internet), toh direct save kar do
      performSave();
    }
  }

} // end main
