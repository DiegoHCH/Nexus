/// **La app del teléfono se actualiza sola**, desde las releases de GitHub.
///
/// Hasta la 1.34 había que enchufar el teléfono y reinstalarla a mano en cada
/// versión, porque las releases solo traían lo del Mac. Ahora cada release
/// pública trae también su APK —`Nexus-movil-<versión>.apk`— firmado siempre
/// con la misma llave, y el teléfono mira `releases/latest`: si hay uno más
/// nuevo que el suyo, lo ofrece.
///
/// **Solo las públicas**: `releases/latest` nunca devuelve una interna, así que
/// una versión a medio cerrar no le llega a nadie, igual que en el Mac.
class LaVersionNueva {
  const LaVersionNueva({
    required this.version,
    required this.url,
    required this.bytes,
  });

  final String version;
  final Uri url;
  final int bytes;

  static final _elApk = RegExp(r'^Nexus-movil-(\d+\.\d+\.\d+)\.apk$');

  /// Lo que trae la release, o `null` si no trae APK del teléfono (las de
  /// antes de esto) o no se entiende.
  static LaVersionNueva? deLaRelease(Object? json) {
    if (json is! Map) return null;
    if (json['prerelease'] == true || json['draft'] == true) return null;
    final assets = json['assets'];
    if (assets is! List) return null;
    for (final a in assets) {
      if (a is! Map) continue;
      final nombre = a['name'];
      final url = a['browser_download_url'];
      if (nombre is! String || url is! String) continue;
      final m = _elApk.firstMatch(nombre);
      if (m == null) continue;
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https') continue;
      return LaVersionNueva(
        version: m.group(1)!,
        url: uri,
        bytes: a['size'] is int ? a['size'] as int : 0,
      );
    }
    return null;
  }

  /// Si [nueva] va por delante de [instalada]. Por números y no por texto:
  /// «1.10.0» es más nueva que «1.9.0».
  static bool esMasNueva(String nueva, String instalada) {
    List<int> partes(String v) => [
      for (final p in v.split('+').first.split('.')) int.tryParse(p) ?? 0,
    ];
    final a = partes(nueva), b = partes(instalada);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }
}

/// En qué va la actualización del teléfono.
sealed class EstadoDeLaActualizacion {
  const EstadoDeLaActualizacion();
}

final class SinActualizacion extends EstadoDeLaActualizacion {
  const SinActualizacion();
}

final class HayActualizacion extends EstadoDeLaActualizacion {
  const HayActualizacion(this.nueva, {this.problema});
  final LaVersionNueva nueva;

  /// Lo que salió mal al intentarlo, dicho en la misma tarjeta.
  final String? problema;
}

final class BajandoActualizacion extends EstadoDeLaActualizacion {
  const BajandoActualizacion(this.nueva, this.fraccion);
  final LaVersionNueva nueva;
  final double? fraccion;
}

/// Hace falta el permiso de «instalar apps desconocidas». Se pidió; al volver
/// se reintenta.
final class FaltaElPermiso extends EstadoDeLaActualizacion {
  const FaltaElPermiso(this.nueva, this.apk);
  final LaVersionNueva nueva;
  final String apk;
}
