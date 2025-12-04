import 'package:flutter/material.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/food_allergy.dart';
import 'package:pet_pal/data/database_helper.dart'; // Asegúrate de que esta es la única importación de DatabaseHelper
import 'package:pet_pal/screens/add_edit_food_allergy_screen/add_edit_food_allergy_screen.dart';
import 'package:intl/intl.dart';

class FoodAllergyScreen extends StatefulWidget {
  final Pet pet;

  const FoodAllergyScreen({super.key, required this.pet});

  @override
  State<FoodAllergyScreen> createState() => _FoodAllergyScreenState();
}

class _FoodAllergyScreenState extends State<FoodAllergyScreen> {
  List<FoodAllergy> _foodAllergies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFoodAllergies();
  }

  Future<void> _loadFoodAllergies() async {
    setState(() {
      _isLoading = true;
    });
    // CORREGIDO: Uso correcto del singleton DatabaseHelper
    final allergies = await DatabaseHelper().getFoodAllergiesForPet(widget.pet.id);
    allergies.sort((a, b) => b.dateRecorded.compareTo(a.dateRecorded));
    setState(() {
      _foodAllergies = allergies;
      _isLoading = false;
    });
  }

  Future<void> _deleteFoodAllergy(FoodAllergy foodAllergy) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: const Text('¿Estás seguro de que quieres eliminar esta alergia alimentaria?'),
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
      // CORREGIDO: Uso correcto del singleton DatabaseHelper
      await DatabaseHelper().deleteFoodAllergy(foodAllergy.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alergia alimentaria eliminada con éxito.')),
        );
      }
      _loadFoodAllergies();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Alergias de ${widget.pet.name}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _foodAllergies.isEmpty
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'No hay alergias alimentarias registradas para esta mascota.',
            style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ),
      )
          : ListView.builder(
        itemCount: _foodAllergies.length,
        itemBuilder: (context, index) {
          final allergy = _foodAllergies[index];
          return Dismissible(
            key: Key(allergy.id.toString()),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (direction) async {
              await _deleteFoodAllergy(allergy);
              return null;
            },
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: ListTile(
                leading: const Icon(Icons.warning_amber, color: Colors.amber),
                title: Text(
                  allergy.food,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Registrada el ${DateFormat('dd/MM/yyyy').format(allergy.dateRecorded)}',
                  style: const TextStyle(color: Colors.grey),
                ),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddEditFoodAllergyScreen(
                        petId: widget.pet.id,
                        foodAllergy: allergy,
                      ),
                    ),
                  );
                  _loadFoodAllergies();
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEditFoodAllergyScreen(petId: widget.pet.id),
            ),
          );
          _loadFoodAllergies();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}