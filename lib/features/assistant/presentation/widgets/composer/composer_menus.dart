import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/presentation/providers/model_providers.dart';
import 'package:nexus/features/workspace/presentation/pages/settings_page.dart';
import 'package:nexus/features/assistant/presentation/state/session_meter.dart';
import 'package:nexus/features/stats/domain/usecases/model_label.dart';
import 'package:nexus/features/workspace/data/datasources/claude_profiles_data_source.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/updates/presentation/widgets/pending_dot.dart';
import 'package:nexus/features/assistant/presentation/providers/assistant_controller.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

/// Los tres menús del compositor: adjuntar y ajustes, el modelo, y el esfuerzo.
///
/// Juntos porque son la misma forma repetida tres veces —un `PopupMenuButton` con
/// sus filas— y separarlos en tres archivos habría multiplicado los imports sin
/// que ninguno pese lo suficiente para vivir solo.

/// El «+»: lo que se añade a lo que estás pidiendo.
///
/// Adjuntar es **señalar una ruta**, no subir un archivo a ningún sitio: Claude
/// trabaja en tu disco y lee lo que le señales, así que copiar el contenido
/// sería duplicarlo y perder el vínculo con el original.
///
/// Lo que se añade por aquí y lo que se suelta arrastrando acaban en el mismo
/// sitio —la tira de miniaturas—, porque son el mismo gesto dicho de dos
/// formas.
class MoreMenu extends ConsumerWidget {
  const MoreMenu({super.key, required this.onAttach});

  final void Function(Iterable<String>) onAttach;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;

    // Mismo caso que el círculo del cupo: sin globo se quedó sin etiqueta, y
    // este es el único camino para adjuntar sin arrastrar un archivo.
    return Semantics(
      button: true,
      label: context.strings.attachFile,
      child: PopupMenuButton<String>(
        color: colors.deep,
        tooltip: '',
        onSelected: (value) async {
          switch (value) {
            case 'file':
              // Varios de una vez, como al arrastrar: elegir tres archivos de una
              // carpeta y tener que abrir el diálogo tres veces es de las cosas
              // que hacen que nadie use el botón.
              final files = await openFiles();
              if (files.isNotEmpty) onAttach(files.map((file) => file.path));
            case 'folder':
              await ref.read(workspaceControllerProvider.notifier).pairFolder();
            case 'parte':
              // El parte del último día con trabajo. Va en este menú y no como
              // un botón suelto: se pide una vez al día, y lo que se usa una
              // vez al día no merece sitio fijo en la barra.
              // La conversación enfocada, leída aquí y no pasada desde arriba:
              // el compositor no la conoce, y hacerla bajar dos capas para un
              // menú sería cablear media pantalla por un elemento de lista.
              final cual = ref.read(conversationsProvider).focusedId;
              if (cual == null) return;
              final hubo = await ref
                  .read(assistantControllerProvider(cual).notifier)
                  .pedirElParte();
              if (!hubo && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.strings.parteSinDia)),
                );
              }
            case 'settings':
              if (context.mounted) await SettingsPage.open(context);
          }
        },
        itemBuilder: (context) => [
          _item('file', Icons.attach_file, strings.attachFile, colors),
          _item(
            'folder',
            Icons.create_new_folder_outlined,
            strings.addFolderShort,
            colors,
          ),
          _item(
            'parte',
            Icons.calendar_today_outlined,
            strings.parteDelDia,
            colors,
          ),
          _item('settings', Icons.tune, strings.openSettings, colors),
        ],
        // Con punto rojo mientras quede una versión sin instalar: Ajustes vive
        // dentro de este menú, así que el aviso va pegado al camino que lleva a
        // la actualización.
        child: PendingDot(
          child: Icon(Icons.add, size: 16, color: colors.faint),
        ),
      ),
    );
  }

  PopupMenuItem<String> _item(
    String value,
    IconData icon,
    String label,
    NexusColors colors,
  ) => PopupMenuItem<String>(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 14, color: colors.faint),
        const SizedBox(width: NexusSpacing.s3),
        Text(label, style: NexusTypography.control.copyWith(color: colors.ink)),
      ],
    ),
  );
}

/// El modelo con el que va a trabajar esta carpeta: con el nombre que dio el
/// CLI si ya corrió —`claude-opus-5-5`— o con el alias pedido si no —`opus`—.
///
/// Lo que dijo el CLI vale **mientras sea de la familia que se pide**: si
/// acabas de pasar de Opus a Sonnet, el último turno sigue diciendo Opus, y
/// enseñarlo sería decir que el cambio no se hizo.
String? _modeloEnUso(WidgetRef ref, PairedFolder? folder, SessionMeter meter) {
  final perfil = ref.watch(claudeDefaultsProvider(folder?.claudeProfile)).value;
  final pedido = folder?.claudeModel ?? perfil?.model;
  // Una versión pedida por su nombre entero es exactamente esa: lo que dijera
  // el último turno es de antes de elegirla.
  if (pedido != null && pedido.startsWith('claude-')) return pedido;
  final visto =
      meter.displayModel ??
      // Un perfil puede no fijar modelo —`private` no lo hace—: entonces vale
      // el último con el que se le vio trabajar. **Solo entonces**: con un
      // modelo pedido, ese recuerdo es de otra versión —decía «Opus 5» con el
      // CLI ya en Opus 5.5—.
      (pedido == null
          ? ref.watch(seenModelsProvider)[folder?.claudeProfile ??
                'por-defecto']
          : null);
  final familia = ClaudeModel.fromCliName(pedido);
  if (visto != null &&
      (pedido == null || ClaudeModel.fromCliName(visto) == familia)) {
    return visto;
  }
  // Sin turno todavía, el alias no dice versión. Pero `/effort` guarda sus
  // ajustes con el nombre entero, así que si el perfil tiene alguno de esa
  // familia, el más nuevo es a quien apunta el alias.
  final conocidos = [
    for (final modelo in perfil?.effortPorModelo.keys ?? const <String>[])
      if (familia != null && ClaudeModel.fromCliName(modelo) == familia) modelo,
  ]..sort();
  if (conocidos.isNotEmpty) return conocidos.last;
  return pedido ?? visto;
}

/// Qué modelo usa Claude **en este perfil**.
///
/// 🔴 **Elegir aquí es lo mismo que `/model` en la consola**: se escribe en el
/// `settings.json` del perfil, que es lo que leen los dos. Antes se guardaba
/// por carpeta y viajaba como `--model`, así que Nexus y la consola podían ir
/// cada uno con un modelo sin que ninguno lo dijera. El precio, que es el que
/// se pidió: cambia para **todas** las carpetas de ese perfil.
class ModelMenu extends ConsumerWidget {
  const ModelMenu({super.key, required this.folder, required this.meter});

  final PairedFolder? folder;
  final SessionMeter meter;

  /// El valor de «por defecto» en el menú. No puede ser `null`: un menú que
  /// devuelve `null` lo toma por cerrado sin elegir.
  static const _porDefecto = '';

  /// Los alias, en el orden del `/model` del CLI.
  static const _alias = [
    ClaudeModel.opus,
    ClaudeModel.fable,
    ClaudeModel.sonnet,
    ClaudeModel.haiku,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final perfil = ref
        .watch(claudeDefaultsProvider(folder?.claudeProfile))
        .value;
    final enUso = _modeloEnUso(ref, folder, meter);
    final pedido = folder?.claudeModel ?? perfil?.model;
    // Con la versión que dio el CLI —«Opus 5.5»— cuando se sabe, y si no la
    // familia: el alias no dice versión y no hay que inventarla.
    final nombre = enUso == null
        ? null
        : enUso.startsWith('claude-')
        ? modelLabel(enUso)
        : ClaudeModel.fromCliName(enUso)?.label ?? enUso;

    // Los nombres enteros que este perfil ya ha usado: de ahí sale a qué
    // versión apunta hoy cada alias, sin escribirlo a mano.
    final conocidos = {
      ...?perfil?.effortPorModelo.keys,
      ...ref.watch(seenModelsProvider).values,
      ?enUso,
    }.map(PerfilDeClaude.nombreCanonico).where((m) => m.startsWith('claude-'));
    String etiquetaDe(ClaudeModel alias) {
      final suyos = [
        for (final modelo in conocidos)
          if (ClaudeModel.fromCliName(modelo) == alias &&
              !versionesAnteriores.contains(modelo))
            modelo,
      ]..sort();
      return suyos.isEmpty ? alias.label : modelLabel(suyos.last);
    }

    PopupMenuItem<String> opcion(String valor, String etiqueta) =>
        PopupMenuItem<String>(
          value: valor,
          child: Row(
            children: [
              Text(
                etiqueta,
                style: NexusTypography.control.copyWith(color: colors.ink),
              ),
              if (valor == (pedido ?? _porDefecto)) ...[
                const SizedBox(width: NexusSpacing.s3),
                Icon(Icons.check, size: 13, color: colors.accent),
              ],
            ],
          ),
        );

    return PopupMenuButton<String>(
      color: colors.deep,
      tooltip: '',
      onSelected: (valor) => unawaited(
        elegirModelo(
          ref,
          configDir: folder?.claudeProfile,
          carpeta: folder?.path,
          modelo: valor == _porDefecto ? null : valor,
        ).catchError(
          (Object error) => debugPrint('modelo · no se pudo guardar: $error'),
        ),
      ),
      // 🔴 **Las mismas tres partes que el `/model` del CLI**, y por el mismo
      // motivo: el de por defecto, el último de cada familia por su alias, y
      // las versiones anteriores por su nombre entero. Con solo los alias, lo
      // que la consola ofrecía no se podía elegir aquí.
      itemBuilder: (context) => [
        opcion(_porDefecto, strings.modelPorDefecto),
        for (final alias in _alias) opcion(alias.alias, etiquetaDe(alias)),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          enabled: false,
          height: 28,
          child: Text(
            strings.modelVersionesAnteriores,
            style: NexusTypography.control.copyWith(color: colors.faint),
          ),
        ),
        for (final modelo in versionesAnteriores)
          opcion(modelo, modelLabel(modelo)),
      ],
      child: Text(
        nombre ?? strings.modelTitle,
        style: NexusTypography.label.copyWith(
          // Más visible cuando lo fija el repo: ahí manda `.nexus/config.json`
          // y no el perfil, y conviene que se note.
          color: folder?.claudeModel == null ? colors.faint : colors.mute,
        ),
      ),
    );
  }
}

/// Cuánto razona antes de contestar, de más rápido a más listo.
///
/// Como el modelo, es **del perfil** y va **por modelo**: `/effort` lo guarda
/// en `modelSettings.<modelo>.effortLevel`, y aquí se lee y se escribe lo
/// mismo. Ver [ModelMenu].
class EffortMenu extends ConsumerWidget {
  const EffortMenu({super.key, required this.folder, required this.meter});

  final PairedFolder? folder;
  final SessionMeter meter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final perfil = ref
        .watch(claudeDefaultsProvider(folder?.claudeProfile))
        .value;
    final enUso = _modeloEnUso(ref, folder, meter);
    // Solo con nombre de verdad se sabe bajo qué modelo guardarlo: con el
    // alias a secas se usa el general.
    final modelo = enUso != null && enUso.startsWith('claude-') ? enUso : null;
    // El vigente: el que fije el repo, o el que el perfil tenga para ese
    // modelo.
    final vigente = ClaudeEffort.fromStored(
      folder?.claudeEffort ?? perfil?.esfuerzoPara(modelo),
    );

    return PopupMenuButton<ClaudeEffort>(
      color: colors.deep,
      tooltip: '',
      onSelected: (option) => unawaited(
        elegirEsfuerzo(
          ref,
          configDir: folder?.claudeProfile,
          carpeta: folder?.path,
          esfuerzo: option,
          modeloEnUso: modelo,
        ).catchError(
          (Object error) => debugPrint('esfuerzo · no se pudo guardar: $error'),
        ),
      ),
      itemBuilder: (context) => [
        for (final option in ClaudeEffort.values)
          PopupMenuItem<ClaudeEffort>(
            value: option,
            child: Row(
              children: [
                Text(
                  option.flag,
                  style: NexusTypography.control.copyWith(color: colors.ink),
                ),
                const SizedBox(width: NexusSpacing.s3),
                // Los extremos se nombran, porque «xhigh» no dice por sí solo
                // hacia qué lado tira.
                if (option == ClaudeEffort.low)
                  Text(
                    strings.effortFaster,
                    style: NexusTypography.nota.copyWith(color: colors.faint),
                  ),
                if (option == ClaudeEffort.max)
                  Text(
                    strings.effortSmarter,
                    style: NexusTypography.nota.copyWith(color: colors.faint),
                  ),
                if (option == vigente) ...[
                  const SizedBox(width: NexusSpacing.s3),
                  Icon(Icons.check, size: 13, color: colors.accent),
                ],
              ],
            ),
          ),
      ],
      child: Text(
        vigente?.flag ?? strings.effortTitle,
        style: NexusTypography.label.copyWith(
          color: folder?.claudeEffort == null ? colors.faint : colors.mute,
        ),
      ),
    );
  }
}
