# PetPal — Aplicación Móvil de Gestión de Mascotas

Aplicación móvil multiplataforma desarrollada en Flutter para centralizar
el cuidado y seguimiento de mascotas: historial médico, recordatorios,
documentos clínicos y estado de salud, todo organizado por mascota.

## Características

- Registro y gestión de múltiples mascotas, con foto de perfil (recorte
  integrado en la app) y cálculo automático de edad exacta (años, meses
  y días)
- **Dashboard "Hoy"**: resumen de citas, próximas dosis y tratamientos
  activos de todas las mascotas, ordenado por urgencia
- **Historial médico completo**: vacunas, medicación, desparasitación,
  peso y signos vitales (temperatura), cada uno con su propia pantalla,
  gráfico de tendencia y su lugar en el calendario unificado de la
  mascota. Los signos vitales alertan cuando un valor sale del rango
  normal
- **Documentos clínicos**: exámenes, informes de cirugía, radiografías y
  recetas, organizados por categoría, con visualización diferenciada
  (imágenes en vista ampliada, PDFs abiertos con la app nativa del
  sistema)
- Registro de alergias alimentarias, integrado al calendario
- **Recordatorios confiables**: notificaciones para medicación (con
  horarios múltiples configurables por el usuario), vacunas y
  desparasitación, que sobreviven a un reinicio del dispositivo y a la
  restauración de un backup
- **Ficha clínica exportable en PDF**, consolidando vacunas, medicación,
  desparasitación, peso y el índice de documentos — pensada para llevar
  directamente a una consulta veterinaria
- **Exportación de historial** (peso, vacunas, medicación) a CSV
- Diario de comportamiento y notas por mascota, con fotos y exportación
  a PDF
- **Backup y restauración completa cifrada**: todos los datos de la app
  (incluyendo imágenes y documentos adjuntos) en un solo archivo ZIP
  protegido con contraseña
- Modo oscuro (sigue la preferencia del sistema)
- Acceso a galería y cámara con manejo de permisos Android/iOS modernos
- Persistencia local con integridad referencial real (`PRAGMA
  foreign_keys` activa, borrado en cascada verificado por tests)

## Stack tecnológico

- **Flutter / Dart** — desarrollo multiplataforma (Android / iOS)
- **Riverpod** — manejo de estado, con una capa de repository entre las
  pantallas y el acceso a datos (ver *Arquitectura* abajo)
- **sqflite** — persistencia local con integridad referencial real
- **flutter_local_notifications** — recordatorios y alertas locales, con
  manejo explícito de permisos de alarma exacta (Android 12+) y
  recuperación tras reinicio del dispositivo
- **fl_chart** — gráficos de tendencia (peso, signos vitales)
- **archive** — copia de seguridad ZIP con cifrado AES por contraseña
- **csv** — exportación de historiales
- **pdf / open_filex / share_plus** — generación, visualización y
  exportación de documentos
- **image_picker / pro_image_editor / file_picker** — captura, recorte y
  selección de archivos e imágenes
- **Gradle / Kotlin** — compatibilidad con versiones recientes de Android

## Arquitectura

El proyecto está migrando de forma incremental hacia una arquitectura en
capas: **pantalla → provider (Riverpod) → repository → base de datos**,
feature por feature, sin tocar todo el proyecto de una vez. Cada
repository es acceso a datos puro; la orquestación de efectos
secundarios (programar/cancelar recordatorios, evaluar alertas de rango
anormal, limpiar archivos obsoletos) vive en el provider correspondiente,
que es la única puerta de escritura real para esa feature.

Features ya migradas: mascotas, registro de peso, desparasitación,
vacunas, medicación y signos vitales. El resto del proyecto sigue un
patrón más simple (acceso directo a la base de datos desde la pantalla)
mientras se completa la migración.

## Estado del proyecto

En desarrollo activo. Funcionalidades implementadas y estables: perfiles,
dashboard, vacunas, desparasitación, medicación, peso, signos vitales,
alergias, documentos, calendario, notas, notificaciones, exportación a
CSV, backup/restore cifrado, modo oscuro y persistencia local.

Próximas funcionalidades planificadas:
- Localización a inglés
- Recordatorios recurrentes flexibles (ej. "cada 3 meses")
- Backup opcional en la nube
- Toggle manual de modo oscuro (hoy sigue la preferencia del sistema)

## Testing y CI

El proyecto cuenta con una suite de pruebas automatizadas centrada en los
puntos donde un bug puede fallar en silencio, sin lanzar ningún error
visible:

- Integridad referencial y borrado en cascada, verificados contra
  SQLite real (no simulado) en las 9 tablas de la base de datos
- Programación y cancelación de recordatorios, incluyendo ausencia de
  colisión de IDs entre mascotas, horarios y rangos de fechas largos
- Orquestación correcta entre cada provider y sus efectos secundarios
  (recordatorios, alertas de signos vitales, limpieza de archivos)
- Primeros widget tests del repo (dashboard "Hoy")

Cada push corre automáticamente `flutter analyze` y `flutter test` vía
GitHub Actions (`.github/workflows/ci.yml`).

## Instalación

1. Clona el repositorio:
```bash
git clone https://github.com/Soofiaa/pet_pal.git
cd pet_pal
```

2. Instala las dependencias:
```bash
flutter pub get
```

3. Ejecuta la aplicación:
```bash
flutter run
```

Requiere Flutter 3.38+ y un dispositivo o emulador Android (compatibilidad
con iOS en desarrollo).

Para correr la suite de pruebas localmente:
```bash
flutter analyze
flutter test
```

## Autor

Sofía Menzel — [GitHub](https://github.com/Soofiaa) ·
[LinkedIn](https://linkedin.com/in/sofia-menzel-madrid)
