import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/providers/dashboard_providers.dart';
import 'package:pet_pal/providers/pets_providers.dart';
import 'package:pet_pal/widgets/empty_state.dart';
import 'package:pet_pal/widgets/today_dashboard_section.dart';

/// Vista completa de los eventos accionables de "Hoy", sin el recorte a
/// [TodayDashboardSection._maxVisibleEvents]. Se llega acá desde el "y N
/// más..." de esa sección.
class TodayEventsScreen extends ConsumerWidget {
  const TodayEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(todayDashboardProvider);
    final petsAsync = ref.watch(petsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Eventos de hoy')),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('No se pudo cargar el resumen de hoy: $error'),
        ),
        data: (events) {
          if (events.isEmpty) {
            return const EmptyState(
              icon: Icons.event_available,
              message: 'No hay eventos pendientes para hoy.',
            );
          }

          final petsCount = petsAsync.value?.length ?? 0;
          final showPetName = petsCount > 1;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: events.length,
            itemBuilder: (context, index) =>
                DashboardEventTile(
                  event: events[index],
                  showPetName: showPetName,
                ),
          );
        },
      ),
    );
  }
}
