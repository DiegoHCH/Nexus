import 'package:flutter/painting.dart';
import 'package:nexus/core/design_system/orbe_preference.dart';

/// El personaje del Mac, dicho por el canal: el campo `character` del saludo y
/// el evento del mismo nombre. Ver `docs/PROTOCOL.md`, 4.9.
///
/// 🔴 **Con nombres propios del protocolo y no los del enum** —`suit` y no
/// `traje`—: el enum es de la app y se puede renombrar cualquier día; lo que
/// viaja lo leen teléfonos de otra versión, y un nombre que cambia en un lado
/// y no en el otro es un ajuste que se pierde sin que nadie se entere.
abstract final class ElPersonajePorElCanal {
  static const _luces = {
    LuzDelPersonaje.traje: 'suit',
    LuzDelPersonaje.aura: 'aura',
    LuzDelPersonaje.horizonte: 'horizon',
  };

  static const _ojos = {
    OjosDelPersonaje.comoEstan: 'asDrawn',
    OjosDelPersonaje.delAcento: 'accent',
    OjosDelPersonaje.deColor: 'color',
  };

  /// Lo que se manda del [estilo] del Mac. Solo lo del personaje: la forma y el
  /// plasma no viajan, porque el orbe del teléfono es el de fábrica.
  static Map<String, Object?> deEstilo(OrbeEstilo estilo) => {
    'shown': estilo.personaje,
    'light': _luces[estilo.luz],
    'eyes': _ojos[estilo.ojos],
    if (estilo.ojos == OjosDelPersonaje.deColor)
      'eyeColor': estilo.colorDeLosOjos.toARGB32(),
  };

  /// [actual] con lo que dijo el Mac en [datos]. Sin [datos] —un Mac de antes
  /// del personaje— es el orbe. Lo que no se entiende sale de fábrica.
  static OrbeEstilo aplicar(OrbeEstilo actual, Map<String, Object?>? datos) {
    if (datos == null) return actual.copyWith(personaje: false);
    T leer<T>(Map<T, String> nombres, Object? valor, T porDefecto) =>
        nombres.entries.where((e) => e.value == valor).firstOrNull?.key ??
        porDefecto;
    return actual.copyWith(
      personaje: datos['shown'] == true,
      luz: leer(_luces, datos['light'], LuzDelPersonaje.traje),
      ojos: leer(_ojos, datos['eyes'], OjosDelPersonaje.comoEstan),
      colorDeLosOjos: switch (datos['eyeColor']) {
        final int argb => Color(argb),
        _ => null,
      },
    );
  }
}
