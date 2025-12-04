import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerExampleScreen extends StatefulWidget {
  const ImagePickerExampleScreen({super.key});

  @override
  State<ImagePickerExampleScreen> createState() => _ImagePickerExampleScreenState();
}

class _ImagePickerExampleScreenState extends State<ImagePickerExampleScreen> {
  String? _imagePath;
  final ImagePicker _picker = ImagePicker();

  Future<void> _showImageSourceDialog() async {
    return showDialog<void>(
      context: context, // 'context' está disponible aquí
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Seleccionar Imagen'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                GestureDetector(
                  onTap: () {
                    _pickImage(ImageSource.gallery);
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Galería'),
                  ),
                ),
                const Divider(),
                GestureDetector(
                  onTap: () {
                    _pickImage(ImageSource.camera);
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Cámara'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() { // 'setState' está disponible aquí
        _imagePath = pickedFile.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ejemplo de Cámara/Galería'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey),
                ),
                child: _imagePath != null
                    ? Image.file(
                  File(_imagePath!),
                  fit: BoxFit.cover,
                )
                    : const Icon(
                  Icons.add_a_photo,
                  size: 50,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _imagePath ?? 'Haz clic en el cuadro para seleccionar una imagen.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}