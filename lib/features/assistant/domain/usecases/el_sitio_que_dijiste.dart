import 'package:nexus/features/assistant/domain/repositories/las_carpetas_del_disco.dart';
import 'package:nexus/features/assistant/domain/usecases/donde_abrir_la_conversacion.dart';

/// Qué hacer después de buscar en el disco el sitio que se dijo.
sealed class ElSitio {
  const ElSitio();
}

/// No se pidió abrir nada, o era una tarea con pinta de sitio: se atiende aquí.
final class SeguirAqui extends ElSitio {
  const SeguirAqui();
}

/// Está, y es uno: se abre ahí.
final class AbrirEn extends ElSitio {
  const AbrirEn(this.ruta, this.tarea);
  final String ruta;
  final String tarea;
}

/// Se dijo claro y no está.
final class NoEsta extends ElSitio {
  const NoEsta(this.nombre);
  final String nombre;
}

/// Hay varias y no se puede elegir: se pregunta. **No se elige ninguna**, por
/// la misma regla que con las emparejadas: de la carpeta cuelgan la cuenta, el
/// modelo y los permisos, y trabajar en la que no era no se deshace.
final class HayVarias extends ElSitio {
  const HayVarias(this.nombre, this.rutas);
  final String nombre;
  final List<String> rutas;
}

/// De lo que se dijo al sitio donde abrir. Ver [DondeAbrirLaConversacion].
abstract final class ElSitioQueDijiste {
  static Future<ElSitio> buscar(
    DondeAbrir dicho,
    LasCarpetasDelDisco disco,
  ) async {
    switch (dicho) {
      case NoPideAbrir():
        return const SeguirAqui();

      case EnEstaRuta(:final ruta, :final tarea):
        // Una ruta escrita es lo más claro que hay: si no existe, se dice.
        if (await disco.existe(ruta)) return AbrirEn(ruta, tarea);
        return NoEsta(ruta);

      case EnLaQueSeLlame(:final candidatos, :final loDijoClaro):
        // Del nombre más largo al más corto: el primero que exista es el que
        // se quiso decir, y lo que sobra de la frase es la tarea.
        for (final (:nombre, :tarea) in candidatos) {
          final rutas = await disco.lasQueSeLlaman(nombre);
          if (rutas.isEmpty) continue;
          if (rutas.length == 1) return AbrirEn(rutas.single, tarea);

          // 🔴 **El desempate: si solo una es un proyecto, esa.** Medido en
          // esta máquina: `nexus` salía en cuatro sitios —el repo, dos carpetas
          // de chats y un paquete de Kotlin dentro del propio repo—, y
          // preguntar cada vez por la obvia hace inútil decirlo por nombre.
          final repos = [
            for (final ruta in rutas)
              if (await disco.esUnRepo(ruta)) ruta,
          ];
          if (repos.length == 1) return AbrirEn(repos.single, tarea);
          return HayVarias(nombre, repos.isEmpty ? rutas : repos);
        }
        // Ninguna existe. Dicho claro —«la carpeta X»—, se avisa; dicho a
        // secas, era una tarea —«trabajemos en el bug del login»— y no hay
        // nada que avisar.
        return loDijoClaro
            ? NoEsta(candidatos.first.nombre)
            : const SeguirAqui();
    }
  }
}
