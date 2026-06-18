# PetPal — Aplicación Móvil de Gestión de Mascotas

Aplicación móvil multiplataforma desarrollada en Flutter para centralizar 
el cuidado y seguimiento de mascotas, con foco en bienestar, 
organización y registro médico.

## Características

- Registro y gestión de múltiples mascotas con perfil individual
- Foto de perfil con recorte integrado dentro de la app
- Cálculo automático de edad exacta (años, meses y días)
- Historial de vacunas con nombre, fecha, observaciones e imagen de comprobante
- Diario de comportamiento y notas por mascota
- Acceso a galería y cámara con manejo de permisos Android modernos
- Persistencia local de datos estructurados por mascota
- Arquitectura modular por pantallas y servicios orientada a escalabilidad

## Stack tecnológico

- **Flutter / Dart** — desarrollo multiplataforma (Android / iOS)
- **Almacenamiento local** — persistencia de datos y registros médicos
- **image_picker / image_cropper** — gestión y recorte de imágenes
- **Gradle / Kotlin** — compatibilidad con versiones recientes de Android

## Estado del proyecto

En desarrollo activo. Funcionalidades implementadas y estables:
perfiles, vacunas, diario, imágenes y persistencia local.

Próximas funcionalidades planificadas:
- Notificaciones locales para vacunas y medicamentos
- Historial médico extendido
- Control de peso y alimentación
- Rutinas de cuidado

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

## Estructura del proyecto
pet_pal/
├── lib/
│   ├── screens/     # Pantallas de la app
│   ├── services/    # Lógica de negocio y persistencia
│   ├── models/      # Modelos de datos
│   └── widgets/     # Componentes reutilizables
├── assets/
└── pubspec.yaml

## Autor

Sofía Menzel — [GitHub](https://github.com/Soofiaa) · 
[LinkedIn](https://linkedin.com/in/sofia-menzel-madrid)
