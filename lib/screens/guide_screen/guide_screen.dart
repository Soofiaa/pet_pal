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
            'Al abrir PetPal, acá ves de un vistazo qué necesita atención hoy '
            'entre todas tus mascotas: citas, próximas dosis y tratamientos '
            'activos, ordenados por urgencia.',
      ),
      _GuideCard(
        icon: Icons.pets,
        color: primary,
        title: 'Mascotas',
        description:
            'Cada mascota tiene su propio perfil: foto, especie, raza, y hasta '
            'su número de microchip. La edad se calcula sola, en años, meses y '
            'días exactos.',
      ),
      _GuideCard(
        icon: Icons.local_hospital,
        color: entityColorFor('vaccination'),
        title: 'Vacunas',
        description:
            'Registra cada vacuna aplicada con su fecha y, si corresponde, la '
            'próxima dosis. PetPal te avisa cuando se acerca.',
      ),
      _GuideCard(
        icon: Icons.medical_services,
        color: entityColorFor('medication'),
        title: 'Medicación',
        description:
            'Define cuántas veces al día se da un medicamento y a qué hora '
            'exacta — los recordatorios respetan tu horario real, no uno '
            'genérico.',
      ),
      _GuideCard(
        icon: Icons.bug_report,
        color: entityColorFor('deworming'),
        title: 'Desparasitación',
        description:
            'Además de registrar cada aplicación, podés marcarla como '
            'recurrente (por ejemplo, cada 3 meses) y PetPal te va a recordar '
            'sin que tengas que crear un registro nuevo cada vez.',
      ),
      _GuideCard(
        icon: Icons.scale,
        color: entityColorFor('weight'),
        title: 'Peso',
        description:
            'Cada control de peso se suma a un gráfico de tendencia, para ver '
            'de un vistazo si tu mascota está subiendo, bajando, o estable en '
            'el tiempo.',
      ),
      _GuideCard(
        icon: Icons.monitor_heart,
        color: entityColorFor('vital_sign'),
        title: 'Signos Vitales',
        description:
            'Registra la temperatura de tu mascota y recibí una alerta '
            'automática si el valor sale del rango normal para su especie.',
      ),
      _GuideCard(
        icon: Icons.folder_shared,
        color: entityColorFor('document'),
        title: 'Documentos',
        description:
            'Guarda exámenes, informes de cirugía, radiografías y recetas, '
            'organizados por categoría — todo el historial clínico en un solo '
            'lugar.',
      ),
      _GuideCard(
        icon: Icons.description,
        color: entityColorFor('note'),
        title: 'Notas',
        description:
            'Un diario de comportamiento y observaciones, con fotos, que '
            'podés exportar a PDF cuando lo necesites.',
      ),
      _GuideCard(
        icon: Icons.calendar_today,
        color: entityColorFor('appointment'),
        title: 'Citas',
        description: 'Programa tus visitas al veterinario con recordatorio incluido.',
      ),
      _GuideCard(
        icon: Icons.no_food,
        color: entityColorFor('food_allergy'),
        title: 'Alergias Alimentarias',
        description:
            'Llevá registro de qué alimentos no le sientan bien a tu mascota, '
            'para tenerlo siempre a mano.',
      ),
      _GuideCard(
        icon: Icons.calendar_month,
        color: primary,
        title: 'Calendario',
        description:
            'Todo el historial de una mascota —vacunas, medicación, citas, '
            'notas y más— en una sola vista cronológica, cada tipo con su '
            'propio ícono y color.',
      ),
      _GuideCard(
        icon: Icons.search,
        color: primary,
        title: 'Buscador',
        description:
            '¿No te acordás en qué vacuna o documento aparece algo puntual? '
            'El buscador revisa todas tus mascotas y todas las secciones a la '
            'vez.',
      ),
      _GuideCard(
        icon: Icons.lock,
        color: primary,
        title: 'Backup y Restauración',
        description:
            'Respalda toda la información de la app —incluyendo archivos '
            'adjuntos— en un solo archivo protegido con contraseña. Podés '
            'restaurarlo cuando lo necesites.',
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
