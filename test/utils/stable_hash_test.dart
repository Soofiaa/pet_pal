// Pruebas de stableNotificationId: el id de una notificación debe ser el
// mismo en cualquier ejecución, versión del SDK o plataforma. Los valores
// esperados son vectores de referencia de FNV-1a de 32 bits, recortados a
// 31 bits, así que este test falla si alguien cambia el algoritmo sin
// querer (y con él los ids de todos los recordatorios ya programados).
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_pal/utils/stable_hash.dart';

void main() {
  group('stableNotificationId', () {
    test('coincide con los vectores de referencia de FNV-1a (31 bits)', () {
      expect(stableNotificationId(''), 0x011C9DC5);
      expect(stableNotificationId('a'), 0x640C292C);
      expect(stableNotificationId('foobar'), 0x3F9CF968);
    });

    test('es determinista: la misma clave da siempre el mismo id', () {
      expect(stableNotificationId('med-1_0_3'), stableNotificationId('med-1_0_3'));
    });

    test('siempre cabe en un entero con signo de 32 bits y no es negativo', () {
      for (int i = 0; i < 1000; i++) {
        final int id = stableNotificationId('clave-$i');
        expect(id, inInclusiveRange(0, 0x7FFFFFFF));
      }
    });

    test(
      '250 claves (25 medicaciones x 2 horarios x 5 días) no colisionan',
      () {
        final ids = <int>{};
        for (int med = 0; med < 25; med++) {
          for (int time = 0; time < 2; time++) {
            for (int day = 0; day < 5; day++) {
              ids.add(stableNotificationId('med-${med}_${time}_$day'));
            }
          }
        }
        expect(ids, hasLength(250));
      },
    );
  });
}
