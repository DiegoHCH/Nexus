import 'package:nexus/features/emulators/domain/entities/emulador.dart';
import 'package:nexus/features/run/domain/entities/corrida.dart';

/// **Cómo se reconoce la ventana del espejo de una corrida**, entre todas las
/// del Mac.
///
/// El espejo no es de Nexus: es scrcpy, el emulador, el Simulador o el
/// Duplicado de iPhone, cada uno con su ventana. Para pegarlo debajo de la
/// botonera hay que encontrar esa ventana desde fuera —por Accesibilidad—, y
/// esto es lo que se le dice al lado nativo que busque: de qué programa es y
/// qué dice su título.
class LaVentanaDelEspejo {
  const LaVentanaDelEspejo({
    this.ejecutables = const [],
    this.apps = const [],
    this.titulo,
  });

  /// Cómo empieza el nombre del ejecutable, para lo que no es una app con
  /// paquete: scrcpy, el `qemu-system-…` del emulador.
  final List<String> ejecutables;

  /// Los identificadores de paquete de las apps que pueden tenerla.
  final List<String> apps;

  /// Lo que tiene que decir su título. `null` es «la que haya»: el Duplicado
  /// de iPhone tiene una sola y no dice de qué teléfono es.
  final String? titulo;

  Map<String, Object?> toMap() => {
    'ejecutables': ejecutables,
    'apps': apps,
    'titulo': ?titulo,
  };

  @override
  bool operator ==(Object other) =>
      other is LaVentanaDelEspejo &&
      _iguales(other.ejecutables, ejecutables) &&
      _iguales(other.apps, apps) &&
      other.titulo == titulo;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(ejecutables), Object.hashAll(apps), titulo);

  static bool _iguales(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'LaVentanaDelEspejo(ejecutables: $ejecutables, apps: $apps, '
      'titulo: $titulo)';
}

/// **Qué espejo se pega a la botonera, y cómo encontrarlo.**
///
/// Pedido así: «que sean pegadas pero que al moverla se muevan juntas» — la
/// botonera y la pantalla del teléfono, leídas como una sola ventana. El
/// espejo sigue siendo el programa de siempre; lo que cambia es que Nexus lo
/// lleva pegado debajo de la barra.
abstract final class ElEspejoQueSePega {
  /// El Simulador de iOS.
  static const simulador = 'com.apple.iphonesimulator';

  /// Duplicado de iPhone y QuickTime, por este orden: el primero da control y
  /// es el que se abre para mirar y tocar; QuickTime es el que queda cuando no.
  static const duplicado = 'com.apple.ScreenContinuity';
  static const quickTime = 'com.apple.QuickTimePlayerX';

  /// La ventana que hace de espejo de [corrida], o `null` si no hay forma de
  /// reconocerla.
  ///
  /// [esFisico] es si el dispositivo está enchufado y no es un emulador: el
  /// mismo teléfono Android se ve con scrcpy si es de verdad y con la ventana
  /// del emulador si no.
  static LaVentanaDelEspejo? de(Corrida corrida, {required bool esFisico}) =>
      switch ((corrida.plataforma, esFisico)) {
        // scrcpy lleva de título el nombre del teléfono: es lo que se le pasa
        // al abrirlo, ver `ElEspejoDelMovil.argumentos`.
        (PlataformaEmulador.android, true) => LaVentanaDelEspejo(
          ejecutables: const ['scrcpy'],
          titulo: corrida.dispositivo,
        ),
        // El emulador se titula «Android Emulator - Pixel_9:5554»: el puerto es
        // lo único que distingue dos emuladores del mismo modelo, y es justo lo
        // que lleva el `emulator-5554` de la corrida.
        (PlataformaEmulador.android, false) => switch (_puerto(
          corrida.deviceId,
        )) {
          final puerto? => LaVentanaDelEspejo(
            ejecutables: const ['qemu-system'],
            titulo: ':$puerto',
          ),
          null => null,
        },
        (PlataformaEmulador.ios, false) => LaVentanaDelEspejo(
          apps: const [simulador],
          titulo: corrida.dispositivo,
        ),
        (PlataformaEmulador.ios, true) => const LaVentanaDelEspejo(
          apps: [duplicado, quickTime],
        ),
      };

  static String? _puerto(String deviceId) =>
      RegExp(r'^emulator-(\d+)$').firstMatch(deviceId)?.group(1);

  /// **Cuál se pega**: el del último que se abrió —o que empezó a correr— de
  /// los que siguen corriendo. Uno solo a la vez: dos espejos colgando de la
  /// misma barra ya no se leen como una ventana, se leen como un montón.
  ///
  /// [recientes] va de más viejo a más nuevo.
  static String? elQueToca(List<String> recientes, Set<String> conCorrida) {
    for (final id in recientes.reversed) {
      if (conCorrida.contains(id)) return id;
    }
    return null;
  }
}
