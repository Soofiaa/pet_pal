import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_pal/utils/event_type_details.dart';

void main() {
  // Tipos que emiten los modelos en `toEventMap` / `toEventMaps`.
  const emittedTypes = [
    'appointment',
    'deworming',
    'next_deworming',
    'document',
    'food_allergy',
    'food_record',
    'food_record_end',
    'medication',
    'medication_end',
    'note',
    'weight',
    'vaccination',
    'next_vaccination',
    'vital_sign',
  ];

  test('todo tipo de evento emitido tiene ícono propio (no el "?" genérico)', () {
    for (final type in emittedTypes) {
      expect(eventIconFor(type), isNot(Icons.help_outline), reason: type);
    }
  });

  test('los tipos de próxima dosis se consideran vencidos al pasar la fecha', () {
    expect(isOverdueEventType('next_vaccination'), isTrue);
    expect(isOverdueEventType('next_deworming'), isTrue);
    expect(isOverdueEventType('vaccination'), isFalse);
    expect(isOverdueEventType('note'), isFalse);
  });
}
