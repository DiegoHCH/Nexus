import 'package:flutter/material.dart';

/// Escala tipográfica de Nexus, con **tres papeles** y una frontera entre
/// ellos que no se cruza:
///
/// - `Oxanium`, **el instrumento**: rótulos, estado, marca, títulos y
///   controles. Lo que dice qué es cada cosa y en qué está, como el panel de
///   un aparato, y los mandos con que se maneja.
/// - `Instrument Sans`, **lo que se dice**: la conversación, el subtítulo, las
///   explicaciones y ayudas ([nota]). Se lee de corrido.
/// - `Geist Mono`, **el dato**: rutas, comandos, horas, porcentajes, claves.
///   Se lee en columna.
///
/// 🔴 Hasta el 25 sep los rótulos y la marca iban en mono, y con eso el dato y
/// el rótulo eran la misma voz: «CONTEXTO» y «34 %» con la misma letra. El
/// mockup del escenario separó los tres papeles y eligió Oxanium entre cuatro
/// candidatas por ser la que se lee como instrumento sin volverse ciencia
/// ficción. Ver `nexus-orbe-plasma.html`.
///
/// `Instrument Sans` se empaqueta como fuente variable (ejes `wdth`/`wght`);
/// los estilos en peso 300 fijan [TextStyle.fontVariations] además de
/// [TextStyle.fontWeight] para que el eje `wght` se resuelva igual en todas
/// las plataformas, sin depender del emparejamiento automático de Skia.
abstract final class NexusTypography {
  static const String sansFamily = 'Instrument Sans';
  static const String monoFamily = 'Geist Mono';
  static const String hudFamily = 'Oxanium';

  static const _light = [FontVariation('wght', 300)];

  /// Oxanium también es variable: el peso se fija en el eje por lo mismo que
  /// en Instrument Sans.
  static const _hud400 = [FontVariation('wght', 400)];
  static const _hud500 = [FontVariation('wght', 500)];

  /// Oxanium 10px, mayúsculas, tracking .18em. Palabra clave / etiqueta de
  /// estado.
  static const TextStyle label = TextStyle(
    fontFamily: hudFamily,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    fontVariations: _hud400,
    letterSpacing: 1.8,
  );

  /// Oxanium 12px, en minúscula de frase y tracking corto. Los **controles**:
  /// botones, chips, opciones de un menú, pestañas, filtros, insignias.
  ///
  /// 🔴 Hasta el 25 sep los controles iban en [mono] o [data], y con eso un
  /// botón «Cerrar» y una ruta `~/proyectos` hablaban con la misma voz: se
  /// leían los dos como dato. Un control es parte del aparato, así que va en
  /// el instrumento. No se pone en mayúsculas como [label] porque el texto de
  /// un botón se lee como orden («Añadir carpeta»), no como rótulo; el tracking
  /// de [label] en minúsculas abre la palabra hasta que cuesta leerla.
  static const TextStyle control = TextStyle(
    fontFamily: hudFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    fontVariations: _hud400,
    letterSpacing: 0.3,
    height: 1.3,
  );

  /// Sans 13px. Las **notas**: explicaciones, ayudas, frases de un estado
  /// vacío, la descripción debajo de una opción.
  ///
  /// 🔴 Antes iban en [mono] con color tenue, y el mockup lo rechaza: una
  /// explicación se lee de corrido, y en mono se lee en columna, como si fuese
  /// un log. Va en Instrument Sans —la voz de lo que se dice— y el color
  /// `mute` la baja de tono sin volverla dato.
  static const TextStyle nota = TextStyle(
    fontFamily: sansFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// Mono 11px, tracking .02em. Datos: tokens, % de contexto, modelo.
  static const TextStyle data = TextStyle(
    fontFamily: monoFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.22,
  );

  /// Oxanium 11px/500, mayúsculas, tracking .42em. El wordmark de la marca.
  static const TextStyle brand = TextStyle(
    fontFamily: hudFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    fontVariations: _hud500,
    letterSpacing: 4.62,
  );

  /// Mono 13px. Actividad: rutas, comandos, líneas de log.
  static const TextStyle mono = TextStyle(
    fontFamily: monoFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// Sans 15px. Cuerpo de interfaz.
  static const TextStyle body = TextStyle(
    fontFamily: sansFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.55,
  );

  /// Sans 17px. Entradilla.
  static const TextStyle lead = TextStyle(
    fontFamily: sansFamily,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// Oxanium 22px/300. Título de pantalla, como los del mockup.
  static const TextStyle title = TextStyle(
    fontFamily: hudFamily,
    fontSize: 22,
    fontWeight: FontWeight.w300,
    fontVariations: _light,
    letterSpacing: -0.22,
  );

  /// Sans 20px/300. Subtítulo en móvil (la línea de conversación).
  static const TextStyle subtitleMobile = TextStyle(
    fontFamily: sansFamily,
    fontSize: 20,
    fontWeight: FontWeight.w300,
    fontVariations: _light,
    letterSpacing: -0.36,
    height: 1.35,
  );

  /// Sans 34px/300. La franja de subtítulos en escritorio — no es burbuja de chat.
  static const TextStyle subtitle = TextStyle(
    fontFamily: sansFamily,
    fontSize: 34,
    fontWeight: FontWeight.w300,
    fontVariations: _light,
    letterSpacing: -0.748,
    height: 1.34,
  );

  /// Sans 46px/300. Transcripción en vivo mientras escucha.
  static const TextStyle hero = TextStyle(
    fontFamily: sansFamily,
    fontSize: 46,
    fontWeight: FontWeight.w300,
    fontVariations: _light,
    letterSpacing: -1.288,
    height: 1.15,
  );
}
