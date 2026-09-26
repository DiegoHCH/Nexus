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
    this.sobreElCentro = 230,
  });

  /// En una palabra, lo que pasa: «Falta algo», «Antes de empezar».
  final String rotulo;

  /// El rótulo en ámbar: falta algo y hay que decirlo antes de leer nada.
  final bool alerta;

  final Widget orbe;

  /// Lo que se lee y se decide. Se desplaza por su cuenta si lo necesita: el
  /// marco no sabe cuánto mide.
  final Widget panel;

  /// Cuánto por encima del centro del orbe empieza el panel.
  ///
  /// 🔴 **El panel no se centra en vertical: arranca a una altura fija
  /// respecto al orbe**, como en el mockup (la comprobación a 230 px del centro
  /// del orbe, los tres pasos a 284, porque son más largos). Centrado, el
  /// título bailaba de sitio según cuántas filas hubiera, y entre la
  /// comprobación y el primer arranque —que van seguidas— se veía saltar.
  /// Contarlo desde el orbe y no desde la barra es lo que lo mantiene en su
  /// sitio en una ventana más alta: el orbe baja con el centro, y el panel con
  /// él.
  final double sobreElCentro;

  /// El ancho del panel en el mockup: 660 de 1280. Más ancho, las líneas del
  /// texto pasan de lo que se lee de un vistazo.
  static const anchoDelPanel = 660.0;

  /// Y el del orbe: 360, lo mismo que en el mockup.
  static const ladoDelOrbe = 360.0;

  /// El alto de la barra en el mockup (`.mbarra`, 52 px).
  static const altoDeLaBarra = 52.0;

  /// Dónde cae el centro del orbe, de arriba abajo: al 44 % del cuerpo. En el
  /// mockup el orbe de 360 empieza a 200 px en una pantalla de 800 —148 bajo
  /// la barra, en un cuerpo de 748—, un poco por encima del centro, que es
  /// donde se lee como apoyado y no caído.
  static const _alturaDelOrbe = 0.44;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.void_,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // La barra del mockup: 52 de alto, 28 de margen, la marca y el rótulo
          // a 18 el uno del otro, y una línea debajo. Fondo `void`, más oscuro
          // que el cuerpo, para que se lea como marco y no como contenido.
          Container(
            height: altoDeLaBarra,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            decoration: BoxDecoration(
              color: colors.void_,
              border: Border(bottom: BorderSide(color: colors.rule)),
            ),
            child: Row(
              children: [
                Text(
                  context.strings.brand,
                  style: NexusTypography.brand.copyWith(color: colors.mute),
                ),
                const SizedBox(width: 18),
                Flexible(
                  child: Text(
                    rotulo.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    // 11 px y .18em, el `.rot` del mockup: un punto más que
                    // [NexusTypography.label] porque aquí es el rótulo de la
                    // pantalla entera, no el de una pieza.
                    style: NexusTypography.label.copyWith(
                      fontSize: 11,
                      letterSpacing: 1.98,
                      color: alerta ? colors.warn : colors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            // El fondo del mockup: un claro de `deep` detrás del orbe que se
            // apaga hacia `void`. Plano, el orbe flotaba sobre nada; con el
            // claro tiene dónde estar.
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.4, 0.1),
                  radius: 1.2,
                  colors: [colors.deep, colors.void_],
                  stops: const [0, 0.7],
                ),
              ),
              child: LayoutBuilder(
                builder: (context, cuerpo) {
                  final centro = cuerpo.maxHeight * _alturaDelOrbe;
                  final arriba = (centro - sobreElCentro).clamp(
                    NexusSpacing.s5,
                    double.infinity,
                  );
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Align(
                          // -0.12 en `Alignment` es el 44 % de arriba abajo.
                          alignment: Alignment(0, _alturaDelOrbe * 2 - 1),
                          child: Padding(
                            padding: const EdgeInsets.all(NexusSpacing.s5),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: ladoDelOrbe,
                                maxHeight: ladoDelOrbe,
                              ),
                              child: AspectRatio(
                                aspectRatio: 1,
                                // El orbe no se toca aquí: es presencia, no
                                // botón.
                                child: IgnorePointer(child: orbe),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Padding(
                          // A 520 de 1280, como el panel del mockup: los dos
                          // quintos del orbe dejan 512, y los 8 que faltan son
                          // el aire entre el orbe y el título.
                          padding: EdgeInsets.only(
                            top: arriba,
                            left: NexusSpacing.s2,
                          ),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: anchoDelPanel,
                              ),
                              child: panel,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
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
///
/// 🔴 **En mayúsculas y con la letra del instrumento, como el `.btn` del
/// mockup** —Oxanium 10, tracking .14em, 8×11 de relleno—. Con
/// [NexusTypography.control] en minúscula de frase, «Comprobar de nuevo» se
/// leía como una frase más del panel y no como el mando que es: en una
/// pantalla que solo tiene texto y dos o tres botones, el botón tiene que
/// distinguirse del texto a la primera, y es la forma de la letra la que lo
/// hace. Es el mismo trato que el mockup da a todos sus botones de pantalla;
/// el lector de pantalla recibe la frase normal y no las mayúsculas.
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

  /// La letra del `.btn`: la de los rótulos con el tracking un poco más
  /// cerrado, que en mayúsculas seguidas abre la palabra de más.
  static TextStyle estilo(Color color) =>
      NexusTypography.label.copyWith(letterSpacing: 1.4, color: color);

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
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: ocupado
          ? SizedBox.square(
              dimension: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
            )
          : Semantics(
              label: texto,
              excludeSemantics: true,
              child: Text(texto.toUpperCase(), style: estilo(color)),
            ),
    );
  }
}
