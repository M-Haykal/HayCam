import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:widget_zoom/widget_zoom.dart';

class PreviewPage extends StatefulWidget {
  final String? imagePath;
  final String? videoPath;
  const PreviewPage({Key? key, this.imagePath, this.videoPath})
      : super(key: key);

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  VideoPlayerController? controller;

  Future<void> requestPermissions() async {
    await Permission.storage.request();
  }

  Future<void> _startVideoPlayer() async {
    if (widget.videoPath != null) {
      controller = VideoPlayerController.file(File(widget.videoPath!));
      try {
        await controller!.initialize();
        setState(() {});
        await controller!.setLooping(true);
        await controller!.play();
      } catch (e) {
        debugPrint('Error initializing video player: $e');
      }
    }
  }

  Future<void> _saveToGallery(String filePath) async {
    try {
      final file = File(filePath);

      if (!(await file.exists())) {
        throw FileSystemException('File does not exist at path: $filePath');
      }

      String correctFilePath = filePath;
      final fileType = filePath.split('.').last.toLowerCase();
      if (fileType == 'temp') {
        correctFilePath = filePath.replaceAll('.temp', '.mp4');
        await file.rename(correctFilePath);
      }

      final newFileType = correctFilePath.split('.').last.toLowerCase();
      const supportedImageTypes = ['jpg', 'jpeg', 'png'];
      const supportedVideoTypes = ['mp4', 'mov', 'avi'];

      if (!supportedImageTypes.contains(newFileType) &&
          !supportedVideoTypes.contains(newFileType)) {
        throw Exception('Unsupported file type: $newFileType');
      }

      bool isSaved = false;
      if (supportedImageTypes.contains(newFileType)) {
        isSaved = (await GallerySaver.saveImage(correctFilePath))!;
      } else if (supportedVideoTypes.contains(newFileType)) {
        isSaved = (await GallerySaver.saveVideo(correctFilePath))!;
      }

      if (!isSaved) {
        throw Exception('Failed to save to gallery');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to Gallery: $correctFilePath')),
      );
    } catch (e) {
      debugPrint('Error saving file: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving file: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    requestPermissions();
    if (widget.videoPath != null) {
      _startVideoPlayer();
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Preview'),
        actions: [
          if (widget.imagePath != null || widget.videoPath != null)
            IconButton(
              icon: Icon(Icons.save),
              onPressed: () {
                if (widget.imagePath != null) {
                  _saveToGallery(widget.imagePath!);
                } else if (widget.videoPath != null) {
                  _saveToGallery(widget.videoPath!);
                }
              },
            ),
        ],
      ),
      body: Center(
        child: widget.imagePath != null
            ? FutureBuilder<bool>(
                future: File(widget.imagePath!).exists(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    if (snapshot.data ?? false) {
                      return WidgetZoom(
                        heroAnimationTag: 'tag',
                        zoomWidget: Image.file(
                          File(widget.imagePath!),
                          fit: BoxFit.cover,
                        ),
                      );
                    } else {
                      return Text('Image file not found');
                    }
                  } else {
                    return CircularProgressIndicator();
                  }
                },
              )
            : controller != null && controller!.value.isInitialized
                ? AspectRatio(
                    aspectRatio: controller!.value.aspectRatio,
                    child: VideoPlayer(controller!),
                  )
                : CircularProgressIndicator(),
      ),
    );
  }
}
