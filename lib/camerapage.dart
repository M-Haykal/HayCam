import 'package:HayCam/PreviewPage.dart';
import 'package:HayCam/imageConvert.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:toggle_switch/toggle_switch.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  late List<CameraDescription> _cameras;
  CameraDescription? _currentCamera;
  bool _isRecording = false;
  int _selectedMode = 0; // 0: Photo, 1: Video, 2: QR Code

  @override
  void initState() {
    super.initState();
    initCamera();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> initCamera() async {
    try {
      _cameras = await availableCameras();
      _currentCamera = _cameras.first;
      await onNewCameraSelected(_currentCamera!);
    } catch (e) {
      debugPrint('Error initializing cameras: $e');
    }
  }

  Future<void> onNewCameraSelected(CameraDescription description) async {
    if (_controller != null) {
      await _controller?.dispose();
    }

    final CameraController cameraController = CameraController(
      description,
      ResolutionPreset.max,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await cameraController.initialize();
      if (mounted) {
        setState(() {
          _controller = cameraController;
          _isCameraInitialized = _controller!.value.isInitialized;
        });
      }
    } on CameraException catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      onNewCameraSelected(cameraController.description);
    }
  }

  Future<XFile?> capturePhoto() async {
    final CameraController? cameraController = _controller;
    if (cameraController!.value.isTakingPicture) {
      return null;
    }

    try {
      await cameraController.setFlashMode(FlashMode.off);
      XFile file = await cameraController.takePicture();
      return file;
    } on CameraException catch (e) {
      debugPrint('Error occurred while taking picture: $e');
      return null;
    }
  }

  Future<XFile?> captureVideo() async {
    final CameraController? cameraController = _controller;
    try {
      setState(() {
        _isRecording = true;
      });
      await cameraController?.startVideoRecording();
      await Future.delayed(Duration(seconds: 5));
      final video = await cameraController?.stopVideoRecording();
      setState(() {
        _isRecording = false;
      });
      return video;
    } on CameraException catch (e) {
      debugPrint('Error occurred while recording video: $e');
      return null;
    }
  }

  void _onTakePhotoPressed() async {
    final navigator = Navigator.of(context);
    final xFile = await capturePhoto();
    if (xFile != null) {
      if (xFile.path.isNotEmpty) {
        navigator.push(MaterialPageRoute(
            builder: (context) => PreviewPage(
                  imagePath: xFile.path,
                )));
      }
    }
  }

  void _onRecordingVideoPressed() async {
    final navigator = Navigator.of(context);
    final xFile = await captureVideo();
    if (xFile != null) {
      if (xFile.path.isNotEmpty) {
        navigator.push(MaterialPageRoute(
            builder: (context) => PreviewPage(
                  videoPath: xFile.path,
                )));
      }
    }
  }

  void _onSwitchCamera() async {
    if (_cameras.length > 1) {
      try {
        final CameraDescription newCamera =
            _currentCamera == _cameras.first ? _cameras.last : _cameras.first;
        await onNewCameraSelected(newCamera);
        setState(() {
          _currentCamera = newCamera;
        });
      } catch (e) {
        debugPrint('Error switching camera: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCameraInitialized) {
      return SafeArea(
        child: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: Text(
              "HayCam",
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            actions: <Widget>[
              IconButton(
                  icon: Icon(
                    Icons.image,
                    color: Colors.white,
                  ),
                  onPressed: (() {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ImageConvert()));
                  }))
            ],
          ),
          body: Column(
            children: [
              Expanded(child: CameraPreview(_controller!)),
              ToggleSwitch(
                initialLabelIndex: _selectedMode,
                totalSwitches: 3,
                labels: ['Photo', 'Video', 'QR Code'],
                onToggle: (index) {
                  setState(() {
                    _selectedMode = index!;
                    if (_selectedMode == 2) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ImageConvert(),
                        ),
                      );
                    }
                  });
                },
              ),
              if (_selectedMode != 2)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      icon: Icon(Icons.switch_camera_rounded,
                          color: Colors.white),
                      onPressed: _onSwitchCamera,
                    ),
                    if (!_isRecording && _selectedMode == 0)
                      IconButton(
                        onPressed: _onTakePhotoPressed,
                        icon: Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                        ),
                      ),
                    if (_selectedMode == 1)
                      IconButton(
                        onPressed:
                            _isRecording ? null : _onRecordingVideoPressed,
                        icon: Icon(
                          _isRecording ? Icons.stop : Icons.videocam,
                          color: Colors.red,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      );
    } else {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
  }
}
