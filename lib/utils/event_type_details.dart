import 'package:flutter/material.dart';

/// Ícono y color por `type` de evento de `DatabaseHelper.getAllEventsForPet`,
/// compartido entre CalendarScreen y el dashboard "Hoy" (TodayDashboardSection)
/// para que ambos muestren la misma combinación por tipo de evento.
final Map<String, Map<String, dynamic>> eventTypeDetails = {
  'note': {'icon': Icons.description, 'color': Colors.blue},
  'appointment': {'icon': Icons.calendar_today, 'color': Colors.orange},
  'vaccination': {'icon': Icons.local_hospital, 'color': Colors.green},
  'next_vaccination': {'icon': Icons.event_repeat, 'color': Colors.green[300]},
  'medication': {'icon': Icons.medical_services, 'color': Colors.purple},
  'medication_end': {'icon': Icons.check_circle, 'color': Colors.purple[300]},
  'deworming': {'icon': Icons.bug_report, 'color': Colors.red},
  'next_deworming': {'icon': Icons.next_plan, 'color': Colors.red[300]},
  'weight': {'icon': Icons.scale, 'color': Colors.teal},
  'document': {'icon': Icons.folder_shared, 'color': Colors.brown},
  'food_allergy': {'icon': Icons.no_food, 'color': Colors.deepOrange},
  'food_record': {'icon': Icons.restaurant, 'color': Colors.lightGreen},
  'food_record_end': {'icon': Icons.restaurant, 'color': Colors.lightGreen[300]},
};

IconData eventIconFor(String type) {
  return eventTypeDetails[type.toLowerCase()]?['icon'] as IconData? ??
      Icons.help_outline;
}

Color eventColorFor(String type) {
  return eventTypeDetails[type.toLowerCase()]?['color'] as Color? ??
      Colors.grey;
}
