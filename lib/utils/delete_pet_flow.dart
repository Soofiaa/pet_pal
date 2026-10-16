import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/providers/pets_providers.dart';
import 'package:pet_pal/services/image_storage_service.dart';

/// Pide confirmación y elimina la mascota con sus archivos y recordatorios.
/// Devuelve true si se eliminó.
Future<bool> confirmAndDeletePet(BuildContext context, Pet pet) async {
  final bool? confirm = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text('¿Estás seguro de que quieres eliminar a ${pet.name}? Esta acción no se puede deshacer.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      );
    },
  );

  if (confirm != true || !context.mounted) return false;

  final notifier = ProviderScope.containerOf(context).read(petsProvider.notifier);

  // Documentos y notas guardan archivos en disco (PDFs/imágenes/fotos)
  // que SQLite nunca borra por sí solo. Hay que leerlos y borrar sus
  // archivos ANTES de eliminar la mascota: una vez que deletePet()
  // corre, el cascade borra esas filas y ya no habría forma de saber
  // qué archivos correspondían a esta mascota.
  final documents = await DatabaseHelper().getDocumentsForPet(pet.id);
  for (final document in documents) {
    await ImageStorageService.deleteFileIfExist(document.filePath);
  }

  final notes = await DatabaseHelper().getNotesForPet(pet.id);
  for (final note in notes) {
    await ImageStorageService.deleteFilesIfExist(note.photoPaths);
  }

  // petsProvider.notifier.deletePet (nunca DatabaseHelper().deletePet
  // directo) para que PetRepository.deletePet cancele antes todos los
  // recordatorios pendientes de la mascota.
  await notifier.deletePet(pet.id);
  return true;
}
