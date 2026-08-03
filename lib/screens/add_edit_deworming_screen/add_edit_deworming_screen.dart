import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/deworming.dart';
import 'package:pet_pal/models/deworming_product.dart';
import 'package:pet_pal/data/database_helper.dart';
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
  List<String> _productSuggestions = [];

  String? _selectedType;
  int? _selectedFrequency;
  int _reminderDaysAhead = 0;

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
    _nextDateController = TextEditingController(
      text: _currentDeworming?.nextDate != null
          ? DateFormat('dd/MM/yyyy').format(_currentDeworming!.nextDate!)
          : '',
    );

    _selectedType = _currentDeworming?.type;
    _selectedFrequency = _currentDeworming?.frequencyMonths;
    _reminderDaysAhead = _currentDeworming?.reminderDaysAhead ?? 0;

    _loadProductSuggestions();
  }

  @override
  void dispose() {
    _productController.dispose();
    _dateController.dispose();
    _nextDateController.dispose();
    super.dispose();
  }

  Future<void> _loadProductSuggestions() async {
    final names = await DatabaseHelper().getDewormingProductNames();
    
    if (!mounted) return;

    setState(() {
      _productSuggestions = names;
    });
  }

  void _onProductSelected(DewormingProduct product) {
    setState(() {
      _productController.text = product.name;
      _selectedType = product.defaultType;
      _selectedFrequency = product.defaultFrequencyMonths;
      _calculateNextDate();
    });
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
    if (_formKey.currentState!.validate()) {
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
      }
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
    final productsAsync = ref.watch(dewormingProductsProvider);

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
              productsAsync.when(
                data: (products) {
                  if (products.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: DropdownButtonFormField<DewormingProduct>(
                      decoration: const InputDecoration(
                        labelText: 'Usar producto guardado',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.inventory_2),
                      ),
                      items: products.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                      onChanged: (val) {
                        if (val != null) _onProductSelected(val);
                      },
                    ),
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => const SizedBox.shrink(),
              ),
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _productController.text),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  final query = textEditingValue.text.trim().toLowerCase();

                  if (query.isEmpty) {
                    return _productSuggestions;
                  }

                  return _productSuggestions.where((option) {
                    return option.toLowerCase().contains(query);
                  });
                },
                onSelected: (String selection) {
                  _productController.text = selection;
                },
                fieldViewBuilder: (
                    context,
                    textEditingController,
                    focusNode,
                    onFieldSubmitted,
                    ) {
                  return TextFormField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Producto/Medicina',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.vaccines),
                    ),
                    onChanged: (value) {
                      _productController.text = value;
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor, ingresa el nombre del producto.';
                      }
                      return null;
                    },
                  );
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
                    _calculateNextDate();
                  });
                },
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
                onPressed: _saveDeworming,
                icon: const Icon(Icons.save),
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
