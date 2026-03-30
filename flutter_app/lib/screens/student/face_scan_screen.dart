// lib/screens/student/face_scan_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../services/api_service.dart';
import '../../config.dart';

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

  String _challengeId = '';
  String _challenge = '';
  String _instruction = '';
  bool _challengeLoaded = false;
  bool _isProcessing = false;
  bool _challengeComplete = false;
  bool _isSubmitting = false;
  String _status = 'Preparing camera...';
  String _capturedImageB64 = '';

  int _blinkCount = 0;
  bool _eyesWereClosed = false;
  bool _headTurnedLeft = false;
  bool _headTurnedRight = false;
  bool _smileDetected = false;
  int _attempts = 0;
  static const int maxAttempts = 3;

  DateTime _lastProcessed = DateTime.now();
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
      frontCamera, ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
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
      final result = await ApiService().getLivenessChallenge(sessionId: widget.sessionId);
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

  Future<void> _processCameraImage(CameraImage image) async {
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

      print('Processing image: ${image.width}x${image.height}');
      final faces = await _faceDetector!.processImage(inputImage);
      print('Faces detected: ${faces.length}');

      if (!mounted) { _isProcessing = false; return; }

      if (faces.isEmpty) {
        setState(() => _status = 'No face detected. Position your face.');
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
      case 'blink': _checkBlink(face); break;
      case 'turn_head': _checkHeadTurn(face); break;
      case 'smile': _checkSmile(face); break;
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
      if (_blinkCount >= 2) _onChallengeComplete(face);
    }
  }

  void _checkHeadTurn(Face face) {
    final yAngle = face.headEulerAngleY ?? 0;
    print('Head Y angle: $yAngle');
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
      _status = 'Challenge complete! Face forward... 📷';
    });
    // Give the user 1.5 s to return to a neutral frontal pose before capture.
    // Without this, a head-turn image is captured at an angle and InsightFace
    // returns a side-profile embedding that won't match the frontal enrollment.
    await Future.delayed(const Duration(milliseconds: 1500));
    setState(() => _status = 'Capturing face...');
    await _cameraController?.stopImageStream();
    await _captureAndSubmit();
  }

  /// Fetches a brand-new challenge from the server and resets all liveness
  /// tracking state. Called on every retry so the old (used/expired)
  /// challenge_id is never replayed.
  Future<void> _refreshChallenge() async {
    setState(() {
      _isSubmitting = false;
      _challengeComplete = false;
      _blinkCount = 0;
      _eyesWereClosed = false;
      _headTurnedLeft = false;
      _headTurnedRight = false;
      _smileDetected = false;
      _status = 'Attempt $_attempts/$maxAttempts failed. Refreshing challenge...';
    });
    try {
      final result = await ApiService().getLivenessChallenge(sessionId: widget.sessionId);
      setState(() {
        _challengeId = result['challenge_id'];
        _challenge = result['challenge'];
        _instruction = result['instruction'];
        _status = 'Try again: ${result['instruction']}';
      });
    } catch (e) {
      setState(() => _status = 'Could not refresh challenge: $e');
    }
    _cameraController?.startImageStream(_processCameraImage);
  }

  Future<void> _captureAndSubmit() async {
    setState(() => _isSubmitting = true);
    try {
      final XFile photo = await _cameraController!.takePicture();
      final bytes = await photo.readAsBytes();
      _capturedImageB64 = base64Encode(bytes);
      setState(() => _status = 'Verifying face...');
      final result = await ApiService().verifyFace(
        sessionId: widget.sessionId,
        token: widget.token,
        faceImageB64: _capturedImageB64,
        challengeId: _challengeId,
      );
      if (mounted) _showResult(true, result['message'] ?? 'Attendance marked!');
    } catch (e) {
      _attempts++;
      final errorMsg = e.toString();
      if (_attempts >= maxAttempts) {
        // Show the actual server error so the user/dev knows what went wrong.
        if (mounted) _showResult(false, errorMsg);
      } else {
        // Surface the error in the status so it is visible during refresh.
        if (mounted) {
          setState(() => _status = 'Failed: $errorMsg');
          await Future.delayed(const Duration(seconds: 2));
        }
        // Fetch a fresh challenge so the used/expired challenge_id is not replayed.
        if (mounted) await _refreshChallenge();
      }
    }
  }

  void _showResult(bool success, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: (success ? const Color(AppColors.success) : const Color(AppColors.error))
                    .withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                success ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: success ? const Color(AppColors.success) : const Color(AppColors.error),
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
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Done'),
            ),
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
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            if (_cameraController != null && _cameraController!.value.isInitialized)
              Center(child: CameraPreview(_cameraController!)),

            Center(
              child: Container(
                width: 220, height: 280,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _challengeComplete ? const Color(AppColors.success) : Colors.white,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(140),
                ),
              ),
            ),

            Positioned(
              top: 16, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(widget.subjectName,
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                    const SizedBox(height: 6),
                    Text(
                      _status,
                      style: const TextStyle(
                        color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    if (_attempts > 0) ...[
                      const SizedBox(height: 4),
                      Text('Attempt $_attempts/$maxAttempts',
                          style: const TextStyle(color: Colors.orange, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),

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

            if (_challengeLoaded)
              Positioned(
                bottom: 40, left: 16, right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_getChallengeIcon(), color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(_instruction,
                          style: const TextStyle(color: Colors.white, fontSize: 14)),
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
      case 'blink': return Icons.visibility_rounded;
      case 'turn_head': return Icons.rotate_90_degrees_ccw_rounded;
      case 'smile': return Icons.sentiment_satisfied_alt_rounded;
      default: return Icons.face_rounded;
    }
  }
}
