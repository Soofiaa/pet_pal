import 'package:flutter/material.dart';

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
}) async {
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final password = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: passwordController,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Contraseña'),
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Ingresa una contraseña.' : null,
            ),
            if (requireConfirmation) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirmar contraseña'),
                validator: (value) => value != passwordController.text
                    ? 'Las contraseñas no coinciden.'
                    : null,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.of(dialogContext).pop(passwordController.text);
            }
          },
          child: Text(confirmLabel),
        ),
      ],
    ),
  );

  passwordController.dispose();
  confirmController.dispose();
  return password;
}
