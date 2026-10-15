import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/features/assistant/data/datasources/las_sesiones_rapidas_data_source.dart';
import 'package:nexus/features/assistant/domain/repositories/las_sesiones_rapidas.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Si una pregunta por voz que abre sesión va con el modelo rápido. Ver
/// `ElModeloAlAbrir`.
///
/// **Encendido de fábrica, porque se midió**: la mitad de coste con la misma
/// espera y respuestas equivalentes. Y solo toca sesiones nuevas que llegan
/// por voz a una carpeta sin código: lo demás sigue exactamente igual.
class LasRapidasPorVoz extends Notifier<bool> {
  static const clave = 'voz.rapidas_con_sonnet';

  @override
  bool build() {
    _cargar();
    return true;
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    state = prefs.getBool(clave) ?? true;
  }

  Future<void> cambiar(bool encendido) async {
    state = encendido;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(clave, encendido);
  }
}

final lasRapidasPorVozProvider = NotifierProvider<LasRapidasPorVoz, bool>(
  LasRapidasPorVoz.new,
);

/// Dónde se apuntan las sesiones que se abrieron rápidas.
final lasSesionesRapidasProvider = Provider<LasSesionesRapidas>(
  (ref) => const LasSesionesRapidasGuardadas(),
);
