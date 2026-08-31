import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/deworming.dart';
import 'package:pet_pal/models/deworming_product.dart';
import 'package:pet_pal/providers/deworming_providers.dart';
import '../deworming_products_screen/deworming_products_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class AddEditDewormingScreen extends ConsumerStatefulWidget {
  final Pet pet;
  final Deworming? deworming;

  const AddEditDewormingScreen({
    super.key,
    required this.pet,
    this.deworming,
  });

  @override
  ConsumerState<AddEditDewormingScreen> createState() => _AddEditDewormingScreenState();
}

class _AddEditDewormingScreenState extends ConsumerState<AddEditDewormingScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _productController;
  late TextEditingController _dateController;
  late TextEditingController _nextDateController;

  Deworming? _currentDeworming;

  String? _selectedType;
  int? _selectedFrequency;
  int _reminderDaysAhead = 0;
  bool _isSaving = false;
  bool _isRecurring = false;

  final List<Map<String, dynamic>> _frequencyOptions = [
    {'label': 'Manual', 'value': null},
    {'label': 'Cada 1 mes', 'value': 1},
    {'label': 'Cada 2 meses', 'value': 2},
    {'label': 'Cada 3 meses', 'value': 3},
    {'label': 'Cada 6 meses', 'value': 6},
    {'label': 'Cada 1 año', 'value': 12},
  ];

  @override
  void initState() {
    super.initState();
    _currentDeworming = widget.deworming;
    _productController = TextEditingController(text: _currentDeworming?.product ?? '');
    _dateController = TextEditingController(
      text: _currentDeworming != null
          ? DateFormat('dd/MM/yyyy').format(_currentDeworming!.date)
          : DateFormat('dd/MM/yyyy').format(DateTime.now()),
    );
    // effectiveNextDate() en vez de nextDate crudo: si el registro es
    // recurrente y su ciclo original ya pasó, esto muestra la próxima
    // fecha realmente vigente (la misma que ya está usando el recordatorio
    // programado), no una fecha vencida hace meses.
    _nextDateController = TextEditingController(
      text: _currentDeworming?.effectiveNextDate() != null
          ? DateFormat('dd/MM/yyyy').format(_currentDeworming!.effectiveNextDate()!)
          : '',
    );

    _selectedType = _currentDeworming?.type;
    _selectedFrequency = _currentDeworming?.frequencyMonths;
    _reminderDaysAhead = _currentDeworming?.reminderDaysAhead ?? 0;
    _isRecurring = _currentDeworming?.isRecurring ?? false;
  }

  @override
  void dispose() {
    _productController.dispose();
    _dateController.dispose();
    _nextDateController.dispose();
    super.dispose();
  }

  void _onProductSelected(DewormingProduct product) {
    setState(() {
      _productController.text = product.name;
      _selectedType = product.defaultType;
      _selectedFrequency = product.defaultFrequencyMonths;
      _calculateNextDate();
    });
  }

  // Menú de catálogo: reemplaza al viejo dropdown + autocompletar de nombres
  // ya escritos (fuente de nombres inconsistentes). Si el usuario escribe un
  // nombre libre en el campo, se guarda tal cual, sin sugerencias.
  Future<void> _showProductPicker() async {
    final List<DewormingProduct> products =
        ref.read(dewormingProductsProvider).asData?.value ?? [];

    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay productos guardados en el catálogo.')),
      );
      return;
    }

    final DewormingProduct? selected = await showModalBottomSheet<DewormingProduct>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Elegir del catálogo',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              for (final product in products)
                ListTile(
                  leading: const Icon(Icons.vaccines),
                  title: Text(product.name),
                  onTap: () => Navigator.of(context).pop(product),
                ),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      _onProductSelected(selected);
    }
  }

  void _calculateNextDate() {
    if (_selectedFrequency == null) return;
    if (_dateController.text.isEmpty) return;

    try {
      final date = DateFormat('dd/MM/yyyy').parse(_dateController.text);
      final nextDate = DateTime(date.year, date.month + _selectedFrequency!, date.day);
      _nextDateController.text = DateFormat('dd/MM/yyyy').format(nextDate);
    } catch (e) {
      debugPrint('Error al calcular próxima fecha: $e');
    }
  }

  Future<void> _saveDeworming() async {
    if (_isSaving) return;

    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      final newDeworming = Deworming(
        id: _currentDeworming?.id ?? const Uuid().v4(),
        petId: widget.pet.id,
        product: _productController.text,
        date: DateFormat('dd/MM/yyyy').parse(_dateController.text),
        nextDate: _nextDateController.text.isNotEmpty
            ? DateFormat('dd/MM/yyyy').parse(_nextDateController.text)
            : null,
        type: _selectedType,
        frequencyMonths: _selectedFrequency,
        reminderDaysAhead: _reminderDaysAhead,
        // Defensivo: no puede ser recurrente sin una frecuencia elegida,
        // aunque el switch haya quedado en true de una selección anterior.
        isRecurring: _selectedFrequency != null && _isRecurring,
      );

      final notifier = ref.read(dewormingsProvider(widget.pet.id).notifier);

      try {
        if (_currentDeworming == null) {
          await notifier.addDeworming(newDeworming);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Desparasitación agregada con éxito.')),
            );
          }
        } else {
          await notifier.updateDeworming(_currentDeworming!, newDeworming);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Desparasitación actualizada con éxito.')),
            );
          }
        }

        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        debugPrint('Error al guardar la desparasitación: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar la desparasitación: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa los campos marcados en rojo antes de guardar.')),
      );
    }
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      controller.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deworming == null ? 'Añadir Desparasitación' : 'Editar Desparasitación'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Gestionar Productos',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DewormingProductsScreen()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _productController,
                decoration: InputDecoration(
                  labelText: 'Producto/Medicina',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.vaccines),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.inventory_2),
                    tooltip: 'Elegir del catálogo',
                    onPressed: _showProductPicker,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, ingresa el nombre del producto.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Desparasitación',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: const [
                  DropdownMenuItem(value: 'interna', child: Text('Interna')),
                  DropdownMenuItem(value: 'externa', child: Text('Externa')),
                  DropdownMenuItem(value: 'ambas', child: Text('Ambas (I + E)')),
                ],
                onChanged: (value) {
                  setState(() => _selectedType = value);
                },
                validator: (value) {
                  if (value == null) return 'Por favor, selecciona el tipo.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Fecha de Aplicación',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () async {
                  await _selectDate(context, _dateController);
                  _calculateNextDate();
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, selecciona una fecha.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                initialValue: _selectedFrequency,
                decoration: const InputDecoration(
                  labelText: 'Frecuencia (Recordatorio)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.repeat),
                ),
                items: _frequencyOptions.map((opt) {
                  return DropdownMenuItem<int?>(
                    value: opt['value'],
                    child: Text(opt['label']),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedFrequency = value;
                    if (value == null) _isRecurring = false;
                    _calculateNextDate();
                  });
                },
              ),
              if (_selectedFrequency != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Recordarme automáticamente'),
                  subtitle: Text(
                    'Repite el recordatorio cada $_selectedFrequency ${_selectedFrequency == 1 ? 'mes' : 'meses'} sin tener que cargar un registro nuevo cada vez.',
                  ),
                  value: _isRecurring,
                  onChanged: (value) => setState(() => _isRecurring = value),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nextDateController,
                decoration: InputDecoration(
                  labelText: 'Próxima Fecha',
                  hintText: _selectedFrequency != null ? 'Calculada automáticamente' : 'Selección manual',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.next_plan),
                  suffixIcon: _selectedFrequency != null 
                      ? IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _selectDate(context, _nextDateController),
                          tooltip: 'Cambiar fecha calculada',
                        )
                      : null,
                ),
                readOnly: true,
                onTap: _selectedFrequency == null 
                    ? () => _selectDate(context, _nextDateController)
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _reminderDaysAhead,
                decoration: const InputDecoration(
                  labelText: 'Avisarme con anticipación',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notification_important),
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('El mismo día')),
                  DropdownMenuItem(value: 1, child: Text('1 día antes')),
                  DropdownMenuItem(value: 2, child: Text('2 días antes')),
                  DropdownMenuItem(value: 3, child: Text('3 días antes')),
                  DropdownMenuItem(value: 7, child: Text('1 semana antes')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _reminderDaysAhead = value);
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveDeworming,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(widget.deworming == null ? 'Guardar' : 'Actualizar'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
