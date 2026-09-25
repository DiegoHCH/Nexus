import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/data/datasources/gemini_live_data_source.dart';
import 'package:nexus/features/assistant/data/repositories/gemini_voice_gateway.dart';
import 'package:nexus/features/assistant/domain/repositories/voice_gateway.dart';

/// **El idioma con su acento llega a las tres puertas, no solo a una.**
///
/// 🔴 Reportado así: «el saludo siempre cambia de voz […] como si fuera una voz
/// diferente». El timbre sí era el elegido —`voiceName` va en el `speechConfig`,
/// que es común a los tres perfiles—; lo que cambiaba era el **acento**.
///
/// El acento no se puede fijar en el protocolo: la doc de la Live API dice que
/// «explicitly setting a language code is not supported for native audio output
/// models», así que viaja en la instrucción del sistema, con palabras. Y esa
/// instrucción la compone cada perfil por su cuenta: la conversación recibía el
/// idioma y **la puerta y el aviso no**, así que el saludo del arranque hablaba
/// con el acento que el modelo decidiera esa vez.
///
/// Es el mismo agujero que ya tuvo la identidad, y por el mismo motivo: la
/// puerta arma su prompt aparte. Lo que esta prueba fija es que las tres digan
/// lo mismo.
void main() {
  GeminiVoiceGateway conIdioma(String idioma) => GeminiVoiceGateway(
    const GeminiLiveDataSource(),
    () async => 'una-llave',
    () => 'Laomedeia',
    () => idioma,
    () => null,
    () => null,
    () => null,
    () async {},
  );

  String instruccionDe(GeminiVoiceGateway gateway, PerfilDeVoz perfil) {
    final setup = gateway.elSetupDe(perfil);
    final sistema = setup['systemInstruction'] as Map<String, dynamic>;
    final partes = sistema['parts'] as List<dynamic>;
    return (partes.first as Map<String, dynamic>)['text'] as String;
  }

  const laPuerta = ComoLaPuerta(saludo: 'Buenas tardes', carpetas: ['nexus']);
  const unAviso = ComoUnAviso('tienes una reunión');

  for (final (nombre, perfil) in <(String, PerfilDeVoz)>[
    ('la conversación', ComoUnaConversacion()),
    ('la puerta del arranque', laPuerta),
    ('el aviso de agenda', unAviso),
  ]) {
    test('$nombre habla con el acento elegido', () {
      final dicho = instruccionDe(conIdioma('español de Colombia'), perfil);

      expect(
        dicho,
        contains('español de Colombia'),
        reason:
            'sin esto el modelo elige el acento por su cuenta en cada sesión, '
            'y suena como otra persona',
      );
    });
  }

  // Y que de verdad sea el que se le pasa, no uno cableado: la app también se
  // usa en inglés.
  test('y en el idioma que sea, que la app no es solo española', () {
    for (final perfil in <PerfilDeVoz>[
      const ComoUnaConversacion(),
      laPuerta,
      unAviso,
    ]) {
      final dicho = instruccionDe(conIdioma('inglés'), perfil);

      expect(dicho, contains('inglés'), reason: '$perfil');
      expect(dicho, isNot(contains('español')), reason: '$perfil');
    }
  });

  // El timbre nunca fue el problema —por eso el usuario decía «si es femenina
  // como la de la selección»— y conviene que siga siendo así: va en el
  // `speechConfig`, que es común a los tres.
  test('el timbre sigue siendo el mismo para los tres', () {
    for (final perfil in <PerfilDeVoz>[
      const ComoUnaConversacion(),
      laPuerta,
      unAviso,
    ]) {
      final setup = conIdioma('español').elSetupDe(perfil);
      final config = setup['generationConfig'] as Map<String, dynamic>;
      final speech = config['speechConfig'] as Map<String, dynamic>;
      final voz = speech['voiceConfig'] as Map<String, dynamic>;
      final prebuilt = voz['prebuiltVoiceConfig'] as Map<String, dynamic>;

      expect(prebuilt['voiceName'], 'Laomedeia', reason: '$perfil');
    }
  });
}
