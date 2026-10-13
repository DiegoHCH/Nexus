import 'package:nexus/features/agenda/domain/usecases/la_jornada.dart';
import 'package:nexus/features/agenda/domain/usecases/lo_que_se_contesta_de_la_agenda.dart';
import 'package:nexus/features/lo_que_te_espera/domain/entities/el_material_del_dia.dart';

/// Lo que te espera hoy: qué se cuenta, cuándo se cuenta solo y cómo se pide.
///
/// Es el parte **hacia delante**. El de siempre —`ElParteDeAyer`— cuenta lo que
/// hiciste para mandarlo a Slack; este cuenta lo que viene, para empezar el día
/// sabiéndolo: las reuniones que quedan, los PR que esperan tu revisión, las
/// programadas, y cuánto cupo llevas.
///
/// Reglas y no fontanería, como sus hermanos de la agenda: lo que se rompe
/// aquí no lanza nada — dice otra cosa, o se calla cuando tocaba hablar.
abstract final class LoQueTeEsperaHoy {
  /// Si toca contarlo al llamarla.
  ///
  /// **Una vez por día de jornada.** El primer llamado contesta con el día en
  /// vez de con «¿Sí?»; los siguientes, no: oírlo cada vez que la llamas es la
  /// forma más rápida de que dejes de llamarla. Fuera de jornada —fin de
  /// semana, pasadas las seis— no hay día por delante que contar.
  static bool tocaAlLlamarla({
    required DateTime ahora,
    required DateTime? dichoEl,
  }) {
    if (!LaJornada.dentro(ahora)) return false;
    if (dichoEl == null) return true;
    return dichoEl.year != ahora.year ||
        dichoEl.month != ahora.month ||
        dichoEl.day != ahora.day;
  }

  /// Lo que se dice, en frases cortas: se oye, no se lee.
  ///
  /// El orden es el de lo que te mueve antes: la próxima reunión, lo que
  /// espera de ti, lo que no corrió y lo que va a correr, y al final el cupo.
  /// Lo que no se sabe no se nombra —ver [ElMaterialDelDia]—, y lo que se sabe
  /// vacío solo se dice de las reuniones: «no te quedan reuniones» es una
  /// noticia; «nadie te pidió revisión» es relleno.
  static String comoSeDice(
    ElMaterialDelDia material, {
    required DateTime ahora,
    required LasFrasesDelDia frases,
  }) {
    final dicho = <String>[];

    if (material.reuniones case final reuniones?) {
      final quedan = [
        for (final reunion in reuniones)
          if (reunion.esUnaReunion && !reunion.comienza.isBefore(ahora))
            reunion,
      ]..sort((a, b) => a.comienza.compareTo(b.comienza));
      dicho.add(
        quedan.isEmpty
            ? frases.sinReuniones
            : frases.reuniones(
                quedan.length,
                _paraDecir(quedan.first.titulo),
                LoQueSeContestaDeLaAgenda.laHora(quedan.first.comienza),
              ),
      );
    }

    if (material.prs case final prs? when prs.isNotEmpty) {
      dicho.add(frases.prs(prs.length, _paraDecir(prs.first.titulo)));
    }

    if (material.perdidas.isNotEmpty) {
      dicho.add(
        frases.perdidas(material.perdidas.length, material.perdidas.first),
      );
    }

    if (material.proxima case final proxima?
        when _esHoy(proxima.cuando, ahora) && proxima.cuando.isAfter(ahora)) {
      dicho.add(
        frases.proxima(
          proxima.carpeta,
          LoQueSeContestaDeLaAgenda.laHora(proxima.cuando),
        ),
      );
    }

    if (material.cupoSemanal case final cupo?) {
      dicho.add(frases.cupo(cupo));
    }

    return dicho.isEmpty ? frases.nada : dicho.join(' ');
  }

  /// Reconoce «¿qué me espera hoy?» escrito.
  ///
  /// **Lista cerrada y frase entera**, como la agenda y el parte: buscar
  /// «hoy» dentro del texto convertiría «arregla lo de hoy» en esto, y
  /// secuestrar trabajo de verdad es peor que no reconocer una forma de
  /// preguntar. «Qué tengo hoy» no está: ya es de la agenda.
  static bool loEstanPidiendo(String frase) =>
      _comoSePide.contains(_sinAdornos(frase));

  static const _comoSePide = {
    'que me espera',
    'que me espera hoy',
    'lo que me espera hoy',
    'que me espera el dia de hoy',
    'como viene el dia',
    'como viene mi dia',
    'como viene hoy',
    'como pinta el dia',
    'como pinta hoy',
    'que hay para hoy',
    'whats ahead today',
    'what awaits me today',
    'how does my day look',
    'how is my day looking',
  };

  static String _sinAdornos(String frase) {
    const conTilde = 'áéíóúüñ';
    const sinTilde = 'aeiouun';
    var limpia = frase.trim().toLowerCase();
    for (var i = 0; i < conTilde.length; i++) {
      limpia = limpia.replaceAll(conTilde[i], sinTilde[i]);
    }
    return limpia.replaceAll(RegExp(r'[^a-z0-9 ]'), '').trim();
  }

  /// Un título tal como se va a decir.
  ///
  /// 🔴 **Sin comillas dobles**: lo que se dice al llamarla viaja dentro de
  /// unas comillas en la instrucción del modelo —«di exactamente esto:
  /// "…"»—, y un título con las suyas cortaría la frase por la mitad.
  static String _paraDecir(String titulo) => titulo.replaceAll('"', "'").trim();

  static bool _esHoy(DateTime cuando, DateTime ahora) =>
      cuando.year == ahora.year &&
      cuando.month == ahora.month &&
      cuando.day == ahora.day;
}
