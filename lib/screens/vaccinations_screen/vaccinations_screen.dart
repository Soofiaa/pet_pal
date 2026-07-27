import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/vaccination.dart';
import 'package:pet_pal/screens/add_edit_vaccination_screen/add_edit_vaccination_screen.dart';
import 'package:pet_pal/screens/image_preview_screen/image_preview_screen.dart';
import 'package:pet_pal/services/image_storage_service.dart';
import 'package:pet_pal/services/reminder_scheduler.dart';

class VaccinationsScreen extends StatefulWidget {
  final Pet pet;

  const VaccinationsScreen({super.key, required this.pet});

  @override
  State<VaccinationsScreen> createState() => _VaccinationsScreenState();
}

class _VaccinationsScreenState extends State<VaccinationsScreen> {
  List<Vaccination> _vaccinations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVaccinations();
  }

  Future<void> _loadVaccinations() async {
    setState(() => _isLoading = true);

    final vaccinations =
    await DatabaseHelper().getVaccinationsForPet(widget.pet.id);

    vaccinations.sort((a, b) => b.date.compareTo(a.date));

    if (!mounted) return;

    setState(() {
      _vaccinations = vaccinations;
      _isLoading = false;
    });
  }

  void _openImage(String imagePath, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImagePreviewScreen(
          imagePath: imagePath,
          title: title,
        ),
      ),
    );
  }

  Future<void> _deleteVaccination(Vaccination vaccination) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: const Text(
            'Se eliminará esta vacunación y sus imágenes asociadas. ¿Deseas continuar?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await ImageStorageService.deleteFilesIfExist([
      vaccination.stickerPhotoPath,
      vaccination.extraPhotoPath,
    ]);

    await ReminderScheduler.cancelVaccinationReminder(vaccination);
    await DatabaseHelper().deleteVaccination(vaccination.id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vacunación eliminada con éxito.')),
    );

    await _loadVaccinations();
  }

  Widget _buildPhotoPreview({
    required String path,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _openImage(path, label),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(path),
              width: 78,
              height: 78,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 78,
                height: 78,
                color: Colors.grey.shade200,
                child: const Icon(
                  Icons.broken_image,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVaccinationCard(Vaccination vaccination) {
    final bool hasSticker =
    ImageStorageService.isValidLocalFile(vaccination.stickerPhotoPath);

    final bool hasExtra =
    ImageStorageService.isValidLocalFile(vaccination.extraPhotoPath);

    return Dismissible(
      key: ValueKey(vaccination.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await _deleteVaccination(vaccination);
        return false;
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vaccination.vaccineName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Aplicada: ${DateFormat('dd/MM/yyyy').format(vaccination.date)}',
                        ),
                        if (vaccination.nextDueDate != null)
                          Text(
                            'Próxima dosis: ${DateFormat('dd/MM/yyyy').format(vaccination.nextDueDate!)}',
                            style: TextStyle(color: Colors.green.shade700),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddEditVaccinationScreen(
                            petId: widget.pet.id,
                            vaccination: vaccination,
                          ),
                        ),
                      );

                      await _loadVaccinations();
                    },
                  ),
                ],
              ),

              if (hasSticker || hasExtra) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (hasSticker)
                      _buildPhotoPreview(
                        path: vaccination.stickerPhotoPath!,
                        label: 'Adhesivo',
                      ),
                    if (hasExtra)
                      _buildPhotoPreview(
                        path: vaccination.extraPhotoPath!,
                        label: 'Extra',
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vacunaciones de ${widget.pet.name}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _vaccinations.isEmpty
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'No hay vacunaciones registradas para esta mascota.',
            style: TextStyle(
              fontSize: 18,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      )
          : ListView.builder(
        itemCount: _vaccinations.length,
        itemBuilder: (context, index) {
          return _buildVaccinationCard(_vaccinations[index]);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEditVaccinationScreen(
                petId: widget.pet.id,
              ),
            ),
          );

          await _loadVaccinations();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}