import 'package:fl_chart/fl_chart.dart';
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

  Widget _buildWeightChart() {
    final DateTime firstDate = _weightRecords.first.date;

    final List<FlSpot> spots = _weightRecords.map((record) {
      final double daysSinceFirst =
          record.date.difference(firstDate).inDays.toDouble();
      return FlSpot(daysSinceFirst, record.weight);
    }).toList();

    // Si todos los registros cayeran en el mismo día (maxX 0), se fuerza un
    // rango mínimo de 1 día para que el eje X no quede degenerado.
    final double maxX = spots.last.x > 0 ? spots.last.x : 1;
    double bottomInterval = maxX / 4;
    if (bottomInterval < 1) bottomInterval = 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      child: SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: maxX,
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => Colors.green.shade700,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final DateTime date =
                        firstDate.add(Duration(days: spot.x.round()));
                    return LineTooltipItem(
                      '${DateFormat('dd/MM/yyyy').format(date)}\n'
                      '${spot.y.toStringAsFixed(2)} kg',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  interval: bottomInterval,
                  getTitlesWidget: (value, meta) {
                    final DateTime date =
                        firstDate.add(Duration(days: value.round()));
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(
                        DateFormat('dd/MM').format(date),
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  getTitlesWidget: (value, meta) {
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(
                        '${value.toStringAsFixed(0)} kg',
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
            ),
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: Colors.grey.shade300),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                color: Colors.green,
                barWidth: 3,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.green.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
          if (_weightRecords.length == 1)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Agrega al menos un registro más para ver la evolución del peso.',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            )
          else
            _buildWeightChart(),
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