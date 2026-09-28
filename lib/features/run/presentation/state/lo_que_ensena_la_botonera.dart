import 'package:nexus/features/run/domain/entities/corrida.dart';
import 'package:nexus/features/run/domain/usecases/como_va_la_corrida.dart';
import 'package:nexus/features/run/domain/usecases/el_freno_de_la_app.dart';

/// **Lo que la botonera enseña, y nada más**: la foto de lo que corre.
///
/// 🔴 **Existe porque la botonera salió de la ventana de Nexus.** Pedido así:
/// «la ventana que muestra corriendo en el dispositivo quisiera que fuera una
/// ventana independiente como los documentos y demás, porque al no poder salir
/// ocupa espacio de la ventana normal». Fuera, la barra vive en **otro motor de
/// Flutter** —como el orbe del escritorio—, y dos motores son dos isolates que
/// no comparten ni un provider. Lo único que cruza entre ellos es un mapa.
///
/// Así que esto es ese mapa con forma: lo que cada fila necesita **para
/// pintarse**, ya decidido. Las reglas —qué acciones tocan y en qué orden, de
/// qué color va el punto— se aplican aquí, en el motor de la app, con
/// [ComoVaLaCorridaDe]; el de fuera solo dibuja. Si las decidiera él, habría dos
/// sitios donde mantenerlas de acuerdo, y ese acuerdo no lo guarda nadie.
///
/// Los textos **no** viajan hechos: viaja el idioma, y cada motor los saca de
/// su diccionario. Así una frase nueva no obliga a tocar el mapa.
class LoQueEnsenaLaBotonera {
  const LoQueEnsenaLaBotonera({
    this.corridas = const [],
    this.trabajos = const [],
    this.deFondo = const [],
    this.recargaSola = false,
  });

  final List<FilaDeCorrida> corridas;
  final List<FilaDeTrabajo> trabajos;
  final List<FilaDeFondo> deFondo;

  /// «⚡ Recargar sola al terminar», que va en el asa y vale para todas.
  final bool recargaSola;

  /// El número de «Corriendo · N».
  int get cuantas => corridas.length + trabajos.length + deFondo.length;

  /// Sin nada corriendo no hay botonera: ni dentro ni fuera.
  bool get vacia => cuantas == 0;

  /// Quién está en la foto, para saber si **empezó algo nuevo**. Ver
  /// `LaBotoneraDeFuera`: lo que se escondió a mano vuelve cuando arranca otra
  /// cosa, no cuando la que ya estaba cambia de línea.
  Set<String> get quienes => {
    for (final c in corridas) 'corrida:${c.deviceId}',
    for (final t in trabajos) 'trabajo:${t.conversacion}',
    for (final f in deFondo) 'fondo:${f.id}',
  };

  Map<String, Object?> toMap() => {
    'corridas': [for (final c in corridas) c.toMap()],
    'trabajos': [for (final t in trabajos) t.toMap()],
    'deFondo': [for (final f in deFondo) f.toMap()],
    'recargaSola': recargaSola,
  };

  /// Lo que no se entiende se salta, fila a fila: una fila rara no puede
  /// dejar la barra en blanco, que es quedarse sin el botón de parar.
  factory LoQueEnsenaLaBotonera.fromMap(Map<Object?, Object?> mapa) =>
      LoQueEnsenaLaBotonera(
        corridas: [
          for (final m in _lista(mapa['corridas'])) ?FilaDeCorrida.fromMap(m),
        ],
        trabajos: [
          for (final m in _lista(mapa['trabajos'])) ?FilaDeTrabajo.fromMap(m),
        ],
        deFondo: [
          for (final m in _lista(mapa['deFondo'])) ?FilaDeFondo.fromMap(m),
        ],
        recargaSola: mapa['recargaSola'] == true,
      );

  static Iterable<Map<Object?, Object?>> _lista(Object? valor) =>
      valor is List ? valor.whereType<Map<Object?, Object?>>() : const [];
}

/// Una corrida, lista para su fila.
class FilaDeCorrida {
  const FilaDeCorrida({
    required this.deviceId,
    required this.configuracion,
    required this.dispositivo,
    required this.como,
    required this.acciones,
    this.progreso,
    this.paradaEn,
    this.errores = 0,
    this.frenoPuesto = false,
    this.registroAbierto = false,
    this.sistemaAbierto = false,
  });

  /// Desde la corrida de verdad. [registroAbierto] y [sistemaAbierto] dicen si
  /// sus ventanas de registro están abiertas, para que el botón lo diga.
  factory FilaDeCorrida.de(
    Corrida corrida, {
    required bool registroAbierto,
    required bool sistemaAbierto,
  }) => FilaDeCorrida(
    deviceId: corrida.deviceId,
    configuracion: corrida.configuracion,
    dispositivo: corrida.dispositivo,
    como: ComoVaLaCorridaDe.de(corrida),
    acciones: ComoVaLaCorridaDe.acciones(corrida),
    progreso: corrida.progreso,
    paradaEn: corrida.parada?.donde,
    errores: corrida.errores,
    frenoPuesto: corrida.freno != ModoDePausa.ninguna,
    registroAbierto: registroAbierto,
    sistemaAbierto: sistemaAbierto,
  );

  final String deviceId;
  final String configuracion;
  final String dispositivo;
  final ComoVaLaCorrida como;

  /// En orden, **la que toca primero**. Ver [ComoVaLaCorridaDe.acciones].
  final List<AccionDeCorrida> acciones;

  /// Lo que dice Gradle mientras compila: «Running Gradle task…».
  final String? progreso;

  /// Dónde se detuvo, si se sabe: «credit_summary_banner.dart:42».
  final String? paradaEn;
  final int errores;
  final bool frenoPuesto;
  final bool registroAbierto;
  final bool sistemaAbierto;

  Map<String, Object?> toMap() => {
    'deviceId': deviceId,
    'configuracion': configuracion,
    'dispositivo': dispositivo,
    // Por nombre y no por índice, como el estado del orbe: el orden de un enum
    // es cosa de otro archivo, y atarlo aquí haría que añadir un valor cambiara
    // lo que pinta la ventana sin que nadie la tocara.
    'como': como.name,
    'acciones': [for (final a in acciones) a.name],
    'progreso': ?progreso,
    'paradaEn': ?paradaEn,
    'errores': errores,
    'frenoPuesto': frenoPuesto,
    'registroAbierto': registroAbierto,
    'sistemaAbierto': sistemaAbierto,
  };

  static FilaDeCorrida? fromMap(Map<Object?, Object?> mapa) {
    final deviceId = mapa['deviceId'];
    final como = ComoVaLaCorrida.values
        .where((c) => c.name == mapa['como'])
        .firstOrNull;
    if (deviceId is! String || como == null) return null;
    final acciones = mapa['acciones'];
    return FilaDeCorrida(
      deviceId: deviceId,
      configuracion: mapa['configuracion'] as String? ?? '',
      dispositivo: mapa['dispositivo'] as String? ?? '',
      como: como,
      acciones: [
        if (acciones is List)
          for (final nombre in acciones)
            ?AccionDeCorrida.values.where((a) => a.name == nombre).firstOrNull,
      ],
      progreso: mapa['progreso'] as String?,
      paradaEn: mapa['paradaEn'] as String?,
      errores: (mapa['errores'] as num?)?.toInt() ?? 0,
      frenoPuesto: mapa['frenoPuesto'] == true,
      registroAbierto: mapa['registroAbierto'] == true,
      sistemaAbierto: mapa['sistemaAbierto'] == true,
    );
  }
}

/// Un trabajo largo —un `/gate`, un `make check`— con lo último que dijo.
class FilaDeTrabajo {
  const FilaDeTrabajo({
    required this.conversacion,
    required this.comando,
    this.ultimaLinea,
  });

  /// De quién es, que es por donde se le pide parar.
  final String conversacion;
  final String comando;

  /// `null` antes de la primera línea: entonces se dice «arrancando…».
  final String? ultimaLinea;

  Map<String, Object?> toMap() => {
    'conversacion': conversacion,
    'comando': comando,
    'ultimaLinea': ?ultimaLinea,
  };

  static FilaDeTrabajo? fromMap(Map<Object?, Object?> mapa) {
    final conversacion = mapa['conversacion'];
    final comando = mapa['comando'];
    if (conversacion is! String || comando is! String) return null;
    return FilaDeTrabajo(
      conversacion: conversacion,
      comando: comando,
      ultimaLinea: mapa['ultimaLinea'] as String?,
    );
  }
}

/// Lo que Claude dejó corriendo aparte. Sin botón: ver la fila que lo pinta.
class FilaDeFondo {
  const FilaDeFondo({required this.id, required this.que});

  final String id;
  final String que;

  Map<String, Object?> toMap() => {'id': id, 'que': que};

  static FilaDeFondo? fromMap(Map<Object?, Object?> mapa) {
    final id = mapa['id'];
    final que = mapa['que'];
    if (id is! String || que is! String) return null;
    return FilaDeFondo(id: id, que: que);
  }
}

/// **Lo que cruza a la ventana de fuera**: la botonera y cómo pintarla.
///
/// El tema, el acento y el idioma viajan con **cada** foto por lo mismo que con
/// el orbe: el otro motor no puede leer Ajustes, así que si se cambia el color
/// con la botonera fuera, la única forma de que se entere es decírselo.
class LaFotoDeLaBotonera {
  const LaFotoDeLaBotonera({
    required this.lo,
    this.claro = false,
    this.acento,
    this.idioma = 'es',
    this.pedirPermisoDelEspejo = false,
  });

  final LoQueEnsenaLaBotonera lo;

  /// El tema que la app pinta ya resuelto contra el sistema.
  final bool claro;

  /// El acento ya ajustado al tema, en ARGB. `null` es el de fábrica.
  final int? acento;

  /// `es` o `en`. El español manda si llega otra cosa.
  final String idioma;

  /// Si la barra pregunta por el permiso de Accesibilidad, que es el que deja
  /// llevar el espejo pegado. **Solo fuera**: dentro de Nexus no hay ventana a
  /// la que pegarlo, y preguntar ahí sería pedir algo que no se va a usar.
  final bool pedirPermisoDelEspejo;

  LaFotoDeLaBotonera conElPermiso({required bool pedir}) => LaFotoDeLaBotonera(
    lo: lo,
    claro: claro,
    acento: acento,
    idioma: idioma,
    pedirPermisoDelEspejo: pedir,
  );

  Map<String, Object?> toMap() => {
    'lo': lo.toMap(),
    'claro': claro,
    'acento': ?acento,
    'idioma': idioma,
    'pedirPermisoDelEspejo': pedirPermisoDelEspejo,
  };

  factory LaFotoDeLaBotonera.fromMap(Map<Object?, Object?> mapa) {
    final lo = mapa['lo'];
    return LaFotoDeLaBotonera(
      lo: lo is Map<Object?, Object?>
          ? LoQueEnsenaLaBotonera.fromMap(lo)
          : const LoQueEnsenaLaBotonera(),
      claro: mapa['claro'] == true,
      acento: (mapa['acento'] as num?)?.toInt(),
      idioma: mapa['idioma'] as String? ?? 'es',
      pedirPermisoDelEspejo: mapa['pedirPermisoDelEspejo'] == true,
    );
  }
}
