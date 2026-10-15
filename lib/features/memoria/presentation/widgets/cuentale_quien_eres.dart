import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/memoria/domain/entities/las_preguntas_de_quien_eres.dart';
import 'package:nexus/features/memoria/presentation/providers/lo_que_recuerda_de_ti.dart';

/// Abre las preguntas. Devuelve cuántas respuestas quedaron apuntadas, o
/// `null` si se cerró sin guardar.
Future<int?> preguntarQuienEres(BuildContext context) => showDialog<int>(
  context: context,
  builder: (_) => const CuentaleQuienEres(),
);

/// **El arranque guiado**: una pregunta cada vez, con un ejemplo de respuesta.
///
/// Una cada vez y no un formulario de seis cajas: para quien no programa, una
/// pantalla con seis preguntas abiertas parece un examen. Así es una
/// conversación corta, y cualquiera se salta pulsando «Siguiente» con la caja
/// vacía.
class CuentaleQuienEres extends ConsumerStatefulWidget {
  const CuentaleQuienEres({super.key});

  static const llaveCaja = ValueKey('quien-eres-caja');
  static const llaveSiguiente = ValueKey('quien-eres-siguiente');
  static const llaveAtras = ValueKey('quien-eres-atras');

  @override
  ConsumerState<CuentaleQuienEres> createState() => _CuentaleQuienEresState();
}

class _CuentaleQuienEresState extends ConsumerState<CuentaleQuienEres> {
  final _temas = losTemasDeQuienEres();
  late final _cajas = [
    for (final _ in PreguntaDeQuienEres.values) TextEditingController(),
  ];
  var _cual = 0;
  var _guardando = false;

  @override
  void initState() {
    super.initState();
    _rellena();
    // Si la memoria aún se estaba leyendo, lo de antes llega después.
    unawaited(
      ref.read(loQueRecuerdaDeTiProvider.notifier).leida.then((_) {
        if (mounted) _rellena();
      }),
    );
  }

  /// Contestar otra vez empieza **desde lo que ya contestaste**: con las cajas
  /// vacías, pulsar «Guardar» borraría lo de antes sin querer.
  void _rellena() {
    final notas = ref.read(loQueRecuerdaDeTiProvider);
    for (final (i, caja) in _cajas.indexed) {
      if (caja.text.isNotEmpty) continue;
      final habia = LasPreguntasDeQuienEres.laQueHabia(notas, _temas[i]);
      if (habia != null) caja.text = habia;
    }
  }

  @override
  void dispose() {
    for (final caja in _cajas) {
      caja.dispose();
    }
    super.dispose();
  }

  bool get _esLaUltima => _cual == _cajas.length - 1;

  void _siguiente() {
    if (_esLaUltima) {
      unawaited(_guardar());
      return;
    }
    setState(() => _cual++);
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    setState(() => _guardando = true);
    final preguntas = context.strings.quienEresPreguntas;
    final respuestas = [
      for (final (i, caja) in _cajas.indexed)
        (tema: preguntas[i].tema, temas: _temas[i], respuesta: caja.text),
    ];
    await ref
        .read(loQueRecuerdaDeTiProvider.notifier)
        .contesta(respuestas, DateTime.now());
    if (!mounted) return;
    Navigator.of(
      context,
    ).pop(respuestas.where((una) => una.respuesta.trim().isNotEmpty).length);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final pregunta = strings.quienEresPreguntas[_cual];
    return AlertDialog(
      title: Text(strings.quienEresTitulo),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_cual == 0) ...[
              Text(
                strings.quienEresExplica,
                style: NexusTypography.nota.copyWith(color: colors.mute),
              ),
              const SizedBox(height: NexusSpacing.s5),
            ],
            Text(
              strings.quienEresCuenta(_cual + 1, _cajas.length).toUpperCase(),
              style: NexusTypography.label.copyWith(color: colors.accent),
            ),
            const SizedBox(height: NexusSpacing.s2),
            Text(
              pregunta.pregunta,
              style: NexusTypography.lead.copyWith(color: colors.ink),
            ),
            const SizedBox(height: NexusSpacing.s3),
            TextField(
              // Una caja por pregunta: con la misma, el texto de una se
              // quedaba en la siguiente al pasar.
              key: ValueKey('${CuentaleQuienEres.llaveCaja.value}-$_cual'),
              controller: _cajas[_cual],
              autofocus: true,
              minLines: 1,
              maxLines: 4,
              // Texto y no multilínea: así Intro pasa a la siguiente en vez
              // de partir la línea, que es lo que se espera en un cuestionario.
              keyboardType: TextInputType.text,
              textInputAction: _esLaUltima
                  ? TextInputAction.done
                  : TextInputAction.next,
              onSubmitted: (_) => _siguiente(),
              inputFormatters: [
                LengthLimitingTextInputFormatter(
                  LasPreguntasDeQuienEres.maxPorRespuesta,
                ),
              ],
              style: NexusTypography.body.copyWith(color: colors.ink),
              decoration: InputDecoration(
                hintText: pregunta.pista,
                hintMaxLines: 2,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        if (_cual > 0)
          TextButton(
            key: CuentaleQuienEres.llaveAtras,
            onPressed: () => setState(() => _cual--),
            child: Text(strings.quienEresAtras.toUpperCase()),
          ),
        TextButton(
          key: CuentaleQuienEres.llaveSiguiente,
          onPressed: _guardando ? null : _siguiente,
          child: Text(
            (_esLaUltima
                    ? strings.quienEresGuardar
                    : strings.quienEresSiguiente)
                .toUpperCase(),
          ),
        ),
      ],
    );
  }
}
