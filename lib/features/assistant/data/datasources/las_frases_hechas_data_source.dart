import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Las frases ya dichas con su voz, guardadas en la carpeta de la app.
///
/// Una carpeta por **firma** —la voz, el idioma con su acento y cómo te llama—
/// y un `.pcm` por frase. Al cambiar cualquiera de las tres cambia la firma, y
/// las de la firma vieja se borran: una frase dicha con la voz de antes es
/// justo lo que se reportó el 25 sep —«en ocasiones responde con otra voz»—, y
/// aquí no se renegocia nada, se oye tal cual.
///
/// PCM crudo y no WAV: es lo que come el motor —16 bits mono a 24 kHz— y lo que
/// devuelve el servicio de voz. Sin cabecera no hay nada que convertir.
class LasFrasesHechasDataSource {
  const LasFrasesHechasDataSource({this.carpeta});

  /// Dónde viven. `null` es la carpeta de la app; las pruebas ponen otra.
  final Directory? carpeta;

  static const _raiz = 'frases-hechas';

  /// La firma de lo que suena: si cambia, lo guardado ya no vale.
  static String firma({
    required String voz,
    required String idioma,
    required String? tuyo,
  }) => sha1
      .convert(utf8.encode('v1|$voz|$idioma|${tuyo ?? ''}'))
      .toString()
      .substring(0, 12);

  static String _nombre(String texto) =>
      '${sha1.convert(utf8.encode(texto)).toString().substring(0, 16)}.pcm';

  Future<Directory> _deLaFirma(String firma) async {
    final base = carpeta ?? await getApplicationSupportDirectory();
    return Directory('${base.path}/$_raiz/$firma');
  }

  /// Lo guardado de [textos] con esta [firma]. Las que falten no vienen.
  Future<Map<String, Uint8List>> leer(String firma, List<String> textos) async {
    final hechas = <String, Uint8List>{};
    try {
      final dir = await _deLaFirma(firma);
      for (final texto in textos) {
        final f = File('${dir.path}/${_nombre(texto)}');
        if (f.existsSync()) hechas[texto] = await f.readAsBytes();
      }
    } on Object catch (error) {
      // Sin lo guardado se dicen al vuelo: más lento, no roto.
      debugPrint('frases hechas · no se pudieron leer: $error');
    }
    return hechas;
  }

  Future<void> guardar(String firma, String texto, Uint8List pcm) async {
    try {
      final dir = await _deLaFirma(firma);
      await dir.create(recursive: true);
      await File('${dir.path}/${_nombre(texto)}').writeAsBytes(pcm);
    } on Object catch (error) {
      debugPrint('frases hechas · no se pudo guardar «$texto»: $error');
    }
  }

  /// Borra lo de las firmas que no son [firma].
  Future<void> olvidarLasDemas(String firma) async {
    try {
      final dir = await _deLaFirma(firma);
      final raiz = dir.parent;
      if (!raiz.existsSync()) return;
      for (final otra in raiz.listSync().whereType<Directory>()) {
        if (otra.path != dir.path) await otra.delete(recursive: true);
      }
    } on Object catch (error) {
      debugPrint('frases hechas · no se pudo limpiar: $error');
    }
  }
}
