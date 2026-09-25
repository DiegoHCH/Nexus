import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';

/// El marco de las pantallas del arranque: la barra con su rótulo, **el orbe a
/// la izquierda** y lo que hay que decidir a la derecha.
///
/// 🔴 **El orbe está en las cuatro, y dice en qué punto está.** Antes la
/// comprobación era una pantalla de texto sin presencia y la configuración lo
/// dejaba como adorno encima del título. En el mockup el orbe es el que cuenta
/// el estado —apagado mientras falta algo, dormido mientras se prepara— y el
/// panel es lo que se lee; ponerlos lado a lado es lo que deja leer las dos
/// cosas a la vez sin que una tape a la otra.
///
/// El orbe llega hecho y no se construye aquí: cada pantalla decide en qué
/// estado está, y este marco no tiene por qué saberlo.
class ArranqueConOrbe extends StatelessWidget {
  const ArranqueConOrbe({
    super.key,
    required this.rotulo,
    required this.orbe,
    required this.panel,
    this.alerta = false,
  });

  /// En una palabra, lo que pasa: «Falta algo», «Antes de empezar».
  final String rotulo;

  /// El rótulo en ámbar: falta algo y hay que decirlo antes de leer nada.
  final bool alerta;

  final Widget orbe;

  /// Lo que se lee y se decide. Se desplaza por su cuenta si lo necesita: el
  /// marco no sabe cuánto mide.
  final Widget panel;

  /// El ancho del panel en el mockup: 660 de 1280. Más ancho, las líneas del
  /// texto pasan de lo que se lee de un vistazo.
  static const anchoDelPanel = 660.0;

  /// Y el del orbe: 360, lo mismo que en el mockup.
  static const ladoDelOrbe = 360.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.rule)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: NexusSpacing.s5,
                vertical: NexusSpacing.s4,
              ),
              child: Row(
                children: [
                  Text(
                    context.strings.brand,
                    style: NexusTypography.brand.copyWith(color: colors.mute),
                  ),
                  const SizedBox(width: NexusSpacing.s5),
                  Flexible(
                    child: Text(
                      rotulo.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: NexusTypography.label.copyWith(
                        color: alerta ? colors.warn : colors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(NexusSpacing.s5),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: ladoDelOrbe,
                          maxHeight: ladoDelOrbe,
                        ),
                        child: AspectRatio(
                          aspectRatio: 1,
                          // El orbe no se toca aquí: es presencia, no botón.
                          child: IgnorePointer(child: orbe),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: anchoDelPanel,
                      ),
                      child: panel,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// El botón del arranque: solo contorno, y en acento el que se espera.
///
/// «Solo contorno» es lo que la postura del mockup dice que significa
/// *disponible*; el relleno se reserva para lo elegido. El principal no se
/// rellena: se distingue por el color, que basta para saber cuál pulsar.
class BotonDelArranque extends StatelessWidget {
  const BotonDelArranque({
    super.key,
    required this.texto,
    required this.onPulsar,
    this.principal = false,
    this.ocupado = false,
  });

  final String texto;
  final VoidCallback? onPulsar;
  final bool principal;

  /// Está haciendo lo que se le pidió: el texto se cambia por un giro, del
  /// mismo color, para que el botón no parezca que no respondió.
  final bool ocupado;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = principal ? colors.accent : colors.ink;
    return OutlinedButton(
      onPressed: onPulsar,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: principal ? colors.accent : colors.rule2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NexusRadius.sm),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: NexusSpacing.s4,
          vertical: NexusSpacing.s3,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: ocupado
          ? SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
            )
          : Text(texto, style: NexusTypography.control.copyWith(color: color)),
    );
  }
}
