import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../main.dart';
import 'dart:io';
import 'package:scroll_snap_list/scroll_snap_list.dart';
import 'package:flutter/services.dart'; // For locking orientation
import 'package:sensors_plus/sensors_plus.dart'; // For accelerometer
import 'dart:async';

import 'document_editor_screen.dart';
import 'home_screen.dart'; // For StreamSubscription

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

  StreamSubscription<AccelerometerEvent>? _sensorSubscription;
  double _iconTurns = 0.0; // 0.0 = Portrait, 0.25 = Landscape Left, etc.

  int capturedPhotosCount = 0; // Counter for the badge
  bool isCapturing = false; // To prevent multiple taps while capturing
  int currentCountdown = 0; // Tracks the active countdown (3, 2, 1)
  List<File> capturedImagesList = []; // Nayi list jo saari photos store karegi

  @override
  void initState() {
    super.initState();

    // Lock screen to Portrait mode only so layout doesn't break
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

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

    // Listen to accelerometer to detect physical phone rotation
    _sensorSubscription = accelerometerEventStream().listen((
      AccelerometerEvent event,
    ) {
      if (!mounted) return;

      setState(() {
        if (event.x > 6) {
          // Phone rotated left -> Rotate icons clockwise to keep them upright
          _iconTurns = 0.25;
        } else if (event.x < -6) {
          // Phone rotated right -> Rotate icons counter-clockwise
          _iconTurns = -0.25;
        } else if (event.y > 6) {
          // Phone is upright -> Reset to normal
          _iconTurns = 0.0;
        }
      });
    });
  }

  @override
  void dispose() {
    // Cancel subscription to save battery
    _sensorSubscription?.cancel();

    // Reset orientation settings when leaving this screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

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
        return Symbols
            .crop_5_4_sharp; // 4:3 ke liye sabse best aur similar icon
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
      await _applyFlashMode(selectedFlashMode);
      if (mounted) {
        setState(() {}); // Camera change hone par screen refresh hogi
        //showToast(currentCameraIndex == 1 ? "Front Camera" : "Back Camera");
      }
    } catch (e) {
      showToast("Error switching camera");
    }
  }

  Future<void> _applyFlashMode(String mode) async {
    if (!controller.value.isInitialized) return;

    try {
      switch (mode) {
        case "On":
          await controller.setFlashMode(FlashMode.always);
          break;
        case "Auto":
          await controller.setFlashMode(FlashMode.auto);
          break;
        case "Torch":
          await controller.setFlashMode(FlashMode.torch);
          break;
        case "Off":
        default:
          await controller.setFlashMode(FlashMode.off);
          break;
      }
    } catch (e) {
      // Agar front camera me flash nahi hai, toh yeh error handle kar lega
      showToast("Flash not supported on this camera");
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

  // Function to capture the photo with countdown logic
  Future<void> _capturePhoto() async {
    // Prevent action if camera is not ready or already capturing
    if (!controller.value.isInitialized || isCapturing) return;

    setState(() {
      isCapturing = true;
      activeMenu = "Default"; // Close any open menu
    });

    try {
      // Handle the timer delay with a visual countdown
      if (selectedTimer > 0) {
        for (int i = selectedTimer; i > 0; i--) {
          setState(() {
            currentCountdown = i; // Update the UI with current second
          });
          // Wait for exactly 1 second
          await Future.delayed(const Duration(seconds: 1));
        }

        // Countdown finished, reset to 0 before capturing
        setState(() {
          currentCountdown = 0;
        });
      }

      // Capture the picture
      final XFile photo = await controller.takePicture();

      /// Update the state with the new photo and increment the counter
      setState(() {
        lastCapturedImage = photo;

        // NAYI LINE: Click ki gayi photo ko list me add kar do
        capturedImagesList.add(File(photo.path));

        capturedPhotosCount = capturedImagesList.length; // Counter ko list ki length se update karo
        isCapturing = false;
      });

    } catch (e) {
      // Handle errors and reset states
      setState(() {
        isCapturing = false;
        currentCountdown = 0;
      });
      showToast("Error capturing photo");
    }
  }

  @override
  Widget build(BuildContext context) {
    //final screenWidth = MediaQuery.of(context).size.width;
    //final itemWidth = screenWidth * 0.22;

    if (!controller.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF2C2C2C),
      body: GestureDetector(
        onTap: () {
          if (activeMenu != "Default") {
            setState(() {
              activeMenu =
                  "Default"; // Screen par tap karte hi menu wapas normal ho jayega
            });
          }
        },
        // Translucent zaroori hai taaki yeh poori screen ke touch ko detect kare
        behavior: HitTestBehavior.translucent,
        child: SizedBox.expand(
          child: Stack(
            children: [
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
                              //showToast("Home");
                              // Yeh purani saari screens ko hata kar HomeScreen ko first page bana dega
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const HomeScreen(),
                                ),
                                    (route) => false, // false matlab saari purani history clear
                              );
                            },
                            icon: _buildRotatedIcon(
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
                            icon: _buildRotatedIcon(
                              Icons.photo_library_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),

                          /// Capture Button
                          // GestureDetector(
                          //   onTap: () {
                          //     showToast("Capture");
                          //   },
                          //   child: Container(
                          //     width: 60,
                          //     height: 60,
                          //     decoration: BoxDecoration(
                          //       shape: BoxShape.circle,
                          //       border: Border.all(
                          //         color: Colors.white,
                          //         width: 4,
                          //       ),
                          //     ),
                          //     child: Center(
                          //       child: Container(
                          //         width: 45,
                          //         height: 45,
                          //         decoration: const BoxDecoration(
                          //           color: Colors.white,
                          //           shape: BoxShape.circle,
                          //         ),
                          //       ),
                          //     ),
                          //   ),
                          // ),

                          /// Capture Button
                          /// Dynamic & Animated Capture Button
                          GestureDetector(
                            onTap: _capturePhoto,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Base Outer Circle (Always White or Grey)
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: (isCapturing && selectedTimer == 0) ? Colors.grey : Colors.white,
                                      width: 4,
                                    ),
                                  ),
                                ),

                                // Blue Animated Progress Ring (Shows only during countdown)
                                if (isCapturing && selectedTimer > 0)
                                  SizedBox(
                                    width: 56,
                                    height: 56,
                                    child: TweenAnimationBuilder<double>(
                                      // Animates from 0.0 to 1.0 smoothly over the selected timer duration
                                      tween: Tween<double>(begin: 0.0, end: 1.0),
                                      duration: Duration(seconds: selectedTimer),
                                      builder: (context, value, child) {
                                        return CircularProgressIndicator(
                                          value: value, // Current progress
                                          strokeWidth: 4,
                                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                                          backgroundColor: Colors.transparent,
                                        );
                                      },
                                    ),
                                  ),

                                // Inner Content: Numbers OR Solid Circle
                                if (isCapturing && currentCountdown > 0)
                                // Show actively counting down number (e.g., 3, 2, 1)
                                  Text(
                                    '$currentCountdown',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                else if (!isCapturing && selectedTimer > 0)
                                // Show selected timer duration before tapping (e.g., 3 or 10)
                                  Text(
                                    '$selectedTimer',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                else
                                // Show default inner solid circle when no timer is selected
                                  Container(
                                    width: 45,
                                    height: 45,
                                    decoration: BoxDecoration(
                                      color: isCapturing ? Colors.grey : Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          /// Auto Detect
                          IconButton(
                            onPressed: () {
                              showToast("Auto Detect");
                            },
                            icon: _buildRotatedIcon(
                              Icons.document_scanner_outlined,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),

                          /// Last Photo
                          // GestureDetector(
                          //   onTap: () {
                          //     showToast("Last Photo");
                          //   },
                          //   child: Container(
                          //     width: 42,
                          //     height: 42,
                          //     decoration: BoxDecoration(
                          //       color: Colors.white24,
                          //       borderRadius: BorderRadius.circular(8),
                          //     ),
                          //     child: lastCapturedImage == null
                          //         ? const SizedBox()
                          //         : ClipRRect(
                          //             borderRadius: BorderRadius.circular(8),
                          //             child: Image.file(
                          //               File(lastCapturedImage!.path),
                          //               fit: BoxFit.cover,
                          //             ),
                          //           ),
                          //   ),
                          // ),

                          /// Last Photo with Counter Badge
                          GestureDetector(
                            onTap: () {
                              if (capturedPhotosCount > 0) {
                                // YAHAN NAVIGATOR ADD KIYA HAI
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DocumentEditorScreen(
                                      imageFiles: capturedImagesList, // List pass kar di
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Stack(
                              clipBehavior: Clip.none, // Allows the badge to overflow the box slightly
                              children: [
                                Container(
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

                                // Counter Badge (Shows only if photos are captured)
                                if (capturedPhotosCount > 0)
                                  Positioned(
                                    top: -6,
                                    right: -6,
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: const BoxDecoration(
                                        color: Colors.amber, // Highlight color for the badge
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '$capturedPhotosCount',
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
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

  // Helper widget to animate icon rotation based on phone physical orientation
  Widget _buildRotatedIcon(
    IconData iconData, {
    Color color = Colors.white,
    double size = 26,
  }) {
    return AnimatedRotation(
      turns: _iconTurns,
      duration: const Duration(milliseconds: 300), // Smooth rotation animation
      child: Icon(iconData, color: color, size: size),
    );
  }

  ///top bar option
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
              const Text(
                "Flash",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
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
              const Text(
                "Timer",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  _buildTimerOption(0), // Off
                  _buildTimerOption(3), // 3s
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
                icon: _buildRotatedIcon(
                  _getFlashIcon(),
                  color: Colors.white,
                  size: 26,
                ),
              ),

              /// YAHAN TIMER ICON DYNAMIC KAR DIYA
              IconButton(
                onPressed: () => setState(() => activeMenu = "Timer"),
                icon: _buildRotatedIcon(
                  _getTimerIcon(),
                  color: Colors.white,
                  size: 26,
                ),
              ),
              IconButton(
                onPressed: () => setState(() => activeMenu = "Ratio"),
                icon: _buildRotatedIcon(
                  _getRatioIcon(),
                  color: Colors.white,
                  size: 26,
                ),
              ),
              IconButton(
                onPressed: _flipCamera,
                icon: _buildRotatedIcon(
                  Symbols.flip_camera_android_sharp,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              IconButton(
                onPressed: () => showToast("Settings"),
                icon: _buildRotatedIcon(
                  Symbols.segment_sharp,
                  color: Colors.white,
                  size: 26,
                ),
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
        //showToast("$label Ratio Selected");
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
      onTap: () async {
        setState(() {
          selectedFlashMode = mode;
          activeMenu = "Default"; // YEH LINE MENU KO CLOSE KAREGI
        });
        await _applyFlashMode(mode);
        //showToast("Flash $mode");
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Icon(_getFlashIcon(mode), color: color, size: 26),
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
        //showToast(seconds == 0 ? "Timer Off" : "Timer ${seconds}s");
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Icon(_getTimerIcon(seconds), color: color, size: 26),
      ),
    );
  }
}

///end main class
