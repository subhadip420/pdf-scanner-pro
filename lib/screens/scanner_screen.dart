import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../main.dart';
import 'dart:io';
import 'package:scroll_snap_list/scroll_snap_list.dart';
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {

  late CameraController controller;
  XFile? lastCapturedImage;
  String selectedMode = "Document";
  final ScrollController modeController = ScrollController();

  final List<String> scanModes = [
    "Whiteboard",
    "Book",
    "Document",
    "ID Card",
    "Business Card",
    "OCR",
  ];

  int selectedIndex = 2; // Document
  bool isSelectingRatio = false;
  String selectedRatio = "4:3"; // Default 4:3 select rahega

  // Portrait mode ke hisaab se ratios (width / height)
  double _getAspectRatio() {
    switch (selectedRatio) {
      case "1:1":
        return 1.0;
      case "16:9":
        return 9 / 16;
      case "4:3":
      default:
        return 3 / 4;
    }
  }

  @override
  void initState() {
    super.initState();

    controller = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );

    controller.initialize().then((_) {
      if (mounted) {
        setState(() {});
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollToDocument();
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void scrollToDocument() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (modeController.hasClients) {
        modeController.animateTo(
          150,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void showToast(String msg) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }



  @override
  Widget build(BuildContext context) {

    //final screenWidth = MediaQuery.of(context).size.width;
    //final itemWidth = screenWidth * 0.22;

    if (!controller.value.isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // return Scaffold(
    //     backgroundColor: const Color(0xFF2C2C2C),
    // body: SizedBox.expand(
    // child: Stack(
    // children: [

    return Scaffold(
        backgroundColor: const Color(0xFF2C2C2C),
    body: GestureDetector(
    // Agar ratio menu open hai, toh screen pe tap karte hi use false kar dega
    onTap: () {
    if (isSelectingRatio) {
    setState(() {
    isSelectingRatio = false;
    });
    }
    },
    // Translucent zaroori hai taaki yeh poori screen ke touch ko detect kare
    behavior: HitTestBehavior.translucent,
    child: SizedBox.expand(
    child: Stack(
    children: [

          /// Camera Preview
          // Align(
          //   alignment: const Alignment(0, -0.15),
          //   child: AspectRatio(
          //     aspectRatio: 3 / 4,
          //     child: CameraPreview(controller),
          //   ),
          // ),

          // Positioned(
          //   top: 90,
          //   left: 0,
          //   right: 0,
          //   bottom: 180,
          //   child: Center(
          //     child: AspectRatio(
          //       aspectRatio: 3 / 4,
          //       child: CameraPreview(controller),
          //     ),
          //   ),
          // ),

      // /// Camera Preview
      // selectedRatio == "Full"
      //     ? Positioned.fill(
      //   child: CameraPreview(controller),
      // )
      //     : Positioned(
      //   top: 90,
      //   left: 0,
      //   right: 0,
      //   bottom: 180,
      //   child: Center(
      //     child: AspectRatio(
      //       aspectRatio: _getAspectRatio(),
      //       child: ClipRect( // ClipRect make sure karta hai ki preview bahar na nikle
      //         child: CameraPreview(controller),
      //       ),
      //     ),
      //   ),
      // ),

      /// Camera Preview
      selectedRatio == "Full"
          ? Positioned.fill(
        child: ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            alignment: Alignment.center,
            child: SizedBox(
              width: controller.value.previewSize?.height ?? 1,
              height: controller.value.previewSize?.width ?? 1,
              child: CameraPreview(controller),
            ),
          ),
        ),
      )
          : selectedRatio == "1:1"
          ? Positioned(
        top: 90,
        bottom: 180, // Sirf 1:1 ke liye bottom boundary hai taaki center ho sake
        left: 0,
        right: 0,
        child: Center(
          child: AspectRatio(
            aspectRatio: 1.0,
            child: ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                alignment: Alignment.center,
                child: SizedBox(
                  width: controller.value.previewSize?.height ?? 1,
                  height: controller.value.previewSize?.width ?? 1,
                  child: CameraPreview(controller),
                ),
              ),
            ),
          ),
        ),
      )
          : Positioned(
        top: 115,
        left: 0,
        right: 0,
        // 4:3 aur 16:9 ke liye no 'bottom', bilkul pehle jaisa perfect width cover karega
        child: AspectRatio(
          aspectRatio: _getAspectRatio(),
          child: ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              alignment: Alignment.center,
              child: SizedBox(
                width: controller.value.previewSize?.height ?? 1,
                height: controller.value.previewSize?.width ?? 1,
                child: CameraPreview(controller),
              ),
            ),
          ),
        ),
      ),
          ///for full screen
          // Positioned.fill(
          //   child: CameraPreview(controller),
          // ),

          // /// Dark Overlay
          // Positioned.fill(
          //   child: Container(
          //     color: Colors.black.withOpacity(0.15),
          //   ),
          // ),

          /// Top Controls
    /// Top Controls
    // Positioned(
    // top: 0,
    // left: 0,
    // right: 0,
    // child: SafeArea(
    // child: Padding(
    //           padding: const EdgeInsets.symmetric(
    //             horizontal: 16,
    //             vertical: 9,
    //           ),
    //           child: Container(
    //             padding: const EdgeInsets.symmetric(
    //               horizontal: 8,
    //               vertical: 4,
    //             ),
    //             decoration: BoxDecoration(
    //               color: Colors.black.withOpacity(0.35),
    //               borderRadius: BorderRadius.circular(30),
    //             ),
    //             child: Row(
    //               mainAxisAlignment: MainAxisAlignment.spaceAround,
    //               children: [
    //
    //                 /// Flash
    //                 IconButton(
    //                   onPressed: () {
    //                     showToast("Flash");
    //                   },
    //                   icon: const Icon(
    //                     Icons.flash_off_rounded,
    //                     color: Colors.white,
    //                     size: 26,
    //                   ),
    //                 ),
    //
    //                 /// Timer
    //                 IconButton(
    //                   onPressed: () {
    //                     showToast("Timer");
    //                   },
    //                   icon: const Icon(
    //                     Icons.timer_outlined,
    //                     color: Colors.white,
    //                     size: 26,
    //                   ),
    //                 ),
    //
    //                 /// Ratio
    //                 IconButton(
    //                   onPressed: () {
    //                     showToast("Ratio");
    //                   },
    //                   icon: const Icon(
    //                     Icons.crop_16_9_rounded,
    //                     color: Colors.white,
    //                     size: 26,
    //                   ),
    //                 ),
    //
    //                 /// Flip Camera
    //                 IconButton(
    //                   onPressed: () {
    //                     showToast("Flip Camera");
    //                   },
    //                   icon: const Icon(
    //                     Icons.flip_camera_android_rounded,
    //                     color: Colors.white,
    //                     size: 26,
    //                   ),
    //                 ),
    //
    //                 /// Settings
    //                 IconButton(
    //                   onPressed: () {
    //                     showToast("Settings");
    //                   },
    //                   icon: const Icon(
    //                     Icons.settings_rounded,
    //                     color: Colors.white,
    //                     size: 26,
    //                   ),
    //                 ),
    //               ],
    //             ),
    //           ),
    //         ),
    //         ),
    //       ),


      /// Top Controls
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 9,
            ),
            // Yahan Condition lagayi hai
            child: isSelectingRatio
                ? Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35), // Thoda dark background clarity ke liye
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Aspect ratio",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: [
                      _buildRatioOption("1:1"),
                      const SizedBox(width: 8),
                      _buildRatioOption("4:3"),
                      const SizedBox(width: 8),
                      _buildRatioOption("16:9"),
                      const SizedBox(width: 8),
                      _buildRatioOption("Full"),
                    ],
                  ),
                ],
              ),
            )
                : Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  /// Flash
                  IconButton(
                    onPressed: () => showToast("Flash"),
                    icon: const Icon(Icons.flash_off_rounded, color: Colors.white, size: 26),
                  ),
                  /// Timer
                  IconButton(
                    onPressed: () => showToast("Timer"),
                    icon: const Icon(Icons.timer_outlined, color: Colors.white, size: 26),
                  ),
                  /// Ratio Button (Jo Ratio menu open karega)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        isSelectingRatio = true;
                      });
                    },
                    icon: const Icon(Icons.crop_16_9_rounded, color: Colors.white, size: 26),
                  ),
                  /// Flip Camera
                  IconButton(
                    onPressed: () => showToast("Flip Camera"),
                    icon: const Icon(Icons.flip_camera_android_rounded, color: Colors.white, size: 26),
                  ),
                  /// Settings
                  IconButton(
                    onPressed: () => showToast("Settings"),
                    icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 26),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

          // /// Center Text
          // const Center(
          //   child: Column(
          //     mainAxisSize: MainAxisSize.min,
          //     children: [
          //
          //       Icon(
          //         Icons.document_scanner_outlined,
          //         color: Colors.white70,
          //         size: 50,
          //       ),
          //
          //       SizedBox(height: 12),
          //
          //       Text(
          //         "Looking for document...",
          //         style: TextStyle(
          //           color: Colors.white,
          //           fontSize: 18,
          //           fontWeight: FontWeight.w600,
          //         ),
          //       ),
          //     ],
          //   ),
          // ),

          /// Scan Modes
          Positioned(
            bottom: 155,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 50,
              child: Stack(
                alignment: Alignment.center,
                children: [

                  // /// Center Indicator
                  // Positioned(
                  //   bottom: 0,
                  //   child: Container(
                  //     width: 20,
                  //     height: 3,
                  //     decoration: BoxDecoration(
                  //       color: Colors.blue,
                  //       borderRadius: BorderRadius.circular(10),
                  //     ),
                  //   ),
                  // ),

                  ScrollSnapList(
                    itemBuilder: (_, index) {

                      final bool isSelected =
                          index == selectedIndex;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            scanModes[index],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected ? Colors.blue : Colors.white,
                              fontSize: isSelected ? 15 : 13,
                              fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },

                    itemCount: scanModes.length,

                    itemSize: MediaQuery.of(context).size.width * 0.22,

                    initialIndex: 2,

                    dynamicItemSize: true,

                    onItemFocus: (index) {
                      setState(() {
                        selectedIndex = index;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          /// Bottom Controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 60,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 12,
                  right: 12,
                  bottom: 20,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [

                      /// Home
                      IconButton(
                        onPressed: () {
                          showToast("Home");
                        },
                        icon: const Icon(
                          Icons.home_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),

                      /// Gallery
                      IconButton(
                        onPressed: () {
                          showToast("Gallery");
                        },
                        icon: const Icon(
                          Icons.photo_library_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),

                      /// Capture Button
                      GestureDetector(
                        onTap: () {
                          showToast("Capture");
                        },
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 4,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 45,
                              height: 45,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),

                      /// Auto Detect
                      IconButton(
                        onPressed: () {
                          showToast("Auto Detect");
                        },
                        icon: const Icon(
                          Icons.document_scanner_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),

                      /// Last Photo
                      GestureDetector(
                        onTap: () {
                          showToast("Last Photo");
                        },
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: lastCapturedImage == null
                              ? const SizedBox()
                              : ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(lastCapturedImage!.path),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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

  Widget _buildRatioOption(String label) {
    final bool isSelected = selectedRatio == label;
    final Color color = isSelected ? Colors.amber : Colors.white;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedRatio = label;
          isSelectingRatio = false; // Select hone ke baad wapas normal bar aa jayega
        });
        showToast("$label Ratio Selected");
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }


}