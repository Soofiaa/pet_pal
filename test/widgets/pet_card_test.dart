import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_pal/models/dashboard_event.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/widgets/pet_card.dart';

Pet _pet({String name = 'Olivia', String? imageUrl}) => Pet(
      name: name,
      species: 'Perro',
      breed: 'Mestizo',
      dob: DateTime(2020, 1, 1),
      color: 'Marrón',
      imageUrl: imageUrl,
    );

Future<void> _pump(WidgetTester tester, Widget child, {double textScale = 1.0}) {
  return tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: Center(child: SizedBox(width: 180, height: 200, child: child))),
      ),
    ),
  );
}

void main() {
  testWidgets('muestra nombre, especie y edad, y avisa al tocarla', (tester) async {
    var taps = 0;
    final pet = _pet();
    await _pump(tester, PetCard(pet: pet, onTap: () => taps++));

    expect(find.text('Olivia'), findsOneWidget);
    expect(find.textContaining('Perro'), findsOneWidget);
    expect(find.textContaining(pet.detailedAge), findsOneWidget);

    await tester.tap(find.byType(PetCard));
    expect(taps, 1);
  });

  testWidgets('sin foto muestra el ícono de mascota como fondo', (tester) async {
    await _pump(tester, PetCard(pet: _pet(), onTap: () {}));

    expect(find.byIcon(Icons.pets), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('con una foto que no existe en disco cae al ícono, sin romper', (tester) async {
    await _pump(
      tester,
      PetCard(pet: _pet(imageUrl: '${Directory.systemTemp.path}/no_existe.jpg'), onTap: () {}),
    );

    expect(find.byIcon(Icons.pets), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('con foto válida la usa de fondo', (tester) async {
    final dir = Directory.systemTemp.createTempSync('pet_card_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/foto.png')..writeAsBytesSync(_transparentPng);

    await _pump(tester, PetCard(pet: _pet(imageUrl: file.path), onTap: () {}));

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('es un botón accesible con nombre, especie y edad', (tester) async {
    final handle = tester.ensureSemantics();
    final pet = _pet();
    await _pump(tester, PetCard(pet: pet, onTap: () {}));

    expect(
      tester.getSemantics(find.byType(PetCard)),
      matchesSemantics(
        isButton: true,
        hasTapAction: true,
        hasEnabledState: false,
        label: 'Olivia, Perro · ${pet.detailedAge}',
      ),
    );
    handle.dispose();
  });

  testWidgets('con la fuente al 200 % y un nombre largo no desborda', (tester) async {
    await _pump(
      tester,
      PetCard(pet: _pet(name: 'Princesa Olivia de la Montaña'), onTap: () {}),
      textScale: 2.0,
    );

    expect(tester.takeException(), isNull);
  });
  testWidgets('petAlertsFor deja un ícono por tipo, el más urgente, y omite lo lejano', (tester) async {
    final now = DateTime.now();
    DashboardEvent ev(String type, int days) => DashboardEvent(
          petId: 'p',
          petName: 'Olivia',
          date: now.add(Duration(days: days)),
          title: 't',
          type: type,
        );

    final alerts = petAlertsFor([
      ev('next_vaccination', 3),
      ev('next_vaccination', -10),
      ev('next_deworming', 30),
      ev('appointment', 2),
    ]);

    expect(alerts.map((a) => a.type), ['next_vaccination', 'appointment']);
    expect(alerts.first.isOverdue, isTrue);
  });

  testWidgets('muestra un ícono por pendiente y lo anuncia en la etiqueta', (tester) async {
    await _pump(
      tester,
      PetCard(
        pet: _pet(),
        onTap: () {},
        alerts: const [
          PetAlert(type: 'next_vaccination', urgency: DashboardUrgency.overdue),
          PetAlert(type: 'next_deworming', urgency: DashboardUrgency.upcoming),
        ],
      ),
    );

    expect(find.byIcon(Icons.vaccines), findsOneWidget);
    expect(find.byIcon(Icons.bug_report), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Vacuna vencida, Desparasitación próxima')),
      findsOneWidget,
    );
  });

  testWidgets('sin pendientes no dibuja íconos', (tester) async {
    await _pump(tester, PetCard(pet: _pet(), onTap: () {}));

    expect(find.byIcon(Icons.vaccines), findsNothing);
  });
}

const List<int> _transparentPng = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];
