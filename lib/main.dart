import 'package:flutter/material.dart';
import 'package:pet_pal/screens/home_screen/home_screen.dart'; // Asegúrate de que esta sea tu pantalla principal
import 'package:pet_pal/services/notification_service.dart'; // Importar el servicio de notificaciones
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Necesario para el tipo NotificationResponse
import 'package:intl/date_symbol_data_local.dart'; // Importación necesaria

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// Una GlobalKey para el Navigator para poder navegar desde fuera del widget tree
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Asegura que los widgets de Flutter estén inicializados
  await NotificationService().init(); // Inicializa el servicio de notificaciones

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

  runApp(const PetPalApp());
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

class PetPalApp extends StatefulWidget {
  const PetPalApp({super.key});

  @override
  State<PetPalApp> createState() => _PetPalAppState();
}

class _PetPalAppState extends State<PetPalApp> {
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
      theme: ThemeData(
        primarySwatch: Colors.blueGrey, // Puedes ajustar esto a tu gusto
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF86B6F6), // Azul cielo claro
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 4,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF86B6F6), // Usa el mismo color principal
          foregroundColor: Colors.white,
        ),
        cardTheme: CardTheme.of(context).copyWith(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF86B6F6), // Color principal para botones elevados
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF86B6F6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF5278D9), width: 2), // Un poco más oscuro para enfocar
          ),
          labelStyle: const TextStyle(color: Color(0xFF5278D9)),
          floatingLabelStyle: const TextStyle(color: Color(0xFF5278D9)),
        ),
        // Puedes añadir más personalizaciones aquí
      ),
      home: const HomeScreen(), // Tu pantalla principal
    );
  }
}