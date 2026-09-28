import 'package:flutter/foundation.dart';

/// Lo que costó un turno: cuántos tokens y cuánto tardó.
///
/// Van juntos porque se leen juntos —«dos millones en cuatro minutos» dice algo
/// que ninguno de los dos dice solo— y porque llegan juntos, en el mismo evento
/// de fin de turno.
///
/// Vivía en `chat_message.dart`, en presentation, y se bajó aquí cuando hizo
/// falta sumarlo: la suma de la conversación es de dominio, y el dominio no
/// puede nombrar nada de presentation. `chat_message.dart` lo reexporta.
@immutable
class LoQueCostoElTurno {
  const LoQueCostoElTurno({this.tokens, this.duracion});

  /// Los del turno entero, no solo los de la respuesta: es lo que se pagó por
  /// contestar, que es la pregunta que uno se hace mirando esto.
  final int? tokens;

  final Duration? duracion;

  bool get hayAlgoQueDecir => tokens != null || duracion != null;

  Map<String, dynamic> toJson() => {
    if (tokens != null) 'tokens': tokens,
    if (duracion != null) 'ms': duracion!.inMilliseconds,
  };

  static LoQueCostoElTurno? fromJson(Object? crudo) {
    if (crudo is! Map<String, dynamic>) return null;
    final tokens = (crudo['tokens'] as num?)?.toInt();
    final ms = (crudo['ms'] as num?)?.toInt();
    if (tokens == null && ms == null) return null;
    return LoQueCostoElTurno(
      tokens: tokens,
      duracion: ms == null ? null : Duration(milliseconds: ms),
    );
  }
}

/// Lo que lleva gastado una conversación entera: la suma de sus turnos.
///
/// Pedido así: «¿hay algo en la app donde me diga la cantidad de tokens
/// gastados en una conversación y el tiempo invertido?». Cada respuesta ya
/// decía lo suyo, las esquinas dicen el contexto y el cupo de la semana, y
/// Estadísticas dice lo de la cuenta; lo que no decía nadie era **esta**.
///
/// 🔴 **El tiempo es lo que Claude pasó trabajando, no el que lleva abierta.**
/// Es la suma de la duración de cada turno —el `duration_ms` con que el CLI
/// cierra cada uno—, no la distancia entre el primer mensaje y el último. La
/// de reloj mide sobre todo **lo que tú tardaste**: una conversación que se
/// empieza el lunes y se retoma el jueves saldría con tres días «invertidos»,
/// y lo mismo cualquiera que se deja abierta mientras comes. Lo que se paga
/// —y lo que va al lado de los tokens, que también son solo de Claude— es el
/// rato que estuvo trabajando. Y es lo que ya dice cada turno al pie: sumadas,
/// las etiquetas de la conversación dan exactamente esto.
///
/// 🔴 **Los tokens se suman tal cual, aunque se repitan.** Cada turno cuenta
/// todo lo que leyó, y eso incluye el contexto que arrastra: sumarlos cuenta
/// el mismo contexto una vez por turno. No es un error, es lo que se gastó —
/// cada turno lo volvió a leer—, y es la misma cifra que ya enseña cada turno.
///
/// Los turnos **sin coste** —los de un registro de antes de que se apuntara,
/// los avisos de la app, los tuyos— no suman nada. Por eso esto es «al menos»
/// en una conversación vieja retomada, y por eso una sin ningún turno con
/// coste no tiene total: `null`, no cero. «0 tokens» diría que no costó nada,
/// y lo que pasa es que no consta.
@immutable
class LoQueCostoLaConversacion {
  const LoQueCostoLaConversacion({this.tokens, this.duracion});

  /// La suma de los tokens de los turnos que los apuntaron, o `null` si
  /// ninguno lo hizo.
  final int? tokens;

  /// La suma de lo que tardó cada turno que lo apuntó, o `null` si ninguno.
  final Duration? duracion;

  /// Suma [turnos] —el coste de cada mensaje, `null` en los que no lo
  /// llevan—. `null` si no hay nada que sumar.
  ///
  /// Cada mitad por su lado: un turno que apuntó los tokens y no el tiempo
  /// suma a los tokens y nada más, en vez de tirar el turno entero.
  static LoQueCostoLaConversacion? deLosTurnos(
    Iterable<LoQueCostoElTurno?> turnos,
  ) {
    int? tokens;
    Duration? duracion;
    for (final turno in turnos) {
      if (turno == null) continue;
      if (turno.tokens case final cuantos?) tokens = (tokens ?? 0) + cuantos;
      if (turno.duracion case final cuanto?) {
        duracion = (duracion ?? Duration.zero) + cuanto;
      }
    }
    if (tokens == null && duracion == null) return null;
    return LoQueCostoLaConversacion(tokens: tokens, duracion: duracion);
  }

  /// Lo mismo que [LoQueCostoElTurno.toJson], con las mismas claves: es la
  /// misma forma de decir tokens y tiempo, y leerla con dos nombres distintos
  /// según dónde se guardó sería pedir que un día no coincidieran.
  Map<String, dynamic> toJson() => {
    if (tokens != null) 'tokens': tokens,
    if (duracion != null) 'ms': duracion!.inMilliseconds,
  };

  static LoQueCostoLaConversacion? fromJson(Object? crudo) {
    final comoTurno = LoQueCostoElTurno.fromJson(crudo);
    if (comoTurno == null) return null;
    return LoQueCostoLaConversacion(
      tokens: comoTurno.tokens,
      duracion: comoTurno.duracion,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LoQueCostoLaConversacion &&
      other.tokens == tokens &&
      other.duracion == duracion;

  @override
  int get hashCode => Object.hash(tokens, duracion);
}
