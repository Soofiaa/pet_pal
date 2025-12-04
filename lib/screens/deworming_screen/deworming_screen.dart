
import 'package:flutter/material.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/deworming.dart';
import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/screens/add_edit_deworming_screen/add_edit_deworming_screen.dart';
import 'package:intl/intl.dart';

class DewormingScreen extends StatefulWidget {
  final Pet pet;

  const DewormingScreen({super.key, required this.pet});

  @override
  State<DewormingScreen> createState() => _DewormingScreenState();
}

class _DewormingScreenState extends State<DewormingScreen> {
  late Future<List<Deworming>> _dewormings;

  @override
  void initState() {
    super.initState();
    _loadDewormings();
  }

  void _loadDewormings() {
    setState(() {
      _dewormings = DatabaseHelper().getDewormingsForPet(widget.pet.id);
    });
  }

  Future<void> _confirmDelete(Deworming deworming) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Desparasitación'),
        content: Text('¿Estás seguro de que quieres eliminar la desparasitación "${deworming.product}" del ${DateFormat('dd/MM/yyyy').format(deworming.date)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await DatabaseHelper().deleteDeworming(deworming.id!);
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Desparasitación eliminada correctamente.')),
      );
      _loadDewormings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Desparasitaciones de ${widget.pet.name}'),
      ),
      body: FutureBuilder<List<Deworming>>(
        future: _dewormings,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay desparasitaciones registradas.'));
          } else {
            final dewormingList = snapshot.data!;
            return ListView.builder(
              itemCount: dewormingList.length,
              itemBuilder: (context, index) {
                final deworming = dewormingList[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: ListTile(
                    title: Text(deworming.product, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Fecha: ${DateFormat('dd/MM/yyyy').format(deworming.date)}'),
                        if (deworming.nextDate != null)
                          Text('Próxima fecha: ${DateFormat('dd/MM/yyyy').format(deworming.nextDate!)}'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddEditDewormingScreen(
                                  pet: widget.pet,
                                  deworming: deworming,
                                ),
                              ),
                            );
                            _loadDewormings();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDelete(deworming),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEditDewormingScreen(pet: widget.pet),
            ),
          );
          _loadDewormings();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}