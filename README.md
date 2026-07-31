# PetPal — Aplicación Móvil de Gestión de Mascotas

Aplicación móvil multiplataforma desarrollada en Flutter para centralizar 
el cuidado y seguimiento de mascotas, con foco en bienestar, 
organización y registro médico.

## Características

- Registro y gestión de múltiples mascotas con perfil individual
- Dashboard "Hoy": resumen de citas, próximas dosis y tratamientos activos de todas las mascotas, ordenado por urgencia
- Foto de perfil con recorte integrado dentro de la app
- Cálculo automático de edad exacta (años, meses y días)
- Historial de vacunas, desparasitaciones y medicación, con recordatorios locales (horarios múltiples, tratamientos con o sin fecha de fin)
- Control de peso y signos vitales (temperatura) con gráfico de evolución y alertas cuando un valor sale del rango normal
- Registro de alergias alimentarias, integrado al calendario
- Calendario unificado de eventos por mascota
- Diario de comportamiento y notas, con documentos médicos adjuntos (exámenes, recetas, cirugías)
- Exportación de historial (peso, vacunas, medicación) a CSV
- Copia de seguridad completa cifrada (ZIP con contraseña) con restauración, incluyendo imágenes y documentos
- Modo oscuro (sigue la preferencia del sistema)
- Acceso a galería y cámara con manejo de permisos Android/iOS modernos
- Persistencia local de datos estructurados por mascota
- Arquitectura repository + Riverpod (en migración incremental) para testabilidad, con suite de tests automatizados y CI

## Stack tecnológico

- **Flutter / Dart** — desarrollo multiplataforma (Android / iOS)
- **sqflite** — persistencia local en SQLite
- **flutter_riverpod** — manejo de estado (módulos migrados: mascotas, peso, vacunas, desparasitación, medicación, signos vitales)
- **flutter_local_notifications** — recordatorios y alertas locales
- **fl_chart** — gráficos de evolución (peso, signos vitales)
- **archive** — copia de seguridad ZIP con cifrado AES por contraseña
- **csv** — exportación de historiales
- **image_picker / pro_image_editor** — gestión y recorte de imágenes
- **Gradle / Kotlin** — compatibilidad con versiones recientes de Android

## Estado del proyecto

En desarrollo activo. Funcionalidades implementadas y estables: perfiles,
dashboard, vacunas, desparasitación, medicación, peso, signos vitales,
alergias, documentos, calendario, notas, notificaciones, exportación a CSV,
backup/restore cifrado, modo oscuro y persistencia local.

Próximas funcionalidades planificadas:
- Localización a inglés
- Recordatorios recurrentes flexibles (ej. "cada 3 meses")
- Backup opcional en la nube
- Toggle manual de modo oscuro (hoy sigue la preferencia del sistema)

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

Requiere Flutter 3.x o superior y un dispositivo o emulador Android.

## Tests

```bash
flutter analyze
flutter test
```

Corre automáticamente en cada push/PR vía GitHub Actions
(`.github/workflows/ci.yml`).

## Autor

Sofía Menzel — [GitHub](https://github.com/Soofiaa) · 
[LinkedIn](https://linkedin.com/in/sofia-menzel-madrid)
