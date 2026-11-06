import 'package:flutter/material.dart';

/// Largo mínimo de la contraseña al exportar un respaldo cifrado.
const int minBackupPasswordLength = 10;

/// Diálogo compartido para pedir la contraseña de cifrado/descifrado del
/// backup ZIP. Usado desde home_screen.dart y backup_settings_screen.dart
/// (los dos puntos de entrada a DataBackupService.exportAllData/
/// importAllData). Devuelve `null` si el usuario cancela.
///
/// Con [requireConfirmation] pide repetir la contraseña -para export, ya
/// que un typo ahí deja el backup inutilizable; para import no hace
/// falta, el propio ZipDecoder ya valida si es la correcta.
Future<String?> promptForBackupPassword(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  bool requireConfirmation = false,
}) {
  final contentKey = GlobalKey<_BackupPasswordDialogContentState>();

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: _BackupPasswordDialogContent(
        key: contentKey,
        requireConfirmation: requireConfirmation,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final password = contentKey.currentState?.validateAndGetPassword();
            if (password != null) {
              Navigator.of(dialogContext).pop(password);
            }
          },
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

/// Contenido con estado propio del diálogo: sus TextEditingController y su
/// `GlobalKey<FormState>` son campos de instancia descartados en [dispose],
/// para que el framework los libere en sincronía con el desmontaje real del
/// widget (tras la animación de cierre) en vez de que `promptForBackupPassword`
/// los descarte manualmente justo después de que `showDialog` retorna, antes
/// de que el árbol termine de desmontarse.
class _BackupPasswordDialogContent extends StatefulWidget {
  const _BackupPasswordDialogContent({
    super.key,
    required this.requireConfirmation,
  });

  final bool requireConfirmation;

  @override
  State<_BackupPasswordDialogContent> createState() => _BackupPasswordDialogContentState();
}

class _BackupPasswordDialogContentState extends State<_BackupPasswordDialogContent> {
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  /// Valida el formulario y devuelve la contraseña ingresada, o `null` si la
  /// validación falla. Invocado por el botón de confirmar en las acciones
  /// del AlertDialog, fuera de este widget.
  String? validateAndGetPassword() {
    if (formKey.currentState!.validate()) {
      // Solo el export (requireConfirmation) pone el mínimo; el import acepta
      // cualquier contraseña para no bloquear respaldos antiguos.
      return passwordController.text;
    }
    return null;
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: passwordController,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Contraseña'),
            validator: (value) => (value == null || value.isEmpty)
                ? 'Ingresa una contraseña.'
                : (widget.requireConfirmation && value.length < minBackupPasswordLength)
                    ? 'Usa al menos $minBackupPasswordLength caracteres.'
                    : null,
          ),
          if (widget.requireConfirmation) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirmar contraseña'),
              validator: (value) =>
                  value != passwordController.text ? 'Las contraseñas no coinciden.' : null,
            ),
          ],
        ],
      ),
    );
  }
}
