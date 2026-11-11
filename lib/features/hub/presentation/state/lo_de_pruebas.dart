import 'package:flutter/foundation.dart';

/// Un flow de `.maestro` de la app, con cómo acabó su última pasada.
@immutable
class FlowDelHub {
  const FlowDelHub({
    required this.ruta,
    required this.nombre,
    this.bien,
    this.enGit,
  });

  final String ruta;
  final String nombre;

  /// `true` pasó, `false` cayó, `null` sin pasadas.
  final bool? bien;

  /// Si git lo tiene: entonces borrarlo se recupera, y si no, se pierde. Es
  /// lo que dice el aviso de borrar. `null` mientras se pregunta, o sin git.
  final bool? enGit;

  Map<String, Object?> toMap() => {
    'ruta': ruta,
    'nombre': nombre,
    'bien': ?bien,
    'enGit': ?enGit,
  };

  static FlowDelHub? fromMap(Object? o) => switch (o) {
    {'ruta': final String ruta, 'nombre': final String nombre} => FlowDelHub(
      ruta: ruta,
      nombre: nombre,
      bien: (o as Map)['bien'] as bool?,
      enGit: o['enGit'] as bool?,
    ),
    _ => null,
  };
}

/// **Publicar una prueba en el repo del equipo**, desde el hub (11 nov): crea
/// una rama y abre un PR. La app prepara y publica; el hub enseña el diálogo
/// con lo que aquí viene. Es lo del diálogo del panel completo, mudado.
@immutable
class LaPublicacionDelHub {
  const LaPublicacionDelHub({
    required this.ruta,
    required this.nombre,
    required this.destino,
    this.repo,
    this.reemplaza,
    this.publicando = false,
    this.resultado,
  });

  /// La prueba que se publica, y cómo se llama.
  final String ruta;
  final String nombre;

  /// A dónde va dentro del repo: `flows/<nombre>.yaml`.
  final String destino;

  /// El repo de pruebas (`equipo/qa-flows`), o `null` si no está clonado: sin
  /// él no hay dónde escribir, y se dice en vez de ofrecer el botón.
  final String? repo;

  /// Si ya hay un archivo en [destino]: entonces lo reemplaza, y se avisa
  /// antes. `null` mientras se mira.
  final bool? reemplaza;

  final bool publicando;

  /// Cómo fue: la rama y el PR, o el motivo del fallo.
  final ({bool ok, String detalle, String rama, String url})? resultado;

  LaPublicacionDelHub copyWith({
    String? repo,
    bool? reemplaza,
    bool? publicando,
    ({bool ok, String detalle, String rama, String url})? resultado,
  }) => LaPublicacionDelHub(
    ruta: ruta,
    nombre: nombre,
    destino: destino,
    repo: repo ?? this.repo,
    reemplaza: reemplaza ?? this.reemplaza,
    publicando: publicando ?? this.publicando,
    resultado: resultado ?? this.resultado,
  );

  Map<String, Object?> toMap() => {
    'ruta': ruta,
    'nombre': nombre,
    'destino': destino,
    'repo': ?repo,
    'reemplaza': ?reemplaza,
    'publicando': publicando,
    if (resultado case final r?)
      'resultado': {
        'ok': r.ok,
        'detalle': r.detalle,
        'rama': r.rama,
        'url': r.url,
      },
  };

  static LaPublicacionDelHub? fromMap(Object? o) => switch (o) {
    {
          'ruta': final String ruta,
          'nombre': final String nombre,
          'destino': final String destino,
        } &&
        final Map<Object?, Object?> m =>
      LaPublicacionDelHub(
        ruta: ruta,
        nombre: nombre,
        destino: destino,
        repo: m['repo'] as String?,
        reemplaza: m['reemplaza'] as bool?,
        publicando: m['publicando'] == true,
        resultado: switch (m['resultado']) {
          final Map<Object?, Object?> r => (
            ok: r['ok'] == true,
            detalle: (r['detalle'] as String?) ?? '',
            rama: (r['rama'] as String?) ?? '',
            url: (r['url'] as String?) ?? '',
          ),
          _ => null,
        },
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
/// se hace también aquí (11 nov): ya no se abre el panel completo en Nexus.
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
    this.variables = 0,
    this.envEnGit = false,
    this.publicacion,
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

  /// Cuántas variables del `.env.local` de la app se cargaron, sin enseñar
  /// ninguna, y si ese archivo está en git (que no debería).
  final int variables;
  final bool envEnGit;

  /// La publicación en curso, si hay una: ver [LaPublicacionDelHub].
  final LaPublicacionDelHub? publicacion;

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
    'variables': variables,
    'envEnGit': envEnGit,
    if (publicacion case final p?) 'publicacion': p.toMap(),
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
    variables: (m['variables'] as int?) ?? 0,
    envEnGit: m['envEnGit'] == true,
    publicacion: LaPublicacionDelHub.fromMap(m['publicacion']),
  );
}
