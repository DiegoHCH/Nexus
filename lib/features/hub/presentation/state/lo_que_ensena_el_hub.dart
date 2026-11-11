import 'package:flutter/foundation.dart';
import 'package:nexus/features/emulators/domain/entities/linea_de_registro.dart';
import 'package:nexus/core/design_system/la_apariencia_de_fuera.dart';
import 'package:nexus/features/hub/domain/entities/dispositivo_del_hub.dart';
import 'package:nexus/features/hub/domain/usecases/correr_desde_el_hub.dart';
import 'package:nexus/features/hub/presentation/state/lo_de_pruebas.dart';
import 'package:nexus/features/run/presentation/state/lo_que_ensena_la_botonera.dart';

/// **Todo lo que pinta la ventana del hub**, en una foto.
///
/// El hub corre su propio motor de Flutter, como la botonera de fuera, y ese
/// motor **no tiene los providers de la app ni sus plugins**: lo que no viaje
/// aquí no existe para él. La app arma la foto, la manda entera cada vez que
/// algo cambia —como mucho cada 300 ms— y lo que se pulsa vuelve como un
/// `PedidoDelHub`. Ver `ElHubDeDispositivos`.
@immutable
class LoQueEnsenaElHub {
  const LoQueEnsenaElHub({
    required this.apariencia,
    required this.dispositivos,
    required this.elegido,
    required this.buscando,
    required this.botonera,
    required this.registro,
    this.correr = const LoDeCorrer(),
    this.verFuera = const [],
    this.pruebas = const LoDePruebas(),
    this.enPruebas = false,
    this.enSistema = false,
    this.sistema = const [],
    this.escuchandoSistema = false,
    this.nivelDelSistema = NivelDeRegistro.info,
    this.buscaEnElSistema = '',
    this.aviso,
  });

  /// La de Nexus: tema, acento e idioma. Ver `LaAparienciaDeFuera`.
  final LaAparienciaDeFuera apariencia;

  final List<DispositivoDelHub> dispositivos;

  /// El `id` del elegido en la lista, o `null` si no hay ninguno.
  final String? elegido;

  /// Que alguna de las listas todavía no contestó: «todavía no sé» no es lo
  /// mismo que «no hay ninguno».
  final bool buscando;

  /// La de la botonera de siempre, **solo con la corrida del elegido**: la
  /// cabecera del hub habla de un dispositivo, no de todos.
  final LoQueEnsenaLaBotonera botonera;

  /// Las líneas de su corrida, las mismas que guarda `registrosProvider`.
  final List<String> registro;

  /// Qué se corre: la app, la configuración y si se puede. Ver [LoDeCorrer].
  final LoDeCorrer correr;

  /// Cómo se puede ver la pantalla del elegido en otra ventana: scrcpy en un
  /// Android enchufado, Duplicado y QuickTime en un iPhone. Lo de hoy en el
  /// panel de dispositivos.
  final List<ComoVerFuera> verFuera;

  /// La cara de pruebas (T15). Ver [LoDePruebas].
  final LoDePruebas pruebas;

  /// Si se ve la cara de pruebas en vez de la pantalla.
  final bool enPruebas;

  /// Si el panel de abajo enseña el registro del sistema del elegido en vez
  /// del de su corrida (11 nov: las dos, como pestañas del mismo panel).
  final bool enSistema;

  /// Lo que dice el sistema del elegido —`logcat` en Android—, ya filtrado y
  /// solo las últimas: solo viaja con [enSistema] puesto.
  final List<LineaDeRegistro> sistema;

  /// Si se está escuchando ahora: «escuchando, todavía nada» no es lo mismo
  /// que «no se pudo».
  final bool escuchandoSistema;

  /// El filtro del registro del sistema, el de la ventana del sistema: desde
  /// qué nivel y qué texto. Viaja para que la pestaña enseñe cuál está puesto.
  final NivelDeRegistro nivelDelSistema;
  final String buscaEnElSistema;

  /// Lo que salió mal en lo último que se pidió —arrancar, cerrar—, tal como lo
  /// contó la herramienta. Se borra con el siguiente pedido.
  final String? aviso;

  DispositivoDelHub? get elDispositivo {
    for (final d in dispositivos) {
      if (d.id == elegido) return d;
    }
    return null;
  }

  Map<String, Object?> toMap() => {
    'apariencia': apariencia.toMap(),
    'dispositivos': [for (final d in dispositivos) d.toMap()],
    'elegido': ?elegido,
    'buscando': buscando,
    'botonera': botonera.toMap(),
    'registro': registro,
    'correr': correr.toMap(),
    'verFuera': [for (final c in verFuera) c.name],
    'pruebas': pruebas.toMap(),
    'enPruebas': enPruebas,
    'enSistema': enSistema,
    'sistema': [
      for (final l in sistema)
        {'n': l.nivel.name, 'e': l.etiqueta, 't': l.texto},
    ],
    'escuchandoSistema': escuchandoSistema,
    'nivelSistema': nivelDelSistema.name,
    'buscaSistema': buscaEnElSistema,
    'aviso': ?aviso,
  };

  factory LoQueEnsenaElHub.fromMap(Map<Object?, Object?> mapa) =>
      LoQueEnsenaElHub(
        apariencia: LaAparienciaDeFuera.fromMap(_mapa(mapa['apariencia'])),
        dispositivos: [
          for (final d in _lista(mapa['dispositivos']))
            if (d is Map<Object?, Object?>) ?DispositivoDelHub.fromMap(d),
        ],
        elegido: mapa['elegido'] as String?,
        buscando: mapa['buscando'] == true,
        botonera: LoQueEnsenaLaBotonera.fromMap(_mapa(mapa['botonera'])),
        registro: [
          for (final l in _lista(mapa['registro']))
            if (l is String) l,
        ],
        correr: LoDeCorrer.fromMap(_mapa(mapa['correr'])),
        verFuera: [
          for (final c in _lista(mapa['verFuera']))
            ?ComoVerFuera.values.asNameMap()[c],
        ],
        pruebas: LoDePruebas.fromMap(_mapa(mapa['pruebas'])),
        enPruebas: mapa['enPruebas'] == true,
        enSistema: mapa['enSistema'] == true,
        sistema: [
          for (final l in _lista(mapa['sistema']))
            if (l is Map<Object?, Object?>)
              LineaDeRegistro(
                nivel:
                    NivelDeRegistro.values.asNameMap()[l['n']] ??
                    NivelDeRegistro.info,
                etiqueta: l['e'] is String ? l['e']! as String : '',
                texto: l['t'] is String ? l['t']! as String : '',
              ),
        ],
        escuchandoSistema: mapa['escuchandoSistema'] == true,
        nivelDelSistema:
            NivelDeRegistro.values.asNameMap()[mapa['nivelSistema']] ??
            NivelDeRegistro.info,
        buscaEnElSistema: mapa['buscaSistema'] is String
            ? mapa['buscaSistema']! as String
            : '',
        aviso: mapa['aviso'] as String?,
      );

  static Map<Object?, Object?> _mapa(Object? o) =>
      o is Map<Object?, Object?> ? o : const {};

  static List<Object?> _lista(Object? o) => o is List<Object?> ? o : const [];
}

/// Con qué se ve la pantalla de un dispositivo en otra ventana.
enum ComoVerFuera { scrcpy, duplicado, quickTime }

/// Una configuración de `launch.json`, o una copia «tuya» ([deCasa]).
@immutable
class ConfigDelHub {
  const ConfigDelHub({required this.nombre, this.deCasa = false});

  final String nombre;
  final bool deCasa;

  @override
  bool operator ==(Object other) =>
      other is ConfigDelHub && other.nombre == nombre && other.deCasa == deCasa;

  @override
  int get hashCode => Object.hash(nombre, deCasa);
}

/// Lo que se puede hacer con la configuración elegida, como en el menú de
/// correr: quitar la copia si es tuya, duplicarla con la consola si se puede,
/// o decir que ya la trae.
enum LaCopia { quitar, duplicar, yaTraeConsola }

/// **Qué se corre** (P1): la app, su configuración y por qué no se puede, si
/// no se puede. Es lo que hacía el menú de correr del chat, ahora en la
/// cabecera del hub.
@immutable
class LoDeCorrer {
  const LoDeCorrer({
    this.apps = const [],
    this.app,
    this.configs = const [],
    this.config,
    this.porQueNo = PorQueNoSeCorre.sinApp,
    this.arrancaYCorre = false,
    this.copia,
    this.ocupado = false,
  });

  final List<AppDelHub> apps;
  final String? app;
  final List<ConfigDelHub> configs;
  final String? config;

  /// `null` si se puede correr.
  final PorQueNoSeCorre? porQueNo;

  /// Que el elegido está apagado: ▶ lo arranca y corre en él.
  final bool arrancaYCorre;

  final LaCopia? copia;

  /// Que se está corriendo o copiando: los botones se apagan mientras.
  final bool ocupado;

  Map<String, Object?> toMap() => {
    'apps': [
      for (final a in apps) {'ruta': a.ruta, 'nombre': a.nombre},
    ],
    'app': ?app,
    'configs': [
      for (final c in configs) {'nombre': c.nombre, 'deCasa': c.deCasa},
    ],
    'config': ?config,
    'porQueNo': ?porQueNo?.name,
    'arrancaYCorre': arrancaYCorre,
    'copia': ?copia?.name,
    'ocupado': ocupado,
  };

  factory LoDeCorrer.fromMap(Map<Object?, Object?> mapa) => LoDeCorrer(
    apps: [
      for (final a in LoQueEnsenaElHub._lista(mapa['apps']))
        if (a case {'ruta': final String ruta, 'nombre': final String nombre})
          AppDelHub(ruta: ruta, nombre: nombre),
    ],
    app: mapa['app'] as String?,
    configs: [
      for (final c in LoQueEnsenaElHub._lista(mapa['configs']))
        if (c case {'nombre': final String nombre})
          ConfigDelHub(nombre: nombre, deCasa: c['deCasa'] == true),
    ],
    config: mapa['config'] as String?,
    porQueNo: PorQueNoSeCorre.values.asNameMap()[mapa['porQueNo']],
    arrancaYCorre: mapa['arrancaYCorre'] == true,
    copia: LaCopia.values.asNameMap()[mapa['copia']],
    ocupado: mapa['ocupado'] == true,
  );
}
