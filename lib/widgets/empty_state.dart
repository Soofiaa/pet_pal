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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            if (actionHint != null) ...[
              const SizedBox(height: 8),
              Text(
                actionHint!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
