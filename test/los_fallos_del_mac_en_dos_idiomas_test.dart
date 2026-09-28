import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/remote/data/channel_link.dart';
import 'package:nexus/features/remote/presentation/el_fallo_en_palabras.dart';
import 'package:nexus_protocol/nexus_protocol.dart';

/// **Lo que el Mac contesta que no, en el idioma del teléfono.**
///
/// El Mac manda un código y una frase para su registro en **su** idioma. La
/// frase no se enseña —un teléfono en inglés la leería en español—: se traduce
/// el código con los textos del teléfono. Aquí se vigila que cada código tenga
/// su texto en los dos idiomas, que los datos entren en la frase, y que los dos
/// sentidos de la compatibilidad —un Mac más nuevo, uno más viejo— digan algo.
void main() {
  const es = NexusStringsEs();
  const en = NexusStringsEn();

  group('cada código, en los dos idiomas', () {
    for (final codigo in FailureCode.values) {
      test(codigo.name, () {
        final enEspanol = ElFalloEnPalabras.delCodigo(es, codigo.name);
        final enIngles = ElFalloEnPalabras.delCodigo(en, codigo.name);

        expect(enEspanol, isNotEmpty);
        expect(enIngles, isNotEmpty);
        // Una traducción que se quedara copiando el español compilaría igual:
        // el getter existe en los dos. Esto no.
        expect(enIngles, isNot(enEspanol), reason: 'sin traducir');
        // Y ninguno cae en el comodín de «no lo conozco»: es un código del
        // contrato, y el teléfono tiene que saber qué decir de él.
        expect(enEspanol, isNot(es.mobileFailUnknownCode(codigo.name)));
        expect(enIngles, isNot(en.mobileFailUnknownCode(codigo.name)));
      });
    }
  });

  group('los datos van en la frase de este idioma', () {
    test('cuánto ocupa el documento que no cabe', () {
      const args = {FailureArg.kb: 3072, FailureArg.artifact: 'informe.md'};
      expect(
        ElFalloEnPalabras.delCodigo(es, 'artifactTooLarge', args: args),
        contains('3072 KB'),
      );
      expect(
        ElFalloEnPalabras.delCodigo(en, 'artifactTooLarge', args: args),
        allOf(contains('3072 KB'), contains('open it on the Mac')),
      );
    });

    test('la versión que el Mac ofrece ahora', () {
      const args = {FailureArg.version: '1.36.0'};
      expect(
        ElFalloEnPalabras.delCodigo(en, 'updateChanged', args: args),
        contains('1.36.0'),
      );
    });

    // Un Mac anterior a `a` manda el código sin los datos. La frase tiene que
    // decir lo mismo sin el número, y no un «null KB».
    test('sin los datos —un Mac viejo— se dice igual, sin el número', () {
      for (final strings in [es, en]) {
        final texto = ElFalloEnPalabras.delCodigo(strings, 'artifactTooLarge');
        expect(texto, isNot(contains('null')));
        expect(texto, isNot(contains('KB')));
        expect(
          ElFalloEnPalabras.delCodigo(strings, 'updateChanged'),
          isNot(contains('null')),
        );
      }
    });
  });

  group('la frase del Mac no se enseña nunca', () {
    test('un «no» del Mac se dice con el código, no con su `msg`', () {
      // El marco tal como lo escribe un Mac en español.
      final marco =
          Frame.decode(
                '{"t":"failure","id":"q","code":"tooManyConversations",'
                '"msg":"el Mac ya tiene todas sus conversaciones abiertas"}',
              )
              as Failure;
      final error = LinkError(
        LinkFailure.rechazada,
        code: marco.code,
        message: marco.message,
        args: marco.args,
      );

      final texto = ElFalloEnPalabras.de(en, error);
      expect(texto, en.mobileFailTooManyConversations);
      expect(texto, isNot(contains(marco.message)));
    });

    test('la frase de escritura sigue diciendo lo suyo', () {
      expect(
        ElFalloEnPalabras.delCodigo(en, 'wrongPhrase'),
        en.mobileWrongPhrase,
      );
      expect(ElFalloEnPalabras.delCodigo(es, 'noPhrase'), es.mobileNoPhrase);
    });
  });

  group('lo que no es un «no» del Mac', () {
    test('un código del futuro dice que el Mac dijo que no, y cuál', () {
      final texto = ElFalloEnPalabras.delCodigo(en, 'telepathy');
      expect(texto, en.mobileFailUnknownCode('telepathy'));
      expect(texto, contains('telepathy'));
    });

    test('sin enlace no hay nada que traducir: lo cuenta la cabecera', () {
      expect(
        ElFalloEnPalabras.de(es, const LinkError(LinkFailure.desconectado)),
        isNull,
      );
      expect(
        ElFalloEnPalabras.de(es, const LinkError(LinkFailure.sinRespuesta)),
        isNull,
      );
      expect(ElFalloEnPalabras.de(es, StateError('otra cosa')), isNull);
    });
  });
}
