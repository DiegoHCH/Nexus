import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Una respuesta corta en texto de Gemini: la misma voz, escrita.
///
/// Para lo que ella contesta sin Claude —quién es, qué sabe hacer— cuando se
/// le pregunta **escribiendo**. Hablando ya lo contestaba el modelo de voz; por
/// escrito iba a Claude, que relee el contexto entero y cobra miles de tokens
/// por decir su nombre (reportado el 27 sep).
///
/// Contra la Interactions API, como las imágenes: misma ruta y misma revisión.
/// Las instrucciones van **dentro de la entrada** y no en un campo aparte: es
/// la forma que ya funciona con las imágenes, y un campo con el nombre mal
/// escrito no falla en el análisis, falla en la cara de quien pregunta.
class GeminiTextDataSource {
  const GeminiTextDataSource();

  static const _host = 'generativelanguage.googleapis.com';
  static const _ruta = '/v1beta/interactions';
  static const _revision = '2026-05-20';

  /// El modelo de texto rápido. Esto es una o dos frases: el grande no aporta.
  static const modelo = 'gemini-3.8-flash';

  /// Lo que contestó, o `null` si no se pudo: sin llave, sin red, un error del
  /// servicio o una respuesta sin texto. Quien llama decide qué hacer entonces.
  Future<String?> contestar({
    required String llave,
    required String instrucciones,
    required String frase,
    Duration tope = const Duration(seconds: 20),
    Duration antesDeReintentar = const Duration(milliseconds: 800),
  }) async {
    if (llave.isEmpty) return null;
    // 🔴 **Un 503 es el servicio saturado, no un no.** Pasó a la primera con la
    // llave de verdad (27 sep): la pregunta se fue a Claude por un rato malo de
    // Gemini. Se reintenta **una** vez tras un respiro; si sigue, a Claude.
    for (var intento = 0; intento < 2; intento++) {
      if (intento > 0) await Future<void>.delayed(antesDeReintentar);
      final (texto, reintentable) = await _unaVez(
        llave: llave,
        entrada: laEntrada(instrucciones, frase),
        tope: tope,
      );
      if (texto != null || !reintentable) return texto;
    }
    return null;
  }

  /// Se reintenta lo que es pasajero: saturado, demasiadas peticiones, un
  /// fallo suyo o la red.
  static bool esPasajero(int estado) =>
      estado == 429 || estado == 500 || estado == 503 || estado == 504;

  /// Una frase redactada para decirse, **en un intento y con prisa**.
  ///
  /// 🔴 **Sin reintento, al revés que [contestar].** Esto es lo que cuenta de
  /// por dónde va un encargo hablado (29 sep): si no llega en un par de
  /// segundos, lo que iba a contar ya es viejo, y quien pide tiene una frase
  /// de plantilla lista. Esperar al segundo intento sería llegar tarde dos
  /// veces. [peticion] va tal cual: aquí no se chatea.
  Future<String?> redactar({
    required String llave,
    required String peticion,
    Duration tope = const Duration(seconds: 3),
  }) async {
    if (llave.isEmpty) return null;
    final (texto, _) = await _unaVez(
      llave: llave,
      entrada: peticion,
      tope: tope,
    );
    return texto;
  }

  Future<(String?, bool)> _unaVez({
    required String llave,
    required String entrada,
    required Duration tope,
  }) async {
    final cliente = HttpClient()..connectionTimeout = tope;
    try {
      final peticion = await cliente
          .postUrl(Uri.https(_host, _ruta))
          .timeout(tope);
      peticion.headers
        ..set('x-goog-api-key', llave)
        ..set('Api-Revision', _revision)
        ..set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
      peticion.write(
        jsonEncode({
          'model': modelo,
          'input': [
            {'type': 'text', 'text': entrada},
          ],
        }),
      );
      final respuesta = await peticion.close().timeout(tope);
      final cuerpo = await respuesta
          .transform(utf8.decoder)
          .join()
          .timeout(tope);
      // Dicho en el registro y no en pantalla: si esto falla, la pregunta va
      // a Claude y se contesta igual, pero hay que poder saber por qué.
      if (respuesta.statusCode != 200) {
        debugPrint(
          'ella · Gemini respondió ${respuesta.statusCode}: '
          '${elMotivo(cuerpo) ?? 'sin motivo'}',
        );
        return (null, esPasajero(respuesta.statusCode));
      }
      final texto = elTexto(cuerpo);
      if (texto == null) debugPrint('ella · Gemini no devolvió texto');
      return (texto, false);
    } on Object catch (error) {
      debugPrint('ella · no se pudo preguntar a Gemini: ${error.runtimeType}');
      return (null, true);
    } finally {
      cliente.close(force: true);
    }
  }

  /// Las instrucciones y lo que se escribió, en una sola entrada.
  static String laEntrada(String instrucciones, String frase) =>
      '$instrucciones\n\n'
      'AHORA te escriben por el chat, no te hablan: contesta en texto, en una '
      'a tres frases, sin llamar a ninguna herramienta. Lo que te escribieron: '
      '«$frase»';

  /// El mensaje de error que manda Gemini, para el registro.
  static String? elMotivo(String cuerpo) {
    try {
      final leido = jsonDecode(cuerpo);
      if (leido case {'error': {'message': final String mensaje}}) {
        return mensaje;
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  /// El texto de la respuesta: el atajo `output_text` si viene, o los trozos
  /// de texto de sus pasos. `null` si no hay ninguno.
  static String? elTexto(String cuerpo) {
    final Object? leido;
    try {
      leido = jsonDecode(cuerpo);
    } on FormatException {
      return null;
    }
    if (leido is! Map<String, dynamic>) return null;
    if (leido['output_text'] case final String atajo
        when atajo.trim().isNotEmpty) {
      return atajo.trim();
    }
    final trozos = <String>[];
    final pasos = leido['steps'];
    if (pasos is List) {
      for (final paso in pasos) {
        if (paso is! Map<String, dynamic>) continue;
        // Los pensamientos no son la respuesta.
        if (paso['type'] == 'thought') continue;
        if (paso['text'] case final String t) trozos.add(t);
        final contenido = paso['content'];
        if (contenido is List) {
          for (final trozo in contenido) {
            if (trozo is Map<String, dynamic> && trozo['text'] is String) {
              trozos.add(trozo['text'] as String);
            }
          }
        }
      }
    }
    final texto = trozos.join().trim();
    return texto.isEmpty ? null : texto;
  }
}
