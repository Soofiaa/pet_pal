import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pet_pal/models/dashboard_event.dart';
import 'package:pet_pal/providers/dashboard_providers.dart';
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
                (event) => _DashboardEventTile(event: event),
              ),
              if (remaining > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                  child: Text(
                    'y $remaining más...',
                    style: TextStyle(color: Colors.grey[600]),
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

class _DashboardEventTile extends StatelessWidget {
  const _DashboardEventTile({required this.event});

  final DashboardEvent event;

  @override
  Widget build(BuildContext context) {
    final isOverdue = event.urgency == DashboardUrgency.overdue;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      color: isOverdue ? Colors.red[50] : null,
      child: ListTile(
        leading: Icon(eventIconFor(event.type), color: eventColorFor(event.type)),
        title: Text(event.title),
        subtitle: Text(
          '${event.petName} · ${DateFormat('dd/MM/yyyy').format(event.date)}',
        ),
        trailing: isOverdue
            ? const Icon(Icons.warning_amber_rounded, color: Colors.red)
            : null,
      ),
    );
  }
}
