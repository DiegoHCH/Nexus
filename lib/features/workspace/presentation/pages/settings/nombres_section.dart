import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/workspace/domain/entities/los_nombres.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

/// Cómo se llama quien contesta y cómo te llama a ti.
///
/// 🔴 **La app sigue llamándose Nexus, y eso se dice aquí.** El nombre del
/// producto está compilado dentro —Dock, ventana, identificador de los canales
/// nativos y del llavero— así que no es un ajuste. Lo que se elige es quién te
/// contesta, y quien abra esta pantalla esperando renombrar la app tiene que
/// salir sabiendo la diferencia sin haber probado nada.
class NombresSection extends ConsumerWidget {
  const NombresSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final nombres = ref.watch(losNombresProvider);

    return BloquesDeAjustes(
      bloques: [
        TextoDeAjustes(strings.nombresExplainer),
        BloqueDeAjustes(
          rotulo: strings.comoSeLlamaElAgente,
          hijos: [
            _UnNombre(
              pista: strings.comoSeLlamaElAgentePista,
              valor: nombres.agente,
              onGuardar: (valor) =>
                  ref.read(losNombresProvider.notifier).cambiar(agente: valor),
            ),
          ],
        ),
        BloqueDeAjustes(
          rotulo: strings.comoTeLlamas,
          hijos: [
            _UnNombre(
              pista: strings.comoTeLlamasPista,
              valor: nombres.tuyo,
              onGuardar: (valor) =>
                  ref.read(losNombresProvider.notifier).cambiar(tuyo: valor),
            ),
            // La vista previa: es lo único que convierte «te llamas Patricia»
            // en algo comprobable sin cerrar Ajustes y mandar un encargo.
            _ComoSeVera(nombres: nombres),
            // Decía que ponerle nombre no la despertaba, y desde que existe el
            // oído sí: el aviso en ámbar contaba una limitación que ya no
            // está. Ahora es una explicación, y va en el tono de las
            // explicaciones.
            TextoDeAjustes(strings.suNombreLaDespierta),
          ],
        ),
      ],
    );
  }
}

/// Un campo que **guarda al salir del foco**, no con un botón.
///
/// Dos campos con dos botones de guardar son cuatro clics para decir dos
/// palabras. Y guardar en cada tecla escribiría en preferencias una vez por
/// letra, que es ruido en el disco por nada.
class _UnNombre extends StatefulWidget {
  const _UnNombre({
    required this.pista,
    required this.valor,
    required this.onGuardar,
  });

  final String pista;
  final String? valor;

  /// Recibe `null` cuando el campo se deja vacío, que es cómo se borra.
  final void Function(Object? valor) onGuardar;

  @override
  State<_UnNombre> createState() => _UnNombreState();
}

class _UnNombreState extends State<_UnNombre> {
  late final _controller = TextEditingController(text: widget.valor ?? '');
  final _foco = FocusNode();

  @override
  void initState() {
    super.initState();
    _foco.addListener(() {
      if (!_foco.hasFocus) _guardar();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _foco.dispose();
    super.dispose();
  }

  void _guardar() {
    final escrito = _controller.text.trim();
    // Un `null` explícito borra el nombre; el centinela del `copyWith` es lo que
    // permite distinguirlo de «no lo toques».
    widget.onGuardar(escrito.isEmpty ? null : escrito);
  }

  // Una línea que se rellena y no una caja: el rótulo lo pone el bloque, y el
  // nombre es un dato —en mono, como en el mockup—.
  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    focusNode: _foco,
    style: estiloDeCampoDeAjustes(context),
    onSubmitted: (_) => _guardar(),
    decoration: decoracionDeCampoDeAjustes(context, hint: widget.pista),
  );
}

/// Un turno de mentira con los nombres puestos.
class _ComoSeVera extends StatelessWidget {
  const _ComoSeVera({required this.nombres});

  final LosNombres nombres;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    // Con los rótulos de siempre —«TÚ», «HESTIA»— y dentro de su caja, que
    // es lo que dice que esto se mira y no se toca.
    return CajaDeAjustes(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RotuloDeAjustes(strings.asiSeVera),
          const SizedBox(height: 8),
          RotuloDeAjustes(strings.you),
          const SizedBox(height: 4),
          Text(
            strings.ejemploDeLoQuePides(nombres.agente ?? strings.nexus),
            style: NexusTypography.body.copyWith(color: colors.ink),
          ),
          const SizedBox(height: 8),
          RotuloDeAjustes(nombres.etiqueta(strings.nexus)),
          const SizedBox(height: 4),
          Text(
            strings.ejemploDeLoQueContesta(nombres.vocativo),
            style: NexusTypography.body.copyWith(color: colors.mute),
          ),
        ],
      ),
    );
  }
}
