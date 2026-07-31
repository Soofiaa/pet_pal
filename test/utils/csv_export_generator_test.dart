import 'package:flutter_test/flutter_test.dart';
import 'package:pet_pal/models/medication.dart';
import 'package:pet_pal/models/vaccination.dart';
import 'package:pet_pal/models/weight_record.dart';
import 'package:pet_pal/utils/csv_export_generator.dart';

void main() {
  group('generateWeightRecordsCsv', () {
    test('incluye cabecera y filas con fecha formateada', () {
      final csv = generateWeightRecordsCsv([
        WeightRecord(id: 1, petId: 'pet-1', weight: 10.5, date: DateTime(2026, 3, 10)),
      ]);

      final lines = csv.trim().split('\r\n');
      expect(lines[0], 'Fecha,Peso (kg)');
      expect(lines[1], '10/03/2026,10.5');
    });

    test('devuelve solo la cabecera si no hay registros', () {
      final csv = generateWeightRecordsCsv([]);
      expect(csv.trim(), 'Fecha,Peso (kg)');
    });
  });

  group('generateVaccinationsCsv', () {
    test('deja la columna de próxima dosis vacía si es null', () {
      final csv = generateVaccinationsCsv([
        Vaccination(petId: 'pet-1', vaccineName: 'Rabia', date: DateTime(2026, 1, 1)),
      ]);

      final lines = csv.trim().split('\r\n');
      expect(lines[1], '01/01/2026,Rabia,');
    });

    test('escapa correctamente un nombre de vacuna con coma', () {
      final csv = generateVaccinationsCsv([
        Vaccination(
          petId: 'pet-1',
          vaccineName: 'Rabia, refuerzo',
          date: DateTime(2026, 1, 1),
          nextDueDate: DateTime(2026, 7, 1),
        ),
      ]);

      final lines = csv.trim().split('\r\n');
      expect(lines[1], '01/01/2026,"Rabia, refuerzo",01/07/2026');
    });
  });

  group('generateMedicationsCsv', () {
    test('incluye todas las columnas esperadas', () {
      final csv = generateMedicationsCsv([
        Medication(
          petId: 'pet-1',
          name: 'Amoxicilina',
          dosage: '250mg',
          frequency: 'Cada 12 horas',
          notes: 'Con comida',
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 1, 10),
        ),
      ]);

      final lines = csv.trim().split('\r\n');
      expect(lines[0], 'Nombre,Dosis,Frecuencia,Inicio,Fin,Notas');
      expect(lines[1], 'Amoxicilina,250mg,Cada 12 horas,01/01/2026,10/01/2026,Con comida');
    });

    test('deja la columna de fin vacía si el tratamiento sigue activo', () {
      final csv = generateMedicationsCsv([
        Medication(
          petId: 'pet-1',
          name: 'Amoxicilina',
          dosage: '250mg',
          frequency: 'Diaria',
          notes: '',
          startDate: DateTime(2026, 1, 1),
        ),
      ]);

      final lines = csv.trim().split('\r\n');
      expect(lines[1], 'Amoxicilina,250mg,Diaria,01/01/2026,,');
    });
  });
}
