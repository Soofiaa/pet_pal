import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/screens/home_screen/home_screen.dart'; // Asegúrate de que esta sea tu pantalla principal
import 'package:pet_pal/services/notification_service.dart'; // Importar el servicio de notificaciones
import 'package:pet_pal/theme/app_theme.dart';
import 'package:pet_pal/services/reminder_scheduler.dart';
import 'package:pet_pal/services/orphan_cleanup_service.dart';
import 'package:pet_pal/providers/theme_mode_provider.dart';
import 'package:pet_pal/data/database_helper.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Necesario para el tipo NotificationResponse
import 'package:intl/date_symbol_data_local.dart'; // Importación necesaria
import 'package:shared_preferences/shared_preferences.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// Una GlobalKey para el Navigator para poder navegar desde fuera del widget tree
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Asegura que los widgets de Flutter estén inicializados
  await NotificationService().init(); // Inicializa el servicio de notificaciones

  // Abre la conexión a la base de datos una sola vez y de forma explícita
  // ANTES de lanzar las dos tareas de abajo. DatabaseHelper.database es un
  // getter de inicialización perezosa no atómico (chequea _database == null
  // y recién después lo asigna, con un await en el medio); si
  // ReminderScheduler y OrphanCleanupService llamaran a ese getter al mismo
  // tiempo sin esto, ambos podrían ver _database == null y disparar
  // _initDatabase() (y por lo tanto _onUpgrade) por duplicado. No es un
  // problema introducido por esta tarea, pero como ya estamos tocando este
  // arranque, lo cerramos de una vez.
  await DatabaseHelper().database;

  // Red de seguridad adicional al receiver nativo de reinicio: si el usuario
  // reabre la app después de un reinicio del dispositivo (o de una
  // reinstalación/actualización), esto reprograma cualquier recordatorio
  // pendiente. Es idempotente: usa los mismos ids que ya se usan hoy, así
  // que no genera notificaciones duplicadas.
  // Migración única: los ids de los recordatorios pasaron de String.hashCode
  // a un hash estable (utils/stable_hash.dart). Los ids ya programados en
  // el dispositivo ya no coinciden con los nuevos, así que se cancelan todos
  // una sola vez y rescheduleAllPending los vuelve a programar con los ids
  // correctos. Sin esto, tras actualizar podrían sonar dos veces (el viejo y
  // el nuevo). Si algo falla, no debe impedir que la app abra.
  try {
    final prefs = await SharedPreferences.getInstance();
    // v2: medicación pasó de baseId*1000+día a hash de la clave completa, y
    // desparasitación pasó a ciclos múltiples (_next_N). Se cancela todo una
    // vez y rescheduleAllPending reprograma con los ids nuevos.
    if (prefs.getBool('reminder_ids_stable_v2') != true) {
      await NotificationService().cancelAllNotifications();
      await prefs.setBool('reminder_ids_stable_v2', true);
    }
  } catch (e) {
    debugPrint('No se pudo migrar los ids de recordatorios: $e');
  }

  unawaited(ReminderScheduler.rescheduleAllPending());

  // Limpieza única de datos heredados de antes de activar PRAGMA
  // foreign_keys: filas huérfanas (vía migración v17) y sus archivos
  // asociados en petpal_files/. Solo hace algo la primera vez que se abre
  // la app tras esta actualización; en cualquier otro lanzamiento es un
  // no-op inmediato. Nunca debe bloquear ni impedir que la app abra.
  unawaited(OrphanCleanupService.runOnce());

  // Inicializa los datos de formato de fecha para el idioma español (o el que necesites)
  await initializeDateFormatting('es_ES', null);

  // Manejar notificaciones cuando la aplicación se abre por primera vez desde una notificación
  final NotificationAppLaunchDetails? notificationAppLaunchDetails =
  await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

  if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
    // Si la app se lanzó debido a una notificación, manejamos el payload
    final String? payload = notificationAppLaunchDetails!.notificationResponse?.payload;
    if (payload != null) {
      // Usar un pequeño retardo para asegurar que la UI esté lista
      Future.delayed(const Duration(milliseconds: 100), () {
        handleNotificationPayload(payload);
      });
    }
  }

  // ProviderScope solo envuelve el árbol de widgets: no afecta ni reordena
  // nada de la secuencia de arranque de arriba (apertura de la DB,
  // notificaciones, reprogramación de recordatorios, limpieza de
  // huérfanos), que sigue corriendo exactamente igual antes de este punto.
  runApp(const ProviderScope(child: PetPalApp()));
}

// Función para manejar el payload de la notificación y navegar
void handleNotificationPayload(String payload) async {
  // En este caso, simplemente volvemos a la pantalla principal,
  // ya que no tenemos una pantalla específica para recordatorios.
  debugPrint('Manejando payload de notificación: $payload');
  navigatorKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
  );
}

class PetPalApp extends ConsumerStatefulWidget {
  const PetPalApp({super.key});

  @override
  ConsumerState<PetPalApp> createState() => _PetPalAppState();
}

class _PetPalAppState extends ConsumerState<PetPalApp> {
  @override
  void initState() {
    super.initState();
    // Escuchar el stream de notificaciones cuando la app ya está abierta
    NotificationService().onNotifications.listen((payload) {
      if (payload != null) {
        handleNotificationPayload(payload);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Asigna la GlobalKey al Navigator
      title: 'PetPal',
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      home: const HomeScreen(), // Tu pantalla principal
    );
  }
}