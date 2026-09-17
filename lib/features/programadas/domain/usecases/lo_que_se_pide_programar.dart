import 'package:nexus/features/programadas/domain/entities/encargo_programado.dart';

/// Una programación que se ha entendido en una frase, **todavía sin crear**.
///
/// Es un candidato y no un hecho: quien lo reciba tiene que preguntar antes de
/// guardar nada. Ver [LoQueSePideProgramar].
class LoQueSeEntendio {
  const LoQueSeEntendio({
    required this.dias,
    required this.hora,
    required this.minuto,
    required this.tarea,
  });

  final Set<int> dias;
  final int hora;
  final int minuto;

  /// La frase sin la parte que decía cuándo. Es lo que se le pediría a Claude.
  final String tarea;
}

/// Si lo que se acaba de escribir estaba pidiendo repetir algo, y con qué ritmo.
///
/// 🔴 **Devuelve un candidato y no crea nada, y esa es la decisión de diseño.**
/// Se eligió preguntar antes de programar por lo que pasó el mismo día que se
/// escribió esto: el enrutador de carpetas buscaba el nombre de una carpeta en
/// cualquier parte de la frase, y «tambien puede ver el resumen **general**» se
/// llevó un encargo entero a la carpeta `General` —y de camino le quitó la
/// palabra—. Aquí el riesgo es idéntico y el daño mayor: «revisa el informe de
/// las 5» no es una programación, y confundirlo deja una tarea repetida que
/// nadie pidió, escribiendo archivos a diario.
///
/// Así que esto solo **propone**. Lo que se enseña al proponer es la próxima
/// cita resuelta —«mañana martes a las 17:00»—, que es lo único que deja
/// comprobar de un vistazo que se entendió: «de lunes a viernes a las 5» y «el
/// viernes a las 5» se leen parecido; sus próximas citas no.
///
/// Lo que no entiende se dice, no se adivina: cada dos semanas, el último
/// viernes de mes, «cuando termine el sprint». Entender mal *cuándo* es
/// ejecutar un día que no era.
abstract final class LoQueSePideProgramar {
  static LoQueSeEntendio? deLaFrase(String frase) {
    final plano = _aplanar(frase);
    final cuando = _laHora(plano);
    if (cuando == null) return null;
    final dias = _losDias(plano);
    if (dias == null) return null;

    final tarea = _sinElCuando(frase, cuando.desde, cuando.hasta);
    // Sin tarea no hay nada que programar: «todos los días a las cinco» a secas
    // es una hora, no un encargo.
    if (tarea.isEmpty) return null;

    // 🔴 **Una pregunta no es una tarea que repetir.** «¿Qué reuniones tengo el
    // martes a las 5?» trae día y hora y no pide repetir nada — hoy va a
    // Claude, que sabe contestarla, y sin esta regla se convertía en una
    // propuesta de programar «¿qué reuniones tengo?» cada martes.
    //
    // Se mira el **pronombre** y no el signo: «¿puedes actualizar el documento
    // todos los días a las 5?» también es una pregunta por la forma, y es una
    // petición de las buenas.
    if (_empiezaPreguntando.hasMatch(_aplanar(tarea))) return null;

    return LoQueSeEntendio(
      dias: dias,
      hora: cuando.hora,
      minuto: cuando.minuto,
      tarea: tarea,
    );
  }

  /// Los días, con las formas que se dicen de verdad.
  ///
  /// **Sin días no hay programación**, y a propósito: «actualiza el documento a
  /// las 5» es un encargo para hoy a las cinco, no una cita semanal. Pedir que
  /// el ritmo esté dicho es lo que separa una cosa de la otra sin adivinar.
  static Set<int>? _losDias(String plano) {
    if (_diario.hasMatch(plano)) return EncargoProgramado.todosLosDias;
    if (_entreSemana.hasMatch(plano)) return EncargoProgramado.laborables;
    if (_finDeSemana.hasMatch(plano)) {
      return const {DateTime.saturday, DateTime.sunday};
    }

    // «de lunes a viernes», «de martes a jueves».
    if (_deTalATal.firstMatch(plano) case final rango?) {
      final desde = _nombreDeDia[rango.group(1)];
      final hasta = _nombreDeDia[rango.group(2)];
      if (desde != null && hasta != null) return _rango(desde, hasta);
    }

    // «los martes», «cada jueves», «los martes y jueves».
    final sueltos = <int>{
      for (final entrada in _nombreDeDia.entries)
        if (RegExp('(?<![a-z])${entrada.key}(es)?(?![a-z])').hasMatch(plano))
          entrada.value,
    };
    return sueltos.isEmpty ? null : sueltos;
  }

  /// Los días de [desde] a [hasta], dando la vuelta a la semana si hace falta.
  static Set<int> _rango(int desde, int hasta) {
    final dias = <int>{};
    var dia = desde;
    for (var vueltas = 0; vueltas < 7; vueltas++) {
      dias.add(dia);
      if (dia == hasta) break;
      dia = dia % 7 + 1;
    }
    return dias;
  }

  /// La hora, y **el caso ambiguo resuelto a la vista**.
  ///
  /// «A las 5» no dice si son las cinco de la mañana o las de la tarde. No se
  /// pregunta por ello: se resuelve con la costumbre —de 1 a 7 es por la tarde,
  /// de 8 a 12 por la mañana— y **se enseña resuelto** en la confirmación. Un
  /// «la próxima: mañana a las 17:00» delante se corrige en dos segundos; una
  /// pregunta más antes de crear nada, no.
  static ({int hora, int minuto, int desde, int hasta})? _laHora(String plano) {
    for (final match in _horaEscrita.allMatches(plano)) {
      final prefijo = match.group(1);
      final minutos = match.group(3);
      final sufijo = match.group(4);
      final franja = match.group(5);

      // 🔴 **Un número suelto no es una hora.** Sin esto, «todos los días
      // revisa los 3 primeros PRs» se programaba a las 15:00 y la tarea
      // llegaba como «revisa los primeros PRs», sin el número. Es exactamente
      // el fallo que el enrutador de carpetas tuvo el mismo día con la palabra
      // «general», y se arregla igual: la hora cuenta cuando **apunta** —la
      // introduce un «a las», trae minutos, o lleva am/pm o su franja— y no por
      // el mero hecho de ser un número.
      if (prefijo == null &&
          minutos == null &&
          sufijo == null &&
          franja == null) {
        continue;
      }

      var hora = int.parse(match.group(2)!);
      final minuto = int.tryParse(minutos ?? '') ?? 0;
      if (hora > 23 || minuto > 59) continue;

      final esTarde = sufijo == 'pm' || franja == 'tarde' || franja == 'noche';
      final esManana =
          sufijo == 'am' || franja == 'manana' || franja == 'madrugada';

      if (hora <= 12) {
        if (esTarde) {
          hora = hora == 12 ? 12 : hora + 12;
        } else if (esManana) {
          hora = hora == 12 ? 0 : hora;
        } else if (hora >= 1 && hora <= 7) {
          // La costumbre: nadie programa nada a las cinco de la mañana.
          hora += 12;
        }
      }
      return (hora: hora, minuto: minuto, desde: match.start, hasta: match.end);
    }
    return null;
  }

  /// La frase sin lo que decía cuándo, que es lo que se le pide a Claude.
  ///
  /// Se recorta sobre el texto original y no sobre el aplanado: lo que queda se
  /// le manda al modelo, y mandarle la frase sin tildes ya sería empezar a
  /// romperla.
  static String _sinElCuando(String frase, int desde, int hasta) {
    // La hora se quita **por su tramo** y no volviendo a buscarla: la que vale
    // puede no ser la primera que aparece —«revisa los 3 PRs todos los días a
    // las 5pm»— y buscarla otra vez se llevaría el número de la tarea.
    var queda = frase.substring(0, desde) + frase.substring(hasta);
    for (final patron in [_diario, _entreSemana, _finDeSemana, _deTalATal]) {
      queda = _quitar(queda, patron);
    }
    queda = _quitar(queda, _losDiasSueltos);
    return queda
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s+([,.;:])'), r'$1')
        .replaceAll(RegExp(r'^[\s,.;:]+|[\s,.;:]+$'), '')
        .trim();
  }

  /// Recorta sobre el original usando las posiciones del aplanado, que mide
  /// igual porque [_aplanar] baja los acentos uno a uno.
  static String _quitar(String frase, RegExp patron) {
    final donde = patron.firstMatch(_aplanar(frase));
    if (donde == null) return frase;
    return frase.substring(0, donde.start) + frase.substring(donde.end);
  }

  static final _diario = RegExp(
    r'(?<![a-z])(todos los dias|cada dia|a diario|diariamente|every day|daily)'
    r'(?![a-z])',
  );
  static final _entreSemana = RegExp(
    r'(?<![a-z])(entre semana|los dias laborables|weekdays)(?![a-z])',
  );
  static final _finDeSemana = RegExp(
    r'(?<![a-z])((los |el )?fines? de semana|weekends?)(?![a-z])',
  );
  static final _deTalATal = RegExp(
    r'(?<![a-z])de (lunes|martes|miercoles|jueves|viernes|sabado|domingo) '
    r'a (lunes|martes|miercoles|jueves|viernes|sabado|domingo)(?![a-z])',
  );
  static final _losDiasSueltos = RegExp(
    r'(?<![a-z])((los|cada|el) )?'
    r'(lunes|martes|miercoles|jueves|viernes|sabados?|domingos?)'
    r'( y (lunes|martes|miercoles|jueves|viernes|sabados?|domingos?))*(?![a-z])',
  );

  /// `a las 5`, `a las 5:30pm`, `a las 17:00`, `a las 9 de la mañana`.
  /// `a las 5`, `a las 5:30pm`, `17:00`, `5pm`, `9 de la mañana`.
  ///
  /// Las cuatro señales van capturadas —el «a las», los minutos, el am/pm y la
  /// franja— porque **hace falta al menos una**: ver [_laHora].
  static final _horaEscrita = RegExp(
    r'(?<![0-9])(a las |a la |at )?'
    r'([0-9]{1,2})(?::([0-9]{2}))?\s*'
    r'(am|pm)?'
    r'(?:\s*(?:de la|por la)\s*(manana|tarde|noche|madrugada))?'
    r'(?![0-9])',
  );

  /// Los pronombres con los que empieza una pregunta de verdad.
  static final _empiezaPreguntando = RegExp(
    r'^[¿\s]*(que|cual|cuales|cuando|quien|quienes|cuanto|cuantos|cuanta|'
    r'cuantas|donde|como|por que|what|which|when|who|how many|how much|where)'
    r'(?![a-z])',
  );

  static const _nombreDeDia = {
    'lunes': DateTime.monday,
    'martes': DateTime.tuesday,
    'miercoles': DateTime.wednesday,
    'jueves': DateTime.thursday,
    'viernes': DateTime.friday,
    'sabado': DateTime.saturday,
    'domingo': DateTime.sunday,
  };

  /// Igual de largo que el original, para que los tramos encontrados sirvan
  /// para cortar. La misma regla que usa el enrutador de carpetas.
  static String _aplanar(String texto) {
    const acentos = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    var plano = texto.toLowerCase();
    acentos.forEach((con, sin) => plano = plano.replaceAll(con, sin));
    return plano;
  }
}
