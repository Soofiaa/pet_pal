import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/deworming_product.dart';
import 'package:pet_pal/providers/deworming_providers.dart';

class DewormingProductsScreen extends ConsumerWidget {
  const DewormingProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(dewormingProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Desparasitantes'),
      ),
      body: productsAsync.when(
        data: (products) => products.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      'Tu catálogo está vacío',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Registra tus productos habituales\npara automatizar las fechas.',
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
                        'Frecuencia: cada ${product.defaultFrequencyMonths} mes${product.defaultFrequencyMonths > 1 ? 'es' : ''} · Tipo: ${product.defaultType ?? 'No definido'}'),
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

  void _confirmDelete(BuildContext context, WidgetRef ref, DewormingProduct product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: Text('¿Estás seguro de que quieres eliminar "${product.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              await ref.read(dewormingProductsProvider.notifier).deleteProduct(product.id);
              if (context.mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showAddEditDialog(BuildContext context, DewormingProduct? product) {
    showDialog(
      context: context,
      builder: (context) => _AddEditDewormingProductDialog(product: product),
    );
  }
}

class _AddEditDewormingProductDialog extends ConsumerStatefulWidget {
  final DewormingProduct? product;
  const _AddEditDewormingProductDialog({this.product});

  @override
  ConsumerState<_AddEditDewormingProductDialog> createState() => __AddEditDewormingProductDialogState();
}

class __AddEditDewormingProductDialogState extends ConsumerState<_AddEditDewormingProductDialog> {
  late TextEditingController _nameController;
  late TextEditingController _frequencyController;
  String? _selectedType;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _frequencyController = TextEditingController(
      text: widget.product?.defaultFrequencyMonths.toString() ?? '1',
    );
    _selectedType = widget.product?.defaultType;
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
      title: Text(widget.product == null ? 'Añadir Producto' : 'Editar Producto'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del Producto',
                border: OutlineInputBorder(),
              ),
              enabled: !_isSaving,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _frequencyController,
              decoration: const InputDecoration(
                labelText: 'Frecuencia (meses)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              enabled: !_isSaving,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Tipo predeterminado',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'interna', child: Text('Interna')),
                DropdownMenuItem(value: 'externa', child: Text('Externa')),
                DropdownMenuItem(value: 'ambas', child: Text('Ambas (I+E)')),
              ],
              onChanged: _isSaving ? null : (val) => setState(() => _selectedType = val),
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
    final freq = int.tryParse(_frequencyController.text) ?? 1;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduce un nombre antes de guardar.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final existing = await ref.read(dewormingProductsProvider.future);
      if (existing.any((p) => p.name.toLowerCase() == name.toLowerCase() && p.id != widget.product?.id)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ya existe un producto con este nombre.')),
          );
        }
        return;
      }

      if (widget.product == null) {
        await ref.read(dewormingProductsProvider.notifier).addProduct(
              DewormingProduct(
                name: name,
                defaultFrequencyMonths: freq,
                defaultType: _selectedType,
              ),
            );
      } else {
        await ref.read(dewormingProductsProvider.notifier).updateProduct(
              widget.product!.copyWith(
                name: name,
                defaultFrequencyMonths: freq,
                defaultType: _selectedType,
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
