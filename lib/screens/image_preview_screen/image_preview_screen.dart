import 'dart:io';

import 'package:flutter/material.dart';

class ImagePreviewScreen extends StatelessWidget {
  final String imagePath;
  final String title;

  const ImagePreviewScreen({
    super.key,
    required this.imagePath,
    this.title = 'Imagen',
  });

  @override
  Widget build(BuildContext context) {
    final File imageFile = File(imagePath);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: imageFile.existsSync()
            ? InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: Image.file(
                  imageFile,
                  fit: BoxFit.contain,
                ),
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, color: Colors.white70, size: 72),
                  SizedBox(height: 12),
                  Text(
                    'La imagen ya no está disponible.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
      ),
    );
  }
}
