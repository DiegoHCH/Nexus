import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/programadas/domain/entities/encargo_programado.dart';
import 'package:nexus/features/programadas/domain/usecases/lo_que_se_pide_programar.dart';

/// **Reconocer que alguien está pidiendo repetir algo.**
///
/// 🔴 **La mitad importante de estas pruebas es la de abajo: lo que NO debe
/// reconocer.** El mismo día que se escribió esto, el enrutador de carpetas
/// buscaba el nombre de una carpeta en cualquier parte de la frase, y «también
/// puede ver el resumen **general**» se llevó un encargo entero a la carpeta
/// `General`. Aquí el riesgo es el mismo y el daño mayor: confundir «revisa el
/// informe de las 5» con una programación deja una tarea repetida que nadie
/// pidió, escribiendo archivos a diario.
///
/// Por eso esto solo **propone**, nunca crea. Y por eso hacen falta dos cosas
/// dichas —el ritmo y la hora—: con una sola, cualquier encargo con un número
/// dentro sería una cita semanal.
void main() {
  LoQueSeEntendio? de(String frase) => LoQueSePideProgramar.deLaFrase(frase);

  group('lo que sí se entiende', () {
    // La frase con la que empezó todo.
    test('la que lo pidió', () {
      final r = de('actualiza el documento de lunes a viernes a las 5pm')!;

      expect(r.dias, EncargoProgramado.laborables);
      expect(r.hora, 17);
      expect(r.minuto, 0);
      expect(r.tarea, 'actualiza el documento');
    });

    test('todos los días', () {
      final r = de('mándame el parte todos los días a las 9 de la mañana')!;

      expect(r.dias, EncargoProgramado.todosLosDias);
      expect(r.hora, 9);
      expect(r.tarea, 'mándame el parte');
    });

    test('un día suelto, con minutos y en 24h', () {
      final r = de('los martes a las 17:30 revisa los PRs')!;

      expect(r.dias, {DateTime.tuesday});
      expect(r.hora, 17);
      expect(r.minuto, 30);
      expect(r.tarea, 'revisa los PRs');
    });

    test('entre semana', () {
      expect(
        de('entre semana a las 8 revisa el correo')!.dias,
        EncargoProgramado.laborables,
      );
    });

    test('los fines de semana', () {
      expect(de('los fines de semana a las 10 haz el resumen')!.dias, {
        DateTime.saturday,
        DateTime.sunday,
      });
    });

    // 🔴 Lo que se le manda a Claude se recorta del texto **original**: sin
    // tildes ya iría medio roto.
    test('la tarea conserva sus tildes', () {
      expect(
        de('cada día a las 6 revisa la configuración del móvil')!.tarea,
        'revisa la configuración del móvil',
      );
    });
  });

  // «A las 5» no dice de qué mitad del día. No se pregunta: se resuelve con la
  // costumbre y se enseña resuelto en la confirmación, que es donde se corrige
  // en dos segundos.
  group('la hora a medias', () {
    test('de 1 a 7 se entiende por la tarde', () {
      expect(de('todos los días a las 5 haz algo')!.hora, 17);
      expect(de('todos los días a las 7 haz algo')!.hora, 19);
    });

    test('de 8 a 12, por la mañana', () {
      expect(de('todos los días a las 8 haz algo')!.hora, 8);
      expect(de('todos los días a las 11 haz algo')!.hora, 11);
    });

    test('pero si lo dice, manda lo que dice', () {
      expect(de('todos los días a las 5 de la mañana haz algo')!.hora, 5);
      expect(de('todos los días a las 11pm haz algo')!.hora, 23);
    });
  });

  group('lo que no debe reconocer', () {
    // 🔴 **La que protege todo lo demás.** Una hora sin ritmo es un encargo
    // para hoy, no una cita semanal.
    test('una hora sola no es una programación', () {
      expect(de('revisa el informe de las 5'), isNull);
      expect(de('actualiza el documento a las 17:00'), isNull);
    });

    test('un ritmo sin hora tampoco', () {
      expect(de('todos los días reviso el correo'), isNull);
      expect(de('de lunes a viernes trabajo en esto'), isNull);
    });

    // 🔴 **El fallo que me comí escribiendo esto.** La primera versión cogía
    // cualquier número de 1 o 2 cifras como hora: «revisa los 3 primeros PRs»
    // se programaba a las 15:00 **y la tarea llegaba sin el número**. Es
    // calcado al de la carpeta `General` del mismo día, y se arregla igual: la
    // hora cuenta cuando apunta —un «a las», minutos, o am/pm—, no por ser un
    // número.
    test('un número dentro de la tarea no es una hora', () {
      expect(de('todos los días revisa los 3 primeros PRs'), isNull);
      expect(de('cada día mira los 2 informes pendientes'), isNull);
      expect(de('de lunes a viernes cierra los 10 tickets viejos'), isNull);
    });

    // Y la otra mitad: con una hora de verdad más adelante, gana esa y el
    // número de la tarea se queda donde estaba.
    test('y con una hora de verdad detrás, el número se respeta', () {
      final r = de('revisa los 3 primeros PRs todos los días a las 5pm')!;

      expect(r.hora, 17);
      expect(
        r.tarea,
        'revisa los 3 primeros PRs',
        reason: 'mirar solo la primera cifra se comería el 3',
      );
    });

    // 🔴 **Una pregunta no es una tarea que repetir.** Salió escribiendo la
    // prueba de la precedencia: «¿qué reuniones tengo el martes a las 5?» trae
    // día y hora, no pide repetir nada, y hoy va a Claude — que sabe
    // contestarla. Se mira el pronombre y no el signo, porque preguntar por
    // cortesía sí es pedir.
    test('una pregunta de verdad no se programa', () {
      expect(de('¿qué reuniones tengo el martes a las 5?'), isNull);
      expect(de('cuándo toca el informe los lunes a las 9'), isNull);
    });

    test('pero pedirlo preguntando sí', () {
      final r = de('¿puedes actualizar el documento todos los días a las 5pm?');

      expect(r, isNotNull);
      expect(r!.hora, 17);
    });

    test('ni una frase que no pide nada de esto', () {
      expect(de('arregla el login'), isNull);
      expect(de(''), isNull);
    });

    // Sin encargo no hay nada que programar: es una hora, no una tarea.
    test('el cuándo sin el qué no es una tarea', () {
      expect(de('todos los días a las 5'), isNull);
      expect(de('de lunes a viernes a las 17:00'), isNull);
    });
  });
}
