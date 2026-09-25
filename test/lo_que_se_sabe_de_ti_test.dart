import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/domain/usecases/a_donde_va_lo_que_se_escribe.dart';
import 'package:nexus/features/memoria/domain/entities/lo_que_se_sabe_de_ti.dart';
import 'package:nexus/features/memoria/domain/usecases/lo_que_se_pide_recordar.dart';

/// **Lo que Nexus sabe de ti, y no de la carpeta.**
///
/// 🔴 La memoria de hoy es del repositorio: la sesión de Claude vive en la
/// carpeta, así que lo que cuentas en una no existe en la de al lado. Eso es
/// correcto para el trabajo y es lo que falla para todo lo demás — en qué andas
/// esta semana, cómo te gusta que se hagan las cosas—. Esto viaja con todos los
/// encargos, de cualquier repo.
void main() {
  UnaCosaQueSeSabe cosa(String texto, [int dia = 1]) =>
      UnaCosaQueSeSabe(texto: texto, cuando: DateTime(2026, 9, dia));

  group('apuntar', () {
    test('lo nuevo va delante', () {
      final ya = [cosa('uso tabuladores')];

      final conMas = LoQueSeSabeDeTi.con(ya, cosa('estoy con la migración', 2));

      expect(conMas.first.texto, 'estoy con la migración');
      expect(conMas, hasLength(2));
    });

    // Lo mismo dicho dos veces no ocupa dos sitios, y se queda la nueva, que es
    // la que trae la fecha buena.
    test('lo repetido no se duplica', () {
      final ya = [cosa('uso tabuladores')];

      final conMas = LoQueSeSabeDeTi.con(ya, cosa('Uso Tabuladores  ', 5));

      expect(conMas, hasLength(1));
      expect(conMas.single.cuando.day, 5);
    });

    test('lo vacío no se apunta', () {
      final ya = [cosa('uno')];

      expect(LoQueSeSabeDeTi.con(ya, cosa('   ')), same(ya));
    });

    // 🔴 Esto entra en el prompt de **cada** encargo, así que lo que crezca
    // aquí se paga en cada turno de por vida.
    test('y hay tope: entra la nueva, sale la más vieja', () {
      final llenas = [
        for (var i = 0; i < LoQueSeSabeDeTi.cuantas; i++) cosa('cosa $i'),
      ];

      final conMas = LoQueSeSabeDeTi.con(llenas, cosa('la última'));

      expect(conMas, hasLength(LoQueSeSabeDeTi.cuantas));
      expect(conMas.first.texto, 'la última');
      expect(
        conMas.map((c) => c.texto),
        isNot(contains('cosa ${LoQueSeSabeDeTi.cuantas - 1}')),
      );
    });
  });

  group('olvidar', () {
    test('se va la que se señala', () {
      final ya = [cosa('uno'), cosa('dos'), cosa('tres')];

      expect(LoQueSeSabeDeTi.sin(ya, 1).map((c) => c.texto), ['uno', 'tres']);
    });

    // La lista se enseña en dos sitios —el chat y Ajustes—, así que un índice
    // viejo no puede borrar otra cosa.
    test('y un sitio que no existe no borra nada', () {
      final ya = [cosa('uno')];

      expect(LoQueSeSabeDeTi.sin(ya, 7), same(ya));
      expect(LoQueSeSabeDeTi.sin(ya, -1), same(ya));
    });
  });

  group('lo que viaja en el prompt', () {
    test('sin nada, no se manda nada', () {
      expect(LoQueSeSabeDeTi.paraElPrompt(const []), isNull);
    });

    test('van todas, y dicho como lo que son', () {
      final bloque = LoQueSeSabeDeTi.paraElPrompt([
        cosa('uso tabuladores'),
        cosa('estoy con la migración'),
      ])!;

      expect(bloque, contains('- uso tabuladores'));
      expect(bloque, contains('- estoy con la migración'));
      expect(
        bloque.toLowerCase(),
        contains('no'),
        reason: 'lleva el aviso de que es contexto y no una lista de tareas',
      );
    });

    test('y no se pasa del tope de caracteres', () {
      final largas = [for (var i = 0; i < 20; i++) cosa('x' * 300)];

      final bloque = LoQueSeSabeDeTi.paraElPrompt(largas)!;

      expect(
        bloque.length,
        lessThan(LoQueSeSabeDeTi.maxCaracteres + 300),
        reason: 'se paga en cada turno de por vida',
      );
    });
  });

  group('cómo se pide', () {
    test('«/recuerda algo» trae lo que hay que apuntar', () {
      expect(
        LoQueSePideRecordar.deLaFrase('/recuerda  uso tabuladores '),
        'uso tabuladores',
      );
      expect(
        LoQueSePideRecordar.deLaFrase('/memoria que me llamo Diego'),
        'que me llamo Diego',
      );
    });

    // El pelado lo reconoce el catálogo, que es quien enseña la lista.
    test('y «/recuerda» a secas no lo reconoce este', () {
      expect(LoQueSePideRecordar.deLaFrase('/recuerda'), isNull);
      expect(LoQueSePideRecordar.deLaFrase('/recuerda   '), isNull);
    });

    // 🔴 **Una frase natural se la queda Claude, y es lo correcto**: «recuerda
    // que ayer dejamos el PR a medias» es contexto de la conversación, no una
    // nota para siempre.
    test('y una frase natural no es una nota', () {
      expect(
        LoQueSePideRecordar.deLaFrase('recuerda que ayer dejamos el PR'),
        isNull,
      );
    });

    test('las dos formas acaban en la memoria', () {
      ADondeVa aDonde(String frase) => ADondeVaLoQueSeEscribe.de(
        frase,
        esElParte: false,
        hayAdjuntos: false,
      );

      expect(aDonde('/recuerda'), isA<ALaMemoria>());
      expect((aDonde('/recuerda') as ALaMemoria).queApuntar, isEmpty);
      expect(
        (aDonde('/recuerda uso tabuladores') as ALaMemoria).queApuntar,
        'uso tabuladores',
      );
    });
  });
}
