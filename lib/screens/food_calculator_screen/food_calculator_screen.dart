import 'package:flutter/material.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/pet_food_config.dart';
import 'package:pet_pal/data/database_helper.dart';
import 'dart:math';

class FoodCalculatorScreen extends StatefulWidget {
  final Pet pet;
  const FoodCalculatorScreen({super.key, required this.pet});

  @override
  State<FoodCalculatorScreen> createState() => _FoodCalculatorScreenState();
}

class _FoodCalculatorScreenState extends State<FoodCalculatorScreen> {
  final _totalDailyGramsController = TextEditingController();
  final _kcalController = TextEditingController(text: '3500'); // Valor promedio
  int _portions = 2;
  double? _gramsPerPortion;
  String _selectedActivityFactor = '1.6'; // Adulto esterilizado

  final Map<String, String> _factors = {
    '1.2': 'Poco activo / Propenso a obesidad',
    '1.4': 'Adulto sedentario',
    '1.6': 'Adulto esterilizado',
    '1.8': 'Adulto activo (sin esterilizar)',
    '2.0': 'Muy activo / Trabajo',
    '3.0': 'Cachorro (4-12 meses)',
  };

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await DatabaseHelper().getFoodConfigForPet(widget.pet.id);
    if (!mounted) return;

    if (config != null) {
      setState(() {
        _totalDailyGramsController.text = config.dailyGrams.toStringAsFixed(0);
        _portions = config.portions;
        if (config.foodKcalPerKg != null) {
          _kcalController.text = config.foodKcalPerKg!.toStringAsFixed(0);
        }
        _calculate();
      });
    } else {
      // ✅ Automatización: Ajustar factor si está esterilizado
      if (widget.pet.isNeutered) {
        setState(() {
          _selectedActivityFactor = '1.6';
        });
      }
    }
  }

  Future<void> _saveConfig() async {
    final grams = double.tryParse(_totalDailyGramsController.text);
    if (grams == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduce una cantidad válida de gramos antes de guardar.')),
      );
      return;
    }

    final config = PetFoodConfig(
      petId: widget.pet.id,
      dailyGrams: grams,
      portions: _portions,
      foodKcalPerKg: double.tryParse(_kcalController.text),
    );

    await DatabaseHelper().insertOrUpdateFoodConfig(config);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración guardada correctamente')),
      );
    }
  }

  @override
  void dispose() {
    _totalDailyGramsController.dispose();
    _kcalController.dispose();
    super.dispose();
  }

  void _calculate() {
    final totalGrams = double.tryParse(_totalDailyGramsController.text);
    if (totalGrams != null) {
      setState(() {
        _gramsPerPortion = totalGrams / _portions;
      });
    }
  }

  void _showScientificDialog() {
    final weightController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Calculadora Científica (RER)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Calcula los gramos diarios basados en las necesidades energéticas reales.'),
                const SizedBox(height: 16),
                TextField(
                  controller: weightController,
                  decoration: const InputDecoration(labelText: 'Peso de la mascota (kg)', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedActivityFactor,
                  decoration: const InputDecoration(labelText: 'Nivel de actividad / Estado', border: OutlineInputBorder()),
                  items: _factors.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (val) => setDialogState(() => _selectedActivityFactor = val!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _kcalController,
                  decoration: const InputDecoration(labelText: 'kcal por kg de alimento', helperText: 'Dato en el envase (ej: 3500)', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                final w = double.tryParse(weightController.text);
                final k = double.tryParse(_kcalController.text);
                if (w == null || w <= 0 || k == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Introduce un peso mayor a cero y kcal válidas antes de calcular.')),
                  );
                  return;
                }

                // Fórmula RER: 70 * (peso ^ 0.75)
                final rer = 70 * pow(w, 0.75);
                final factor = double.parse(_selectedActivityFactor);
                final der = rer * factor; // Daily Energy Requirement
                final totalGrams = (der / k) * 1000;

                setState(() {
                  _totalDailyGramsController.text = totalGrams.toStringAsFixed(0);
                  _calculate();
                });
                Navigator.pop(context);
              },
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculadora de Alimento'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveConfig,
            tooltip: 'Guardar configuración',
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.restaurant, size: 50, color: Colors.brown),
                    const SizedBox(height: 10),
                    Text(
                      'Ración para ${widget.pet.name}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _showScientificDialog,
                      icon: const Icon(Icons.science),
                      label: const Text('Calcular según peso y actividad'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _totalDailyGramsController,
              decoration: const InputDecoration(
                labelText: 'Gramos totales al día',
                hintText: 'Ej: 150',
                helperText: 'Puedes ponerlo manual o usar el cálculo científico arriba',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.scale),
                suffixText: 'g',
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => _calculate(),
            ),
            const SizedBox(height: 24),
            Text(
              '¿En cuántas tomas al día repartir?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('1')),
                ButtonSegment(value: 2, label: Text('2')),
                ButtonSegment(value: 3, label: Text('3')),
                ButtonSegment(value: 4, label: Text('4')),
              ],
              selected: {_portions},
              onSelectionChanged: (Set<int> newSelection) {
                setState(() {
                  _portions = newSelection.first;
                  _calculate();
                });
              },
            ),
            const SizedBox(height: 32),
            if (_gramsPerPortion != null)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.brown.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.brown.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'CANTIDAD POR CADA TOMA',
                      style: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w600, color: Colors.brown),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          _gramsPerPortion!.toStringAsFixed(0),
                          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.brown),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'gramos',
                          style: TextStyle(fontSize: 20, color: Colors.brown),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Debes darle esta cantidad $_portions veces al día.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
