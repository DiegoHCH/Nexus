import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexus/core/design_system/nexus_theme.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';

/// **El orbe que sale al escritorio cuando la llamas.**
///
/// Corre en un motor de Flutter **aparte**, dentro de una ventana sin marco que
/// monta `NexusOrbeFlotante`. Aquí no hay app: hay un orbe y un canal que le
/// dice en qué estado pintarse.
///
/// 🔴 **Y dibuja el orbe de siempre, no uno nuevo.** Reescribirlo —en Swift o
/// aquí— sería tener dos orbes con cinco estados cada uno que alguien tendría
/// que mantener de acuerdo para siempre. Ese «alguien» no existe, así que se
/// importa el mismo widget y se acabó.
/// 🔴 **El punto de entrada vive en `lib/main.dart` y esto es solo el cuerpo.**
/// El motor busca la función **en la librería principal**, y con ella aquí el
/// arranque moría con «Could not resolve main entrypoint function» — medido
/// lanzando la app, no leído.
void arrancarElOrbeFlotante() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _ElOrbeSolo());
}

class _ElOrbeSolo extends StatefulWidget {
  const _ElOrbeSolo();

  @override
  State<_ElOrbeSolo> createState() => _ElOrbeSoloState();
}

class _ElOrbeSoloState extends State<_ElOrbeSolo> {
  static const _canal = MethodChannel('com.katanalabs.nexus/orbe.pinta');

  var _estado = NexusOrbState.listen;

  /// El acento que tenga la app. Llega con cada aviso porque este motor no
  /// comparte estado con el otro: son dos isolates, y lo único que los une es
  /// este canal.
  Color? _acento;

  @override
  void initState() {
    super.initState();
    _canal.setMethodCallHandler((llamada) async {
      if (llamada.method != 'estado') return null;
      final datos = llamada.arguments as Map?;
      final cual = datos?['estado'] as String?;
      final acento = datos?['acento'] as int?;
      setState(() {
        _estado = _elEstado(cual);
        if (acento != null) _acento = Color(acento);
      });
      return null;
    });
  }

  /// Por nombre y no por índice: el orden del enum es una decisión de otro
  /// archivo, y atarlos haría que añadir un estado cambiara lo que se pinta
  /// aquí sin que nadie lo tocara.
  static NexusOrbState _elEstado(String? nombre) =>
      NexusOrbState.values.where((uno) => uno.name == nombre).firstOrNull ??
      NexusOrbState.listen;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    // 🔴 **Con el tema de la casa, que sin él el orbe no se pinta.** Lanzado y
    // medido: el widget exige los colores de Nexus y revienta con un
    // `ThemeData` cualquiera —lo dice él mismo al fallar—. Oscuro siempre: esto
    // se dibuja sobre el escritorio y no sobre una pantalla de la app, así que
    // el claro no tiene fondo contra el que leerse.
    theme: NexusTheme.dark(accent: _acento),
    // Sin fondo: la ventana es transparente y lo que se ve es el escritorio.
    // Cualquier color aquí sería un cuadrado flotando sobre tu pantalla.
    // 🔴 **Sin `Scaffold`, y esto es lo que lo hacía un cuadrado negro.** El
    // `Scaffold` pinta el fondo del tema aunque se le pida transparente —lo que
    // se ve detrás es su `Material`—, y sobre un escritorio eso es un recuadro
    // opaco flotando. Lo reportó la captura: el orbe bien, el cuadro negro
    // también. Aquí no hace falta ninguna de las cosas que un `Scaffold` trae.
    home: ColoredBox(
      color: Colors.transparent,
      child: Center(child: NexusOrb(state: _estado, showHorizon: false)),
    ),
  );
}
