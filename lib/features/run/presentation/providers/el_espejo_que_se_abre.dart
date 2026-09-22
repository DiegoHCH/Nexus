import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/features/emulators/presentation/providers/emuladores_providers.dart';
import 'package:nexus/features/run/presentation/providers/corridas_providers.dart';

final elEspejoQueSeAbreProvider = Provider<ElEspejoQueSeAbre>(
  ElEspejoQueSeAbre.new,
);

/// La pantalla del móvil, abierta sola al correr la app en uno físico.
///
/// Pedido así: «cuando compile la app, también se lance —obvio, si es
/// dispositivo físico— igual que el dashboard que se abre solo». Y se hace
/// donde ya se hacía lo otro: `LaConsolaQueSeAbre` resuelve el mismo problema
/// para la consola de depuración, y las dos cuelgan del mismo arranque.
///
/// Aparte del controlador de corridas a propósito, por el mismo motivo que
/// aquélla: el controlador lleva el proceso y su estado, y esto es una decisión
/// —¿se puede espejar?, ¿ya hay uno?— que se prueba sin lanzar un `flutter run`.
class ElEspejoQueSeAbre {
  ElEspejoQueSeAbre(this._ref);

  final Ref _ref;

  /// Al arrancar una corrida: si es un móvil físico, se abre su pantalla.
  ///
  /// **Nada de esto es un fallo de la corrida.** Que no haya scrcpy, que sea un
  /// emulador o que el espejo no arranque no puede impedir que la app corra: es
  /// una comodidad, y se cuenta en el registro de la corrida como lo demás.
  Future<void> alArrancar({
    required String deviceId,
    required String dispositivo,
  }) async {
    // Emulador, iPhone o sin scrcpy instalado: no hay nada que abrir. Es el
    // mismo criterio que decide si el botón se pinta, y vive en un solo sitio
    // justamente para que no se separen.
    if (!_ref.read(sePuedeVerLaPantallaProvider(deviceId))) return;

    final emuladores = _ref.read(emuladoresDataSourceProvider);
    // Uno por teléfono: volver a correr con la ventana anterior abierta no
    // puede dejar dos espejos del mismo móvil.
    if (await emuladores.yaHayEspejoDe(deviceId)) return;

    final problema = await emuladores.verLaPantalla(
      deviceId: deviceId,
      titulo: dispositivo,
      // Con control: quien corre la app en su teléfono va a querer tocarla, y
      // un espejo de solo mirar obligaría a soltar el ratón y coger el móvil.
      conControl: true,
    );
    if (problema == null) return;

    // Se dice donde se está mirando, como los problemas del túnel de la
    // consola, y no en un aviso que tape la pantalla.
    _ref.read(registrosProvider.notifier).anota(deviceId, 'espejo: $problema');
  }
}
