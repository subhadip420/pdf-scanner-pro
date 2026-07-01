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
import 'camera_settings_screen.dart';
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
  //late CameraController controller;
  // 🚨 MASTER FIX: 'late' variable ko by-default value de di taaki UI kabhi crash na ho!
  late CameraController controller = CameraController(
    cameras[currentCameraIndex],
    ResolutionPreset.high,
    enableAudio: false,
    imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
  );

  XFile? lastCapturedImage;
  String selectedMode = "Document";
  final ScrollController modeController = ScrollController();

  final List<String> scanModes = ["Whiteboard", "Book", "Document", "ID Card", "Business Card", "OCR"];

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
  List<Map<String, dynamic>> capturedImagesList = [];

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

  // 🚨 FIX 1: Camera ka naya safety tracker
  bool _isCameraReady = false;

  // --- SLEEP MODE VARIABLES ---
  Timer? _sleepTimer;
  bool _isCameraSleeping = false;
// 🚨 NAYA: Multiple scan mode toggle ke liye (By default ON rakha hai)
  bool isMultiScanMode = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    // 🚨 Yahan direct start karne ke bajaye, Master helper call hoga
    _initializeCamera();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollToDocument();
    });

    _sensorSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      if (!mounted) return;
      setState(() {
        if (event.x > 6)
          _iconTurns = 0.25;
        else if (event.x < -6)
          _iconTurns = -0.25;
        else if (event.y > 6)
          _iconTurns = 0.0;
      });
    });
  }

  // 🚨 FIX 2: Camera chalu karne ka Master Helper
  Future<void> _initializeCamera() async {
    if (!mounted) return;
    setState(() => _isCameraReady = false);

    if (mounted) {
      setState(() => _isCameraReady = true);
      if (isAutoDetectOn) _startMLAutoDetect();
      _resetSleepTimer(); // 🚨 NAYA: Camera chalu hote hi 1 min ka timer shuru
    }

    controller = CameraController(
      cameras[currentCameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    try {
      await controller.initialize();
      await _applyFlashMode(selectedFlashMode);
      if (mounted) {
        setState(() => _isCameraReady = true);
        if (isAutoDetectOn) _startMLAutoDetect();
      }
    } catch (e) {
      print("Camera init error: $e");
    }
  }

  // 🚨 FIX 3: Editor me jane se pehle Camera Free karne ka logic
  Future<void> _goToEditor() async {
    setState(() => _isCameraReady = false); // Loader dikhayega

    // 1. Hardware memory release karo taaki crash na ho
    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    await controller.dispose();

    // 2. Editor screen kholo aur result ka wait karo
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DocumentEditorScreen(imageFiles: capturedImagesList)),
    );

    // 3. Jab "Keep Scanning" daba ke wapas aao, toh camera naye sire se fresh start hoga
    if (mounted) {
      await _initializeCamera();
    }
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
    _sleepTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  // --- 🚨 NAYA BLOCK: CAMERA SLEEP & WAKE LOGIC ---
  void _resetSleepTimer() {
    _sleepTimer?.cancel();

    // Agar camera pehle se so raha hai, toh timer restart mat karo
    if (_isCameraSleeping) return;

    // 1 Minute (60 seconds) ka timer set karo
    _sleepTimer = Timer(const Duration(minutes: 1), _putCameraToSleep);
  }

  Future<void> _putCameraToSleep() async {
    if (!mounted || !controller.value.isInitialized) return;

    setState(() {
      _isCameraSleeping = true;

      // 🚨 FIX 1: Sleep hone par saara ML data aur UI text reset kar do
      _detectedDocumentBox = null;
      _stableFrames = 0;
      autoScanStatus = "Looking for document...";
      isHoldingSteady = false;
    });

    // 1. Agar ML Kit Auto-detect chal raha hai toh usko roko
    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }

    // 2. Camera hardware ko temporarily pause kardo (Battery bachayega)
    await controller.pausePreview();
  }

  Future<void> _wakeUpCamera() async {
    if (!mounted || !controller.value.isInitialized) return;

    // 1. Camera hardware wapas chalu karo
    await controller.resumePreview();

    setState(() {
      _isCameraSleeping = false;
    });

    // 2. Agar auto-detect ON tha, toh ML stream wapas chalu kardo
    if (isAutoDetectOn) {
      _startMLAutoDetect();
    }

    // 3. Timer wapas 1 minute ke liye restart kardo
    _resetSleepTimer();
  }

  // 🚨 FIX: Hardware Back Button ko Handle Karne ke liye naya function
  Future<bool> _onWillPop() async {
    // 1. Agar Retake Mode hai toh normal back hone do
    if (widget.isRetakeMode) {
      return true;
    }

    // 2. Agar user ne photo le rakhi hai aur back dabata hai, toh use wapas Editor mein bhej do!
    if (capturedImagesList.isNotEmpty) {
      _goToEditor();
      return false; // App close hone se rok dega
    }

    // 3. Agar koi photo nahi hai, toh back dabane par seedha HomeScreen par le jao
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
    return false;
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
        modeController.animateTo(150, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
      }
    });
  }

  void showToast(String msg) {
    Fluttertoast.showToast(msg: msg, toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.BOTTOM);
  }

  // Function to capture the photo with countdown logic
  Future<void> _capturePhoto() async {
    // Prevent action if camera is not ready or already capturing
    // 🚨 FIX 1: Agar camera so raha hai (_isCameraSleeping), toh capture block ho jayega
    if (!controller.value.isInitialized || isCapturing || _isCameraSleeping) return;

    setState(() {
      isCapturing = true;
      activeMenu = "Default"; // Close any open menu
    });

    try {
      // Handle the timer delay with a visual countdown
      if (selectedTimer > 0) {
        for (int i = selectedTimer; i > 0; i--) {
          if (!mounted) return;
          setState(() {
            currentCountdown = i; // Update the UI with current second
          });
          // Wait for exactly 1 second
          await Future.delayed(const Duration(seconds: 1));
        }

        // Countdown finished, reset to 0 before capturing
        if (!mounted) return;
        setState(() {
          currentCountdown = 0;
        });
      }

      // Capture the picture
      final XFile photo = await controller.takePicture();

      // Replace file capture part with this:
      Map<String, dynamic>? cropData = await _cropTo43(photo.path);
      File finalCroppedFile = cropData != null ? cropData['file'] : File(photo.path);

      // 🚨 FIX 1: RETAKE LOGIC (Manual Camera Click) 🚨
      if (widget.isRetakeMode) {
        setState(() => isCapturing = false);
        Navigator.pop(context, File(photo.path)); // Seedha photo wapas bhej do
        return; // Niche ka code nahi chalega
      }

      /// Update the state with the new photo and increment the counter
      setState(() {
        lastCapturedImage = photo;

        capturedImagesList.add(<String, dynamic>{
          'original': File(photo.path),
          'cropped': finalCroppedFile,
          // 🚨 MAGIC: Coordinates list me chhupe rahenge Editor ke liye!
          if (cropData != null) 'crop_ratios': cropData['ratios'],
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

  // 🚨 MASTER FIX: Strict 4:3 Smart Crop (Without extra options)
  Future<Map<String, dynamic>?> _cropTo43(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    img.Image? originalImage = img.decodeImage(bytes);

    if (originalImage == null) return null;

    // Camera ki photo ko seedha karna zaroori hai
    originalImage = img.bakeOrientation(originalImage);

    int origW = originalImage.width;
    int origH = originalImage.height;
    double origRatio = origW / origH;

    // 🚨 YAHAN HAI ASLI JADOO: Check karo photo RAM me landscape hai ya portrait
    bool isLandscape = origW > origH;

    // Seedha 4:3 logic lagao: Agar landscape hai toh 4/3, portrait hai toh 3/4
    double targetRatio = isLandscape ? (4 / 3) : (3 / 4);

    // Agar image pehle se lagbhag 4:3 hai, toh skip kardo
    if ((origRatio - targetRatio).abs() < 0.05) return null;

    int cropW = origW;
    int cropH = origH;
    int x = 0;
    int y = 0;

    if (origRatio > targetRatio) {
      // Image expected se zyada chodi (wide) hai, sides (left/right) kaato
      cropW = (origH * targetRatio).toInt();
      x = (origW - cropW) ~/ 2;
    } else {
      // Image expected se zyada lambi (tall) hai, upar-neeche (top/bottom) kaato!
      cropH = (origW / targetRatio).toInt();
      y = (origH - cropH) ~/ 2;
    }

    img.Image croppedImage = img.copyCrop(originalImage, x: x, y: y, width: cropW, height: cropH);

    final String newPath = filePath.replaceAll('.jpg', '_manualcrop_${DateTime.now().millisecondsSinceEpoch}.jpg');
    final newFile = File(newPath);
    await newFile.writeAsBytes(img.encodeJpg(croppedImage, quality: 85));

    return {
      'file': newFile,
      'ratios': {
        'left': x / origW,
        'top': y / origH,
        'right': 1.0 - ((x + cropW) / origW),
        'bottom': 1.0 - ((y + cropH) / origH),
      },
    };
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
      _focusTimer = Timer(const Duration(milliseconds: 1200), () {
        // Time 1.5s se 1.2s kiya for fast response
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
    final double previewWidth = controller.value.previewSize?.height ?? 1080;
    final double previewHeight = controller.value.previewSize?.width ?? 1920;

    // 🚨 FIX 3: Yahan se GestureDetector hata diya kyunki ab poori screen hi touch track kar rahi hai
    if (_isCameraSleeping) {
      return SizedBox(
        width: previewWidth,
        height: previewHeight,
        child: Container(
          color: Colors.black, // Sirf preview area black hoga
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bedtime_outlined, color: Colors.white54, size: previewWidth * 0.12),
                SizedBox(height: previewHeight * 0.02),
                Text(
                  "Tap anywhere to wake up", // 🚨 Text thoda update kar diya
                  style: TextStyle(color: Colors.white70, fontSize: previewWidth * 0.045, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      );
    }

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

                // YEH NAYI LINE: Real-time Blue Overlay
                if (_detectedDocumentBox != null && isAutoDetectOn)
                  Positioned.fill(
                    // FIX 4: Isko Positioned.fill me wrap kiya
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
                      width: 80, // Size 50 se badhakar 80 kar diya
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
        final imageRotation =
            InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation90deg;

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

      // Replace file capture part with this:
      Map<String, dynamic>? cropData = await _autoCropImage(photo.path, boxToCrop);
      File finalFile = cropData != null ? cropData['file'] : File(photo.path);

      // 🚨 FIX 3: RETAKE LOGIC (AI Auto-Capture) 🚨
      if (widget.isRetakeMode) {
        setState(() {
          isCapturing = false;
          _detectedDocumentBox = null;
        });
        Navigator.pop(context, finalFile); // Auto crop wali photo wapas bhej do
        return;
      }

      capturedImagesList.add(<String, dynamic>{
        'original': File(photo.path),
        'cropped': finalFile,
        // 🚨 MAGIC: Coordinates list me chhupe rahenge Editor ke liye!
        if (cropData != null) 'crop_ratios': cropData['ratios'],
      });

      capturedPhotosCount = capturedImagesList.length;

      setState(() {
        lastCapturedImage = photo; // <-- YEH NAYI LINE ADD KI HAI
        capturedPhotosCount = capturedImagesList.length; // Count bhi yahi update kar diya
        isCapturing = false;
        isHoldingSteady = false;
        _stableFrames = 0;
        _detectedDocumentBox = null;
      });

      // if (mounted) {
      //   _goToEditor(); // 🚨 Master Helper call kiya
      // }

      if (mounted) {
        // 🚨 FIX 3A: Check karega ki Multi-scan switch ka status kya hai
        if (isMultiScanMode) {
          // ON hai toh rukega aur agla page scan karega
          showToast("Page $capturedPhotosCount captured. Scanning next...");
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted && isAutoDetectOn && !_isCameraSleeping) {
              _startMLAutoDetect();
            }
          });
        } else {
          // OFF hai toh 1st click me seedha Editor!
          _goToEditor();
        }
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
        _autoDetectPopupSubtitle =
            "We'll find the borders and take the photo for you. You can adjust or take other quick actions.";
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

  // 🚨 FIX 1: Scanner ka Auto Crop ab Exact Ratios bhi return karega
  Future<Map<String, dynamic>?> _autoCropImage(String originalPath, Rect? detectionBox) async {
    if (detectionBox == null || !controller.value.isInitialized) return null;

    try {
      final file = File(originalPath);
      final bytes = await file.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) return null;

      originalImage = img.bakeOrientation(originalImage);

      final double streamWidth = controller.value.previewSize!.height;
      final double streamHeight = controller.value.previewSize!.width;
      final double scaleX = originalImage.width / streamWidth;
      final double scaleY = originalImage.height / streamHeight;

      int x = (detectionBox.left * scaleX).toInt();
      int y = (detectionBox.top * scaleY).toInt();
      int w = (detectionBox.width * scaleX).toInt();
      int h = (detectionBox.height * scaleY).toInt();

      x = x.clamp(0, originalImage.width);
      y = y.clamp(0, originalImage.height);
      w = w.clamp(1, originalImage.width - x);
      h = h.clamp(1, originalImage.height - y);

      img.Image croppedImage = img.copyCrop(originalImage, x: x, y: y, width: w, height: h);

      final String croppedPath = originalPath.replaceAll(
        '.jpg',
        '_autocrop_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final croppedFile = File(croppedPath);
      await croppedFile.writeAsBytes(img.encodeJpg(croppedImage, quality: 100));

      // 🚨 NAYA: File ke sath exact map return kar rahe hain
      return {
        'file': croppedFile,
        'ratios': {
          'left': x / originalImage.width,
          'top': y / originalImage.height,
          'right': 1.0 - ((x + w) / originalImage.width),
          'bottom': 1.0 - ((y + h) / originalImage.height),
        },
      };
    } catch (e) {
      print("Auto Crop Error: $e");
      return null;
    }
  }

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

      // 🚨 FIX: Gallery me jane se pehle ML Kit background processing rok do taaki crash na ho
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
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
          capturedImagesList.add(<String, dynamic>{
            // 🚨 Yahan <String, dynamic> add kora hoyeche
            'original': file,
            'cropped': file,
          });
        }
        capturedPhotosCount = capturedImagesList.length;
      });

      showToast("${selectedFiles.length} images imported serial wise");

      if (mounted) {
        _goToEditor(); // 🚨 Master Helper call kiya
      }
    } catch (e) {
      print("Gallery Error: $e");
      showToast("Error importing images");
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🚨 FIX 4: Jab tak memory release/reload na ho jaye, safe loading screen dikhao
    if (!_isCameraReady || !controller.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF2C2C2C),
        body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
      );
    }

    // return Scaffold(
    return WillPopScope(
      onWillPop: _onWillPop,

      // 🚨 FIX: Listener laga diya. User screen par kahin bhi tap karega toh timer reset hoga
      child: Listener(
        onPointerDown: (_) {
          if (!_isCameraSleeping) {
            _resetSleepTimer(); // Activity hui, timer wapas 0 se shuru!
          }
        },
        child: Scaffold(
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        // Yahan humne simply naya function call kar diya
                        child: _buildTopBarContent(),
                      ),
                    ),
                  ),

                  /// Status Text (Looking for document / Hold steady)
                  if (isAutoDetectOn && !_isCameraSleeping)
                    Positioned(
                      top: MediaQuery.of(context).size.height * 0.45,
                      left: 0,
                      right: 0,
                      child: Center(
                        // 🚨 FIX: Yahan bhi AnimatedRotation laga diya
                        child: AnimatedRotation(
                          turns: _iconTurns,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              autoScanStatus,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.normal),
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
                          ScrollSnapList(
                            itemBuilder: (_, index) {
                              final bool isSelected = index == selectedIndex;

                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                alignment: Alignment.center,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  alignment: Alignment.center,
                                  child: Text(
                                    scanModes[index],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isSelected ? Colors.blue : Colors.white,
                                      fontSize: isSelected ? 15 : 13,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
                        padding: const EdgeInsets.only(left: 12, right: 12, bottom: 20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                                      (route) => false, // false matlab saari purani history clear
                                    );
                                  },
                                  icon: _buildRotatedIcon(Icons.home_rounded, color: Colors.white, size: 24),
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
                                icon: _buildRotatedIcon(Icons.photo_library_rounded, color: Colors.white, size: 24),
                              ),

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

                                    // Blue Animated Progress Ring (Shows only during Timer countdown)
                                    if (isCapturing && selectedTimer > 0)
                                      SizedBox(
                                        width: 56,
                                        height: 56,
                                        child: TweenAnimationBuilder<double>(
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
                                      )
                                    // 🚨 NAYA: Auto-Detect Progress Ring (Fills up as document stays stable!)
                                    else if (isAutoDetectOn && _stableFrames > 0)
                                      SizedBox(
                                        width: 56,
                                        height: 56,
                                        child: CircularProgressIndicator(
                                          // MAGIC: stableFrames 10 tak jata hai, isko 10 se divide kiya toh 0.0 se 1.0 tak progress ban gaya
                                          value: (_stableFrames / 10.0).clamp(0.0, 1.0),
                                          strokeWidth: 4,
                                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                                          backgroundColor: Colors.transparent,
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
                                          // 🚨 FIX: Jab document 'Hold steady' par aayega, toh center button grey ho jayega (Busy state)
                                          color: (isCapturing || isHoldingSteady) ? Colors.grey : Colors.white,
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
                                  Icons.document_scanner_outlined,
                                  // Aap chahein toh Icons.auto_awesome use kar sakte hain
                                  color: isAutoDetectOn ? Colors.blueAccent : Colors.white, // ON hone par Blue
                                  size: 24,
                                ),
                              ),

                              /// Last Photo with Counter Badge
                              GestureDetector(
                                onTap: () {
                                  if (capturedPhotosCount > 0) {
                                    _goToEditor(); // 🚨 Master Helper call kiya
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
                                              child: Image.file(File(lastCapturedImage!.path), fit: BoxFit.cover),
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
                        // 🚨 FIX: Yahan AnimatedRotation lagaya taaki popup bhi ghume
                        child: AnimatedRotation(
                          turns: _iconTurns,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 40),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.45), // Dark translucent background
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
                                    fontSize: 15,
                                    height: 1.4, // Line spacing
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 🚨 FIX 2: GLOBAL INVISIBLE SHIELD
                  // Jab camera so raha hoga, ye invisible layer poori screen ko cover kar legi.
                  // Koi bhi touch seedha '_wakeUpCamera' ko trigger karega aur buttons ko block karega.
                  if (_isCameraSleeping)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _wakeUpCamera, // Kahin bhi tap karo, camera jaag jayega
                        child: Container(
                          color: Colors.transparent, // Invisible hai, par touches ko aage jaane nahi dega!
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper widget to animate icon rotation based on phone physical orientation
  Widget _buildRotatedIcon(IconData iconData, {Color color = Colors.white, double size = 26}) {
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
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.35), borderRadius: BorderRadius.circular(30)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Flash",
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
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

      case "Timer":
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.35), borderRadius: BorderRadius.circular(30)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Timer",
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
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
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.35), borderRadius: BorderRadius.circular(30)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                onPressed: () => setState(() => activeMenu = "Flash"),
                icon: _buildRotatedIcon(_getFlashIcon(), color: Colors.white, size: 26),
              ),


              IconButton(
                onPressed: _flipCamera,
                icon: _buildRotatedIcon(Symbols.flip_camera_android_sharp, color: Colors.white, size: 26),
              ),

              // 🚨 NAYA: Multiple Scan Icon (Sirf normal mode me dikhega)
              if (!widget.isRetakeMode)
                IconButton(
                  onPressed: () {
                    setState(() {
                      isMultiScanMode = !isMultiScanMode; // ON ko OFF, OFF ko ON karega
                    });
                    showToast(isMultiScanMode ? "Multi-scan ON" : "Single-scan ON");
                  },
                  icon: _buildRotatedIcon(
                    // ON hone par overlapping pages, OFF hone par single page
                    isMultiScanMode ? Icons.file_copy_rounded : Icons.insert_drive_file_outlined,
                    color: isMultiScanMode ? Colors.blueAccent : Colors.white, // ON hone par Blue dikhega
                    size: 24,
                  ),
                ),

              /// YAHAN TIMER ICON DYNAMIC KAR DIYA
              IconButton(
                onPressed: () => setState(() => activeMenu = "Timer"),
                icon: _buildRotatedIcon(_getTimerIcon(), color: Colors.white, size: 26),
              ),

              if (!widget.isRetakeMode)
                IconButton(
                  //onPressed: () => showToast("Settings"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CameraSettingsScreen(),
                      ),
                    );
                  },
                  icon: _buildRotatedIcon(Symbols.segment_sharp, color: Colors.white, size: 26),
                ),
            ],
          ),
        );
    }
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
    // final Paint fillPaint = Paint()
    //   ..color = Colors.lightBlueAccent.withOpacity(0.2)
    //   ..style = PaintingStyle.fill;

    // Box ka border
    final Paint borderPaint = Paint()
      ..color = Colors.lightBlueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    //canvas.drawRect(scaledRect, fillPaint);
    canvas.drawRect(scaledRect, borderPaint);

    // FIX 4: Adobe Scan jaise 4 Corners par Blue Dots (Points)
    final Paint dotPaint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.fill;
    final Paint dotBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
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
