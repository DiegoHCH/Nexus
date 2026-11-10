import 'package:flutter/foundation.dart';
import 'package:nexus/core/design_system/la_apariencia_de_fuera.dart';
import 'package:nexus/features/hub/domain/entities/dispositivo_del_hub.dart';
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
        aviso: mapa['aviso'] as String?,
      );

  static Map<Object?, Object?> _mapa(Object? o) =>
      o is Map<Object?, Object?> ? o : const {};

  static List<Object?> _lista(Object? o) => o is List<Object?> ? o : const [];
}
