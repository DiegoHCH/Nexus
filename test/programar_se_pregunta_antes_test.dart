import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/domain/usecases/a_donde_va_lo_que_se_escribe.dart';
import 'package:nexus/features/programadas/domain/entities/encargo_programado.dart';
import 'package:nexus/features/programadas/domain/usecases/como_se_lee_la_cita.dart';

/// **Una frase que pide repetir algo se propone, no se programa.**
///
/// 🔴 La decisión de producto que sostiene todo esto: equivocarse al reconocer
/// una programación cuesta una pregunta, no un mes de ejecuciones que nadie
/// mandó. Y el sitio en la precedencia es la otra mitad: va **última**, así que
/// solo puede interceptar lo que iba a acabar en Claude como un encargo suelto.
void main() {
  ADondeVa a(String frase, {bool hayAdjuntos = false}) =>
      ADondeVaLoQueSeEscribe.de(
        frase,
        esElParte: false,
        hayAdjuntos: hayAdjuntos,
      );

  group('la precedencia', () {
    test('la frase que lo pidió acaba en una propuesta', () {
      final donde = a('actualiza el documento de lunes a viernes a las 5pm');

      expect(donde, isA<AProgramar>());
      final entendido = (donde as AProgramar).loQueSeEntendio;
      expect(entendido.dias, EncargoProgramado.laborables);
      expect(entendido.hora, 17);
      expect(entendido.tarea, 'actualiza el documento');
    });

    // 🔴 **Lo que protege ir el último, y la regla que hizo falta además.**
    // Esta frase trae día y hora y no pide repetir nada. `LoQueSePreguntaDeLaAgenda`
    // **no** la reconoce —su lista es cerrada a propósito: solo las formas que
    // se escriben para preguntar eso y nada más— así que hoy va a Claude, que
    // sabe contestarla. Escribiendo esta prueba salió que se la comía la
    // propuesta, y de ahí la regla de que una pregunta no es una tarea.
    test('una pregunta con día y hora sigue yendo a Claude', () {
      expect(a('¿qué reuniones tengo el martes a las 5?'), isA<AClaude>());
    });

    // Y la otra cara: preguntado por cortesía sí es una petición.
    test('pero pedirlo en forma de pregunta sí se propone', () {
      expect(
        a('¿puedes actualizar el documento todos los días a las 5pm?'),
        isA<AProgramar>(),
      );
    });

    test('un comando de barra sigue mandando', () {
      expect(a('/parte'), isA<AlParte>());
    });

    test('y con adjuntos va a Claude, como todo lo demás', () {
      expect(
        a('actualiza el documento todos los días a las 5pm', hayAdjuntos: true),
        isA<AClaude>(),
      );
    });

    test('lo que no pide repetir nada sigue yendo a Claude', () {
      expect(a('actualiza el documento'), isA<AClaude>());
      expect(a('revisa el informe de las 5'), isA<AClaude>());
    });
  });

  // Lo que se enseña antes de decir que sí. Es lo único que deja comprobar de
  // un vistazo que se entendió: «de lunes a viernes a las 5» y «el viernes a
  // las 5» se leen casi igual, y sus citas no se parecen en nada.
  group('cómo se lee la cita', () {
    const nombres = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

    String ritmo(Set<int> dias, {int hora = 17, int minuto = 0}) =>
        ComoSeLeeLaCita.elRitmo(
          dias,
          hora: hora,
          minuto: minuto,
          nombres: nombres,
          todosLosDias: 'todos los días',
        );

    test('un rango seguido se dice como rango', () {
      expect(ritmo(EncargoProgramado.laborables), 'lun–vie · 17:00');
    });

    test('los sueltos se enumeran', () {
      expect(ritmo({DateTime.tuesday, DateTime.thursday}), 'mar, jue · 17:00');
    });

    test('la semana entera se dice con su nombre', () {
      expect(ritmo(EncargoProgramado.todosLosDias), 'todos los días · 17:00');
    });

    test('uno solo, tal cual', () {
      expect(ritmo({DateTime.friday}, minuto: 30), 'vie · 17:30');
    });

    // Siempre en 24 horas: un «5:00» en una lista de tareas que corren solas se
    // lee mal una vez, y una vez ya es una de más.
    test('la hora va en 24, con sus ceros', () {
      expect(ritmo({DateTime.monday}, hora: 9, minuto: 5), 'lun · 09:05');
    });

    test('y la próxima cita dice qué día', () {
      expect(
        ComoSeLeeLaCita.laProxima(DateTime(2026, 9, 16, 17), nombres: nombres),
        'mié 17:00',
      );
    });
  });
}
