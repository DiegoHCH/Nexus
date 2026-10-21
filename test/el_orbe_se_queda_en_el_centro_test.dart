import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/presentation/widgets/el_escenario.dart';
import 'package:nexus/features/assistant/presentation/widgets/las_etiquetas_del_orbe.dart';

/// **Trabajando, el orbe se queda en el centro si los pasos caben.**
///
/// 🔴 Reportado el 21 oct, a pantalla completa en la pantalla grande: «el orbe
/// no se ve centrado». Se corría reservando a su derecha el ancho máximo de la
/// etiqueta de los pasos, 380 px, aunque la etiqueta se ajusta sola al hueco:
/// en la captura, 121 px a la izquierda para unos pasos que ocupaban 250.
void main() {
  Rect sitio(double sala, double alto, {required bool trabajando}) =>
      elSitioDelOrbe(
        sala: sala,
        alto: alto,
        trabajando: trabajando,
        debajo: 120,
      );

  // A la derecha del orbe, desde donde se mide lo que ocupan los pasos.
  double loQueQuedaALaDerecha(Rect orbe, double sala) =>
      sala - (orbe.center.dx + 0.47 * orbe.width) - sala * 0.03;

  test('la sala de la captura: trabajando, el orbe sigue en el centro', () {
    // La sala con la conversación abierta, en la pantalla grande.
    const sala = 1263.0, alto = 1080.0;
    final dormido = sitio(sala, alto, trabajando: false);
    final trabajando = sitio(sala, alto, trabajando: true);

    expect(trabajando.center.dx, sala / 2, reason: 'antes, 510');
    expect(trabajando, dormido, reason: 'ni se mueve ni cambia de tamaño');
    expect(
      loQueQuedaALaDerecha(trabajando, sala),
      greaterThanOrEqualTo(LasEtiquetasDelOrbe.anchoComodoDeLosPasos),
    );
  });

  test('sin sitio, se corre lo justo para un ancho cómodo, no el máximo', () {
    const sala = 968.0, alto = 768.0;
    final dormido = sitio(sala, alto, trabajando: false);
    final trabajando = sitio(sala, alto, trabajando: true);

    expect(trabajando.center.dx, lessThan(sala / 2), reason: 'se corre');
    expect(
      trabajando.width,
      moreOrLessEquals(dormido.width),
      reason: 'conserva su tamaño',
    );
    expect(
      loQueQuedaALaDerecha(trabajando, sala),
      moreOrLessEquals(LasEtiquetasDelOrbe.anchoComodoDeLosPasos),
      reason: 'lo justo: ni un píxel más de lo que pide un ancho cómodo',
    );
  });

  test('si ni corrido hasta el margen caben, se encoge sin salirse', () {
    const sala = 640.0, alto = 900.0;
    final dormido = sitio(sala, alto, trabajando: false);
    final trabajando = sitio(sala, alto, trabajando: true);

    expect(trabajando.width, lessThan(dormido.width));
    expect(trabajando.left, moreOrLessEquals(sala * 0.03));
    expect(
      loQueQuedaALaDerecha(trabajando, sala),
      moreOrLessEquals(LasEtiquetasDelOrbe.anchoComodoDeLosPasos),
    );
  });

  test('el ancho cómodo deja pintarse siempre a los pasos', () {
    // Si lo que se reserva bajara de lo mínimo, el orbe se quedaría centrado
    // y los pasos dejarían de verse trabajando.
    expect(
      LasEtiquetasDelOrbe.anchoComodoDeLosPasos,
      greaterThanOrEqualTo(LasEtiquetasDelOrbe.anchoMinimoDeLosPasos),
    );
  });
}
