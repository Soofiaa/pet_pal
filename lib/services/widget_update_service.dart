import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

class WidgetUpdateService {
  static const String _widgetId = '_petPalWidget';

  /// Actualiza los datos del widget de home screen con los recordatorios del día
  static Future<void> updateWidget(List<Map<String, dynamic>> reminders) async {
    final data = {
      'reminders': reminders,
      'lastUpdated': DateTime.now().toIso8601String(),
    };

    await HomeWidget.saveWidgetData<String>(
      _widgetId,
      jsonEncode(data),
    );

    // Forzar actualización del widget
    await HomeWidget.updateWidget(
      name: 'PetPalWidgetProvider',
      androidName: 'PetPalWidgetProvider',
      qualifiedAndroidName: 'com.Sofia_Menzel.PetPal.pet_pal.PetPalWidgetProvider',
    );
  }

  /// Formatea los recordatorios para el widget
  static List<Map<String, dynamic>> formatRemindersForWidget(
    List<Map<String, dynamic>> events,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final todayEvents = events.where((event) {
      final eventDate = DateTime.parse(event['date'] as String);
      final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
      return eventDay.isAtSameMomentAs(today) || eventDay.isAtSameMomentAs(tomorrow);
    }).toList();

    return todayEvents.map((event) {
      final eventDate = DateTime.parse(event['date'] as String);
      final isToday = DateTime(eventDate.year, eventDate.month, eventDate.day)
          .isAtSameMomentAs(today);
      
      return {
        'petName': event['petName'] as String,
        'type': event['type'] as String,
        'time': isToday
            ? DateFormat('HH:mm').format(eventDate)
            : 'Mañana',
        'isUrgent': event['isUrgent'] as bool? ?? false,
      };
    }).toList();
  }
}
