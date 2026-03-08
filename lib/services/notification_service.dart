// notification_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:rxdart/subjects.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  final BehaviorSubject<String?> onNotifications = BehaviorSubject<String?>();

  Future<void> init() async {
    await _configureLocalTimeZone();

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
      onDidReceiveBackgroundNotificationResponse,
    );

    // Recomendado para Android 13+ (no rompe en versiones anteriores)
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('Error al configurar la zona horaria: $e');
      tz.setLocalLocation(tz.getLocation('Etc/UTC'));
    }
  }

  void onDidReceiveNotificationResponse(
      NotificationResponse notificationResponse) async {
    final String? payload = notificationResponse.payload;
    if (payload != null) {
      debugPrint('Payload de notificación: $payload');
      onNotifications.add(payload);
    }
  }

  @pragma('vm:entry-point')
  static void onDidReceiveBackgroundNotificationResponse(
      NotificationResponse notificationResponse) async {
    final String? payload = notificationResponse.payload;
    if (payload != null) {
      debugPrint('Payload de notificación en segundo plano: $payload');
    }
  }

  NotificationDetails _notificationDetails() {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'medication_reminders',
      'Recordatorios de Medicación',
      channelDescription:
      'Canal para notificaciones de recordatorios de medicación de mascotas.',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const DarwinNotificationDetails iosPlatformChannelSpecifics =
    DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return const NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosPlatformChannelSpecifics,
    );
  }

  /// Notificación "one-shot" (una sola vez).
  Future<void> scheduleNotificationOnce({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    String? payload,
  }) async {
    // Evita agendar en el pasado
    if (scheduledDateTime.isBefore(DateTime.now())) return;

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDateTime, tz.local),
      _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: null,
      payload: payload,
    );
  }

  /// Medicación por varios días (misma hora cada día).
  /// Genera 1 notificación por día para tener control total del rango.
  Future<void> scheduleMedicationForDays({
    required int baseId, // ej: id del medicamento
    required String title,
    required String body,
    required DateTime firstDoseDateTime, // fecha + hora de la primera dosis
    required int days, // ej: 7
    String? payload,
  }) async {
    if (days <= 0) return;

    for (int i = 0; i < days; i++) {
      final DateTime doseDateTime = firstDoseDateTime.add(Duration(days: i));
      if (doseDateTime.isBefore(DateTime.now())) continue;

      // ID único por cada día del tratamiento
      final int id = baseId * 1000 + i;

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(doseDateTime, tz.local),
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: null, // one-shot
        payload: payload,
      );
    }
  }

  /// Cancela una notificación (por id exacto).
  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  /// Cancela todas las notificaciones de un tratamiento creado con scheduleMedicationForDays.
  Future<void> cancelMedicationForDays({
    required int baseId,
    required int days,
  }) async {
    for (int i = 0; i < days; i++) {
      final int id = baseId * 1000 + i;
      await _flutterLocalNotificationsPlugin.cancel(id);
    }
  }

  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  void dispose() {
    onNotifications.close();
  }
}
