import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:pet_pal/models/medication.dart';
import 'package:pet_pal/models/vaccination.dart';
import 'package:pet_pal/models/weight_record.dart';

final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

String generateWeightRecordsCsv(List<WeightRecord> records) {
  final rows = <List<dynamic>>[
    ['Fecha', 'Peso (kg)'],
    ...records.map((r) => [_dateFormat.format(r.date), r.weight]),
  ];
  return const ListToCsvConverter().convert(rows);
}

String generateVaccinationsCsv(List<Vaccination> vaccinations) {
  final rows = <List<dynamic>>[
    ['Fecha', 'Vacuna', 'Próxima dosis'],
    ...vaccinations.map((v) => [
          _dateFormat.format(v.date),
          v.vaccineName,
          v.nextDueDate != null ? _dateFormat.format(v.nextDueDate!) : '',
        ]),
  ];
  return const ListToCsvConverter().convert(rows);
}

String generateMedicationsCsv(List<Medication> medications) {
  final rows = <List<dynamic>>[
    ['Nombre', 'Dosis', 'Frecuencia', 'Inicio', 'Fin', 'Notas'],
    ...medications.map((m) => [
          m.name,
          m.dosage,
          m.frequency,
          _dateFormat.format(m.startDate),
          m.endDate != null ? _dateFormat.format(m.endDate!) : '',
          m.notes,
        ]),
  ];
  return const ListToCsvConverter().convert(rows);
}
