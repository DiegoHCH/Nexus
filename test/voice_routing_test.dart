import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/domain/usecases/voice_routing.dart';

void main() {
  group('se contesta solo', () {
    // La lista corta: cortesía y control de la conversación. Nada que hable
    // del Mac, del proyecto o del mundo.
    const solo = [
      'Hola',
      'hola!',
      'Buenos días',
      '¿Qué tal?',
      'Gracias',
      'Muchísimas gracias',
      'Vale',
      'Perfecto',
      'Adiós',
      'Hasta luego',
      'Para',
      'Espera',
      'Repite',
      'Repítelo, por favor',
      '¿Qué dijiste?',
      'Hi',
      'Thanks a lot',
      'Stop',
      'Say that again',
    ];

    for (final frase in solo) {
      test('«$frase»', () => expect(VoiceRouting.needsClaude(frase), isFalse));
    }

    // 🔴 Medido el 25 sep: «¿En qué te puedo ayudar?» — «En nada, adiós», y
    // detrás de la despedida salió «Voy a pedirle a Claude que te responda».
    // Nadie se despide empezando por «adiós».
    const conRelleno = [
      'En nada, adiós',
      'Nada, gracias',
      'No, gracias',
      'Bueno, hasta luego',
      'Vale, hasta mañana',
      'Eso es todo',
      'Nada más',
      'Listo',
      '¿Cómo te encuentras?',
      "No, that's all",
      'No, gracias, eso es todo',
      'Bueno, gracias, hasta mañana',
    ];

    for (final frase in conRelleno) {
      test('«$frase»', () => expect(VoiceRouting.needsClaude(frase), isFalse));
    }

    test('con su nombre delante o detrás sigue siendo cortesía', () {
      expect(
        VoiceRouting.needsClaude('Hestia, gracias', agente: 'Hestia'),
        isFalse,
      );
      expect(
        VoiceRouting.needsClaude('Adiós, Hestia', agente: 'Hestia'),
        isFalse,
      );
      // Y quitarle el nombre no convierte un encargo en charla.
      expect(
        VoiceRouting.needsClaude('Hestia, corre los tests', agente: 'Hestia'),
        isTrue,
      );
    });

    test('el silencio no dispara nada', () {
      expect(VoiceRouting.needsClaude(''), isFalse);
      expect(VoiceRouting.needsClaude('   '), isFalse);
    });
  });

  group('va a Claude', () {
    // La zona gris medida en b6: preguntas que el modelo cree saber y no sabe,
    // porque la respuesta está en esta máquina y no en su memoria.
    const aClaude = [
      '¿Qué opinas de Riverpod?',
      '¿Qué hora es?',
      '¿Cuánto ocupa este repo?',
      '¿Qué versión tengo instalada?',
      'Mira el historial de git',
      'Corre los tests',
      '¿Cuántos archivos hay en lib?',
      'Resume lo que hicimos ayer',
      'What time is it?',
      'Run the tests',
    ];

    for (final frase in aClaude) {
      test('«$frase»', () => expect(VoiceRouting.needsClaude(frase), isTrue));
    }

    // La trampa de empezar por un saludo: si bastara con que la frase empiece
    // como cortesía, «hola, mira el historial» se contestaría de memoria.
    test('un saludo delante no cuela el encargo', () {
      expect(
        VoiceRouting.needsClaude('Hola, mira el historial de git'),
        isTrue,
      );
      expect(
        VoiceRouting.needsClaude('Gracias, ahora corre los tests'),
        isTrue,
      );
    });

    // Y el relleno delante tampoco: «bueno» o «no» no convierten en charla lo
    // que viene detrás.
    test('una muletilla delante no cuela el encargo', () {
      expect(VoiceRouting.needsClaude('Bueno, borra la rama'), isTrue);
      expect(VoiceRouting.needsClaude('No, corre los tests'), isTrue);
      expect(VoiceRouting.needsClaude('Nada, ¿qué hora es?'), isTrue);
      // Y el agujero de antes: empezar por cortesía bastaba si cabía en el tope.
      expect(VoiceRouting.needsClaude('Hola, ¿qué hora es?'), isTrue);
    });

    test('la puntuación y las mayúsculas no cambian la decisión', () {
      expect(VoiceRouting.needsClaude('¡¡GRACIAS!!'), isFalse);
      expect(VoiceRouting.needsClaude('¿¿Qué HORA es??'), isTrue);
    });
  });

  test('la corrección lleva la respuesta entera y no regaña', () {
    final texto = VoiceRouting.correction('Son las cuatro y veinte.');
    expect(texto, contains('Son las cuatro y veinte.'));
    expect(texto, contains('sin disculparte'));
  });
}
