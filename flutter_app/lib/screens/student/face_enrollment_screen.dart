// lib/screens/student/face_enrollment_screen.dart

import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
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
    final frontCamera = _cameras!.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras!.first,
    );
    _cameraController = CameraController(
      frontCamera, ResolutionPreset.medium, enableAudio: false,
    );
    await _cameraController!.initialize();
    setState(() => _cameraReady = true);
  }

  Future<void> _takePicture() async {
    if (_cameraController == null) return;
    try {
      final XFile photo = await _cameraController!.takePicture();
      final bytes = await photo.readAsBytes();
      setState(() {
        _capturedFaceB64 = base64Encode(bytes);
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
      maxWidth: 1024, maxHeight: 1024, imageQuality: 80,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _idCardB64 = base64Encode(bytes);
        _idCardSelected = true;
        _status = 'ID card selected ✅';
      });
    }
  }

  Future<void> _submit() async {
    if (!_faceCaptured || !_idCardSelected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please capture your face and select ID card'),
        backgroundColor: Color(AppColors.error),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await ApiService().checkDuplicateFace(
        faceImageB64: _capturedFaceB64!,
        idCardImageB64: _idCardB64!,
      );
      await ApiService().submitFaceEnrollment(
        faceImageB64: _capturedFaceB64!,
        idCardImageB64: _idCardB64!,
      );
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: const Color(AppColors.success).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: Color(AppColors.success), size: 36),
                ),
                const SizedBox(height: 16),
                const Text('Enrollment Submitted!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'Your face enrollment is pending admin approval.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 13, height: 1.5),
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
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: const Color(AppColors.error),
        behavior: SnackBarBehavior.floating,
      ));
    }
    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isCameraOpen) return _buildCameraView();
    return _buildEnrollmentForm();
  }

  Widget _buildCameraView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (_cameraReady && _cameraController != null)
              Center(child: CameraPreview(_cameraController!)),
            Center(
              child: Container(
                width: 220, height: 280,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(140),
                ),
              ),
            ),
            Positioned(
              top: 24, left: 16, right: 16,
              child: Text(
                'Position your face in the oval',
                style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
            Positioned(
              bottom: 40, left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _isCameraOpen = false),
                    child: Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                    ),
                  ),
                  const SizedBox(width: 48),
                  GestureDetector(
                    onTap: _takePicture,
                    child: Container(
                      width: 70, height: 70,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.black, size: 34),
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
      appBar: AppBar(title: const Text('Face Enrollment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(AppColors.primary).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(AppColors.primary).withOpacity(0.15)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(AppColors.primary), size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your face and ID card will be reviewed by admin. This is a one-time process.',
                      style: TextStyle(color: Color(AppColors.primary), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Step 1
            const Text('Step 1: Capture Your Face',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Take a clear selfie in good lighting',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 13,
                )),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _cameraReady ? () => setState(() => _isCameraOpen = true) : null,
              child: Container(
                width: double.infinity, height: 150,
                decoration: BoxDecoration(
                  color: _faceCaptured
                      ? const Color(AppColors.success).withOpacity(0.08)
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _faceCaptured
                        ? const Color(AppColors.success).withOpacity(0.3)
                        : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: _faceCaptured
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Color(AppColors.success), size: 44),
                          const SizedBox(height: 8),
                          const Text('Face captured!',
                              style: TextStyle(color: Color(AppColors.success), fontWeight: FontWeight.w600)),
                          TextButton(
                            onPressed: () => setState(() => _isCameraOpen = true),
                            child: const Text('Retake'),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.face_rounded, size: 44,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                          const SizedBox(height: 8),
                          Text('Tap to open camera',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                              )),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Step 2
            const Text('Step 2: Upload College ID Card',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Upload a clear photo of your college ID card',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 13,
                )),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _pickIdCard,
              child: Container(
                width: double.infinity, height: 150,
                decoration: BoxDecoration(
                  color: _idCardSelected
                      ? const Color(AppColors.success).withOpacity(0.08)
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _idCardSelected
                        ? const Color(AppColors.success).withOpacity(0.3)
                        : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: _idCardSelected
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Color(AppColors.success), size: 44),
                          const SizedBox(height: 8),
                          const Text('ID card selected!',
                              style: TextStyle(color: Color(AppColors.success), fontWeight: FontWeight.w600)),
                          TextButton(onPressed: _pickIdCard, child: const Text('Change')),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.badge_outlined, size: 44,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                          const SizedBox(height: 8),
                          Text('Tap to select from gallery',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                              )),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 32),

            AppButton(
              label: 'Submit for Approval',
              onPressed: (_faceCaptured && _idCardSelected) ? _submit : null,
              isLoading: _isSubmitting,
              icon: Icons.upload_rounded,
            ),

            if (_status.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                _status,
                style: TextStyle(
                  color: _status.contains('✅')
                      ? const Color(AppColors.success)
                      : const Color(AppColors.error),
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
