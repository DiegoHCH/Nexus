import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';

/// La guía corta: qué hace, cómo se le habla, qué puede y qué no.
///
/// 🔴 **Cuatro párrafos y no cinco pantallas.** La guía de Ajustes › Ayuda
/// contesta lo que se pregunta el día que algo falla —qué sale de tu Mac, qué
/// hacer cuando no va—, y a quien acaba de instalar la app le sobra. Lo que esa
/// persona necesita cabe en un minuto de lectura: para qué sirve esto, cómo se
/// le habla, y dónde acaba. El resto se enlaza al final.
///
/// Un diálogo y no una sección más de Ajustes porque se abre **desde fuera**
/// —el menú Ayuda de macOS, donde se busca ayuda en cualquier app del Mac— y
/// tiene que poder leerse encima de lo que haya, sin llevarte a otra pantalla.
class LaGuiaCorta extends StatelessWidget {
  const LaGuiaCorta({super.key});

  /// La llave del diálogo, para encontrarlo en una prueba.
  static const llave = ValueKey('la-guia-corta');

  static Future<void> abrir(BuildContext context) =>
      showDialog<void>(context: context, builder: (_) => const LaGuiaCorta());

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final apartados = [
      (strings.guiaCortaQueHace, strings.guiaCortaQueHaceCuerpo),
      (strings.guiaCortaComoHablarle, strings.guiaCortaComoHablarleCuerpo),
      (strings.guiaCortaQuePuede, strings.guiaCortaQuePuedeCuerpo),
      (strings.guiaCortaQueNo, strings.guiaCortaQueNoCuerpo),
    ];

    return Dialog(
      key: llave,
      backgroundColor: colors.rise,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NexusRadius.md),
        side: BorderSide(color: colors.rule),
      ),
      child: ConstrainedBox(
        // El ancho de una columna que se lee de un vistazo, como el panel del
        // arranque: más ancho, cada línea pasa de lo que se abarca.
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                strings.guiaCortaTitulo,
                style: NexusTypography.title.copyWith(
                  color: colors.ink,
                  fontSize: 24,
                  height: 1.2,
                ),
              ),
              for (final (titulo, cuerpo) in apartados) ...[
                const SizedBox(height: NexusSpacing.s4),
                // El rótulo en el instrumento y el cuerpo en la sans de lo que
                // se lee, como las explicaciones de Ajustes.
                Text(
                  titulo.toUpperCase(),
                  style: NexusTypography.label.copyWith(color: colors.mute),
                ),
                const SizedBox(height: 6),
                Text(
                  cuerpo,
                  style: NexusTypography.nota.copyWith(
                    color: colors.ink,
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
              ],
              const SizedBox(height: NexusSpacing.s4),
              Text(
                strings.guiaCortaMas,
                style: NexusTypography.nota.copyWith(
                  color: colors.mute,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: NexusSpacing.s4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(strings.guiaCortaEntendido.toUpperCase()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
