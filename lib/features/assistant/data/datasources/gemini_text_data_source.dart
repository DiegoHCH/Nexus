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
  }) async {
    if (llave.isEmpty) return null;
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
            {'type': 'text', 'text': laEntrada(instrucciones, frase)},
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
        debugPrint('ella · Gemini respondió ${respuesta.statusCode}');
        return null;
      }
      final texto = elTexto(cuerpo);
      if (texto == null) debugPrint('ella · Gemini no devolvió texto');
      return texto;
    } on Object catch (error) {
      debugPrint('ella · no se pudo preguntar a Gemini: ${error.runtimeType}');
      return null;
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
