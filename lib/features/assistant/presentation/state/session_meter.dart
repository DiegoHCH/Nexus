import 'package:flutter/foundation.dart';

/// Los tres datos que el HUD enseña arriba a la derecha: qué modelo, cuántos
/// tokens y cuánto contexto lleva ocupado.
///
/// El diseño los llama «datos honestos» y ese es justo el punto: los mockups
/// llegaron a decir `claude-4-sonnet` cuando ya no existía. Aquí el modelo es
/// **el que reporta el CLI**, y los tokens los que devuelve su `usage` — nada
/// se escribe a mano.
@immutable
class SessionMeter {
  const SessionMeter({this.model, this.turnTokens, this.contextTokens});

  final String? model;
  final int? turnTokens;
  final int? contextTokens;

  /// El identificador trae variantes entre corchetes —`claude-opus-5[1m]`— que
  /// dicen el tamaño de ventana, no el modelo. Para leerlo de un vistazo
  /// sobra, así que se enseña limpio y el corchete se usa para la ventana.
  String? get displayModel {
    final value = model;
    if (value == null) return null;
    final bracket = value.indexOf('[');
    return bracket == -1 ? value : value.substring(0, bracket);
  }

  /// La ventana de cada modelo, en tokens.
  ///
  /// 🔴 **Deducirla del corchete costaba una compresión por turno.** La regla
  /// era «`[1m]` es de un millón y el resto 200k», y el resto no es 200k:
  /// Sonnet 5 también tiene un millón y el CLI lo reporta a secas, sin
  /// corchete. Medido en la máquina: una sesión con `claude-sonnet-5` iba por
  /// 252.460 tokens en una petición que **no falló** —cosa imposible en una
  /// ventana de 200k—, y la app la pintaba al 100 % y pedía comprimir al final
  /// de cada turno, para siempre.
  ///
  /// Así que se escriben las que se saben, y el corchete sigue mandando cuando
  /// viene. Lo que no esté aquí no tiene ventana: ver [contextWindow].
  static const _ventanas = <String, int>{
    'claude-fable-5-1': 1000000,
    'claude-fable-5': 1000000,
    'claude-mythos-5-1': 1000000,
    'claude-opus-5': 1000000,
    'claude-opus-4-8': 1000000,
    'claude-opus-4-7': 1000000,
    'claude-opus-4-6': 1000000,
    'claude-sonnet-5': 1000000,
    'claude-sonnet-4-6': 1000000,
    'claude-haiku-4-5': 200000,
  };

  /// Ventana de contexto del modelo, en tokens. `null` si no se sabe.
  ///
  /// 🔴 **Sin dato se dice que no se sabe, y no se asume.** Asumir 200k para
  /// todo lo desconocido es lo que disparaba la compresión en bucle, y el coste
  /// de las dos equivocaciones no se parece: quedarse sin medidor es una cifra
  /// que falta en el HUD, y asumir de menos es un turno entero de Claude
  /// gastado al final de cada turno. Ver [contextPercent], que devuelve `null`,
  /// y `LaCompresionDeLaConversacion.toca`, que sin medida no dispara.
  ///
  /// El corchete va primero: es lo que dice el CLI de **esta** corrida, y manda
  /// sobre lo que la tabla sepa de la familia.
  int? get contextWindow {
    final id = model;
    if (id == null) return null;
    if (id.contains('[1m]')) return 1000000;
    final limpio = displayModel!;
    if (_ventanas[limpio] case final exacta?) return exacta;
    // Con sufijo de fecha —`claude-haiku-4-5-20251001`— gana el prefijo más
    // largo, o `claude-fable-5` se comería a `claude-fable-5-1`.
    int? ventana;
    var largo = 0;
    _ventanas.forEach((nombre, tokens) {
      if (limpio.startsWith(nombre) && nombre.length > largo) {
        largo = nombre.length;
        ventana = tokens;
      }
    });
    return ventana;
  }

  /// Acotado al 100 %, como el círculo que lo acompaña.
  ///
  /// Una sesión reanudada puede traer más tokens que la ventana del modelo que
  /// tiene puesto la carpeta ahora, y entonces la división pasa de uno. Eso es
  /// un dato cierto, pero «132 %» se lee como un error de medida —lo fue
  /// durante un tiempo— y no como «esto ya no cabe». Las dos cifras de al lado
  /// siguen diciendo la verdad entera: `264,2k / 200,0k (100 %)` deja ver que
  /// se pasó, sin pedirle al porcentaje que signifique algo que no significa.
  int? get contextPercent {
    final used = contextTokens;
    final ventana = contextWindow;
    if (used == null || used <= 0 || ventana == null) return null;
    return ((used / ventana) * 100).round().clamp(0, 100);
  }

  /// Cuánto de la ventana va ocupado, de 0 a 1. Lo que llena el círculo.
  double get contextFraction {
    final used = contextTokens;
    final ventana = contextWindow;
    if (used == null || used <= 0 || ventana == null) return 0;
    return (used / ventana).clamp(0.0, 1.0);
  }

  /// `63,3k / 1,0M (6 %)`.
  ///
  /// Las tres cifras juntas y no solo el porcentaje: un 6 % no dice si te queda
  /// margen para pegar un archivo entero — depende de si la ventana es de 200k
  /// o de un millón, y eso cambia con el modelo que tenga puesto la carpeta.
  String? get contextLabel {
    final used = contextTokens;
    if (used == null || used <= 0) return null;
    // Sin ventana conocida se enseñan los tokens y nada más: inventar el
    // denominador es justo lo que hacía mentir al porcentaje.
    final ventana = contextWindow;
    if (ventana == null) return _short(used);
    return '${_short(used)} / ${_short(ventana)} (${contextPercent ?? 0} %)';
  }

  /// `63,3k`, `1,0M`. La coma decimal es la española, como en el resto del HUD.
  static String _short(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(1).replaceAll('.', ',')}M';
    }
    if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1).replaceAll('.', ',')}k';
    }
    return '$tokens';
  }

  /// `12,4k` como en el mockup: la coma decimal es la española.
  String? get tokensLabel {
    final tokens = turnTokens;
    if (tokens == null || tokens <= 0) return null;
    if (tokens < 1000) return '$tokens';
    return '${(tokens / 1000).toStringAsFixed(1).replaceAll('.', ',')}k';
  }

  SessionMeter copyWith({String? model, int? turnTokens, int? contextTokens}) {
    return SessionMeter(
      model: model ?? this.model,
      turnTokens: turnTokens ?? this.turnTokens,
      contextTokens: contextTokens ?? this.contextTokens,
    );
  }
}
