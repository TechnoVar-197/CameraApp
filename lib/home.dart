import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({Key? key}) : super(key: key);

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndInitialize();
  }

  Future<void> _checkPermissionsAndInitialize() async {
    final status = await Permission.camera.request(); // Request camera permission
    if (status.isGranted) {
      await _initCamera(); // Initialize camera if permission is granted
    } else if (status.isPermanentlyDenied) {
      openAppSettings(); // Open app settings if permission is permanently denied
    }
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    _controller = CameraController(_cameras!.first, ResolutionPreset.high);
    await _controller!.initialize();
    setState(() => _isCameraInitialized = true);
  }

  Future<void> _takePicture() async {
    if (!_controller!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Camera not initialized')),
      );
      return;
    }

    try {
      final XFile imageFile = await _controller!.takePicture();

      // Get a reference to the Firebase Storage bucket
      final storageRef = FirebaseStorage.instance.ref();

      // Create a unique filename with timestamp
      final filename = '${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Upload the image to Firebase Storage
      final uploadTask = storageRef.child('images/$filename').putFile(File(imageFile.path));

      // Track upload progress
      final taskSnapshot = await uploadTask;
      final downloadUrl = await taskSnapshot.ref.getDownloadURL();
      print('Image uploaded to Firebase Storage: $downloadUrl');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image uploaded successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during image capture or upload: $e')),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Camera')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text('Camera permission is required to use this feature.'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _checkPermissionsAndInitialize,
                child: const Text('Request Permission'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Camera')),
      body: Center(
        child: CameraPreview(_controller!),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.camera_alt),
        onPressed: _takePicture, // Call _takePicture directly
      ),
    );
  }
}
