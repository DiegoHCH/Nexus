import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/nexus_colors.dart';
import 'package:nexus/core/design_system/orbe_preference.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb_painter.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb_plasma_painter.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/icono/domain/icono_del_dock.dart';

/// El icono del Dock, pintado con **los mismos pinceles que el orbe**.
///
/// Se compone como el icono del paquete (`AppIcon.appiconset`), que es contra lo
/// que se va a ver en el Dock: la placa de `--void` con la esquina continua de
/// macOS, de 824 dentro de 1024 —la rejilla de Apple—, y el orbe en el centro
/// del tamaño del de ahí. Con otra medida, el icono saltaría de tamaño al
/// abrir la app, que es justo el momento en que se mira.
///
/// Una foto fija y no una animación: el plasma se mueve, pero el Dock no es
/// sitio para un vídeo, y cada fotograma costaría un dibujo entero.
abstract final class DibujoDelIcono {
  /// El lado del PNG, en píxeles.
  ///
  /// 🔴 **512 y no 1024.** El Dock enseña el icono a 128 pt como mucho —256 px
  /// en Retina— y solo llega a 512 px con la ampliación al máximo, que casi
  /// nadie usa. A 1024 el dibujo cuesta el cuádruple de píxeles de shader y el
  /// PNG pesa el cuádruple para una resolución que no se enseña nunca. Medido
  /// en `flutter test` (sin GPU, así que es el techo): ver [pintar].
  static const lado = 512;

  /// La placa según la rejilla de Apple, en unidades de un icono de 1024.
  static const _margen = 100.0;
  static const _placa = 824.0;

  /// La esquina de la placa: el 22,5 % del lado, la de los iconos de macOS.
  /// Con `RSuperellipse` sale **continua** —la curva que usa Apple— y no un
  /// arco de círculo, que junto a los demás iconos del Dock se nota.
  static const _esquina = 185.4;

  /// El radio del orbe, medido en el icono del paquete: 235 de 1024.
  static const _radioDelOrbe = 235.0;

  /// El del plasma, más pequeño: su halo llega hasta el doble del radio, y con
  /// el de los puntos inundaba la placa entera de luz. Así el halo se funde
  /// antes del borde y el orbe se lee del mismo tamaño que el de puntos.
  static const _radioDelPlasma = 190.0;

  /// Escuchando: despierto, con la malla a la vista y sin voz que lo deforme.
  /// Es la pose de la vista previa de Ajustes, la que eligió quien lo ajustó.
  static const _estado = NexusOrbState.listen;

  /// A cuánto se pintan las líneas de los puntos: el orbe de puntos está
  /// pensado para verse a unos cientos de píxeles, y a 1024 una arista de
  /// 1 px desaparece al reducirlo al Dock. Se pinta en pequeño y se escala.
  static const _escalaDePuntos = 3.0;

  /// La pose de la foto: cuánto ha girado y en qué momento del remolino.
  ///
  /// Elegida a ojo entre varias, y fija para que el icono no cambie de pose
  /// cada vez que se repinta: lo único que tiene que cambiar es lo que elegiste.
  static const _t = 1.0;
  static const _anguloDelPlasma = 0.9;
  static const _tiempoDelPlasma = 2.4;

  /// El icono de [pedido] como PNG de [lado] × [lado], o `null` si no se pudo.
  ///
  /// Coste medido en `flutter test`, sin GPU —el techo, en la app es menos—:
  /// ver el comentario de `ElIconoDelDock`. [programa] es el shader del
  /// plasma; sin él se pinta de puntos, lo mismo que hace el orbe.
  static Future<Uint8List?> pintar(
    LoQueSePinta pedido, {
    ui.FragmentProgram? programa,
    int lado = DibujoDelIcono.lado,
  }) async {
    final grabadora = ui.PictureRecorder();
    final lienzo = Canvas(grabadora);
    componer(lienzo, pedido, programa: programa, lado: lado.toDouble());
    final foto = grabadora.endRecording();
    ui.Image? imagen;
    try {
      imagen = await foto.toImage(lado, lado);
      final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
      return datos?.buffer.asUint8List();
    } on Object catch (error) {
      debugPrint('icono · no se pudo pintar: $error');
      return null;
    } finally {
      imagen?.dispose();
      foto.dispose();
    }
  }

  /// Pinta el icono en [lienzo], en un cuadrado de [lado].
  ///
  /// Aparte de [pintar] para poder mirarlo sin sacar un PNG.
  static void componer(
    Canvas lienzo,
    LoQueSePinta pedido, {
    ui.FragmentProgram? programa,
    required double lado,
  }) {
    final k = lado / 1024;
    final centro = Offset(lado / 2, lado / 2);
    final placa = RSuperellipse.fromRectAndRadius(
      Rect.fromLTWH(_margen * k, _margen * k, _placa * k, _placa * k),
      Radius.circular(_esquina * k),
    );

    // La placa es **siempre la oscura**, se use la app en claro o en oscuro:
    // es la del icono del paquete, y el Dock no cambia de icono con el tema de
    // una app. El acento se ajusta a este fondo por lo mismo.
    lienzo
      ..drawRSuperellipse(placa, Paint()..color = NexusColors.dark.void_)
      ..save()
      ..clipRSuperellipse(placa);

    final dePlasma = pedido.estilo.forma == FormaDelOrbe.plasma;

    if (dePlasma && programa != null) {
      _plasma(lienzo, pedido, programa, centro, k);
    } else {
      _puntos(lienzo, pedido, centro, k);
    }
    lienzo.restore();
  }

  static void _plasma(
    Canvas lienzo,
    LoQueSePinta pedido,
    ui.FragmentProgram programa,
    Offset centro,
    double k,
  ) {
    // 🔴 **El tamaño es el del icono, no el de tu ajuste** —ya viene quitado en
    // [LoQueSePinta]—. El resto del estilo —hebras, torsión, finura, núcleo,
    // luz— es tuyo y se respeta; el radio lo fija la rejilla, porque un orbe al
    // 15 % en un icono de 16 px es un punto.
    final estilo = pedido.estilo;
    final caja = _radioDelPlasma * k / estilo.tamano;
    final vivo = PlasmaVivo()
      ..fijar(_estado)
      ..angulo = _anguloDelPlasma
      ..tiempo = _tiempoDelPlasma;
    lienzo
      ..save()
      ..translate(centro.dx - caja / 2, centro.dy - caja / 2);
    NexusOrbPlasmaPainter(
      programa: programa,
      estado: _estado,
      estilo: estilo,
      vivo: vivo,
      t: _t,
      accent: pedido.acento,
      onLight: false,
      fillsBox: true,
      // La voz al mínimo: escuchando sin nadie hablando, que es la pose quieta.
      nivel: 0,
    ).paint(lienzo, Size.square(caja));
    lienzo.restore();
  }

  static void _puntos(
    Canvas lienzo,
    LoQueSePinta pedido,
    Offset centro,
    double k,
  ) {
    final escala = _escalaDePuntos * k;
    final radio = _radioDelOrbe * k;
    // Con `fillsBox` el radio es la caja entre 3,1 —ver `NexusOrbPainter`—.
    final caja = radio / escala * 3.1;

    // El horizonte del icono del paquete, a los dos lados del orbe y no por
    // detrás: el halo es translúcido y la línea se vería cruzándolo.
    final linea = Paint()
      ..color = pedido.acento.withValues(alpha: 0.35)
      ..strokeWidth = 2 * k;
    lienzo
      ..drawLine(
        Offset(_margen * k, centro.dy),
        Offset(centro.dx - radio, centro.dy),
        linea,
      )
      ..drawLine(
        Offset(centro.dx + radio, centro.dy),
        Offset((_margen + _placa) * k, centro.dy),
        linea,
      )
      ..save()
      ..translate(centro.dx, centro.dy)
      ..scale(escala)
      ..translate(-caja / 2, -caja / 2);
    NexusOrbPainter(
      state: _estado,
      t: _t,
      accent: pedido.acento,
      showHorizon: false,
      fillsBox: true,
      nivel: 0,
    ).paint(lienzo, Size.square(caja));
    lienzo.restore();
  }
}
