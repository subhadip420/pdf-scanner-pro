import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:material_symbols_icons/symbols.dart';
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

  bool isSelectingFlash = false;
  String selectedFlashMode = "Off"; // Options: "Off", "On", "Auto", "Torch"

  // Kaunsa top menu open hai: "Default", "Ratio", "Flash", ya "Timer"
  String activeMenu = "Default";
  int selectedTimer = 0; // 0 matlab Off, baaki 3 aur 10 seconds ke liye

  int currentCameraIndex = 0; // 0 matlab By Default Back Camera

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

  // Selected ratio ke hisaab se dynamic icon
  IconData _getRatioIcon() {
    switch (selectedRatio) {
      case "1:1":
        return Symbols.crop_square_sharp;
      case "16:9":
        return Symbols.crop_16_9_sharp;
      case "Full":
        return Symbols.fullscreen_sharp;
      case "4:3":
      default:
        return Symbols.crop_5_4_sharp; // 4:3 ke liye sabse best aur similar icon
    }
  }

  // Selected flash mode ke hisaab se icon return karega
  IconData _getFlashIcon([String? mode]) {
    final String currentMode = mode ?? selectedFlashMode;
    switch (currentMode) {
      case "On":
        return Symbols.flash_on_sharp;
      case "Auto":
        return Symbols.flash_auto_sharp;
      case "Torch":
        return Symbols.highlight_sharp; // Ya Icons.flashlight_on_rounded
      case "Off":
      default:
        return Symbols.flash_off_sharp;
    }
  }

  // Timer icon return karne ke liye
  IconData _getTimerIcon([int? timer]) {
    final int currentTimer = timer ?? selectedTimer;
    switch (currentTimer) {
      case 3:
        return Symbols.timer_3_alt_1; // 3 second icon
      case 10:
        return Symbols.timer_10_alt_1; // 10 second icon
      case 0:
      default:
        return Symbols.timer; // Default timer icon
    }
  }

  Future<void> _flipCamera() async {
    // Agar phone me front camera nahi hai ya 1 hi camera hai
    if (cameras.length < 2) {
      showToast("Secondary camera not available");
      return;
    }

    // Index ko toggle karein (0 hai toh 1 kardo, 1 hai toh 0 kardo)
    currentCameraIndex = currentCameraIndex == 0 ? 1 : 0;
    final CameraDescription newCamera = cameras[currentCameraIndex];

    // Purane camera controller ko stop aur dispose karna zaroori hai
    await controller.dispose();

    // Naye camera ke saath naya controller banayein
    controller = CameraController(
      newCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    // Naye controller ko initialize karke UI update karein
    try {
      await controller.initialize();
      if (mounted) {
        setState(() {}); // Camera change hone par screen refresh hogi
        showToast(currentCameraIndex == 1 ? "Front Camera" : "Back Camera");
      }
    } catch (e) {
      showToast("Error switching camera");
    }
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // return Scaffold(
    //     backgroundColor: const Color(0xFF2C2C2C),
    // body: SizedBox.expand(
    // child: Stack(
    // children: [

    return Scaffold(
      backgroundColor: const Color(0xFF2C2C2C),
      body: GestureDetector(
        onTap: () {
          if (activeMenu != "Default") {
            setState(() {
              activeMenu = "Default"; // Screen par tap karte hi menu wapas normal ho jayega
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
                      bottom: 180,
                      // Sirf 1:1 ke liye bottom boundary hai taaki center ho sake
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
                                width:
                                    controller.value.previewSize?.height ?? 1,
                                height:
                                    controller.value.previewSize?.width ?? 1,
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
              // Positioned(
              //   top: 0,
              //   left: 0,
              //   right: 0,
              //   child: SafeArea(
              //     child: Padding(
              //       padding: const EdgeInsets.symmetric(
              //         horizontal: 16,
              //         vertical: 9,
              //       ),
              //       // Yahan Condition lagayi hai
              //       child: isSelectingRatio
              //           ? Container(
              //               padding: const EdgeInsets.symmetric(
              //                 horizontal: 22,
              //                 vertical: 14,
              //               ),
              //               decoration: BoxDecoration(
              //                 color: Colors.black.withOpacity(0.35),
              //                 // Thoda dark background clarity ke liye
              //                 borderRadius: BorderRadius.circular(30),
              //               ),
              //               child: Row(
              //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //                 children: [
              //                   const Text(
              //                     "Aspect ratio",
              //                     style: TextStyle(
              //                       color: Colors.white,
              //                       fontSize: 14,
              //                       fontWeight: FontWeight.w500,
              //                     ),
              //                   ),
              //                   Row(
              //                     children: [
              //                       _buildRatioOption("1:1"),
              //                       const SizedBox(width: 8),
              //                       _buildRatioOption("4:3"),
              //                       const SizedBox(width: 8),
              //                       _buildRatioOption("16:9"),
              //                       const SizedBox(width: 8),
              //                       _buildRatioOption("Full"),
              //                     ],
              //                   ),
              //                 ],
              //               ),
              //             )
              //           : Container(
              //               padding: const EdgeInsets.symmetric(
              //                 horizontal: 8,
              //                 vertical: 4,
              //               ),
              //               decoration: BoxDecoration(
              //                 color: Colors.black.withOpacity(0.35),
              //                 borderRadius: BorderRadius.circular(30),
              //               ),
              //               child: Row(
              //                 mainAxisAlignment: MainAxisAlignment.spaceAround,
              //                 children: [
              //                   /// Flash
              //                   IconButton(
              //                     onPressed: () => showToast("Flash"),
              //                     icon: const Icon(
              //                       Icons.flash_off_rounded,
              //                       color: Colors.white,
              //                       size: 26,
              //                     ),
              //                   ),
              //
              //                   /// Timer
              //                   IconButton(
              //                     onPressed: () => showToast("Timer"),
              //                     icon: const Icon(
              //                       Icons.timer_outlined,
              //                       color: Colors.white,
              //                       size: 26,
              //                     ),
              //                   ),
              //
              //                   /// Ratio Button (Jo Ratio menu open karega)
              //                   /// Ratio Button (Jo Ratio menu open karega)
              //                   IconButton(
              //                     onPressed: () {
              //                       setState(() {
              //                         isSelectingRatio = true;
              //                       });
              //                     },
              //                     // Yahan humne function call kiya aur 'const' hata diya
              //                     icon: Icon(
              //                       _getRatioIcon(),
              //                       color: Colors.white,
              //                       size: 26,
              //                     ),
              //                   ),
              //
              //                   /// Flip Camera
              //                   IconButton(
              //                     onPressed: () => showToast("Flip Camera"),
              //                     icon: const Icon(
              //                       Icons.flip_camera_android_rounded,
              //                       color: Colors.white,
              //                       size: 26,
              //                     ),
              //                   ),
              //
              //                   /// Settings
              //                   IconButton(
              //                     onPressed: () => showToast("Settings"),
              //                     icon: const Icon(
              //                       Icons.settings_rounded,
              //                       color: Colors.white,
              //                       size: 26,
              //                     ),
              //                   ),
              //                 ],
              //               ),
              //             ),
              //     ),
              //   ),
              // ),

              /// Top Controls
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    // Yahan humne simply naya function call kar diya
                    child: _buildTopBarContent(),
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
                          final bool isSelected = index == selectedIndex;

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
                                  color: isSelected
                                      ? Colors.blue
                                      : Colors.white,
                                  fontSize: isSelected ? 15 : 13,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
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

  Widget _buildTopBarContent() {
    switch (activeMenu) {
      case "Flash":
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Flash", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
              Row(
                children: [
                  _buildFlashOption("Off"),
                  _buildFlashOption("On"),
                  _buildFlashOption("Auto"),
                  _buildFlashOption("Torch"),
                ],
              ),
            ],
          ),
        );

      case "Ratio":
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Aspect ratio", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
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
        );

      case "Timer":
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Timer", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
              Row(
                children: [
                  _buildTimerOption(0),  // Off
                  _buildTimerOption(3),  // 3s
                  _buildTimerOption(10), // 10s
                ],
              ),
            ],
          ),
        );

      case "Default":
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                onPressed: () => setState(() => activeMenu = "Flash"),
                icon: Icon(_getFlashIcon(), color: Colors.white, size: 26),
              ),
              /// YAHAN TIMER ICON DYNAMIC KAR DIYA
              IconButton(
                onPressed: () => setState(() => activeMenu = "Timer"),
                icon: Icon(_getTimerIcon(), color: Colors.white, size: 26),
              ),
              IconButton(
                onPressed: () => setState(() => activeMenu = "Ratio"),
                icon: Icon(_getRatioIcon(), color: Colors.white, size: 26),
              ),
              IconButton(
                onPressed: _flipCamera,
                icon: const Icon(Symbols.flip_camera_android_sharp, color: Colors.white, size: 26),
              ),
              IconButton(
                onPressed: () => showToast("Settings"),
                icon: const Icon(Symbols.settings_photo_camera_sharp, color: Colors.white, size: 26),
              ),
            ],
          ),
        );
    }
  }

// Ratio menu ke options banane ke liye
  Widget _buildRatioOption(String label) {
    final bool isSelected = selectedRatio == label;
    final Color color = isSelected ? Colors.amber : Colors.white;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedRatio = label;
          activeMenu = "Default"; // YEH LINE MENU KO CLOSE KAREGI
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

  // Flash menu ke icons banane ke liye
  Widget _buildFlashOption(String mode) {
    final bool isSelected = selectedFlashMode == mode;
    final Color color = isSelected ? Colors.amber : Colors.white;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFlashMode = mode;
          activeMenu = "Default"; // YEH LINE MENU KO CLOSE KAREGI
        });
        showToast("Flash $mode");
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Icon(
          _getFlashIcon(mode),
          color: color,
          size: 26,
        ),
      ),
    );
  }

  // Timer menu ke icons banane ke liye
  Widget _buildTimerOption(int seconds) {
    final bool isSelected = selectedTimer == seconds;
    final Color color = isSelected ? Colors.amber : Colors.white;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTimer = seconds;
          activeMenu = "Default"; // Tap karte hi menu close ho jayega
        });
        showToast(seconds == 0 ? "Timer Off" : "Timer ${seconds}s");
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Icon(
          _getTimerIcon(seconds),
          color: color,
          size: 26,
        ),
      ),
    );
  }

}///end main class
