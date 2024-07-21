import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class ImageConvert extends StatefulWidget {
  @override
  _ImageConvertState createState() => _ImageConvertState();
}

class _ImageConvertState extends State<ImageConvert> {
  List<File> _images = [];
  final ImagePicker _picker = ImagePicker();
  String _status = 'No images selected';

  Future<void> _pickImages() async {
    final List<XFile>? pickedFiles = await _picker.pickMultiImage();

    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      List<File> imageFiles =
          pickedFiles.map((pickedFile) => File(pickedFile.path)).toList();
      setState(() {
        _images = imageFiles;
        _status = '${_images.length} images selected';
      });
    } else {
      setState(() {
        _status = 'No images selected';
      });
    }
  }

  Future<bool> _convertImageToPng(File image) async {
    final imageBytes = await image.readAsBytes();
    final decodedImage = img.decodeImage(imageBytes);

    if (decodedImage != null) {
      final pngBytes = img.encodePng(decodedImage);
      final pngFile =
          File(image.path.replaceAll(RegExp(r'\.(jpg|jpeg)$'), '.png'));
      await pngFile.writeAsBytes(pngBytes);

      final saved = await GallerySaver.saveImage(pngFile.path);
      return saved != null && saved;
    }
    return false;
  }

  Future<void> _convertAllImagesToPng() async {
    bool allConverted = true;
    for (File image in _images) {
      bool result = await _convertImageToPng(image);
      if (!result) allConverted = false;
    }
    setState(() {
      _status = allConverted
          ? 'All images converted to PNG and saved to gallery'
          : 'Failed to convert some images to PNG';
    });
  }

  Future<bool> _convertImageToPdf(File image) async {
    final imageBytes = await image.readAsBytes();
    final decodedImage = img.decodeImage(imageBytes);

    if (decodedImage != null) {
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

      return true;
    }
    return false;
  }

  Future<void> _convertAllImagesToPdf() async {
    bool allConverted = true;
    for (File image in _images) {
      bool result = await _convertImageToPdf(image);
      if (!result) allConverted = false;
    }
    setState(() {
      _status = allConverted
          ? 'All images converted to PDF and saved'
          : 'Failed to convert some images to PDF';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Image Convert'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: _pickImages,
              child: Text('Pick Images'),
            ),
            SizedBox(height: 20),
            _images.isNotEmpty
                ? Container(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _images.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: EdgeInsets.symmetric(horizontal: 5),
                          width: MediaQuery.of(context).size.width * 0.8,
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: FileImage(_images[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : Container(),
            SizedBox(height: 20),
            if (_images.isNotEmpty)
              Column(
                children: [
                  ElevatedButton(
                    onPressed: _convertAllImagesToPng,
                    child: Text('Convert All to PNG'),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _convertAllImagesToPdf,
                    child: Text('Convert All to PDF'),
                  ),
                ],
              ),
            SizedBox(height: 20),
            Text(_status),
          ],
        ),
      ),
    );
  }
}
