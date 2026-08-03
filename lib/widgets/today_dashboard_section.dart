import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pet_pal/models/dashboard_event.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/providers/dashboard_providers.dart';
import 'package:pet_pal/providers/database_providers.dart';
import 'package:pet_pal/screens/appointments_screen/appointments_screen.dart';
import 'package:pet_pal/screens/deworming_screen/deworming_screen.dart';
import 'package:pet_pal/screens/medications_screen/medications_screen.dart';
import 'package:pet_pal/screens/today_events_screen/today_events_screen.dart';
import 'package:pet_pal/screens/vaccinations_screen/vaccinations_screen.dart';
import 'package:pet_pal/utils/event_type_details.dart';

/// Sección "Hoy" al tope de HomeScreen: combina los eventos accionables de
/// todas las mascotas (citas, próximas dosis, fin de tratamientos),
/// mostrando primero los más urgentes. Ver BACKLOG.md ítem 1.
class TodayDashboardSection extends ConsumerWidget {
  const TodayDashboardSection({super.key});

  static const int _maxVisibleEvents = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(todayDashboardProvider);

    return dashboardAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24.0),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'No se pudo cargar el resumen de hoy: $error',
          style: TextStyle(color: Colors.red[700]),
        ),
      ),
      data: (events) {
        if (events.isEmpty) {
          return const SizedBox.shrink();
        }

        final visibleEvents = events.take(_maxVisibleEvents).toList();
        final remaining = events.length - visibleEvents.length;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hoy', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ...visibleEvents.map(
                (event) => DashboardEventTile(event: event),
              ),
              if (remaining > 0)
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TodayEventsScreen(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                    child: Text(
                      'y $remaining más...',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ),
              const Divider(height: 24),
            ],
          ),
        );
      },
    );
  }
}

/// Pantalla de la mascota que corresponde a cada tipo de evento accionable
/// del dashboard, o `null` si el tipo no tiene una pantalla asociada (mismo
/// patrón de navegación que `pet_detail_screen.dart`: pushear la pantalla
/// del rubro con `pet: pet`). Función pura y testeable por separado del
/// resto de [DashboardEventTile._onTap] (resolución async del [Pet] y
/// manejo de mascota inexistente).
Widget? screenForDashboardEventType(String type, Pet pet) {
  switch (type) {
    case 'appointment':
      return AppointmentsScreen(pet: pet);
    case 'next_vaccination':
      return VaccinationsScreen(pet: pet);
    case 'next_deworming':
      return DewormingScreen(pet: pet);
    case 'medication_end':
      return MedicationsScreen(pet: pet);
    default:
      return null;
  }
}

/// Tarjeta de un [DashboardEvent], reutilizada tanto en [TodayDashboardSection]
/// como en [TodayEventsScreen]. Al tocarla, navega a la pantalla de la
/// mascota correspondiente al tipo de evento.
class DashboardEventTile extends ConsumerWidget {
  const DashboardEventTile({super.key, required this.event});

  final DashboardEvent event;

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    final dbHelper = ref.read(databaseHelperProvider);
    final pet = await dbHelper.getPetById(event.petId);
    if (pet == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${event.petName} ya no existe.')),
        );
      }
      return;
    }
    if (!context.mounted) return;

    final screen = screenForDashboardEventType(event.type, pet);
    if (screen == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOverdue = event.urgency == DashboardUrgency.overdue;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      color: isOverdue ? colorScheme.errorContainer : null,
      child: ListTile(
        onTap: () => _onTap(context, ref),
        leading: Icon(eventIconFor(event.type), color: eventColorFor(event.type)),
        title: Text(
          event.title,
          style: isOverdue ? TextStyle(color: colorScheme.onErrorContainer) : null,
        ),
        subtitle: Text(
          '${event.petName} · ${DateFormat('dd/MM/yyyy').format(event.date)}',
          style: isOverdue ? TextStyle(color: colorScheme.onErrorContainer) : null,
        ),
        trailing: isOverdue
            ? Icon(Icons.warning_amber_rounded, color: colorScheme.error)
            : null,
      ),
    );
  }
}
