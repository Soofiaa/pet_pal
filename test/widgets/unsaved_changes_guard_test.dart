import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_pal/widgets/unsaved_changes_guard.dart';

class _Form extends StatefulWidget {
  const _Form();

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  final _controller = TextEditingController(text: 'inicial');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      snapshot: () => [_controller.text],
      child: Scaffold(body: TextField(controller: _controller)),
    );
  }
}

Future<void> _openForm(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const _Form()),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sin cambios, volver atrás sale sin preguntar', (tester) async {
    await _openForm(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('¿Descartar cambios?'), findsNothing);
  });

  testWidgets('con cambios, volver atrás pregunta y "Seguir editando" se queda', (tester) async {
    await _openForm(tester);
    await tester.enterText(find.byType(TextField), 'editado');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar cambios?'), findsOneWidget);

    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('¿Descartar cambios?'), findsNothing);
  });

  testWidgets('con cambios, "Descartar" cierra la pantalla', (tester) async {
    await _openForm(tester);
    await tester.enterText(find.byType(TextField), 'editado');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('volver al valor original deja de pedir confirmación', (tester) async {
    await _openForm(tester);
    await tester.enterText(find.byType(TextField), 'editado');
    await tester.enterText(find.byType(TextField), 'inicial');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('¿Descartar cambios?'), findsNothing);
  });
}
