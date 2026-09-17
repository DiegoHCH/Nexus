import 'package:nexus/features/programadas/domain/entities/encargo_programado.dart';

/// Qué hacer con un encargo programado en este instante.
sealed class LoQueTocaConEl {
  const LoQueTocaConEl(this.encargo);
  final EncargoProgramado encargo;
}

/// Le toca ahora: se lanza.
final class LanzarloYa extends LoQueTocaConEl {
  const LanzarloYa(super.encargo);
}

/// Le tocaba y no corrió —la app estaba cerrada—, así que **se dice y se deja
/// decidir**.
///
/// 🔴 **Ni se ejecuta solo ni se calla.** Ejecutarlo al abrir significa que un
/// encargo que escribe archivos arranca tres horas tarde sin que nadie lo
/// pidiera, y con varios perdidos arrancan todos a la vez. Callarlo es peor de
/// otra forma: una tarea que no corrió y no deja rastro es justo el fallo que
/// no se ve hasta que importa. Se enseña con las dos salidas —hacerlo ahora o
/// saltarlo— y elige quien lo programó.
final class SePaso extends LoQueTocaConEl {
  const SePaso(super.encargo, this.cuandoTocaba);

  /// El momento que se perdió. **El último**, no todos: si se perdieron el
  /// lunes, el martes y el miércoles, «actualiza el documento» sigue siendo una
  /// sola cosa por hacer. Enseñar tres avisos para una tarea que se hace una
  /// vez convierte una ausencia en una lista de tareas.
  final DateTime cuandoTocaba;
}

/// Cuándo toca lanzar un encargo programado, y qué hacer con el que se pasó.
///
/// Es hermano de `LoQueTocaAvisar`, el de la agenda, y por el mismo motivo:
/// son **reglas y no fontanería**. Lo que se rompe aquí no lanza ninguna
/// excepción — hace otra cosa, o no hace nada, y una tarea que no corre no deja
/// rastro por su cuenta.
abstract final class LoQueTocaLanzar {
  /// Cuánto se le perdona a la hora antes de considerar que se pasó.
  ///
  /// El reloj de la app mira cada 30 segundos, así que con Nexus abierto la
  /// diferencia es de segundos. Los minutos de margen son para lo otro: el Mac
  /// que estaba suspendido y despierta, o el arranque de la app justo encima de
  /// la hora. Pasado el margen ya no es «va con retraso»: es que no estabas, y
  /// eso se pregunta en vez de decidirlo por ti.
  static const margen = Duration(minutes: 5);

  /// Qué hay que hacer con cada uno, ahora mismo.
  ///
  /// [cuando] entra como parámetro y no se lee el reloj aquí dentro: es lo que
  /// permite probar las cinco de la tarde de un martes sin esperar al martes.
  static List<LoQueTocaConEl> revisar(
    List<EncargoProgramado> encargos, {
    required DateTime cuando,
  }) {
    final toca = <LoQueTocaConEl>[];
    for (final encargo in encargos) {
      if (!encargo.activo) continue;
      final momento = _ultimoMomentoDe(encargo, cuando);
      if (momento == null) continue;

      // Ya se lanzó en este turno de reloj: dos veces la misma tarea es peor
      // que ninguna, porque la segunda pisa lo que hizo la primera.
      final ultima = encargo.ultimaCorrida;
      if (ultima != null && !ultima.isBefore(momento)) continue;

      toca.add(
        cuando.difference(momento) <= margen
            ? LanzarloYa(encargo)
            : SePaso(encargo, momento),
      );
    }
    return toca;
  }

  /// El último momento en que le tocaba, mirando hacia atrás desde [cuando].
  ///
  /// `null` cuando no hay ninguno que valga: o todavía no ha llegado su primer
  /// día, o el que habría tocado es **anterior a cuando se creó** — y esa es la
  /// que evita que una tarea recién escrita a las ocho de la tarde anuncie de
  /// nacimiento que se perdió la de las cinco.
  static DateTime? _ultimoMomentoDe(
    EncargoProgramado encargo,
    DateTime cuando,
  ) {
    if (encargo.dias.isEmpty) return null;
    // Una semana hacia atrás basta: con cualquier día en la lista, el anterior
    // está como mucho a siete días.
    for (var atras = 0; atras <= 7; atras++) {
      final dia = DateTime(
        cuando.year,
        cuando.month,
        cuando.day,
      ).subtract(Duration(days: atras));
      if (!encargo.dias.contains(dia.weekday)) continue;
      final momento = DateTime(
        dia.year,
        dia.month,
        dia.day,
        encargo.hora,
        encargo.minuto,
      );
      if (momento.isAfter(cuando)) continue;
      return momento.isBefore(encargo.creado) ? null : momento;
    }
    return null;
  }

  /// Cuándo le toca la próxima vez, para poder decirlo al programarla.
  ///
  /// Se enseña porque **es la única forma de comprobar que se entendió**: «de
  /// lunes a viernes a las 5» y «el viernes a las 5» se escriben parecido y se
  /// confunden leyendo, pero «la próxima: mañana martes a las 17:00» no se
  /// confunde con nada.
  static DateTime? proxima(
    EncargoProgramado encargo, {
    required DateTime desde,
  }) {
    if (encargo.dias.isEmpty || !encargo.activo) return null;
    for (var adelante = 0; adelante <= 7; adelante++) {
      final dia = DateTime(
        desde.year,
        desde.month,
        desde.day,
      ).add(Duration(days: adelante));
      if (!encargo.dias.contains(dia.weekday)) continue;
      final momento = DateTime(
        dia.year,
        dia.month,
        dia.day,
        encargo.hora,
        encargo.minuto,
      );
      if (!momento.isAfter(desde)) continue;
      return momento;
    }
    return null;
  }
}
