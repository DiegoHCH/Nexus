import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/domain/usecases/la_compresion_de_la_conversacion.dart';

/// Cuándo se comprime la conversación, y qué se cuenta después.
///
/// 🔴 **Las tres decisiones son caras de las dos maneras.** Comprimir de más
/// gasta un turno entero de Claude —un minuto largo— por nada. Comprimir de
/// menos deja que la ventana se llene y el contexto se recorte solo, sin que
/// nadie lo decida. Y contarlo mal es lo que producía «el contexto baja del
/// 132 % al 132 %», que además de no decir nada hacía dudar de si la compresión
/// había hecho algo.
void main() {
  group('cuándo toca', () {
    bool toca(int? contexto, {bool comprimiendo = false, int? dejoEn}) =>
        LaCompresionDeLaConversacion.toca(
          contexto: contexto,
          yaComprimiendo: comprimiendo,
          dondeLoDejoLaUltima: dejoEn,
        );

    test('por debajo del umbral no se toca nada', () {
      expect(toca(0), isFalse);
      expect(toca(84), isFalse);
    });

    test('desde el umbral, sí', () {
      expect(toca(LaCompresionDeLaConversacion.alPorCiento), isTrue);
      expect(toca(90), isTrue);
    });

    // La ventana puede pasarse del 100 %: el porcentaje se calcula contra la
    // que declara el modelo, y no es un tope duro.
    test('pasada la ventana, con más razón', () {
      expect(toca(132), isTrue);
    });

    // 🔴 La mitad de la decisión: `/compact` es un turno entero, y dispararlo
    // dos veces gasta dos.
    test('comprimiendo ya, no se dispara otra', () {
      expect(toca(95, comprimiendo: true), isFalse);
      expect(toca(132, comprimiendo: true), isFalse);
    });

    // 🔴 **El bucle que lo trajo.** Reportado así: «a cada rato me sale el
    // mensaje de comprimiendo esta conversación y nunca se comprime». Una
    // compresión que no baja nada deja la condición intacta, así que al final
    // del turno siguiente vuelve a cumplirse — siete veces seguidas en la
    // sesión medida, cero bajadas. Cada vuelta es un turno entero de Claude, y
    // encima toma el turno de la carpeta.
    test('donde la dejó la última y sigue ahí, no se reintenta', () {
      expect(toca(100, dejoEn: 100), isFalse);
      expect(toca(90, dejoEn: 95), isFalse);
    });

    // Pero si ha crecido desde entonces, sí: es contexto nuevo, no el mismo.
    test('si ha crecido desde entonces, otra vez sí', () {
      expect(toca(96, dejoEn: 95), isTrue);
      expect(toca(100, dejoEn: 90), isTrue);
    });

    // Sin compresión previa no hay nada que recordar, y manda el umbral.
    test('la primera vez no la frena nadie', () {
      expect(toca(90), isTrue);
      expect(toca(84, dejoEn: 50), isFalse, reason: 'el umbral sigue primero');
    });

    test('sin medida no se decide nada', () {
      expect(toca(null), isFalse);
      expect(toca(null, comprimiendo: true), isFalse);
    });
  });

  group('qué se cuenta después', () {
    LoQueDejoLaCompresion dejo(int antes, int? despues) =>
        LaCompresionDeLaConversacion.loQueDejo(antes: antes, despues: despues);

    test('con una medida nueva se cuenta la bajada entera', () {
      final r = dejo(90, 30) as BajoDe;

      expect(r.antes, 90);
      expect(r.despues, 30);
    });

    test('sin medida no se inventa una', () {
      expect(dejo(90, null), isA<SinMedidaTodavia>());
    });

    // 🔴 El caso que producía «baja del 132 % al 132 %». `copyWith` conserva el
    // valor anterior cuando le llega `null`, así que un número idéntico no
    // distingue «no se midió» de «no bajó» — y anunciar una bajada de X a X es
    // peor que no anunciarla.
    test('la misma medida es no haber medido, no una bajada de cero', () {
      expect(dejo(132, 132), isA<SinMedidaTodavia>());
      expect(dejo(90, 90), isA<SinMedidaTodavia>());
    });

    // Subir después de comprimir no debería pasar, pero si pasa se cuenta lo
    // que hay en vez de callarlo: un número raro delante es lo que hace que
    // alguien mire.
    test('una medida mayor se cuenta igual', () {
      final r = dejo(90, 95) as BajoDe;

      expect(r.despues, 95);
    });
  });
}
