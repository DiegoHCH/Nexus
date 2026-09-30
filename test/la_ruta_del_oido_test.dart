import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';

/// Donde se dice cómo llegar al oído, **la ruta que ve el usuario**.
///
/// 🔴 Salió al escribir la guía de configuración de la voz (30 sep): el arranque
/// y la guía corta decían «Ajustes › Oído», y en Ajustes el oído vive bajo «Cómo
/// es ella» —la barra de la izquierda agrupa las secciones por pregunta—. Quien
/// lo buscaba por la ruta dicha no la encontraba escrita así en ninguna parte.
void main() {
  String laRuta(NexusStrings s) {
    final ajustes = s.settings[0] + s.settings.substring(1).toLowerCase();
    return '$ajustes › ${s.preguntaComoEsElla} › ${s.sectionOido}';
  }

  test('la ruta se arma con lo que se lee en Ajustes', () {
    expect(laRuta(const NexusStringsEs()), 'Ajustes › Cómo es ella › Oído');
    expect(
      laRuta(const NexusStringsEn()),
      'Settings › What she is like › Hearing',
    );
  });

  test('los textos que mandan al oído la dicen entera', () {
    for (final s in [const NexusStringsEs(), const NexusStringsEn()]) {
      final ruta = laRuta(s);
      expect(s.pasoSuNombreExplica('hestia'), contains(ruta));
      expect(s.guiaCortaComoHablarleCuerpo, contains(ruta));
      expect(s.elOidoSeEnciendeAlEmpezar('hestia'), contains(ruta));
    }
  });

  // Por el texto y no por los textos conocidos: el que se añada mañana con la
  // ruta vieja también tiene que caer aquí.
  test('ningún texto dice ya «Ajustes › Oído»', () {
    final viejas = RegExp(r'(Ajustes › Oído|Settings › Hearing)');
    final culpables = <String>[];
    for (final archivo in Directory('lib').listSync(recursive: true)) {
      if (archivo is! File || !archivo.path.endsWith('.dart')) continue;
      final lineas = archivo.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        final linea = lineas[i].trimLeft();
        // Los comentarios nombran la sección, no le dicen a nadie por dónde ir.
        if (linea.startsWith('//')) continue;
        if (viejas.hasMatch(linea)) culpables.add('${archivo.path}:${i + 1}');
      }
    }
    expect(culpables, isEmpty);
  });
}
