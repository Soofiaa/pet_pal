import 'package:flutter/material.dart';
import 'package:pet_pal/utils/event_type_details.dart';

/// Color por entidad para la grilla de funciones de PetDetailScreen y la guía.
/// Reutiliza [eventColorFor] para las entidades con `type` de evento asociado,
/// así todas las pantallas muestran el mismo color (el de su categoría, ver
/// theme/category_colors.dart). Signos vitales usa su tipo de evento propio.
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
  'vital_sign': eventColorFor('vital_sign'),
};

Color entityColorFor(String key) => entityColors[key] ?? Colors.grey;
