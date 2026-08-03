import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/emergency_contact.dart';
import 'package:pet_pal/providers/emergency_contact_providers.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyContactsScreen extends ConsumerWidget {
  const EmergencyContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(emergencyContactsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contactos de Emergencia'),
      ),
      body: contactsAsync.when(
        data: (contacts) => contacts.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.contact_phone_outlined, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      'Sin contactos de emergencia',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Guarda los datos de tu veterinario\no urgencias para acceso rápido.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: contacts.length,
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(_getIconForCategory(contact.category)),
                      ),
                      title: Text(contact.name),
                      subtitle: Text('${contact.category ?? 'Otros'} · ${contact.phone}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.phone, color: Colors.green),
                            onPressed: () => _makeCall(contact.phone),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(context, ref, contact),
                          ),
                        ],
                      ),
                      onTap: () => _showAddEditDialog(context, ref, contact),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(context, ref, null),
        child: const Icon(Icons.person_add),
      ),
    );
  }

  IconData _getIconForCategory(String? category) {
    switch (category) {
      case 'Veterinario':
        return Icons.local_hospital;
      case 'Urgencias':
        return Icons.emergency;
      case 'Paseador':
        return Icons.directions_walk;
      default:
        return Icons.person;
    }
  }

  Future<void> _makeCall(String phone) async {
    final Uri url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, EmergencyContact contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Contacto'),
        content: Text('¿Estás seguro de que quieres eliminar a "${contact.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              ref.read(emergencyContactsProvider.notifier).deleteContact(contact.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showAddEditDialog(BuildContext context, WidgetRef ref, EmergencyContact? contact) {
    showDialog(
      context: context,
      builder: (context) => _AddEditContactDialog(contact: contact),
    );
  }
}

class _AddEditContactDialog extends ConsumerStatefulWidget {
  final EmergencyContact? contact;
  const _AddEditContactDialog({this.contact});

  @override
  ConsumerState<_AddEditContactDialog> createState() => __AddEditContactDialogState();
}

class __AddEditContactDialogState extends ConsumerState<_AddEditContactDialog> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _notesController;
  String? _selectedCategory;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contact?.name ?? '');
    _phoneController = TextEditingController(text: widget.contact?.phone ?? '');
    _notesController = TextEditingController(text: widget.contact?.notes ?? '');
    _selectedCategory = widget.contact?.category ?? 'Veterinario';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.contact == null ? 'Añadir Contacto' : 'Editar Contacto'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
              enabled: !_isSaving,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder()),
              keyboardType: TextInputType.phone,
              enabled: !_isSaving,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'Veterinario', child: Text('Veterinario')),
                DropdownMenuItem(value: 'Urgencias', child: Text('Urgencias 24h')),
                DropdownMenuItem(value: 'Paseador', child: Text('Paseador')),
                DropdownMenuItem(value: 'Otros', child: Text('Otros')),
              ],
              onChanged: _isSaving ? null : (val) => setState(() => _selectedCategory = val),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notas (opcional)', border: OutlineInputBorder()),
              maxLines: 2,
              enabled: !_isSaving,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving ? const CircularProgressIndicator() : const Text('Guardar'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      if (widget.contact == null) {
        await ref.read(emergencyContactsProvider.notifier).addContact(
              EmergencyContact(name: name, phone: phone, category: _selectedCategory, notes: _notesController.text),
            );
      } else {
        await ref.read(emergencyContactsProvider.notifier).updateContact(
              widget.contact!.copyWith(name: name, phone: phone, category: _selectedCategory, notes: _notesController.text),
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
