// lib/screens/student/face_scan_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../services/api_service.dart';
import '../../config.dart';
import 'package:flutter/foundation.dart';

class FaceScanScreen extends StatefulWidget {
  final String sessionId;
  final String token;
  final String subjectName;

  const FaceScanScreen({
    super.key,
    required this.sessionId,
    required this.token,
    required this.subjectName,
  });

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen> {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;

  // Challenge state
  String _challengeId = '';
  String _challenge = '';
  String _instruction = '';
  bool _challengeLoaded = false;

  // Detection state
  bool _isProcessing = false;
  bool _challengeComplete = false;
  bool _isSubmitting = false;
  String _status = 'Preparing camera...';
  String _capturedImageB64 = '';

  // Liveness tracking
  int _blinkCount = 0;
  bool _eyesWereClosed = false;
  bool _headTurnedLeft = false;
  bool _headTurnedRight = false;
  bool _smileDetected = false;

  // Attempts tracking
  int _attempts = 0;
  static const int maxAttempts = 3;

  Timer? _processingTimer;

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  @override
  void dispose() {
    _processingTimer?.cancel();
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  Future<void> _initAll() async {
    await _initCamera();
    await _loadChallenge();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      setState(() => _status = 'No camera available');
      return;
    }

    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.low,     // ← change to low
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,  // ← change to yuv420
    );

    await _cameraController!.initialize();

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        enableTracking: true,
        minFaceSize: 0.3,
        performanceMode: FaceDetectorMode.fast,
      ),
    );

    setState(() => _status = 'Camera ready');
    _cameraController!.startImageStream(_processCameraImage);
  }

  Future<void> _loadChallenge() async {
    try {
      final result = await ApiService().getLivenessChallenge(
        sessionId: widget.sessionId,
      );
      setState(() {
        _challengeId = result['challenge_id'];
        _challenge = result['challenge'];
        _instruction = result['instruction'];
        _challengeLoaded = true;
        _status = _instruction;
      });
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  DateTime _lastProcessed = DateTime.now();

  Future<void> _processCameraImage(CameraImage image) async {
    // Throttle — only process every 200ms
    final now = DateTime.now();
    if (now.difference(_lastProcessed).inMilliseconds < 200) return;
    _lastProcessed = now;

    if (_isProcessing || _challengeComplete || !_challengeLoaded) return;
    if (_faceDetector == null || _cameraController == null) return;

    _isProcessing = true;

    try {
      final inputImage = _buildInputImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final faces = await _faceDetector!.processImage(inputImage);

      if (!mounted) {
        _isProcessing = false;
        return;
      }

      if (faces.isEmpty) {
        setState(() => _status = 'No face detected. Position your face in the frame.');
        _isProcessing = false;
        return;
      }

      final face = faces.first;
      _checkLiveness(face);

    } catch (e) {
      print('Face detection error: $e');
    }

    _isProcessing = false;
  }

  InputImage? _buildInputImage(CameraImage image) {
    if (_cameraController == null) return null;

    final camera = _cameraController!.description;
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) return null;

    // Concatenate all planes for NV21/YUV
    final WriteBuffer allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

    void _checkLiveness(Face face) {
      switch (_challenge) {
        case 'blink':
          _checkBlink(face);
          break;
        case 'turn_head':
          _checkHeadTurn(face);
          break;
        case 'smile':
          _checkSmile(face);
          break;
      }
    }

  void _checkBlink(Face face) {
    final leftEye = face.leftEyeOpenProbability ?? 1.0;
    final rightEye = face.rightEyeOpenProbability ?? 1.0;
    final eyesClosed = leftEye < 0.3 && rightEye < 0.3;
    print('Left eye: $leftEye, Right eye: $rightEye, Closed: $eyesClosed, BlinkCount: $_blinkCount');

    if (eyesClosed && !_eyesWereClosed) {
      _eyesWereClosed = true;
    } else if (!eyesClosed && _eyesWereClosed) {
      _eyesWereClosed = false;
      _blinkCount++;
      setState(() => _status = 'Blink $_blinkCount/2 detected!');

      if (_blinkCount >= 2) {
        _onChallengeComplete(face);
      }
    }
  }

  void _checkHeadTurn(Face face) {
    final yAngle = face.headEulerAngleY ?? 0;
    print('Head Y angle: $yAngle, TurnedLeft: $_headTurnedLeft, TurnedRight: $_headTurnedRight');

    if (yAngle < -20 && !_headTurnedLeft) {
      _headTurnedLeft = true;
      setState(() => _status = 'Left ✅ Now turn right');
    }

    if (_headTurnedLeft && yAngle > 20 && !_headTurnedRight) {
      _headTurnedRight = true;
      _onChallengeComplete(face);
    }
  }

  void _checkSmile(Face face) {
    final smileProb = face.smilingProbability ?? 0.0;
    print('Smile probability: $smileProb'); 
    if (smileProb > 0.7 && !_smileDetected) {
      _smileDetected = true;
      _onChallengeComplete(face);
    }
  }

  Future<void> _onChallengeComplete(Face face) async {
    if (_challengeComplete) return;
    setState(() {
      _challengeComplete = true;
      _status = 'Challenge complete! Capturing face...';
    });

    // Stop image stream
    await _cameraController?.stopImageStream();

    // Capture the photo
    await _captureAndSubmit();
  }

  Future<void> _captureAndSubmit() async {
    setState(() => _isSubmitting = true);

    try {
      // Take picture
      final XFile photo = await _cameraController!.takePicture();
      final bytes = await photo.readAsBytes();
      _capturedImageB64 = base64Encode(bytes);

      setState(() => _status = 'Verifying face...');

      // Submit to server
      final result = await ApiService().verifyFace(
        sessionId: widget.sessionId,
        token: widget.token,
        faceImageB64: _capturedImageB64,
        challengeId: _challengeId,
      );

      if (mounted) {
        _showResult(true, result['message'] ?? 'Attendance marked!');
      }
    } catch (e) {
      _attempts++;
      if (_attempts >= maxAttempts) {
        if (mounted) _showResult(false, 'Maximum attempts reached. Marked absent.');
      } else {
        setState(() {
          _challengeComplete = false;
          _blinkCount = 0;
          _eyesWereClosed = false;
          _headTurnedLeft = false;
          _headTurnedRight = false;
          _smileDetected = false;
          _status = 'Attempt $_attempts/$maxAttempts failed. Try again: $_instruction';
          _isSubmitting = false;
        });
        // Restart image stream
        _cameraController?.startImageStream(_processCameraImage);
      }
    }
  }

  void _showResult(bool success, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: success ? const Color(0xFFE6F4EA) : const Color(0xFFFCE8E6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                success ? Icons.check_circle : Icons.cancel,
                color: success ? const Color(0xFF137333) : const Color(0xFFEA4335),
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              success ? 'Attendance Marked!' : 'Verification Failed',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // go back to dashboard
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.subjectName,
            style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Camera preview
            if (_cameraController != null && _cameraController!.value.isInitialized)
              Center(child: CameraPreview(_cameraController!)),

            // Face oval guide
            Center(
              child: Container(
                width: 220,
                height: 280,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _challengeComplete ? Colors.green : Colors.white,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(140),
                ),
              ),
            ),

            // Status + instruction
            Positioned(
              top: 16,
              left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      widget.subjectName,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _status,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    if (_attempts > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Attempt $_attempts/$maxAttempts',
                        style: const TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Loading overlay when submitting
            if (_isSubmitting)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text('Verifying...', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),

            // Challenge indicator bottom
            if (_challengeLoaded)
              Positioned(
                bottom: 40,
                left: 16, right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getChallengeIcon(),
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _instruction,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
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

  IconData _getChallengeIcon() {
    switch (_challenge) {
      case 'blink': return Icons.visibility;
      case 'turn_head': return Icons.rotate_90_degrees_ccw;
      case 'smile': return Icons.sentiment_satisfied_alt;
      default: return Icons.face;
    }
  }
}
