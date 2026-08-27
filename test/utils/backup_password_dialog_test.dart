// Reproduce el crash real (dispositivo físico) de
// lib/utils/backup_password_dialog.dart: promptForBackupPassword() creaba
// sus TextEditingController como variables locales de función y los
// descartaba (.dispose()) apenas showDialog() retornaba, sin esperar a que
// terminara la animación de cierre / desmontaje del diálogo. Eso producía
// "TextEditingController usado después de ser descartado" y, en cadena,
// otras excepciones (RenderFlex overflow, `_dependents.isEmpty`, GlobalKeys
// duplicados) que eran síntomas del mismo problema, no bugs separados.
//
// La corrección movió los controllers y el GlobalKey<FormState> a campos de
// instancia de _BackupPasswordDialogContent (un StatefulWidget propio), que
// los descarta en su propio dispose() -manejado por el ciclo de vida normal
// del widget-. Este test reproduce el escenario completo: abrir el diálogo,
// escribir en ambos campos, confirmar, y dejar correr la animación de
// cierre hasta el final, verificando que no se lanzó ninguna excepción.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pet_pal/utils/backup_password_dialog.dart';

void main() {
  testWidgets(
    'promptForBackupPassword: escribir en ambos campos y confirmar no lanza excepciones al cerrar',
    (tester) async {
      String? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await promptForBackupPassword(
                    context,
                    title: 'Contraseña del respaldo',
                    confirmLabel: 'Exportar',
                    requireConfirmation: true,
                  );
                },
                child: const Text('Abrir diálogo'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir diálogo'));
      await tester.pumpAndSettle();

      expect(find.text('Contraseña'), findsOneWidget);
      expect(find.text('Confirmar contraseña'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'mi-contraseña');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar contraseña'),
        'mi-contraseña',
      );

      await tester.tap(find.text('Exportar'));
      // Deja correr la animación de cierre del diálogo y el desmontaje
      // completo -exactamente el timing donde ocurría el crash original.
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(result, 'mi-contraseña');
      expect(find.text('Contraseña del respaldo'), findsNothing);
    },
  );
}
