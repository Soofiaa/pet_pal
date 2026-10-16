import 'package:flutter/material.dart';
import 'package:pet_pal/theme/category_colors.dart';

/// Ícono y color por `type` de evento de `DatabaseHelper.getAllEventsForPet`,
/// compartido entre CalendarScreen y el dashboard "Hoy" (TodayDashboardSection)
/// para que ambos muestren la misma combinación por tipo de evento. El color
/// es el de la categoría (salud / registro / agenda); el ícono distingue el tipo.
final Map<String, Map<String, dynamic>> eventTypeDetails = {
  'note': {'icon': Icons.description, 'color': CategoryColors.records},
  'appointment': {'icon': Icons.calendar_today, 'color': CategoryColors.agenda},
  'vaccination': {'icon': Icons.local_hospital, 'color': CategoryColors.health},
  'next_vaccination': {'icon': Icons.event_repeat, 'color': CategoryColors.health},
  'medication': {'icon': Icons.medical_services, 'color': CategoryColors.health},
  'medication_end': {'icon': Icons.check_circle, 'color': CategoryColors.health},
  'deworming': {'icon': Icons.bug_report, 'color': CategoryColors.health},
  'next_deworming': {'icon': Icons.next_plan, 'color': CategoryColors.health},
  'weight': {'icon': Icons.scale, 'color': CategoryColors.records},
  'vital_sign': {'icon': Icons.monitor_heart, 'color': CategoryColors.health},
  'document': {'icon': Icons.folder_shared, 'color': CategoryColors.records},
  'food_allergy': {'icon': Icons.no_food, 'color': CategoryColors.health},
  'food_record': {'icon': Icons.restaurant, 'color': CategoryColors.records},
  'food_record_end': {'icon': Icons.restaurant, 'color': CategoryColors.records},
};

/// Eventos que representan una dosis pendiente: si su fecha ya pasó no están
/// "cumplidos", están vencidos.
bool isOverdueEventType(String type) =>
    type == 'next_vaccination' || type == 'next_deworming';

IconData eventIconFor(String type) {
  return eventTypeDetails[type.toLowerCase()]?['icon'] as IconData? ??
      Icons.help_outline;
}

Color eventColorFor(String type) {
  return eventTypeDetails[type.toLowerCase()]?['color'] as Color? ??
      Colors.grey;
}
