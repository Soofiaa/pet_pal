import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Pide confirmación al salir de un formulario con cambios sin guardar.
///
/// [snapshot] devuelve los valores editables actuales (textos, fechas,
/// switches, rutas de fotos como valores simples). Se compara con el estado
/// inicial, tomado al montar el widget, en el momento de salir: así no hace
/// falta que cada pantalla avise cada cambio. El pop programático tras un
/// guardado (`Navigator.pop`) no pasa por la confirmación.
class UnsavedChangesGuard extends StatefulWidget {
  final List<Object?> Function() snapshot;
  final Widget child;

  const UnsavedChangesGuard({
    super.key,
    required this.snapshot,
    required this.child,
  });

  @override
  State<UnsavedChangesGuard> createState() => _UnsavedChangesGuardState();
}

class _UnsavedChangesGuardState extends State<UnsavedChangesGuard> {
  late final List<Object?> _initial;

  @override
  void initState() {
    super.initState();
    _initial = widget.snapshot();
  }

  bool get _isDirty => !listEquals(_initial, widget.snapshot());

  Future<void> _onPop(bool didPop, Object? result) async {
    if (didPop) return;
    if (!_isDirty) {
      Navigator.of(context).pop();
      return;
    }
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Descartar cambios?'),
        content: const Text('Tienes cambios sin guardar. Si sales ahora, se perderán.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Seguir editando'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: _onPop,
      child: widget.child,
    );
  }
}
