import 'package:flutter/foundation.dart';
import 'package:nexus/features/remote/domain/remote_mirror.dart';

/// El paso en que va el turno: cuál es, de cuántos, y qué dice.
@immutable
class ElPasoDeAhora {
  const ElPasoDeAhora({
    required this.paso,
    required this.total,
    required this.hechos,
    required this.texto,
  });

  /// Contando desde uno, que es como se dice: «paso 3 de 4».
  final int paso;
  final int total;

  /// Cuántos terminaron, para los segmentos del reactor.
  final int hechos;

  final String texto;

  /// El primero sin terminar, o el último si ya terminaron todos.
  ///
  /// **El primero sin terminar y no el último de la lista**: los pasos llegan en
  /// orden y se van cerrando, así que el que está en marcha es el primero abierto. El
  /// último de la lista puede ser uno que Claude anunció y todavía no empezó. `null`
  /// sin pasos: no hay nada que contar, y un «paso 0 de 0» sería peor que callarse.
  static ElPasoDeAhora? de(List<MirroredStep> pasos) {
    if (pasos.isEmpty) return null;
    final hechos = pasos.where((p) => p.done).length;
    final abierto = pasos.indexWhere((p) => !p.done);
    final i = abierto == -1 ? pasos.length - 1 : abierto;
    return ElPasoDeAhora(
      paso: i + 1,
      total: pasos.length,
      hechos: hechos,
      texto: pasos[i].text,
    );
  }
}

/// El subtítulo que sigue la voz: **lo dicho y lo que falta** de la frase de ahora.
///
/// Es lo que el mockup dibuja debajo del orbe al hablar —«lo dicho en blanco, lo que
/// falta en gris»— y existe por quien no puede oírla: en el metro, con el teléfono en
/// silencio, o simplemente leyendo mientras ella habla.
@immutable
class SubtituloDeLaVoz {
  const SubtituloDeLaVoz({required this.ya, required this.falta});

  final String ya;
  final String falta;

  bool get vacio => ya.isEmpty && falta.isEmpty;

  /// Corta [texto] por donde va la voz.
  ///
  /// [avance] es la parte de la respuesta que ya sonó, de 0 a 1; `null` cuando no
  /// suena aquí —la voz sale por el Mac, o está callada— y entonces todo cuenta como
  /// dicho: sin saber por dónde va, pintar una parte en gris sería inventárselo.
  ///
  /// **Se enseña una ventana y no la respuesta entera**: la frase en que va la voz y la
  /// siguiente, como el mockup. Una respuesta de Claude puede tener cinco párrafos, y
  /// a letra grande debajo del orbe no caben ni se siguen. Si aun así pasa de [tope]
  /// caracteres, se recorta alrededor del corte, que es lo que se está leyendo.
  ///
  /// El corte cae siempre **entre palabras**: partir «comen|tado» en dos colores se lee
  /// como un error de pintura, no como la voz avanzando.
  static SubtituloDeLaVoz de(String texto, {double? avance, int tope = 180}) {
    final t = texto.trim();
    if (t.isEmpty) return const SubtituloDeLaVoz(ya: '', falta: '');

    var corte = avance == null
        ? t.length
        : (avance.clamp(0.0, 1.0) * t.length).round();
    // Hasta el final de la palabra en que cae.
    while (corte < t.length && !_esEspacio(t.codeUnitAt(corte))) {
      corte++;
    }

    final frases = _frases(t);
    // La frase donde está el corte. Con todo dicho, el corte está al final, y la
    // ventana son las dos últimas.
    var i = frases.indexWhere((f) => corte < f.$2);
    if (i == -1) i = frases.length - 1;
    final desdeFrase = corte >= t.length ? (i - 1).clamp(0, i) : i;
    final hastaFrase = corte >= t.length
        ? i
        : (i + 1).clamp(i, frases.length - 1);

    var desde = frases[desdeFrase].$1;
    var hasta = frases[hastaFrase].$2;
    var antes = '';
    var despues = '';
    if (hasta - desde > tope) {
      // Se recorta alrededor del corte, dejando más de lo que falta que de lo dicho:
      // lo dicho ya se oyó, lo que falta es lo que se va a leer.
      final nuevoDesde = (corte - tope ~/ 3).clamp(desde, corte);
      if (nuevoDesde > desde) {
        desde = _inicioDePalabra(t, nuevoDesde);
        antes = '…';
      }
      final nuevoHasta = (desde + tope).clamp(corte, hasta);
      if (nuevoHasta < hasta) {
        hasta = _finDePalabra(t, nuevoHasta, minimo: corte);
        despues = '…';
      }
    }

    final ya = t.substring(desde, corte.clamp(desde, hasta)).trimLeft();
    final falta = t.substring(corte.clamp(desde, hasta), hasta).trimRight();
    return SubtituloDeLaVoz(
      ya: ya.isEmpty ? '' : '$antes$ya',
      falta: falta.isEmpty ? '' : '$falta$despues',
    );
  }

  /// La última frase de [texto], para la fila de una lista.
  ///
  /// La última y no la primera: lo que se está diciendo **ahora** es el final de lo
  /// que llegó, y una fila que enseña el principio se queda congelada en la primera
  /// frase mientras la voz sigue.
  static String laUltimaFrase(String texto, {int tope = 90}) {
    final t = texto.trim();
    if (t.isEmpty) return '';
    final frases = _frases(t);
    final (desde, hasta) = frases.last;
    final frase = t.substring(desde, hasta).trim();
    if (frase.length <= tope) return frase;
    final corte = _inicioDePalabra(frase, frase.length - tope);
    return '…${frase.substring(corte)}';
  }

  /// Los tramos de cada frase, `(desde, hasta)`, con su puntuación y su espacio
  /// detrás dentro. Una frase acaba en `.`, `!`, `?`, `…` o un salto de línea.
  static List<(int, int)> _frases(String t) {
    final tramos = <(int, int)>[];
    var desde = 0;
    for (final m in RegExp(r'[.!?…]+\s+|\n+').allMatches(t)) {
      tramos.add((desde, m.end));
      desde = m.end;
    }
    if (desde < t.length) tramos.add((desde, t.length));
    return tramos;
  }

  static bool _esEspacio(int c) => c == 0x20 || c == 0x0A || c == 0x09;

  static int _inicioDePalabra(String t, int i) {
    var j = i;
    while (j < t.length && !_esEspacio(t.codeUnitAt(j))) {
      j++;
    }
    while (j < t.length && _esEspacio(t.codeUnitAt(j))) {
      j++;
    }
    return j >= t.length ? i : j;
  }

  static int _finDePalabra(String t, int i, {required int minimo}) {
    var j = i;
    while (j > minimo && !_esEspacio(t.codeUnitAt(j - 1))) {
      j--;
    }
    return j <= minimo ? i : j;
  }
}
