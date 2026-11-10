import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/accent_preference.dart';
import 'package:nexus/core/design_system/nexus_theme.dart';
import 'package:nexus/core/design_system/theme_preference.dart';
import 'package:nexus/core/i18n/language_preference.dart';

/// **La apariencia de Nexus, para las ventanas que pinta otro motor** —la
/// botonera de fuera, el hub de dispositivos—.
///
/// Pedido el 10 nov, al empezar el hub: «la interfaz y colores y demás debe
/// tomar lo que se configure en Nexus». Esas ventanas corren su propio motor de
/// Flutter, que no tiene los providers de la app, así que la apariencia les
/// llega en la foto: el tema que se ve (con «Sistema» ya resuelto), el acento
/// elegido en la rueda **ya ajustado al tema** —igual que lo recibe la app, que
/// sin ajustar no cumpliría contraste en el claro— y el idioma.
///
/// Viaja en la foto y la foto se vuelve a mandar en cuanto algo cambia: cambiar
/// el tema con la ventana abierta la repinta en el acto.
@immutable
class LaAparienciaDeFuera {
  const LaAparienciaDeFuera({
    required this.claro,
    required this.acento,
    required this.idioma,
  });

  final bool claro;

  /// ARGB, ya ajustado al tema. Ver `Accent.forBrightness`.
  final int acento;

  final String idioma;

  ThemeData get tema => claro
      ? NexusTheme.light(accent: Color(acento))
      : NexusTheme.dark(accent: Color(acento));

  Locale get locale => Locale(idioma);

  Map<String, Object?> toMap() => {
    'claro': claro,
    'acento': acento,
    'idioma': idioma,
  };

  /// Lo que falte, el de fábrica: una ventana que se pinta sin apariencia es
  /// peor que una con la de siempre.
  static LaAparienciaDeFuera fromMap(Map<Object?, Object?> mapa) =>
      LaAparienciaDeFuera(
        claro: mapa['claro'] == true,
        acento: switch (mapa['acento']) {
          final int argb => argb,
          _ => 0xFF56E1EA,
        },
        idioma: switch (mapa['idioma']) {
          final String i when i.isNotEmpty => i,
          _ => 'es',
        },
      );

  @override
  bool operator ==(Object other) =>
      other is LaAparienciaDeFuera &&
      other.claro == claro &&
      other.acento == acento &&
      other.idioma == idioma;

  @override
  int get hashCode => Object.hash(claro, acento, idioma);
}

final laAparienciaDeFueraProvider = Provider<LaAparienciaDeFuera>((ref) {
  final claro = !ref.watch(isDarkProvider);
  final acento = ref
      .watch(accentControllerProvider)
      .forBrightness(claro ? Brightness.light : Brightness.dark);
  return LaAparienciaDeFuera(
    claro: claro,
    acento: acento.toARGB32(),
    idioma: ref.watch(localeProvider).languageCode,
  );
});
