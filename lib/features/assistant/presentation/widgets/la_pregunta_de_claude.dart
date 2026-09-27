import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/domain/entities/pregunta_de_claude.dart';
import 'package:nexus/features/assistant/domain/entities/peticion_de_permiso.dart';
import 'package:nexus/features/assistant/presentation/widgets/boton_del_registro.dart';

/// Una pregunta de Claude con sus opciones, **dentro del turno**.
///
/// Con la forma del permiso —el filo a la izquierda, la pregunta, las salidas
/// debajo— porque es lo mismo: Claude se para y espera a que decidas. Cambian
/// las salidas: aquí son las opciones que él propone, **la recomendada
/// marcada**, y una respuesta libre para cuando ninguna vale.
///
/// Con una sola pregunta de una sola opción, pulsar la opción ya contesta: un
/// «Responder» después sería un segundo clic para decir lo mismo. Con varias,
/// o con varias opciones a la vez, se elige todo y se responde una vez.
class LaPreguntaDeClaudeEnElChat extends StatefulWidget {
  const LaPreguntaDeClaudeEnElChat({
    super.key,
    required this.peticion,
    required this.decision,
    required this.respuestas,
    required this.onResponder,
    required this.onNoContestar,
  });

  final PeticionDePermiso peticion;
  final DecisionDePermiso? decision;
  final Map<String, String>? respuestas;
  final void Function(String id, Map<String, String> respuestas)? onResponder;
  final void Function(String id)? onNoContestar;

  static ValueKey<String> laOpcion(int pregunta, int opcion) =>
      ValueKey('opcion-$pregunta-$opcion');
  static ValueKey<String> laOtra(int pregunta) => ValueKey('otra-$pregunta');
  static const elBotonDeResponder = ValueKey('responder-la-pregunta');

  @override
  State<LaPreguntaDeClaudeEnElChat> createState() => _Estado();
}

class _Estado extends State<LaPreguntaDeClaudeEnElChat> {
  late final _preguntas = LaPreguntaDeClaude.de(widget.peticion);

  /// Lo elegido en cada pregunta, por su posición.
  late final _elegidas = [for (final _ in _preguntas) <int>{}];
  late final _otras = [for (final _ in _preguntas) TextEditingController()];

  @override
  void dispose() {
    for (final c in _otras) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _deUnToque =>
      _preguntas.length == 1 && !_preguntas.single.variasALaVez;

  String? _respuestaDe(int i) {
    final pregunta = _preguntas[i];
    final otra = _otras[i].text.trim();
    final elegidas = [
      for (final j in _elegidas[i].toList()..sort())
        pregunta.opciones[j].etiqueta,
    ];
    if (otra.isNotEmpty) elegidas.add(otra);
    return elegidas.isEmpty ? null : elegidas.join(', ');
  }

  bool get _todasContestadas => [
    for (var i = 0; i < _preguntas.length; i++) _respuestaDe(i),
  ].every((r) => r != null);

  void _responder() {
    final respuestas = <String, String>{
      for (var i = 0; i < _preguntas.length; i++)
        _preguntas[i].pregunta: ?_respuestaDe(i),
    };
    if (respuestas.length != _preguntas.length) return;
    widget.onResponder?.call(widget.peticion.id, respuestas);
  }

  void _elegir(int i, int j) {
    setState(() {
      final pregunta = _preguntas[i];
      if (pregunta.variasALaVez) {
        if (!_elegidas[i].remove(j)) _elegidas[i].add(j);
      } else {
        _elegidas[i]
          ..clear()
          ..add(j);
        _otras[i].clear();
      }
    });
    if (_deUnToque) _responder();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final contestada = widget.decision != null;

    return Padding(
      padding: const EdgeInsets.only(top: NexusSpacing.s2),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(NexusSpacing.s3, 6, 0, 6),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: contestada ? colors.rule2 : colors.accent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, pregunta) in _preguntas.indexed) ...[
              if (i > 0) const SizedBox(height: NexusSpacing.s4),
              if (pregunta.rotulo case final rotulo?)
                Text(
                  rotulo.toUpperCase(),
                  style: NexusTypography.label.copyWith(color: colors.mute),
                ),
              const SizedBox(height: 4),
              Text(
                pregunta.pregunta,
                style: NexusTypography.nota.copyWith(
                  color: colors.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: NexusSpacing.s2),
              if (contestada)
                _LoQueSeDijo(
                  texto: widget.respuestas?[pregunta.pregunta],
                  sinContestar: strings.preguntaSinContestar,
                )
              else ...[
                for (final (j, opcion) in pregunta.opciones.indexed)
                  _LaOpcion(
                    key: LaPreguntaDeClaudeEnElChat.laOpcion(i, j),
                    numero: j + 1,
                    opcion: opcion,
                    elegida: _elegidas[i].contains(j),
                    varias: pregunta.variasALaVez,
                    recomendada: strings.preguntaRecomendada,
                    onPulsar: widget.onResponder == null
                        ? null
                        : () => _elegir(i, j),
                  ),
                const SizedBox(height: 6),
                TextField(
                  key: LaPreguntaDeClaudeEnElChat.laOtra(i),
                  controller: _otras[i],
                  style: NexusTypography.nota.copyWith(color: colors.ink),
                  onChanged: (_) => setState(() {
                    if (!pregunta.variasALaVez) _elegidas[i].clear();
                  }),
                  onSubmitted: (_) {
                    if (_todasContestadas) _responder();
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: strings.preguntaOtra,
                    hintStyle: NexusTypography.nota.copyWith(
                      color: colors.faint,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ],
            ],
            if (!contestada) ...[
              const SizedBox(height: NexusSpacing.s2),
              Wrap(
                spacing: NexusSpacing.s2,
                runSpacing: NexusSpacing.s2,
                children: [
                  if (!_deUnToque || _otras.single.text.trim().isNotEmpty)
                    BotonDelRegistro(
                      key: LaPreguntaDeClaudeEnElChat.elBotonDeResponder,
                      texto: strings.preguntaResponder.toUpperCase(),
                      tono: TonoDeBoton.principal,
                      onPulsar: _todasContestadas && widget.onResponder != null
                          ? _responder
                          : null,
                    ),
                  BotonDelRegistro(
                    texto: strings.preguntaNoContestar.toUpperCase(),
                    onPulsar: widget.onNoContestar == null
                        ? null
                        : () => widget.onNoContestar!(widget.peticion.id),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Una opción: su número, lo que dice y por qué, y la marca si es la que
/// Claude recomienda. El relleno solo en la elegida.
class _LaOpcion extends StatefulWidget {
  const _LaOpcion({
    super.key,
    required this.numero,
    required this.opcion,
    required this.elegida,
    required this.varias,
    required this.recomendada,
    required this.onPulsar,
  });

  final int numero;
  final UnaOpcion opcion;
  final bool elegida;
  final bool varias;
  final String recomendada;
  final VoidCallback? onPulsar;

  @override
  State<_LaOpcion> createState() => _LaOpcionState();
}

class _LaOpcionState extends State<_LaOpcion> {
  var _encima = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final opcion = widget.opcion;
    final elegida = widget.elegida;

    return Semantics(
      button: true,
      selected: elegida,
      label: opcion.sinLaMarca,
      child: MouseRegion(
        cursor: widget.onPulsar == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _encima = true),
        onExit: (_) => setState(() => _encima = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPulsar,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: elegida
                  ? colors.accent.withValues(alpha: 0.12)
                  : _encima
                  ? colors.ink.withValues(alpha: 0.04)
                  : null,
              border: Border.all(color: elegida ? colors.accent : colors.rule),
              borderRadius: BorderRadius.circular(NexusRadius.sm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    widget.varias ? (elegida ? '☑' : '☐') : '${widget.numero}.',
                    style: NexusTypography.data.copyWith(
                      color: elegida ? colors.accent : colors.faint,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: NexusSpacing.s2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            opcion.sinLaMarca,
                            style: NexusTypography.nota.copyWith(
                              color: colors.ink,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (opcion.recomendada)
                            Text(
                              widget.recomendada.toUpperCase(),
                              style: NexusTypography.label.copyWith(
                                color: colors.accent,
                              ),
                            ),
                        ],
                      ),
                      if (opcion.descripcion case final d?
                          when d.trim().isNotEmpty)
                        Text(
                          d,
                          style: NexusTypography.nota.copyWith(
                            color: colors.mute,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Contestada: lo que se eligió, en su sitio, sin botones.
class _LoQueSeDijo extends StatelessWidget {
  const _LoQueSeDijo({required this.texto, required this.sinContestar});

  final String? texto;
  final String sinContestar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dicho = texto;
    return Row(
      children: [
        Icon(
          dicho == null ? Icons.block : Icons.check,
          size: 12,
          color: dicho == null ? colors.faint : colors.ok,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            dicho ?? sinContestar,
            style: NexusTypography.nota.copyWith(
              color: dicho == null ? colors.faint : colors.ink,
            ),
          ),
        ),
      ],
    );
  }
}
