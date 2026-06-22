import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import '../../main.dart';
import 'dart:io';
import 'package:scroll_snap_list/scroll_snap_list.dart';
import 'package:flutter/services.dart'; // For locking orientation
import 'package:sensors_plus/sensors_plus.dart'; // For accelerometer
import 'dart:async';
import 'package:image/image.dart' as img;
import 'custom_gallery_screen.dart';
import 'document_editor_screen.dart';
import 'home_screen.dart'; // For StreamSubscription
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:flutter/foundation.dart'; // WriteBuffer ke liye


class ScannerScreen extends StatefulWidget {

  final bool isRetakeMode;

  const ScannerScreen({
    Key? key,
    this.isRetakeMode = false, // By default normal mode rahega
  }) : super(key: key);

  //const ScannerScreen({super.key});

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
  //List<File> capturedImagesList = []; // Nayi list jo saari photos store karegi
  // NAYI LINE:
  List<Map<String, File>> capturedImagesList = [];
// Focus ke liye variables
  Offset? _focusPointPosition;
  bool _showFocusIndicator = false;
  Timer? _focusTimer;
// Real ML Auto-Detect Variables
  bool isAutoDetectOn = true;
  String autoScanStatus = "Looking for document...";
  bool isHoldingSteady = false;

  final TextRecognizer _textRecognizer = TextRecognizer();
  bool _isProcessingImage = false;
  Rect? _detectedDocumentBox; // Screen par blue border draw karne ke liye
  int _stableFrames = 0; // Document kitni der stable raha

  // Auto-Detect Popup Variables
  bool _showAutoDetectPopup = false;
  String _autoDetectPopupTitle = "";
  String _autoDetectPopupSubtitle = "";
  Timer? _popupTimer;


  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    controller = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    controller.initialize().then((_) {
      if (mounted) {
        setState(() {});
        // FIX 1: Screen khulte hi auto-detect start karna zaroori hai
        if (isAutoDetectOn) _startMLAutoDetect();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollToDocument();
    });

    _sensorSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      if (!mounted) return;
      setState(() {
        if (event.x > 6) _iconTurns = 0.25;
        else if (event.x < -6) _iconTurns = -0.25;
        else if (event.y > 6) _iconTurns = 0.0;
      });
    });
  }

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    _popupTimer?.cancel();

    // FIX 2: ML Recognizer ko memory se clear karna zaroori hai warna app crash hoga
    _textRecognizer.close();

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

  // // Selected ratio ke hisaab se dynamic icon
  // IconData _getRatioIcon() {
  //   switch (selectedRatio) {
  //     case "1:1":
  //       return Symbols.crop_square_sharp;
  //     case "16:9":
  //       return Symbols.crop_16_9_sharp;
  //     case "Full":
  //       return Symbols.fullscreen_sharp;
  //     case "4:3":
  //     default:
  //       return Symbols
  //           .crop_5_4_sharp; // 4:3 ke liye sabse best aur similar icon
  //   }
  // }

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
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
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

      // NAYI LINE: Photo save hone se pehle usko explicitly 4:3 me crop kar do
      await _cropTo43(photo.path);

      // 🚨 FIX 1: RETAKE LOGIC (Manual Camera Click) 🚨
      if (widget.isRetakeMode) {
        setState(() => isCapturing = false);
        Navigator.pop(context, File(photo.path)); // Seedha photo wapas bhej do
        return; // Niche ka code nahi chalega
      }

      /// Update the state with the new photo and increment the counter
      setState(() {
        lastCapturedImage = photo;

        // NAYI LINE: Click ki gayi photo ko list me add kar do
        //capturedImagesList.add(File(photo.path));
        capturedImagesList.add({
          'original': File(photo.path),
          'cropped': File(photo.path),
        });
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

  // Image ko perfect 4:3 document ratio me crop karne ke liye
  Future<void> _cropTo43(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    img.Image? originalImage = img.decodeImage(bytes);

    if (originalImage == null) return;

    int origW = originalImage.width;
    int origH = originalImage.height;
    double origRatio = origW / origH;
    double targetRatio = 3 / 4; // 4:3 portrait ratio

    // Agar image pehle se lagbhag 4:3 hai, toh processing time bachane ke liye skip karo
    if ((origRatio - targetRatio).abs() < 0.05) return;

    int cropW = origW;
    int cropH = origH;
    int x = 0;
    int y = 0;

    if (origRatio > targetRatio) {
      cropW = (origH * targetRatio).toInt();
      x = (origW - cropW) ~/ 2;
    } else {
      cropH = (origW / targetRatio).toInt();
      y = (origH - cropH) ~/ 2;
    }

    img.Image croppedImage = img.copyCrop(
      originalImage,
      x: x,
      y: y,
      width: cropW,
      height: cropH,
    );

    // Image wapas save karo (Quality 85 rakhi hai taaki processing fast ho)
    await file.writeAsBytes(img.encodeJpg(croppedImage, quality: 85));
  }


  // 1. Optimized Focus Function (Parallel execution se time kam lagega)
  Future<void> _setFocusPoint(TapUpDetails details, BoxConstraints constraints) async {
    if (!controller.value.isInitialized) return;

    final double x = details.localPosition.dx / constraints.maxWidth;
    final double y = details.localPosition.dy / constraints.maxHeight;
    final Offset focusPoint = Offset(x, y);

    try {
      // Box ko turant screen par dikhane ke liye pehle setState kiya
      if (mounted) {
        setState(() {
          _focusPointPosition = details.localPosition;
          _showFocusIndicator = true;
        });
      }

      // FIX: Future.wait use karne se Focus aur Exposure ek saath trigger honge, jisse speed fast ho jayegi
      await Future.wait([
        if (controller.value.focusPointSupported) controller.setFocusPoint(focusPoint),
        if (controller.value.exposurePointSupported) controller.setExposurePoint(focusPoint),
      ]);

      _focusTimer?.cancel();
      _focusTimer = Timer(const Duration(milliseconds: 1200), () { // Time 1.5s se 1.2s kiya for fast response
        if (mounted) {
          setState(() => _showFocusIndicator = false);
        }
      });
    } catch (e) {
      print("Error setting focus: $e");
    }
  }

  // 2. Camera Preview Helper with Bigger Focus Box
  Widget _buildCameraPreviewWithFocus() {
    return SizedBox(
      width: controller.value.previewSize?.height ?? 1,
      height: controller.value.previewSize?.width ?? 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onTapUp: (details) => _setFocusPoint(details, constraints),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(controller),

                // // YEH NAYI LINE: Real-time Blue Overlay
                // if (_detectedDocumentBox != null && isAutoDetectOn)
                //   CustomPaint(
                //     painter: DocumentOverlayPainter(
                //       _detectedDocumentBox,
                //       Size(controller.value.previewSize!.width, controller.value.previewSize!.height),
                //     ),
                //   ),

                // YEH NAYI LINE: Real-time Blue Overlay
                if (_detectedDocumentBox != null && isAutoDetectOn)
                  Positioned.fill(  // FIX 4: Isko Positioned.fill me wrap kiya
                    child: CustomPaint(
                      painter: DocumentOverlayPainter(
                        _detectedDocumentBox,
                        Size(controller.value.previewSize!.width, controller.value.previewSize!.height),
                      ),
                    ),
                  ),

                if (_showFocusIndicator && _focusPointPosition != null)
                  Positioned(
                    // FIX: Size 80 kiya hai, toh center karne ke liye 40 minus kiya (80 / 2)
                    left: _focusPointPosition!.dx - 40,
                    top: _focusPointPosition!.dy - 40,
                    child: Container(
                      width: 80,  // Size 50 se badhakar 80 kar diya
                      height: 80, // Size 50 se badhakar 80 kar diya
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.amber,
                          width: 2.0, // Border ko thoda aur sharp aur mota kiya
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _startMLAutoDetect() {
    if (!isAutoDetectOn || !controller.value.isInitialized) return;

    // FIX 2: Agar pehle se stream chal rahi hai, toh naya start na kare (crash rokne ke liye)
    if (controller.value.isStreamingImages) return;

    setState(() {
      autoScanStatus = "Looking for document...";
      isHoldingSteady = false;
      _stableFrames = 0;
    });

    controller.startImageStream((CameraImage image) async {
      if (_isProcessingImage || !isAutoDetectOn || isCapturing) return;
      _isProcessingImage = true;

      try {
        final WriteBuffer allBytes = WriteBuffer();
        for (final Plane plane in image.planes) {
          allBytes.putUint8List(plane.bytes);
        }
        final bytes = allBytes.done().buffer.asUint8List();

        final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
        final camera = cameras[currentCameraIndex];
        final imageRotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation90deg;

        // FIX 3: Strict format define kiya Platform ke hisab se, taaki ML Kit block na ho
        final inputImageFormat = Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888;

        final inputImageData = InputImageMetadata(
          size: imageSize,
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: image.planes[0].bytesPerRow,
        );

        final inputImage = InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
        final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

        // Agar text/document mil gaya!
        if (recognizedText.blocks.isNotEmpty) {
          double minX = double.infinity, minY = double.infinity;
          double maxX = 0, maxY = 0;

          for (TextBlock block in recognizedText.blocks) {
            if (block.boundingBox.left < minX) minX = block.boundingBox.left;
            if (block.boundingBox.top < minY) minY = block.boundingBox.top;
            if (block.boundingBox.right > maxX) maxX = block.boundingBox.right;
            if (block.boundingBox.bottom > maxY) maxY = block.boundingBox.bottom;
          }

          if (mounted) {
            setState(() {
              _detectedDocumentBox = Rect.fromLTRB(minX - 20, minY - 20, maxX + 20, maxY + 20);
              _stableFrames++;

              if (_stableFrames > 3) {
                autoScanStatus = "Capturing... hold steady";
                isHoldingSteady = true;
              }
            });

            if (_stableFrames > 10) {
              await controller.stopImageStream();
              _autoCaptureAndNavigate();
            }
          }
        } else {
          // Document screen se hat gaya
          if (mounted) {
            setState(() {
              _detectedDocumentBox = null;
              _stableFrames = 0;
              autoScanStatus = "Looking for document...";
              isHoldingSteady = false;
            });
          }
        }
      } catch (e) {
        print("ML Error: $e");
      } finally {
        _isProcessingImage = false;
      }
    });
  }

  Future<void> _autoCaptureAndNavigate() async {
    if (!controller.value.isInitialized || isCapturing) return;
    setState(() => isCapturing = true);

    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }

      // Photo capture
      Rect? boxToCrop = _detectedDocumentBox;
      final XFile photo = await controller.takePicture();

      // 🚨 YAHAN SE _cropTo43() KO HATA DIYA HAI 🚨
      // Kyunki wo original photo ko bigad raha tha.

      // Asli raw photo par AI ka auto-crop chalao
      File? croppedFile = await _autoCropImage(photo.path, boxToCrop);
      File finalFile = croppedFile ?? File(photo.path);

      // 🚨 FIX 3: RETAKE LOGIC (AI Auto-Capture) 🚨
      if (widget.isRetakeMode) {
        setState(() {
          isCapturing = false;
          _detectedDocumentBox = null;
        });
        Navigator.pop(context, finalFile); // Auto crop wali photo wapas bhej do
        return;
      }

      capturedImagesList.add({
        'original': File(photo.path),
        'cropped': croppedFile ?? File(photo.path),
      });
      capturedPhotosCount = capturedImagesList.length;

      setState(() {
        isCapturing = false;
        isHoldingSteady = false;
        _stableFrames = 0;
        _detectedDocumentBox = null;
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DocumentEditorScreen(imageFiles: capturedImagesList)),
        ).then((_) {
          if (isAutoDetectOn && !controller.value.isStreamingImages) {
            _startMLAutoDetect();
          }
        });
      }
    } catch (e) {
      setState(() => isCapturing = false);
    }
  }


  Future<void> _toggleAutoDetect() async {
    setState(() {
      isAutoDetectOn = !isAutoDetectOn; // ON ko OFF, OFF ko ON karega
      _showAutoDetectPopup = true; // Popup dikhana shuru karega

      if (isAutoDetectOn) {
        _autoDetectPopupTitle = "Auto-capture on";
        _autoDetectPopupSubtitle = "We'll find the borders and take the photo for you. You can adjust or take other quick actions.";
      } else {
        _autoDetectPopupTitle = "Auto-capture off";
        _autoDetectPopupSubtitle = "Scan multiple pages faster. Just tap the photo button, and adjust borders later.";

        // OFF hone par ML variables ko reset kar do
        isHoldingSteady = false;
        autoScanStatus = "Looking for document...";
        _detectedDocumentBox = null;
        _stableFrames = 0;
      }

      // 3 Second baad popup automatically hide ho jayega
      _popupTimer?.cancel();
      _popupTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showAutoDetectPopup = false;
          });
        }
      });
    });

    // ML Kit stream start/stop logic (setState ke bahar)
    if (isAutoDetectOn) {
      _startMLAutoDetect();
    } else {
      // Agar stream chal rahi hai aur user ne OFF kar diya, toh stream rok do
      if (controller.value.isStreamingImages) {
        try {
          await controller.stopImageStream();
        } catch (e) {
          print("Error stopping stream: $e");
        }
      }
    }
  }

  // Naya Helper Function: ML Box coordinates se asli image ko crop karna
  Future<File?> _autoCropImage(String originalPath, Rect? detectionBox) async {
    if (detectionBox == null || !controller.value.isInitialized) return null;

    try {
      final file = File(originalPath);
      final bytes = await file.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) return null;

      // Photo ko perfect seedha (portrait) karo
      originalImage = img.bakeOrientation(originalImage);

      // Scale calculations
      final double streamWidth = controller.value.previewSize!.height;
      final double streamHeight = controller.value.previewSize!.width;

      final double scaleX = originalImage.width / streamWidth;
      final double scaleY = originalImage.height / streamHeight;

      // Exact pixel coordinates nikalna
      int x = (detectionBox.left * scaleX).toInt();
      int y = (detectionBox.top * scaleY).toInt();
      int w = (detectionBox.width * scaleX).toInt();
      int h = (detectionBox.height * scaleY).toInt();

      x = x.clamp(0, originalImage.width);
      y = y.clamp(0, originalImage.height);
      w = w.clamp(1, originalImage.width - x);
      h = h.clamp(1, originalImage.height - y);

      // Original photo se strict box ko kaatna
      img.Image croppedImage = img.copyCrop(originalImage, x: x, y: y, width: w, height: h);

      final String croppedPath = originalPath.replaceAll('.jpg', '_autocrop.jpg');
      final croppedFile = File(croppedPath);
      await croppedFile.writeAsBytes(img.encodeJpg(croppedImage, quality: 100));

      return croppedFile;
    } catch (e) {
      print("Auto Crop Error: $e");
      return null;
    }
  }

///default media picker
  // Future<void> _pickImagesFromGallery() async {
  //   try {
  //     // 🚨 FIX: PhotoManager ke version ke jhanjhat ko chhodo,
  //     // permission_handler use karo jo tumhari file me pehle se imported hai!
  //     // 🚨 SMART PERMISSION BLOCK 🚨
  //     PermissionStatus status;
  //
  //     if (Platform.isAndroid) {
  //       // Pehle Android 13+ ke hisab se photos permission mangega
  //       status = await Permission.photos.request();
  //
  //       // Agar phone purana (Android 12 ya niche) hoga toh photos permission fail ho jayegi
  //       // Tab hum purane storage permission ko mangenge
  //       if (status.isDenied || status.isPermanentlyDenied) {
  //         PermissionStatus storageStatus = await Permission.storage.request();
  //         status = storageStatus; // Final status update kar diya
  //       }
  //     } else {
  //       // iOS ke liye
  //       status = await Permission.photos.request();
  //     }
  //
  //     // Agar user ne 'Don't ask again' kar diya hai, toh seedhe Settings me bhejo
  //     if (status.isPermanentlyDenied) {
  //       showToast("Please allow gallery access from Settings");
  //       await openAppSettings();
  //       return;
  //     }
  //
  //     // Final check
  //     if (!status.isGranted && !status.isLimited) {
  //       showToast("Gallery permission required to pick images.");
  //       return;
  //     }
  //
  //     // Iske niche tumhara AssetPicker.pickAssets() wala code chalega...
  //
  //     // Agar user ne permission nahi di, toh return ho jao
  //     if (!status.isGranted && !status.isLimited) {
  //       showToast("Gallery permission denied. Please enable it from settings.");
  //       return;
  //     }
  //
  //     // 🚨 Ab jab system level par permission mil gayi hai, picker bina kisi crash ke khulega
  //     final List<AssetEntity>? selectedAssets = await AssetPicker.pickAssets(
  //       context,
  //       pickerConfig: const AssetPickerConfig(
  //         requestType: RequestType.image,
  //         maxAssets: 50, // Max 50 images ek baar mein pick ho sakti hain
  //       ),
  //     );
  //
  //     if (selectedAssets == null || selectedAssets.isEmpty) return;
  //
  //     // Loading screen dikhao jab tak assets file me convert ho rahe hon
  //     showDialog(
  //       context: context,
  //       barrierDismissible: false,
  //       builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
  //     );
  //
  //     List<Map<String, File>> tempList = [];
  //
  //     for (var asset in selectedAssets) {
  //       final File? file = await asset.file;
  //       if (file != null) {
  //         tempList.add({
  //           'original': file,
  //           'cropped': file,
  //         });
  //       }
  //     }
  //
  //     if (mounted) Navigator.pop(context); // Loading close karo
  //
  //     setState(() {
  //       capturedImagesList.addAll(tempList);
  //       capturedPhotosCount = capturedImagesList.length; // Counter badge update
  //     });
  //
  //     showToast("${selectedAssets.length} images imported serial wise");
  //
  //     if (mounted) {
  //       Navigator.push(
  //         context,
  //         MaterialPageRoute(
  //           builder: (context) => DocumentEditorScreen(imageFiles: capturedImagesList),
  //         ),
  //       ).then((_) {
  //         if (isAutoDetectOn && !controller.value.isStreamingImages) {
  //           _startMLAutoDetect();
  //         }
  //       });
  //     }
  //   } catch (e) {
  //     if (mounted && Navigator.canPop(context)) Navigator.pop(context);
  //     print("Gallery Pick Error: $e");
  //     showToast("Error importing images");
  //   }
  // }

  /// custom media picker:
  Future<void> _pickImagesFromGallery() async {
    try {
      // Permission Handling (Pehle jaise tha)
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

      // 🚨 Puraane AssetPicker.pickAssets() ki jagah hum apni custom screen call karenge
      final List<File>? selectedFiles = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CustomGalleryScreen()),
      );

      // Agar user ne bina select kiye close kar diya
      if (selectedFiles == null || selectedFiles.isEmpty) return;

      // 🚨 FIX 2: RETAKE LOGIC (Gallery Selection) 🚨
      if (widget.isRetakeMode) {
        // Retake me sirf 1 image replace karni hai, toh list ki pehli photo bhej do
        Navigator.pop(context, selectedFiles.first);
        return;
      }

      setState(() {
        for (var file in selectedFiles) {
          capturedImagesList.add({
            'original': file,
            'cropped': file,
          });
        }
        capturedPhotosCount = capturedImagesList.length;
      });

      showToast("${selectedFiles.length} images imported serial wise");

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DocumentEditorScreen(imageFiles: capturedImagesList),
          ),
        ).then((_) {
          if (isAutoDetectOn && !controller.value.isStreamingImages) {
            _startMLAutoDetect();
          }
        });
      }
    } catch (e) {
      print("Gallery Error: $e");
      showToast("Error importing images");
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
                    // YAHAN HELPER WIDGET CALL KIYA HAI
                    child: _buildCameraPreviewWithFocus(),
                  ),
                ),
              )
                  : selectedRatio == "1:1"
                  ? Positioned(
                top: 90,
                bottom: 180,
                left: 0,
                right: 0,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: ClipRect(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        // YAHAN HELPER WIDGET CALL KIYA HAI
                        child: _buildCameraPreviewWithFocus(),
                      ),
                    ),
                  ),
                ),
              )
                  : Positioned(
                top: 115,
                left: 0,
                right: 0,
                child: AspectRatio(
                  aspectRatio: _getAspectRatio(),
                  child: ClipRect(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      // YAHAN HELPER WIDGET CALL KIYA HAI
                      child: _buildCameraPreviewWithFocus(),
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

              /// Status Text (Looking for document / Hold steady)
              if (isAutoDetectOn)
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.45,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        autoScanStatus,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),


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
                          if (!widget.isRetakeMode)
                            IconButton(
                              onPressed: () {
                                //showToast("Home");
                                // Yeh purani saari screens ko hata kar HomeScreen ko first page bana dega
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const HomeScreen(),
                                  ),
                                      (
                                      route) => false, // false matlab saari purani history clear
                                );
                              },
                              icon: _buildRotatedIcon(
                                Icons.home_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            )
                          else
                          // 🚨 NAYA BLOCK: Retake mode me Cross dikhega
                            IconButton(
                              onPressed: () {
                                // Retake cancel karke wapas editor me jao
                                Navigator.pop(context);
                              },
                              icon: _buildRotatedIcon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 28, // Thoda bada size acha lagega
                              ),
                            ),

                          /// Gallery
                          /// Gallery Button
                          IconButton(
                            onPressed: _pickImagesFromGallery, // Alag function yahan call ho gaya
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
                          /// Auto Detect Button
                          IconButton(
                            onPressed: _toggleAutoDetect, // Yeh naya function call karega
                            icon: _buildRotatedIcon(
                              Icons.document_scanner_outlined, // Aap chahein toh Icons.auto_awesome use kar sakte hain
                              color: isAutoDetectOn ? Colors.blueAccent : Colors.white, // ON hone par Blue
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

              /// Auto-Detect Toggle Popup (Center of screen)
              if (_showAutoDetectPopup)
                Positioned.fill(
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75), // Dark translucent background
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min, // Jitna text utna hi bada box
                        children: [
                          Text(
                            _autoDetectPopupTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _autoDetectPopupSubtitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              height: 1.4, // Line spacing
                            ),
                            textAlign: TextAlign.center,
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

      // case "Ratio":
      //   return Container(
      //     padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      //     decoration: BoxDecoration(
      //       color: Colors.black.withOpacity(0.35),
      //       borderRadius: BorderRadius.circular(30),
      //     ),
      //     child: Row(
      //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
      //       children: [
      //         const Text(
      //           "Aspect ratio",
      //           style: TextStyle(
      //             color: Colors.white,
      //             fontSize: 14,
      //             fontWeight: FontWeight.w500,
      //           ),
      //         ),
      //         Row(
      //           children: [
      //             _buildRatioOption("1:1"),
      //             const SizedBox(width: 8),
      //             _buildRatioOption("4:3"),
      //             const SizedBox(width: 8),
      //             _buildRatioOption("16:9"),
      //             const SizedBox(width: 8),
      //             _buildRatioOption("Full"),
      //           ],
      //         ),
      //       ],
      //     ),
      //   );

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
              // IconButton(
              //   onPressed: () => setState(() => activeMenu = "Ratio"),
              //   icon: _buildRotatedIcon(
              //     _getRatioIcon(),
              //     color: Colors.white,
              //     size: 26,
              //   ),
              // ),
              IconButton(
                onPressed: _flipCamera,
                icon: _buildRotatedIcon(
                  Symbols.flip_camera_android_sharp,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              if (!widget.isRetakeMode)
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

  // // Ratio menu ke options banane ke liye
  // Widget _buildRatioOption(String label) {
  //   final bool isSelected = selectedRatio == label;
  //   final Color color = isSelected ? Colors.amber : Colors.white;
  //
  //   return GestureDetector(
  //     onTap: () {
  //       setState(() {
  //         selectedRatio = label;
  //         activeMenu = "Default"; // YEH LINE MENU KO CLOSE KAREGI
  //       });
  //       //showToast("$label Ratio Selected");
  //     },
  //     child: Container(
  //       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
  //       decoration: BoxDecoration(
  //         border: Border.all(color: color, width: 1.5),
  //         borderRadius: BorderRadius.circular(6),
  //       ),
  //       child: Text(
  //         label,
  //         style: TextStyle(
  //           color: color,
  //           fontSize: 12,
  //           fontWeight: FontWeight.bold,
  //         ),
  //       ),
  //     ),
  //   );
  // }

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


class DocumentOverlayPainter extends CustomPainter {
  final Rect? documentRect;
  final Size imageSize;

  DocumentOverlayPainter(this.documentRect, this.imageSize);

  @override
  void paint(Canvas canvas, Size size) {
    if (documentRect == null) return;

    final double scaleX = size.width / imageSize.height;
    final double scaleY = size.height / imageSize.width;

    final Rect scaledRect = Rect.fromLTRB(
      documentRect!.left * scaleX,
      documentRect!.top * scaleY,
      documentRect!.right * scaleX,
      documentRect!.bottom * scaleY,
    );

    // Box ke andar ka halka blue color
    final Paint fillPaint = Paint()
      ..color = Colors.lightBlueAccent.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    // Box ka border
    final Paint borderPaint = Paint()
      ..color = Colors.lightBlueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawRect(scaledRect, fillPaint);
    canvas.drawRect(scaledRect, borderPaint);

    // FIX 4: Adobe Scan jaise 4 Corners par Blue Dots (Points)
    final Paint dotPaint = Paint()..color = Colors.blueAccent..style = PaintingStyle.fill;
    final Paint dotBorder = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.0;
    final double radius = 8.0; // Point ka size

    // Charo corners ke coordinates nikal liye
    final List<Offset> corners = [
      scaledRect.topLeft,
      scaledRect.topRight,
      scaledRect.bottomLeft,
      scaledRect.bottomRight,
    ];

    // Har corner par pehle blue dot, fir uspe white border bana do
    for (Offset corner in corners) {
      canvas.drawCircle(corner, radius, dotPaint);
      canvas.drawCircle(corner, radius, dotBorder);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}