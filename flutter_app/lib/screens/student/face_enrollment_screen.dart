// lib/screens/student/face_enrollment_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../widgets/common_widgets.dart';
import '../../config.dart';

class FaceEnrollmentScreen extends StatefulWidget {
  const FaceEnrollmentScreen({super.key});

  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;

  String? _capturedFaceB64;
  String? _idCardB64;
  bool _cameraReady = false;
  bool _faceCaptured = false;
  bool _idCardSelected = false;
  bool _isSubmitting = false;
  bool _isCameraOpen = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras == null || _cameras!.isEmpty) {
      setState(() => _status = 'No camera available');
      return;
    }

    // Use front camera
    final frontCamera = _cameras!.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras!.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    setState(() => _cameraReady = true);
  }

  Future<void> _captureface() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() => _isCameraOpen = true);
  }

  Future<void> _takePicture() async {
    if (_cameraController == null) return;
    try {
      final XFile photo = await _cameraController!.takePicture();
      final bytes = await photo.readAsBytes();

      // Compress and convert to base64
      final b64 = base64Encode(bytes);

      setState(() {
        _capturedFaceB64 = b64;
        _faceCaptured = true;
        _isCameraOpen = false;
        _status = 'Face captured ✅';
      });
    } catch (e) {
      setState(() => _status = 'Capture failed: $e');
    }
  }

  Future<void> _pickIdCard() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      final b64 = base64Encode(bytes);
      setState(() {
        _idCardB64 = b64;
        _idCardSelected = true;
        _status = 'ID card selected ✅';
      });
    }
  }

  Future<void> _submit() async {
    if (!_faceCaptured || !_idCardSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture your face and select ID card'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Check for duplicate first
      await ApiService().checkDuplicateFace(
        faceImageB64: _capturedFaceB64!,
        idCardImageB64: _idCardB64!,
      );

      // Submit enrollment
      await ApiService().submitFaceEnrollment(
        faceImageB64: _capturedFaceB64!,
        idCardImageB64: _idCardB64!,
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE6F4EA),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: Color(0xFF137333), size: 36),
                ),
                const SizedBox(height: 16),
                const Text('Enrollment Submitted!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'Your face enrollment is pending admin approval. You will be able to mark attendance once approved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }

    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isCameraOpen) {
      return _buildCameraView();
    }
    return _buildEnrollmentForm();
  }

  Widget _buildCameraView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera preview
            if (_cameraReady && _cameraController != null)
              Center(child: CameraPreview(_cameraController!)),

            // Face oval guide
            Center(
              child: Container(
                width: 220,
                height: 280,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(140),
                ),
              ),
            ),

            // Instructions
            Positioned(
              top: 24,
              left: 0, right: 0,
              child: Column(
                children: [
                  const Text(
                    'Position your face in the oval',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Make sure your face is well lit and clearly visible',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Capture button
            Positioned(
              bottom: 40,
              left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Cancel
                  GestureDetector(
                    onTap: () => setState(() => _isCameraOpen = false),
                    child: Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 28),
                    ),
                  ),
                  const SizedBox(width: 48),
                  // Capture
                  GestureDetector(
                    onTap: _takePicture,
                    child: Container(
                      width: 72, height: 72,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.black, size: 36),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnrollmentForm() {
    return Scaffold(
      backgroundColor: const Color(AppColors.surface),
      appBar: AppBar(
        title: const Text('Face Enrollment', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(AppColors.primary), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your face photo and ID card will be reviewed by admin before approval. This is a one-time process.',
                      style: TextStyle(color: Color(AppColors.primary), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Step 1: Face capture
            const Text('Step 1: Capture Your Face',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Take a clear photo of your face in good lighting',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 16),

            GestureDetector(
              onTap: _cameraReady ? _captureface : null,
              child: Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  color: _faceCaptured
                      ? const Color(0xFFE6F4EA)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _faceCaptured
                        ? const Color(0xFF137333)
                        : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: _faceCaptured
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xFF137333), size: 48),
                          const SizedBox(height: 8),
                          const Text('Face captured!',
                              style: TextStyle(color: Color(0xFF137333), fontWeight: FontWeight.w600)),
                          TextButton(
                            onPressed: _captureface,
                            child: const Text('Retake'),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.face, size: 48, color: Colors.grey.shade500),
                          const SizedBox(height: 8),
                          Text('Tap to open camera',
                              style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 28),

            // Step 2: ID card
            const Text('Step 2: Upload ID Card Photo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Upload a clear photo of your college ID card',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 16),

            GestureDetector(
              onTap: _pickIdCard,
              child: Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  color: _idCardSelected
                      ? const Color(0xFFE6F4EA)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _idCardSelected
                        ? const Color(0xFF137333)
                        : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: _idCardSelected
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xFF137333), size: 48),
                          const SizedBox(height: 8),
                          const Text('ID card selected!',
                              style: TextStyle(color: Color(0xFF137333), fontWeight: FontWeight.w600)),
                          TextButton(
                            onPressed: _pickIdCard,
                            child: const Text('Change'),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.badge_outlined, size: 48, color: Colors.grey.shade500),
                          const SizedBox(height: 8),
                          Text('Tap to select from gallery',
                              style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 32),

            // Submit
            AppButton(
              label: 'Submit for Approval',
              onPressed: (_faceCaptured && _idCardSelected) ? _submit : null,
              isLoading: _isSubmitting,
              icon: Icons.upload,
            ),

            if (_status.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(_status,
                  style: TextStyle(
                    color: _status.contains('✅')
                        ? const Color(0xFF137333)
                        : Colors.red,
                    fontSize: 13,
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
