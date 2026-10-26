import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nexus/core/platform/claude_environment.dart';
import 'package:nexus/core/platform/herramienta_externa.dart';
import 'package:nexus/features/artifacts/domain/entities/la_publicacion.dart';
import 'package:nexus/features/artifacts/domain/repositories/el_publicador.dart';

/// Publica en claude.ai **por una sesión interactiva de Claude Code que nadie
/// ve**.
///
/// 🔴 **Por qué así y no por `claude -p`, que es como Nexus habla con Claude.**
/// La herramienta `Artifact` no existe en headless: la documentación la deja
/// apagada en `-p` y en el Agent SDK sin forma de encenderla, `--allowedTools`
/// no la registra, y un mod que la llame desde `-p` recibe «no tool named
/// Artifact» —medido el 26 oct—. En una sesión interactiva sí está. Así que se
/// lanza una dentro de una pseudoterminal (`script`), con el mod
/// `mods/nexus-publicar` cargado: el mod la llama él mismo al arrancar, sin
/// pasar por el modelo, deja el enlace en `respuesta.json` y la sesión se para.
/// Medido: 9 s la primera publicación, 5 s una actualización.
///
/// No es una vía soportada: una versión del CLI que añada otra pregunta al
/// arrancar la deja esperando hasta el plazo. El día que `Artifact` llegue a
/// `-p`, esto sobra.
class ElPublicadorPorLaTerminal implements ElPublicador {
  ElPublicadorPorLaTerminal({
    required this._soporte,
    Future<String> Function()? rutaDeClaude,
    AssetBundle? bundle,
    this.plazo = const Duration(seconds: 120),
  }) : _rutaDeClaude = rutaDeClaude ?? HerramientaExterna.rutaDeClaude,
       _bundle = bundle ?? rootBundle;

  final Future<Directory> Function() _soporte;
  final Future<String> Function() _rutaDeClaude;
  final AssetBundle _bundle;

  /// Lo que se espera a la sesión oculta antes de darla por perdida.
  final Duration plazo;

  /// Los archivos del mod, como viajan en la app. Ver `pubspec.yaml`.
  static const losArchivosDelMod = [
    'mods/nexus-publicar/.claude-plugin/plugin.json',
    'mods/nexus-publicar/hooks/hooks.json',
    'mods/nexus-publicar/hooks/register.js',
    'mods/nexus-publicar/hooks/el_pedido.js',
  ];

  /// Con qué nombre queda la copia del documento en la carpeta de la sesión.
  /// La herramienta solo publica lo que está bajo la carpeta donde corre.
  static const laPagina = 'pagina.html';

  @override
  Future<LoQueSalioDePublicar> publicar({
    required String archivo,
    required String titulo,
    required String? cuenta,
    required String? enlace,
  }) async {
    final soporte = await _soporte();
    final Directory mod;
    final Directory raiz;
    final Directory aqui;
    try {
      mod = await _ponerElMod(soporte);
      raiz = Directory('${soporte.path}/publicar')..createSync(recursive: true);
      // Una carpeta por publicación, **dentro de la de siempre**: dos a la vez
      // no se pisan el pedido, y la confianza se hereda de la de arriba, que
      // es la única que hay que aceptar.
      aqui = Directory('${raiz.path}/${DateTime.now().microsecondsSinceEpoch}')
        ..createSync();
      File(archivo).copySync('${aqui.path}/$laPagina');
      File(
        '${aqui.path}/pedido.json',
      ).writeAsStringSync(elPedido(titulo: titulo, enlace: enlace));
    } on FileSystemException catch (error) {
      return NoSePudoPublicar(error.message);
    }
    try {
      return await _lanzar(aqui, mod: mod, raiz: raiz, cuenta: cuenta);
    } finally {
      try {
        aqui.deleteSync(recursive: true);
      } on FileSystemException {
        // Una carpeta de trabajo que se queda no estorba: la siguiente es otra.
      }
    }
  }

  @override
  Future<void> confiarEnLaCarpeta(
    HayQueConfiarEnLaCarpeta pedido, {
    String aviso = '',
  }) async {
    final soporte = await _soporte();
    final guion = File('${soporte.path}/confiar-para-publicar.command');
    guion.writeAsStringSync(
      elGuionDeConfianza(
        carpeta: pedido.carpeta,
        cuenta: pedido.cuenta,
        claude: await _rutaDeClaude(),
        aviso: aviso,
      ),
    );
    await Process.run('chmod', ['+x', guion.path]);
    await Process.run('open', ['-a', 'Terminal', guion.path]);
  }

  /// El mod, copiado a la carpeta de soporte: la sesión interactiva escribe sus
  /// tipos dentro de la carpeta del mod, y dentro de la app no se puede.
  Future<Directory> _ponerElMod(Directory soporte) async {
    final mod = Directory('${soporte.path}/mods/nexus-publicar');
    for (final asset in losArchivosDelMod) {
      final dentro = asset.substring('mods/nexus-publicar/'.length);
      final destino = File('${mod.path}/$dentro');
      destino.parent.createSync(recursive: true);
      destino.writeAsStringSync(await _bundle.loadString(asset, cache: false));
    }
    return mod;
  }

  Future<LoQueSalioDePublicar> _lanzar(
    Directory aqui, {
    required Directory mod,
    required Directory raiz,
    required String? cuenta,
  }) async {
    final Process proceso;
    try {
      proceso = await Process.start(
        '/usr/bin/script',
        losArgumentos(claude: await _rutaDeClaude(), mod: mod.path),
        workingDirectory: aqui.path,
        environment: {
          ...ClaudeEnvironment.forProfile(cuenta),
          // Sin terminal declarada, una interfaz de terminal no sabe pintar.
          'TERM': 'xterm-256color',
        },
        includeParentEnvironment: false,
      );
    } on ProcessException catch (error) {
      return NoSePudoPublicar(error.message);
    }

    // Lo que pinta la sesión, para ver si se quedó en una pregunta. Solo la
    // cola: es una interfaz que se repinta, y lo que importa es lo último.
    var pantalla = '';
    void oir(List<int> trozo) {
      pantalla += utf8.decode(trozo, allowMalformed: true);
      if (pantalla.length > 64 * 1024) {
        pantalla = pantalla.substring(pantalla.length - 32 * 1024);
      }
    }

    final oidos = [proceso.stdout.listen(oir), proceso.stderr.listen(oir)];
    var termino = false;
    unawaited(proceso.exitCode.then((_) => termino = true));

    final respuesta = File('${aqui.path}/respuesta.json');
    final hasta = DateTime.now().add(plazo);
    LoQueSalioDePublicar? salio;
    while (salio == null && DateTime.now().isBefore(hasta)) {
      if (respuesta.existsSync()) {
        // Ilegible es a medio escribir: se vuelve a mirar en la siguiente.
        salio = laRespuesta(respuesta.readAsStringSync());
      }
      if (salio == null && pideConfianza(pantalla)) {
        salio = HayQueConfiarEnLaCarpeta(raiz.path, cuenta: cuenta);
      }
      if (salio == null && termino) {
        salio = NoSePudoPublicar(
          'la sesión oculta terminó sin publicar: ${loUltimoQuePinto(pantalla)}',
        );
      }
      if (salio == null) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }

    await _parar(proceso);
    for (final oido in oidos) {
      await oido.cancel();
    }
    return salio ??
        NoSePudoPublicar(
          'la sesión oculta no respondió en ${plazo.inSeconds} s: '
          '${loUltimoQuePinto(pantalla)}',
        );
  }

  /// Para la sesión: `script` y lo que lanzó, con `TERM` y, si en tres
  /// segundos sigue ahí, con `KILL`. Medido: con `TERM` se va, pero tarda un
  /// momento.
  Future<void> _parar(Process proceso) async {
    final hijos = await _losHijosDe(proceso.pid);
    proceso.kill();
    for (final hijo in hijos) {
      Process.killPid(hijo);
    }
    final salio = await proceso.exitCode
        .then((_) => true)
        .timeout(const Duration(seconds: 3), onTimeout: () => false);
    if (!salio) proceso.kill(ProcessSignal.sigkill);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    for (final hijo in hijos) {
      Process.killPid(hijo, ProcessSignal.sigkill);
    }
  }

  Future<List<int>> _losHijosDe(int pid) async {
    try {
      final r = await Process.run('/usr/bin/pgrep', ['-P', '$pid']);
      return [
        for (final linea in '${r.stdout}'.split('\n'))
          ?int.tryParse(linea.trim()),
      ];
    } on ProcessException {
      return const [];
    }
  }

  // MARK: Lo puro, aparte para probarlo sin lanzar nada.

  /// Cómo se lanza la sesión oculta. `script` le da la pseudoterminal; sin ella
  /// Claude Code no arranca en interactivo.
  ///
  /// `--strict-mcp-config` y sin `--mcp-config`: **ningún servidor MCP**.
  /// Publicar no usa ninguno, y la cuenta del trabajo arranca 29: segundos de
  /// espera y procesos que luego hay que parar.
  @visibleForTesting
  static List<String> losArgumentos({
    required String claude,
    required String mod,
  }) => [
    '-q',
    '/dev/null',
    claude,
    '--plugin-dir',
    mod,
    '--allowedTools',
    'Artifact',
    '--strict-mcp-config',
  ];

  /// Lo que lee el mod. El archivo es la copia de esta carpeta.
  @visibleForTesting
  static String elPedido({required String titulo, required String? enlace}) =>
      jsonEncode({'archivo': laPagina, 'titulo': titulo, 'url': ?enlace});

  /// Lo que contestó el mod. `null` si todavía no se puede leer.
  @visibleForTesting
  static LoQueSalioDePublicar? laRespuesta(String texto) {
    final Object? crudo;
    try {
      crudo = jsonDecode(texto);
    } on FormatException {
      return null;
    }
    if (crudo is! Map) return null;
    final url = crudo['url'];
    if (crudo['ok'] == true && url is String && url.isNotEmpty) {
      return Publicado(url, nuevo: crudo['nuevo'] != false);
    }
    final error = crudo['error'];
    return NoSePudoPublicar(
      error is String && error.isNotEmpty ? error : 'el mod no dijo por qué',
    );
  }

  /// Si la sesión se quedó en la pregunta de confiar en la carpeta.
  ///
  /// 🔴 **Sin espacios, porque la pantalla no los trae.** La interfaz coloca
  /// cada palabra moviendo el cursor, así que lo que llega por la
  /// pseudoterminal es «Yes,Itrustthisfolder»: visto el 26 oct en la primera
  /// prueba, en una carpeta sin aceptar.
  @visibleForTesting
  static bool pideConfianza(String pantalla) {
    final plano = _sinCodigos(
      pantalla,
    ).replaceAll(RegExp(r'\s+'), '').toLowerCase();
    return plano.contains('itrustthisfolder') ||
        plano.contains('isthisaprojectyoucreated');
  }

  /// Las últimas palabras de la pantalla, para decir dónde se quedó.
  @visibleForTesting
  static String loUltimoQuePinto(String pantalla) {
    final limpio = _sinCodigos(pantalla).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (limpio.isEmpty) return 'no pintó nada';
    return limpio.length > 240
        ? '…${limpio.substring(limpio.length - 240)}'
        : limpio;
  }

  static String _sinCodigos(String texto) => texto
      .replaceAll(RegExp(r'\x1B\][^\x07\x1B]*(?:\x07|\x1B\\)'), '')
      .replaceAll(RegExp(r'\x1B\[[0-9;?<>=]*[ -/]*[@-~]'), '')
      .replaceAll(RegExp(r'\x1B[()][0-9A-Za-z]'), '')
      .replaceAll(RegExp(r'[\x00-\x08\x0B-\x1F\x7F]'), ' ');

  /// La terminal a la vista para aceptar la carpeta: entra en ella con la
  /// cuenta de la publicación y abre Claude Code, que pregunta.
  @visibleForTesting
  static String elGuionDeConfianza({
    required String carpeta,
    required String? cuenta,
    required String claude,
    required String aviso,
  }) {
    String q(String s) => "'${s.replaceAll("'", r"'\''")}'";
    return [
      '#!/bin/zsh',
      // La suscripción y no una clave: con una clave no se puede publicar.
      'unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN',
      'cd ${q(carpeta)} || exit 1',
      if (aviso.isNotEmpty) 'echo ${q(aviso)}',
      if (cuenta != null) 'export CLAUDE_CONFIG_DIR=${q(cuenta)}',
      'exec ${q(claude)}',
      '',
    ].join('\n');
  }
}
