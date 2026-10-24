import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pet_pal/theme/app_theme.dart';
import 'package:pet_pal/theme/category_colors.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    group('tema ${brightness.name}', () {
      final theme = buildAppTheme(brightness);
      final scheme = theme.colorScheme;

      test('texto sobre botón primario cumple 4.5:1', () {
        expect(_contrast(scheme.primary, scheme.onPrimary), greaterThanOrEqualTo(4.5));
      });

      test('título de la barra superior cumple 4.5:1', () {
        final bar = theme.appBarTheme;
        expect(_contrast(bar.backgroundColor!, bar.foregroundColor!), greaterThanOrEqualTo(4.5));
      });

      test('texto principal y secundario sobre el fondo cumplen 4.5:1', () {
        expect(_contrast(scheme.surface, scheme.onSurface), greaterThanOrEqualTo(4.5));
        expect(_contrast(scheme.surface, scheme.onSurfaceVariant), greaterThanOrEqualTo(4.5));
      });

      test('color de error (vencido) legible como texto sobre el fondo', () {
        expect(_contrast(scheme.surface, scheme.error), greaterThanOrEqualTo(4.5));
      });

      test('el ícono del botón flotante cumple 3:1', () {
        final fab = theme.floatingActionButtonTheme;
        expect(_contrast(fab.backgroundColor!, fab.foregroundColor!), greaterThanOrEqualTo(3));
      });

      test('los colores de categoría se distinguen del fondo (3:1)', () {
        for (final color in [CategoryColors.health, CategoryColors.records, CategoryColors.agenda]) {
          expect(_contrast(scheme.surface, color), greaterThanOrEqualTo(3));
        }
      });
    });
  }
}
