// Primer widget test del repo (ver BACKLOG.md ítem 2 / Fase 5 del plan de
// implementación): pumpea TodayDashboardSection con todayDashboardProvider
// sobreescrito, sin tocar SQLite real ni providers intermedios.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pet_pal/models/dashboard_event.dart';
import 'package:pet_pal/providers/dashboard_providers.dart';
import 'package:pet_pal/widgets/today_dashboard_section.dart';

import '../helpers/pump_app.dart';

DashboardEvent _event({
  required String title,
  required DateTime date,
  String petName = 'Firulais',
  String type = 'appointment',
}) {
  return DashboardEvent(
    petId: 'pet-1',
    petName: petName,
    date: date,
    title: title,
    type: type,
  );
}

void main() {
  testWidgets('muestra un indicador de carga mientras el provider resuelve', (tester) async {
    await pumpApp(
      tester,
      const TodayDashboardSection(),
      overrides: [
        todayDashboardProvider.overrideWith((ref) => Completer<List<DashboardEvent>>().future),
      ],
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('no muestra nada si no hay eventos accionables', (tester) async {
    await pumpApp(
      tester,
      const TodayDashboardSection(),
      overrides: [
        todayDashboardProvider.overrideWith((ref) async => <DashboardEvent>[]),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Hoy'), findsNothing);
  });

  testWidgets('muestra el título "Hoy" y los eventos cuando hay datos', (tester) async {
    await pumpApp(
      tester,
      const TodayDashboardSection(),
      overrides: [
        todayDashboardProvider.overrideWith((ref) async => [
              _event(title: 'Cita: Control vencido', date: DateTime.now().subtract(const Duration(days: 2))),
              _event(title: 'Cita: Control futuro', date: DateTime.now().add(const Duration(days: 10))),
            ]),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Cita: Control vencido'), findsOneWidget);
    expect(find.text('Cita: Control futuro'), findsOneWidget);
  });

  testWidgets('el evento vencido se renderiza antes que el futuro', (tester) async {
    await pumpApp(
      tester,
      const TodayDashboardSection(),
      overrides: [
        todayDashboardProvider.overrideWith((ref) async => [
              _event(title: 'Vencido', date: DateTime.now().subtract(const Duration(days: 2))),
              _event(title: 'Futuro', date: DateTime.now().add(const Duration(days: 10))),
            ]),
      ],
    );
    await tester.pumpAndSettle();

    final vencidoOffset = tester.getTopLeft(find.text('Vencido')).dy;
    final futuroOffset = tester.getTopLeft(find.text('Futuro')).dy;
    expect(vencidoOffset, lessThan(futuroOffset));
  });

  testWidgets('muestra un mensaje de error si el provider falla', (tester) async {
    await pumpApp(
      tester,
      const TodayDashboardSection(),
      overrides: [
        todayDashboardProvider.overrideWith((ref) async => throw Exception('fallo de red')),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No se pudo cargar el resumen de hoy'), findsOneWidget);
  });
}
