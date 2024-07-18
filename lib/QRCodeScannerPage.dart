import 'package:flutter/material.dart';
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'dart:typed_data';

class QRCodeScannerPage extends StatefulWidget {
  const QRCodeScannerPage({Key? key}) : super(key: key);

  @override
  _QRCodeScannerPageState createState() => _QRCodeScannerPageState();
}

class _QRCodeScannerPageState extends State<QRCodeScannerPage> {
  MobileScannerController? _controller;
  Uint8List? _scannedImage;
  String? _scannedValue;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('QR Code Scanner'),
      ),
      body: Column(
        children: [
          Expanded(
            child: AiBarcodeScanner(
              controller: _controller!,
              onDetect: (BarcodeCapture capture) {
                setState(() {
                  _scannedValue = capture.barcodes.first.rawValue;
                  _scannedImage = capture.image;
                });
              },
              onDispose: () {
                debugPrint("Barcode scanner disposed!");
              },
              validator: (value) {
                if (value.barcodes.isEmpty) {
                  return false;
                }
                if (!(value.barcodes.first.rawValue?.contains('flutter.dev') ??
                    false)) {
                  return false;
                }
                return true;
              },
            ),
          ),
          _scannedValue != null
              ? Text('Scanned Data: $_scannedValue')
              : SizedBox(),
          _scannedImage != null ? Image.memory(_scannedImage!) : SizedBox(),
        ],
      ),
    );
  }
}
