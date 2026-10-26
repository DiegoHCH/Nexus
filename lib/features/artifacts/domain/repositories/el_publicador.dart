import 'package:nexus/features/artifacts/domain/entities/la_publicacion.dart';

/// Publica un documento en claude.ai, como artifact.
abstract interface class ElPublicador {
  /// Publica [archivo] con la cuenta [cuenta] —el directorio de configuración
  /// de Claude, `null` para el de siempre—: encima de [enlace] si ya se había
  /// publicado, o en uno nuevo.
  Future<LoQueSalioDePublicar> publicar({
    required String archivo,
    required String titulo,
    required String? cuenta,
    required String? enlace,
  });

  /// Abre, a la vista, una terminal con Claude Code en la carpeta donde se
  /// publica, para aceptar una vez que es de confianza. Ver
  /// [HayQueConfiarEnLaCarpeta]. [aviso] es lo que se le dice al abrirla, en
  /// el idioma de la app.
  Future<void> confiarEnLaCarpeta(
    HayQueConfiarEnLaCarpeta pedido, {
    String aviso = '',
  });
}

/// Los enlaces que ya tiene cada documento publicado, para actualizar el mismo
/// en vez de sacar uno nuevo cada vez.
abstract interface class LosEnlacesPublicados {
  Future<String?> de(String archivo, {required String? cuenta});

  Future<void> apuntar(String archivo, String url, {required String? cuenta});
}
