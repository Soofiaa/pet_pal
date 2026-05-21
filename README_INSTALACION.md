# Mejoras PetPal 1 al 9

Incluye:

1. Backup completo ZIP con datos + imágenes.
2. Pantalla para ver imágenes en pantalla completa con zoom.
3. Eliminación de imágenes asociadas al borrar notas/vacunas.
4. Confirmación antes de restaurar backup.
5. Placeholder seguro si una imagen no existe.
6. Organización en `petpal_files/pets`, `petpal_files/notes`, `petpal_files/vaccinations`, `petpal_files/restored`.
7. Pantalla de Ajustes/Respaldo.
8. Validación del backup antes de importar.
9. Tarjetas visuales mejoradas para vacunas.
10. Backup en nube: dejado como pendiente en `PENDIENTE_BACKUP_NUBE.md`.

## Dependencias necesarias en pubspec.yaml

```yaml
archive: ^3.6.1
file_picker: ^8.1.7
share_plus: ^10.1.4
path_provider: ^2.1.5
path: ^1.9.0
```

Luego ejecutar:

```bash
flutter pub get
```

## Ubicación sugerida de archivos

- `lib/services/image_storage_service.dart`
- `lib/services/data_backup_service.dart`
- `lib/screens/image_preview_screen/image_preview_screen.dart`
- `lib/screens/backup_settings_screen/backup_settings_screen.dart`
- Reemplazar tus pantallas de notas, vacunas y detalle de mascota por las versiones incluidas.

## Para abrir la pantalla de respaldo desde tu menú de ajustes

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const BackupSettingsScreen(),
  ),
);
```

Import:

```dart
import 'package:pet_pal/screens/backup_settings_screen/backup_settings_screen.dart';
```
