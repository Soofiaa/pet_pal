import 'package:flutter/material.dart';
import 'package:pet_pal/utils/event_type_details.dart';

/// Color por entidad para la grilla de funciones de PetDetailScreen.
/// Fuente única de verdad compartida con CalendarScreen y
/// TodayDashboardSection: reutiliza [eventColorFor] de event_type_details.dart
/// para las entidades que ya tienen un `type` de evento asociado, así las
/// tres pantallas muestran el mismo color por función (antes cada una tenía
/// su propia paleta hardcodeada). Las dos entidades sin tipo de evento propio
/// (signos vitales, calculadora de alimento) se definen acá.
final Map<String, Color> entityColors = {
  'note': eventColorFor('note'),
  'appointment': eventColorFor('appointment'),
  'vaccination': eventColorFor('vaccination'),
  'medication': eventColorFor('medication'),
  'deworming': eventColorFor('deworming'),
  'weight': eventColorFor('weight'),
  'document': eventColorFor('document'),
  'food_allergy': eventColorFor('food_allergy'),
  'food_record': eventColorFor('food_record'),
  'vital_sign': Colors.indigo,
  'food_calculator': Colors.amber,
};

Color entityColorFor(String key) => entityColors[key] ?? Colors.grey;
