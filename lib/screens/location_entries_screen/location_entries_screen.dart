import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/location_entry.dart';
import 'package:pet_pal/providers/location_entry_providers.dart';
import 'package:pet_pal/widgets/empty_state.dart';

/// Administra el catálogo de ubicaciones, compartido entre todas las
/// mascotas (mismo diseño que VaccinationProductsScreen). Editar o eliminar
/// una entrada acá no afecta a las citas que ya la usaron: una cita guarda
/// su propia copia de name/mapsUrl al elegirla, no una referencia -ver
/// add_edit_appointment_screen.dart-.
class LocationEntriesScreen extends ConsumerWidget {
  const LocationEntriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(locationEntriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Ubicaciones'),
      ),
      body: entriesAsync.when(
        data: (entries) => entries.isEmpty
            ? const EmptyState(
                icon: Icons.location_on_outlined,
                message: 'Aún no hay lugares guardados en el catálogo.',
                actionHint: 'Presiona "+" para añadir uno nuevo.',
              )
            : ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return ListTile(
                    title: Text(entry.name),
                    subtitle: entry.mapsUrl.isEmpty
                        ? null
                        : Text(
                            entry.mapsUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDelete(context, ref, entry),
                    ),
                    onTap: () => _showAddEditDialog(context, entry),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(context, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, LocationEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Lugar del Catálogo'),
        content: Text(
          '¿Estás seguro de que quieres eliminar "${entry.name}"? Las citas '
          'que ya usaron este lugar no se ven afectadas.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              await ref.read(locationEntriesProvider.notifier).deleteEntry(entry.id);
              if (context.mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showAddEditDialog(BuildContext context, LocationEntry? entry) {
    showDialog(
      context: context,
      builder: (context) => _AddEditLocationEntryDialog(entry: entry),
    );
  }
}

class _AddEditLocationEntryDialog extends ConsumerStatefulWidget {
  final LocationEntry? entry;
  const _AddEditLocationEntryDialog({this.entry});

  @override
  ConsumerState<_AddEditLocationEntryDialog> createState() => __AddEditLocationEntryDialogState();
}

class __AddEditLocationEntryDialogState extends ConsumerState<_AddEditLocationEntryDialog> {
  late TextEditingController _nameController;
  late TextEditingController _mapsUrlController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.entry?.name ?? '');
    _mapsUrlController = TextEditingController(text: widget.entry?.mapsUrl ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mapsUrlController.dispose();
    super.dispose();
  }

  /// Misma validación laxa y no bloqueante que
  /// add_edit_appointment_screen.dart (solo el esquema de la URL): un texto
  /// de ayuda discreto, nunca impide guardar.
  bool get _mapsUrlLooksValid {
    final String text = _mapsUrlController.text.trim();
    return text.isEmpty || text.startsWith('http://') || text.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.entry == null ? 'Añadir Lugar' : 'Editar Lugar'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del lugar',
                border: OutlineInputBorder(),
              ),
              enabled: !_isSaving,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _mapsUrlController,
              decoration: InputDecoration(
                labelText: 'Enlace de Google Maps',
                border: const OutlineInputBorder(),
                helperText:
                    _mapsUrlLooksValid ? null : 'Pega el enlace que compartiste desde Google Maps.',
              ),
              keyboardType: TextInputType.url,
              enabled: !_isSaving,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduce un nombre antes de guardar.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final mapsUrl = _mapsUrlController.text.trim();
      if (widget.entry == null) {
        await ref.read(locationEntriesProvider.notifier).addEntry(
              LocationEntry(name: name, mapsUrl: mapsUrl),
            );
      } else {
        await ref.read(locationEntriesProvider.notifier).updateEntry(
              widget.entry!.copyWith(name: name, mapsUrl: mapsUrl),
            );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
