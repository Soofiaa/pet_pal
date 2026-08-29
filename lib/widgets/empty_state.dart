import 'package:flutter/material.dart';

/// Estado vacío estándar para listas de la app: ícono + mensaje principal
/// y, opcionalmente, una sugerencia de acción (ej. hacia el FAB "+").
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionHint;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionHint,
  });

  @override
  Widget build(BuildContext context) {
    // onSurfaceVariant en vez de un gris fijo: mismo criterio que ya usa
    // today_dashboard_section.dart (colorScheme.errorContainer/onErrorContainer
    // en vez de Colors.red[50] fijo) para que el estado vacío se mantenga
    // consistente con la paleta tonal real de cada tema -el tema oscuro de
    // la app usa colorSchemeSeed, no un gris neutro-.
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionHint != null) ...[
              const SizedBox(height: 8),
              Text(
                actionHint!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
