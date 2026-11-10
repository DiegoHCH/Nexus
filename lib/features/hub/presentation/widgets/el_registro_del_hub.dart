import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/run/domain/usecases/el_error_que_pinta_la_app.dart';

/// **El registro de la corrida, abajo**: la tercera parte de la mesa.
///
/// Lo mismo que la ventana del registro de hoy, aquí dentro: las últimas 200
/// líneas de `flutter run`, en rojo las que son un error de la app
/// ([ElErrorQuePintaLaApp.pintaMal], el mismo criterio) y «copiar». Sigue el
/// final mientras no subas a leer algo, y se pliega —no se va— cuando hace
/// falta el sitio para la pantalla.
class ElRegistroDelHub extends StatefulWidget {
  const ElRegistroDelHub({
    super.key,
    required this.lineas,
    required this.hayCorrida,
  });

  final List<String> lineas;
  final bool hayCorrida;

  static const alto = 150.0;

  @override
  State<ElRegistroDelHub> createState() => _ElRegistroDelHubState();
}

class _ElRegistroDelHubState extends State<ElRegistroDelHub> {
  final _scroll = ScrollController();
  bool _plegado = false;
  bool _copiado = false;

  /// Si se está mirando el final: entonces una línea nueva lo baja. Si se subió
  /// a leer algo, se queda donde está.
  bool _alFinal = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      final p = _scroll.position;
      _alFinal = p.pixels >= p.maxScrollExtent - 24;
    });
  }

  @override
  void didUpdateWidget(ElRegistroDelHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_alFinal && widget.lineas.length != oldWidget.lineas.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: widget.lineas.join('\n')));
    if (!mounted) return;
    setState(() => _copiado = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copiado = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final lineas = widget.lineas;

    final cabecera = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: NexusSpacing.s4,
        vertical: NexusSpacing.s1 + 2,
      ),
      child: Row(
        children: [
          Text(
            strings.hubRegistro.toUpperCase(),
            style: NexusTypography.label.copyWith(color: colors.faint),
          ),
          const SizedBox(width: NexusSpacing.s3),
          Text(
            widget.hayCorrida
                ? strings.hubLineas(lineas.length)
                : strings.hubSinCorrida,
            style: NexusTypography.data.copyWith(color: colors.faint),
          ),
          const Spacer(),
          if (widget.hayCorrida && lineas.isNotEmpty && !_plegado)
            TextButton(
              onPressed: _copiar,
              child: Text(
                (_copiado ? strings.hubCopiado : strings.hubCopiar)
                    .toUpperCase(),
                style: NexusTypography.boton.copyWith(color: colors.accent),
              ),
            ),
          if (widget.hayCorrida)
            IconButton(
              tooltip: _plegado ? strings.hubDesplegar : strings.hubPlegar,
              visualDensity: VisualDensity.compact,
              iconSize: 16,
              color: colors.accent,
              onPressed: () => setState(() => _plegado = !_plegado),
              icon: Icon(
                _plegado
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
              ),
            ),
        ],
      ),
    );

    final abierto = widget.hayCorrida && !_plegado;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.deep,
        border: Border(top: BorderSide(color: colors.rule)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cabecera,
          if (abierto)
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.rule)),
              ),
              child: SizedBox(
                height: ElRegistroDelHub.alto,
                child: lineas.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(NexusSpacing.s4),
                        child: Text(
                          strings.hubSinLineas,
                          style: NexusTypography.data.copyWith(
                            color: colors.faint,
                          ),
                        ),
                      )
                    : SelectionArea(
                        child: ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.symmetric(
                            horizontal: NexusSpacing.s4,
                            vertical: NexusSpacing.s1 + 2,
                          ),
                          itemCount: lineas.length,
                          itemBuilder: (context, i) => Text(
                            lineas[i],
                            style: NexusTypography.data.copyWith(
                              fontSize: 11.5,
                              height: 1.55,
                              color: ElErrorQuePintaLaApp.pintaMal(lineas[i])
                                  ? colors.err
                                  : colors.mute,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
