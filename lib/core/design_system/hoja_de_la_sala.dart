import 'package:nexus/core/design_system/la_entrada_de_la_hoja.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexus/core/design_system/boton_de_fila.dart';
import 'package:nexus/core/design_system/nexus_colors.dart';
import 'package:nexus/core/design_system/nexus_radius.dart';
import 'package:nexus/core/design_system/nexus_spacing.dart';
import 'package:nexus/core/design_system/nexus_typography.dart';
import 'package:nexus/core/i18n/strings_scope.dart';

/// Una hoja **ancha** sobre la sala: la barra de arriba, la sala atenuada a la
/// izquierda y, a la derecha, la hoja con su lado y su vista.
///
/// Es la «hoja ancha» del mockup —`#historial` y `#documentos`—: la barra
/// cruza la ventana entera con la marca, el rótulo de la hoja y «Cerrar · Esc»,
/// y la hoja se pega al borde derecho debajo de ella.
///
/// 🔴 **Antes eran diálogos centrados**, con su caja redondeada flotando sobre
/// una pantalla negra: la sala desaparecía, y el historial y los documentos se
/// leían como ventanas emergentes de otra app. Como hoja, la sala sigue a la
/// vista —atenuada— y pulsarla cierra, igual que Esc.
///
/// **Vive en el sistema de diseño porque ya son dos** —el historial y los
/// documentos—, y dos copias del armazón acabarían con dos barras distintas en
/// cuanto se tocara una.
class HojaDeLaSala extends StatelessWidget {
  const HojaDeLaSala({
    super.key,
    required this.rotulo,
    required this.lado,
    required this.vista,
  });

  /// Lo que se lee en la barra junto a la marca: «Historial», «Documentos».
  final String rotulo;

  /// La columna de la izquierda: buscar, filtrar, la lista.
  final Widget lado;

  /// Lo elegido, a la derecha.
  final Widget vista;

  /// Abre [hoja] como ruta transparente, para que la sala se siga pintando
  /// detrás.
  static Future<void> abrir(BuildContext context, Widget hoja) =>
      Navigator.of(context).push(RutaDeLaHoja<void>(builder: (_) => hoja));

  /// El ancho de la hoja para una ventana dada.
  ///
  /// Mil de cada mil doscientos ochenta, como el mockup, con suelo y techo: por
  /// debajo de 860 la vista se queda en una columna de frases partidas al lado
  /// de un lado de 420, y por encima de 1160 las líneas se alargan tanto que
  /// cuesta leerlas. En una ventana más estrecha que el suelo, la hoja la ocupa
  /// entera.
  @visibleForTesting
  static double anchoDeLaHoja(double ventana) =>
      (ventana * 1000 / 1280).clamp(860.0, 1160.0).clamp(0.0, ventana);

  /// El ancho del lado. Fijo, como en el mockup: la lista se recorre con la
  /// vista en vertical y, si cambiase con la ventana, las horas y los turnos
  /// dejarían de cuadrar entre dos aperturas.
  static const double anchoDelLado = 420;

  void _cerrar(BuildContext context) => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            _cerrar(context),
      },
      child: Focus(
        autofocus: true,
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElVeloEntra(
                child: _LaBarra(
                  rotulo: rotulo,
                  onCerrar: () => _cerrar(context),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, caja) => Row(
                    // Estirado a lo alto: sin esto el velo de la sala, que no
                    // tiene hijo, mediría cero y ni atenuaría ni se podría
                    // pulsar.
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          key: const ValueKey('la-sala-detras'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _cerrar(context),
                          child: ElVeloEntra(
                            child: ColoredBox(
                              color: colors.scrim.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                      ),
                      LaHojaEntra(
                        child: SizedBox(
                          width: anchoDeLaHoja(caja.maxWidth),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              // Casi opaca, como el `deep 97 %` del mockup: la
                              // sala se adivina detrás sin ensuciar lo que se lee.
                              color: colors.deep.withValues(alpha: 0.97),
                              border: Border(
                                left: BorderSide(color: colors.rule2),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  width: anchoDelLado,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 22,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(color: colors.rule),
                                    ),
                                  ),
                                  child: lado,
                                ),
                                Expanded(child: vista),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La vista de la derecha, con el aire del mockup: 28 arriba, 36 a los lados.
///
/// Se desplaza entera y no por partes: lo que se mira es una sola cosa —una
/// conversación, un documento— y partirla en dos rodillos haría perder el
/// sitio.
class VistaDeLaHoja extends StatelessWidget {
  const VistaDeLaHoja({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, hijo) in children.indexed) ...[
          if (i > 0) const SizedBox(height: 14),
          hijo,
        ],
      ],
    ),
  );
}

/// Un bloque de la vista: una línea encima, quién habla o qué es, y debajo lo
/// que dijo.
///
/// Bloques con línea y no burbujas: esto es un registro de lo que se hizo, no
/// dos personas charlando. Lo usan la vista de una conversación —«Lo que
/// pediste», «Lo último que dijo»— y la de un documento —«Salió de»—.
class BloqueDeLaVista extends StatelessWidget {
  const BloqueDeLaVista({super.key, required this.quien, required this.child});

  final String quien;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.rule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quien.toUpperCase(),
            style: NexusTypography.label.copyWith(
              color: colors.mute,
              fontSize: 9.5,
              letterSpacing: 1.52,
            ),
          ),
          const SizedBox(height: NexusSpacing.s1),
          child,
        ],
      ),
    );
  }
}

/// Una acción de la hoja: «Retomar», «Abrir», «Enseñar en el Finder», la
/// papelera de una fila.
///
/// Con el aire del `.btn` del mockup —8 × 11— y no con el de [BotonDeFila]:
/// ése está apretado para caber en la fila de una corrida, y a su tamaño las
/// acciones de la vista se quedaban en una tira de catorce píxeles que se leía
/// como etiquetas y no como botones. Los colores son los mismos, por
/// [TonoDeBoton], para que «principal» y «peligro» digan lo mismo en toda la
/// app.
///
/// En minúscula de frase y no en mayúsculas como el mockup: es el papel
/// [NexusTypography.control], que decidió que un botón se lee como una orden y
/// no como un rótulo.
class BotonDeLaHoja extends StatelessWidget {
  const BotonDeLaHoja({
    super.key,
    required this.texto,
    required this.onPulsar,
    this.tono = TonoDeBoton.neutro,
    this.tooltip,
  });

  final String texto;
  final VoidCallback? onPulsar;
  final TonoDeBoton tono;

  /// Lo que no cabe en el nombre: la papelera de una fila se escribe «✕», y
  /// su nombre de verdad va aquí.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (color, borde) = switch (tono) {
      TonoDeBoton.principal => (colors.accent, colors.accent),
      TonoDeBoton.bien => (colors.ok, colors.ok.withValues(alpha: 0.45)),
      TonoDeBoton.peligro => (colors.err, colors.err.withValues(alpha: 0.45)),
      TonoDeBoton.neutro => (colors.ink, colors.rule2),
    };
    final apagado = onPulsar == null;

    final boton = OutlinedButton(
      onPressed: onPulsar,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(color: apagado ? colors.rule : borde),
        foregroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NexusRadius.sm),
        ),
      ),
      child: Text(
        texto.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: NexusTypography.boton.copyWith(
          color: apagado ? colors.faint : color,
        ),
      ),
    );
    if (tooltip case final mensaje? when mensaje.isNotEmpty) {
      return Tooltip(message: mensaje, child: boton);
    }
    return boton;
  }
}

/// La barra de arriba: la marca, el rótulo de la hoja y cómo se cierra.
///
/// Cruza la ventana entera, sala incluida, como en el mockup: es la barra de la
/// app mientras la hoja está abierta, no un título dentro de la hoja.
class _LaBarra extends StatelessWidget {
  const _LaBarra({required this.rotulo, required this.onCerrar});

  final String rotulo;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: colors.void_,
        border: Border(bottom: BorderSide(color: colors.rule)),
      ),
      child: Row(
        children: [
          // La misma marca que la barra de la sala, para que la hoja se lea
          // como la app y no como otra ventana.
          Text(
            strings.brand,
            style: NexusTypography.brand.copyWith(color: colors.mute),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              rotulo.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: NexusTypography.label.copyWith(
                color: colors.accent,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: NexusSpacing.s4),
          // Con su contorno y en rótulo, como en el mockup: dice a la vez qué
          // hace y con qué tecla, y no compite con las acciones de la vista.
          InkWell(
            onTap: onCerrar,
            borderRadius: BorderRadius.circular(NexusRadius.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: colors.rule2),
                borderRadius: BorderRadius.circular(NexusRadius.sm),
              ),
              child: Text(
                strings.closeEsc,
                style: NexusTypography.label.copyWith(
                  color: colors.mute,
                  letterSpacing: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
