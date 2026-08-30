// Pruebas de la lógica pura reutilizable de pdf_generator.dart (Tareas 1-3
// de la revisión de generateHealthSummaryPdf): agrupamiento por nombre,
// reutilización del criterio de "aplicación más reciente" del dashboard, y
// ocultamiento de secciones vacías. No genera bytes de PDF -recorre el
// árbol de widgets `pw.*` real que devuelve buildHealthSummarySections,
// la misma lista que usa generateHealthSummaryPdf para renderizar-, así
// que estos tests verifican el comportamiento real, no una copia.
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:pet_pal/models/deworming.dart';
import 'package:pet_pal/models/document.dart';
import 'package:pet_pal/models/food_allergy.dart';
import 'package:pet_pal/models/medication.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/vaccination.dart';
import 'package:pet_pal/models/weight_record.dart';
import 'package:pet_pal/utils/pdf_generator.dart';

List<String> _collectSpanTexts(pw.InlineSpan span) {
  final texts = <String>[];
  if (span is pw.TextSpan) {
    if (span.text != null) texts.add(span.text!);
    if (span.children != null) {
      for (final child in span.children!) {
        texts.addAll(_collectSpanTexts(child));
      }
    }
  }
  return texts;
}

List<String> _collectTexts(pw.Widget widget) {
  if (widget is pw.RichText) {
    return _collectSpanTexts(widget.text);
  }
  if (widget is pw.Container) {
    return widget.child == null ? [] : _collectTexts(widget.child!);
  }
  if (widget is pw.SizedBox) {
    return widget.child == null ? [] : _collectTexts(widget.child!);
  }
  if (widget is pw.SingleChildWidget) {
    return widget.child == null ? [] : _collectTexts(widget.child!);
  }
  if (widget is pw.MultiChildWidget) {
    return widget.children.expand(_collectTexts).toList();
  }
  return [];
}

List<String> _allTexts(Iterable<pw.Widget> widgets) =>
    widgets.expand(_collectTexts).toList();

Pet _samplePet() {
  return Pet(
    name: 'Olivia',
    species: 'Perro',
    breed: 'Mestiza',
    dob: DateTime(2020, 1, 1),
    color: 'Negra',
  );
}

void main() {
  group('groupByNameSortedByDateDesc', () {
    test('agrupa por nombre y ordena cada grupo por fecha descendente', () {
      final items = [
        Deworming(id: 'a', petId: 'p1', product: 'Drontal', date: DateTime(2026, 1, 1)),
        Deworming(id: 'b', petId: 'p1', product: 'Bravecto', date: DateTime(2026, 3, 1)),
        Deworming(id: 'c', petId: 'p1', product: 'Drontal', date: DateTime(2026, 5, 1)),
      ];

      final grouped = groupByNameSortedByDateDesc<Deworming>(
        items,
        (d) => d.product,
        (d) => d.date,
      );

      expect(grouped.keys.toList(), ['Drontal', 'Bravecto']);
      expect(grouped['Drontal']!.map((d) => d.id), ['c', 'a']);
      expect(grouped['Bravecto']!.map((d) => d.id), ['b']);
    });

    test('lista vacía produce un mapa vacío', () {
      final grouped = groupByNameSortedByDateDesc<Deworming>([], (d) => d.product, (d) => d.date);
      expect(grouped, isEmpty);
    });
  });

  group('dewormingIdsWithUrgencyBadge', () {
    test('con dos aplicaciones del mismo producto, solo la más reciente queda marcada', () {
      final older = Deworming(id: 'old', petId: 'p1', product: 'Drontal', date: DateTime(2026, 1, 1));
      final newer = Deworming(id: 'new', petId: 'p1', product: 'Drontal', date: DateTime(2026, 5, 1));

      final winnerIds = dewormingIdsWithUrgencyBadge([older, newer]);

      expect(winnerIds, {'new'});
    });

    test('con productos distintos, cada uno tiene su propio ganador', () {
      final drontal = Deworming(id: 'd', petId: 'p1', product: 'Drontal', date: DateTime(2026, 1, 1));
      final bravecto = Deworming(id: 'b', petId: 'p1', product: 'Bravecto', date: DateTime(2026, 2, 1));

      final winnerIds = dewormingIdsWithUrgencyBadge([drontal, bravecto]);

      expect(winnerIds, {'d', 'b'});
    });

    test('sin desparasitaciones, no hay ganadores', () {
      expect(dewormingIdsWithUrgencyBadge([]), isEmpty);
    });
  });

  group('buildHealthSummarySections — ocultamiento de secciones vacías', () {
    test('con todas las listas vacías, ninguna sección aparece (ni título ni "Sin registros")', () {
      final texts = _allTexts(buildHealthSummarySections(
        _samplePet(),
        vaccinations: const [],
        medications: const [],
        dewormings: const [],
        foodAllergies: const [],
        weightRecords: const [],
        documents: const [],
        now: DateTime(2026, 6, 1),
      ));

      expect(texts, isNot(contains('Vacunas')));
      expect(texts, isNot(contains('Medicación')));
      expect(texts, isNot(contains('Desparasitación')));
      expect(texts, isNot(contains('Alergias Alimentarias')));
      expect(texts, isNot(contains('Peso')));
      expect(texts, isNot(contains('Documentos')));
      expect(texts, isNot(contains(contains('Sin registros'))));
      // Información General siempre se muestra, no depende de ninguna lista.
      expect(texts, contains('Información General'));
    });

    test('cada sección con datos muestra su título', () {
      final texts = _allTexts(buildHealthSummarySections(
        _samplePet(),
        vaccinations: [Vaccination(petId: 'p1', vaccineName: 'Rabia', date: DateTime(2026, 1, 1))],
        medications: [
          Medication(
            petId: 'p1',
            name: 'Amoxicilina',
            dosage: '250mg',
            frequency: 'Cada 12h',
            notes: '',
            startDate: DateTime(2026, 1, 1),
          ),
        ],
        dewormings: [Deworming(id: 'd1', petId: 'p1', product: 'Drontal', date: DateTime(2026, 1, 1))],
        foodAllergies: [FoodAllergy(petId: 'p1', food: 'Pollo', dateRecorded: DateTime(2026, 1, 1))],
        weightRecords: [WeightRecord(petId: 'p1', weight: 12.5, date: DateTime(2026, 1, 1))],
        documents: [
          Document(
            petId: 'p1',
            categoria: 'Receta',
            titulo: 'Análisis',
            fecha: DateTime(2026, 1, 1),
            filePath: '/tmp/doc.pdf',
          ),
        ],
        now: DateTime(2026, 6, 1),
      ));

      expect(texts, contains('Vacunas'));
      expect(texts, contains('Medicación'));
      expect(texts, contains('Desparasitación'));
      expect(texts, contains('Alergias Alimentarias'));
      expect(texts, contains('Peso'));
      expect(texts, contains('Documentos'));
    });
  });

  group('buildHealthSummarySections — desparasitaciones agrupadas (Tarea 1, caso real tipo Olivia)', () {
    test(
      'una aplicación vieja ya superada por una nueva no muestra "Vencida", '
      'aunque su propio nextDate ya haya pasado',
      () {
        final now = DateTime(2026, 6, 1);
        final oldApplication = Deworming(
          id: 'd-old',
          petId: 'p1',
          product: 'Drontal',
          date: DateTime(2026, 1, 1),
          nextDate: DateTime(2026, 2, 1), // vencido hace rato respecto de `now`
        );
        final newApplication = Deworming(
          id: 'd-new',
          petId: 'p1',
          product: 'Drontal',
          date: DateTime(2026, 5, 1),
          nextDate: DateTime(2026, 8, 1), // vigente respecto de `now`
        );

        final texts = _allTexts(buildHealthSummarySections(
          _samplePet(),
          vaccinations: const [],
          medications: const [],
          dewormings: [oldApplication, newApplication],
          foodAllergies: const [],
          weightRecords: const [],
          documents: const [],
          now: now,
        ));

        expect(texts, isNot(contains(contains('Vencida'))));
        expect(texts, contains(contains('Vigente hasta')));
        // Las dos aplicaciones siguen apareciendo en el historial.
        expect(texts.where((t) => t.contains('Fecha aplicada')), hasLength(2));
      },
    );

    test('sin una aplicación más nueva que la reemplace, la vencida sí muestra el badge', () {
      final now = DateTime(2026, 6, 1);
      final onlyApplication = Deworming(
        id: 'd1',
        petId: 'p1',
        product: 'Drontal',
        date: DateTime(2026, 1, 1),
        nextDate: DateTime(2026, 2, 1),
      );

      final texts = _allTexts(buildHealthSummarySections(
        _samplePet(),
        vaccinations: const [],
        medications: const [],
        dewormings: [onlyApplication],
        foodAllergies: const [],
        weightRecords: const [],
        documents: const [],
        now: now,
      ));

      expect(texts, contains(contains('Vencida')));
    });
  });

  group('buildHealthSummarySections — vacunas agrupadas por nombre (Tarea 2)', () {
    test('varias aplicaciones del mismo nombre aparecen todas, no solo la más reciente', () {
      final applications = [
        Vaccination(petId: 'p1', vaccineName: 'Rabia', date: DateTime(2026, 1, 1)),
        Vaccination(petId: 'p1', vaccineName: 'Rabia', date: DateTime(2026, 6, 1)),
        Vaccination(petId: 'p1', vaccineName: 'Rabia', date: DateTime(2026, 12, 1)),
      ];

      final texts = _allTexts(buildHealthSummarySections(
        _samplePet(),
        vaccinations: applications,
        medications: const [],
        dewormings: const [],
        foodAllergies: const [],
        weightRecords: const [],
        documents: const [],
        now: DateTime(2027, 1, 1),
      ));

      expect(texts.where((t) => t.contains('Fecha aplicada')), hasLength(3));
      // El nombre de la vacuna aparece una sola vez (encabezado del grupo),
      // no repetido por cada aplicación.
      expect(texts.where((t) => t == 'Rabia'), hasLength(1));
    });
  });
}
