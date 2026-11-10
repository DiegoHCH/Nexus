import 'package:nexus/features/hub/domain/entities/dispositivo_del_hub.dart';

/// Una app que se puede correr: una carpeta de conversación con `pubspec.yaml`.
class AppDelHub {
  const AppDelHub({required this.ruta, required this.nombre});

  final String ruta;
  final String nombre;

  @override
  bool operator ==(Object other) =>
      other is AppDelHub && other.ruta == ruta && other.nombre == nombre;

  @override
  int get hashCode => Object.hash(ruta, nombre);

  @override
  String toString() => 'AppDelHub($nombre)';
}

/// Por qué no se puede correr ahora, **en el orden en que hay que arreglarlo**:
/// es el que seguía el menú de correr (`runEligeConfig` → `runSearchingDevices`
/// → `runNoDevices` → `runChooseDevice`), con lo que el hub añade delante y
/// detrás.
enum PorQueNoSeCorre {
  /// No hay ninguna carpeta con `pubspec.yaml` entre las conversaciones.
  sinApp,
  eligeConfig,
  buscando,
  sinDispositivos,
  eligeDispositivo,

  /// Arrancando: se corre solo en cuanto esté.
  arrancando,

  /// Ya corre en ese: lo que toca es la botonera, no ▶.
  yaCorre,
}

/// **Correr desde el hub** (P1): qué app, con qué configuración y en qué
/// dispositivo. Lo que no es de vista del menú de correr, aquí, para que lo
/// usen el hub y sus pruebas.
abstract final class CorrerDesdeElHub {
  /// **Las apps que se pueden correr** (P5): las carpetas de las conversaciones
  /// que tienen `pubspec.yaml`, la de la conversación activa primero y sin
  /// repetir —dos conversaciones pueden ser de la misma carpeta—.
  static List<AppDelHub> lasApps({
    required List<AppDelHub> carpetas,
    required bool Function(String ruta) tienePubspec,
    String? activa,
  }) {
    final vistas = <String>{};
    final apps = <AppDelHub>[];
    final enOrden = [
      ...carpetas.where((c) => c.ruta == activa),
      ...carpetas.where((c) => c.ruta != activa),
    ];
    for (final c in enOrden) {
      if (!vistas.add(c.ruta)) continue;
      if (tienePubspec(c.ruta)) apps.add(c);
    }
    return apps;
  }

  /// La app elegida: la que se eligió si sigue en la lista; si no, la primera
  /// (que es la de la conversación activa, si tiene app).
  static String? laApp(String? elegida, List<AppDelHub> apps) {
    if (apps.isEmpty) return null;
    if (elegida != null && apps.any((a) => a.ruta == elegida)) return elegida;
    return apps.first.ruta;
  }

  /// La configuración: la elegida en esta sesión, si no la recordada para esa
  /// app —la del menú de correr, `configsPorDefectoProvider`—, y si ninguna
  /// existe, ninguna: elegir por quien mira sería correr algo que no pidió.
  static String? laConfig(
    List<String> nombres, {
    String? deLaSesion,
    String? recordada,
  }) {
    if (deLaSesion != null && nombres.contains(deLaSesion)) return deLaSesion;
    if (recordada != null && nombres.contains(recordada)) return recordada;
    return null;
  }

  /// Por qué no se puede correr, o `null` si se puede.
  static PorQueNoSeCorre? porQueNo({
    required String? app,
    required String? config,
    required bool buscando,
    required List<DispositivoDelHub> dispositivos,
    required DispositivoDelHub? elegido,
  }) {
    if (app == null) return PorQueNoSeCorre.sinApp;
    if (config == null) return PorQueNoSeCorre.eligeConfig;
    if (dispositivos.isEmpty) {
      return buscando
          ? PorQueNoSeCorre.buscando
          : PorQueNoSeCorre.sinDispositivos;
    }
    if (elegido == null) return PorQueNoSeCorre.eligeDispositivo;
    return switch (elegido.estado) {
      EstadoDelDispositivo.corre => PorQueNoSeCorre.yaCorre,
      EstadoDelDispositivo.arrancando => PorQueNoSeCorre.arrancando,
      EstadoDelDispositivo.encendido || EstadoDelDispositivo.apagado => null,
    };
  }
}
