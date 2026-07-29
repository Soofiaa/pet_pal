# PetPal — Aplicación Móvil de Gestión de Mascotas

Aplicación móvil multiplataforma desarrollada en Flutter para centralizar
el cuidado y seguimiento de mascotas: historial médico, recordatorios,
documentos clínicos y estado de salud, todo organizado por mascota.

## Características

- Registro y gestión de múltiples mascotas, con foto de perfil y cálculo
  automático de edad exacta (años, meses y días)
- **Historial médico completo**: vacunas, medicación, desparasitación y
  registro de peso, cada uno con su propia pantalla y su lugar en el
  calendario unificado de la mascota
- **Documentos clínicos**: exámenes, informes de cirugía, radiografías y
  recetas, organizados por categoría, con visualización diferenciada
  (imágenes en vista ampliada, PDFs abiertos con la app nativa del
  sistema)
- **Recordatorios confiables**: notificaciones para medicación (con
  horarios múltiples configurables por el usuario), vacunas y
  desparasitación, que sobreviven a un reinicio del dispositivo y a la
  restauración de un backup
- **Gráfico de tendencia de peso**, para seguir la evolución de la
  mascota en el tiempo
- **Ficha clínica exportable en PDF**, consolidando vacunas, medicación,
  desparasitación, peso y el índice de documentos — pensada para llevar
  directamente a una consulta veterinaria
- Backup y restauración completa de los datos de la app (incluyendo
  archivos adjuntos) en un solo archivo
- Diario de comportamiento y notas por mascota, con fotos y exportación
  a PDF

## Stack tecnológico

- **Flutter / Dart** — desarrollo multiplataforma (Android / iOS)
- **Riverpod** — manejo de estado, con una capa de repository entre las
  pantallas y el acceso a datos (ver *Arquitectura* abajo)
- **sqflite** — persistencia local con integridad referencial real
  (`PRAGMA foreign_keys` activa, borrado en cascada verificado por tests)
- **flutter_local_notifications** — recordatorios locales, con manejo
  explícito de permisos de alarma exacta (Android 12+) y recuperación
  tras reinicio del dispositivo
- **fl_chart** — visualización de tendencias de peso
- **pdf / open_filex / share_plus** — generación, visualización y
  exportación de documentos
- **image_picker / file_picker** — captura y selección de archivos e
  imágenes

## Arquitectura

El proyecto está migrando de forma incremental hacia una arquitectura en
capas: **pantalla → provider (Riverpod) → repository → base de datos**,
feature por feature, sin tocar todo el proyecto de una vez. Cada
repository es acceso a datos puro; la orquestación de efectos
secundarios (programar/cancelar recordatorios, limpiar archivos
obsoletos) vive en el provider correspondiente, que es la única puerta
de escritura real para esa feature.

Features ya migradas: registro de peso, desparasitación, vacunas y
medicación. El resto del proyecto sigue un patrón más simple (acceso
directo a la base de datos desde la pantalla) mientras se completa la
migración.

## Testing y CI

El proyecto cuenta con una suite de pruebas unitarias centrada en los
puntos donde un bug puede fallar en silencio, sin lanzar ningún error
visible:

- Integridad referencial y borrado en cascada, verificados contra
  SQLite real (no simulado) en las 8 tablas de la base de datos
- Programación y cancelación de recordatorios, incluyendo ausencia de
  colisión de IDs entre mascotas, horarios y rangos de fechas largos
- Orquestación correcta entre cada provider y sus efectos secundarios
  (recordatorios, limpieza de archivos)

Cada push corre automáticamente `flutter analyze` y `flutter test` vía
GitHub Actions.

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
flutter test
```

## Autor

Sofía Menzel — [GitHub](https://github.com/Soofiaa) ·
[LinkedIn](https://linkedin.com/in/sofia-menzel-madrid)
