import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/presentation/state/session_meter.dart';

void main() {
  group('la ventana de contexto', () {
    // El corchete manda cuando viene: es lo que dice el CLI de esta corrida.
    test('el corchete gana sobre la tabla', () {
      expect(
        const SessionMeter(model: 'claude-opus-5[1m]').contextWindow,
        1000000,
      );
    });

    // 🔴 **Lo que costaba una compresión por turno.** La regla era «`[1m]` es de
    // un millón y el resto 200k», y el resto no es 200k. Medido en la máquina:
    // una sesión con `claude-sonnet-5` iba por 252.460 tokens en una petición
    // que no falló, y la app la pintaba al 100 % pidiendo comprimir cada turno.
    test('sin corchete, la ventana la dice la tabla y no el corchete', () {
      expect(
        const SessionMeter(model: 'claude-sonnet-5').contextWindow,
        1000000,
      );
      expect(const SessionMeter(model: 'claude-opus-5').contextWindow, 1000000);
      expect(
        const SessionMeter(model: 'claude-haiku-4-5').contextWindow,
        200000,
      );
    });

    // El caso de verdad, con las cifras de la sesión que lo reportó.
    test('la sesión que pedía comprimir cada turno ya no llega al umbral', () {
      const meter = SessionMeter(
        model: 'claude-sonnet-5',
        contextTokens: 252460,
      );

      expect(meter.contextPercent, 25);
    });

    // Con sufijo de fecha gana el prefijo más largo, o `claude-fable-5` se
    // comería a `claude-fable-5-1`.
    test('un sufijo detrás no despista', () {
      expect(
        const SessionMeter(model: 'claude-haiku-4-5-20251001').contextWindow,
        200000,
      );
      expect(
        const SessionMeter(model: 'claude-fable-5-1').contextWindow,
        1000000,
      );
    });

    // 🔴 **Lo desconocido se dice, no se asume.** Asumir 200k para todo lo que
    // no se conoce es justo lo que disparaba la compresión en bucle: sin
    // ventana no hay porcentaje, y sin porcentaje no se comprime.
    test('un modelo que no está en la tabla no tiene ventana', () {
      const meter = SessionMeter(
        model: 'claude-loquesea-9',
        contextTokens: 63300,
      );

      expect(meter.contextWindow, isNull);
      expect(meter.contextPercent, isNull);
      expect(meter.contextFraction, 0);
      expect(meter.contextLabel, '63,3k', reason: 'los tokens sí, el % no');
    });

    test('las tres cifras, como en el CLI', () {
      const meter = SessionMeter(
        model: 'claude-opus-5[1m]',
        contextTokens: 63300,
      );

      expect(meter.contextLabel, '63,3k / 1,0M (6 %)');
      expect(meter.contextPercent, 6);
    });

    test('con ventana de 200k, los mismos tokens pesan mucho más', () {
      const meter = SessionMeter(
        model: 'claude-haiku-4-5',
        contextTokens: 63300,
      );

      expect(meter.contextLabel, '63,3k / 200,0k (32 %)');
    });

    // Sin turno todavía no hay medida. Un «0 / 1,0M» se leería como una ventana
    // comprobada y vacía, que no es lo mismo que una que nadie ha mirado.
    test('sin tokens no se inventa una lectura', () {
      expect(const SessionMeter(model: 'claude-opus-5').contextLabel, isNull);
      expect(const SessionMeter().contextFraction, 0);
    });

    test('lo que llena el círculo va de 0 a 1 y no se pasa', () {
      expect(
        const SessionMeter(
          model: 'claude-haiku-4-5',
          contextTokens: 100000,
        ).contextFraction,
        0.5,
      );
      // Una sesión reanudada puede traer más tokens que la ventana del modelo
      // que hay puesto ahora: el círculo se queda lleno, no se desborda.
      expect(
        const SessionMeter(
          model: 'claude-haiku-4-5',
          contextTokens: 900000,
        ).contextFraction,
        1.0,
      );
    });

    // El círculo ya se quedaba lleno; el texto de al lado seguía diciendo
    // «132 %». Con la medida arreglada esa cifra sale de una sesión reanudada
    // con más tokens que la ventana del modelo de ahora, y aun siendo cierta se
    // lee como el error de medida que fue durante un tiempo.
    test('el porcentaje tampoco se pasa del 100', () {
      const desbordada = SessionMeter(
        model: 'claude-haiku-4-5',
        contextTokens: 264200,
      );
      expect(desbordada.contextPercent, 100);
      // Y las cifras de al lado siguen enseñando que se pasó: el tope está en
      // el porcentaje, no en el dato.
      expect(desbordada.contextLabel, '264,2k / 200,0k (100 %)');
    });
  });
}
