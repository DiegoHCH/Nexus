import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/domain/usecases/como_se_lee_un_turno.dart';
import 'package:nexus/features/memoria/domain/entities/lo_que_se_sabe_de_ti.dart';
import 'package:nexus/features/memoria/presentation/providers/lo_que_recuerda_de_ti.dart';

/// Lo que Nexus sabe de ti, entero y borrable.
///
/// 🔴 **Se enseña completo a propósito.** Esto viaja en el prompt de **cada**
/// encargo, en tu nombre, así que esconderlo sería lo único que no se puede
/// hacer con una memoria: que no puedas ver qué se está diciendo de ti. Aquí
/// está tal cual se manda, con la fecha en que se apuntó —para que puedas
/// decidir si algo de hace dos meses sigue siendo verdad— y con su cruz.
class MemoriaSection extends ConsumerWidget {
  const MemoriaSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final cosas = ref.watch(loQueRecuerdaDeTiProvider);

    // Un solo bloque, como en el mockup: la explicación, las filas y la nota
    // de lo que cuesta van juntas porque son la misma pregunta —qué sabe de
    // ti—, y una línea entre ellas las separaría.
    return BloquesDeAjustes(
      bloques: [
        BloqueDeAjustes(
          hijos: [
            TextoDeAjustes(strings.memoriaExplainer),
            if (cosas.isEmpty)
              TextoDeAjustes(strings.laMemoriaVacia)
            else
              FilasDeAjustes(
                filas: [
                  for (final (i, cosa) in cosas.indexed)
                    FilaDeAjustes(
                      tono: TonoDeAjustes.apagado,
                      titulo: cosa.texto,
                      // 🔴 **La fecha se queda, aunque el mockup no la
                      // pinte.** Es lo que deja decidir si algo apuntado hace
                      // dos meses sigue siendo verdad, y sin ella todas las
                      // filas parecen de hoy.
                      dato: ComoSeLeeUnTurno.laFechaYLaHora(cosa.cuando),
                      accion: BotonDeAjustes(
                        texto: strings.memoriaOlvidar,
                        tono: TonoDeBoton.peligro,
                        onPulsar: () => ref
                            .read(loQueRecuerdaDeTiProvider.notifier)
                            .olvida(i),
                      ),
                    ),
                ],
              ),
            NotaDeAjustes(strings.memoriaNota(LoQueSeSabeDeTi.cuantas)),
          ],
        ),
      ],
    );
  }
}
