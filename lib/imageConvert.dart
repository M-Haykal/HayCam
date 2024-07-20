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
  File? _image;
  final ImagePicker _picker = ImagePicker();
  String _status = 'No image selected';
  bool _isImageSelected = false;

  Future<void> _pickImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      setState(() {
        _image = imageFile;
        _status = 'Image selected';
        _isImageSelected = true;
      });
    } else {
      setState(() {
        _status = 'No image selected';
        _isImageSelected = false;
      });
    }
  }

  Future<void> _convertImageToPng() async {
    if (_image == null) {
      setState(() {
        _status = 'No image to convert';
      });
      return;
    }

    final imageBytes = await _image!.readAsBytes();
    final image = img.decodeImage(imageBytes);

    if (image != null) {
      final pngBytes = img.encodePng(image);

      final pngFile =
          File(_image!.path.replaceAll(RegExp(r'\.(jpg|jpeg)$'), '.png'));
      await pngFile.writeAsBytes(pngBytes);

      final saved = await GallerySaver.saveImage(pngFile.path);

      if (saved != null && saved) {
        setState(() {
          _status =
              'Image converted to PNG and saved to gallery as ${pngFile.path}';
        });
      } else {
        setState(() {
          _status = 'Failed to save image to gallery';
        });
      }
    } else {
      setState(() {
        _status = 'Failed to decode image';
      });
    }
  }

  Future<void> _convertImageToPdf() async {
    if (_image == null) {
      setState(() {
        _status = 'No image to convert';
      });
      return;
    }

    final imageBytes = await _image!.readAsBytes();
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

      setState(() {
        _status = 'Image converted to PDF and saved as ${pdfFile.path}';
      });
    } else {
      setState(() {
        _status = 'Failed to decode image';
      });
    }
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
              onPressed: _pickImage,
              child: Text('Pick an Image'),
            ),
            SizedBox(height: 20),
            _image != null
                ? Container(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height * 0.5,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: FileImage(_image!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                : Container(),
            SizedBox(height: 20),
            if (_isImageSelected)
              Column(
                children: [
                  ElevatedButton(
                    onPressed: _convertImageToPng,
                    child: Text('Convert to PNG'),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _convertImageToPdf,
                    child: Text('Convert to PDF'),
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
