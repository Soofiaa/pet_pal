import 'package:flutter/material.dart';
import 'package:pet_pal/utils/entity_colors.dart';

/// Guía conceptual de PetPal: qué hace cada sección de la app, sin
/// referencias a capturas de pantalla ni ubicaciones exactas de botones
/// (eso se desactualiza cada vez que cambia una pantalla).
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    final cards = [
      _GuideCard(
        icon: Icons.today,
        color: primary,
        title: 'Hoy',
        description:
            'Al abrir PetPal, aquí ves de un vistazo qué necesita atención hoy '
            'entre todas tus mascotas: citas, próximas dosis y tratamientos '
            'activos, ordenados por urgencia. Aparece automáticamente al abrir '
            'la app, no necesitas hacer nada para verla.',
      ),
      _GuideCard(
        icon: Icons.pets,
        color: primary,
        title: 'Mascotas',
        description:
            'Cada mascota tiene su propio perfil: foto, especie, raza, y hasta '
            'su número de microchip. La edad se calcula sola, en años, meses y '
            'días exactos. Para agregar una, toca el botón + en la esquina '
            'inferior derecha de la pantalla principal.',
      ),
      _GuideCard(
        icon: Icons.local_hospital,
        color: entityColorFor('vaccination'),
        title: 'Vacunas',
        description:
            'Registra cada vacuna aplicada con su fecha y, si corresponde, la '
            'próxima dosis. PetPal te avisa cuando se acerca. Entra al perfil '
            'de tu mascota, toca \'Vacunas\', y presiona el botón + para '
            'agregar una nueva.',
      ),
      _GuideCard(
        icon: Icons.medical_services,
        color: entityColorFor('medication'),
        title: 'Medicación',
        description:
            'Define cuántas veces al día se da un medicamento y a qué hora '
            'exacta — los recordatorios respetan tu horario real, no uno '
            'genérico. Entra al perfil de tu mascota, toca \'Medicación\', y '
            'presiona el botón + para registrar una.',
      ),
      _GuideCard(
        icon: Icons.bug_report,
        color: entityColorFor('deworming'),
        title: 'Desparasitación',
        description:
            'Además de registrar cada aplicación, puedes marcarla como '
            'recurrente (por ejemplo, cada 3 meses) y PetPal te va a recordar '
            'sin que tengas que crear un registro nuevo cada vez. Entra al '
            'perfil de tu mascota, toca \'Desparasitaciones\', y presiona el '
            'botón + —ahí encontrarás la opción de recurrencia.',
      ),
      _GuideCard(
        icon: Icons.scale,
        color: entityColorFor('weight'),
        title: 'Peso',
        description:
            'Cada control de peso se suma a un gráfico de tendencia, para ver '
            'de un vistazo si tu mascota está subiendo, bajando, o estable en '
            'el tiempo. Entra al perfil de tu mascota, toca \'Peso\', y '
            'presiona el botón + para agregar un registro.',
      ),
      _GuideCard(
        icon: Icons.monitor_heart,
        color: entityColorFor('vital_sign'),
        title: 'Signos Vitales',
        description:
            'Registra la temperatura de tu mascota y recibe una alerta '
            'automática si el valor sale del rango normal para su especie. '
            'Entra al perfil de tu mascota, toca \'Signos Vitales\', y '
            'presiona el botón + para registrar una medición.',
      ),
      _GuideCard(
        icon: Icons.folder_shared,
        color: entityColorFor('document'),
        title: 'Documentos',
        description:
            'Guarda exámenes, informes de cirugía, radiografías y recetas, '
            'organizados por categoría — todo el historial clínico en un solo '
            'lugar. Entra al perfil de tu mascota, toca \'Documentos\', y '
            'presiona el botón + para adjuntar un archivo.',
      ),
      _GuideCard(
        icon: Icons.description,
        color: entityColorFor('note'),
        title: 'Notas',
        description:
            'Un diario de comportamiento y observaciones, con fotos, que '
            'puedes exportar a PDF cuando lo necesites. Entra al perfil de tu '
            'mascota, toca \'Notas\', y presiona el botón + para escribir una.',
      ),
      _GuideCard(
        icon: Icons.calendar_today,
        color: entityColorFor('appointment'),
        title: 'Citas',
        description:
            'Programa tus visitas al veterinario con recordatorio incluido. '
            'Entra al perfil de tu mascota, toca \'Citas\', y presiona el '
            'botón + para agendar una.',
      ),
      _GuideCard(
        icon: Icons.no_food,
        color: entityColorFor('food_allergy'),
        title: 'Alergias Alimentarias',
        description:
            'Lleva registro de qué alimentos no le sientan bien a tu mascota, '
            'para tenerlo siempre a mano. Entra al perfil de tu mascota, toca '
            '\'Alergias\', y presiona el botón + para agregar una.',
      ),
      _GuideCard(
        icon: Icons.calendar_month,
        color: primary,
        title: 'Calendario',
        description:
            'Todo el historial de una mascota —vacunas, medicación, citas, '
            'notas y más— en una sola vista cronológica, cada tipo con su '
            'propio ícono y color. Entra al perfil de tu mascota y toca '
            '\'Eventos\' en la parte superior de la pantalla.',
      ),
      _GuideCard(
        icon: Icons.search,
        color: primary,
        title: 'Buscador',
        description:
            '¿No recuerdas en qué vacuna o documento aparece algo puntual? El '
            'buscador revisa todas tus mascotas y todas las secciones a la '
            'vez. Si tienes más de una mascota, cada resultado te indica de '
            'cuál es, para que no haya confusión. Toca el ícono de lupa en la '
            'parte superior de la pantalla principal, y escribe lo que '
            'buscas.',
      ),
      _GuideCard(
        icon: Icons.lock,
        color: primary,
        title: 'Backup y Restauración',
        description:
            'Respalda toda la información de la app —incluyendo archivos '
            'adjuntos— en un solo archivo protegido con contraseña. Puedes '
            'restaurarlo cuando lo necesites. Abre el menú lateral (ícono de '
            'las tres líneas, arriba a la izquierda) y toca \'Notificaciones '
            'y Respaldo\'.',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Guía de PetPal')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: cards,
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _GuideCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
