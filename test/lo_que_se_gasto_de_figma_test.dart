import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/superpowers/data/datasources/las_llamadas_guardadas.dart';

/// **Contar en los registros lo que se le pidió a Figma.**
///
/// Pedido así: «sería interesante un botón para poder ver cuántos llamados a
/// figma he usado, en mi caso por cuenta». Como Figma no publica el contador,
/// el único sitio donde está escrito es el registro de las sesiones.
String _linea(String cuando, List<String> herramientas) => jsonEncode({
  'timestamp': cuando,
  'message': {
    'role': 'assistant',
    'content': [
      for (final herramienta in herramientas)
        {
          'type': 'tool_use',
          'id': 't1',
          'name': herramienta,
          'input': <String, Object?>{},
        },
    ],
  },
});

void main() {
  late Directory cuenta;

  setUp(() {
    cuenta = Directory.systemTemp.createTempSync('cuenta');
    Directory('${cuenta.path}/projects/un-repo').createSync(recursive: true);
  });
  tearDown(() => cuenta.deleteSync(recursive: true));

  Future<File> registro(String nombre, List<String> lineas) async {
    final f = File('${cuenta.path}/projects/un-repo/$nombre');
    await f.writeAsString('${lineas.join('\n')}\n');
    return f;
  }

  test('cuenta las de este mes, y aparta las exentas', () async {
    await registro('a.jsonl', [
      _linea('2026-09-14T10:00:00.000Z', ['mcp__figma__get_design_context']),
      _linea('2026-09-14T10:01:00.000Z', ['mcp__figma__whoami']),
      _linea('2026-09-15T09:00:00.000Z', [
        'mcp__claude_ai_Figma__get_screenshot',
        'mcp__figma__get_design_context',
      ]),
      // De otro servidor: ni se mira.
      _linea('2026-09-15T09:05:00.000Z', ['mcp__g66__jira_get_issue']),
      // Del mes pasado: no es de este cupo.
      _linea('2026-08-31T23:00:00.000Z', ['mcp__figma__get_metadata']),
      // Y una línea que no es JSON, que las hay.
      'esto no es json',
    ]);

    final uso = await const LasLlamadasGuardadas().deFigmaEn(
      cuenta.path,
      ahora: DateTime(2026, 9, 15, 13),
    );

    expect(uso.gastadas, 3);
    expect(uso.exentas, 1);
    expect(uso.porHerramienta, {'get_design_context': 2, 'get_screenshot': 1});
    expect(uso.ultima?.toUtc(), DateTime.utc(2026, 9, 15, 9));
  });

  test('un registro que no se tocó este mes ni se abre', () async {
    final viejo = await registro('viejo.jsonl', [
      // Con fecha de este mes dentro, para que solo lo excluya la fecha del
      // archivo: si se abriera, contaría.
      _linea('2026-09-10T10:00:00.000Z', ['mcp__figma__get_design_context']),
    ]);
    await viejo.setLastModified(DateTime(2026, 8, 20));

    final uso = await const LasLlamadasGuardadas().deFigmaEn(
      cuenta.path,
      ahora: DateTime(2026, 9, 15),
    );

    expect(uso.gastadas, 0, reason: 'se salta por la fecha del archivo');
  });

  test('una cuenta sin registros contesta cero, no revienta', () async {
    final uso = await const LasLlamadasGuardadas().deFigmaEn(
      '/no/existe/esta/cuenta',
      ahora: DateTime(2026, 9, 15),
    );

    expect(uso.gastadas, 0);
    expect(uso.exentas, 0);
    expect(uso.hayAlgo, isFalse);
  });
}
