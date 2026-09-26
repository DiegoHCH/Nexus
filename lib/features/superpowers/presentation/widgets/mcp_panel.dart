import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/superpowers/domain/entities/mcp_catalog.dart';
import 'package:nexus/features/superpowers/domain/usecases/la_lista_de_mcp.dart';
import 'package:nexus/features/superpowers/domain/usecases/mcp_command.dart';
import 'package:nexus/features/superpowers/domain/entities/mcp_server.dart';
import 'package:nexus/features/superpowers/presentation/providers/superpowers_providers.dart';
import 'package:nexus/features/superpowers/domain/usecases/fallos_por_cuenta.dart';
import 'package:nexus/features/superpowers/domain/entities/el_uso_de_figma.dart';

/// Los servidores MCP de una cuenta: los que hay, los que se pueden poner de un
/// clic, y uno a mano.
class McpPanel extends ConsumerStatefulWidget {
  const McpPanel({
    super.key,
    required this.configDir,
    this.tambienEn = const [],
  });

  final String configDir;

  /// Las demás cuentas donde replicar lo que se instale aquí.
  ///
  /// Vacío es lo normal: solo la de arriba. Va como lista y no como un booleano «en
  /// todas» porque este panel no sabe cuántas cuentas hay ni cómo se llaman — eso lo
  /// decide la sección, que es quien tiene las pestañas.
  final List<String> tambienEn;

  @override
  ConsumerState<McpPanel> createState() => _McpPanelState();
}

class _McpPanelState extends ConsumerState<McpPanel> {
  final _name = TextEditingController();
  final _spec = TextEditingController();

  /// La cabecera, para los servidores con llave.
  ///
  /// Existe porque sin ella media Internet de MCP no entra por aquí: el de
  /// Hugging Face —y cualquiera con `Authorization`— rechaza toda petición sin
  /// cabecera, así que se registraba con tic verde y contestaba 401 al primer
  /// encargo. El único camino era la terminal.
  final _header = TextEditingController();
  var _busy = false;

  /// Si se está preguntando al CLI **porque alguien lo pidió**.
  ///
  /// Aparte de la caducidad de lo recordado: sin esto, pulsar «volver a
  /// comprobar» dentro de las seis horas no haría nada visible — se invalidaría
  /// un proveedor que nadie está mirando.
  var _preguntando = false;

  /// Si alguien pidió contar lo gastado de Figma.
  ///
  /// Igual que la comprobación de arriba y por el mismo motivo: contar recorre
  /// los registros de las sesiones —cientos de megas— y abrir una pestaña no
  /// puede costar eso.
  var _contando = false;
  String? _error;

  /// El catálogo y el formulario, cerrados hasta que se piden: se usan una vez
  /// por servidor, y abiertos siempre empujaban la lista de los puestos —lo
  /// que se mira a diario— hacia abajo de todo.
  var _catalogo = false;
  var _aMano = false;

  @override
  void dispose() {
    _name.dispose();
    _spec.dispose();
    _header.dispose();
    super.dispose();
  }

  Future<void> _install(
    String name, {
    String? url,
    List<String> command = const [],
    List<String> headers = const [],
    String? comoSeInstala,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    // **El binario, antes de registrar nada.** `claude mcp add` acepta cualquier
    // comando sin comprobar que exista: se instalaría con un tic verde y fallaría
    // la primera vez que un encargo lo use, en headless, diciendo algo que no se
    // parece a esto. Aquí el aviso llega donde se pulsó el botón.
    final binario = command.isEmpty ? null : command.first;
    if (binario != null &&
        !ref.read(mcpDataSourceProvider).hayBinario(binario)) {
      setState(() {
        _busy = false;
        // Sin traducir y con la ruta del comando dentro, como los errores del
        // CLI que este panel ya muestra literales: lo accionable es el comando,
        // y un «no se pudo instalar» obliga a abrir la terminal para averiguar
        // qué faltaba.
        _error = comoSeInstala == null
            ? 'No se encuentra «$binario». Instálalo y vuelve a intentarlo.'
            : 'No se encuentra «$binario». Instálalo con: $comoSeInstala';
      });
      return;
    }
    final error = await ref
        .read(mcpDataSourceProvider)
        // A la cuenta de arriba **y a las demás si se pidió**. Aquí el síntoma de
        // tenerlo en una sola es el peor de leer: «no puedo consultar tu calendario»
        // no se parece a un problema de cuentas.
        .addEn(
          [widget.configDir, ...widget.tambienEn],
          name: name,
          url: url,
          command: command,
          headers: headers,
        )
        .then(FallosPorCuenta.primero);
    ref.invalidate(mcpServersProvider(widget.configDir));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  Future<void> _remove(String name) async {
    setState(() => _busy = true);
    final error = await ref
        .read(mcpDataSourceProvider)
        .remove(widget.configDir, name);
    ref.invalidate(mcpServersProvider(widget.configDir));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  /// Lo escrito a mano puede ser una URL o un comando, y se distingue solo: lo
  /// que empieza por `http` es lo primero. Pedir que el usuario elija el tipo
  /// en un desplegable sería preguntarle algo que ya dijo al escribirlo.
  Future<void> _addManual() async {
    final name = _name.text.trim();
    final spec = _spec.text.trim();
    if (name.isEmpty || spec.isEmpty) return;
    final isUrl = spec.startsWith('http://') || spec.startsWith('https://');
    final header = _header.text.trim();

    // Se avisa aquí y no se manda a medias: una cabecera mal escrita la
    // descartaría el comando en silencio, y el servidor quedaría registrado
    // **sin llave** — con tic verde y un 401 en el primer encargo, que es
    // justo el rato en que nadie está mirando este panel.
    if (header.isNotEmpty && !McpCommand.validHeader(header)) {
      setState(() => _error = 'La cabecera va como «Nombre: valor».');
      return;
    }

    await _install(
      name,
      url: isUrl ? spec : null,
      command: isUrl ? const [] : spec.split(RegExp(r'\s+')),
      headers: isUrl && header.isNotEmpty ? [header] : const [],
    );
    if (_error == null && mounted) {
      _name.clear();
      _spec.clear();
      // La llave se va con el resto: ya viajó al registro, y dejarla escrita en
      // pantalla es lo que acaba en la captura de alguien enseñando la app.
      _header.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final delArchivo =
        ref.watch(mcpServersProvider(widget.configDir)).value ?? const [];
    final names = delArchivo.map((server) => server.name).toSet();

    // 🔴 **Lo recordado y la comprobación entran en la MISMA lista.** Antes los
    // conectores de la cuenta solo salían en un bloque aparte al pulsar
    // «Comprobar», y desde fuera eso se lee como que no están: reportado tal
    // cual, «solo se listan los de usuario y no los de claude.ai». Ver
    // [LaListaDeMcp], donde está la medición: cinco en el archivo, veinte en el
    // CLI.
    final recordado = ref.watch(mcpRecordadosProvider(widget.configDir)).value;
    // Se le pregunta al CLI **por detrás** cuando lo recordado ya no vale o no
    // hay nada: sin esto, la primera vez la lista volvería a salir a medias.
    final preguntando =
        _preguntando || LaListaDeMcp.hayQuePreguntar(recordado?.cuando);
    final health = preguntando
        ? ref.watch(mcpHealthProvider(widget.configDir))
        : null;
    final installed = LaListaDeMcp.junta(
      delArchivo: delArchivo,
      recordados: recordado?.servidores ?? const [],
      comprobados: health?.value,
    );
    final deLaCuenta = LaListaDeMcp.deLaCuenta(installed);

    // Con la gramática de Ajustes, como el mockup: los puestos como filas con
    // su punto de estado y su acción, y el catálogo y el formulario detrás de
    // dos botones. Antes estaban los tres siempre abiertos, y la lista de lo
    // que ya tienes —lo único que se mira a diario— quedaba en medio de lo que
    // se usa una vez.
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        TextoDeAjustes(strings.mcpExplainer),
        const SizedBox(height: 9),
        if (installed.isEmpty)
          TextoDeAjustes(strings.mcpNone)
        else
          FilasDeAjustes(
            filas: [
              for (final server in installed)
                _ServerRow(
                  server: server,
                  enabled: !_busy,
                  // Los de la cuenta no se quitan desde aquí —se gestionan en
                  // claude.ai— y un botón que no funciona es peor que no
                  // tenerlo.
                  onRemove: server.fromAccount
                      ? null
                      : () => _remove(server.name),
                  onRecheck: () {
                    ref.invalidate(mcpHealthProvider(widget.configDir));
                    setState(() => _preguntando = true);
                  },
                ),
            ],
          ),
        if (deLaCuenta > 0) ...[
          const SizedBox(height: 4),
          TextoDeAjustes(strings.mcpDeLaCuenta(deLaCuenta), tamano: 12.5),
        ],
        // 🔴 **La lista ya no se repinta aquí abajo.** Lo que llega del CLI
        // entra arriba, en la lista de verdad; esto solo dice en qué anda —o
        // que no se pudo—, que es lo único que no cabe en una fila.
        if (health != null)
          switch (health) {
            AsyncLoading() => Padding(
              padding: const EdgeInsets.only(top: 9),
              child: EstadoDeAjustes(
                tono: TonoDeAjustes.apagado,
                texto: strings.mcpChecking,
              ),
            ),
            AsyncData(value: null) || AsyncError() => Padding(
              padding: const EdgeInsets.only(top: 9),
              child: EstadoDeAjustes(
                tono: TonoDeAjustes.atencion,
                texto: strings.mcpCheckFailed,
              ),
            ),
            _ => const SizedBox.shrink(),
          },
        const SizedBox(height: 9),
        AccionesDeAjustes(
          botones: [
            BotonDeAjustes(
              texto: strings.mcpAnadirAMano,
              tono: TonoDeBoton.principal,
              onPulsar: () => setState(() => _aMano = !_aMano),
            ),
            BotonDeAjustes(
              texto: strings.mcpVerElCatalogo,
              onPulsar: () => setState(() => _catalogo = !_catalogo),
            ),
          ],
        ),

        if (_catalogo) ...[
          const SizedBox(height: 16),
          RotuloDeAjustes(strings.mcpCatalog),
          const SizedBox(height: 4),
          FilasDeAjustes(
            filas: [
              for (final entry in McpCatalog.entries)
                _CatalogRow(
                  entry: entry,
                  already: names.contains(entry.name),
                  enabled: !_busy,
                  onAdd: () => _install(
                    entry.name,
                    url: entry.url,
                    command: entry.command,
                    comoSeInstala: entry.comoSeInstala,
                  ),
                ),
            ],
          ),
        ],

        if (_aMano) ...[
          const SizedBox(height: 16),
          RotuloDeAjustes(strings.mcpManual),
          const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 140,
                child: _Field(controller: _name, hint: strings.mcpNameHint),
              ),
              const SizedBox(width: NexusSpacing.s3),
              Expanded(
                child: _Field(controller: _spec, hint: strings.mcpSpecHint),
              ),
              const SizedBox(width: NexusSpacing.s3),
              BotonDeAjustes(
                texto: strings.mcpAdd,
                tono: TonoDeBoton.principal,
                onPulsar: _busy ? null : _addManual,
              ),
            ],
          ),
          // Debajo y a lo ancho, no en la misma fila: es opcional, y ponerla
          // al lado de la URL sugeriría que hace falta siempre.
          const SizedBox(height: 9),
          _Field(controller: _header, hint: strings.mcpHeaderHint),
          const SizedBox(height: 6),
          TextoDeAjustes(strings.mcpHeaderNote, tamano: 12.5),
        ],
        if (_error case final message?) ...[
          const SizedBox(height: NexusSpacing.s3),
          // Lo que dijo el CLI, literal: «ya existe uno con ese nombre» o «no
          // se pudo resolver el comando» es accionable, y taparlo con un «no se
          // pudo» obliga a abrir la terminal para saber qué pasó.
          Text(
            message,
            style: NexusTypography.mono.copyWith(color: colors.err),
          ),
        ],

        // Lo gastado de Figma, en su propio bloque y al final: se consulta de
        // vez en cuando, y contar recorre los registros —tarda—.
        const SizedBox(height: 16),
        Divider(color: colors.rule, height: 1),
        const SizedBox(height: 16),
        RotuloDeAjustes(strings.figmaUso),
        const SizedBox(height: 9),
        TextoDeAjustes(strings.figmaUsoDeDonde, tamano: 12.5),
        const SizedBox(height: 9),
        AccionesDeAjustes(
          botones: [
            BotonDeAjustes(
              texto: strings.figmaUsoContar,
              onPulsar: () {
                ref.invalidate(elUsoDeFigmaProvider(widget.configDir));
                setState(() => _contando = true);
              },
            ),
          ],
        ),
        if (_contando) ...[
          const SizedBox(height: NexusSpacing.s3),
          switch (ref.watch(elUsoDeFigmaProvider(widget.configDir))) {
            AsyncLoading() => EstadoDeAjustes(
              tono: TonoDeAjustes.apagado,
              texto: strings.figmaUsoContando,
            ),
            AsyncError() => EstadoDeAjustes(
              tono: TonoDeAjustes.atencion,
              texto: strings.figmaUsoNoSePudo,
            ),
            AsyncData(:final value) => _ElUso(uso: value),
          },
        ],
      ],
    );
  }
}

/// Un servidor puesto: su punto de estado, su nombre, lo que lo arranca y la
/// acción que le toca —quitarlo, o volver a preguntarle si no respondió—.
class _ServerRow extends StatelessWidget {
  const _ServerRow({
    required this.server,
    required this.onRecheck,
    this.enabled = true,
    this.onRemove,
  });

  final McpServer server;
  final bool enabled;
  final VoidCallback? onRemove;
  final VoidCallback onRecheck;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final (tono, estado) = switch (server.status) {
      McpStatus.connected => (TonoDeAjustes.bien, strings.mcpConectado),
      McpStatus.needsAuth => (TonoDeAjustes.atencion, strings.mcpPideEntrar),
      McpStatus.failed => (TonoDeAjustes.fallo, strings.mcpNoResponde),
      McpStatus.unknown => (TonoDeAjustes.apagado, null),
    };

    return FilaDeAjustes(
      tono: tono,
      titulo: server.name,
      dato: [?estado, server.spec].join(' · '),
      accion: switch (server.status) {
        // El que no respondió se ofrece a volver a preguntar antes que a
        // quitarse: casi siempre es que no estaba arrancado, no que sobre.
        McpStatus.failed => BotonDeAjustes(
          texto: strings.mcpCheck,
          onPulsar: enabled ? onRecheck : null,
        ),
        // Los conectores de claude.ai llegan con la sesión y se gestionan
        // allí: un botón de quitar que no puede quitar es peor que ninguno.
        _ when onRemove != null && !server.fromAccount => BotonDeAjustes(
          texto: strings.mcpRemove,
          tono: TonoDeBoton.peligro,
          onPulsar: enabled ? onRemove : null,
        ),
        _ => null,
      },
    );
  }
}

class _CatalogRow extends StatelessWidget {
  const _CatalogRow({
    required this.entry,
    required this.already,
    required this.enabled,
    required this.onAdd,
  });

  final McpCatalogEntry entry;
  final bool already;
  final bool enabled;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return FilaDeAjustes(
      tono: already ? TonoDeAjustes.bien : null,
      titulo: entry.name,
      dato: entry.what,
      accion: already
          ? null
          : BotonDeAjustes(
              texto: strings.mcpAdd,
              tono: TonoDeBoton.principal,
              onPulsar: enabled ? onAdd : null,
            ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    style: estiloDeCampoDeAjustes(context),
    decoration: decoracionDeCampoDeAjustes(context, hint: hint),
  );
}

/// Lo gastado de Figma este mes, en la cuenta que se está mirando.
///
/// El desglose por herramienta va sin traducir: son los nombres con los que
/// Figma las llama en su documentación —`get_design_context`, `get_screenshot`—
/// y traducirlos rompería el puente entre lo que se ve aquí y lo que se lee
/// allí.
class _ElUso extends StatelessWidget {
  const _ElUso({required this.uso});

  final ElUsoDeFigma uso;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    if (!uso.hayAlgo) {
      return Text(
        strings.figmaUsoNinguna,
        style: NexusTypography.nota.copyWith(color: colors.faint),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.figmaUsoGastadas(uso.gastadas),
          style: NexusTypography.nota.copyWith(color: colors.ink),
        ),
        for (final entrada in uso.porHerramienta.entries)
          Padding(
            padding: const EdgeInsets.only(top: NexusSpacing.s1),
            child: Text(
              '${entrada.value}  ${entrada.key}',
              style: NexusTypography.mono.copyWith(color: colors.faint),
            ),
          ),
        if (uso.exentas > 0)
          Padding(
            padding: const EdgeInsets.only(top: NexusSpacing.s2),
            child: Text(
              strings.figmaUsoExentas(uso.exentas),
              style: NexusTypography.label.copyWith(color: colors.faint),
            ),
          ),
      ],
    );
  }
}
