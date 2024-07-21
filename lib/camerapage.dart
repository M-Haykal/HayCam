import 'package:HayCam/PreviewPage.dart';
import 'package:HayCam/imageConvert.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

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
  int _selectedMode = 0;
  late bool _isFlashOn = false;
  double _currentZoomLevel = 1.0;
  double _maxZoomLevel = 8.0;
  final List<double> _zoomLevels = [1.0, 2.0, 4.0, 6.0, 8.0];
  final List<String> _menuLabels = ['Camera', 'Video', 'QrCode'];

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
      ResolutionPreset.medium,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await cameraController.initialize();
      double maxZoomLevel = await cameraController.getMaxZoomLevel();
      _maxZoomLevel = maxZoomLevel > 8.0 ? 8.0 : maxZoomLevel;

      if (mounted) {
        setState(() {
          _controller = cameraController;
          _isCameraInitialized = _controller!.value.isInitialized;
          if (_isFlashOn) {
            _controller?.setFlashMode(FlashMode.torch);
          }
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
      if (_isFlashOn) {
        await cameraController.setFlashMode(FlashMode.torch);
      }
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
      if (_isFlashOn) {
        await cameraController?.setFlashMode(FlashMode.torch);
      }
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

  Future<void> toggleFlashLight() async {
    try {
      if (_controller == null || !_controller!.value.isInitialized) {
        debugPrint('Camera controller is not initialized or not ready');
        return;
      }

      if (_isFlashOn) {
        await _controller?.setFlashMode(FlashMode.off);
        debugPrint('Flash turned off');
      } else {
        await _controller?.setFlashMode(FlashMode.torch);
        debugPrint('Flash turned on');
      }
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      debugPrint('Error toggling flash: $e');
    }
  }

  Future<void> _updateZoomLevel(double zoomLevel) async {
    try {
      if (_controller != null && _controller!.value.isInitialized) {
        await _controller?.setZoomLevel(zoomLevel);
      }
    } catch (e) {
      debugPrint('Error setting zoom level: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => ImageConvert()));
            },
          ),
        ],
      ),
      body: _isCameraInitialized
          ? Column(
              children: [
                Expanded(
                  child: _controller == null
                      ? Center(child: CircularProgressIndicator())
                      : CameraPreview(_controller!),
                ),
                Container(
                  height: 50,
                  child: Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_menuLabels.length, (index) {
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedMode = index;
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
                              style: TextButton.styleFrom(
                                foregroundColor: _selectedMode == index
                                    ? Colors.blue
                                    : Colors.grey,
                              ),
                              child: Text(
                                _menuLabels[index],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: _selectedMode == index
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
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
                      IconButton(
                        onPressed: toggleFlashLight,
                        icon: Icon(
                          _isFlashOn ? Icons.flash_off : Icons.flash_on,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                if (_isCameraInitialized)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: SizedBox(
                      height: 50,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _zoomLevels.map((zoomLevel) {
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: ElevatedButton(
                              onPressed: () async {
                                setState(() {
                                  _currentZoomLevel = zoomLevel;
                                });
                                await _updateZoomLevel(_currentZoomLevel);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _currentZoomLevel == zoomLevel
                                    ? Colors.blue
                                    : Colors.grey,
                              ),
                              child: Text('${zoomLevel.toStringAsFixed(1)}x'),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            )
          : Center(
              child: CircularProgressIndicator(),
            ),
    );
  }
}
