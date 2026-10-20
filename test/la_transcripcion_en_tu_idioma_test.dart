import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/data/datasources/gemini_live_data_source.dart';
import 'package:nexus/features/assistant/data/repositories/gemini_voice_gateway.dart';
import 'package:nexus/features/assistant/domain/repositories/voice_gateway.dart';

/// **Lo que dices se transcribe con el idioma de la app como pista.**
///
/// 🔴 Visto en el chat: un «sí» dicho en español quedó escrito como «C'est
/// votre leçon.». El modelo sí lo había entendido —el encargo a Claude salió
/// bien—; lo que se equivocó fue la transcripción, que sin pista adivina el
/// idioma frase a frase y en las cortas falla.
///
/// Lo que esta prueba fija es que la pista llegue a las tres puertas, porque el
/// `setup` es común a las tres, y que sin código no se mande una lista vacía:
/// el mapa vacío es lo que se mandaba antes y se sabe que funciona.
void main() {
  GeminiVoiceGateway conCodigo(String? codigo) => GeminiVoiceGateway(
    const GeminiLiveDataSource(),
    () async => 'una-llave',
    () => 'Laomedeia',
    () => 'español',
    () => null,
    () => null,
    () => null,
    () async {},
    leerElCodigoDelIdioma: () => codigo,
  );

  Map<String, dynamic> transcripcionDe(
    GeminiVoiceGateway gateway,
    PerfilDeVoz perfil,
  ) =>
      gateway.elSetupDe(perfil)['inputAudioTranscription']
          as Map<String, dynamic>;

  const perfiles = <PerfilDeVoz>[
    ComoUnaConversacion(),
    ComoLaPuerta(saludo: 'Buenas tardes', carpetas: ['nexus']),
    ComoUnAviso('tienes una reunión'),
  ];

  test('las tres puertas transcriben con el idioma de la app de pista', () {
    for (final perfil in perfiles) {
      expect(transcripcionDe(conCodigo('es'), perfil)['languageCodes'], [
        'es',
      ], reason: '$perfil');
    }
  });

  // La app también se usa en inglés: la pista es la que se le pasa, no una
  // cableada.
  test('y en inglés, la pista es inglés', () {
    expect(transcripcionDe(conCodigo('en'), const ComoUnaConversacion()), {
      'languageCodes': ['en'],
    });
  });

  test('sin código se pide la transcripción como antes, sin pista', () {
    for (final perfil in perfiles) {
      expect(
        transcripcionDe(conCodigo(null), perfil),
        isEmpty,
        reason: '$perfil',
      );
    }
  });
}
