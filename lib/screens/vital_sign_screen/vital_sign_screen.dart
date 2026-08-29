import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/vital_sign_config.dart';
import 'package:pet_pal/models/vital_sign_record.dart';
import 'package:pet_pal/providers/vital_sign_providers.dart';
import 'package:pet_pal/screens/add_edit_vital_sign_screen/add_edit_vital_sign_screen.dart';
import 'package:pet_pal/widgets/empty_state.dart';

/// Generalización de weight_record_screen.dart: mismo patrón de gráfico
/// (días desde el primer registro) y lista, parametrizado por
/// VitalSignConfig en vez de asumir "peso en kg".
class VitalSignScreen extends ConsumerWidget {
  final Pet pet;
  final VitalSignType type;

  const VitalSignScreen({super.key, required this.pet, required this.type});

  VitalSignConfig get _config => vitalSignConfigs[type]!;

  Future<void> _deleteRecord(
    BuildContext context,
    WidgetRef ref,
    VitalSignRecord record,
  ) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text(
            '¿Estás seguro de que quieres eliminar este registro de ${_config.label.toLowerCase()}?',
          ),
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
      try {
        await ref
            .read(vitalSignRecordsProvider(pet.id).notifier)
            .deleteVitalSignRecord(record.id!);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Registro de ${_config.label.toLowerCase()} eliminado con éxito.',
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error al eliminar el registro de ${_config.label.toLowerCase()}: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error al eliminar el registro de ${_config.label.toLowerCase()}: $e',
              ),
            ),
          );
        }
      }
    }
  }

  Widget _buildChart(List<VitalSignRecord> records) {
    final DateTime firstDate = records.first.date;

    final List<FlSpot> spots = records.map((record) {
      final double daysSinceFirst =
          record.date.difference(firstDate).inDays.toDouble();
      return FlSpot(daysSinceFirst, record.value);
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
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: _config.normalMin,
                  color: Colors.grey,
                  strokeWidth: 1,
                  dashArray: const [4, 4],
                ),
                HorizontalLine(
                  y: _config.normalMax,
                  color: Colors.grey,
                  strokeWidth: 1,
                  dashArray: const [4, 4],
                ),
              ],
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => _config.chartColor.withValues(alpha: 0.9),
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final DateTime date =
                        firstDate.add(Duration(days: spot.x.round()));
                    return LineTooltipItem(
                      '${DateFormat('dd/MM/yyyy').format(date)}\n'
                      '${spot.y.toStringAsFixed(1)} ${_config.unit}',
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
                        '${value.toStringAsFixed(0)} ${_config.unit}',
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
                color: _config.chartColor,
                barWidth: 3,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: _config.chartColor.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<VitalSignRecord>> asyncAllRecords =
        ref.watch(vitalSignRecordsProvider(pet.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('${_config.label} de ${pet.name}'),
      ),
      body: asyncAllRecords.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Error: $error')),
        data: (allRecords) {
          final records = allRecords.where((r) => r.type == type).toList();

          if (records.isEmpty) {
            return EmptyState(
              icon: _config.icon,
              message: 'Aún no hay registros de ${_config.label.toLowerCase()} para ${pet.name}.',
              actionHint: 'Presiona "+" para añadir uno nuevo.',
            );
          }

          return Column(
            children: [
              if (records.length == 1)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Agrega al menos un registro más para ver la evolución de ${_config.label.toLowerCase()}.',
                    style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                _buildChart(records),
              Expanded(
                child: ListView.builder(
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final bool isAbnormal = _config.isAbnormal(record.value);
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
                        await _deleteRecord(context, ref, record);
                        return null;
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        color: isAbnormal ? Colors.red[50] : null,
                        child: ListTile(
                          leading: Icon(_config.icon, color: _config.chartColor),
                          title: Text(
                            '${_config.label}: ${record.value.toStringAsFixed(1)} ${_config.unit}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Fecha: ${DateFormat('dd/MM/yyyy').format(record.date)}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          trailing: isAbnormal
                              ? const Icon(Icons.warning_amber_rounded, color: Colors.red)
                              : null,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddEditVitalSignScreen(
                                  petId: pet.id,
                                  type: type,
                                  vitalSignRecord: record,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEditVitalSignScreen(petId: pet.id, type: type),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
