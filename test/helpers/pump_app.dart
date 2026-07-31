import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Envuelve [child] en ProviderScope + MaterialApp para widget tests, con
/// los overrides de providers que cada test necesite. Evita repetir este
/// boilerplate en cada archivo de test de pantalla/widget -mockear vía
/// overrides de providers, no SQLite real, para que los widget tests
/// corran aislados y rápido.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: child),
    ),
  );
}
