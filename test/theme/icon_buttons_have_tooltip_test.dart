// Un IconButton sin tooltip no tiene nombre para los lectores de pantalla.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('todo IconButton de lib/ declara tooltip', () {
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('IconButton(')) continue;
        final end = (i + 12).clamp(0, lines.length);
        final window = lines.sublist(i, end).join('\n');
        if (!window.contains('tooltip:')) offenders.add('${file.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty, reason: 'IconButton sin tooltip');
  });
}
