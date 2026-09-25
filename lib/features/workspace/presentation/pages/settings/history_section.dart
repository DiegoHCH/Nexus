import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/history/domain/repositories/conversation_archive.dart';
import 'package:nexus/features/history/presentation/providers/archive_providers.dart';
import 'package:nexus/features/history/presentation/providers/slack_providers.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

/// Historial: dónde se archivan las conversaciones cuando terminan.

/// Dónde acaban las conversaciones.
///
/// Los tres destinos son del usuario, no del programa, y por eso el estado de
/// partida es «en ningún sitio»: sacar lo que hablas de esta máquina es una
/// decisión suya, no algo que pase por omisión.
///
/// 🔴 **Los destinos a la vista, con su estado debajo.** Eran cuatro radios
/// con su explicación cada uno, y lo que importaba —si de verdad se está
/// guardando, y dónde— venía al final, debajo del parte a Slack: la carpeta se
/// elegía en el bloque de otra cosa. Ahora el estado va justo debajo del
/// destino, en verde si se guarda y en ámbar si falta algo, como el mockup.
class HistorySection extends ConsumerWidget {
  const HistorySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final settings = ref.watch(archiveControllerProvider);
    final controller = ref.read(archiveControllerProvider.notifier);

    String label(ArchiveDestination option) => switch (option) {
      ArchiveDestination.none => strings.archiveNone,
      ArchiveDestination.folder => strings.archiveFolder,
      ArchiveDestination.obsidian => strings.archiveObsidian,
      ArchiveDestination.notion => strings.archiveNotion,
    };

    return BloquesDeAjustes(
      bloques: [
        BloqueDeAjustes(
          rotulo: strings.archiveTitle,
          hijos: [
            TextoDeAjustes(strings.archiveExplainer),
            ElegirDeAjustes<ArchiveDestination>(
              llave: 'archivo',
              opciones: ArchiveDestination.values,
              elegida: settings.destination,
              nombre: label,
              onElegir: controller.selectDestination,
            ),
            ...switch (settings.destination) {
              ArchiveDestination.none => [
                EstadoDeAjustes(
                  tono: TonoDeAjustes.apagado,
                  texto: strings.archiveNoneHint,
                ),
              ],
              ArchiveDestination.notion => [
                _NotionFields(settings: settings, controller: controller),
              ],
              ArchiveDestination.folder || ArchiveDestination.obsidian => [
                EstadoDeAjustes(
                  tono: settings.isReady
                      ? TonoDeAjustes.bien
                      : TonoDeAjustes.atencion,
                  texto: settings.isReady
                      ? strings.archiveLayout(settings.folderPath!)
                      : strings.archiveNoFolderYet,
                ),
                AccionesDeAjustes(
                  botones: [
                    BotonDeAjustes(
                      texto: strings.archiveChooseFolder,
                      tono: settings.isReady
                          ? TonoDeBoton.neutro
                          : TonoDeBoton.principal,
                      onPulsar: () async {
                        final chosen = await getDirectoryPath();
                        if (chosen != null) {
                          await controller.selectFolder(chosen);
                        }
                      },
                    ),
                  ],
                ),
              ],
            },
          ],
        ),
        // El parte del día, junto al destino de archivo: es la misma pregunta
        // —a dónde mando mi trabajo— y no merece una sección propia.
        const _ParteAlSlack(),
      ],
    );
  }
}

/// A dónde va el parte del día, y con qué permiso.
///
/// **El token se escribe y no se vuelve a ver**: al guardarlo el campo se
/// vacía, y lo único que queda en pantalla es si hay uno. Enseñar un secreto
/// recortado no sirve para compararlo y sí para que aparezca en la captura de
/// pantalla de alguien enseñando la app.
///
/// Con todo puesto se ve como en el mockup —el estado en una línea y
/// «Mandar una de prueba»— y los campos se abren con «Cambiar»: una vez
/// configurado, lo que se mira es si funciona, no el formulario.
class _ParteAlSlack extends ConsumerStatefulWidget {
  const _ParteAlSlack();

  @override
  ConsumerState<_ParteAlSlack> createState() => _ParteAlSlackState();
}

class _ParteAlSlackState extends ConsumerState<_ParteAlSlack> {
  final _token = TextEditingController();
  late final _destino = TextEditingController(
    text: ref.read(slackControllerProvider).destino ?? '',
  );
  String? _resultado;
  bool _probando = false;

  /// Los campos abiertos con todo puesto. Sin nada puesto se abren solos:
  /// sin ellos no hay forma de empezar.
  bool _cambiando = false;

  @override
  void dispose() {
    _token.dispose();
    _destino.dispose();
    super.dispose();
  }

  Future<void> _probar() async {
    setState(() {
      _probando = true;
      _resultado = null;
    });
    final fallo = await ref
        .read(slackControllerProvider.notifier)
        .mandar(context.strings.slackPrueba);
    if (!mounted) return;
    setState(() {
      _probando = false;
      _resultado = fallo ?? context.strings.slackLlego;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final slack = ref.watch(slackControllerProvider);
    final abiertos = !slack.listo || _cambiando;
    final proyecto = slack.proyecto;
    final destino = slack.destino?.trim();

    // Lo que hay, dicho en una línea: token, a quién y de qué proyecto.
    final estado = [
      if (slack.hayToken) strings.slackConToken else strings.slackSinToken,
      if (slack.hayToken && destino != null && destino.isNotEmpty)
        strings.salidaA(destino),
      if (slack.hayToken)
        proyecto == null
            ? strings.slackDeTodos
            : strings.slackDeUno(proyecto.split('/').last),
    ].join(' · ');

    return BloqueDeAjustes(
      rotulo: strings.slackTitle,
      hijos: [
        TextoDeAjustes(strings.slackExplainer),
        EstadoDeAjustes(
          tono: slack.listo ? TonoDeAjustes.bien : TonoDeAjustes.atencion,
          texto: estado,
        ),
        if (abiertos) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _token,
                  obscureText: true,
                  style: estiloDeCampoDeAjustes(context),
                  decoration: decoracionDeCampoDeAjustes(
                    context,
                    hint: strings.slackTokenHint,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              BotonDeAjustes(
                texto: strings.geminiKeySave,
                tono: slack.hayToken
                    ? TonoDeBoton.neutro
                    : TonoDeBoton.principal,
                onPulsar: () async {
                  await ref
                      .read(slackControllerProvider.notifier)
                      .guardarToken(_token.text);
                  _token.clear();
                },
              ),
            ],
          ),
          RotuloDeAjustes(strings.slackDestino),
          TextField(
            controller: _destino,
            style: estiloDeCampoDeAjustes(context),
            decoration: decoracionDeCampoDeAjustes(
              context,
              hint: strings.slackDestinoHint,
            ),
            onChanged: (valor) => ref
                .read(slackControllerProvider.notifier)
                .guardarDestino(valor),
          ),
          TextoDeAjustes(strings.slackDestinoExplainer, tamano: 12.5),
          // De qué proyecto se cuenta el trabajo. **Sin esto el parte
          // mezclaría** lo personal con lo del trabajo en el canal de un
          // equipo, y eso no se arregla acordándose cada mañana.
          RotuloDeAjustes(strings.slackProyecto),
          ElegirDeAjustes<String?>(
            llave: 'slack-proyecto',
            opciones: [
              null,
              ...ref
                  .watch(workspaceControllerProvider)
                  .folders
                  .map((f) => f.path),
            ],
            elegida: proyecto,
            nombre: (carpeta) =>
                carpeta == null ? strings.slackTodos : carpeta.split('/').last,
            onElegir: ref
                .read(slackControllerProvider.notifier)
                .guardarProyecto,
          ),
        ],
        AccionesDeAjustes(
          botones: [
            BotonDeAjustes(
              texto: _probando ? strings.slackProbando : strings.slackProbar,
              tono: TonoDeBoton.principal,
              onPulsar: slack.listo && !_probando ? _probar : null,
            ),
            if (slack.listo)
              BotonDeAjustes(
                texto: _cambiando ? strings.slackListo : strings.keyChange,
                onPulsar: () => setState(() => _cambiando = !_cambiando),
              ),
          ],
        ),
        if (_resultado case final dicho?)
          EstadoDeAjustes(
            tono: dicho == strings.slackLlego
                ? TonoDeAjustes.bien
                : TonoDeAjustes.fallo,
            texto: dicho,
          ),
      ],
    );
  }
}

class _NotionFields extends StatefulWidget {
  const _NotionFields({required this.settings, required this.controller});

  final ArchiveSettings settings;
  final ArchiveController controller;

  @override
  State<_NotionFields> createState() => _NotionFieldsState();
}

class _NotionFieldsState extends State<_NotionFields> {
  late final _page = TextEditingController(
    text: widget.settings.notionPage ?? '',
  );
  final _token = TextEditingController();

  @override
  void dispose() {
    _page.dispose();
    _token.dispose();
    super.dispose();
  }

  /// El token y la página de Notion, con la línea de los campos de Ajustes.
  ///
  /// Se piden aquí y no en la configuración inicial porque no son un requisito
  /// para usar Nexus: es una decisión de dónde quieres tus conversaciones. El
  /// token viaja al llavero, como la llave de Gemini — no a las preferencias
  /// en claro.
  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final settings = widget.settings;

    return BloqueDeAjustes(
      hijos: [
        EstadoDeAjustes(
          tono: settings.isReady ? TonoDeAjustes.bien : TonoDeAjustes.atencion,
          texto: settings.isReady ? strings.notionReady : strings.notionMissing,
        ),
        RotuloDeAjustes(strings.notionToken),
        TextField(
          controller: _token,
          obscureText: true,
          style: estiloDeCampoDeAjustes(context),
          decoration: decoracionDeCampoDeAjustes(
            context,
            hint: strings.notionTokenHint,
          ),
          onChanged: widget.controller.saveNotionToken,
        ),
        TextoDeAjustes(strings.notionTokenExplainer, tamano: 12.5),
        RotuloDeAjustes(strings.notionPage),
        TextField(
          controller: _page,
          style: estiloDeCampoDeAjustes(context),
          decoration: decoracionDeCampoDeAjustes(
            context,
            hint: strings.notionPageHint,
          ),
          onChanged: widget.controller.saveNotionPage,
        ),
        TextoDeAjustes(strings.notionPageExplainer, tamano: 12.5),
      ],
    );
  }
}
