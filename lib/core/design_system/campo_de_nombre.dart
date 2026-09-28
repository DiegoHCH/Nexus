import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexus/core/design_system/boton_de_fila.dart';
import 'package:nexus/core/design_system/hoja_de_la_sala.dart';
import 'package:nexus/core/design_system/nexus_colors.dart';
import 'package:nexus/core/design_system/nexus_spacing.dart';
import 'package:nexus/core/design_system/nexus_typography.dart';
import 'package:nexus/core/i18n/strings_scope.dart';

/// Donde se escribe un nombre nuevo **en el mismo sitio donde estaba el
/// viejo**: la línea de 1 px del mockup —el campo «Nombre» de la hoja «···» del
/// teléfono— y, a su lado, «Cancelar · Guardar».
///
/// 🔴 **Sin diálogo**, como la papelera y el «Borrar» del historial: lo que se
/// renombra es lo que se está mirando, y un cuadro encima que repite el nombre
/// lo tapa justo cuando hace falta verlo. Lo usan los tres sitios desde los que
/// se renombra —el orbe pequeño del escenario, el historial y la fila de un
/// documento— para que el gesto sea el mismo en los tres.
///
/// Intro guarda y Esc deja las cosas como estaban, que es lo que se prueba
/// primero en un Mac. Nace con el foco y **con lo editable ya elegido** —ver
/// [seleccion]—, así que escribir sustituye sin tener que borrar antes.
class CampoDeNombre extends StatefulWidget {
  const CampoDeNombre({
    super.key,
    required this.inicial,
    required this.onGuardar,
    required this.onCancelar,
    this.sufijo,
    this.error,
    this.estilo,
    this.etiqueta,
    this.seleccion,
  });

  /// Lo que ya se llama, para cambiarlo y no escribirlo entero.
  final String inicial;
  final ValueChanged<String> onGuardar;
  final VoidCallback onCancelar;

  /// Lo que acompaña sin poder tocarse: la extensión de un documento.
  final String? sufijo;

  /// Por qué no vale lo escrito, debajo y en rojo. `null` mientras vale.
  final String? error;

  /// La letra de lo escrito: mono para un archivo —es un dato—, la del texto
  /// para una conversación.
  final TextStyle? estilo;

  /// El nombre del campo para el lector de pantalla.
  final String? etiqueta;

  /// Qué queda elegido al abrir. Por defecto, todo.
  final TextSelection? seleccion;

  @override
  State<CampoDeNombre> createState() => _CampoDeNombreState();
}

class _CampoDeNombreState extends State<CampoDeNombre> {
  late final _texto = TextEditingController(text: widget.inicial)
    ..selection =
        widget.seleccion ??
        TextSelection(baseOffset: 0, extentOffset: widget.inicial.length);

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final estilo = (widget.estilo ?? NexusTypography.body).copyWith(
      color: colors.ink,
    );
    final error = widget.error;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onCancelar,
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: error == null ? colors.accent : colors.err,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        // El nombre del campo, para el lector de pantalla: sin
                        // él, una línea sin rótulo no dice qué se está
                        // cambiando.
                        child: Semantics(
                          label: widget.etiqueta,
                          textField: true,
                          child: TextField(
                            controller: _texto,
                            autofocus: true,
                            onSubmitted: widget.onGuardar,
                            style: estilo,
                            cursorColor: colors.accent,
                            decoration: const InputDecoration(
                              isDense: true,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      if (widget.sufijo case final sufijo?
                          when sufijo.isNotEmpty)
                        Text(
                          sufijo,
                          style: estilo.copyWith(color: colors.mute),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: NexusSpacing.s2),
              BotonDeLaHoja(
                texto: strings.renombrarCancelar,
                onPulsar: widget.onCancelar,
              ),
              const SizedBox(width: NexusSpacing.s2),
              BotonDeLaHoja(
                texto: strings.renombrarGuardar,
                tono: TonoDeBoton.principal,
                onPulsar: () => widget.onGuardar(_texto.text),
              ),
            ],
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: NexusSpacing.s1),
              child: Text(
                error,
                style: NexusTypography.nota.copyWith(
                  color: colors.err,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
