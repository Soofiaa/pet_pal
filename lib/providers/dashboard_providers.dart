import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/dashboard_event.dart';
import 'package:pet_pal/models/medication_intake.dart';
import 'package:pet_pal/providers/database_providers.dart';
import 'package:pet_pal/providers/pets_providers.dart';

/// Vista agregada de "qué necesita atención hoy": combina los eventos
/// accionables (citas, próximas dosis, fin de tratamientos) de todas las
/// mascotas, ordenados por urgencia y luego por fecha. No es family: es
/// una única vista global derivada de [petsProvider] y de cada tabla de
/// DatabaseHelper, sin mutación propia.
final todayDashboardProvider =
    FutureProvider<List<DashboardEvent>>((ref) async {
  final pets = await ref.watch(petsProvider.future);
  final dbHelper = ref.watch(databaseHelperProvider);

  final events = <DashboardEvent>[];
  for (final pet in pets) {
    final rawEvents = await dbHelper.getAllEventsForPet(pet.id);
    final intakes = await dbHelper.getAllIntakesForPet(pet.id);
    events.addAll(DashboardEvent.fromEventMaps(rawEvents, pet, intakes: intakes));
  }

  events.sort((a, b) {
    final rankCompare = a.urgencyRank.compareTo(b.urgencyRank);
    if (rankCompare != 0) return rankCompare;
    return a.date.compareTo(b.date);
  });

  return events;
});
