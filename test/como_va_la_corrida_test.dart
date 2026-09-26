import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/emulators/domain/entities/emulador.dart';
import 'package:nexus/features/run/domain/entities/corrida.dart';
import 'package:nexus/features/run/domain/usecases/como_va_la_corrida.dart';
import 'package:nexus/features/run/domain/usecases/el_freno_de_la_app.dart';

/// Cómo va una corrida y qué se le ofrece, en orden.
///
/// Las dos reglas del mockup que se rompen sin que nadie lo note al añadir un
/// botón: que el punto diga lo mismo que la frase —verde corriendo, rojo con
/// errores, ámbar parada— y que **la acción que toca vaya primero**.
Corrida _corrida({
  EstadoDeCorrida estado = EstadoDeCorrida.corriendo,
  int errores = 0,
  LaParadaDeLaApp? parada,
  int? consola,
  String? url,
}) => Corrida(
  deviceId: 'emulator-5554',
  dispositivo: 'Pixel',
  proyecto: '/casa/tienda',
  configuracion: 'ci',
  plataforma: PlataformaEmulador.android,
  estado: estado,
  appId: 'abc',
  errores: errores,
  parada: parada,
  consola: consola,
  url: url,
);

const _parada = LaParadaDeLaApp(isolate: 'isolates/1');

void main() {
  group('el punto', () {
    test('corriendo y sin errores, corriendo', () {
      expect(ComoVaLaCorridaDe.de(_corrida()), ComoVaLaCorrida.corriendo);
    });

    // 🔴 La mentira que había: el daemon la da por «corriendo» aunque se
    // rompa en cada fotograma.
    test('con errores gana a corriendo', () {
      expect(
        ComoVaLaCorridaDe.de(_corrida(errores: 3)),
        ComoVaLaCorrida.conErrores,
      );
    });

    // Una app congelada no se arregla leyendo el error: primero se suelta.
    test('parada gana a los errores', () {
      expect(
        ComoVaLaCorridaDe.de(_corrida(errores: 3, parada: _parada)),
        ComoVaLaCorrida.parada,
      );
    });

    test('parando gana a todo', () {
      expect(
        ComoVaLaCorridaDe.de(
          _corrida(
            estado: EstadoDeCorrida.parando,
            errores: 3,
            parada: _parada,
          ),
        ),
        ComoVaLaCorrida.parando,
      );
    });

    test('compilando es arrancando, no «atención»', () {
      expect(
        ComoVaLaCorridaDe.de(_corrida(estado: EstadoDeCorrida.arrancando)),
        ComoVaLaCorrida.arrancando,
      );
    });
  });

  group('las acciones, la que toca primero', () {
    test('con errores, pasarle el error y luego el registro', () {
      final acciones = ComoVaLaCorridaDe.acciones(_corrida(errores: 2));

      expect(acciones.take(3), [
        AccionDeCorrida.pasarleElError,
        AccionDeCorrida.registro,
        AccionDeCorrida.registroDelSistema,
      ]);
      // Y no se pierde nada de lo de siempre: recargar sigue, y parar también.
      expect(acciones, contains(AccionDeCorrida.recargar));
      expect(acciones.last, AccionDeCorrida.parar);
      // Sin repetidos: el registro subió, no se duplicó.
      expect(acciones.toSet().length, acciones.length);
    });

    test('parada, los pasos del depurador primero y sin recargar', () {
      final acciones = ComoVaLaCorridaDe.acciones(_corrida(parada: _parada));

      expect(acciones.take(4), [
        AccionDeCorrida.seguir,
        AccionDeCorrida.siguienteLinea,
        AccionDeCorrida.entrar,
        AccionDeCorrida.salir,
      ]);
      // Recargar con la app detenida no recarga nada: primero hay que soltarla.
      expect(acciones, isNot(contains(AccionDeCorrida.recargar)));
      expect(acciones, isNot(contains(AccionDeCorrida.freno)));
    });

    test('sin errores ni parada, no hay pasos ni error que pasar', () {
      final acciones = ComoVaLaCorridaDe.acciones(_corrida());

      expect(acciones.first, AccionDeCorrida.recargar);
      expect(acciones, isNot(contains(AccionDeCorrida.pasarleElError)));
      expect(acciones, isNot(contains(AccionDeCorrida.seguir)));
    });

    test('compilando, solo los registros y parar', () {
      expect(
        ComoVaLaCorridaDe.acciones(
          _corrida(estado: EstadoDeCorrida.arrancando),
        ),
        [
          AccionDeCorrida.registro,
          AccionDeCorrida.registroDelSistema,
          AccionDeCorrida.parar,
        ],
      );
    });

    test('parando no ofrece parar otra vez', () {
      expect(
        ComoVaLaCorridaDe.acciones(_corrida(estado: EstadoDeCorrida.parando)),
        isNot(contains(AccionDeCorrida.parar)),
      );
    });

    test('la consola solo si la corrida la declaró', () {
      expect(
        ComoVaLaCorridaDe.acciones(_corrida()),
        isNot(contains(AccionDeCorrida.consola)),
      );
      expect(
        ComoVaLaCorridaDe.acciones(_corrida(consola: 9777)),
        contains(AccionDeCorrida.consola),
      );
    });
  });
}
