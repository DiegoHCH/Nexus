import 'package:nexus/features/onboarding/domain/entities/pasos_del_arranque.dart';
import 'package:nexus/features/onboarding/domain/repositories/lo_que_quedo_para_luego.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// En las preferencias, por nombre: es una lista corta que no es un secreto.
class LoQueQuedoParaLuegoImpl implements LoQueQuedoParaLuego {
  const LoQueQuedoParaLuegoImpl();

  static const _clave = 'arranque_para_luego';

  @override
  Future<Set<QueSePide>> leer() async {
    final prefs = await SharedPreferences.getInstance();
    final nombres = prefs.getStringList(_clave) ?? const [];
    // Por nombre y sin lanzar: un paso que deje de existir en una versión
    // futura se ignora en vez de romper la lectura del resto.
    return {
      for (final nombre in nombres)
        ?QueSePide.values.where((q) => q.name == nombre).firstOrNull,
    };
  }

  @override
  Future<void> guardar(Set<QueSePide> pasos) async {
    final prefs = await SharedPreferences.getInstance();
    if (pasos.isEmpty) {
      await prefs.remove(_clave);
      return;
    }
    await prefs.setStringList(_clave, [for (final p in pasos) p.name]);
  }
}
