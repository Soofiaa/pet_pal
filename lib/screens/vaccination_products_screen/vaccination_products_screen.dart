import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/vaccination_product.dart';
import 'package:pet_pal/providers/vaccination_providers.dart';

class VaccinationProductsScreen extends ConsumerWidget {
  const VaccinationProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(vaccinationProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Vacunas'),
      ),
      body: productsAsync.when(
        data: (products) => products.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.vaccines_outlined, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      'No hay vacunas en el catálogo',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Guarda las vacunas frecuentes\npara calcular refuerzos automáticamente.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return ListTile(
                    title: Text(product.name),
                    subtitle: Text(
                        'Frecuencia recomendada: cada ${product.defaultFrequencyMonths} mes${product.defaultFrequencyMonths > 1 ? 'es' : ''}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDelete(context, ref, product),
                    ),
                    onTap: () => _showAddEditDialog(context, product),
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

  void _confirmDelete(BuildContext context, WidgetRef ref, VaccinationProduct product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Vacuna del Catálogo'),
        content: Text('¿Estás seguro de que quieres eliminar "${product.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              await ref.read(vaccinationProductsProvider.notifier).deleteProduct(product.id);
              if (context.mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showAddEditDialog(BuildContext context, VaccinationProduct? product) {
    showDialog(
      context: context,
      builder: (context) => _AddEditVaccinationProductDialog(product: product),
    );
  }
}

class _AddEditVaccinationProductDialog extends ConsumerStatefulWidget {
  final VaccinationProduct? product;
  const _AddEditVaccinationProductDialog({this.product});

  @override
  ConsumerState<_AddEditVaccinationProductDialog> createState() => __AddEditVaccinationProductDialogState();
}

class __AddEditVaccinationProductDialogState extends ConsumerState<_AddEditVaccinationProductDialog> {
  late TextEditingController _nameController;
  late TextEditingController _frequencyController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _frequencyController = TextEditingController(
      text: widget.product?.defaultFrequencyMonths.toString() ?? '12',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _frequencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product == null ? 'Añadir Vacuna' : 'Editar Vacuna'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la Vacuna',
                border: OutlineInputBorder(),
              ),
              enabled: !_isSaving,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _frequencyController,
              decoration: const InputDecoration(
                labelText: 'Refuerzo cada (meses)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              enabled: !_isSaving,
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
    final freq = int.tryParse(_frequencyController.text) ?? 12;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduce un nombre antes de guardar.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final existing = await ref.read(vaccinationProductsProvider.future);
      if (existing.any((p) => p.name.toLowerCase() == name.toLowerCase() && p.id != widget.product?.id)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ya existe una vacuna con este nombre.')),
          );
        }
        return;
      }

      if (widget.product == null) {
        await ref.read(vaccinationProductsProvider.notifier).addProduct(
              VaccinationProduct(
                name: name,
                defaultFrequencyMonths: freq,
              ),
            );
      } else {
        await ref.read(vaccinationProductsProvider.notifier).updateProduct(
              widget.product!.copyWith(
                name: name,
                defaultFrequencyMonths: freq,
              ),
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
