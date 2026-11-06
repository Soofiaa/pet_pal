# Auditoría de seguridad de PetPal

Nivel de calidad: **portafolio** (equivalente a ASVS / MASVS L1, sin certificar cumplimiento).

Esta página registra qué se revisó, qué se corrigió y qué quedó pendiente. No contiene credenciales.

## Estado

| Fase | Tema | Estado | Commit / nota |
|---|---|---|---|
| 1 | `allowBackup="false"` en el manifest Android | Hecho | `55091f0` |
| 2 | Contraseña mínima de 10 caracteres al exportar backup | Hecho | `2895f71` |
| 3 | Keystores fuera de OneDrive | Hecho | Ver sección "Firma de la app" |
| 4 | Sin datos personales en `debugPrint` | Hecho | `78c1406` |
| 5 | Mensajes genéricos al usuario y limpieza de ZIP en caché | Hecho | `2895f71` |
| 6 | Escaneo de secretos (gitleaks) en CI | Hecho | `063e4c2` |
| - | Rotación de contraseñas del keystore | **Pendiente (decisión de la titular)** | Ver "Riesgos aceptados" |

## Hallazgos y correcciones

### 1. `allowBackup` sin declarar (media)
- **Riesgo:** `adb backup` o el respaldo automático de Google podían extraer la base SQLite (historial médico) y `petpal_files/` (fotos, PDFs).
- **Corrección:** `android:allowBackup="false"` en `<application>`.
- **Referencia:** CWE-530; MASVS-STORAGE-2.

### 2. Contraseña del backup sin largo mínimo (media)
- **Riesgo:** el ZIP usa AES, pero una contraseña corta permite fuerza bruta offline sobre datos médicos.
- **Corrección:** mínimo de 10 caracteres (`minBackupPasswordLength` en `lib/utils/backup_password_dialog.dart`), solo al **exportar**. Al importar no se aplica, para no bloquear respaldos antiguos.
- **Referencia:** CWE-521.

### 3. Credenciales de firma expuestas en la carpeta sincronizada (media)
- **Riesgo:** `key.properties` y los keystores estaban dentro de `OneDrive\Documentos\...`, y OneDrive los sincronizaba.
- **Corrección:** los keystores se movieron a `C:\Claves\PetPal\` (fuera de OneDrive y del repo). `key.properties` vive en `AndroidStudioProjects\pet_pal\android\`, también fuera del repo. Git ya los ignoraba (`android/.gitignore`), y no hay rastro de ellos en el historial.
- **Referencia:** CWE-312, CWE-798.

### 4. Datos personales en logs (baja)
- **Corrección:** los `debugPrint` de `database_helper.dart` registran IDs en lugar de nombres, títulos, nombres de vacuna o producto. `orphan_cleanup_service.dart` ya no imprime el valor crudo de `photoPaths`.
- **Referencia:** CWE-532; MASVS-PRIVACY.

### 5. Detalle técnico en mensajes al usuario (baja)
- **Corrección:** `data_backup_service.dart` muestra mensajes genéricos. El detalle va a `debugPrint`.
- **Extra:** antes de crear un ZIP nuevo se borran los `pet_pal_backup_*.zip` de exportaciones anteriores en caché.
- **Referencia:** CWE-209.

### 6. Sin escaneo de secretos en CI (baja)
- **Corrección:** paso `gitleaks/gitleaks-action@v2` con `fetch-depth: 0`, para revisar todo el historial.
- **Pendiente:** no se ejecutó en un runner real todavía. Si el primer CI falla por la acción, revisar su configuración.

## Firma de la app

Huellas SHA-256 (públicas, sirven para identificar la clave):

| Keystore | Alias | SHA-256 (inicio) | Uso |
|---|---|---|---|
| `C:\Claves\PetPal\archivo\petpal-release.jks` | `petpal` | `ba2b856d…` | **Activa.** Firma la app instalada en el teléfono y el build de release. |
| `C:\Claves\PetPal\archivo\upload-keystore.jks` | `upload` | `0A:93:40:9F…` | Histórica. Ya no firma nada. Conservar. |
| `C:\Claves\PetPal\petpal-upload.jks` | `upload` | `fc416403…` | Creada por error al cambiar `key.properties`. No firma nada. Se puede borrar. |

Verificación realizada:
- La app instalada en el teléfono tiene firma `ba2b856d…`.
- `flutter build apk --release` con la configuración nueva produce un APK firmado con `ba2b856d…`.
- La actualización (`adb install -r`) se instaló correctamente y conservó los datos.

**Regla:** no borrar `archivo\`. Esa clave es la única que permite actualizar la app instalada.

## Riesgos aceptados

- **Contraseñas del keystore sin rotar.** Aparecieron en la salida de herramientas durante la sesión del 2026-11-05. La titular decidió no rotarlas. Si cambia de opinión, basta con cambiar las contraseñas del almacén y de la clave en `key.properties` (la clave de firma no cambia). Antes de rotar, verificar que el build siga firmando con `ba2b856d…`.

## Pendiente de la auditoría

Revisado en esta fase:
- Manifest Android, `build.gradle.kts`, widget de Android.
- Servicios de backup, biometría, limpieza de archivos huérfanos, notificaciones.
- Capa de base de datos (consultas parametrizadas, claves foráneas).

Sin revisar todavía:
- Pantallas que cargan URLs externas (`add_edit_appointment_screen.dart`, `emergency_contacts_screen.dart`).
- Permisos de archivos en el widget (`home_screen_widget.dart` lee datos guardados por `widget_update_service.dart`).
- Dependencias: no se ejecutó `flutter pub outdated` ni una herramienta de vulnerabilidades.
- Escaneo real con `gitleaks` local.

## Cómo verificar

```bash
flutter analyze
flutter test
```

Para el build de release, `key.properties` tiene que estar en `android/` (no está en el repo). Copiarlo temporalmente y borrarlo después.
