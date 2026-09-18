import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/domain/entities/claude_event.dart';
import 'package:nexus/features/assistant/data/repositories/claude_bridge_impl.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';

/// **Si la compactación comprimió de verdad, o por qué no.**
///
/// 🔴 Nexus mandaba `/compact` y solo miraba el `result` final, así que una
/// compactación que funcionó y una que falló se contaban igual: «se actualiza
/// en el siguiente turno» en los dos casos. Medido en la sesión de
/// `feria-iglesia`: nueve compactaciones seguidas sin que el contexto bajara —
/// y sin que la app tuviera forma de saberlo.
///
/// El CLI sí lo dice, y se estaba tirando. Estas son las líneas que emite,
/// copiadas de una corrida real contra el binario 2.1.273.
void main() {
  const carpeta = '/Users/alguien/General';

  List<ClaudeEvent> de(Map<String, dynamic> json) =>
      ClaudeBridgeImpl.eventosDe(json, carpeta);

  test('la que falló lo dice, y con su motivo', () {
    final eventos = de({
      'type': 'system',
      'subtype': 'status',
      'status': null,
      'compact_result': 'failed',
      'compact_error': 'Not enough messages to compact.',
    });

    final compacto = eventos.whereType<ClaudeCompacto>().single;
    expect(compacto.ok, isFalse);
    expect(compacto.error, 'Not enough messages to compact.');
  });

  test('y la que funcionó, también', () {
    final compacto = de({
      'type': 'system',
      'subtype': 'status',
      'status': null,
      'compact_result': 'success',
    }).whereType<ClaudeCompacto>().single;

    expect(compacto.ok, isTrue);
    expect(compacto.error, isNull);
  });

  // El `status: compacting` de antes no aporta nada: que empezó ya lo sabe
  // quien la pidió, y reenviarlo sería un evento por ruido.
  test('que empezó no se reenvía', () {
    expect(
      de({'type': 'system', 'subtype': 'status', 'status': 'compacting'}),
      isEmpty,
    );
  });

  // Y lo de siempre sigue pasando: el arranque trae la sesión y el modelo.
  test('el arranque sigue siendo el arranque', () {
    final eventos = de({
      'type': 'system',
      'subtype': 'init',
      'session_id': 's1',
      'model': 'claude-sonnet-5',
    });

    expect(eventos.whereType<ClaudeSessionStarted>(), hasLength(1));
    expect(eventos.whereType<ClaudeCompacto>(), isEmpty);
  });

  // El motivo se enseña tal cual —es del CLI— pero sin motivo no puede quedar
  // una frase colgando con dos puntos y nada detrás.
  test('el texto aguanta quedarse sin motivo', () {
    for (final textos in <NexusStrings>[
      const NexusStringsEs(),
      const NexusStringsEn(),
    ]) {
      expect(textos.noSePudoComprimir('').trim(), isNotEmpty);
      expect(textos.noSePudoComprimir('').trim(), isNot(endsWith(':')));
      expect(
        textos.noSePudoComprimir('se acabó el cupo'),
        contains('se acabó el cupo'),
      );
    }
  });
}
