import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/artifacts/presentation/providers/artifacts_providers.dart';
import 'package:nexus/features/artifacts/presentation/widgets/artifacts_sheet.dart';
import 'package:nexus/features/assistant/domain/usecases/la_sesion_que_se_comparte.dart';
import 'package:nexus/features/assistant/presentation/providers/assistant_controller.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

/// Dónde estás: carpeta, repositorio, rama, cuenta y memoria compartida.
///
/// Las fichas y **las piezas que las hacen funcionar** —el menú de la carpeta,
/// el del repo, qué cuenta se dice y qué se dice de la memoria compartida—, que
/// usan dos sitios: estas fichas, en la casa sin ninguna conversación, y la
/// esquina de arriba a la izquierda de la sala, con una abierta.

/// Dónde estás, en fila: carpeta, repositorio, rama, cuenta y si se le puede
/// hablar a este proyecto.
///
/// La carpeta **se puede cambiar desde aquí**: antes, sin ninguna emparejada,
/// esto era una etiqueta que decía que no había carpeta y no hacía nada — un
/// cartel en el sitio donde uno va a arreglarlo.
///
/// 🔴 **Ya solo en la casa sin conversación.** En el panel del chat se quitó
/// (30 sep) porque decía lo mismo que la esquina de la sala, a un palmo:
/// «ya en la pantalla principal, en la parte superior izquierda, ya sale». Lo
/// que estas fichas **hacían** —cambiar de carpeta, de repo, separar la
/// memoria— se mudó con ellas a la esquina. Aquí siguen porque sin
/// conversación no hay sala con esquinas: es el único sitio donde se ve a qué
/// carpeta irá lo que escribas.
class ComposerChips extends ConsumerWidget {
  const ComposerChips({
    super.key,
    required this.folder,
    this.folderPath,
    this.alSepararse,
  });

  /// Qué hacer cuando se pide separar esta conversación de la carpeta.
  ///
  /// Llega de fuera porque este widget no sabe de qué conversación es: la
  /// carpeta sí la recibe, el identificador no, y pedírselo solo para esto
  /// sería ensanchar su contrato por un botón.
  final VoidCallback? alSepararse;

  final PairedFolder? folder;

  /// La carpeta de **esta** conversación, emparejada o no. Hace falta aparte
  /// porque «sin proyecto» trabaja sobre la carpeta de documentos, que no está
  /// emparejada y por tanto no aparece como `PairedFolder`.
  final String? folderPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final paired = folder;
    final suelta = esSinProyecto(ref, folderPath);
    // La rama es la del sitio donde va a trabajar Claude, que con una raíz de
    // varios repos no es la carpeta emparejada sino el repo elegido.
    final git = paired == null
        ? null
        : ref.watch(gitInfoProvider(paired.workingDirectory)).value;
    final repos = paired == null
        ? const <String>[]
        : ref.watch(reposInsideProvider(paired.path)).value ?? const [];
    final comparten = cuantasCompartenLaSesion(ref, folderPath);
    final cuenta = laCuentaQueSeEnsena(ref, paired);

    // En `Wrap` y no en fila: en una ventana estrecha, la cuenta y las
    // conversaciones que comparten memoria bajan a otra línea en vez de
    // salirse por el borde.
    return Wrap(
      runSpacing: NexusSpacing.s2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        MenuDeLaCarpeta(
          folder: paired,
          folderPath: folderPath,
          child: _Chip(
            label: suelta
                ? strings.noProject
                : paired?.name ?? strings.chooseFolder,
            // Sin proyecto no es un aviso: es una elección legítima, y pintarla
            // en ámbar la haría parecer un estado a medio arreglar.
            warn: paired == null && !suelta,
            // La carpeta es **dónde** se trabaja: la primera y en tinta, como
            // en el mockup. Lo demás la matiza.
            principal: true,
          ),
        ),
        // Con varios repos dentro, el chip elige. Ver [MenuDelRepo].
        if (repos.length > 1 && paired != null)
          MenuDelRepo(
            carpeta: paired,
            repos: repos,
            child: _Chip(label: git?.repository ?? paired.name),
          )
        else if (git != null) ...[
          // El repositorio aparte de la carpeta porque no siempre coinciden: se
          // puede trabajar sobre un subdirectorio de un repo, y entonces la
          // carpeta dice una cosa y el repo otra.
          _Chip(label: git.repository),
        ],
        // La rama, a secas. **Abría la hoja de la corrida y ya no**: eso era del marco
        // flow, que se fue entero al plugin.
        if (git?.branch case final branch?) _Chip(label: branch),
        if (git == null && paired != null)
          // Sin repositorio no hay nada que deshacer, y eso hay que decirlo
          // donde se ve el permiso: es la red de seguridad que falta.
          _Chip(label: strings.noGitRepo, warn: true),
        if (cuenta != null) _Chip(label: cuenta),
        if (comparten > 1)
          _Chip(
            label: laMemoriaCompartida(ref, strings, folderPath!, comparten),
            explica: strings.tocaParaSepararla,
            alTocar: alSepararse,
          ),
        // La modalidad de voz no se repite aquí: se decide por carpeta en
        // Ajustes, y tenerla también en la barra creaba dos sitios que decían
        // lo mismo con distinta forma —uno como estado, el otro como
        // interruptor— y se contradecían a la vista.
      ],
    );
  }
}

/// Si [folderPath] es «sin proyecto»: la carpeta de documentos.
///
/// No es un modo aparte con reglas propias —sería otra cosa que mantener—, es
/// una carpeta más, la que ya elegiste para lo que sale de las conversaciones.
bool esSinProyecto(WidgetRef ref, String? folderPath) =>
    folderPath != null && folderPath == ref.watch(artifactsFolderProvider);

/// La cuenta de Claude de [carpeta], **solo si hay que decirla**: con una sola
/// cuenta en el Mac, decir cuál se usa es contestar una pregunta que nadie
/// tiene. `null` cuando no se dice.
///
/// Aparte porque la dicen dos sitios —las fichas de la casa y la esquina de la
/// sala— y los dos tienen que callarse igual.
String? laCuentaQueSeEnsena(WidgetRef ref, PairedFolder? carpeta) {
  final cuentas = ref.watch(claudeProfilesProvider).value;
  if (cuentas == null || cuentas.length <= 1) return null;
  final perfil = carpeta?.claudeProfile?.split('/').last;
  if (perfil == null || !perfil.startsWith('.claude-')) return null;
  return perfil.substring(8);
}

/// Cuántas conversaciones abiertas comparten la sesión de [folderPath]. Ver
/// [LaSesionQueSeComparte].
int cuantasCompartenLaSesion(WidgetRef ref, String? folderPath) =>
    folderPath == null
    ? 0
    : LaSesionQueSeComparte.cuantasComparten(
        ref
            .watch(conversationsProvider)
            .items
            .map((i) => (carpeta: i.folderPath, propia: i.memoriaPropia)),
        folderPath,
      );

/// Qué se dice de la memoria que se comparte.
///
/// 🔴 **Que este chat no es un hilo aparte.** La sesión de Claude es de la
/// carpeta, así que dos conversaciones sobre el mismo repo reanudan **la
/// misma**: comparten el contexto del modelo, lo pedido y el permiso concedido.
/// Lo que no comparten es lo que se ve —cada una guarda su transcripción—, o
/// sea dos historiales encima de una sola memoria. Se vio en vivo: un chat
/// nuevo avisó «ojo que cambiaste de rama», y ese dato venía de la sesión del
/// anterior.
///
/// Solo con más de una —ver [cuantasCompartenLaSesion]— y **solo si esta sigue
/// compartiendo**. Se reportó al revés: «por más que le doy empezar de cero, si
/// tengo las dos conversaciones abiertas sigue saliendo el chip».
///
/// 🔴 **El tiempo verbal.** Sin sesión guardada todavía no comparten nada: la
/// crea la primera que escriba y la segunda se engancha. Decirlo en presente
/// era afirmar algo que aún no había pasado —reportado así: «no hay sesión pero
/// si abro otra conversación me sigue saliendo el chip»—.
String laMemoriaCompartida(
  WidgetRef ref,
  NexusStrings strings,
  String folderPath,
  int comparten,
) => (ref.watch(laCarpetaTieneSesionProvider(folderPath)).value ?? true)
    ? strings.memoriaCompartida(comparten)
    : strings.memoriaQueSeCompartira(comparten);

/// Dónde se trabaja, **y cambiarlo**: el menú con las carpetas emparejadas,
/// «sin proyecto» y emparejar una nueva, colgado de [child].
///
/// Aparte de las fichas porque lo cuelgan dos sitios con aspecto distinto: la
/// ficha de la casa sin conversación y la esquina de la sala.
class MenuDeLaCarpeta extends ConsumerWidget {
  const MenuDeLaCarpeta({
    super.key,
    required this.folder,
    required this.folderPath,
    required this.child,
  });

  final PairedFolder? folder;

  /// Ver [ComposerChips.folderPath].
  final String? folderPath;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final workspace = ref.watch(workspaceControllerProvider);
    final paired = folder;
    final documentos = ref.watch(artifactsFolderProvider);
    final suelta = esSinProyecto(ref, folderPath);

    return PopupMenuButton<String>(
      color: colors.deep,
      tooltip: '',
      onSelected: (value) async {
        if (value == '__pair__') {
          await ref.read(workspaceControllerProvider.notifier).pairFolder();
          return;
        }
        if (value == '__loose__') {
          // Sin carpeta de documentos todavía no hay dónde trabajar, así
          // que se abre justo la ventana donde se elige, en vez de un
          // aviso que manda a buscarla.
          if (documentos == null) {
            if (context.mounted) await ArtifactsSheet.open(context);
            return;
          }
          value = documentos;
        }
        final abierta = ref.read(conversationsProvider).focused;
        if (abierta == null) {
          // Sin ninguna abierta no se crea nada: se apunta la carpeta y la
          // conversación nacerá cuando escribas o hables. Crear una aquí
          // llenaría el dock de conversaciones vacías cada vez que miras
          // dónde ibas a trabajar.
          //
          // Lo que sí tiene que valer es **esa** carpeta y no otra: la que
          // se apunte aquí es la que se usa al escribir.
          await ref.read(workspaceControllerProvider.notifier).setActive(value);
          return;
        }

        final dicho = ref
            .read(assistantControllerProvider(abierta.id))
            .messages
            .isEmpty;
        if (dicho) {
          // Vacía: se mueve, y con ella su nombre en el dock. Es corregir
          // el rumbo antes de empezar, no empezar otra cosa.
          await ref
              .read(conversationsProvider.notifier)
              .moveTo(abierta.id, value);
        } else {
          // Con algo hablado, la nueva carpeta merece su propia
          // conversación: la de al lado tiene la memoria de la suya.
          await ref.read(conversationsProvider.notifier).open(value);
        }
      },
      itemBuilder: (context) => [
        for (final option in workspace.folders)
          PopupMenuItem<String>(
            value: option.path,
            child: Row(
              children: [
                Text(
                  option.name,
                  style: NexusTypography.control.copyWith(color: colors.ink),
                ),
                if (option.path == paired?.path) ...[
                  const SizedBox(width: NexusSpacing.s3),
                  Icon(Icons.check, size: 13, color: colors.accent),
                ],
              ],
            ),
          ),
        PopupMenuItem<String>(
          value: '__loose__',
          child: Row(
            children: [
              Icon(Icons.auto_awesome_outlined, size: 14, color: colors.faint),
              const SizedBox(width: NexusSpacing.s3),
              Text(
                strings.noProject,
                style: NexusTypography.control.copyWith(color: colors.mute),
              ),
              if (suelta) ...[
                const SizedBox(width: NexusSpacing.s3),
                Icon(Icons.check, size: 13, color: colors.accent),
              ],
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: '__pair__',
          child: Row(
            children: [
              Icon(
                Icons.create_new_folder_outlined,
                size: 14,
                color: colors.faint,
              ),
              const SizedBox(width: NexusSpacing.s3),
              Text(
                strings.addFolderShort,
                style: NexusTypography.control.copyWith(color: colors.mute),
              ),
            ],
          ),
        ),
      ],
      child: child,
    );
  }
}

/// Sobre qué repo de dentro se trabaja, en una carpeta raíz con varios.
///
/// Claude tiene que arrancar **dentro** del repo o cualquier cosa de git ocurre
/// en el sitio equivocado. Aparte por lo mismo que [MenuDeLaCarpeta].
class MenuDelRepo extends ConsumerWidget {
  const MenuDelRepo({
    super.key,
    required this.carpeta,
    required this.repos,
    required this.child,
  });

  final PairedFolder carpeta;
  final List<String> repos;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return PopupMenuButton<String?>(
      color: colors.deep,
      tooltip: '',
      onSelected: (value) => ref
          .read(workspaceControllerProvider.notifier)
          .setActiveRepo(carpeta.path, value),
      itemBuilder: (context) => [
        PopupMenuItem<String?>(
          child: Row(
            children: [
              Text(
                // Trabajar sobre la raíz sigue siendo válido: hay encargos que
                // cruzan repos y ahí bajar a uno sería esconderle la mitad.
                carpeta.name,
                style: NexusTypography.control.copyWith(color: colors.mute),
              ),
              if (carpeta.activeRepo == null) ...[
                const SizedBox(width: NexusSpacing.s3),
                Icon(Icons.check, size: 13, color: colors.accent),
              ],
            ],
          ),
        ),
        for (final repo in repos)
          PopupMenuItem<String?>(
            value: repo,
            child: Row(
              children: [
                Text(
                  repo.split('/').last,
                  style: NexusTypography.control.copyWith(color: colors.ink),
                ),
                if (repo == carpeta.activeRepo) ...[
                  const SizedBox(width: NexusSpacing.s3),
                  Icon(Icons.check, size: 13, color: colors.accent),
                ],
              ],
            ),
          ),
      ],
      child: child,
    );
  }
}

/// Una ficha de la fila de arriba: el rótulo en su caja y nada más.
///
/// **Sin icono, como en el mockup**: carpeta, rama y cuenta se distinguen por lo
/// que dicen y por el orden, y un icono delante de cada una era ruido que la
/// fila leía antes que el nombre.
///
/// En versales y en la letra del instrumento, como las fichas del mockup: son
/// controles, no texto que se lee de corrido. El nombre de una rama distingue
/// mayúsculas y aquí se pinta en versales; el nombre exacto sigue en el menú de
/// la carpeta, que es donde se elige.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    this.warn = false,
    this.principal = false,
    this.alTocar,
    this.explica,
  });

  final String label;

  /// La ficha que manda —la carpeta—, en tinta. Las demás en tenue.
  final bool principal;

  /// Qué hace al pulsarlo, si hace algo. Casi ninguno hace nada: son estado.
  final VoidCallback? alTocar;

  /// Qué explica, para quien no sepa qué es eso de la memoria compartida.
  final String? explica;

  /// Algo que falta o que conviene mirar: sin carpeta, sin git.
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(
          color: warn ? colors.warn.withValues(alpha: 0.5) : colors.rule2,
        ),
        borderRadius: BorderRadius.circular(NexusRadius.sm),
      ),
      child: Text(
        label.toUpperCase(),
        style: NexusTypography.label.copyWith(
          color: warn
              ? colors.warn
              : principal
              ? colors.ink
              : colors.mute,
          letterSpacing: 1.4,
          height: 1,
        ),
      ),
    );

    // 🔴 **El que se puede tocar, se toca; los demás son estado y ya.**
    //
    // Casi todos estos chips dicen algo y no hacen nada, así que envolverlos
    // todos en algo pulsable enseñaría a pulsarlos por si acaso. Solo el de la
    // memoria compartida lleva acción, y por eso solo él cambia de cursor.
    final envuelto = alTocar == null
        ? chip
        : MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(onTap: alTocar, child: chip),
          );

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: explica == null
          ? envuelto
          : Tooltip(message: explica!, child: envuelto),
    );
  }
}
