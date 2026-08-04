import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class ImageCropScreen extends StatelessWidget {
  final Uint8List imageBytes;
  final String title;

  const ImageCropScreen({
    super.key,
    required this.imageBytes,
    this.title = 'Recortar',
  });

  @override
  Widget build(BuildContext context) {
    return ProImageEditor.memory(
      imageBytes,
      callbacks: ProImageEditorCallbacks(
        onImageEditingComplete: (Uint8List bytes) async {
          Navigator.of(context).pop(bytes);
        },
      ),
    );
  }
}