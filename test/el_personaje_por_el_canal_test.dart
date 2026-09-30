import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/orbe_preference.dart';
import 'package:nexus/features/remote/data/el_personaje_por_el_canal.dart';

/// El personaje del Mac, dicho por el canal y leído en el teléfono. Los nombres
/// son los del protocolo (`docs/PROTOCOL.md`, 4.9), no los del enum.
void main() {
  test('se dice con los nombres del protocolo', () {
    expect(
      ElPersonajePorElCanal.deEstilo(
        const OrbeEstilo(
          personaje: true,
          luz: LuzDelPersonaje.horizonte,
          ojos: OjosDelPersonaje.deColor,
          colorDeLosOjos: Color(0xFFB06EFF),
        ),
      ),
      {
        'shown': true,
        'light': 'horizon',
        'eyes': 'color',
        'eyeColor': 0xFFB06EFF,
      },
    );
    // Sin personaje también se dice: es lo que apaga el del teléfono.
    expect(ElPersonajePorElCanal.deEstilo(OrbeEstilo.fabrica), {
      'shown': false,
      'light': 'suit',
      'eyes': 'asDrawn',
    });
  });

  test('ida y vuelta, sin tocar la forma del orbe del teléfono', () {
    const delMac = OrbeEstilo(
      forma: FormaDelOrbe.puntos,
      personaje: true,
      luz: LuzDelPersonaje.aura,
      ojos: OjosDelPersonaje.delAcento,
    );
    final enElTelefono = ElPersonajePorElCanal.aplicar(
      OrbeEstilo.fabrica,
      ElPersonajePorElCanal.deEstilo(delMac),
    );
    expect(enElTelefono.personaje, isTrue);
    expect(enElTelefono.luz, LuzDelPersonaje.aura);
    expect(enElTelefono.ojos, OjosDelPersonaje.delAcento);
    // La forma no viaja: el orbe del teléfono sigue siendo el suyo.
    expect(enElTelefono.forma, OrbeEstilo.fabrica.forma);
  });

  test('un Mac de antes no lo dice: el orbe', () {
    const antes = OrbeEstilo(personaje: true, luz: LuzDelPersonaje.aura);
    expect(ElPersonajePorElCanal.aplicar(antes, null).personaje, isFalse);
  });

  test('lo que no se entiende sale de fábrica, no revienta', () {
    final raro = ElPersonajePorElCanal.aplicar(OrbeEstilo.fabrica, {
      'shown': 'sí',
      'light': 'neón',
      'eyes': 3,
      'eyeColor': 'violeta',
    });
    expect(raro.personaje, isFalse);
    expect(raro.luz, LuzDelPersonaje.traje);
    expect(raro.ojos, OjosDelPersonaje.comoEstan);
  });
}
