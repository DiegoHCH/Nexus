import 'package:nexus/features/oido/domain/usecases/como_se_le_llama.dart';

/// Lo que dices en un turno, **sin su nombre delante**, trozo a trozo según va
/// llegando la transcripción.
///
/// 🔴 Nace del reporte del 28 sep: «Ciel, necesito que actualices el documento
/// de tareas…» se pintó en el chat como «de él Necesito que actualice…». El
/// oído del Mac la despertó bien; lo que trajo el nombre fue la transcripción
/// del servicio de voz, que no lo conoce y lo escribe como le suena. La regla
/// de qué cuenta como nombre es [ComoSeLeLlama.dondeEmpiezaLoDicho]; esto es lo
/// que la aplica a una transcripción que **llega a trozos**.
///
/// Por eso retiene: con «de» todavía no se sabe si viene «de él» —el nombre— o
/// «de verdad» —lo que pides—. Mientras no se sabe no se enseña nada, y en
/// cuanto se sabe sale todo lo retenido de una vez. Lo que no empieza por algo
/// que pueda ser el nombre sale tal cual, trozo a trozo, como siempre.
///
/// Uno por turno: el nombre va al principio de **lo que dices**, no de cada
/// trozo.
class LoDichoSinSuNombre {
  LoDichoSinSuNombre({this.agente});

  /// Cómo se llama ella en esta instalación. Ver [ComoSeLeLlama].
  final String? agente;
  final _crudo = StringBuffer();

  /// Dónde empieza lo dicho en [_crudo]. `null` mientras no se sabe.
  int? _desde;

  /// Hasta dónde de [_crudo] ya salió.
  var _dado = 0;

  /// Si ya salió algo. Hasta entonces, lo que sale es el principio de la frase
  /// y va sin la coma que lo separaba del nombre.
  var _empezado = false;

  /// Llegó un trozo más. Devuelve lo que hay que enseñar ahora —puede ser nada
  /// si todavía no se sabe—.
  String trozo(String texto) {
    _crudo.write(texto);
    _desde ??= ComoSeLeLlama.dondeEmpiezaLoDicho(
      _crudo.toString(),
      agente: agente,
    );
    return _loNuevo();
  }

  /// La frase se acabó —o pasó otra cosa que la cierra—: lo que quedara
  /// retenido sale ya, decidido con lo que haya.
  ///
  /// Si se había quitado el nombre y detrás no llegó nada, sale el nombre: la
  /// frase era solo eso, y un turno vacío se lee como que no te oyó.
  String suelta() {
    final crudo = _crudo.toString();
    if (crudo.isEmpty) return '';
    _desde ??= ComoSeLeLlama.dondeEmpiezaLoDicho(
      crudo,
      agente: agente,
      acabado: true,
    );
    final nuevo = _loNuevo();
    if (_empezado) return nuevo;
    _empezado = true;
    _dado = crudo.length;
    return crudo;
  }

  String _loNuevo() {
    final desde = _desde;
    if (desde == null) return '';
    final crudo = _crudo.toString();
    if (_empezado) {
      final nuevo = crudo.substring(_dado);
      _dado = crudo.length;
      return nuevo;
    }
    // Sin nombre delante sale tal cual: el turno de siempre no se toca.
    if (desde == 0) {
      _empezado = true;
      _dado = crudo.length;
      return crudo;
    }
    final resto = ComoSeLeLlama.empezarDesde(crudo, desde);
    if (resto.isEmpty) return '';
    _empezado = true;
    _dado = crudo.length;
    return resto;
  }
}
