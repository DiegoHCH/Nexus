import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/assistant/data/datasources/las_frases_hechas_data_source.dart';

// Las frases del acuse, dichas una vez con su voz y guardadas: tienen que sonar
// en menos de un segundo, y eso no deja tiempo para la red (29 sep).

void main() {
  late Directory tmp;
  late LasFrasesHechasDataSource disco;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('frases-hechas');
    disco = LasFrasesHechasDataSource(carpeta: tmp);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('lo guardado se lee de vuelta, y lo que falta no viene', () async {
    await disco.guardar('f1', 'Enseguida.', Uint8List.fromList([1, 2]));

    final leido = await disco.leer('f1', ['Enseguida.', 'Voy con eso.']);

    expect(leido.keys, ['Enseguida.']);
    expect(leido['Enseguida.'], [1, 2]);
  });

  // 🔴 Una frase dicha con la voz de antes es lo que se reportó el 25 sep —«en
  // ocasiones responde con otra voz»—, y aquí se oiría tal cual.
  test('otra voz, otro idioma u otro trato es otra firma', () {
    final base = LasFrasesHechasDataSource.firma(
      voz: 'Laomedeia',
      idioma: 'español de Colombia',
      tuyo: 'Master',
    );
    expect(
      LasFrasesHechasDataSource.firma(
        voz: 'Kore',
        idioma: 'español de Colombia',
        tuyo: 'Master',
      ),
      isNot(base),
    );
    expect(
      LasFrasesHechasDataSource.firma(
        voz: 'Laomedeia',
        idioma: 'English',
        tuyo: 'Master',
      ),
      isNot(base),
    );
    expect(
      LasFrasesHechasDataSource.firma(
        voz: 'Laomedeia',
        idioma: 'español de Colombia',
        tuyo: null,
      ),
      isNot(base),
    );
  });

  test('al cambiar de firma se olvida lo de la vieja', () async {
    await disco.guardar('vieja', 'Enseguida.', Uint8List.fromList([1]));
    await disco.guardar('nueva', 'Enseguida.', Uint8List.fromList([2]));

    await disco.olvidarLasDemas('nueva');

    expect(await disco.leer('vieja', ['Enseguida.']), isEmpty);
    expect((await disco.leer('nueva', ['Enseguida.']))['Enseguida.'], [2]);
  });

  test('los acuses llevan tu nombre y no conjugan hacia ti', () {
    const es = NexusStringsEs();
    const en = NexusStringsEn();
    expect(es.acuses('Master'), contains('Enseguida, Master.'));
    expect(en.acuses('Master'), contains('Right away, Master.'));
    expect(es.acuses(null), contains('Enseguida.'));
    // Ni «dame» ni «deme»: el trato lo pone la personalidad, que no se lee.
    for (final frase in es.acuses('Master')) {
      expect(frase, isNot(matches(RegExp(r'\b(dame|deme|déjame|déjeme)\b'))));
    }
  });
}
