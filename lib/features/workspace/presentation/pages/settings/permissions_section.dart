import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/workspace/data/datasources/claude_profiles_data_source.dart';
import 'package:nexus/features/workspace/domain/entities/config_del_repo.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/domain/usecases/allowed_commands.dart';
import 'package:nexus/features/workspace/domain/usecases/el_permiso_que_vale.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

/// Permisos: el tope de la app, las carpetas emparejadas y qué puede ejecutar.
///
/// Es la sección más grande, y la que más piezas propias tiene —la fila de
/// carpeta, su detalle, los comandos—. Ninguna se usa fuera de aquí, así que se
/// quedan privadas en este archivo.
///
/// 🔴 **Cada carpeta es una fila, como en el mockup, y no una tarjeta con
/// cinco mandos.** Antes cada carpeta llevaba a la vista su radio, su cuenta,
/// su modalidad y su botón de quitar, y seis carpetas eran treinta controles
/// que había que leer para saber cuál trabajaba. Ahora la fila dice lo que
/// importa —dónde, con qué cuenta, si sale a la voz, si puede editar— y su
/// acción, «Trabajar aquí»; lo que se toca de vez en cuando se abre pulsándola.
class PermissionsSection extends ConsumerStatefulWidget {
  const PermissionsSection({super.key});

  @override
  ConsumerState<PermissionsSection> createState() => _PermissionsSectionState();
}

class _PermissionsSectionState extends ConsumerState<PermissionsSection> {
  /// La carpeta abierta para cambiar su cuenta, su voz o quitarla. Una a la
  /// vez: dos detalles abiertos vuelven a ser la pila de mandos de antes.
  String? _abierta;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final workspace = ref.watch(workspaceControllerProvider);
    final controller = ref.read(workspaceControllerProvider.notifier);
    // Dos vistas del mismo estado, y hacen falta las dos: `workspace` es lo que
    // está en vigor —ya apretado por el repositorio— y es lo que hay que
    // **enseñar**; `mio` es lo que elegiste tú, y es sobre lo que hay que
    // **editar**. Editar sobre lo apretado guardaría la regla del repo como si
    // fuera tuya, y al día siguiente ya no sabrías cuál era cuál.
    final mio = controller.guardado;
    final manda = workspace.configActiva;
    final activa = mio.folders
        .where((folder) => folder.path == workspace.activePath)
        .firstOrNull;

    return BloquesDeAjustes(
      bloques: [
        BloqueDeAjustes(
          rotulo: strings.filePermissionsTitle,
          hijos: [
            TextoDeAjustes(strings.filePermissionsExplainer),
            // 🔴 **Ya no lo bloquea el repo que esté delante.** Esto es el
            // tope de la app y un `soloLectura` de un repositorio se respeta
            // donde toca —en el permiso de **su** carpeta, ver
            // [ElPermisoQueVale]—. Bloquearlo aquí ataba el cerrojo de toda la
            // app a qué conversación tenías abierta.
            ElegirDeAjustes<FilePermission>(
              llave: 'tope',
              opciones: FilePermission.values,
              elegida: workspace.permission,
              nombre: (permiso) => _nombreDelPermiso(permiso, strings),
              pista: (permiso) => switch (permiso) {
                FilePermission.readOnly => strings.permisoPistaSoloLeer,
                FilePermission.canEdit => strings.permisoPistaPuedeEditar,
              },
              onElegir: controller.setPermission,
            ),
          ],
        ),
        if (manda != null && (manda.declaraAlgo || manda.avisos.isNotEmpty))
          _LoQueDeclaraElRepo(config: manda),
        BloqueDeAjustes(
          rotulo: strings.foldersWithPermission,
          hijos: [
            if (workspace.isEmpty)
              TextoDeAjustes(strings.noFoldersYet)
            else
              FilasDeAjustes(
                filas: [
                  for (final folder in workspace.folders)
                    _FolderRow(
                      folder: folder,
                      workspace: workspace,
                      abierta: _abierta == folder.path,
                      onAbrir: () => setState(
                        () => _abierta = _abierta == folder.path
                            ? null
                            : folder.path,
                      ),
                    ),
                ],
              ),
            AccionesDeAjustes(
              botones: [
                BotonDeAjustes(
                  texto: strings.addFolder,
                  tono: TonoDeBoton.principal,
                  onPulsar: controller.pairFolder,
                ),
              ],
            ),
          ],
        ),
        // De la carpeta activa: lo que tarda en un repo no tarda en otro, así
        // que una lista global bloquearía en un proyecto lo que en otro es
        // instantáneo.
        if (activa != null) ...[
          _BlockedCommands(
            folder: activa,
            delRepo: manda?.comandosVetados ?? const [],
          ),
          _AllowedCommands(folder: activa),
        ],
      ],
    );
  }
}

String _nombreDelPermiso(FilePermission permiso, NexusStrings strings) =>
    switch (permiso) {
      FilePermission.readOnly => strings.permisoSoloLeer,
      FilePermission.canEdit => strings.permisoPuedeEditar,
    };

/// Una carpeta: su ruta, lo que la distingue en una línea de datos y la acción
/// que toca. Pulsarla abre lo demás.
class _FolderRow extends ConsumerWidget {
  const _FolderRow({
    required this.folder,
    required this.workspace,
    required this.abierta,
    required this.onAbrir,
  });

  final PairedFolder folder;
  final Workspace workspace;
  final bool abierta;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final home = ref.watch(homeDirectoryProvider);
    // «Activa» dejó de existir al haber varias conversaciones: lo que importa
    // aquí es si esa carpeta tiene una abierta.
    final isActive = ref.watch(conversationsProvider).hasFolder(folder.path);
    final profiles = ref.watch(claudeProfilesProvider).value ?? const [];
    final repo = workspace.delRepo[folder.path];
    // Si el repo pide solo texto, la voz no se puede prometer: se dice en el
    // dato, y en el detalle la opción no responde.
    final bloqueada = repo?.soloTexto ?? false;

    final cuenta = profiles
        .where((profile) => profile.path == folder.claudeProfile)
        .firstOrNull
        ?.name;
    final vetados =
        folder.blockedCommands.length + (repo?.comandosVetados.length ?? 0);
    final dato = [
      ?cuenta,
      (folder.modality.allowsVoice
              ? strings.modalidadVoz
              : strings.modalidadSoloTexto)
          .toLowerCase(),
      if (bloqueada)
        strings.repoLoFijaCorto
      else
        _nombreDelPermiso(
          ElPermisoQueVale.enLaCarpeta(workspace, folder.path)
              ? FilePermission.canEdit
              : FilePermission.readOnly,
          strings,
        ).toLowerCase(),
      if (vetados > 0) strings.comandosVetadosEnDato(vetados),
    ].join(' · ');

    return Container(
      // La fila abierta con el fondo elevado: es «la fila seleccionada» de la
      // tabla de formas del mockup, y dice de quién es el detalle de debajo.
      color: abierta ? colors.rise : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilaDeAjustes(
            key: ValueKey('carpeta-${folder.path}'),
            tono: isActive ? TonoDeAjustes.activo : TonoDeAjustes.apagado,
            titulo: folder.displayPath(home),
            tituloEnMono: true,
            dato: dato,
            onPulsar: onAbrir,
            accion: isActive
                ? BotonDeAjustes(
                    texto: strings.carpetaActiva,
                    tooltip: strings.isActiveFolder,
                    onPulsar: null,
                  )
                : BotonDeAjustes(
                    texto: strings.workHere,
                    onPulsar: () => ref
                        .read(conversationsProvider.notifier)
                        .open(folder.path),
                  ),
          ),
          if (abierta)
            _ElDetalle(
              folder: folder,
              profiles: profiles,
              bloqueada: bloqueada,
            ),
        ],
      ),
    );
  }
}

/// Lo que se cambia de una carpeta de vez en cuando: con qué cuenta trabaja,
/// si sale hacia la voz, y quitarla.
///
/// **La cuenta y la voz se deciden por carpeta**, y por eso viven aquí y no en
/// un ajuste global: los repos del trabajo con la cuenta del trabajo y los
/// personales con la personal, y hay repos a los que se les puede hablar y
/// otros a los que no. Equivocarse en la cuenta gasta el cupo de la que no
/// era; en la voz, saca hacia Google lo que no debía.
class _ElDetalle extends ConsumerWidget {
  const _ElDetalle({
    required this.folder,
    required this.profiles,
    required this.bloqueada,
  });

  final PairedFolder folder;
  final List<ClaudeProfile> profiles;
  final bool bloqueada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final controller = ref.read(workspaceControllerProvider.notifier);
    final voz = folder.modality.allowsVoice;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 12, 14),
      child: BloqueDeAjustes(
        hijos: [
          // Solo con más de una cuenta en la máquina: con una sola, elegir no
          // es una decisión, es un adorno.
          if (profiles.length >= 2) ...[
            RotuloDeAjustes(strings.claudeAccount),
            ElegirDeAjustes<String?>(
              llave: 'cuenta-${folder.path}',
              opciones: [null, for (final profile in profiles) profile.path],
              elegida:
                  profiles.any(
                    (profile) => profile.path == folder.claudeProfile,
                  )
                  ? folder.claudeProfile
                  : null,
              nombre: (path) {
                if (path == null) return strings.claudeAccountDefault;
                final profile = profiles.firstWhere((p) => p.path == path);
                // Un perfil sin sesión se puede elegir, pero se dice: el
                // encargo fallaría con un error del CLI que no explica nada.
                return profile.signedIn
                    ? profile.name
                    : strings.claudeAccountSignedOut(profile.name);
              },
              onElegir: (path) =>
                  controller.setClaudeProfile(folder.path, path),
            ),
          ],
          RotuloDeAjustes(strings.vozEnEstaCarpeta),
          ElegirDeAjustes<FolderModality>(
            llave: 'modalidad-${folder.path}',
            opciones: const [FolderModality.voice, FolderModality.textOnly],
            elegida: folder.modality,
            nombre: (modalidad) => modalidad.allowsVoice
                ? strings.modalidadVoz
                : strings.modalidadSoloTexto,
            onElegir: (modalidad) {
              if (!bloqueada) controller.setModality(folder.path, modalidad);
            },
          ),
          TextoDeAjustes(
            bloqueada
                ? strings.repoLoFija
                : voz
                ? strings.voiceAllowedExplainer
                : strings.textOnlyExplainer,
            tamano: 12.5,
          ),
          AccionesDeAjustes(
            botones: [
              BotonDeAjustes(
                texto: strings.remove,
                tono: TonoDeBoton.peligro,
                onPulsar: () => controller.removeFolder(folder.path),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Parte lo escrito en comandos: por líneas o por puntos medios.
///
/// Las dos a la vez porque el campo se enseña como el mockup —«build_runner ·
/// pod install · make generate», en una línea— y lo guardado de antes va una
/// por línea. Cada línea sigue siendo suya, así que el «#» para comentar vale
/// igual que antes.
List<String> _losComandos(String escrito) => escrito
    .split(RegExp(r'[\n·]'))
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .toList();

/// Lo que Claude no puede ejecutar en la carpeta activa.
///
/// Va en Permisos y no en una sección propia porque es un permiso: la
/// diferencia con el tope es que aquel dice si puede escribir y este dice qué
/// **no** puede correr, y los dos se leen juntos.
class _BlockedCommands extends ConsumerStatefulWidget {
  const _BlockedCommands({required this.folder, required this.delRepo});

  /// **La carpeta como la guardaste tú**, no la que quedó tras apretar el
  /// repositorio: lo que se escriba aquí se guarda, y guardar los comandos del
  /// repo como tuyos los dejaría puestos aunque el repo los quitara.
  final PairedFolder folder;

  /// Los que pone el repositorio. Se enseñan debajo y no se pueden editar aquí:
  /// se editan en su `.nexus/config.json`, que es donde se revisan.
  final List<String> delRepo;

  @override
  ConsumerState<_BlockedCommands> createState() => _BlockedCommandsState();
}

class _BlockedCommandsState extends ConsumerState<_BlockedCommands> {
  late final _controller = TextEditingController(
    text: widget.folder.blockedCommands.join('\n'),
  );

  @override
  void didUpdateWidget(covariant _BlockedCommands oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Al cambiar de carpeta activa hay que traer su lista: sin esto se quedaría
    // la de la anterior y se guardaría encima de la nueva.
    if (widget.folder.path == oldWidget.folder.path) return;
    _controller.text = widget.folder.blockedCommands.join('\n');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return BloqueDeAjustes(
      rotulo: strings.blockedTitle(widget.folder.name),
      hijos: [
        // Una línea que crece: el mockup lo dibuja como un campo de una línea,
        // y quien tenga diez comandos, uno por línea, no pierde ninguno de
        // vista.
        TextField(
          controller: _controller,
          minLines: 1,
          maxLines: 6,
          style: estiloDeCampoDeAjustes(context),
          decoration: decoracionDeCampoDeAjustes(
            context,
            hint: strings.blockedHint,
          ),
          onChanged: (value) => ref
              .read(workspaceControllerProvider.notifier)
              .setBlockedCommands(widget.folder.path, _losComandos(value)),
        ),
        if (widget.delRepo.isNotEmpty)
          Text(
            '${ConfigDelRepo.archivo} · ${widget.delRepo.join(' · ')}',
            style: NexusTypography.data.copyWith(color: colors.mute),
          ),
      ],
    );
  }
}

/// Lo que Claude **sí** puede ejecutar en la carpeta activa.
///
/// Va justo debajo de los bloqueados porque se leen juntos, y son las dos
/// mitades de la misma pregunta. La asimetría con ellos es deliberada y se
/// explica en [AllowedCommands]: bloquear de más deja un comando sin correr;
/// permitir de más deja correr algo que nadie autorizó.
///
/// **Sin la línea del repositorio** que sí tienen los bloqueados: un
/// `.nexus/config.json` no puede ampliar permisos, así que aquí no hay nada del
/// repo que enseñar.
class _AllowedCommands extends ConsumerStatefulWidget {
  const _AllowedCommands({required this.folder});

  final PairedFolder folder;

  @override
  ConsumerState<_AllowedCommands> createState() => _AllowedCommandsState();
}

class _AllowedCommandsState extends ConsumerState<_AllowedCommands> {
  late final _controller = TextEditingController(
    text: widget.folder.allowedCommands.join('\n'),
  );

  @override
  void didUpdateWidget(covariant _AllowedCommands oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Al cambiar de carpeta activa hay que traer su lista, por lo mismo que en
    // los bloqueados: si no, se guardaría la de la anterior encima de la nueva.
    if (widget.folder.path == oldWidget.folder.path) return;
    _controller.text = widget.folder.allowedCommands.join('\n');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return BloqueDeAjustes(
      rotulo: strings.allowedTitle(widget.folder.name),
      hijos: [
        TextoDeAjustes(strings.allowedExplainer),
        TextField(
          controller: _controller,
          minLines: 1,
          maxLines: 5,
          style: estiloDeCampoDeAjustes(context),
          decoration: decoracionDeCampoDeAjustes(
            context,
            hint: strings.allowedHint,
          ),
          onChanged: (value) => ref
              .read(workspaceControllerProvider.notifier)
              .setAllowedCommands(widget.folder.path, _losComandos(value)),
        ),
      ],
    );
  }
}

/// Lo que el repositorio declara sobre sí mismo, en cristiano.
///
/// Tiene que verse, y por una razón que no es de transparencia sino de que la
/// pantalla no mienta: si el repo apaga la voz y aquí no lo dice, la carpeta
/// se queda en «solo texto» sin motivo visible y parece un fallo.
///
/// Los avisos van con el mismo peso que las declaraciones, no escondidos: este
/// archivo se escribe a mano y se revisa en un PR, así que una llave mal puesta
/// necesita salir a la primera y no cuando alguien note que no se aplica.
class _LoQueDeclaraElRepo extends StatelessWidget {
  const _LoQueDeclaraElRepo({required this.config});

  final ConfigDelRepo config;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    final dice = <String>[
      if (config.soloTexto) strings.repoSoloTexto,
      if (config.soloLectura) strings.repoSoloLectura,
      if (config.comandosVetados.isNotEmpty)
        strings.repoComandosVetados(config.comandosVetados.length),
      if (config.carpetaDePruebas case final carpeta?)
        strings.repoCarpetaDePruebas(carpeta),
      if (config.modelo case final modelo?) strings.repoModelo(modelo),
    ];

    return BloqueDeAjustes(
      rotulo: strings.repoDeclaraTitle,
      hijos: [
        TextoDeAjustes(strings.repoDeclaraExplainer),
        for (final linea in dice)
          Text(
            '· $linea',
            style: NexusTypography.nota.copyWith(color: colors.ink),
          ),
        if (config.avisos.isNotEmpty) ...[
          EstadoDeAjustes(
            tono: TonoDeAjustes.atencion,
            texto: strings.repoAvisosTitle,
          ),
          for (final aviso in config.avisos)
            Text(
              '· $aviso',
              style: NexusTypography.nota.copyWith(color: colors.warn),
            ),
        ],
      ],
    );
  }
}
