// Pruebas de la lógica pura reutilizable de pdf_generator.dart: vacunas
// como lista plana por fecha, desparasitación como una sola línea de
// tiempo por mascota (criterio propio de la ficha clínica, independiente
// del dashboard), y ocultamiento de secciones vacías. No genera bytes de
// PDF -recorre el árbol de widgets `pw.*` real que devuelve
// buildHealthSummarySections, la misma lista que usa
// generateHealthSummaryPdf para renderizar-, así que estos tests
// verifican el comportamiento real, no una copia.
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
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

/// Índice del widget de nivel superior que arma _buildPdfSectionTitle(title)
/// -un pw.Padding envolviendo el pw.Text con el título de sección- dentro de
/// la lista que devuelve buildHealthSummarySections. -1 si no aparece.
int _indexOfSectionTitle(List<pw.Widget> widgets, String title) {
  return widgets.indexWhere((w) => w is pw.Padding && _collectTexts(w).contains(title));
}

/// Widget de instrumentación para los tests de paginación real: delega todo
/// el layout/render a [child], pero además registra en qué página del
/// documento terminó pintándose -pw.Context.pageNumber es público
/// (widget.dart) y refleja la página real asignada durante el render, no
/// una estimación-. Permite verificar de forma determinista, sin parsear
/// bytes de PDF, si dos widgets terminaron en la misma página.
class _PageRecorder extends pw.StatelessWidget {
  _PageRecorder({required this.child, required this.onPaint});

  final pw.Widget child;
  final void Function(int pageNumber) onPaint;

  @override
  pw.Widget build(pw.Context context) => child;

  @override
  void paint(pw.Context context) {
    onPaint(context.pageNumber);
    super.paint(context);
  }
}

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
  group('dewormingIdsWithUrgencyBadge', () {
    test('con dos aplicaciones del mismo producto, solo la más reciente queda marcada', () {
      final older = Deworming(id: 'old', petId: 'p1', product: 'Drontal', date: DateTime(2026, 1, 1));
      final newer = Deworming(id: 'new', petId: 'p1', product: 'Drontal', date: DateTime(2026, 5, 1));

      final winnerIds = dewormingIdsWithUrgencyBadge([older, newer]);

      expect(winnerIds, {'new'});
    });

    test(
      'con productos distintos, gana la aplicación más reciente de TODAS '
      '(una sola línea de tiempo, no una por producto)',
      () {
        final drontal = Deworming(id: 'd', petId: 'p1', product: 'Drontal', date: DateTime(2026, 1, 1));
        final bravecto = Deworming(id: 'b', petId: 'p1', product: 'Bravecto', date: DateTime(2026, 2, 1));

        final winnerIds = dewormingIdsWithUrgencyBadge([drontal, bravecto]);

        expect(winnerIds, {'b'});
      },
    );

    test(
      'caso real tipo Olivia: 5 productos distintos, solo la aplicación con '
      'fecha más reciente de todas queda marcada, sin importar su producto',
      () {
        final applications = [
          Deworming(id: 'nexgard', petId: 'p1', product: 'Nexgard spectra', date: DateTime(2025, 11, 24)),
          Deworming(id: 'interno-externo', petId: 'p1', product: 'Interno/Externo', date: DateTime(2026, 1, 24)),
          Deworming(id: 'simparica', petId: 'p1', product: 'Simparica Trio', date: DateTime(2026, 3, 24)),
          Deworming(id: 'simparica-mebermic', petId: 'p1', product: 'Simparica+Mebermic', date: DateTime(2026, 5, 24)),
          Deworming(id: 'simparica-ambas', petId: 'p1', product: 'Simparica Trio (Ambas)', date: DateTime(2026, 8, 24)),
        ];

        final winnerIds = dewormingIdsWithUrgencyBadge(applications);

        expect(winnerIds, {'simparica-ambas'});
      },
    );

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

  group('buildHealthSummarySections — desparasitación como una sola línea de tiempo', () {
    test(
      'una aplicación vieja ya superada por una más reciente (de OTRO producto) '
      'no muestra "Vencida", aunque su propio nextDate ya haya pasado',
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
          product: 'Bravecto', // producto distinto: no debe importar para el criterio
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

    test(
      'caso real tipo Olivia: 5 productos distintos, solo la aplicación con fecha '
      'más reciente de todas muestra badge; el resto es historial plano sin badge',
      () {
        final now = DateTime(2026, 9, 1);
        final applications = [
          Deworming(id: 'nexgard', petId: 'p1', product: 'Nexgard spectra', date: DateTime(2025, 11, 24)),
          Deworming(id: 'interno-externo', petId: 'p1', product: 'Interno/Externo', date: DateTime(2026, 1, 24)),
          Deworming(id: 'simparica', petId: 'p1', product: 'Simparica Trio', date: DateTime(2026, 3, 24)),
          Deworming(id: 'simparica-mebermic', petId: 'p1', product: 'Simparica+Mebermic', date: DateTime(2026, 5, 24)),
          Deworming(
            id: 'simparica-ambas',
            petId: 'p1',
            product: 'Simparica Trio (Ambas)',
            date: DateTime(2026, 8, 24),
            nextDate: DateTime(2026, 11, 24),
          ),
        ];

        final texts = _allTexts(buildHealthSummarySections(
          _samplePet(),
          vaccinations: const [],
          medications: const [],
          dewormings: applications,
          foodAllergies: const [],
          weightRecords: const [],
          documents: const [],
          now: now,
        ));

        // Las 5 aplicaciones siguen apareciendo en el historial.
        expect(texts.where((t) => t.contains('Fecha aplicada')), hasLength(5));
        // Solo la más reciente de todas (Simparica Trio (Ambas)) muestra el
        // badge de vigencia; ninguna otra -sin importar su propia fecha o
        // producto- debería mostrar "Vencida" ni "Vigente hasta".
        expect(texts, contains(contains('Vigente hasta')));
        expect(texts.where((t) => t.contains('Vigente hasta') || t.contains('Vencida')), hasLength(1));
      },
    );
  });

  group('buildHealthSummarySections — vacunas como lista plana por fecha', () {
    test('todas las aplicaciones aparecen, ordenadas por fecha descendente, sin agrupar por nombre', () {
      final applications = [
        Vaccination(petId: 'p1', vaccineName: 'Rabia', date: DateTime(2026, 1, 1)),
        Vaccination(petId: 'p1', vaccineName: 'Polivalente', date: DateTime(2026, 6, 1)),
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

      final dateTexts = texts.where((t) => t.contains('Fecha aplicada')).toList();
      expect(dateTexts, hasLength(3));
      // "Rabia" aparece dos veces: una caja por aplicación, no agrupada.
      expect(texts.where((t) => t == 'Rabia'), hasLength(2));

      // Orden: fecha descendente (más reciente primero), sin agrupar por nombre.
      expect(dateTexts[0], contains('01/12/2026'));
      expect(dateTexts[1], contains('01/06/2026'));
      expect(dateTexts[2], contains('01/01/2026'));
    });
  });

  group('buildHealthSummarySections — grids de varias columnas', () {
    // Cada sección de grid queda como un único pw.Wrap de nivel superior en
    // la lista que devuelve buildHealthSummarySections -los pw.Wrap
    // anidados dentro de una caja de vacuna (para sus fotos) no cuentan acá
    // porque no son elementos de nivel superior-.
    pw.Wrap singleTopLevelGrid(List<pw.Widget> sections) => sections.whereType<pw.Wrap>().single;

    test('Vacunas: 3 registros arman un grid de 3 cajas, todas del mismo ancho', () {
      final result = buildHealthSummarySections(
        _samplePet(),
        vaccinations: [
          Vaccination(petId: 'p1', vaccineName: 'Rabia', date: DateTime(2026, 1, 1)),
          Vaccination(petId: 'p1', vaccineName: 'Polivalente', date: DateTime(2026, 2, 1)),
          Vaccination(petId: 'p1', vaccineName: 'Sextuple', date: DateTime(2026, 3, 1)),
        ],
        medications: const [],
        dewormings: const [],
        foodAllergies: const [],
        weightRecords: const [],
        documents: const [],
        now: DateTime(2026, 6, 1),
      );

      final grid = singleTopLevelGrid(result);
      expect(grid.children, hasLength(3));
      final widths = grid.children.map((c) => (c as pw.SizedBox).width).toSet();
      expect(widths, hasLength(1), reason: 'todas las columnas deben tener el mismo ancho');
    });

    test(
      'Desparasitación (3 columnas) queda con cajas más angostas que Vacunas '
      '(2 columnas) -mismo ancho de página, más columnas-',
      () {
        final vaccinationsResult = buildHealthSummarySections(
          _samplePet(),
          vaccinations: [Vaccination(petId: 'p1', vaccineName: 'Rabia', date: DateTime(2026, 1, 1))],
          medications: const [],
          dewormings: const [],
          foodAllergies: const [],
          weightRecords: const [],
          documents: const [],
          now: DateTime(2026, 6, 1),
        );
        final vaccinationColumnWidth =
            (singleTopLevelGrid(vaccinationsResult).children.single as pw.SizedBox).width!;

        final dewormingsResult = buildHealthSummarySections(
          _samplePet(),
          vaccinations: const [],
          medications: const [],
          dewormings: [
            Deworming(id: 'd1', petId: 'p1', product: 'Drontal', date: DateTime(2026, 1, 1)),
            Deworming(id: 'd2', petId: 'p1', product: 'Bravecto', date: DateTime(2026, 2, 1)),
            Deworming(id: 'd3', petId: 'p1', product: 'Nexgard', date: DateTime(2026, 3, 1)),
          ],
          foodAllergies: const [],
          weightRecords: const [],
          documents: const [],
          now: DateTime(2026, 6, 1),
        );
        final dewormingGrid = singleTopLevelGrid(dewormingsResult);
        expect(dewormingGrid.children, hasLength(3));
        final dewormingColumnWidth = (dewormingGrid.children.first as pw.SizedBox).width!;

        expect(dewormingColumnWidth, lessThan(vaccinationColumnWidth));
      },
    );

    test('Alergias Alimentarias: 2 registros arman un grid de 2 cajas', () {
      final result = buildHealthSummarySections(
        _samplePet(),
        vaccinations: const [],
        medications: const [],
        dewormings: const [],
        foodAllergies: [
          FoodAllergy(petId: 'p1', food: 'Pollo', dateRecorded: DateTime(2026, 1, 1)),
          FoodAllergy(petId: 'p1', food: 'Lácteos', dateRecorded: DateTime(2026, 2, 1)),
        ],
        weightRecords: const [],
        documents: const [],
        now: DateTime(2026, 6, 1),
      );

      final grid = singleTopLevelGrid(result);
      expect(grid.children, hasLength(2));
    });

    test('el grid de Vacunas contiene exactamente una caja por registro, sin perder ni duplicar', () {
      final result = buildHealthSummarySections(
        _samplePet(),
        vaccinations: List.generate(
          5,
          (i) => Vaccination(petId: 'p1', vaccineName: 'Vacuna $i', date: DateTime(2026, 1, i + 1)),
        ),
        medications: const [],
        dewormings: const [],
        foodAllergies: const [],
        weightRecords: const [],
        documents: const [],
        now: DateTime(2026, 6, 1),
      );

      expect(singleTopLevelGrid(result).children, hasLength(5));
    });

    test('Medicación no cambia a grid -sigue una caja por fila, sin pw.Wrap de nivel superior-', () {
      final result = buildHealthSummarySections(
        _samplePet(),
        vaccinations: const [],
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
        dewormings: const [],
        foodAllergies: const [],
        weightRecords: const [],
        documents: const [],
        now: DateTime(2026, 6, 1),
      );

      expect(result.whereType<pw.Wrap>(), isEmpty);
    });
  });

  group('buildHealthSummarySections — título nunca queda huérfano de su contenido', () {
    test(
      'cada sección con datos trae un pw.NewPage(freeSpace: kMinSectionHeight) '
      'como widget inmediatamente anterior a su título',
      () {
        final result = buildHealthSummarySections(
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
        );

        for (final title in [
          'Vacunas',
          'Medicación',
          'Desparasitación',
          'Alergias Alimentarias',
          'Peso',
          'Documentos',
        ]) {
          final titleIndex = _indexOfSectionTitle(result, title);
          expect(titleIndex, greaterThan(0), reason: 'no se encontró el título "$title"');

          final guard = result[titleIndex - 1];
          expect(guard, isA<pw.NewPage>(), reason: 'falta el guard antes de "$title"');
          expect(
            (guard as pw.NewPage).freeSpace,
            kMinSectionHeight,
            reason: '"$title" no usa el umbral compartido kMinSectionHeight',
          );
        }
      },
    );

    test('Información General -siempre visible, siempre primera- no lleva el guard', () {
      final result = buildHealthSummarySections(
        _samplePet(),
        vaccinations: const [],
        medications: const [],
        dewormings: const [],
        foodAllergies: const [],
        weightRecords: const [],
        documents: const [],
        now: DateTime(2026, 6, 1),
      );

      final titleIndex = _indexOfSectionTitle(result, 'Información General');
      expect(titleIndex, 0, reason: 'Información General debe ser siempre el primer widget');
    });
  });

  group('buildHealthSummarySections — paginación real: título y contenido nunca en páginas distintas', () {
    // contentHeight: mismo cálculo que usa pdf_generator.dart para el ancho
    // de columna (_kContentWidth), pero en altura. Ninguno de los dos
    // números está hardcodeado acá: se calculan a partir de kPageMargin y
    // kMinSectionHeight, las mismas constantes que usa la generación real,
    // así que si alguna cambia, este test se recalibra solo.
    final double contentHeight = PdfPageFormat.a4.height - (kPageMargin * 2);

    Future<Map<String, int>> renderWithFiller(double fillerHeight) async {
      final pageNumbers = <String, int>{};
      final document = pw.Document();

      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(kPageMargin),
          build: (pw.Context context) => [
            // Relleno de altura exacta: deja calibrado, a propósito, cuánto
            // espacio libre queda antes del guard -no es un volumen de
            // datos "al azar" esperando reproducir el bug por casualidad-.
            pw.SizedBox(height: fillerHeight),
            pw.NewPage(freeSpace: kMinSectionHeight),
            _PageRecorder(
              child: pw.Text('Título de sección de prueba'),
              onPaint: (n) => pageNumbers['title'] = n,
            ),
            _PageRecorder(
              child: pw.Text('Primer elemento de contenido de prueba'),
              onPaint: (n) => pageNumbers['content'] = n,
            ),
          ],
        ),
      );

      await document.save();
      return pageNumbers;
    }

    test(
      'con menos espacio libre que kMinSectionHeight, el guard fuerza el salto '
      'ANTES del título: título y contenido arrancan juntos en la página nueva',
      () async {
        // Deja exactamente 20pt menos que el umbral: el escenario real que
        // orfanaba el título -entraba solo, el contenido no-, antes de este fix.
        final fillerHeight = contentHeight - (kMinSectionHeight - 20);

        final pageNumbers = await renderWithFiller(fillerHeight);

        expect(pageNumbers['title'], isNotNull);
        expect(pageNumbers['content'], isNotNull);
        expect(pageNumbers['title'], pageNumbers['content'], reason: 'título y contenido en la misma página');
        expect(pageNumbers['title'], 2, reason: 'el relleno solo debería entrar en la página 1');
      },
    );

    test(
      'con más espacio libre que kMinSectionHeight, el guard NO fuerza un '
      'salto de página innecesario: título y contenido quedan en la página del relleno',
      () async {
        // Deja exactamente 50pt más que el umbral.
        final fillerHeight = contentHeight - (kMinSectionHeight + 50);

        final pageNumbers = await renderWithFiller(fillerHeight);

        expect(pageNumbers['title'], isNotNull);
        expect(pageNumbers['content'], isNotNull);
        expect(pageNumbers['title'], pageNumbers['content'], reason: 'título y contenido en la misma página');
        expect(pageNumbers['title'], 1, reason: 'no debería haber salto de página, sobraba espacio');
      },
    );
  });
}
