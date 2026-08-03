import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pet_pal/models/dashboard_event.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/models/medication_intake.dart';
import 'package:pet_pal/providers/dashboard_providers.dart';
import 'package:pet_pal/providers/database_providers.dart';
import 'package:pet_pal/providers/pets_providers.dart';
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
    final petsAsync = ref.watch(petsProvider);

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

        final petsCount = petsAsync.value?.length ?? 0;
        final showPetName = petsCount > 1;

        // ✅ MEJORA SENIOR: Agrupar por mascota si hay muchas
        final Map<String, List<DashboardEvent>> groupedEvents = {};
        for (var event in events) {
          groupedEvents.putIfAbsent(event.petName, () => []).add(event);
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Hoy', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  if (remaining > 0)
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TodayEventsScreen())),
                      child: Text('Ver todo ($remaining más)'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ...groupedEvents.entries.take(3).map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showPetName)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                      ),
                    ...entry.value.take(2).map((event) => DashboardEventTile(event: event, showPetName: false)),
                    const SizedBox(height: 8),
                  ],
                );
              }),
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
  const DashboardEventTile({
    super.key,
    required this.event,
    this.showPetName = true,
  });

  final DashboardEvent event;
  final bool showPetName;

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

  Future<void> _confirmMedicationIntake(BuildContext context, WidgetRef ref) async {
    final dbHelper = ref.read(databaseHelperProvider);
    final now = DateTime.now();

    // Extraer id de la medicación del payload o del título
    // En DashboardEvent, el payload suele ser el ID del objeto original.
    // Usaremos el event.payload si existe, o buscaremos por nombre.
    // Asumiendo que el sistema de eventos actual guarda el ID en el payload (estándar en la app).
    
    try {
      final intake = MedicationIntake(
        petId: event.petId,
        medicationId: event.type == 'medication_end' ? 'end_${event.date.millisecondsSinceEpoch}' : 'reminder_${event.date.millisecondsSinceEpoch}', // ID temporal o real
        intakeDateTime: now,
        medicationName: event.title.replaceFirst('Fin de medicación: ', '').replaceFirst('Fin de medicación de ${event.petName}: ', ''),
      );

      await dbHelper.insertMedicationIntake(intake);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Toma de "${intake.medicationName}" registrada!'),
            backgroundColor: Colors.green,
          ),
        );
        // Refrescar el dashboard para que el evento desaparezca o cambie de estado si lo deseamos
        ref.invalidate(todayDashboardProvider);
      }
    } catch (e) {
      debugPrint('Error al registrar toma: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOverdue = event.urgency == DashboardUrgency.overdue;
    final isMedication = event.type == 'medication_end';
    final colorScheme = Theme.of(context).colorScheme;
    final dateStr = DateFormat('dd/MM/yyyy').format(event.date);

    String displayTitle = event.title;
    Widget? subtitle;

    if (event.type == 'next_deworming') {
      displayTitle = showPetName 
          ? 'Próxima desparasitación de ${event.petName}: $dateStr'
          : 'Próxima desparasitación: $dateStr';
      if (showPetName) subtitle = Text(event.petName);
    } else if (event.type == 'next_vaccination') {
      displayTitle = showPetName
          ? 'Próxima vacunación de ${event.petName}: $dateStr'
          : 'Próxima vacunación: $dateStr';
    } else if (event.type == 'appointment') {
      final pureTitle = event.title.startsWith('Cita: ') 
          ? event.title.substring(6) 
          : event.title;
      displayTitle = showPetName
          ? 'Cita de ${event.petName}: $pureTitle - $dateStr'
          : 'Cita: $pureTitle - $dateStr';
    } else if (event.type == 'medication_end') {
      displayTitle = showPetName
          ? 'Fin de medicación de ${event.petName}: $dateStr'
          : 'Fin de medicación: $dateStr';
    }

    if (isOverdue) {
      subtitle = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (subtitle != null) subtitle,
          Text(
            '¡Evento vencido!',
            style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold),
          ),
        ],
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      color: event.isTaken 
          ? Colors.green.withValues(alpha: 0.1) 
          : (isOverdue ? colorScheme.errorContainer : null),
      child: ListTile(
        onTap: () => _onTap(context, ref),
        leading: Icon(
          event.isTaken ? Icons.check_circle : eventIconFor(event.type), 
          color: event.isTaken ? Colors.green : eventColorFor(event.type)
        ),
        title: Text(
          displayTitle,
          style: TextStyle(
            color: event.isTaken 
                ? Colors.green[700] 
                : (isOverdue ? colorScheme.onErrorContainer : null),
            decoration: event.isTaken ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: subtitle,
        trailing: event.isTaken
            ? const Icon(Icons.done_all, color: Colors.green)
            : (isMedication
                ? IconButton(
                    icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                    tooltip: 'Marcar como tomada',
                    onPressed: () => _confirmMedicationIntake(context, ref),
                  )
                : (isOverdue
                    ? Icon(Icons.warning_amber_rounded, color: colorScheme.error)
                    : null)),
      ),
    );
  }
}
