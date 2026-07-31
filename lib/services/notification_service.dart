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

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // Recomendado para Android 13+ (no rompe en versiones anteriores)
    await androidPlugin?.requestNotificationsPermission();

    // Requerido en Android 12+ para poder usar AndroidScheduleMode.exactAllowWhileIdle.
    // Sin este permiso, las alarmas exactas no se agendan (sin error visible).
    await androidPlugin?.requestExactAlarmsPermission();
  }

  /// Indica si la app puede programar alarmas exactas en este momento.
  /// Útil para decidir el AndroidScheduleMode y para la UI de estado de permisos.
  Future<bool> canScheduleExactAlarms() async {
    final bool? result = await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.canScheduleExactNotifications();
    return result ?? false;
  }

  /// Indica si las notificaciones básicas están habilitadas para la app.
  Future<bool> areNotificationsEnabled() async {
    final bool? result = await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.areNotificationsEnabled();
    return result ?? false;
  }

  /// Vuelve a pedir el permiso de alarmas exactas (abre el flujo del sistema
  /// correspondiente). Devuelve si quedó concedido.
  Future<bool> requestExactAlarmsPermission() async {
    final bool? result = await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
    return result ?? false;
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

  NotificationDetails _notificationDetails({
    String channelId = 'medication_reminders',
    String channelName = 'Recordatorios de Medicación',
    String channelDescription =
        'Canal para notificaciones de recordatorios de medicación de mascotas.',
  }) {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
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

    return NotificationDetails(
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

    final bool canScheduleExact = await canScheduleExactAlarms();

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDateTime, tz.local),
      _notificationDetails(),
      androidScheduleMode: canScheduleExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
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

    final bool canScheduleExact = await canScheduleExactAlarms();
    final AndroidScheduleMode scheduleMode = canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

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
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: null, // one-shot
        payload: payload,
      );
    }
  }

  /// Notificación que se repite todos los días a la misma hora (usa
  /// [DateTimeComponents.time], así que Android/el plugin se encargan de
  /// reprogramarla automáticamente cada día; no hace falta pre-programar
  /// día por día). Pensada para tratamientos sin fecha de fin.
  /// [firstOccurrence] debe ser la primera vez futura en la que debe sonar;
  /// a partir de ahí se repite indefinidamente hasta que se cancele con [id].
  Future<void> scheduleDailyRepeatingNotification({
    required int id,
    required String title,
    required String body,
    required DateTime firstOccurrence,
    String? payload,
  }) async {
    final bool canScheduleExact = await canScheduleExactAlarms();

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(firstOccurrence, tz.local),
      _notificationDetails(),
      androidScheduleMode: canScheduleExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
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

  /// Notificación inmediata (sin `zonedSchedule`), para alertas puntuales
  /// que no son un recordatorio programado a futuro -ej. un signo vital
  /// fuera de rango normal al momento de registrarlo-. Usa un canal propio
  /// (no 'medication_reminders') para que el usuario pueda silenciar estas
  /// alertas por separado de los recordatorios de medicación.
  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      _notificationDetails(
        channelId: 'vital_sign_alerts',
        channelName: 'Alertas de Signos Vitales',
        channelDescription:
            'Canal para alertas de valores de signos vitales fuera de rango normal.',
      ),
      payload: payload,
    );
  }

  void dispose() {
    onNotifications.close();
  }
}
