import 'package:flutter/material.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/weight_record.dart';
import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/screens/add_edit_weight_record_screen/add_edit_weight_record_screen.dart';
import 'package:intl/intl.dart';

class WeightRecordScreen extends StatefulWidget {
  final Pet pet;

  const WeightRecordScreen({super.key, required this.pet});

  @override
  State<WeightRecordScreen> createState() => _WeightRecordScreenState();
}

class _WeightRecordScreenState extends State<WeightRecordScreen> {
  List<WeightRecord> _weightRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeightRecords();
  }

  Future<void> _loadWeightRecords() async {
    setState(() {
      _isLoading = true;
    });
    final records = await DatabaseHelper().getWeightRecordsForPet(widget.pet.id);
    records.sort((a, b) => a.date.compareTo(b.date));
    setState(() {
      _weightRecords = records;
      _isLoading = false;
    });
  }

  Future<void> _deleteRecord(WeightRecord record) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: const Text('¿Estás seguro de que quieres eliminar este registro de peso?'),
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
      await DatabaseHelper().deleteWeightRecord(record.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro de peso eliminado con éxito.')),
        );
      }
      _loadWeightRecords();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Registro de Peso de ${widget.pet.name}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _weightRecords.isEmpty
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'No hay registros de peso para esta mascota.',
            style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ),
      )
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _weightRecords.length,
              itemBuilder: (context, index) {
                final record = _weightRecords[index];
                return Dismissible(
                  key: Key(record.id.toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    await _deleteRecord(record);
                    return null;
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: ListTile(
                      leading: const Icon(Icons.monitor_weight, color: Colors.green),
                      title: Text(
                        'Peso: ${record.weight.toStringAsFixed(2)} kg',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Fecha: ${DateFormat('dd/MM/yyyy').format(record.date)}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddEditWeightRecordScreen(
                              petId: widget.pet.id,
                              weightRecord: record,
                            ),
                          ),
                        );
                        _loadWeightRecords();
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEditWeightRecordScreen(petId: widget.pet.id),
            ),
          );
          _loadWeightRecords();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}