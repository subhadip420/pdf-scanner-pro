import 'dart:io';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _fileName = widget.pdfFile.path.split('/').last;
    _originalSize = _formatBytes(widget.pdfFile.lengthSync());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCompression();
    });
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

  // Dummy Compress Function (Yahan tum future me real compression logic lagaoge)
  Future<void> _startCompression() async {
    setState(() {
      _isCompressing = true;
      _newSize = null;
    });

    // 2 second ka wait simulate kar rahe hain
    await Future.delayed(const Duration(seconds: 2));

    // Calculate new size (Slider percentage ke hisaab se dummy size reduce kar rahe hain)
    int originalBytes = widget.pdfFile.lengthSync();
    double reductionFactor = _compressionLevel / 100.0;
    int compressedBytes = (originalBytes * (1.0 - (reductionFactor * 0.7))).toInt(); // Formula for demo

    setState(() {
      _isCompressing = false;
      _newSize = _formatBytes(compressedBytes);
    });

    // showToast("Compression Successful!");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        leading: Tooltip(
          message: "Back",
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text("Compress PDF", style: TextStyle(color: Colors.white, fontSize: 20)),
      ),
      // 1. Scrollable Body
      body: SingleChildScrollView(
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
            const SizedBox(height: 20),

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
            const SizedBox(height: 20),

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
                    onPressed: _newSize == null ? null : () { /* Share logic */ },
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
            const SizedBox(height: 15),

            // 7. Download PDF Button
            ElevatedButton.icon(
              onPressed: _newSize == null ? null : () { /* Download logic */ },
              icon: const Icon(Icons.download_rounded, color: Colors.white),
              label: const Text("DOWNLOAD COMPRESSED PDF", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    );
  }
}