import 'package:nexus/features/assistant/domain/usecases/el_modelo_al_abrir.dart';

/// Las sesiones que se abrieron con un modelo que no es el de la carpeta.
///
/// Es lo que hace que una sesión **siga** con el modelo con que se abrió: el
/// segundo turno de una pregunta rápida ya no llega por voz —o sí, da igual—,
/// y sin apuntarlo volvería al de la carpeta y tiraría el caché. Ver
/// [ElModeloAlAbrir].
///
/// Por sesión y no por carpeta: empezar de cero abre otra, y esa se decide
/// otra vez.
abstract interface class LasSesionesRapidas {
  Future<ModeloDeLaSesion?> de(String sessionId);

  Future<void> apunta(String sessionId, ModeloDeLaSesion modelo);
}

/// En memoria: lo que usan las pruebas, y lo que vale si no se dice otra cosa.
class LasSesionesRapidasEnMemoria implements LasSesionesRapidas {
  final _apuntadas = <String, ModeloDeLaSesion>{};

  @override
  Future<ModeloDeLaSesion?> de(String sessionId) async => _apuntadas[sessionId];

  @override
  Future<void> apunta(String sessionId, ModeloDeLaSesion modelo) async =>
      _apuntadas[sessionId] = modelo;
}
