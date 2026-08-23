import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/screens/add_edit_pet_screen/add_edit_pet_screen.dart';
import 'package:pet_pal/models/pet.dart';
import 'dart:io';
import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/providers/pets_providers.dart';
import 'package:pet_pal/screens/pet_detail_screen/pet_detail_screen.dart';
import 'package:pet_pal/screens/emergency_contacts_screen/emergency_contacts_screen.dart';
import 'package:pet_pal/screens/vaccination_products_screen/vaccination_products_screen.dart';
import 'package:pet_pal/screens/deworming_products_screen/deworming_products_screen.dart';
import 'package:pet_pal/screens/backup_settings_screen/backup_settings_screen.dart';
import 'package:pet_pal/services/image_storage_service.dart';
import 'package:pet_pal/providers/theme_mode_provider.dart';
import 'package:pet_pal/widgets/today_dashboard_section.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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
      // Documentos y notas guardan archivos en disco (PDFs/imágenes/fotos)
      // que SQLite nunca borra por sí solo. Hay que leerlos y borrar sus
      // archivos ANTES de eliminar la mascota: una vez que deletePet()
      // corre, el cascade borra esas filas y ya no habría forma de saber
      // qué archivos correspondían a esta mascota.
      final documents = await DatabaseHelper().getDocumentsForPet(petId);
      for (final document in documents) {
        await ImageStorageService.deleteFileIfExist(document.filePath);
      }

      final notes = await DatabaseHelper().getNotesForPet(petId);
      for (final note in notes) {
        await ImageStorageService.deleteFilesIfExist(note.photoPaths);
      }

      // petsProvider.notifier.deletePet (nunca DatabaseHelper().deletePet
      // directo) para que PetRepository.deletePet cancele antes todos los
      // recordatorios pendientes de la mascota.
      await ref.read(petsProvider.notifier).deletePet(petId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$petName eliminada con éxito.')),
        );
      }
      return true;
    } else {
      return false;
    }
  }

  bool _hasValidPetImage(Pet pet) {
    final imagePath = pet.imageUrl;
    if (imagePath == null || imagePath.trim().isEmpty) return false;
    return File(imagePath).existsSync();
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Claro';
      case ThemeMode.dark:
        return 'Oscuro';
      case ThemeMode.system:
        return 'Sistema';
    }
  }

  void _showThemeModeDialog(BuildContext context) {
    final current = ref.read(themeModeProvider);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apariencia'),
        content: RadioGroup<ThemeMode>(
          groupValue: current,
          onChanged: (value) {
            if (value != null) {
              ref.read(themeModeProvider.notifier).setThemeMode(value);
            }
            Navigator.of(dialogContext).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ThemeMode.values.map((mode) {
              return RadioListTile<ThemeMode>(
                title: Text(_themeModeLabel(mode)),
                value: mode,
              );
            }).toList(),
          ),
        ),
      ),
    );
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
        ref.read(petsProvider.notifier).refresh();
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
    final petsAsync = ref.watch(petsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Mascotas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.contact_phone),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EmergencyContactsScreen()),
            ),
            tooltip: 'Contactos de Emergencia',
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pets, size: 50),
                    SizedBox(height: 10),
                    Text(
                      'PetPal Manager',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('Apariencia'),
              subtitle: Text(_themeModeLabel(ref.watch(themeModeProvider))),
              onTap: () => _showThemeModeDialog(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Catálogo de Vacunas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VaccinationProductsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.medication),
              title: const Text('Catálogo de Desparasitantes'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DewormingProductsScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_backup_restore),
              title: const Text('Notificaciones y Respaldo'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BackupSettingsScreen()),
                );
              },
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Versión 1.0.0 (v26)', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          ],
        ),
      ),
      body: petsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error al cargar mascotas: $error')),
        data: (pets) {
          if (pets.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'Aquí aparecerán tus mascotas registradas.\nPresiona "+" para añadir una nueva.',
                  style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: TodayDashboardSection()),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final pet = pets[index];
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
                  childCount: pets.length,
                ),
              ),
            ],
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
          ref.read(petsProvider.notifier).refresh();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
