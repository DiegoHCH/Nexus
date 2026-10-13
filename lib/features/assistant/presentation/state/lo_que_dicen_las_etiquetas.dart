import 'package:flutter/foundation.dart';
import 'package:nexus/features/assistant/domain/usecases/el_verbo_de_un_paso.dart';
import 'package:nexus/features/assistant/presentation/state/activity_layout.dart';
import 'package:nexus/features/assistant/presentation/state/assistant_hud_state.dart';

/// El paso que corre ahora, como lo cuenta su etiqueta.
typedef ElPasoDeAhora = ({
  VerboDelPaso verbo,
  String objeto,
  bool escribe,
  bool deUnSubagente,
  DateTime desde,
});

/// Un subagente que sigue trabajando: lo que se le encargó y desde cuándo.
typedef UnSubagente = ({String que, DateTime desde});

/// Lo que cuentan las etiquetas del orbe mientras trabaja.
///
/// **Solo lo que no se ve en otro sitio.** La lista de pasos ya está a la
/// derecha y el contexto en la esquina; esto añade lo que ninguna dice: cuánto
/// lleva el paso de ahora, cuánto lleva el encargo entero y qué subagentes
/// siguen en marcha. Datos que se miden, como pide el diseño — nada de
/// «energía del núcleo».
@immutable
class LasEtiquetas {
  const LasEtiquetas({this.paso, this.desde, this.subagentes = const []});

  final ElPasoDeAhora? paso;

  /// Desde cuándo trabaja el encargo: el primer paso que dio.
  final DateTime? desde;

  final List<UnSubagente> subagentes;

  bool get vacias => paso == null && desde == null && subagentes.isEmpty;

  static const nada = LasEtiquetas();
}

/// Cuánto se escribe del objeto de un paso: una etiqueta es una línea corta,
/// no el registro.
const _largo = 36;

/// De la actividad del turno a lo que dicen las etiquetas. Puro, para poder
/// probar cada caso sin pintar nada.
LasEtiquetas loQueDicenLasEtiquetas(List<ActivityItem> actividad) {
  if (actividad.isEmpty) return LasEtiquetas.nada;

  final filas = layoutActivity(actividad);
  final enMarcha = filas.where((fila) => fila.running).firstOrNull;

  ElPasoDeAhora? paso;
  if (enMarcha != null) {
    final (:verbo, :objeto) = ElVerboDeUnPaso.de(enMarcha.item.description);
    paso = (
      verbo: verbo,
      objeto: _corto(verbo, objeto),
      escribe: enMarcha.item.writes,
      deUnSubagente: enMarcha.depth > 0,
      desde: enMarcha.item.startedAt,
    );
  }

  final propios = actividad.where((item) => item.parentId == null);
  final subagentes = <UnSubagente>[
    for (final item in propios)
      if (!item.done)
        if (ElVerboDeUnPaso.de(item.description) case (
          verbo: VerboDelPaso.delega,
          :final objeto,
        ))
          (que: _recorta(objeto), desde: item.startedAt),
  ];

  DateTime? desde;
  for (final item in propios) {
    if (desde == null || item.startedAt.isBefore(desde)) desde = item.startedAt;
  }

  return LasEtiquetas(paso: paso, desde: desde, subagentes: subagentes);
}

/// Lo justo para reconocer el paso: el archivo sin su ruta, la orden con sus
/// primeras palabras.
String _corto(VerboDelPaso verbo, String objeto) => switch (verbo) {
  VerboDelPaso.lee ||
  VerboDelPaso.escribe ||
  VerboDelPaso.edita => _recorta(objeto.split('/').last),
  VerboDelPaso.ejecuta => _recorta(objeto.split(' ').take(3).join(' ')),
  _ => _recorta(objeto),
};

String _recorta(String texto) {
  final limpio = texto.trim();
  return limpio.length <= _largo
      ? limpio
      : '${limpio.substring(0, _largo - 1).trimRight()}…';
}

/// Cuánto lleva algo, para una etiqueta: segundos hasta el minuto, y después
/// minutos y segundos como en un cronómetro.
String elTiempoDeUnaEtiqueta(Duration cuanto) {
  final segundos = cuanto.inSeconds.clamp(0, 359999);
  if (segundos < 60) return '$segundos s';
  final m = segundos ~/ 60, s = segundos % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
