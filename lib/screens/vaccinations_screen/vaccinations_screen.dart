import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/vaccination.dart';
import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/screens/add_edit_vaccination_screen/add_edit_vaccination_screen.dart';
import 'package:intl/intl.dart';

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
    setState(() {
      _isLoading = true;
    });
    final vaccinations = await DatabaseHelper().getVaccinationsForPet(widget.pet.id);
    vaccinations.sort((a, b) => b.date.compareTo(a.date));
    setState(() {
      _vaccinations = vaccinations;
      _isLoading = false;
    });
  }

  Future<void> _deleteVaccination(String? vaccinationId) async {
    if (vaccinationId == null) return;
    final bool? confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: const Text('¿Estás seguro de que quieres eliminar esta vacunación?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await DatabaseHelper().deleteVaccination(vaccinationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vacunación eliminada con éxito.')),
        );
      }
      _loadVaccinations();
    }
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
            style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ),
      )
          : ListView.builder(
        itemCount: _vaccinations.length,
        itemBuilder: (context, index) {
          final vaccination = _vaccinations[index];
          return Dismissible(
            key: ValueKey(vaccination.id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (direction) async {
              await _deleteVaccination(vaccination.id);
              return false;
            },
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        vaccination.vaccineName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: vaccination.stickerPhotoPath != null
                          ? Image.file(
                        File(vaccination.stickerPhotoPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.broken_image, color: Colors.grey);
                        },
                      )
                          : const Icon(Icons.camera_alt, color: Colors.grey),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Text(
                        DateFormat('dd/MM/yyyy').format(vaccination.date),
                        textAlign: TextAlign.right,
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
                        _loadVaccinations();
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEditVaccinationScreen(petId: widget.pet.id),
            ),
          );
          _loadVaccinations();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}