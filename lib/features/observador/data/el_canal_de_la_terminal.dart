import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:nexus/features/remote/domain/constant_time.dart';

/// El canal por el que el mod `nexus-observador` le cuenta a Nexus lo que
/// pasa en tus sesiones de la terminal, y le pasa sus permisos.
///
/// **Solo `127.0.0.1` y con token.** El puerto y el token se anuncian en
/// [archivo], que solo tú puedes leer (`600`): los procesos que pueden leerlo
/// ya pueden hacer cualquier cosa como tú, así que no abre nada que no
/// estuviera abierto. Es un canal aparte del del teléfono, que por política
/// solo escucha en la dirección de Tailscale.
class ElCanalDeLaTerminal {
  ElCanalDeLaTerminal({
    required this.archivo,
    this.poll = const Duration(seconds: 25),
    this.plazo = const Duration(seconds: 30),
  });

  /// Dónde se anuncia el canal. El mod lo lee en
  /// `~/Library/Application Support/com.katanalabs.nexus/observador.json`.
  final File archivo;

  /// Cuánto se retiene cada pregunta de permiso antes de contestar «espera»:
  /// por debajo de los 30 s que tiene un `$.http.fetch` del mod.
  final Duration poll;

  /// Cuánto se espera en total a que contestes un permiso antes de
  /// devolvérselo a la terminal.
  ///
  /// 🔴 **Corto a propósito.** Mientras Nexus lo retiene, la terminal no
  /// enseña su pregunta: quien esté mirando la terminal y no a Nexus vería una
  /// sesión parada. Medio minuto alcanza para contestar desde Nexus, y
  /// pasado eso pregunta la terminal como siempre.
  final Duration plazo;

  HttpServer? _servidor;
  String _token = '';
  final _eventos = StreamController<Map<String, dynamic>>.broadcast();
  final _preguntas = StreamController<Map<String, dynamic>>.broadcast();
  final _vencidos = StreamController<String>.broadcast();
  final _respuestas = <String, Completer<String>>{};
  final _primeraVez = <String, DateTime>{};

  /// Lo que cuentan las sesiones: inicio, turno, herramienta, fin, cierre.
  Stream<Map<String, dynamic>> get eventos => _eventos.stream;

  /// Los permisos que llegan, una vez cada uno. Se contestan con [contestar].
  Stream<Map<String, dynamic>> get preguntas => _preguntas.stream;

  /// Los permisos que pasaron a la terminal sin que se contestaran aquí.
  Stream<String> get vencidos => _vencidos.stream;

  /// Abre el canal y lo anuncia. Devuelve el puerto.
  Future<int> abrir() async {
    final azar = Random.secure();
    _token = List.generate(
      32,
      (_) => azar.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _servidor = servidor;
    servidor.listen(_atender, onError: (Object _) {});
    archivo.parent.createSync(recursive: true);
    archivo.writeAsStringSync(
      jsonEncode({'puerto': servidor.port, 'token': _token, 'pid': pid}),
    );
    // Solo tú: el token es la llave del canal.
    await Process.run('chmod', ['600', archivo.path]);
    return servidor.port;
  }

  /// Cierra el canal y lo desanuncia. Los permisos en vuelo vuelven a su
  /// terminal.
  Future<void> cerrar() async {
    for (final respuesta in _respuestas.values) {
      if (!respuesta.isCompleted) respuesta.complete('terminal');
    }
    _respuestas.clear();
    await _servidor?.close(force: true);
    _servidor = null;
    try {
      // Solo si sigue siendo nuestro: otro Nexus pudo anunciarse después.
      final anunciado = jsonDecode(archivo.readAsStringSync());
      if (anunciado is Map && anunciado['token'] == _token) {
        archivo.deleteSync();
      }
    } on Object {
      // Ya no estaba, o no se puede leer: nada que desanunciar.
    }
  }

  /// La respuesta a un permiso, desde Nexus.
  void contestar(String id, String decision) {
    final respuesta = _respuestas[id];
    if (respuesta != null && !respuesta.isCompleted) {
      respuesta.complete(decision);
    }
  }

  Future<void> _atender(HttpRequest peticion) async {
    final respuesta = peticion.response;
    try {
      if (peticion.method != 'POST') {
        respuesta.statusCode = HttpStatus.methodNotAllowed;
        return;
      }
      final llave = peticion.headers.value(HttpHeaders.authorizationHeader);
      if (llave == null || !igualesSinDelatar(llave, 'Bearer $_token')) {
        respuesta.statusCode = HttpStatus.unauthorized;
        return;
      }
      final cuerpo = await utf8.decodeStream(peticion);
      if (cuerpo.length > 64 * 1024) {
        respuesta.statusCode = HttpStatus.requestEntityTooLarge;
        return;
      }
      final leido = jsonDecode(cuerpo);
      if (leido is! Map<String, dynamic>) {
        respuesta.statusCode = HttpStatus.badRequest;
        return;
      }
      final contestacion = switch (peticion.uri.path) {
        '/evento' => _alEvento(leido),
        '/permiso' => await _alPermiso(leido),
        _ => null,
      };
      if (contestacion == null) {
        respuesta.statusCode = HttpStatus.notFound;
        return;
      }
      respuesta.headers.contentType = ContentType.json;
      respuesta.write(jsonEncode(contestacion));
    } on Object catch (error) {
      debugPrint('la terminal · una petición que no se entendió: $error');
      respuesta.statusCode = HttpStatus.badRequest;
    } finally {
      await respuesta.close();
    }
  }

  Map<String, dynamic> _alEvento(Map<String, dynamic> evento) {
    _eventos.add(evento);
    return const {};
  }

  /// Retiene la pregunta hasta que contestes, hasta [poll] por vuelta y
  /// [plazo] en total. La primera vez que llega un permiso se anuncia.
  Future<Map<String, dynamic>> _alPermiso(Map<String, dynamic> pregunta) async {
    final id = pregunta['id'];
    if (id is! String || id.isEmpty) return const {'decision': 'terminal'};
    final ahora = DateTime.now();
    final primera = _primeraVez.putIfAbsent(id, () {
      _respuestas[id] = Completer<String>();
      _preguntas.add(pregunta);
      return ahora;
    });
    final queda = plazo - ahora.difference(primera);
    final respuesta = _respuestas[id];
    if (respuesta == null || queda <= Duration.zero) {
      _vencer(id);
      return const {'decision': 'terminal'};
    }
    final espera = queda < poll ? queda : poll;
    final decision = await respuesta.future.timeout(
      espera,
      onTimeout: () => queda <= poll ? 'terminal' : 'espera',
    );
    if (decision == 'terminal' && !respuesta.isCompleted) _vencer(id);
    if (decision != 'espera') {
      _respuestas.remove(id);
    }
    return {'decision': decision};
  }

  void _vencer(String id) {
    _respuestas.remove(id);
    _vencidos.add(id);
  }
}
