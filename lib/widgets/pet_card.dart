import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pet_pal/models/dashboard_event.dart';
import 'package:pet_pal/models/pet.dart';

/// Tarjeta de una mascota para la pantalla "Mis Mascotas", en dos columnas:
/// la foto a la izquierda y, a la derecha, nombre, especie, edad y los
/// íconos de pendientes (vacuna, desparasitación, etc.) o "Al día" si no hay
/// ninguno. Sin foto válida usa un fondo de color con el ícono de mascota.
class PetCard extends StatelessWidget {
  const PetCard({super.key, required this.pet, required this.onTap, this.alerts = const []});

  final Pet pet;
  final VoidCallback onTap;
  final List<PetAlert> alerts;

  bool get _hasValidImage {
    final path = pet.imageUrl;
    if (path == null || path.trim().isEmpty) return false;
    return File(path).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final subtitle = '${pet.species} · ${pet.detailedAge}';
    final alertsLabel = alerts.isEmpty ? '' : '. ${alerts.map((a) => a.label).join(', ')}';

    return Semantics(
      button: true,
      label: '${pet.name}, $subtitle$alertsLabel',
      excludeSemantics: true,
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 2,
                child: _hasValidImage
                    ? Image.file(
                        File(pet.imageUrl!),
                        fit: BoxFit.cover,
                        cacheWidth: 600,
                        errorBuilder: (_, _, _) => _Placeholder(colorScheme: colorScheme),
                      )
                    : _Placeholder(colorScheme: colorScheme),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        pet.species,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      Text(
                        pet.detailedAge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      const Spacer(),
                      if (alerts.isEmpty)
                        Row(
                          children: [
                            Icon(Icons.check_circle, size: 18, color: colorScheme.primary),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Al día',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodyMedium?.copyWith(color: colorScheme.primary),
                              ),
                            ),
                          ],
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [for (final alert in alerts) _AlertBadge(alert: alert)],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
/// Pendiente de una mascota que se muestra como ícono sobre su tarjeta.
class PetAlert {
  const PetAlert({required this.type, required this.urgency});

  final String type;
  final DashboardUrgency urgency;

  bool get isOverdue => urgency == DashboardUrgency.overdue;

  IconData get icon {
    switch (type) {
      case 'next_vaccination':
        return Icons.vaccines;
      case 'next_deworming':
        return Icons.bug_report;
      case 'appointment':
        return Icons.event;
      case 'medication_end':
        return Icons.medication;
      default:
        return Icons.notifications_active;
    }
  }

  String get label {
    final what = switch (type) {
      'next_vaccination' => 'Vacuna',
      'next_deworming' => 'Desparasitación',
      'appointment' => 'Cita',
      'medication_end' => 'Fin de medicación',
      _ => 'Pendiente',
    };
    final when = switch (urgency) {
      DashboardUrgency.overdue => 'vencida',
      DashboardUrgency.today => 'hoy',
      _ => 'próxima',
    };
    return '$what $when';
  }
}

/// Un ícono por tipo de pendiente que requiere atención pronto (vencido,
/// hoy o en los próximos 7 días); conserva el más urgente de cada tipo y
/// ordena primero los vencidos.
List<PetAlert> petAlertsFor(Iterable<DashboardEvent> events) {
  final byType = <String, PetAlert>{};
  for (final event in events) {
    if (event.urgency == DashboardUrgency.later) continue;
    final current = byType[event.type];
    if (current == null || event.urgency.index < current.urgency.index) {
      byType[event.type] = PetAlert(type: event.type, urgency: event.urgency);
    }
  }
  final alerts = byType.values.toList()
    ..sort((a, b) => a.urgency.index.compareTo(b.urgency.index));
  return alerts;
}

class _AlertBadge extends StatelessWidget {
  const _AlertBadge({required this.alert});

  final PetAlert alert;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: alert.label,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: alert.isOverdue ? const Color(0xFFD32F2F) : const Color(0xFFEF8F00),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Icon(alert.icon, size: 18, color: Colors.white),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: colorScheme.primaryContainer,
      child: Center(
        child: Icon(Icons.pets, size: 64, color: colorScheme.onPrimaryContainer.withValues(alpha: 0.6)),
      ),
    );
  }
}
