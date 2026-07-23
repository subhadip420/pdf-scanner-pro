import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gal/gal.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import '../../main.dart';
import 'dart:io';
import 'package:scroll_snap_list/scroll_snap_list.dart';
import 'package:flutter/services.dart'; // For locking orientation
import 'package:sensors_plus/sensors_plus.dart'; // For accelerometer
import 'dart:async';
import 'package:image/image.dart' as img;
import 'camera_settings_screen.dart';
import 'custom_dialog.dart';
import 'custom_gallery_screen.dart';
import 'document_editor_screen.dart';
import 'home_screen.dart'; // For StreamSubscription
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:flutter/foundation.dart'; // WriteBuffer ke liye

class ScannerScreen extends StatefulWidget {
  final List<dynamic>? initialImages;
  final bool isRetakeMode;
  final bool isOpenedFromEditor;

  const ScannerScreen({Key? key, this.isRetakeMode = false, this.initialImages, required this.isOpenedFromEditor})
    : super(key: key);

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  late CameraController controller;

  XFile? lastCapturedImage;
  String selectedMode = "Document";
  final ScrollController modeController = ScrollController();

  final List<String> scanModes = ["Document", "QR Scanner"];
  int selectedIndex = 0;

  final BarcodeScanner _barcodeScanner = BarcodeScanner();
  String? _detectedQrCode;

  bool isSelectingRatio = false;

  bool isSelectingFlash = false;
  String selectedFlashMode = "Off";

  String activeMenu = "Default";
  int selectedTimer = 0;
  int currentCameraIndex = 0;

  StreamSubscription<AccelerometerEvent>? _sensorSubscription;
  double _iconTurns = 0.0;

  int capturedPhotosCount = 0;
  bool isCapturing = false;
  int currentCountdown = 0;
  List<Map<String, dynamic>> capturedImagesList = [];

  Offset? _focusPointPosition;
  bool _showFocusIndicator = false;
  Timer? _focusTimer;

  // Real ML Auto-Detect Variables
  bool isAutoDetectOn = true;
  String autoScanStatus = "Looking for document...";
  bool isHoldingSteady = false;

  final TextRecognizer _textRecognizer = TextRecognizer();
  bool _isProcessingImage = false;
  Rect? _detectedDocumentBox;
  int _stableFrames = 0;

  // Auto-Detect Popup Variables
  bool _showAutoDetectPopup = false;
  String _autoDetectPopupTitle = "";
  String _autoDetectPopupSubtitle = "";
  Timer? _popupTimer;

  bool _isCameraReady = false;

  // --- SLEEP MODE VARIABLES ---
  Timer? _sleepTimer;
  bool _isCameraSleeping = false;

  bool isMultiScanMode = true;
  Rect? _detectedQrBox;

  bool isGridOn = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialImages != null) {
      for (var item in widget.initialImages!) {
        capturedImagesList.add(Map<String, dynamic>.from(item));
      }
      capturedPhotosCount = capturedImagesList.length;
      final lastItem = capturedImagesList.last;
      if (lastItem['original'] != null) {
        lastCapturedImage = XFile((lastItem['original'] as File).path);
      }
    }

    _loadSettings();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

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

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    _popupTimer?.cancel();
    _textRecognizer.close();
    _barcodeScanner.close();

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

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        isGridOn = prefs.getBool('show_grid') ?? false;
        isAutoDetectOn = prefs.getBool('pref_auto_detect_always_on') ?? true;
      });
    }
  }

  Future<void> _triggerVibration({bool isLight = true}) async {
    final prefs = await SharedPreferences.getInstance();
    // Setting check karo, default ON (true) rahega
    final isHapticOn = prefs.getBool('haptic_feedback') ?? true;

    if (isHapticOn) {
      if (isLight) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    }
  }

  Future<void> _initializeCamera() async {
    if (!mounted) return;

    // Reset status
    setState(() {
      _isCameraReady = false;
      _isCameraSleeping = false;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 300));

      if (cameras.isEmpty) {
        cameras = await availableCameras();
      }
      if (cameras.isEmpty) {
        debugPrint("Koi camera hardware nahi mila!");
        return;
      }
      controller = CameraController(
        cameras[currentCameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      await _applyFlashMode(selectedFlashMode);

      if (mounted) {
        setState(() => _isCameraReady = true);
        if (isAutoDetectOn) _startMLAutoDetect();
        _resetSleepTimer();
      }
    } catch (e) {
      debugPrint("Camera init error: $e");
    }
  }

  Future<void> _goToEditor() async {
    setState(() => _isCameraReady = false);
    if (selectedFlashMode != "Off") {
      await _applyFlashMode("Off");
      selectedFlashMode = "Off";
    }

    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    await controller.dispose();

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentEditorScreen(imageFiles: capturedImagesList, isFromGallery: false),
      ),
    );

    if (mounted) {
      setState(() {
        capturedPhotosCount = capturedImagesList.length;
        if (capturedImagesList.isNotEmpty) {
          lastCapturedImage = XFile((capturedImagesList.last['original'] as File).path);
        } else {
          lastCapturedImage = null;
        }
      });
      await _initializeCamera();
    }
  }

  void _resetSleepTimer() {
    _sleepTimer?.cancel();

    if (_isCameraSleeping) return;
    _sleepTimer = Timer(const Duration(minutes: 1), _putCameraToSleep);
  }

  Future<void> _putCameraToSleep() async {
    if (!mounted || !controller.value.isInitialized) return;

    setState(() {
      _isCameraSleeping = true;

      _detectedDocumentBox = null;
      _stableFrames = 0;
      autoScanStatus = selectedIndex == 1 ? "Looking for QR code..." : "Looking for document...";
      isHoldingSteady = false;
    });

    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }

    await controller.pausePreview();
  }

  Future<void> _wakeUpCamera() async {
    if (!mounted || !controller.value.isInitialized) return;

    await controller.resumePreview();

    setState(() {
      _isCameraSleeping = false;
    });
    if (selectedIndex == 1 || (selectedIndex == 0 && isAutoDetectOn)) {
      _startMLAutoDetect();
    }
    _resetSleepTimer();
  }

  bool get _hasNewCaptures {
    int initialCount = widget.initialImages?.length ?? 0;
    return capturedImagesList.length > initialCount;
  }

  Future<bool> _onWillPop() async {
    if (widget.isRetakeMode) {
      return true;
    }

    if (_hasNewCaptures) {
      await _handleBackButton();
      return false;
    }
    Navigator.pop(context);
    return false;
  }

  Future<void> _handleBackButton() async {
    if (_hasNewCaptures) {
      bool shouldDiscard = await showCustomConfirmDialog(
        context,
        title: "Discard new scans?",
        message: "This will discard the newly captured scans. Are you sure?",
        positiveBtnText: "Discard",
        negativeBtnText: "Cancel",
        positiveBtnColor: Colors.redAccent,
      );

      if (shouldDiscard && context.mounted) {
        Navigator.pop(context);
      }
    } else {
      Navigator.pop(context);
    }
  }

  IconData _getFlashIcon([String? mode]) {
    final String currentMode = mode ?? selectedFlashMode;
    switch (currentMode) {
      case "On":
        return Symbols.flash_on_sharp;
      case "Auto":
        return Symbols.flash_auto_sharp;
      case "Torch":
        return Symbols.highlight_sharp;
      case "Off":
      default:
        return Symbols.flash_off_sharp;
    }
  }

  IconData _getTimerIcon([int? timer]) {
    final int currentTimer = timer ?? selectedTimer;
    switch (currentTimer) {
      case 3:
        return Symbols.timer_3_alt_1;
      case 10:
        return Symbols.timer_10_alt_1;
      case 0:
      default:
        return Symbols.timer;
    }
  }

  Future<void> _flipCamera() async {
    if (cameras.length < 2) {
      showToast("Secondary camera not available");
      return;
    }
    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }

    if (mounted) {
      setState(() {
        _isCameraReady = false;
        _detectedDocumentBox = null;
        _detectedQrBox = null;
        _stableFrames = 0;
        isHoldingSteady = false;
      });
    }
    currentCameraIndex = currentCameraIndex == 0 ? 1 : 0;
    final CameraDescription newCamera = cameras[currentCameraIndex];
    await controller.dispose();

    controller = CameraController(
      newCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    try {
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);

      if (mounted) {
        setState(() {
          _isCameraReady = true;
          selectedFlashMode = "Off";
        });
        _startMLAutoDetect();
      }
    } catch (e) {
      showToast("Error switching camera");
      if (mounted) {
        setState(() => _isCameraReady = true);
      }
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

  Future<void> _capturePhoto() async {
    if (!controller.value.isInitialized || isCapturing || _isCameraSleeping) return;

    setState(() {
      isCapturing = true;
      activeMenu = "Default";
    });

    try {
      if (selectedTimer > 0) {
        for (int i = selectedTimer; i > 0; i--) {
          if (!mounted) return;
          setState(() {
            currentCountdown = i;
          });
          await Future.delayed(const Duration(seconds: 1));
        }
        if (!mounted) return;
        setState(() {
          currentCountdown = 0;
        });
      }

      await _triggerVibration(isLight: false);
      final XFile photo = await controller.takePicture();

      ///TURANT GALLERY ME SAVE KARNE KA LOGIC
      // ==========================================
      try {
        final prefs = await SharedPreferences.getInstance();
        bool shouldSaveToGallery = prefs.getBool('pref_save_to_gallery') ?? false;
        if (shouldSaveToGallery) {
          await Gal.putImage(photo.path);
        }
      } catch (e) {
        debugPrint("Gallery Save Error: $e");
      }
      // ==========================================

      Map<String, dynamic>? cropData = await _cropTo43(photo.path);
      File finalCroppedFile = cropData != null ? cropData['file'] : File(photo.path);

      if (widget.isRetakeMode) {
        setState(() => isCapturing = false);
        if (selectedFlashMode == "Torch" || selectedFlashMode == "On") {
          await _applyFlashMode("Off");
          if (mounted) setState(() => selectedFlashMode = "Off");
        }
        Navigator.pop(context, File(photo.path)); // Seedha photo wapas bhej do
        return; // Niche ka code nahi chalega
      }

      /// Update the state with the new photo and increment the counter
      setState(() {
        lastCapturedImage = photo;

        capturedImagesList.add(<String, dynamic>{
          'original': File(photo.path),
          'cropped': finalCroppedFile,
          if (cropData != null) 'crop_ratios': cropData['ratios'],
        });

        capturedPhotosCount = capturedImagesList.length;
        isCapturing = false;
      });
    } catch (e) {
      setState(() {
        isCapturing = false;
        currentCountdown = 0;
      });
      showToast("Error capturing photo");
    }
  }

  Future<Map<String, dynamic>?> _cropTo43(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    img.Image? originalImage = img.decodeImage(bytes);

    if (originalImage == null) return null;
    originalImage = img.bakeOrientation(originalImage);

    int origW = originalImage.width;
    int origH = originalImage.height;
    double origRatio = origW / origH;

    bool isLandscape = origW > origH;
    double targetRatio = isLandscape ? (4 / 3) : (3 / 4);
    if ((origRatio - targetRatio).abs() < 0.05) return null;

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

  Future<void> _setFocusPoint(TapUpDetails details, BoxConstraints constraints) async {
    if (!controller.value.isInitialized) return;

    final double x = details.localPosition.dx / constraints.maxWidth;
    final double y = details.localPosition.dy / constraints.maxHeight;
    final Offset focusPoint = Offset(x, y);

    try {
      if (mounted) {
        setState(() {
          _focusPointPosition = details.localPosition;
          _showFocusIndicator = true;
        });
      }
      await Future.wait([
        if (controller.value.focusPointSupported) controller.setFocusPoint(focusPoint),
        if (controller.value.exposurePointSupported) controller.setExposurePoint(focusPoint),
      ]);

      _focusTimer?.cancel();
      _focusTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) {
          setState(() => _showFocusIndicator = false);
        }
      });
    } catch (e) {
      print("Error setting focus: $e");
    }
  }

  Widget _buildCameraPreviewWithFocus() {
    final double previewWidth = controller.value.previewSize?.height ?? 1080;
    final double previewHeight = controller.value.previewSize?.width ?? 1920;

    if (_isCameraSleeping) {
      return SizedBox(
        width: previewWidth,
        height: previewHeight,
        child: Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bedtime_outlined, color: Colors.white54, size: previewWidth * 0.12),
                SizedBox(height: previewHeight * 0.02),
                Text(
                  "Tap anywhere to wake up",
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
                if (_detectedDocumentBox != null && isAutoDetectOn && selectedIndex == 0)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: DocumentOverlayPainter(
                        _detectedDocumentBox,
                        Size(controller.value.previewSize!.width, controller.value.previewSize!.height),
                      ),
                    ),
                  ),

                if (_detectedQrBox != null && selectedIndex == 1)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: QrOverlayPainter(
                        _detectedQrBox,
                        Size(controller.value.previewSize!.width, controller.value.previewSize!.height),
                      ),
                    ),
                  ),

                if (_showFocusIndicator && _focusPointPosition != null)
                  Positioned(
                    left: _focusPointPosition!.dx - 40,
                    top: _focusPointPosition!.dy - 40,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(border: Border.all(color: Colors.amber, width: 2.0)),
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
    if (!controller.value.isInitialized) return;
    if (selectedIndex == 0 && !isAutoDetectOn) return;
    if (controller.value.isStreamingImages) return;

    setState(() {
      autoScanStatus = selectedIndex == 1 ? "Looking for QR code..." : "Looking for document...";
      isHoldingSteady = false;
      _stableFrames = 0;
    });

    controller.startImageStream((CameraImage image) async {
      if (_isProcessingImage || isCapturing) return;
      if (selectedIndex == 0 && !isAutoDetectOn) return;
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

        final inputImageFormat = Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888;

        final inputImageData = InputImageMetadata(
          size: imageSize,
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: image.planes[0].bytesPerRow,
        );

        final inputImage = InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
        if (selectedIndex == 0) {
          // ==========================================
          /// MODE 0: DOCUMENT SCANNER (Purana Logic)
          // ==========================================
          final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
          if (!mounted || selectedIndex != 0) return;

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

                if (_stableFrames > 3 && !isHoldingSteady) {
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
            if (mounted) {
              if (_detectedDocumentBox != null || _stableFrames != 0 || autoScanStatus != "Looking for document...") {
                setState(() {
                  _detectedDocumentBox = null;
                  _stableFrames = 0;
                  autoScanStatus = "Looking for document...";
                  isHoldingSteady = false;
                });
              }
            }
          }
        } else if (selectedIndex == 1) {
          // ==========================================
          /// MODE 1: QR & BARCODE SCANNER (Naya Logic)
          // ==========================================
          final List<Barcode> barcodes = await _barcodeScanner.processImage(inputImage);
          if (!mounted || selectedIndex != 1) return;

          if (barcodes.isNotEmpty) {
            final Barcode barcode = barcodes.first;
            final String? rawValue = barcodes.first.rawValue;
            if (mounted) {
              setState(() {
                _detectedQrBox = barcode.boundingBox;
              });
            }
            if (rawValue != null && rawValue != _detectedQrCode) {
              if (mounted) {
                setState(() {
                  _detectedQrCode = rawValue; // State update ki
                  autoScanStatus = "";
                });
                HapticFeedback.lightImpact();
              }
            }
          } else {
            if (mounted) {
              if (_detectedQrBox != null || (autoScanStatus != "Looking for QR code..." && _detectedQrCode == null)) {
                setState(() {
                  _detectedQrBox = null;
                  if (_detectedQrCode == null) {
                    autoScanStatus = "Looking for QR code...";
                  }
                });
              }
            }
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
      await _triggerVibration(isLight: false);
      Rect? boxToCrop = _detectedDocumentBox;
      final XFile photo = await controller.takePicture();

      // ==========================================
      /// AUTO-CAPTURE KI PHOTO GALLERY ME SAVE KARNE KA LOGIC
      // ==========================================
      try {
        final prefs = await SharedPreferences.getInstance();
        bool shouldSaveToGallery = prefs.getBool('pref_save_to_gallery') ?? false;

        if (shouldSaveToGallery) {
          await Gal.putImage(photo.path);
        }
      } catch (e) {
        debugPrint("Auto Gallery Save Error: $e");
      }
      // ==========================================

      Map<String, dynamic>? cropData = await _autoCropImage(photo.path, boxToCrop);
      File finalFile = cropData != null ? cropData['file'] : File(photo.path);

      /// RETAKE LOGIC (AI Auto-Capture)
      if (widget.isRetakeMode) {
        setState(() {
          isCapturing = false;
          _detectedDocumentBox = null;
        });
        if (selectedFlashMode == "Torch" || selectedFlashMode == "On") {
          await _applyFlashMode("Off");
          if (mounted) setState(() => selectedFlashMode = "Off");
        }

        Navigator.pop(context, finalFile);
        return;
      }

      capturedImagesList.add(<String, dynamic>{
        'original': File(photo.path),
        'cropped': finalFile,
        if (cropData != null) 'crop_ratios': cropData['ratios'],
      });

      capturedPhotosCount = capturedImagesList.length;

      setState(() {
        lastCapturedImage = photo;
        capturedPhotosCount = capturedImagesList.length;
        isCapturing = false;
        isHoldingSteady = false;
        _stableFrames = 0;
        _detectedDocumentBox = null;
      });

      if (mounted) {
        if (isMultiScanMode) {
          showToast("Page $capturedPhotosCount captured. Scanning next...");
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted && isAutoDetectOn && !_isCameraSleeping) {
              _startMLAutoDetect();
            }
          });
        } else {
          _goToEditor();
        }
      }
    } catch (e) {
      setState(() => isCapturing = false);
    }
  }

  Future<void> _toggleAutoDetect() async {
    setState(() {
      isAutoDetectOn = !isAutoDetectOn;
      _showAutoDetectPopup = true;

      if (isAutoDetectOn) {
        _autoDetectPopupTitle = "Auto-capture on";
        _autoDetectPopupSubtitle =
            "We'll find the borders and take the photo for you. You can adjust or take other quick actions.";
      } else {
        _autoDetectPopupTitle = "Auto-capture off";
        _autoDetectPopupSubtitle = "Scan multiple pages faster. Just tap the photo button, and adjust borders later.";

        isHoldingSteady = false;
        autoScanStatus = "Looking for document...";
        _detectedDocumentBox = null;
        _stableFrames = 0;
      }

      _popupTimer?.cancel();
      _popupTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showAutoDetectPopup = false;
          });
        }
      });
    });

    if (isAutoDetectOn) {
      _startMLAutoDetect();
    } else {
      if (controller.value.isStreamingImages) {
        try {
          await controller.stopImageStream();
        } catch (e) {
          print("Error stopping stream: $e");
        }
      }
    }
  }

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

      if (selectedFlashMode != "Off") {
        await _applyFlashMode("Off");
        setState(() => selectedFlashMode = "Off");
      }

      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }

      if (mounted) {
        setState(() {
          _detectedDocumentBox = null;
          _stableFrames = 0;
          isHoldingSteady = false;
          if (selectedIndex == 0 && isAutoDetectOn) {
            autoScanStatus = "Looking for document...";
          }
        });
      }

      final List<File>? selectedFiles = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CustomGalleryScreen()),
      );

      if (selectedFiles == null || selectedFiles.isEmpty) {
        if (mounted) {
          setState(() {
            _isCameraSleeping = false;
          });
          _resetSleepTimer();
          await _wakeUpCamera();
          if (isAutoDetectOn && selectedIndex == 0) {
            _startMLAutoDetect();
          }
        }
        return;
      }

      if (widget.isRetakeMode) {
        Navigator.pop(context, selectedFiles.first);
        return;
      }

      setState(() {
        for (var file in selectedFiles) {
          capturedImagesList.add(<String, dynamic>{'original': file, 'cropped': file});
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
    if (!_isCameraReady) {
      return const Scaffold(
        backgroundColor: Color(0xFF2C2C2C),
        body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
      );
    }

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    // return Scaffold(
    return WillPopScope(
      onWillPop: _onWillPop,

      child: Listener(
        onPointerDown: (_) {
          if (!_isCameraSleeping) {
            _resetSleepTimer();
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF2C2C2C),
          body: GestureDetector(
            onTap: () {
              if (activeMenu != "Default") {
                setState(() {
                  activeMenu = "Default";
                });
              }
            },

            behavior: HitTestBehavior.translucent,
            child: SizedBox.expand(
              child: Stack(
                children: [
                  /// MASTER FIX: Camera Preview + Perfect Grid Alignment
                  Positioned(
                    top: 115,
                    left: 0,
                    right: 0,
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRect(
                              child: FittedBox(
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                child: _buildCameraPreviewWithFocus(),
                              ),
                            ),
                          ),

                          if (isGridOn && !_isCameraSleeping)
                            Positioned.fill(
                              child: IgnorePointer(child: CustomPaint(painter: GridOverlayPainter())),
                            ),
                        ],
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
                        child: _buildTopBarContent(),
                      ),
                    ),
                  ),

                  /// Status Text (Looking for document / Hold steady / Looking for QR)
                  if (isAutoDetectOn && !_isCameraSleeping && autoScanStatus.isNotEmpty)
                    Positioned(
                      top: MediaQuery.of(context).size.height * 0.45,
                      left: 0,
                      right: 0,
                      child: Center(
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
                            initialIndex: 0,
                            dynamicItemSize: true,
                            onItemFocus: (index) async {
                              await _triggerVibration();
                              setState(() {
                                selectedIndex = index;

                                if (selectedIndex == 1) {
                                  // =====================
                                  /// QR SCANNER MODE
                                  // =====================
                                  _detectedDocumentBox = null;
                                  _stableFrames = 0;
                                  isHoldingSteady = false;
                                  autoScanStatus = "Looking for QR code...";
                                  if (!controller.value.isStreamingImages) {
                                    _startMLAutoDetect();
                                  }
                                } else {
                                  // =====================
                                  /// DOCUMENT MODE
                                  // =====================
                                  _detectedQrCode = null;
                                  _detectedQrBox = null;

                                  if (isAutoDetectOn) {
                                    autoScanStatus = "Looking for document...";
                                    if (!controller.value.isStreamingImages) {
                                      _startMLAutoDetect();
                                    }
                                  } else {
                                    autoScanStatus = "";
                                    if (controller.value.isStreamingImages) {
                                      controller.stopImageStream();
                                    }
                                  }
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  /// NAYA: GOOGLE LENS JAISE QR RESULT POPUP
                  if (selectedIndex == 1 && _detectedQrCode != null)
                    Positioned(
                      bottom: 220,
                      left: 20,
                      right: 20,
                      child: AnimatedRotation(
                        turns: _iconTurns,
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, spreadRadius: 2),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.qr_code_scanner_rounded, color: Colors.blueAccent),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      "QR Code Detected",
                                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                                    //onPressed: () => setState(() => _detectedQrCode = null),
                                    onPressed: () async {
                                      await _triggerVibration();
                                      _detectedQrCode = null;
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _detectedQrCode!,
                                style: TextStyle(color: Colors.grey.shade800, fontSize: 14),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () async {
                                      await _triggerVibration();
                                      Clipboard.setData(ClipboardData(text: _detectedQrCode!));
                                      showToast("Copied to clipboard");
                                    },
                                    icon: const Icon(Icons.copy_rounded, size: 18),
                                    label: const Text("Copy"),
                                  ),
                                  const SizedBox(width: 8),
                                  if (_detectedQrCode!.startsWith("http"))
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        await _triggerVibration();
                                        final Uri url = Uri.parse(_detectedQrCode!);
                                        if (await canLaunchUrl(url)) {
                                          await launchUrl(url, mode: LaunchMode.externalApplication);
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blueAccent,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                                      label: const Text("Open"),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
                              if (!widget.isRetakeMode)
                                IconButton(
                                  onPressed: () async {
                                    await _triggerVibration();
                                    int initialCount = widget.initialImages?.length ?? 0;
                                    bool hasNewCaptures = capturedImagesList.length > initialCount;
                                    bool isFromEditor = widget.isOpenedFromEditor;

                                    if (hasNewCaptures) {
                                      bool shouldDiscard = await showCustomConfirmDialog(
                                        context,
                                        title: "Discard new scans?",
                                        message: "This will discard the newly captured scans. Are you sure?",
                                        positiveBtnText: "Discard",
                                        negativeBtnText: "Cancel",
                                        positiveBtnColor: Colors.redAccent,
                                      );

                                      if (shouldDiscard && context.mounted) {
                                        if (isFromEditor) {
                                          Navigator.pop(context);
                                        } else {
                                          Navigator.pushAndRemoveUntil(
                                            context,
                                            MaterialPageRoute(builder: (context) => const HomeScreen()),
                                            (route) => false,
                                          );
                                        }
                                      }
                                    } else {
                                      if (isFromEditor) {
                                        Navigator.pop(context);
                                      } else {
                                        Navigator.pushAndRemoveUntil(
                                          context,
                                          MaterialPageRoute(builder: (context) => const HomeScreen()),
                                          (route) => false,
                                        );
                                      }
                                    }
                                  },
                                  icon: _buildRotatedIcon(
                                    widget.isOpenedFromEditor ? Icons.close_rounded : Icons.home_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                )
                              else
                                IconButton(
                                  onPressed: () async {
                                    await _triggerVibration();
                                    Navigator.pop(context);
                                  },
                                  icon: _buildRotatedIcon(Icons.close_rounded, color: Colors.white, size: 28),
                                ),

                              /// Gallery Button
                              IconButton(
                                onPressed: selectedIndex == 1
                                    ? null
                                    : () async {
                                        await _triggerVibration();
                                        //_pickImagesFromGallery;
                                        await _pickImagesFromGallery();
                                      },
                                icon: Opacity(
                                  opacity: selectedIndex == 1 ? 0.4 : 1.0,
                                  child: _buildRotatedIcon(Icons.photo_library_rounded, color: Colors.white, size: 24),
                                ),
                              ),

                              /// Dynamic & Animated Capture Button
                              GestureDetector(
                                //onTap: _capturePhoto,
                                onTap: selectedIndex == 1 ? null : _capturePhoto,
                                child: Opacity(
                                  opacity: selectedIndex == 1 ? 0.4 : 1.0,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
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
                                      else if (isAutoDetectOn && _stableFrames > 0)
                                        SizedBox(
                                          width: 56,
                                          height: 56,
                                          child: CircularProgressIndicator(
                                            value: (_stableFrames / 10.0).clamp(0.0, 1.0),
                                            strokeWidth: 4,
                                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                                            backgroundColor: Colors.transparent,
                                          ),
                                        ),

                                      if (isCapturing && currentCountdown > 0)
                                        Text(
                                          '$currentCountdown',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      else if (!isCapturing && selectedTimer > 0)
                                        Text(
                                          '$selectedTimer',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      else
                                        Container(
                                          width: 45,
                                          height: 45,
                                          decoration: BoxDecoration(
                                            color: (isCapturing || isHoldingSteady) ? Colors.grey : Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),

                              /// Auto Detect Button
                              IconButton(
                                onPressed: selectedIndex == 1
                                    ? null
                                    : () async {
                                        await _triggerVibration();
                                        _toggleAutoDetect();
                                      },
                                icon: Opacity(
                                  opacity: selectedIndex == 1 ? 0.4 : 1.0,
                                  child: _buildRotatedIcon(
                                    Icons.document_scanner_outlined,
                                    color: isAutoDetectOn ? Colors.blueAccent : Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),

                              /// Last Photo with Counter Badge
                              GestureDetector(
                                onTap: selectedIndex == 1
                                    ? null
                                    : () async {
                                        await _triggerVibration();
                                        if (capturedPhotosCount > 0) {
                                          _goToEditor();
                                        }
                                      },
                                child: Opacity(
                                  opacity: selectedIndex == 1 ? 0.4 : 1.0,
                                  child: Stack(
                                    clipBehavior: Clip.none,
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

                                      if (capturedPhotosCount > 0)
                                        Positioned(
                                          top: -6,
                                          right: -6,
                                          child: Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: const BoxDecoration(
                                              color: Colors.amber,
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
                        child: AnimatedRotation(
                          turns: _iconTurns,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 40),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
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

                  if (_isCameraSleeping)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _wakeUpCamera,
                        child: Container(color: Colors.transparent),
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

  Widget _buildRotatedIcon(IconData iconData, {Color color = Colors.white, double size = 26}) {
    return AnimatedRotation(
      turns: _iconTurns,
      duration: const Duration(milliseconds: 300),
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
                onPressed: () async {
                  await _triggerVibration();
                  setState(() {
                    activeMenu = "Flash";
                  });
                },
                icon: _buildRotatedIcon(_getFlashIcon(), color: Colors.white, size: 26),
              ),

              IconButton(
                //onPressed: _flipCamera,
                onPressed: () async {
                  await _triggerVibration();
                  _flipCamera();
                },
                icon: _buildRotatedIcon(Symbols.flip_camera_android_sharp, color: Colors.white, size: 26),
              ),
              if (!widget.isRetakeMode)
                IconButton(
                  //onPressed: () async {
                  onPressed: selectedIndex == 1
                      ? null
                      : () async {
                          await _triggerVibration();
                          setState(() {
                            isMultiScanMode = !isMultiScanMode;
                          });
                          showToast(isMultiScanMode ? "Multi-scan ON" : "Single-scan ON");
                        },
                  icon: Opacity(
                    opacity: selectedIndex == 1 ? 0.4 : 1.0,
                    child: _buildRotatedIcon(
                      isMultiScanMode ? Icons.file_copy_rounded : Icons.insert_drive_file_outlined,
                      color: isMultiScanMode ? Colors.blueAccent : Colors.white,
                      size: 24,
                    ),
                  ),
                ),

              /// YAHAN TIMER ICON DYNAMIC KAR DIYA
              IconButton(
                onPressed: selectedIndex == 1
                    ? null
                    : () async {
                        await _triggerVibration();
                        setState(() {
                          activeMenu = "Timer";
                        });
                      },
                icon: Opacity(
                  opacity: selectedIndex == 1 ? 0.4 : 1.0,
                  child: _buildRotatedIcon(_getTimerIcon(), color: Colors.white, size: 26),
                ),
              ),

              if (!widget.isRetakeMode)
                IconButton(
                  onPressed: _goToSettings,
                  icon: _buildRotatedIcon(Symbols.segment_sharp, color: Colors.white, size: 26),
                ),
            ],
          ),
        );
    }
  }

  Future<void> _goToSettings() async {
    await _triggerVibration();

    // 1. Settings jane se pehle flash sync reset
    if (selectedFlashMode != "Off") {
      await _applyFlashMode("Off");
      if (mounted) {
        setState(() => selectedFlashMode = "Off");
      }
    }

    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    if (mounted) {
      setState(() {
        _detectedDocumentBox = null;
        _stableFrames = 0;
      });
    }

    await Navigator.push(context, MaterialPageRoute(builder: (context) => const CameraSettingsScreen()));
    await _loadSettings();

    if (mounted) {
      setState(() {
        _isCameraSleeping = false;
      });
      _resetSleepTimer();
      await _wakeUpCamera();
      if (isAutoDetectOn && selectedIndex == 0) {
        _startMLAutoDetect();
      }
    }
  }

  Widget _buildFlashOption(String mode) {
    final bool isSelected = selectedFlashMode == mode;
    final Color color = isSelected ? Colors.amber : Colors.white;

    return GestureDetector(
      onTap: () async {
        setState(() {
          selectedFlashMode = mode;
          activeMenu = "Default";
        });
        await _applyFlashMode(mode);
        await _triggerVibration();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Icon(_getFlashIcon(mode), color: color, size: 26),
      ),
    );
  }

  Widget _buildTimerOption(int seconds) {
    final bool isSelected = selectedTimer == seconds;
    final Color color = isSelected ? Colors.amber : Colors.white;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTimer = seconds;
          activeMenu = "Default";
        });
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

    final Paint borderPaint = Paint()
      ..color = Colors.lightBlueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawRect(scaledRect, borderPaint);

    final Paint dotPaint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.fill;
    final Paint dotBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final double radius = 8.0;

    final List<Offset> corners = [
      scaledRect.topLeft,
      scaledRect.topRight,
      scaledRect.bottomLeft,
      scaledRect.bottomRight,
    ];

    for (Offset corner in corners) {
      canvas.drawCircle(corner, radius, dotPaint);
      canvas.drawCircle(corner, radius, dotBorder);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class QrOverlayPainter extends CustomPainter {
  final Rect? qrRect;
  final Size imageSize;

  QrOverlayPainter(this.qrRect, this.imageSize);

  @override
  void paint(Canvas canvas, Size size) {
    if (qrRect == null) return;

    final double scaleX = size.width / imageSize.height;
    final double scaleY = size.height / imageSize.width;

    final double padding = 15.0;

    final Rect scaledRect = Rect.fromLTRB(
      (qrRect!.left * scaleX) - padding,
      (qrRect!.top * scaleY) - padding,
      (qrRect!.right * scaleX) + padding,
      (qrRect!.bottom * scaleY) + padding,
    );

    final Paint borderPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final double cornerLength = 30.0;

    // Top-Left corner draw
    canvas.drawLine(scaledRect.topLeft, scaledRect.topLeft + Offset(cornerLength, 0), borderPaint);
    canvas.drawLine(scaledRect.topLeft, scaledRect.topLeft + Offset(0, cornerLength), borderPaint);

    // Top-Right corner draw
    canvas.drawLine(scaledRect.topRight, scaledRect.topRight + Offset(-cornerLength, 0), borderPaint);
    canvas.drawLine(scaledRect.topRight, scaledRect.topRight + Offset(0, cornerLength), borderPaint);

    // Bottom-Left corner draw
    canvas.drawLine(scaledRect.bottomLeft, scaledRect.bottomLeft + Offset(cornerLength, 0), borderPaint);
    canvas.drawLine(scaledRect.bottomLeft, scaledRect.bottomLeft + Offset(0, -cornerLength), borderPaint);

    // Bottom-Right corner draw
    canvas.drawLine(scaledRect.bottomRight, scaledRect.bottomRight + Offset(-cornerLength, 0), borderPaint);
    canvas.drawLine(scaledRect.bottomRight, scaledRect.bottomRight + Offset(0, -cornerLength), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class GridOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0; // Motayi

    final double cellWidth = size.width / 3;
    canvas.drawLine(Offset(cellWidth, 0), Offset(cellWidth, size.height), paint);
    canvas.drawLine(Offset(cellWidth * 2, 0), Offset(cellWidth * 2, size.height), paint);

    final double cellHeight = size.height / 3;
    canvas.drawLine(Offset(0, cellHeight), Offset(size.width, cellHeight), paint);
    canvas.drawLine(Offset(0, cellHeight * 2), Offset(size.width, cellHeight * 2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
