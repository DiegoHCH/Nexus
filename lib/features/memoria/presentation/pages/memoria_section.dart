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
    final colors = context.colors;
    final strings = context.strings;
    final cosas = ref.watch(loQueRecuerdaDeTiProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.memoriaExplainer,
            style: NexusTypography.mono.copyWith(color: colors.faint),
          ),
          const SizedBox(height: NexusSpacing.s5),
          if (cosas.isEmpty)
            Text(
              strings.laMemoriaVacia,
              style: NexusTypography.body.copyWith(color: colors.faint),
            )
          else
            for (final (i, cosa) in cosas.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: NexusSpacing.s3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cosa.texto,
                            style: NexusTypography.body.copyWith(
                              color: colors.ink,
                            ),
                          ),
                          Text(
                            ComoSeLeeUnTurno.laFechaYLaHora(cosa.cuando),
                            style: NexusTypography.label.copyWith(
                              color: colors.faint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: NexusSpacing.s3),
                    IconButton(
                      onPressed: () => ref
                          .read(loQueRecuerdaDeTiProvider.notifier)
                          .olvida(i),
                      icon: const Icon(Icons.close, size: 14),
                      color: colors.faint,
                      splashRadius: 14,
                      tooltip: strings.memoriaOlvidar,
                    ),
                  ],
                ),
              ),
          const SizedBox(height: NexusSpacing.s5),
          Text(
            strings.memoriaNota(LoQueSeSabeDeTi.cuantas),
            style: NexusTypography.mono.copyWith(color: colors.faint),
          ),
        ],
      ),
    );
  }
}
