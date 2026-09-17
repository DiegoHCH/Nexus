import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/domain/entities/voice_event.dart';
import 'package:nexus/features/assistant/presentation/state/session_meter.dart';

// El medidor de contexto cuando se habla.
//
// Nace de un caso medido en la app instalada: seis mensajes **por audio** dejaron
// el medidor en 84 %, y el contexto real era 175.922 tokens sobre una ventana de un
// millón — el 18 %. Cinco veces inflado.
//
// La causa: el evento que trae el modelo se descartaba en el flujo de voz con un
// `break`, y sin modelo `contextWindow` da por hecha una ventana de 200k. Es la
// mitad que faltaba de un arreglo anterior, donde se hicieron llegar los tokens y
// se olvidó el modelo: **se arregló el numerador y se dejó el denominador**.
//
// Y el clamp al 100 % lo tapaba: un 398 % habría gritado, un 100 % parece
// «contexto lleno».
void main() {
  group('la ventana sale del identificador del modelo', () {
    test('con la variante de un millón', () {
      const m = SessionMeter(model: 'claude-opus-5[1m]', contextTokens: 175922);
      expect(m.contextWindow, 1000000);
      expect(m.contextPercent, 18, reason: 'el caso real que lo destapó');
    });

    test('y con una de doscientos mil, el 88 % que se veía', () {
      const m = SessionMeter(model: 'claude-haiku-4-5', contextTokens: 175922);
      expect(m.contextWindow, 200000);
      expect(
        m.contextPercent,
        88,
        reason: 'lo que se veía mal, con el mismo dato',
      );
    });

    // 🔴 **Antes aquí se asumían 200k, y esa suposición volvió a morder.** La
    // regla «si no lo sé, 200k» daba un 88 % falso sin modelo y un 100 % falso
    // con `claude-sonnet-5`, que también es de un millón — y ese 100 % pedía
    // comprimir al final de cada turno, para siempre.
    //
    // Ahora lo que no se sabe se dice: sin ventana no hay porcentaje, y sin
    // porcentaje no se comprime. Sigue sin poder pasar **llegar aquí sin modelo
    // cuando el CLI sí lo dijo**, que es lo que mide el grupo de abajo.
    test('sin modelo no se asume ninguna, y no hay porcentaje', () {
      const m = SessionMeter(contextTokens: 175922);
      expect(m.contextWindow, isNull);
      expect(m.contextPercent, isNull);
      expect(m.contextLabel, '175,9k', reason: 'los tokens sí, el % no');
    });
  });

  group('el fin de encargo hablado trae el modelo', () {
    test('lo lleva junto a los tokens', () {
      // La regresión concreta: este evento llevaba los tokens y no el modelo, así
      // que el medidor recibía el numerador sin el denominador.
      const evento = VoiceToolFinished(
        ok: true,
        turnTokens: 1200,
        contextTokens: 175922,
        model: 'claude-opus-5[1m]',
      );
      expect(evento.model, 'claude-opus-5[1m]');

      // Y aplicado al medidor, como hace el controlador.
      final medidor = const SessionMeter().copyWith(
        model: evento.model,
        turnTokens: evento.turnTokens,
        contextTokens: evento.contextTokens,
      );
      expect(medidor.contextWindow, 1000000);
      expect(medidor.contextPercent, 18);
      expect(medidor.contextLabel, '175,9k / 1,0M (18 %)');
    });

    test('y sin él, el medidor se calla en vez de mentir', () {
      // La prueba que impide que alguien lo quite «porque no se usa». Lo que
      // cambió es el castigo: antes inventaba un 88 %, ahora no dice nada. Un
      // hueco en el HUD se ve; un porcentaje inventado, no.
      const evento = VoiceToolFinished(ok: true, contextTokens: 175922);
      final medidor = const SessionMeter().copyWith(
        model: evento.model,
        contextTokens: evento.contextTokens,
      );
      expect(medidor.contextPercent, isNull);
    });
  });

  test('el clamp sigue tapando lo imposible, y por eso la etiqueta importa', () {
    // Un contexto mayor que la ventana asumida se recorta a 100 %, y eso ocultó
    // este defecto: 796k sobre 200k son 398 %, que se enseñaban como 100 %. La
    // etiqueta completa es lo único que lo delataba.
    const m = SessionMeter(model: 'claude-haiku-4-5', contextTokens: 796410);
    expect(m.contextPercent, 100);
    expect(
      m.contextLabel,
      '796,4k / 200,0k (100 %)',
      reason: 'la etiqueta enseña la contradicción que el porcentaje esconde',
    );
  });
}
