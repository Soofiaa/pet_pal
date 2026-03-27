import 'package:flutter/material.dart';
import 'package:pet_pal/screens/add_edit_pet_screen/add_edit_pet_screen.dart';
import 'package:pet_pal/models/pet.dart';
import 'dart:io';
import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/screens/pet_detail_screen/pet_detail_screen.dart';
import 'package:pet_pal/services/data_backup_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Pet> _pets = [];
  bool _isLoading = true;

  final DataBackupService _backupService = DataBackupService();

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    setState(() {
      _isLoading = true;
    });
    final pets = await DatabaseHelper().getPets();
    setState(() {
      _pets = pets;
      _isLoading = false;
    });
    debugPrint('Mascotas cargadas desde la BD: ${_pets.length}');
  }

  Future<bool?> _deletePet(String petId, String petName) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text('¿Estás seguro de que quieres eliminar a $petName? Esta acción no se puede deshacer.'),
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
      await DatabaseHelper().deletePet(petId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$petName eliminada con éxito.')),
        );
      }
      _loadPets();
      return true;
    } else {
      _loadPets();
      return false;
    }
  }

  bool _hasValidPetImage(Pet pet) {
    final imagePath = pet.imageUrl;
    if (imagePath == null || imagePath.trim().isEmpty) return false;
    return File(imagePath).existsSync();
  }

  Future<void> _exportData() async {
    try {
      await _backupService.exportAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos exportados con éxito. Revisa tus archivos compartidos.')),
        );
      }
    } catch (e) {
      debugPrint('Error al exportar datos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar datos: $e')),
        );
      }
    }
  }

  Future<void> _importData() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importar Datos'),
        content: const Text('¿Estás seguro de que quieres importar datos? Esto sobrescribirá los datos actuales.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Importar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _backupService.importAllData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Datos importados con éxito.')),
          );
          _loadPets();
        }
      } catch (e) {
        debugPrint('Error al importar datos: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al importar datos: $e')),
          );
        }
      }
    }
  }

  Widget _buildPetCard(Pet pet) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PetDetailScreen(pet: pet),
          ),
        );
        _loadPets();
      },
      onLongPress: () {
        _deletePet(pet.id, pet.name);
      },
      child: Card(
        elevation: 4.0,
        margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 50.0),
          child: Row(
            children: [
              _hasValidPetImage(pet)
                  ? CircleAvatar(
                radius: 50,
                backgroundImage: FileImage(File(pet.imageUrl!)),
              )
                  : const CircleAvatar(
                radius: 50,
                child: Icon(Icons.pets, size: 60),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pet.name,
                      style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${pet.species} \n${pet.detailedAge}',
                      style: const TextStyle(fontSize: 20, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
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
        title: const Text('Mis Mascotas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload),
            onPressed: _exportData,
            tooltip: 'Exportar datos',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _importData,
            tooltip: 'Importar datos',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pets.isEmpty
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Aquí aparecerán tus mascotas registradas.\nPresiona "+" para añadir una nueva.',
            style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ),
      )
          : ListView.builder(
        itemCount: _pets.length,
        itemBuilder: (context, index) {
          final pet = _pets[index];
          return Dismissible(
            key: Key(pet.id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (direction) async {
              return await _deletePet(pet.id, pet.name);
            },
            child: _buildPetCard(pet),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditPetScreen(),
            ),
          );
          _loadPets();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
