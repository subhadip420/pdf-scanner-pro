import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_compressor/pdf_compressor.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:share_plus/share_plus.dart';
import 'custom_dialog.dart';
import 'home_screen.dart';

// 🚨 NAYI SCREEN: PDF Compress UI
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
  // Test Ad Unit ID - Release karte time isko apne AdMob ID se replace karna!
  final String _bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoaded = false;
  // Test ID - Release se pehle apni AdMob ID lagana
  final String _interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';

  @override
  void initState() {
    super.initState();
    _fileName = widget.pdfFile.path.split('/').last;
    _originalSize = _formatBytes(widget.pdfFile.lengthSync());
    _loadBannerAd();
    _loadInterstitialAd();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCompression();
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose(); // 🚨 Memory leak bachane ke liye Ad ko dispose zarur karna

    super.dispose();
  }

  // 🚨 BUSINESS LOGIC: Banner Ad Load karna
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

  // 🚨 BUSINESS LOGIC: Full Screen Ad Load karna
  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoaded = true;
        },
        onAdFailedToLoad: (error) {
          print('Interstitial ad failed to load: $error');
          _isInterstitialAdLoaded = false;
        },
      ),
    );
  }

  // 🚨 UI FIX: Toast message dikhane ke liye helper function
  void showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey.shade900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

// 🚨 BUSINESS LOGIC: Back button aur system gesture rokne ke liye
  Future<void> _handleBackButton() async {
    // Agar background me compression chal raha hai ya user dekh raha hai, toh dialog dikhao
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
        Navigator.pop(context); // 🚨 User ne confirm kiya, tabhi pop (back) karenge
      }
    }
  }

  // File size format karne ka helper function (KB / MB me)
  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    if (bytes < 1024 * 1024) {
      return "${(bytes / 1024).toStringAsFixed(2)} KB";
    }
    return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
  }

  // Info Button dabane par jo Dialog aayega
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blueAccent),
              SizedBox(width: 10),
              Text('Compression Info', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: const Text(
            "Higher percentage will reduce the PDF size more, but might lower image quality slightly.",
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it', style: TextStyle(color: Colors.blueAccent, fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  // // Dummy Compress Function (Yahan tum future me real compression logic lagaoge)
  // Future<void> _startCompression() async {
  //   setState(() {
  //     _isCompressing = true;
  //     _newSize = null;
  //   });
  //
  //   // 2 second ka wait simulate kar rahe hain
  //   await Future.delayed(const Duration(seconds: 2));
  //
  //   // Calculate new size (Slider percentage ke hisaab se dummy size reduce kar rahe hain)
  //   int originalBytes = widget.pdfFile.lengthSync();
  //   double reductionFactor = _compressionLevel / 100.0;
  //   int compressedBytes = (originalBytes * (1.0 - (reductionFactor * 0.7))).toInt(); // Formula for demo
  //
  //   setState(() {
  //     _isCompressing = false;
  //     _newSize = _formatBytes(compressedBytes);
  //   });
  //
  //   // showToast("Compression Successful!");
  // }

  // 🚨 BUSINESS LOGIC: ASLI COMPRESSION FUNCTION
  Future<void> _startCompression() async {
    if (!mounted) return;

    setState(() {
      _isCompressing = true;
      _newSize = null;
      _tempCompressedFilePath = null; // Purana temp hata do
    });

    try {
      // 1. Temporary folder pata karo jahan compressed file rakhi jayegi
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = "${tempDir.path}/temp_compress_${DateTime.now().millisecondsSinceEpoch}.pdf";

      // 2. Slider (10% to 100%) ke hisaab se Compress Quality decide karo
      CompressQuality quality;
      if (_compressionLevel >= 80) {
        quality = CompressQuality.LOW; // Size zyada kam nahi hoga, quality high rahegi
      } else if (_compressionLevel >= 40) {
        quality = CompressQuality.MEDIUM; // Balanced
      } else {
        quality = CompressQuality.HIGH; // Size sabse zyada kam hoga (quality drop ho sakti hai)
      }

      // 3. Asli Package ka use karke file compress karo
      await PdfCompressor.compressPdfFile(
        widget.pdfFile.path, // Original file path
        tempPath,            // Naya temp file path
        quality,             // Quality enum
      );

      // 4. File check karo aur UI update karo
      File compressedFile = File(tempPath);
      if (compressedFile.existsSync()) {
        int newBytes = compressedFile.lengthSync();

        if (mounted) {
          setState(() {
            _tempCompressedFilePath = tempPath; // Path save kar liya taaki download button kaam kare
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
    //return Scaffold(

    // 🚨 FIX 1: PopScope lagaya taaki system back swipe/button block ho jaye
    return PopScope(
        canPop: false, // Direct back hone se rokega
        onPopInvokedWithResult: (bool didPop, Object? result) async {
      if (didPop) return;

      // System ka back gesture ya phone ka back button dabne par
      await _handleBackButton();
    },
    child: Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        leading: Tooltip(
          message: "Back",
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => _handleBackButton(),
          ),
        ),
        title: const Text("Compress PDF", style: TextStyle(color: Colors.white, fontSize: 20)),
      ),
      // 1. Scrollable Body
      //body: SingleChildScrollView(

      body: Column(
          children: [
          // 🚨 NAYA: Banner Ad Container
          if (_isBannerAdLoaded && _bannerAd != null)
      Container(
      width: double.infinity,
      color: const Color(0xFF121212), // Appbar se match karta hua background
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 5), // Thodi breathing space
      child: SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    ),

    // 1. Tumhara Scrollable Body (Expanded me daala taaki bachi hui jagah le le)
    Expanded(
    child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20,0,20,10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 2. Header Row (Text + Info Button)
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //   children: [
            //     const Text(
            //       "Compression Level",
            //       style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            //     ),
            //     IconButton(
            //       icon: const Icon(Icons.info_outline, color: Colors.white54, size: 22),
            //       onPressed: _showInfoDialog,
            //       tooltip: "Info",
            //     ),
            //   ],
            // ),

            Row(
              mainAxisAlignment: MainAxisAlignment.start, // 🚨 FIX: Dono ko start me laya
              children: [
                const Text(
                  "Compression Level",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 4), // Text aur icon ke beech halka sa space
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.white54, size: 20),
                  onPressed: _showInfoDialog,
                  tooltip: "Info",
                  padding: EdgeInsets.zero, // 🚨 FIX: Icon ki extra default space hata di
                  constraints: const BoxConstraints(), // 🚨 FIX: Button ko bilkul icon ke size ka kar diya
                ),
              ],
            ),

            // 3. Slider Area
            Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.blueAccent,
                      inactiveTrackColor: Colors.white12,
                      thumbColor: Colors.blueAccent,
                      overlayColor: Colors.blueAccent.withOpacity(0.2),
                      valueIndicatorTextStyle: const TextStyle(color: Colors.white),
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
                          _newSize = null; // Slider hilane par purana naya size hata do
                        });
                      },
                    ),
                  ),
                ),
                Text(
                  "${_compressionLevel.toInt()}%",
                  style: const TextStyle(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 4. Compress Button
            ElevatedButton(
              onPressed: _isCompressing ? null : _startCompression,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isCompressing
                  ? const SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
              )
                  : const Text("COMPRESS", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
            const SizedBox(height: 15),

            // 5. Card View
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  // File Name
                  Text(
                    _fileName,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Original Size
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Original Size: ", style: TextStyle(color: Colors.white54, fontSize: 14)),
                      Text(_originalSize, style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // PDF Preview (using your existing PdfThumbnailView)
                  Container(
                    height: 180,
                    width: 130,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    clipBehavior: Clip.hardEdge,
                    // 🚨 Tumhara purana class call ho raha hai yahan
                    child: PdfThumbnailView(key: ValueKey(widget.pdfFile.path), filePath: widget.pdfFile.path),
                  ),
                  const SizedBox(height: 16),

                  // New Size
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("New Size: ", style: TextStyle(color: Colors.white54, fontSize: 15)),
                      Text(
                        _newSize ?? "Pending...",
                        style: TextStyle(
                            color: _newSize != null ? Colors.greenAccent : Colors.white54,
                            fontSize: 15,
                            fontWeight: FontWeight.bold
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),

            // 6. Action Row (Download ZIP & Share)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _newSize == null ? null : () { /* Zip logic */ },
                    icon: const Icon(Icons.folder_zip_outlined, size: 20, color: Colors.white),
                    label: const Text("Save as ZIP", style: TextStyle(color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: OutlinedButton.icon(
                    //onPressed: _newSize == null ? null : () { /* Share logic */ },
                    onPressed: _newSize == null ? null : () => _shareCompressedPdf(),
                    icon: const Icon(Icons.share_outlined, size: 20, color: Colors.blueAccent),
                    label: const Text("Share PDF", style: TextStyle(color: Colors.blueAccent)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Colors.blueAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 7. Download PDF Button
            ElevatedButton.icon(
              //onPressed: _newSize == null ? null : () { /* Download logic */ },
              onPressed: _newSize == null ? null : () => _saveCompressedPdf(),
              icon: const Icon(Icons.download_rounded, color: Colors.white),
              label: const Text("SAVE COMPRESSED PDF", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                disabledBackgroundColor: Colors.white12,
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

  // 🚨 BUSINESS LOGIC: Compressed PDF ko direct share karne ka function
  Future<void> _shareCompressedPdf() async {
    if (_tempCompressedFilePath == null) return;

    try {
      // 1. Naya naam banao (Timestamp ke sath)
      final String nameWithoutExt = _fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String newFileName = "compressed_${nameWithoutExt}_$timestamp.pdf";

      // 2. Temp directory path nikalo jahan hum nayi renamed file banayenge
      final Directory tempDir = await getTemporaryDirectory();
      final String renamedTempPath = "${tempDir.path}/$newFileName";

      // 3. Purani temp file ko naye naam ke sath copy kar do (taaki share karte time naam sahi jaye)
      File originalTempFile = File(_tempCompressedFilePath!);
      File renamedTempFile = await originalTempFile.copy(renamedTempPath);

      // 4. Share UI open karo
      // await Share.shareXFiles(
      //   [XFile(renamedTempFile.path)],
      //   text: 'Here is the compressed PDF: $newFileName', // Optional text jo WhatsApp/Email me message banega
      // );

      // 4. Share UI open karo (🚨 Naya aur Updated Syntax)
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(renamedTempFile.path)],
          text: 'Here is the compressed PDF: $newFileName', // WhatsApp/Email ke liye optional text
        ),
      );

    } catch (e) {
      print("Share Error: $e");
      showToast("Failed to share PDF!");
    }
  }

  // 🚨 BUSINESS LOGIC: COMPRESSED FILE KO SAVE KARNA
  // Future<void> _saveCompressedPdf() async {
  //   // Agar koi temp file nahi bani hai toh kuch mat karo
  //   if (_tempCompressedFilePath == null) return;
  //
  //   try {
  //     // 1. Original file ka folder pata karo
  //     final String dirPath = widget.pdfFile.parent.path;
  //
  //     // 2. Naya naam banao (compressed_ + originalName)
  //     //final String newFileName = "compressed_$_fileName";
  //
  //     // 2. Naya naam banao timestamp ke sath
  //     // Pehle original naam se '.pdf' hata do
  //     final String nameWithoutExt = _fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
  //
  //     // Current time ka timestamp nikalo
  //     final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
  //
  //     // Ab sabko jod do: compressed_ + naam + _ + timestamp + .pdf
  //     final String newFileName = "compressed_${nameWithoutExt}_$timestamp.pdf";
  //
  //     // 3. Pura save path banao
  //     final String savePath = "$dirPath/$newFileName";
  //
  //     // 4. Temporary compressed file ko finally Save path par COPY kar do
  //     File tempFile = File(_tempCompressedFilePath!);
  //     await tempFile.copy(savePath);
  //
  //     // 5. Success Message dikhao
  //     showToast("Saved as: $newFileName");
  //
  //     // 6. Screen close karke pichhe bhejo taaki user ko result dikh jaye
  //     if (mounted) {
  //       Navigator.pop(context);
  //     }
  //
  //   } catch (e) {
  //     print("Save Compressed PDF Error: $e");
  //     showToast("Failed to save PDF!");
  //   }
  // }

// 🚨 BUSINESS LOGIC: Ad dikhana aur fir Save karna
  Future<void> _saveCompressedPdf() async {
    if (_tempCompressedFilePath == null) return;

    // Asli Save karne ka code (Isko ek local function bana diya)
    Future<void> performSave() async {
      try {
        final String dirPath = widget.pdfFile.parent.path;
        final String nameWithoutExt = _fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
        final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

        final String newFileName = "compressed_${nameWithoutExt}_$timestamp.pdf";
        final String savePath = "$dirPath/$newFileName";

        File tempFile = File(_tempCompressedFilePath!);
        await tempFile.copy(savePath);

        showToast("Saved as: $newFileName");

        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        print("Save Error: $e");
        showToast("Failed to save PDF!");
      }
    }

    // Check karo: Agar Ad ready hai toh pehle dikhao
    if (_isInterstitialAdLoaded && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          // Jab user 'X' daba kar Ad close kare
          ad.dispose();
          _loadInterstitialAd(); // Agli baar ke liye nayi ad load pe laga do
          performSave(); // 🚨 Ad close hote hi automatically File Save aur screen band!
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          // Agar galti se ad show hone me fail ho jaye
          ad.dispose();
          _loadInterstitialAd();
          performSave(); // User ko wait mat karao, direct save kar do
        },
      );

      _interstitialAd!.show(); // 🚨 Screen par Ad pop-up karo
      _isInterstitialAdLoaded = false; // Purani ad use ho gayi, flag reset

    } else {
      // Agar internet slow hone ki wajah se Ad load hi nahi hui thi
      performSave(); // Direct save kar do
    }
  }

}// end main