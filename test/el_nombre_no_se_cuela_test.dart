import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/domain/usecases/lo_dicho_sin_su_nombre.dart';
import 'package:nexus/features/oido/domain/usecases/como_se_le_llama.dart';

/// 🔴 **El nombre se colaba en el encargo** (reportado el 28 sep). Se dijo
/// «Ciel, necesito que actualices el documento de tareas asignadas de crédito
/// colateral con Jira»; el oído del Mac la despertó bien, pero en el chat quedó
/// como tu mensaje «de él Necesito que actualice…»: la transcripción del
/// servicio de voz, que no conoce el nombre, lo escribió como le sonó.
///
/// El nombre es para llamarla, no parte de lo que le pides. Estas pruebas fijan
/// qué se le quita delante a la frase y, sobre todo, qué **no**.
void main() {
  String sin(String dicho, {String? agente = 'Ciel'}) =>
      ComoSeLeLlama.sinElNombreDelante(dicho, agente: agente);

  test('lo del 28 sep: «de él Necesito…» se queda en lo que pediste', () {
    expect(
      sin(
        'de él Necesito que actualice el documento de tareas asignadas de '
        'crédito colateral con Jira.',
      ),
      'Necesito que actualice el documento de tareas asignadas de crédito '
      'colateral con Jira.',
    );
  });

  group('lo que suena a su nombre, delante, se quita', () {
    for (final (dicho, queda) in [
      ('Ciel, ¿qué reuniones tengo?', '¿qué reuniones tengo?'),
      ('Siel necesito que mires el CI', 'necesito que mires el CI'),
      ('ciel. Mira el PR', 'Mira el PR'),
      // Partido en dos, con el corte detrás.
      ('Si el, mira el PR', 'mira el PR'),
      ('Sí, él Mira el PR', 'Mira el PR'),
      ('cie l, mira el PR', 'mira el PR'),
      ('De él. Revisa el build', 'Revisa el build'),
      // Y «nexus», que vale siempre.
      ('Nexus, abre el diff', 'abre el diff'),
      // El «¿» que abría delante del nombre sigue abriendo la pregunta.
      ('¿Ciel, qué hora es?', '¿qué hora es?'),
    ]) {
      test('«$dicho» → «$queda»', () => expect(sin(dicho), queda));
    }
  });

  group('lo que no es el nombre, o no está delante, se deja', () {
    for (final dicho in [
      // Empieza como el nombre partido, pero sin corte es la frase entera.
      'si el build falla, avísame',
      'Sí, él lo hizo ayer',
      'de él no sé nada',
      // A una letra de menos ya no es el nombre partido.
      '¿Y él? Revisa el build',
      // 🔴 «cielo» es una palabra de verdad a una letra de un nombre de
      // cuatro: el oído del Mac tampoco la toma por el nombre.
      'Cielo, qué nublado está',
      'cielo despejado mañana',
      // En medio de la frase, el nombre es contenido.
      'pregúntale a Ciel qué opina',
      'oye Ciel, mira el PR',
      // Solo el nombre: quitarlo todo dejaría un turno vacío.
      'Ciel',
      'de él.',
      'Necesito que actualices el documento',
    ]) {
      test('«$dicho»', () => expect(sin(dicho), dicho));
    }
  });

  // A una letra de un nombre de cinco hay palabras de verdad: «está» de
  // «Hestia». Esas se quitan solo si detrás hay un corte.
  test('a una letra, solo con corte detrás', () {
    expect(sin('Estia, mira el PR', agente: 'Hestia'), 'mira el PR');
    expect(sin('Está bien, gracias', agente: 'Hestia'), 'Está bien, gracias');
    expect(sin('es tía, mira el PR', agente: 'Hestia'), 'mira el PR');
  });

  test('con el nombre que le pusiste, no con uno fijo', () {
    expect(sin('Jarvis, abre el PR', agente: 'Jarvis'), 'abre el PR');
    expect(
      sin('Jarvis, abre el PR', agente: 'Ciel'),
      'Jarvis, abre el PR',
      reason: 'si se llama Ciel, «Jarvis» es lo que dijiste',
    );
    expect(
      sin('Señor Jarvis, abre el PR', agente: 'señor jarvis'),
      'abre el PR',
    );
  });

  group('a trozos, como llega la transcripción', () {
    String enTrozos(List<String> trozos, {String agente = 'Ciel'}) {
      final dicho = LoDichoSinSuNombre(agente: agente);
      final sale = StringBuffer();
      for (final t in trozos) {
        sale.write(dicho.trozo(t));
      }
      sale.write(dicho.suelta());
      return sale.toString();
    }

    test('«de» se retiene hasta saber si es el nombre', () {
      final dicho = LoDichoSinSuNombre(agente: 'Ciel');
      expect(dicho.trozo('de'), '', reason: 'puede ser «de él»');
      expect(dicho.trozo(' él'), '', reason: 'falta ver si hay corte');
      expect(dicho.trozo(' Necesito que'), 'Necesito que');
      expect(dicho.trozo(' actualices'), ' actualices');
    });

    test('lo que no empieza por el nombre sale tal cual', () {
      final dicho = LoDichoSinSuNombre(agente: 'Ciel');
      expect(dicho.trozo('Necesito que'), 'Necesito que');
      expect(dicho.trozo(' mires el CI'), ' mires el CI');
    });

    test('y lo retenido sale al cerrarse la frase', () {
      expect(enTrozos(['de', ' verdad']), 'de verdad');
      expect(enTrozos(['si el', ' build falla']), 'si el build falla');
      expect(enTrozos(['Ciel']), 'Ciel', reason: 'era solo el nombre');
      expect(enTrozos(['Ciel, ']), 'Ciel, ', reason: 'y con su coma');
    });

    test('el nombre partido entre dos trozos', () {
      expect(enTrozos(['Cie', 'l, mira', ' el PR']), 'mira el PR');
      expect(enTrozos(['de ', 'él ', 'Necesito que…']), 'Necesito que…');
    });
  });
}
