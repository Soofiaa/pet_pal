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

    return Scaffold(
      appBar: AppBar(title: const Text('Guía de PetPal')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _GuideCard(
            icon: Icons.pets,
            color: primary,
            title: 'Mascotas',
            shortDescription: 'Agrega mascotas con foto, especie, raza y microchip. La edad se calcula automáticamente.',
            fullDescription: 'Cada mascota tiene su propio perfil con toda su información. En la pantalla principal, toca la tarjeta de una mascota para ver su perfil. Para agregar una nueva, usa el botón + en la esquina inferior derecha.',
          ),
          _GuideCard(
            icon: Icons.notifications_active,
            color: primary,
            title: 'Avisos',
            shortDescription: 'Íconos en cada mascota cuando algo necesita atención: vacuna, desparasitación o cita.',
            fullDescription: 'Rojo significa vencido; naranja, que es hoy o en los próximos 7 días. Si no hay nada pendiente, verás "Al día". Para ver el detalle de todas tus mascotas, toca el ícono de calendario arriba a la derecha.',
          ),
          _GuideCard(
            icon: Icons.local_hospital,
            color: entityColorFor('vaccination'),
            title: 'Salud',
            shortDescription: 'Registra vacunas, medicación, desparasitación, alergias y signos vitales con recordatorios.',
            fullDescription: 'Entra al perfil de tu mascota y toca la sección que necesites. Para vacunas, puedes configurar la próxima dosis. Para desparasitación, marca la recurrencia (ej. cada 3 meses) y PetPal recuerda por ti. Los signos vitales alertan si el valor está fuera del rango normal.',
          ),
          _GuideCard(
            icon: Icons.folder_shared,
            color: entityColorFor('document'),
            title: 'Historial',
            shortDescription: 'Guarda peso, documentos, notas y observa tendencias en gráficos.',
            fullDescription: 'El peso se muestra en un gráfico de tendencia. Documentos organiza exámenes, informes y recetas por categoría. Notas es un diario de comportamiento con fotos que puedes exportar a PDF.',
          ),
          _GuideCard(
            icon: Icons.calendar_today,
            color: entityColorFor('appointment'),
            title: 'Citas',
            shortDescription: 'Agenda visitas al veterinario con recordatorio personalizable.',
            fullDescription: 'Elige con cuánta anticipación quieres el aviso: mismo día, 1 día antes, 3 días o 1 semana antes. La opción está al agendar o editar una cita.',
          ),
          _GuideCard(
            icon: Icons.calendar_month,
            color: primary,
            title: 'Calendario y buscador',
            shortDescription: 'Vista cronológica de todo el historial y búsqueda global entre mascotas.',
            fullDescription: 'El calendario muestra vacunas, medicación, citas y notas en una línea de tiempo. El buscador revisa todas tus mascotas y secciones a la vez. Toca el ícono de lupa en la pantalla principal.',
          ),
          const Padding(
            padding: EdgeInsets.only(top: 24, left: 16, right: 16),
            child: Text(
              'Consejos avanzados',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          _GuideCard(
            icon: Icons.info_outline,
            color: primary,
            title: 'Equivalencias de vacunas',
            shortDescription: 'Agrupa vacunas similares para que cuenten como una sola.',
            fullDescription: 'Si aplicaste una vacuna que reemplaza a otra (ej. Óctuple en lugar de Séxtuple), PetPal ya las trata como equivalentes. Para configurar otras equivalencias, abre el menú lateral, toca Vacunas en Catálogos y usa el campo "Grupo de equivalencia".',
          ),
          _GuideCard(
            icon: Icons.lock,
            color: primary,
            title: 'Backup y restauración',
            shortDescription: 'Respalda toda la app en un archivo protegido con contraseña.',
            fullDescription: 'Incluye archivos adjuntos. Abre el menú lateral y toca "Respaldo y restauración". Ahí también puedes borrar archivos antiguos sin uso para liberar espacio.',
          ),
          _GuideCard(
            icon: Icons.location_on,
            color: primary,
            title: 'Catálogo de ubicaciones',
            shortDescription: 'Guarda clínicas, peluquerías y otros lugares para reutilizar en citas.',
            fullDescription: 'Los lugares se comparten entre todas tus mascotas. Al agendar una cita, puedes elegir uno guardado o crear uno nuevo. Editar o eliminar un lugar del catálogo no afecta a citas que ya lo usaron.',
          ),
          _GuideCard(
            icon: Icons.more_vert,
            color: primary,
            title: 'Exportar y eliminar',
            shortDescription: 'Genera la ficha clínica en PDF o elimina una mascota.',
            fullDescription: 'En el perfil de tu mascota, toca el ícono de tres puntos (⋮) arriba a la derecha. Eliminar no se puede deshacer, así que te pedimos confirmación.',
          ),
        ],
      ),
    );
  }
}

class _GuideCard extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String shortDescription;
  final String fullDescription;

  const _GuideCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.shortDescription,
    required this.fullDescription,
  });

  @override
  State<_GuideCard> createState() => _GuideCardState();
}

class _GuideCardState extends State<_GuideCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, color: widget.color, size: 22),
            ),
            title: Text(
              widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                _expanded ? widget.fullDescription : widget.shortDescription,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            trailing: TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? 'Ver menos' : 'Ver más'),
            ),
          ),
        ],
      ),
    );
  }
}
