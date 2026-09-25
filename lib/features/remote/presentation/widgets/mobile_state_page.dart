import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/nexus_colors.dart';
import 'package:nexus/core/design_system/nexus_spacing.dart';
import 'package:nexus/core/design_system/nexus_typography.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/remote/presentation/widgets/mobile_chrome.dart';
import 'package:nexus/features/remote/presentation/widgets/orbe_apagado.dart';

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
/// abierta»—, y **apagado** cuando no hay Mac: sin color, quieto y sin el anillo del
/// oído, porque ahí no hay nadie oyendo (ver `OrbeApagado`). Un orbe girando mientras
/// la pantalla dice «no llego a tu Mac» promete trabajo que no está pasando.
///
/// Y va **en el flujo**, con el mismo reparto que `ConnectingPage`: el orbe y su texto
/// como un solo bloque centrado entre dos espaciadores. Estuvo como capa de fondo
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
    this.detalle,
    this.pieDeAyuda,
    this.acciones = const [],
    this.abajo,
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.void_,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            NexusSpacing.s5,
            NexusSpacing.s4,
            NexusSpacing.s5,
            NexusSpacing.s5,
          ),
          child: Column(
            children: [
              MobileChrome(alMenu: alMenu),
              const Spacer(),
              // Sin horizonte: el horizonte es lo que decía «trabajando», y aquí no
              // se está trabajando.
              //
              // `Flexible` alrededor de un alto fijo: 260 donde cabe y **menos donde
              // no**. Con dos botones y un porqué largo, en un teléfono pequeño o con
              // la letra del sistema en grande, el alto fijo desbordaba la columna —
              // y lo que se cortaba era justo el botón de abajo—. Encoge el orbe, que
              // es lo único que puede encoger sin perder nada.
              Flexible(
                flex: 4,
                child: SizedBox(
                  height: 260,
                  child: apagado
                      ? const OrbeApagado()
                      : IgnorePointer(
                          child: NexusOrb(state: orbe, showHorizon: false),
                        ),
                ),
              ),
              const SizedBox(height: NexusSpacing.s2),
              // El título del mockup —`.grande`— es la letra del instrumento a 22,
              // que es `title`: dice qué pasó como el panel de un aparato, no como
              // un párrafo.
              Text(
                titulo,
                key: const ValueKey('titulo-del-estado'),
                textAlign: TextAlign.center,
                style: NexusTypography.title.copyWith(color: colors.ink),
              ),
              const SizedBox(height: NexusSpacing.s3),
              // Y el porqué en sans, que es lo que se lee de corrido: en mono tenue
              // no pasaba AA y se leía como un log.
              Text(
                cuerpo,
                textAlign: TextAlign.center,
                style: NexusTypography.nota.copyWith(color: colors.mute),
              ),
              if (detalle != null) ...[
                const SizedBox(height: NexusSpacing.s3),
                detalle!,
              ],
              if (acciones.isNotEmpty) ...[
                const SizedBox(height: NexusSpacing.s6),
                for (final (i, accion) in acciones.indexed) ...[
                  if (i > 0) const SizedBox(height: NexusSpacing.s3),
                  accion,
                ],
              ],
              if (pieDeAyuda != null) ...[
                const SizedBox(height: NexusSpacing.s3),
                Text(
                  pieDeAyuda!,
                  textAlign: TextAlign.center,
                  style: NexusTypography.nota.copyWith(
                    color: colors.mute,
                    fontSize: 12,
                  ),
                ),
              ],
              const Spacer(),
              ?abajo,
            ],
          ),
        ),
      ),
    );
  }
}

/// Un botón del sistema: borde fino, mono, mayúsculas.
///
/// No un `FilledButton` de Material: el mockup no tiene ninguno relleno salvo la
/// acción principal de emparejar, y el resto son bordes de 1px. Un botón relleno de
/// Material en esta pantalla se ve como de otra app.
class MobileAction extends StatelessWidget {
  const MobileAction({
    super.key,
    required this.texto,
    required this.alTocar,
    this.principal = false,
  });

  final String texto;
  final VoidCallback? alTocar;
  final bool principal;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = principal ? colors.accent : colors.mute;

    return InkWell(
      onTap: alTocar,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: NexusSpacing.s4,
          vertical: NexusSpacing.s3,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: principal
                ? colors.accent.withValues(alpha: 0.5)
                : colors.rule2,
          ),
        ),
        // `control`, el papel de los botones: ver `WideAction`.
        child: Text(
          texto,
          style: NexusTypography.control.copyWith(color: color),
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
