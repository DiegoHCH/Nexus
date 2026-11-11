import 'package:flutter/foundation.dart';

/// Un flow de `.maestro` de la app, con cómo acabó su última pasada.
@immutable
class FlowDelHub {
  const FlowDelHub({required this.ruta, required this.nombre, this.bien});

  final String ruta;
  final String nombre;

  /// `true` pasó, `false` cayó, `null` sin pasadas.
  final bool? bien;

  Map<String, Object?> toMap() => {
    'ruta': ruta,
    'nombre': nombre,
    'bien': ?bien,
  };

  static FlowDelHub? fromMap(Object? o) => switch (o) {
    {'ruta': final String ruta, 'nombre': final String nombre} => FlowDelHub(
      ruta: ruta,
      nombre: nombre,
      bien: (o as Map)['bien'] as bool?,
    ),
    _ => null,
  };
}

/// Una pasada del historial.
@immutable
class PasadaDelHub {
  const PasadaDelHub({
    required this.carpeta,
    required this.flow,
    required this.cuando,
    required this.bien,
    required this.pasos,
    required this.pasosBien,
  });

  final String carpeta;
  final String flow;
  final DateTime cuando;

  /// `null` mientras corre.
  final bool? bien;
  final int pasos;
  final int pasosBien;

  Map<String, Object?> toMap() => {
    'carpeta': carpeta,
    'flow': flow,
    'cuando': cuando.toIso8601String(),
    'bien': ?bien,
    'pasos': pasos,
    'pasosBien': pasosBien,
  };

  static PasadaDelHub? fromMap(Object? o) => switch (o) {
    {
      'carpeta': final String carpeta,
      'flow': final String flow,
      'cuando': final String cuando,
    } =>
      PasadaDelHub(
        carpeta: carpeta,
        flow: flow,
        cuando: DateTime.tryParse(cuando) ?? DateTime(2000),
        bien: (o as Map)['bien'] as bool?,
        pasos: (o['pasos'] as int?) ?? 0,
        pasosBien: (o['pasosBien'] as int?) ?? 0,
      ),
    _ => null,
  };
}

/// Un flow del repositorio de pruebas compartido, con su cuenta.
@immutable
class FlowDelRepo {
  const FlowDelRepo({required this.ruta, this.cuenta, this.porQueNo});

  /// Relativa al clon.
  final String ruta;

  /// La clave de la cuenta con que se corre, o `null` si no tiene.
  final String? cuenta;

  /// Por qué no se puede correr (sin cuenta, variables que faltan), o `null`.
  final String? porQueNo;

  Map<String, Object?> toMap() => {
    'ruta': ruta,
    'cuenta': ?cuenta,
    'porQueNo': ?porQueNo,
  };

  static FlowDelRepo? fromMap(Object? o) => switch (o) {
    {'ruta': final String ruta} => FlowDelRepo(
      ruta: ruta,
      cuenta: (o as Map)['cuenta'] as String?,
      porQueNo: o['porQueNo'] as String?,
    ),
    _ => null,
  };
}

/// **La cara de pruebas del hub** (T15, P7): lo de todos los días del panel
/// de pruebas —correr un flow en el dispositivo elegido, verlo en vivo,
/// pararlo, el historial—. Lo demás (publicar, borrar, cuentas, variables)
/// se abre en el panel completo, desde el hub.
@immutable
class LoDePruebas {
  const LoDePruebas({
    this.flows = const [],
    this.enMarcha,
    this.historial = const [],
    this.repo = const [],
    this.repoComo,
    this.semana = (bien: 0, mal: 0, todas: 0),
    this.aviso,
  });

  final List<FlowDelHub> flows;

  /// La que corre ahora: su flow, pasos hechos de cuántos, y si sigue viva.
  final ({String flow, int hechos, int total, bool viva, bool fallo})? enMarcha;

  final List<PasadaDelHub> historial;
  final List<FlowDelRepo> repo;

  /// Cómo está el repositorio de pruebas: `cargando`, o el nombre de su
  /// `ComoFueLaSync` (`clonado`, `aldia`, `sucio`, `fallo`).
  final String? repoComo;

  /// Las cifras del historial: cuántas pasaron, cayeron y corrieron en los
  /// últimos 7 días.
  final ({int bien, int mal, int todas}) semana;

  /// Lo que falta para correr (sin dispositivo, variables, app sin instalar),
  /// o lo que dijo Maestro al fallar el arranque.
  final String? aviso;

  Map<String, Object?> toMap() => {
    'flows': [for (final f in flows) f.toMap()],
    if (enMarcha case final e?)
      'enMarcha': {
        'flow': e.flow,
        'hechos': e.hechos,
        'total': e.total,
        'viva': e.viva,
        'fallo': e.fallo,
      },
    'historial': [for (final p in historial) p.toMap()],
    'repo': [for (final r in repo) r.toMap()],
    'repoComo': ?repoComo,
    'semana': [semana.bien, semana.mal, semana.todas],
    'aviso': ?aviso,
  };

  factory LoDePruebas.fromMap(Map<Object?, Object?> m) => LoDePruebas(
    flows: [
      for (final f in (m['flows'] as List?) ?? const []) ?FlowDelHub.fromMap(f),
    ],
    enMarcha: switch (m['enMarcha']) {
      {'flow': final String flow} && final Map<Object?, Object?> e => (
        flow: flow,
        hechos: (e['hechos'] as int?) ?? 0,
        total: (e['total'] as int?) ?? 0,
        viva: e['viva'] == true,
        fallo: e['fallo'] == true,
      ),
      _ => null,
    },
    historial: [
      for (final p in (m['historial'] as List?) ?? const [])
        ?PasadaDelHub.fromMap(p),
    ],
    repo: [
      for (final r in (m['repo'] as List?) ?? const []) ?FlowDelRepo.fromMap(r),
    ],
    repoComo: m['repoComo'] as String?,
    semana: switch (m['semana']) {
      [final int bien, final int mal, final int todas] => (
        bien: bien,
        mal: mal,
        todas: todas,
      ),
      _ => (bien: 0, mal: 0, todas: 0),
    },
    aviso: m['aviso'] as String?,
  );
}
