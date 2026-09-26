import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/nexus_colors.dart';
import 'package:nexus/core/design_system/nexus_spacing.dart';
import 'package:nexus/core/design_system/nexus_typography.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/remote/presentation/widgets/mobile_chrome.dart';

/// El molde de las pantallas de estado del teléfono.
///
/// Los mockups dedican una sección entera a esto y empiezan diciendo lo que hacía
/// falta oír: **«no son opcionales y no se resuelven con un spinner centrado. Cada uno
/// dice qué pasó y qué se puede hacer; ninguno se disculpa.»**
///
/// La primera versión de estas pantallas los resolvía con un texto gris en el centro
/// —o con nada—, que es exactamente lo que esa frase descarta. Así que el molde
/// **obliga** a las tres partes: qué pasó, por qué, y qué se puede hacer. Un estado
/// sin acciones tiene que decidirlo quien lo escribe, no aparecer por descuido.
///
/// El orbe va con su estado y no como ilustración: es el único elemento vivo del
/// sistema. Dormido cuando el Mac está pero no hay nada que enseñar —«ya no está
/// abierta»—, y **apagado** cuando no hay Mac: sin color, casi quieto y sin el anillo
/// del oído, porque ahí no hay nadie oyendo (ver `NexusOrb.apagado`). Un orbe girando
/// a su ritmo mientras la pantalla dice «no llego a tu Mac» promete trabajo que no está
/// pasando.
///
/// Y va **en el flujo**, con el mismo reparto que `ConnectingPage`: el orbe y su texto
/// como un solo bloque centrado en el alto. Estuvo como capa de fondo
/// fijada al 46 % del alto, con el orbe pegado arriba y el texto aparte — se veía **de
/// otra app** al lado de las demás. Estas pantallas y la de conectar se ven una detrás
/// de otra —buscar, no llegar, volver a buscar—, y un salto de composición entre ellas
/// se lee como un fallo.
class MobileStatePage extends StatelessWidget {
  const MobileStatePage({
    super.key,
    required this.titulo,
    required this.cuerpo,
    this.orbe = NexusOrbState.sleep,
    this.apagado = false,
    this.alMenu,
    this.alVolver,
    this.detalle,
    this.pieDeAyuda,
    this.acciones = const [],
    this.abajo,
    this.ladoDelOrbe = 230,
  });

  /// Qué pasó, en una frase corta y sin disculparse.
  final String titulo;

  /// Por qué, y qué implica.
  final String cuerpo;

  final NexusOrbState orbe;

  /// Sin nadie al otro lado: el orbe apagado en vez de [orbe].
  final bool apagado;

  /// El menú, en los estados desde los que se puede ir a otra parte.
  final VoidCallback? alMenu;

  /// La vuelta `‹`, en los estados a los que se llega desde otra pantalla.
  final VoidCallback? alVolver;

  /// Un dato en mono: la dirección, el modelo, la ruta. Lo que hace que el mensaje
  /// sea de **este** caso y no genérico.
  final Widget? detalle;

  /// La línea de abajo, más apagada: lo que conviene comprobar.
  final String? pieDeAyuda;

  /// Una debajo de otra y a todo el ancho, como el mockup: la primera es la que la
  /// pantalla propone y las demás, salidas.
  final List<Widget> acciones;

  /// Lo que va pegado al fondo, como el control de permiso.
  final Widget? abajo;

  /// El lado del orbe donde cabe. El mockup lo cambia según lo que haya debajo: 230
  /// con dos botones, 220 con uno y su pie.
  final double ladoDelOrbe;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.void_,
      body: SafeArea(
        child: Column(
          children: [
            MobileChrome(alMenu: alMenu, alVolver: alVolver),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  MedidasDelMovil.margen,
                  0,
                  MedidasDelMovil.margen,
                  MedidasDelMovil.pie,
                ),
                // **El bloque entero centrado en el alto**, como el mockup y como
                // `ConnectingPage`: el orbe, lo que dice y lo que se puede hacer son
                // una sola cosa, y se ven una detrás de otra —buscar, no llegar,
                // volver a buscar—. Un salto de composición entre ellas se lee como
                // un fallo.
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Sin horizonte: el horizonte es lo que decía «trabajando», y aquí
                    // no se está trabajando.
                    //
                    // `Flexible` alrededor de un alto fijo: el lado del mockup donde
                    // cabe y **menos donde no**. Con dos botones y un porqué largo, en
                    // un teléfono pequeño o con la letra del sistema en grande, el
                    // alto fijo desbordaba la columna — y lo que se cortaba era justo
                    // el botón de abajo. Encoge el orbe, que es lo único que puede
                    // encoger sin perder nada.
                    Flexible(
                      child: SizedBox(
                        height: ladoDelOrbe,
                        child: IgnorePointer(
                          child: NexusOrb(
                            state: apagado ? NexusOrbState.sleep : orbe,
                            // Apagado es el mismo orbe sin lo que dice «estoy»: el
                            // color, la mitad de la luz y el oído. Ver
                            // `NexusOrb.apagado`.
                            apagado: apagado,
                            oido: !apagado,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // El título del mockup —`.grande`— va en la letra de los títulos,
                    // que es `title`: dice qué pasó como el panel de un aparato, no
                    // como un párrafo. A 24, que es su medida en el teléfono.
                    TextoEquilibrado(
                      titulo,
                      clave: const ValueKey('titulo-del-estado'),
                      style: NexusTypography.title.copyWith(
                        color: colors.ink,
                        fontSize: 24,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: NexusSpacing.s2),
                    // Y el porqué en sans, que es lo que se lee de corrido: en mono
                    // tenue no pasaba AA y se leía como un log.
                    Text(
                      cuerpo,
                      textAlign: TextAlign.center,
                      style: NexusTypography.nota.copyWith(
                        color: colors.mute,
                        fontSize: 13.5,
                      ),
                    ),
                    if (detalle != null) ...[
                      const SizedBox(height: NexusSpacing.s2),
                      detalle!,
                    ],
                    if (acciones.isNotEmpty) ...[
                      const SizedBox(height: 26),
                      for (final (i, accion) in acciones.indexed) ...[
                        if (i > 0) const SizedBox(height: 10),
                        accion,
                      ],
                    ],
                    if (pieDeAyuda != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        pieDeAyuda!,
                        textAlign: TextAlign.center,
                        style: NexusTypography.nota.copyWith(
                          color: colors.mute,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            ?abajo,
          ],
        ),
      ),
    );
  }
}

/// Un dato en mono, para el `detalle` de un estado.
class MobileDetail extends StatelessWidget {
  const MobileDetail({super.key, required this.partes});

  /// Se separan con un punto medio, como en los mockups: `macbook-diego · red local`.
  final List<String> partes;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Text(
      partes.join('  ·  '),
      textAlign: TextAlign.center,
      style: NexusTypography.data.copyWith(color: colors.mute),
    );
  }
}
