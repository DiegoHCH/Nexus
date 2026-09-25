import 'package:nexus/core/i18n/franja_del_dia.dart';
import 'package:nexus/features/assistant/domain/usecases/a_que_carpeta_va.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';

/// Lo que se sacó en claro de lo que contestaste en la puerta.
sealed class LoQueSeDijoEnLaPuerta {
  const LoQueSeDijoEnLaPuerta();
}

/// Nombraste una: se abre ahí y aparece la interfaz de siempre.
final class SeTrabajaAqui extends LoQueSeDijoEnLaPuerta {
  const SeTrabajaAqui(this.carpeta, this.tarea);

  final PairedFolder carpeta;

  /// Lo que dijiste además de la carpeta, si dijiste algo.
  ///
  /// «Trabajemos en nexus» viene vacío; «en nexus, mira el último PR» trae el
  /// encargo, y entonces la conversación no nace muda: nace con trabajo.
  final String tarea;
}

/// Nombraste dos, y **no se elige ninguna**.
///
/// La misma decisión que ya toma el enrutado de los encargos: adivinar cuál de
/// las dos querías es acertar la mitad de las veces, y equivocarse aquí te
/// coloca en el repo que no era con todo lo que cuelga de él —cuenta, modelo y
/// permisos—.
final class SeNombraronDos extends LoQueSeDijoEnLaPuerta {
  const SeNombraronDos(this.carpetas);
  final List<PairedFolder> carpetas;
}

/// No se reconoció ninguna carpeta en lo que dijiste.
final class NoSeEntendioDonde extends LoQueSeDijoEnLaPuerta {
  const NoSeEntendioDonde();
}

/// La puerta: saludar y entender dónde se va a trabajar.
///
/// 🔴 **Existe para que el arranque no sea una caja de texto vacía.** Sin
/// conversaciones abiertas, la pantalla de hoy enseña la caja y sus chips con la
/// carpeta de la conversación que cerraste, y escribir manda el encargo ahí sin
/// decírtelo. La salida no era arreglar los chips: era quitar el caso. Se saluda,
/// se pregunta dónde, y **la interfaz aparece cuando hay un sitio donde
/// trabajar**.
///
/// Lo que se entiende de la respuesta **no se inventa aquí**: lo resuelve
/// [ACarpetaVaLoQueDices], el mismo que enruta un encargo cuando nombras una
/// carpeta. Dos formas de reconocer el mismo nombre acabarían discrepando, y la
/// que se toque menos sería la que engaña.
abstract final class LaPuertaQueSaluda {
  /// Desde qué hora es «buenas tardes», y desde cuál «buenas noches». Los
  /// números y su motivo están en [FranjaDelDia].
  static const empiezaLaTarde = 12;
  static const empiezaLaNoche = 20;
  static const acabaLaNoche = 6;

  static FranjaDelDia franjaDe(DateTime ahora) {
    final hora = ahora.hour;
    if (hora < acabaLaNoche || hora >= empiezaLaNoche) {
      return FranjaDelDia.noche;
    }
    if (hora >= empiezaLaTarde) return FranjaDelDia.tarde;
    return FranjaDelDia.manana;
  }

  /// Cuántas carpetas se ofrecen para tocar debajo del orbe. Las del mockup
  /// son tres más «Sin proyecto»; cinco es lo que cabe en una fila a 1024 de
  /// ancho con nombres de repo normales, y más ya no es una sugerencia sino
  /// una lista.
  static const cuantasSeSugieren = 5;

  /// Las carpetas que se ponen a la vista para tocar en vez de decir.
  ///
  /// 🔴 **Solo las emparejadas**, y no porque no se pudiera buscar más: son las
  /// únicas que ya elegiste tú, y la puerta no es sitio para descubrir
  /// carpetas —una que no está emparejada abriría una conversación sin cuenta,
  /// sin permisos y sin nada colgando—. Tampoco se mira el disco: sería leer
  /// tus carpetas para ofrecerte las que ya tienes.
  ///
  /// La última en la que trabajaste va primero —es la respuesta más probable a
  /// «¿en dónde vamos a trabajar hoy?»— y las demás en su orden de siempre,
  /// para que cada una esté donde estaba ayer.
  static List<PairedFolder> sugerencias(
    List<PairedFolder> carpetas, {
    String? laUltima,
  }) {
    final primero = [
      ...carpetas.where((c) => c.path == laUltima),
      ...carpetas.where((c) => c.path != laUltima),
    ];
    return primero.take(cuantasSeSugieren).toList();
  }

  /// Qué se sacó en claro de lo que contestaste.
  ///
  /// Se le pasan **todas** las carpetas emparejadas, también las de solo texto:
  /// decidido a la vista de que lo que viaja es un nombre y no su contenido, y
  /// de que una puerta que esconde la mitad de las carpetas es media puerta. La
  /// modalidad sigue mandando **después**, cuando esa conversación quiera abrir
  /// voz: ahí la de solo texto seguirá diciendo que no.
  static LoQueSeDijoEnLaPuerta interpreta(
    String frase,
    List<PairedFolder> carpetas,
  ) => switch (ACarpetaVaLoQueDices.de(frase, carpetas)) {
    AEstaCarpeta(:final carpeta, :final tarea) => SeTrabajaAqui(carpeta, tarea),
    SeNombraronVarias(:final carpetas) => SeNombraronDos(carpetas),
    NoSeNombroCarpeta() => const NoSeEntendioDonde(),
  };
}
