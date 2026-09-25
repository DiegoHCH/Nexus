import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';

/// **El teléfono habla los dos idiomas del Mac.**
///
/// Tenía todo el texto escrito a mano en español, y en el menú llamaba «Los
/// artifacts» y «El archivo» a lo que el escritorio ya llamaba «Documentos» e
/// «Historial»: dos nombres para lo mismo, en dos aparatos que se usan uno al lado
/// del otro.
void main() {
  const es = NexusStringsEs();
  const en = NexusStringsEn();

  test('lo que produjo Claude son «Documentos», como en el Mac', () {
    expect(es.mobileDocuments, 'Documentos');
    expect(es.mobileDocuments, es.artifacts);
    expect(en.mobileDocuments, 'Documents');
  });

  test('las conversaciones de antes son el «Historial»', () {
    expect(es.mobileHistory, 'Historial');
    expect(en.mobileHistory, 'History');
  });

  test('cada idioma dice lo suyo', () {
    // Si una traducción se quedara copiando el español, el compilador no lo vería:
    // el getter existe en los dos. Esto sí.
    expect(en.mobileDocuments, isNot(es.mobileDocuments));
    expect(en.mobileSearchingForMac, isNot(es.mobileSearchingForMac));
    expect(en.mobileWrongPhrase, isNot(es.mobileWrongPhrase));
    expect(en.mobileTurns(3), isNot(es.mobileTurns(3)));
  });

  test('el idioma del sistema decide, y lo que no es inglés es español', () {
    expect(NexusStrings.of(const Locale('en')), isA<NexusStringsEn>());
    expect(NexusStrings.of(const Locale('es')), isA<NexusStringsEs>());
    expect(NexusStrings.of(const Locale('fr')), isA<NexusStringsEs>());
  });
}
