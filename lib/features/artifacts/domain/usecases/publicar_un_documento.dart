import 'package:nexus/features/artifacts/domain/entities/la_publicacion.dart';
import 'package:nexus/features/artifacts/domain/repositories/el_publicador.dart';

/// Publicar un documento de Nexus en claude.ai, y que las veces siguientes
/// **se actualice el mismo enlace**.
///
/// Pedido así: «quisiera poderlo publicar como un artifact directo desde
/// Nexus». Lo de «el mismo enlace» es la mitad que importa: quien ya lo tiene
/// abierto ve la versión nueva sin que haya que mandarle nada.
class PublicarUnDocumento {
  const PublicarUnDocumento(
    this._publicador,
    this._enlaces, {
    required this.home,
    required this.existe,
  });

  final ElPublicador _publicador;
  final LosEnlacesPublicados _enlaces;

  /// La carpeta personal, para encontrar los perfiles de Claude.
  final String home;

  /// Si existe un directorio; inyectable para probarlo sin disco.
  final bool Function(String ruta) existe;

  /// Publica [archivo], cuyo HTML es [html].
  Future<LoQueSalioDePublicar> call(
    String archivo, {
    required String html,
  }) async {
    final cuenta = laCuentaDelDocumento(archivo, home: home, existe: existe);
    final antes = await _enlaces.de(archivo, cuenta: cuenta);
    final salio = await _publicador.publicar(
      archivo: archivo,
      titulo: elTituloDelDocumento(html, archivo),
      cuenta: cuenta,
      enlace: antes,
    );
    if (salio case Publicado(:final url)) {
      await _enlaces.apuntar(archivo, url, cuenta: cuenta);
    }
    return salio;
  }

  /// Con qué cuenta de Claude se publica [archivo]: la de la carpeta donde
  /// está, si es una.
  ///
  /// Nexus guarda los documentos de una conversación con cuenta en
  /// `<documentos>/<cuenta>/` —ver `ProjectContextPrompt`—, y el perfil de esa
  /// cuenta es `~/.claude-<cuenta>`. Publicar con otra lo dejaría en la
  /// galería de la cuenta equivocada: lo del trabajo en la personal. Sin
  /// perfil que case, la de siempre (`null`).
  static String? laCuentaDelDocumento(
    String archivo, {
    required String home,
    required bool Function(String ruta) existe,
  }) {
    final partes = archivo.split('/').where((p) => p.isNotEmpty).toList();
    if (partes.length < 2) return null;
    final carpeta = partes[partes.length - 2];
    if (carpeta.isEmpty || carpeta.startsWith('.')) return null;
    final perfil = '$home/.claude-$carpeta';
    return existe(perfil) ? perfil : null;
  }

  /// El título del artifact: el `<title>` del documento, o su nombre sin la
  /// extensión. Es lo que se lee en la galería de claude.ai, así que nunca
  /// vacío.
  static String elTituloDelDocumento(String html, String archivo) {
    final titulo = RegExp(
      r'<title[^>]*>([\s\S]*?)</title>',
      caseSensitive: false,
    ).firstMatch(html)?.group(1);
    final limpio = titulo?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
    if (limpio.isNotEmpty) return limpio;
    final nombre = archivo.split('/').last;
    final punto = nombre.lastIndexOf('.');
    return punto > 0 ? nombre.substring(0, punto) : nombre;
  }
}
