import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/programadas/domain/entities/encargo_programado.dart';
import 'package:nexus/features/programadas/domain/usecases/lo_que_toca_lanzar.dart';

/// **Cuándo toca lanzar un encargo programado.**
///
/// Pedido así: «quiero que actualices el documento de lunes a viernes a las
/// 5pm». Hoy esa frase se atiende una vez y se olvida.
///
/// 🔴 Lo que se rompe aquí **no falla**: hace otra cosa. Lanza el día que no
/// era, lanza dos veces la misma tarea —y la segunda pisa lo que hizo la
/// primera—, o no lanza nada y no deja rastro. Por eso la regla vive suelta y
/// probada, como su hermana `LoQueTocaAvisar` de la agenda.
void main() {
  // Martes 15 de septiembre de 2026.
  final martes = DateTime(2026, 9, 15);
  DateTime elMartesALas(int hora, [int minuto = 0]) =>
      DateTime(martes.year, martes.month, martes.day, hora, minuto);

  EncargoProgramado unEncargo({
    Set<int>? dias,
    int hora = 17,
    int minuto = 0,
    DateTime? creado,
    DateTime? ultimaCorrida,
    bool activo = true,
  }) => EncargoProgramado(
    id: 'e1',
    carpeta: '/Users/alguien/General',
    tarea: 'actualiza el documento',
    dias: dias ?? EncargoProgramado.laborables,
    hora: hora,
    minuto: minuto,
    // Una semana antes, para que nada choque con el nacimiento salvo donde se
    // esté midiendo justo eso.
    creado: creado ?? martes.subtract(const Duration(days: 7)),
    ultimaCorrida: ultimaCorrida,
    activo: activo,
  );

  List<LoQueTocaConEl> a(DateTime cuando, [List<EncargoProgramado>? cuales]) =>
      LoQueTocaLanzar.revisar(cuales ?? [unEncargo()], cuando: cuando);

  group('a su hora', () {
    test('justo a las cinco, se lanza', () {
      expect(a(elMartesALas(17)).single, isA<LanzarloYa>());
    });

    // El reloj mira cada 30 segundos, así que nunca cae en el segundo exacto.
    test('y unos minutos después también, que el reloj no es puntual', () {
      expect(a(elMartesALas(17, 3)).single, isA<LanzarloYa>());
    });

    // Con la del lunes ya hecha, para aislar lo que se mide: sin eso lo que
    // sale es que la del lunes se perdió, que es verdad y es otra prueba.
    test('antes de la hora, todavía no', () {
      final alDia = unEncargo(ultimaCorrida: DateTime(2026, 9, 14, 17));

      expect(a(elMartesALas(16, 59), [alDia]), isEmpty);
    });

    test('un sábado no, aunque sean las cinco', () {
      final alDia = unEncargo(ultimaCorrida: DateTime(2026, 9, 18, 17));
      final sabado = DateTime(2026, 9, 19, 17);

      expect(a(sabado, [alDia]), isEmpty);
    });

    // 🔴 **Lo que enseñó escribir estas dos.** Mientras no conste que corrió,
    // la cita anterior sigue pendiente: el martes a las cinco menos uno, lo que
    // hay no es «nada todavía» sino «se pasó la del lunes». Es la respuesta
    // correcta —el lunes no corrió— y no es la que uno escribe de primeras.
    test('sin haber corrido nunca, la cita anterior está perdida', () {
      final loQueToca = a(elMartesALas(16, 59)).single;

      expect(loQueToca, isA<SePaso>());
      expect((loQueToca as SePaso).cuandoTocaba, DateTime(2026, 9, 14, 17));
    });
  });

  // 🔴 Dos veces la misma tarea es peor que ninguna: la segunda pisa lo que
  // hizo la primera.
  group('no se repite', () {
    test('lo que ya corrió hoy no vuelve a correr', () {
      final yaCorrio = unEncargo(ultimaCorrida: elMartesALas(17, 1));

      expect(a(elMartesALas(17, 4), [yaCorrio]), isEmpty);
    });

    test('pero al día siguiente sí, que es otra cita', () {
      final yaCorrio = unEncargo(ultimaCorrida: elMartesALas(17, 1));
      final miercoles = DateTime(2026, 9, 16, 17);

      expect(a(miercoles, [yaCorrio]).single, isA<LanzarloYa>());
    });
  });

  group('la que se pasó', () {
    // El caso que decidió el diseño: Nexus cerrado a las cinco, abierto a las
    // ocho.
    test('pasado el margen ya no se lanza: se dice', () {
      final loQueToca = a(elMartesALas(20)).single;

      expect(loQueToca, isA<SePaso>());
      expect((loQueToca as SePaso).cuandoTocaba, elMartesALas(17));
    });

    // 🔴 Tres días sin abrir la app no son tres tareas: «actualiza el
    // documento» sigue siendo una sola cosa por hacer.
    test('varios días perdidos son un solo aviso, el del último', () {
      final viernes = DateTime(2026, 9, 18, 20);
      final loQueToca = a(viernes).single as SePaso;

      expect(loQueToca.cuandoTocaba, DateTime(2026, 9, 18, 17));
    });

    // 🔴 **La que evita el aviso al nacer.** Sin mirar cuándo se creó, una
    // tarea escrita el martes a las ocho de la tarde anunciaría de entrada que
    // se perdió la de las cinco — de ese mismo día, cuando todavía no existía.
    test('no se avisa de una cita anterior a la propia tarea', () {
      final reciennacida = unEncargo(creado: elMartesALas(20));

      expect(a(elMartesALas(20, 1), [reciennacida]), isEmpty);
    });
  });

  // Apagar sin borrar: dejar de recibir algo no debería costar volver a
  // escribirlo entero.
  test('desactivada no hace nada, ni lanza ni avisa', () {
    final apagada = unEncargo(activo: false);

    expect(a(elMartesALas(17), [apagada]), isEmpty);
    expect(a(elMartesALas(20), [apagada]), isEmpty);
  });

  // Se enseña al programar, y es lo único que deja comprobar que se entendió:
  // «de lunes a viernes a las 5» y «el viernes a las 5» se confunden leyendo,
  // pero su próxima cita no se confunde con nada.
  group('la próxima vez', () {
    test('el mismo día si todavía no ha llegado', () {
      expect(
        LoQueTocaLanzar.proxima(unEncargo(), desde: elMartesALas(9)),
        elMartesALas(17),
      );
    });

    test('y el día siguiente que toque si ya pasó', () {
      expect(
        LoQueTocaLanzar.proxima(unEncargo(), desde: elMartesALas(18)),
        DateTime(2026, 9, 16, 17),
      );
    });

    test('saltándose el fin de semana', () {
      final viernesTarde = DateTime(2026, 9, 18, 18);

      expect(
        LoQueTocaLanzar.proxima(unEncargo(), desde: viernesTarde),
        DateTime(2026, 9, 21, 17),
        reason: 'el lunes, no el sábado',
      );
    });

    test('una desactivada no tiene próxima', () {
      expect(
        LoQueTocaLanzar.proxima(
          unEncargo(activo: false),
          desde: elMartesALas(9),
        ),
        isNull,
      );
    });
  });
}
