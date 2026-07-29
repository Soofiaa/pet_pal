import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/data/database_helper.dart';

/// Punto único de acceso al singleton de DatabaseHelper vía Riverpod.
/// Sigue siendo el mismo singleton de siempre (DatabaseHelper._instance,
/// ya abierto explícitamente en main() antes de correr la app); esto solo
/// lo hace inyectable/reemplazable para tests, no crea una conexión nueva.
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper();
});
