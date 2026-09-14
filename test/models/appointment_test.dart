// Pruebas de Appointment.locationMapsUrl (link de Google Maps pegado a
// mano, reemplaza la búsqueda de direcciones vía Nominatim): confirma el
// round-trip toJson/fromJson, incluyendo el caso null -el campo es
// completamente opcional, nunca requerido para guardar una cita-.
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_pal/models/appointment.dart';

void main() {
  group('Appointment.locationMapsUrl', () {
    test('toJson/fromJson conservan el link cuando está presente', () {
      final appointment = Appointment(
        petId: 'pet-1',
        dateTime: DateTime(2026, 3, 15, 14, 30),
        title: 'Control anual',
        location: 'Clínica Veterinaria Central',
        locationMapsUrl: 'https://maps.app.goo.gl/AbCdEfGh',
      );

      final json = appointment.toJson();
      expect(json['locationMapsUrl'], 'https://maps.app.goo.gl/AbCdEfGh');

      final restored = Appointment.fromJson(json);
      expect(restored.locationMapsUrl, 'https://maps.app.goo.gl/AbCdEfGh');
      // location (texto libre) sigue siendo independiente del link.
      expect(restored.location, 'Clínica Veterinaria Central');
    });

    test('toJson/fromJson conservan null cuando no se pegó ningún link', () {
      final appointment = Appointment(
        petId: 'pet-1',
        dateTime: DateTime(2026, 3, 15, 14, 30),
        title: 'Control anual',
      );

      final json = appointment.toJson();
      expect(json['locationMapsUrl'], isNull);

      final restored = Appointment.fromJson(json);
      expect(restored.locationMapsUrl, isNull);
    });

    test('fromJson con la clave ausente (fila migrada del esquema viejo) da null', () {
      final appointment = Appointment(
        petId: 'pet-1',
        dateTime: DateTime(2026, 3, 15, 14, 30),
        title: 'Control anual',
      );
      final Map<String, dynamic> json = appointment.toJson()..remove('locationMapsUrl');

      final restored = Appointment.fromJson(json);
      expect(restored.locationMapsUrl, isNull);
    });

    test('copyWith actualiza el link sin tocar el resto de los campos', () {
      final original = Appointment(
        petId: 'pet-1',
        dateTime: DateTime(2026, 3, 15, 14, 30),
        title: 'Control anual',
      );

      final updated = original.copyWith(locationMapsUrl: 'https://maps.app.goo.gl/XyZ');

      expect(updated.locationMapsUrl, 'https://maps.app.goo.gl/XyZ');
      expect(updated.title, original.title);
      expect(updated.id, original.id);
    });
  });
}
