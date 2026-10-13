import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/agenda/domain/entities/reunion.dart';
import 'package:nexus/features/lo_que_te_espera/domain/entities/el_material_del_dia.dart';
import 'package:nexus/features/lo_que_te_espera/domain/usecases/lo_que_te_espera_hoy.dart';
import 'package:nexus/features/lo_que_te_espera/presentation/providers/lo_que_te_espera_provider.dart';
import 'package:nexus/features/prs/domain/entities/pr_por_revisar.dart';

/// Lo que te espera hoy: el parte hacia delante.
///
/// Su error se oye: un «no tienes reuniones» dicho con la agenda sin leer
/// todavía es mentir con la voz de quien sí sabe. Por eso lo que más se mira
/// aquí es que **lo que no se sabe, no se cuenta**.
void main() {
  // Lunes 12 de octubre de 2026, a las nueve.
  final ahora = DateTime(2026, 10, 12, 9);
  final frases = ElDiaQueTeEspera.lasFrasesDe(const NexusStringsEs());

  Reunion reunion(String titulo, int hora, {int invitados = 3}) => Reunion(
    id: titulo,
    titulo: titulo,
    comienza: DateTime(2026, 10, 12, hora),
    invitados: invitados,
  );

  PrPorRevisar pr(String titulo) =>
      PrPorRevisar(repo: 'org/app', numero: 1, titulo: titulo, autor: 'ana');

  String dicho(ElMaterialDelDia material) =>
      LoQueTeEsperaHoy.comoSeDice(material, ahora: ahora, frases: frases);

  group('las reuniones', () {
    test('cuántas quedan y cuál es la siguiente', () {
      final texto = dicho(
        ElMaterialDelDia(
          reuniones: [reunion('Retro', 16), reunion('Growth', 14)],
        ),
      );

      expect(texto, 'Te quedan 2 reuniones; la próxima, Growth, a las 14:00.');
    });

    test('las que ya pasaron y los bloques tuyos no cuentan', () {
      final texto = dicho(
        ElMaterialDelDia(
          reuniones: [
            reunion('Daily', 8),
            reunion('Foco', 10, invitados: 0),
            reunion('Growth', 14),
          ],
        ),
      );

      expect(texto, 'Te queda una reunión: Growth, a las 14:00.');
    });

    test('sin ninguna por delante, se dice: es una noticia', () {
      expect(
        dicho(ElMaterialDelDia(reuniones: [reunion('Daily', 8)])),
        'No te quedan reuniones hoy.',
      );
    });

    // 🔴 La que importa: «no te quedan reuniones» con la agenda sin leer.
    test('sin agenda que mirar no se dice que no hay', () {
      expect(
        dicho(const ElMaterialDelDia(cupoSemanal: 40)),
        isNot(contains('reuniones')),
      );
    });

    test('un título con comillas dobles no rompe la frase que se dice', () {
      final texto = dicho(
        ElMaterialDelDia(reuniones: [reunion('Demo "beta"', 14)]),
      );

      expect(texto, isNot(contains('"')));
      expect(texto, contains("Demo 'beta'"));
    });
  });

  group('lo demás', () {
    test('los PR: cuántos y el que más espera', () {
      expect(
        dicho(ElMaterialDelDia(prs: [pr('Fix login'), pr('Bump deps')])),
        '2 PR esperan tu revisión; el que más lleva, Fix login.',
      );
    });

    test('ningún PR por revisar no se dice: sería relleno', () {
      expect(dicho(const ElMaterialDelDia(prs: [])), frases.nada);
    });

    test('las programadas que no corrieron, y la próxima de hoy', () {
      final texto = dicho(
        ElMaterialDelDia(
          perdidas: const ['nexus'],
          proxima: (carpeta: 'web', cuando: DateTime(2026, 10, 12, 15, 30)),
        ),
      );

      expect(texto, contains('Una programada de nexus no se lanzó'));
      expect(
        texto,
        contains('La próxima programada corre a las 15:30 en web.'),
      );
    });

    test('una próxima que es mañana no es de hoy', () {
      final texto = dicho(
        ElMaterialDelDia(
          proxima: (carpeta: 'web', cuando: DateTime(2026, 10, 13, 9)),
        ),
      );

      expect(texto, frases.nada);
    });

    test('el cupo, al final', () {
      final texto = dicho(
        ElMaterialDelDia(reuniones: [reunion('Growth', 14)], cupoSemanal: 42),
      );

      expect(texto, endsWith('Llevas el 42 % del cupo de la semana.'));
      expect(texto, startsWith('Te queda una reunión'));
    });

    test('sin nada que se sepa, una frase y no un silencio', () {
      expect(
        dicho(const ElMaterialDelDia()),
        'Por ahora no tengo nada que contarte del día.',
      );
    });
  });

  group('cuándo se cuenta solo, al llamarla', () {
    test('la primera vez del día, sí', () {
      expect(
        LoQueTeEsperaHoy.tocaAlLlamarla(ahora: ahora, dichoEl: null),
        isTrue,
      );
      expect(
        LoQueTeEsperaHoy.tocaAlLlamarla(
          ahora: ahora,
          dichoEl: DateTime(2026, 10, 9),
        ),
        isTrue,
        reason: 'lo del viernes no cuenta para el lunes',
      );
    });

    test('ya dicho hoy, no: oírlo cada vez enseña a no llamarla', () {
      expect(
        LoQueTeEsperaHoy.tocaAlLlamarla(
          ahora: ahora,
          dichoEl: DateTime(2026, 10, 12),
        ),
        isFalse,
      );
    });

    test('fuera de jornada no hay día por delante que contar', () {
      expect(
        LoQueTeEsperaHoy.tocaAlLlamarla(
          ahora: DateTime(2026, 10, 10, 10),
          dichoEl: null,
        ),
        isFalse,
        reason: 'sábado',
      );
      expect(
        LoQueTeEsperaHoy.tocaAlLlamarla(
          ahora: DateTime(2026, 10, 12, 19),
          dichoEl: null,
        ),
        isFalse,
        reason: 'pasadas las seis',
      );
    });
  });

  group('cómo se pide escribiendo', () {
    test('las formas de preguntarlo, con o sin tildes y signos', () {
      for (final frase in [
        '¿Qué me espera hoy?',
        'que me espera',
        '¿Cómo viene el día?',
        "What's ahead today?",
      ]) {
        expect(LoQueTeEsperaHoy.loEstanPidiendo(frase), isTrue, reason: frase);
      }
    });

    test('lo que no es exactamente eso sigue su camino', () {
      for (final frase in [
        '¿qué tengo hoy?',
        'arregla lo que me espera en el login',
        'hoy',
      ]) {
        expect(
          LoQueTeEsperaHoy.loEstanPidiendo(frase),
          isFalse,
          reason: '«$frase» no es esta pregunta',
        );
      }
    });
  });
}
