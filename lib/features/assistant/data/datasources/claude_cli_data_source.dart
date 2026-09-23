import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:nexus/core/platform/herramienta_externa.dart';
import 'package:nexus/core/platform/claude_environment.dart';
import 'package:nexus/features/assistant/data/datasources/el_final_de_la_salida.dart';
import 'package:nexus/features/assistant/data/datasources/la_salida_que_se_cancela.dart';
import 'package:nexus/features/assistant/domain/entities/peticion_de_permiso.dart';

/// Lanza `claude -p` headless y entrega cada línea de su `stream-json` ya
/// decodificada. No sabe nada de dominio: eso lo traduce el repositorio.
class ClaudeCliDataSource {
  const ClaudeCliDataSource();

  /// Un evento del flujo, o `null` si esa línea no lo es.
  ///
  /// Público **para poder probar la tolerancia sin lanzar un proceso**, que es
  /// justo la parte que falló: antes esto era un `jsonDecode` a pelo, y una
  /// línea de texto plano —las que el CLI escribe cuando algo va mal antes de
  /// arrancar el flujo— se llevaba por delante el encargo entero con una
  /// `FormatException`.
  static Map<String, dynamic>? comoJson(String line) {
    try {
      final decoded = jsonDecode(line);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// [workingDirectory] es dónde trabaja Claude, y no es opcional de verdad:
  /// sin él el proceso hereda el directorio de la app, que para un bundle
  /// lanzado por launchd es `/`. Cualquier encargo sobre archivos respondía
  /// entonces sobre la raíz del disco, con seguridad y sin avisar.
  ///
  /// [permissionMode] es el `--permission-mode` del CLI. Con `manual` la
  /// escritura se deniega, también la que intente colarse por Bash.
  /// [extraDirectories] son las demás carpetas emparejadas. Sin ellas, Claude
  /// solo alcanza el directorio de trabajo: un repo que guarda sus reglas en
  /// una carpeta hermana —lo normal en un monorepo de contexto compartido—
  /// carga las instrucciones y luego no puede leer lo que estas le mandan.
  Stream<Map<String, dynamic>> run(
    String instruction, {
    required String workingDirectory,
    required String permissionMode,
    List<String> extraDirectories = const [],
    String? resumeSessionId,
    bool forkSession = false,
    String? appendSystemPrompt,
    String? configDir,
    String? model,
    String? effort,
    List<String> disallowedTools = const [],

    /// Los servidores MCP que este encargo puede usar, ya con el prefijo `mcp__`.
    /// Vacío significa **ninguno**, que es lo que había antes sin querer.
    List<String> herramientasMcp = const [],

    /// A quién preguntarle cuando Claude quiera usar una herramienta que no
    /// tiene concedida. `null` —lo de siempre— deja el encargo headless puro:
    /// no hay canal de vuelta y el modo de permisos decide solo.
    ///
    /// **No es un adorno opcional: cambia cómo se lanza el proceso.** Con esto
    /// puesto la instrucción deja de ir en la línea de comandos y entra por
    /// stdin como `stream-json`, porque el canal de las preguntas es el mismo
    /// que el de la entrada y solo existe si esa entrada está abierta.
    Future<RespuestaDePermiso> Function(PeticionDePermiso peticion)?
    alPedirPermiso,
  }) {
    // 🔴 **El envoltorio no es adorno**: sin él, cancelar esta suscripción no
    // despierta al generador de abajo y su `finally` —el que mata el proceso—
    // no corre jamás. Ver [LaSalidaQueSeCancela] y [ElProcesoDelTurno], donde
    // está medido lo que costó no saberlo.
    final vivo = ElProcesoDelTurno();
    return LaSalidaQueSeCancela.de(
      () => _correr(
        instruction,
        workingDirectory: workingDirectory,
        permissionMode: permissionMode,
        extraDirectories: extraDirectories,
        resumeSessionId: resumeSessionId,
        forkSession: forkSession,
        appendSystemPrompt: appendSystemPrompt,
        configDir: configDir,
        model: model,
        effort: effort,
        disallowedTools: disallowedTools,
        herramientasMcp: herramientasMcp,
        alPedirPermiso: alPedirPermiso,
        vivo: vivo,
      ),
      alCancelar: vivo.soltar,
    );
  }

  /// El generador de siempre. Privado porque **no se expone sin envolver**: un
  /// `async*` suelto no se entera de que lo cancelan.
  Stream<Map<String, dynamic>> _correr(
    String instruction, {
    required String workingDirectory,
    required String permissionMode,
    List<String> extraDirectories = const [],
    String? resumeSessionId,
    bool forkSession = false,
    String? appendSystemPrompt,
    String? configDir,
    String? model,
    String? effort,
    List<String> disallowedTools = const [],

    /// Los servidores MCP que este encargo puede usar, ya con el prefijo `mcp__`.
    /// Vacío significa **ninguno**, que es lo que había antes sin querer.
    List<String> herramientasMcp = const [],

    /// A quién preguntarle cuando Claude quiera usar una herramienta que no
    /// tiene concedida. `null` —lo de siempre— deja el encargo headless puro:
    /// no hay canal de vuelta y el modo de permisos decide solo.
    ///
    /// **No es un adorno opcional: cambia cómo se lanza el proceso.** Con esto
    /// puesto la instrucción deja de ir en la línea de comandos y entra por
    /// stdin como `stream-json`, porque el canal de las preguntas es el mismo
    /// que el de la entrada y solo existe si esa entrada está abierta.
    Future<RespuestaDePermiso> Function(PeticionDePermiso peticion)?
    alPedirPermiso,
    required ElProcesoDelTurno vivo,
  }) async* {
    // Con alguien a quien preguntar, el CLI habla por un canal distinto: manda
    // `control_request` por stdout y espera el `control_response` por stdin.
    // Lo enciende `--permission-prompt-tool stdio` —el valor es literal, lo
    // dice el binario: «permission prompts reach the host over stdio»— y sin
    // `--input-format stream-json` no hay por dónde contestarle.
    final preguntando = alPedirPermiso != null;
    final process = await Process.start(
      await HerramientaExterna.rutaDeClaude(),
      [
        '-p',
        // Preguntando, la instrucción viaja por stdin: pasarla además aquí la
        // mandaría dos veces.
        if (!preguntando) instruction,
        if (preguntando) ...[
          '--input-format',
          'stream-json',
          '--permission-prompt-tool',
          'stdio',
        ],
        '--output-format',
        'stream-json',
        '--include-partial-messages',
        '--verbose',
        '--permission-mode',
        permissionMode,
        // Con esto Claude recuerda lo de antes; sin esto, cada encargo empieza
        // de cero y no sabe ni lo que hizo hace un minuto.
        if (resumeSessionId != null) ...[
          '--resume',
          resumeSessionId,
          // 🔴 **Bifurcar en vez de escribir en el mismo hilo.** Es lo que
          // permite que dos conversaciones trabajen a la vez sobre la misma
          // carpeta: se lleva el contexto hasta aquí y a partir de ahora
          // escribe en una sesión propia. Sin esto, dos `--resume` a la vez
          // sobre la misma sesión contestan bien los dos y después **solo
          // consta uno** — medido con el binario.
          if (forkSession) '--fork-session',
        ],
        // Las reglas del árbol y el contexto del repo, repetidos aquí a
        // propósito. Claude ya carga los CLAUDE.md por su cuenta, pero los
        // aplica todos al mismo nivel: sin esto, el protocolo de la carpeta de
        // arriba diluye las reglas del proyecto.
        if (appendSystemPrompt != null && appendSystemPrompt.isNotEmpty) ...[
          '--append-system-prompt',
          appendSystemPrompt,
        ],
        // **El modelo y el esfuerzo de la carpeta.** Se calculaban, se pasaban por
        // tres capas y se tiraban aquí: llegaban a este método y nunca a la línea de
        // comandos, así que la elección por carpeta no hacía nada.
        if (model != null && model.isNotEmpty) ...['--model', model],
        if (effort != null && effort.isNotEmpty) ...['--effort', effort],
        // **Las herramientas MCP, permitidas por servidor.**
        //
        // En headless nadie aprueba nada, así que sin esto toda llamada a un servidor
        // MCP se deniega sola: se preguntaba «¿qué reuniones tengo hoy?» y contestaba
        // que no podía consultar el calendario, con el conector conectado y sano. Y no
        // lo arregla el modo de permisos — con `acceptEdits` falla igual.
        //
        // Por servidor y no por herramienta porque enumerar las de lectura de cada
        // conector sería una lista que caduca con cada versión suya. Lo que no vale es
        // el comodín: `mcp__*` no autoriza nada, probado contra el CLI real.
        if (herramientasMcp.isNotEmpty) ...[
          '--allowedTools',
          ...herramientasMcp,
        ],
        // **Lo que no puede tocar.** Aquí van los comandos bloqueados de la carpeta y,
        // cuando es de solo lectura, las herramientas MCP que actúan fuera de la
        // máquina. La denegación gana al permiso, medido, así que permitir el servidor
        // entero y negar estas es seguro.
        if (disallowedTools.isNotEmpty) ...[
          '--disallowedTools',
          ...disallowedTools,
        ],
        // Al final y de una sola vez: el flag es variádico, así que cualquier
        // argumento que fuera detrás se lo tragaría como si fuera una carpeta.
        if (extraDirectories.isNotEmpty) ...['--add-dir', ...extraDirectories],
      ],
      workingDirectory: workingDirectory,
      environment: ClaudeEnvironment.forProfile(configDir),
      includeParentEnvironment: false,
    );
    // **Qué manos lleva este encargo, dicho una vez.**
    //
    // Se anota porque su ausencia costó una tarde: «no puedo consultar tu calendario»
    // con el conector conectado y sano no se parece a un problema de permisos, y desde
    // fuera no había forma de ver que el CLI arrancaba sin autorizar ninguna
    // herramienta. Una línea por encargo, no por herramienta: es una decisión y no un
    // caudal.
    debugPrint(
      'claude · perfil ${configDir ?? 'el de siempre'} · '
      // **Si hay alguien a quien preguntar, dicho en la misma línea.**
      //
      // Se anota por lo mismo que las herramientas de aquí al lado, y con un
      // caso propio ya vivido: se probó un encargo esperando el diálogo, no
      // salió, y desde fuera no había forma de distinguir «el canal no se
      // armó» de «el CLI no preguntó nada». Resolverlo costó media hora y
      // acabó siendo que el binario ni siquiera llevaba el cambio. Una línea
      // por encargo lo contesta antes de empezar a buscar.
      '${preguntando ? 'preguntando lo que no tenga concedido' : 'sin nadie a quien preguntar'} · '
      'modo $permissionMode · '
      '${herramientasMcp.length} servidores MCP permitidos'
      '${disallowedTools.isEmpty ? '' : ' · ${disallowedTools.length} herramientas negadas'}'
      '${model == null ? '' : ' · $model'}'
      '${effort == null ? '' : ' · esfuerzo $effort'}',
    );

    // Desde aquí ya se le puede rematar desde fuera, que es lo que hace falta
    // si alguien cancela mientras arranca.
    vivo.tomar(process, preguntando: preguntando);

    if (preguntando) {
      // La instrucción, ahora como mensaje del protocolo. **Y el stdin se queda
      // abierto**, al revés que en el camino de siempre: por ahí van las
      // respuestas a los permisos, y cerrarlo deja al CLI preguntando a una
      // puerta tapiada. Lo mismo hace `CorridaViva` con `flutter run --machine`.
      process.stdin.writeln(
        jsonEncode({
          'type': 'user',
          'message': {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': instruction},
            ],
          },
        }),
      );
    } else {
      // Sin esto, claude espera ~3s por si le llega algo por stdin antes de
      // arrancar — nadie le va a escribir nada, así que se lo avisamos ya.
      unawaited(process.stdin.close());
    }

    final stderrBuffer = StringBuffer();
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .listen(stderrBuffer.write)
        .asFuture<void>();

    try {
      // 🔴 **El final lo marca el proceso, no la pipa.** Ver
      // [ElFinalDeLaSalida]: los servidores MCP heredan esta salida y le
      // sobreviven, así que esperar a que se cierre sola es esperar a un
      // huérfano. Sin esto, un CLI que se muere antes del `result` dejaba el
      // turno girando para siempre y sin un proceso vivo al que culpar.
      final lines = ElFinalDeLaSalida.cuandoMuera(
        process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
        process.exitCode,
      );
      await for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final decoded = ClaudeCliDataSource.comoJson(line);
        // **Una línea que no es JSON no es el final del encargo.** Antes
        // `jsonDecode` reventaba con ella y se llevaba por delante la petición
        // entera —y encima disparaba el reintento sin memoria, que volvía a
        // chocar con lo mismo—. El CLI escribe texto plano cuando algo va mal
        // antes de arrancar el flujo; ahí es justo cuando hace falta leerlo.
        //
        // Va al mismo sitio que stderr porque acaba en el mismo mensaje: es lo
        // que el proceso tenía que decir antes de morir.
        if (decoded == null) {
          stderrBuffer.writeln(line);
          continue;
        }
        // El turno dejó un subagente trabajando aparte: a partir de aquí no se
        // le puede cerrar la entrada al terminar, porque ese subagente vive
        // dentro de este proceso. Ver [dejaUnAgenteTrabajando].
        if (dejaUnAgenteTrabajando(decoded)) vivo.quedaUnAgenteTrabajando();

        // Las preguntas de permiso no son eventos del encargo: no las ve el
        // dominio, se contestan aquí y el turno sigue como si nada.
        if (alPedirPermiso != null) {
          if (peticionDe(decoded) case final peticion?) {
            // **Sin `await`, y esto es lo importante.** Esperar aquí la
            // respuesta pararía de leer stdout mientras la persona mira el
            // diálogo, y por ahí siguen llegando los deltas del texto. La
            // pregunta se lanza y el bucle sigue; quien conteste escribe por
            // stdin cuando toque.
            // 🔴 **Y se apunta que hay una en pie.** Esta rama sale del
            // bucle por el `continue` de aquí abajo, sin pasar por la llamada
            // que reinicia la gracia del cierre: la línea que más necesita el
            // stdin abierto era justo la que no lo pedía.
            vivo.unPermisoEnPie();
            unawaited(
              _contestar(
                process,
                peticion,
                alPedirPermiso,
              ).whenComplete(vivo.unPermisoMenos),
            );
            continue;
          }
        }
        yield decoded;

        // 🔴 **El turno acabó: se le cierra el stdin y sale solo.** Sin esto se
        // queda leyendo una entrada que nadie va a volver a usar —los permisos
        // eran de este turno— y el proceso vive hasta que cierres la app. Uno
        // por encargo: 49 vivos y 3,92 GB medidos en un día.
        //
        // Se cierra **después** de emitir la línea, no antes: el `result` es lo
        // último que hay que entregar, y el bucle de aquí arriba termina solo
        // en cuanto el proceso suelte su stdout.
        if (decoded['type'] == 'result') {
          vivo.elTurnoAcabo();
        } else {
          // Que el modelo vuelva a producir es que hay **otro turno en
          // marcha**, no la cola del anterior: el CLI inyecta los avisos de las
          // tareas de fondo al retomar la sesión, contesta a eso y sigue con lo
          // tuyo en el mismo proceso. Ver [ElProcesoDelTurno.otroTurnoEmpezo].
          if (decoded['type'] == 'assistant') vivo.otroTurnoEmpezo();
          // Todo lo que llegue después del resultado vuelve a contar la gracia:
          // mientras hable, puede pedir un permiso más.
          vivo.todaviaHabla();
        }
      }

      // Primero el proceso y después su stderr, y no al revés: `exitCode`
      // llega siempre —lo resuelve el sistema al morir el hijo, no la pipa—,
      // mientras que el stderr lo puede estar sujetando un nieto. Esperarlo
      // sin tope era el mismo cuelgue por la otra salida.
      final exitCode = await process.exitCode;
      await Future.any([
        stderrDone,
        Future<void>.delayed(ElFinalDeLaSalida.gracia),
      ]);
      // 🔴 **Lo que matamos nosotros no es un fallo del encargo.** El `result`
      // ya salió por arriba —es lo último que hay que entregar— y solo después
      // se le cierra el stdin y, si no sale en diez segundos, se le remata con
      // `SIGKILL`. Ese remate vuelve aquí como `-9`, y enseñarlo como error
      // cuenta como roto un trabajo que salió bien: reportado tal cual, «me
      // salió un error, claude terminó con código -9».
      //
      // Se anota, que no es lo mismo que callarlo: un CLI que deja de salir
      // limpio es un cambio de comportamiento que conviene ver venir.
      if (vivo.loMatamosNosotros) {
        debugPrint('claude · salió con $exitCode porque lo rematamos nosotros');
      } else if (exitCode != 0) {
        throw ClaudeProcessException(exitCode, stderrBuffer.toString().trim());
      }
    } finally {
      // Si quien escuchaba se fue antes de que el proceso terminara —la
      // conversación se cerró, el encargo se canceló— hay que matarlo. Un
      // `claude -p` abandonado no se entera: sigue trabajando, gastando
      // contexto y tiempo para una respuesta que nadie va a leer. Este
      // `finally` también corre al cancelar la suscripción, que es justo el
      // caso que importa. Si el proceso ya salió, `kill` no hace nada.
      //
      // Y el stdin que dejamos abierto se cierra aquí: es nuestro, y un
      // descriptor suelto por encargo se acumula.
      if (preguntando) unawaited(process.stdin.close().catchError((_) {}));
      process.kill();
      // Y se desarma el remate: el proceso ya salió, así que el temporizador
      // solo serviría para mantener viva una referencia diez segundos más.
      vivo.olvida();
    }
  }

  /// Lo que dice el CLI cuando deja trabajo corriendo por su cuenta.
  ///
  /// Copiadas de corridas reales, no deducidas. Son varias porque hay varias
  /// formas de dejar algo detrás, y **mirar solo una fue el fallo**: con la
  /// primera puesta, retomar una revisión seguía matándola. El CLI no la lanza
  /// con `Agent` sino con `SendMessage`, y eso no dice «launched» sino
  /// `resumedAgentId` — reportado tras el arreglo: «volví a lanzar el flow
  /// review con la nueva versión» y se cortó igual.
  ///
  /// **La lista es generosa a propósito.** Equivocarse de más cuesta un proceso
  /// vivo unos minutos; equivocarse de menos cuesta el trabajo que pediste, y
  /// encima en silencio. No se parecen.
  static const marcasDeTrabajoDetras = [
    // Un `Agent` lanzado en segundo plano.
    'Async agent launched successfully',
    // Y el mismo, retomado: `SendMessage` contesta con esto.
    'resumedAgentId',
    // Un comando de `Bash` que sigue corriendo después de contestar.
    'Command running in background with ID',
    // Y un vigía, que existe justamente para hablar más tarde.
    'Monitor started',
  ];

  /// Si esta línea dice que el turno dejó trabajo corriendo por detrás.
  ///
  /// 🔴 **Un subagente asíncrono existe para seguir después del resultado, y
  /// nosotros matábamos el proceso justo ahí.** Reportado como «pedí un flow
  /// review y no sé si está corriendo o se murió»: se murió. El turno contestó
  /// «te traigo los hallazgos cuando termine», el `result` salió detrás, y a los
  /// segundos el subagente se cortó a mitad de leer archivos — vive dentro de
  /// este proceso, así que se va con él.
  ///
  /// Se mira el resultado de la herramienta y no su nombre: un `Agent` normal
  /// termina dentro del turno y no cambia nada. El que hay que esperar es el que
  /// dice que se lanzó y volverá.
  static bool dejaUnAgenteTrabajando(Map<String, dynamic> json) {
    if (json['type'] != 'user') return false;
    final content =
        (json['message'] as Map<String, dynamic>?)?['content']
            as List<dynamic>?;
    for (final block in content ?? const []) {
      if (block is! Map<String, dynamic>) continue;
      if (block['type'] != 'tool_result') continue;
      final dicho = _dice(block['content']);
      if (marcasDeTrabajoDetras.any(dicho.contains)) return true;
    }
    return false;
  }

  /// El texto de un `tool_result`, que llega suelto o en bloques según la
  /// herramienta. Aquí solo hace falta para buscar una marca dentro.
  static String _dice(Object? content) => switch (content) {
    String texto => texto,
    List<dynamic> bloques =>
      bloques
          .whereType<Map<String, dynamic>>()
          .map((b) => b['text'] as String? ?? '')
          .join('\n'),
    _ => '',
  };

  /// La petición de permiso que trae esta línea, o `null` si no es una.
  ///
  /// El CLI manda por el mismo canal otros `control_request` que no son
  /// preguntas para nadie —`request_user_dialog`, por ejemplo—, así que no
  /// vale con mirar el tipo: hay que mirar el `subtype`.
  ///
  /// Pública por el mismo motivo que [comoJson]: **para poder probarla sin
  /// lanzar un proceso**. Es la única forma de fijar contra qué JSON se
  /// programó, y aquí eso pesa más que de costumbre — el protocolo de control
  /// no está documentado, así que lo que hay es lo medido contra el binario y
  /// conviene que quede escrito en algún sitio que se ejecute.
  static PeticionDePermiso? peticionDe(Map<String, dynamic> json) {
    if (json['type'] != 'control_request') return null;
    final request = json['request'];
    if (request is! Map<String, dynamic>) return null;
    if (request['subtype'] != 'can_use_tool') return null;

    final id = json['request_id'];
    final herramienta = request['tool_name'];
    if (id is! String || herramienta is! String) return null;

    final entrada = request['input'];
    final nombreVisible = request['display_name'];
    final descripcion = request['description'];
    final toolUseId = request['tool_use_id'];
    final sugerencias = request['permission_suggestions'];
    return PeticionDePermiso(
      id: id,
      herramienta: herramienta,
      nombreVisible: nombreVisible is String && nombreVisible.isNotEmpty
          ? nombreVisible
          : herramienta,
      entrada: entrada is Map<String, dynamic> ? entrada : const {},
      descripcion: descripcion is String ? descripcion : null,
      toolUseId: toolUseId is String ? toolUseId : null,
      sugerencias: sugerencias is List
          ? [
              for (final una in sugerencias)
                if (una is Map<String, dynamic>) una,
            ]
          : const [],
    );
  }

  /// Pregunta y escribe la respuesta por stdin.
  ///
  /// **Un fallo aquí se convierte en una negación, nunca en silencio.** Si el
  /// diálogo revienta o quien tenía que contestar ya no está, el CLI se queda
  /// esperando para siempre una respuesta que no va a llegar y el turno cuelga
  /// sin decir por qué. Denegar al menos deja al modelo seguir y contarlo.
  static Future<void> _contestar(
    Process process,
    PeticionDePermiso peticion,
    Future<RespuestaDePermiso> Function(PeticionDePermiso) preguntar,
  ) async {
    RespuestaDePermiso respuesta;
    try {
      respuesta = await preguntar(peticion);
    } on Object catch (error) {
      debugPrint(
        'claude · el permiso de ${peticion.herramienta} falló: $error',
      );
      respuesta = const PermisoDenegado('Nexus no pudo preguntar.');
    }

    final cuerpo = switch (respuesta) {
      PermisoConcedido(:final entrada, :final permisosNuevos) => {
        'behavior': 'allow',
        'updatedInput': entrada,
        // Solo cuando hay algo que cambiar: mandar la lista vacía sería pedirle
        // al CLI que toque los permisos para no tocar ninguno.
        if (permisosNuevos.isNotEmpty) 'updatedPermissions': permisosNuevos,
      },
      PermisoDenegado(:final motivo) => {'behavior': 'deny', 'message': motivo},
    };
    try {
      process.stdin.writeln(
        jsonEncode({
          'type': 'control_response',
          'response': {
            'subtype': 'success',
            'request_id': peticion.id,
            'response': cuerpo,
          },
        }),
      );
    } on Object catch (error) {
      // El proceso ya no está: el encargo se canceló mientras el diálogo
      // estaba abierto. No hay nada que arreglar y nadie a quien avisar.
      debugPrint('claude · no se pudo contestar el permiso: $error');
    }
  }

  /// Una app de GUI no hereda el PATH del shell de login ni puede confiar en
  /// que `CLAUDE_CONFIG_DIR` venga seteado igual en cada lanzamiento: se
  /// parte del entorno completo del proceso (HOME, USER, etc.) y se fuerza
  /// lo que el bridge necesita, en vez de dejarlo a lo que herede.
}

/// El proceso de este turno, para poder rematarlo **desde fuera del generador**.
///
/// 🔴 **Hace falta porque cancelar no ejecuta el `finally` de un `async*`** —ver
/// [LaSalidaQueSeCancela], donde está medido—. Ese `finally` de ahí abajo lleva
/// escrito desde siempre el `kill` que nadie ejecutaba.
///
/// Y hay un segundo motivo, medido el mismo día: **el CLI ignora `SIGTERM`**. De
/// 52 procesos acumulados, 51 lo aguantaron. Como `Process.kill()` manda
/// `SIGTERM` por defecto, ese `kill` tampoco habría servido de haber corrido.
class ElProcesoDelTurno {
  Process? _proceso;
  var _preguntando = false;
  Timer? _remate;

  /// Si el proceso salió porque **nosotros** lo matamos.
  ///
  /// 🔴 **Porque un `-9` nuestro se estaba enseñando como un fallo del encargo.**
  /// Reportado tal cual: «me salió un error, claude terminó con código -9». Y el
  /// -9 es `SIGKILL`, o sea el remate de aquí: el turno **ya había entregado su
  /// resultado** —el `result` se emite antes de cerrarle el stdin— y lo único
  /// que pasó después es que el CLI no salió en diez segundos y se le remató.
  /// Enseñar eso como error es contar como roto un encargo que salió bien, y
  /// además invita a reintentarlo.
  bool get loMatamosNosotros => _rematado;

  var _rematado = false;

  /// Cuánto se le espera a que salga por las buenas antes de rematarlo.
  ///
  /// **Sale en 1,48 s, medido**: se lanzó el CLI en `stream-json`, se le cerró el
  /// stdin sin mandarle nada y salió con código 0. Diez segundos es casi siete
  /// veces eso, así que agotarlos no es «tardó un poco».
  static const plazo = Duration(seconds: 10);

  void tomar(Process proceso, {required bool preguntando}) {
    _proceso = proceso;
    _preguntando = preguntando;
  }

  /// El turno terminó: se le cierra la entrada y **se le deja salir solo**.
  ///
  /// Cerrar antes que matar no es cortesía: un CLI que sale limpio recoge a sus
  /// propios servidores MCP. Y sin esto no sale nunca, porque con
  /// `--input-format stream-json` se queda leyendo el stdin que le dejamos
  /// abierto para los permisos — un proceso dormido por encargo, que es la fuga
  /// que se midió en 49 procesos y 3,92 GB en un día.
  ///
  /// 🔴 **Pero no en el mismo instante, y esto se reportó con la pantalla
  /// delante:** «Tool permission request failed: AbortError: Stream closed»,
  /// lanzando un `flow review`. El `result` **no** es lo último que pasa: los
  /// hooks de cierre y los subagentes del marco siguen pidiendo herramientas
  /// después, y esas peticiones se encontraban el canal cerrado. Cerrarlo de
  /// golpe convertía la salida limpia en un permiso abortado.
  ///
  /// Así que se cuenta una gracia, y **cualquier cosa que siga diciendo la
  /// reinicia** —ver [todaviaHabla]—: un proceso que todavía habla no ha
  /// terminado de necesitar su entrada. La fuga sigue cubierta: lo que se
  /// alarga son segundos, no la vida de la app.
  void elTurnoAcabo() {
    if (_proceso == null || !_preguntando) return;
    _turnoAcabo = true;
    // El turno que había empezado después del resultado anterior ya acabó: se
    // vuelve al plazo corto, que es el que impide que se acumulen procesos.
    _otroTurnoEnMarcha = false;
    _programarCierre();
  }

  /// Una pregunta de permiso esperando a una persona.
  ///
  /// 🔴 **Mientras haya una en pie, la entrada no se cierra — y este era el
  /// agujero.** La gracia la reiniciaba [todaviaHabla], que se llama al final
  /// del bucle de lectura; pero una pregunta de permiso sale de ese bucle por un
  /// `continue` mucho antes de llegar ahí, así que **la única línea que de
  /// verdad necesita el stdin abierto era la única que no lo pedía**.
  ///
  /// Con el turno ya terminado, la cuenta de tres segundos seguía corriendo
  /// mientras la persona leía el diálogo. Leer tarda más que eso: a los tres
  /// segundos se cerraba la entrada por debajo, y la respuesta llegaba a un
  /// canal muerto. Reportado tal cual, empujando desde una conversación: «Tool
  /// permission request failed: AbortError: Stream closed» y el turno pegado.
  ///
  /// Se cuenta y no se marca con un booleano porque puede haber varias a la vez
  /// —los subagentes piden en paralelo— y la primera en contestarse no puede
  /// cerrarle la puerta a las demás.
  void unPermisoEnPie() {
    _enPie++;
    _cierre?.cancel();
    _cierre = null;
  }

  /// Contestada. La última en salir vuelve a contar la gracia.
  void unPermisoMenos() {
    if (_enPie > 0) _enPie--;
    if (_enPie == 0) _programarCierre();
  }

  var _enPie = 0;
  var _turnoAcabo = false;
  var _entradaCerrada = false;

  void _programarCierre() {
    final proceso = _proceso;
    if (proceso == null || !_preguntando) return;
    // Antes del `result` no hay nada que retrasar, y después de cerrar ya no hay
    // vuelta atrás.
    if (!_turnoAcabo || _entradaCerrada) return;
    _cierre?.cancel();
    if (_enPie > 0) {
      _cierre = null;
      return;
    }
    _cierre = Timer(_plazo, () => _cerrarLaEntrada(proceso));
  }

  /// Siguió llegando algo por su salida después del resultado.
  ///
  /// Solo cuenta con el cierre pendiente: antes del `result` no hay nada que
  /// retrasar, y después de cerrar ya no hay vuelta atrás.
  void todaviaHabla() => _programarCierre();

  void _cerrarLaEntrada(Process proceso) {
    _cierre = null;
    _entradaCerrada = true;
    unawaited(proceso.stdin.close().catchError((_) {}));
    _remate ??= Timer(plazo, () {
      debugPrint('claude · no salió al cerrarle el stdin: se remata');
      _rematado = true;
      proceso.kill(ProcessSignal.sigkill);
    });
  }

  /// Cuánto se espera desde el resultado —o desde lo último que dijo— antes de
  /// cerrarle la entrada.
  ///
  /// Tres segundos: los permisos que llegan tarde son de los hooks de cierre,
  /// que corren pegados al final del turno. Y cada línea que llegue vuelve a
  /// contarlos, así que un cierre con trabajo detrás no se queda corto.
  static const gracia = Duration(seconds: 3);

  /// Y cuánto cuando el turno dejó un subagente asíncrono trabajando.
  ///
  /// 🔴 **Tres segundos matan justo lo que se pidió.** Un subagente asíncrono
  /// se lanza *para* seguir después del resultado, así que el plazo de los
  /// hooks de cierre —que tardan un suspiro— lo corta a mitad. Medido en la
  /// máquina: lanzado a las 16:17:05, el turno contestó a las 16:17:07 y el
  /// subagente escribió por última vez a las 16:17:35, cortado leyendo
  /// archivos.
  ///
  /// Diez minutos **desde lo último que diga**, no desde el resultado: mientras
  /// trabaje va emitiendo, y cada línea vuelve a contarlos. Así que lo que se
  /// alarga de verdad es el rato que pasa callado al final, no el trabajo.
  static const graciaConAgente = Duration(minutes: 10);

  var _agenteAparte = false;

  /// El proceso volvió a trabajar **después** del resultado.
  ///
  /// 🔴 **Un proceso sirve más de un turno, y la gracia corta lo hacía polvo.**
  /// El CLI inyecta los avisos de las tareas de fondo que quedaron pendientes
  /// al retomar la sesión, así que atiende ese aviso, **emite su `result`**, y
  /// a continuación sigue con lo que le mandaste. De ahí en adelante la cuenta
  /// de tres segundos corre sobre un turno vivo, y lo único que la reinicia es
  /// que el proceso diga algo: una herramienta que tarde más de tres segundos
  /// en contestar no dice nada mientras corre.
  ///
  /// Medido en la sesión de `front-mobile-b2c`: la última línea salió a las
  /// 12:50:35, a las 12:50:38 se le cerró la entrada y a las 12:50:48 lo
  /// rematamos, con la herramienta devolviendo a las 12:50:42 y la respuesta
  /// sin llegar nunca. Ahí es donde se quedó pegado el orbe.
  ///
  /// El plazo largo es el mismo que el del subagente y por el mismo motivo: no
  /// se cuenta desde el resultado sino **desde lo último que dijo**, así que lo
  /// que se alarga es el silencio del final, no el trabajo. Y sigue acotado: un
  /// proceso que se cuelgue del todo se recoge igual.
  var _otroTurnoEnMarcha = false;

  /// El proceso está produciendo otra vez, con el turno ya dado por acabado.
  void otroTurnoEmpezo() {
    if (!_turnoAcabo || _otroTurnoEnMarcha) return;
    _otroTurnoEnMarcha = true;
    _programarCierre();
  }

  /// El turno dejó un subagente asíncrono en marcha.
  ///
  /// Puede llegar antes o después del resultado, así que reprograma lo que
  /// hubiera pendiente: si la cuenta corta ya estaba corriendo, se cambia por la
  /// larga en vez de dejar que venza.
  void quedaUnAgenteTrabajando() {
    if (_agenteAparte) return;
    _agenteAparte = true;
    _programarCierre();
  }

  Duration get _plazo =>
      _agenteAparte || _otroTurnoEnMarcha ? graciaConAgente : gracia;

  Timer? _cierre;

  /// Alguien canceló —Detener, o cerrar la conversación—: aquí no hay salida
  /// limpia que esperar, porque lo que se pidió fue que parase ya.
  ///
  /// `SIGKILL` y no el `kill()` de fábrica, por lo dicho arriba. Los servidores
  /// MCP se recogen igual: medido al limpiar 52 procesos, se fueron 195 hijos y
  /// no quedó ni un huérfano.
  Future<void> soltar() async {
    final proceso = _proceso;
    _cierre?.cancel();
    _cierre = null;
    olvida();
    if (proceso == null) return;
    _rematado = true;
    if (_preguntando) await proceso.stdin.close().catchError((_) {});
    proceso.kill(ProcessSignal.sigkill);
  }

  /// El proceso ya salió por su cuenta: no hay nada que rematar.
  void olvida() {
    _remate?.cancel();
    _remate = null;
    // Y la gracia: si el proceso ya salió, cerrarle la entrada dentro de tres
    // segundos sería tocar algo que ya no está.
    _cierre?.cancel();
    _cierre = null;
    _proceso = null;
  }
}

class ClaudeProcessException implements Exception {
  const ClaudeProcessException(this.exitCode, this.stderr);

  final int exitCode;
  final String stderr;

  @override
  String toString() => 'claude terminó con código $exitCode: $stderr';
}
