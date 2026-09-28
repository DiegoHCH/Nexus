import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/personalidad/domain/la_personalidad.dart';
import 'package:nexus/features/personalidad/presentation/providers/la_personalidad_provider.dart';

/// La personalidad, escrita a mano en Ajustes › Nombres.
///
/// Una caja de texto larga y no un formulario de rasgos: lo que se escribe es
/// un carácter, y un carácter no cabe en cinco desplegables. Arranca con la de
/// la casa para que se vea qué forma tiene lo que hay que escribir.
class LaPersonalidadEnAjustes extends ConsumerStatefulWidget {
  const LaPersonalidadEnAjustes({super.key});

  static const laCaja = ValueKey('la-personalidad');

  @override
  ConsumerState<LaPersonalidadEnAjustes> createState() => _Estado();
}

class _Estado extends ConsumerState<LaPersonalidadEnAjustes> {
  // La plantilla en el idioma de la interfaz: se lee al montar, porque el
  // `context` todavía no se puede mirar en un inicializador.
  late final _controller = TextEditingController(
    text: ref.read(laPersonalidadProvider) ?? '',
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Una vez: si luego vacías la caja a propósito, no vuelve a rellenarse.
    if (_plantillaPuesta) return;
    _plantillaPuesta = true;
    if (_controller.text.isEmpty) {
      _controller.text = LaPersonalidad.plantilla(context.strings.idioma);
    }
  }

  var _plantillaPuesta = false;

  var _guardada = false;

  @override
  void initState() {
    super.initState();
    // Por si se editó el archivo por fuera mientras la app estaba abierta.
    ref.read(laPersonalidadProvider.notifier).releer();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _guardar(String? texto) async {
    await ref.read(laPersonalidadProvider.notifier).guardar(texto);
    if (mounted) setState(() => _guardada = true);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    // Lo leído del disco llega después de construir: se pone en la caja si
    // todavía no se ha tocado.
    ref.listen(laPersonalidadProvider, (_, leida) {
      if (leida != null && LaPersonalidad.esLaDeLaCasa(_controller.text)) {
        _controller.text = leida;
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: LaPersonalidadEnAjustes.laCaja,
          controller: _controller,
          minLines: 8,
          maxLines: 18,
          onChanged: (_) {
            if (_guardada) setState(() => _guardada = false);
          },
          style: NexusTypography.nota.copyWith(color: context.colors.ink),
          decoration: decoracionDeCampoDeAjustes(context, hint: ''),
        ),
        const SizedBox(height: 9),
        AccionesDeAjustes(
          botones: [
            BotonDeAjustes(
              texto: strings.personalidadGuardar,
              tono: TonoDeBoton.principal,
              onPulsar: () => _guardar(_controller.text),
            ),
            BotonDeAjustes(
              texto: strings.personalidadDeLaCasa,
              onPulsar: () async {
                _controller.text = LaPersonalidad.plantilla(
                  context.strings.idioma,
                );
                await _guardar(null);
              },
            ),
            BotonDeAjustes(
              texto: strings.personalidadAbrir,
              onPulsar: () => ref
                  .read(laPersonalidadProvider.notifier)
                  .abrirEnElEditor(_controller.text),
            ),
          ],
        ),
        if (_guardada) ...[
          const SizedBox(height: 9),
          EstadoDeAjustes(
            tono: TonoDeAjustes.bien,
            texto: strings.personalidadGuardada,
          ),
        ],
      ],
    );
  }
}
