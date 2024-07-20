import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:widget_zoom/widget_zoom.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

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

  Future<void> _convertImageToPng(String imagePath) async {
    try {
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image != null) {
        final pngBytes = img.encodePng(image);
        final pngFile =
            File(imagePath.replaceAll(RegExp(r'\.(jpg|jpeg)$'), '.png'));
        await pngFile.writeAsBytes(pngBytes);
        await GallerySaver.saveImage(pngFile.path);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Image converted to PNG and saved to Gallery')),
        );
      } else {
        throw Exception('Failed to decode image');
      }
    } catch (e) {
      debugPrint('Error converting image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error converting image: $e')),
      );
    }
  }

  Future<void> _convertImageToPdf(String imagePath) async {
    try {
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image != null) {
        final pdf = pw.Document();
        final pdfImage = pw.MemoryImage(imageBytes);

        pdf.addPage(
          pw.Page(
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Image(pdfImage),
              );
            },
          ),
        );

        final outputDir = await getExternalStorageDirectory();
        final pdfFile = File(
            '${outputDir!.path}/${DateTime.now().millisecondsSinceEpoch}.pdf');
        await pdfFile.writeAsBytes(await pdf.save());
        await GallerySaver.saveImage(pdfFile.path);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Image converted to PDF and saved to gallery')),
        );
      } else {
        throw Exception('Failed to decode image');
      }
    } catch (e) {
      debugPrint('Error converting image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error converting image: $e')),
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
        centerTitle: true,
        actions: [
          PopupMenuButton(
            onSelected: (value) async {
              if (value == 'Save') {
                if (widget.imagePath != null) {
                  _saveToGallery(widget.imagePath!);
                } else if (widget.videoPath != null) {
                  _saveToGallery(widget.videoPath!);
                }
              } else if (value == 'Share') {
                if (widget.imagePath != null) {
                  final xFile = XFile(widget.imagePath!);
                  await Share.shareXFiles([xFile],
                      text: 'Check out this image!');
                } else if (widget.videoPath != null) {
                  final xFile = XFile(widget.videoPath!);
                  await Share.shareXFiles([xFile],
                      text: 'Check out this video!');
                }
              } else if (value == 'Convert to PNG') {
                if (widget.imagePath != null) {
                  _convertImageToPng(widget.imagePath!);
                }
              } else if (value == 'Convert to PDF') {
                if (widget.imagePath != null) {
                  _convertImageToPdf(widget.imagePath!);
                }
              }
            },
            itemBuilder: (BuildContext bc) {
              return [
                PopupMenuItem(
                  value: 'Save',
                  child: Row(
                    children: [
                      Icon(Icons.save),
                      SizedBox(width: 10),
                      Text('Save'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'Share',
                  child: Row(
                    children: [
                      Icon(Icons.share),
                      SizedBox(width: 10),
                      Text('Share'),
                    ],
                  ),
                ),
                if (widget.imagePath != null) ...[
                  PopupMenuItem(
                    value: 'Convert to PNG',
                    child: Row(
                      children: [
                        Icon(Icons.image),
                        SizedBox(width: 10),
                        Text('Convert to PNG'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'Convert to PDF',
                    child: Row(
                      children: [
                        Icon(Icons.picture_as_pdf),
                        SizedBox(width: 10),
                        Text('Convert to PDF'),
                      ],
                    ),
                  ),
                ]
              ];
            },
          )
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
