import 'dart:typed_data';

/// **Decide cuándo puede empezar a sonar un audio que llega a trozos.**
///
/// 🔴 **Existe porque sonar con el primer trozo se entrecortaba** (1 oct). El
/// Live entrega el audio del aviso a ritmo de habla o más lento —medido en el
/// registro: 2460 ms de aviso en 2495 ms, 3720 en 4121, 6870 en 14733—, así que
/// lo que suena se come lo que llega y el altavoz se queda sin nada entre trozo
/// y trozo. Eso es el corte que se oía.
///
/// Por eso se suelta cuando ya no se puede quedar corto: **con el audio entero**
/// o, antes, si está llegando claramente más rápido de lo que dura. Lo que se
/// paga es esperar lo que tarda en llegar; lo que se compra es que la frase
/// suene de un tirón.
class ElColchonDeLaVoz {
  ElColchonDeLaVoz(this._soltar, {DateTime Function()? ahora})
    : _ahora = ahora ?? DateTime.now;

  final void Function(Uint8List trozo) _soltar;
  final DateTime Function() _ahora;

  /// PCM de 16 bits a 24 kHz: dos bytes por muestra.
  static const bytesPorSegundo = 24000 * 2;

  /// Lo mínimo que tiene que haber guardado para soltarlo antes de tiempo.
  static const minimo = Duration(milliseconds: 1200);

  /// Cuánto más rápido que lo que dura tiene que estar llegando: con esa
  /// ventaja, lo que falta llega antes de que se acabe lo que ya suena.
  static const ventaja = 1.5;

  /// Lo más que se aguanta en silencio. Si llega tan despacio que en esto no
  /// ha terminado, ya no hay forma de que suene de un tirón, y callar más solo
  /// convierte un aviso entrecortado en uno que llega tarde.
  static const tope = Duration(seconds: 8);

  /// Lo que tarda en poder medirse el ritmo: con el primer trozo recién
  /// llegado, cualquier cuenta da infinito.
  static const _paraMedir = Duration(milliseconds: 400);

  final _guardado = <Uint8List>[];
  var _bytes = 0;
  DateTime? _primero;
  var _suelto = false;

  /// Si ya empezó a soltar lo que llega.
  bool get suelto => _suelto;

  void llega(Uint8List trozo) {
    if (_suelto) {
      _soltar(trozo);
      return;
    }
    _primero ??= _ahora();
    _guardado.add(trozo);
    _bytes += trozo.lengthInBytes;
    if (_llegaConVentaja()) _soltarLoGuardado();
  }

  /// Ya no llega más: lo guardado suena entero.
  void termina() {
    if (!_suelto) _soltarLoGuardado();
  }

  bool _llegaConVentaja() {
    final tarda = _ahora().difference(_primero!).inMilliseconds;
    if (tarda >= tope.inMilliseconds) return true;
    final dura = _bytes / bytesPorSegundo * 1000;
    if (dura < minimo.inMilliseconds) return false;
    if (tarda < _paraMedir.inMilliseconds) return false;
    return dura >= tarda * ventaja;
  }

  void _soltarLoGuardado() {
    _suelto = true;
    if (_guardado.isEmpty) return;
    final todo = Uint8List(_bytes);
    var en = 0;
    for (final trozo in _guardado) {
      todo.setRange(en, en + trozo.lengthInBytes, trozo);
      en += trozo.lengthInBytes;
    }
    _guardado.clear();
    _soltar(todo);
  }
}
