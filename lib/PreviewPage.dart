import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'dart:typed_data';

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
    final file = File(filePath);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      final result = await ImageGallerySaver.saveFile(filePath,
          name: "HayCam/${file.uri.pathSegments.last}");
      if (result['isSuccess']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to Gallery: ${result['filePath']}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save to gallery')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
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
            ? Image.file(
                File(widget.imagePath ?? ""),
                fit: BoxFit.cover,
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
