import 'package:flutter/foundation.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_ensena_el_hub.dart';

/// **Lo que se pulsa en el hub**, de vuelta a la app.
///
/// El motor del hub no hace nada por su cuenta: dice qué se pulsó y la app,
/// que es la que tiene el estado, lo hace. Es el mismo reparto que la
/// botonera de fuera, y por eso lo de la botonera viaja dentro tal cual
/// ([DeLaBotonera]): copiar aquí su lista de pedidos sería tener dos que
/// mantener de acuerdo.
@immutable
sealed class PedidoDelHub {
  const PedidoDelHub();

  Map<String, Object?> toMap();

  static PedidoDelHub? fromMap(Map<Object?, Object?> mapa) =>
      switch ((mapa['que'], mapa['id'])) {
        ('elegir', final String id) => ElegirDispositivo(id),
        ('arrancar', final String id) => ArrancarDispositivo(
          id,
          frio: mapa['frio'] == true,
        ),
        ('cerrar', final String id) => CerrarDispositivo(id),
        ('refrescar', _) => const RefrescarLaLista(),
        ('app', final String ruta) => ElegirApp(ruta),
        ('config', final String nombre) => ElegirConfig(nombre),
        ('correr', _) => const Correr(),
        ('duplicar', _) => const DuplicarConConsola(),
        ('quitarCopia', _) => const QuitarLaCopia(),
        ('traer', final String id) => TraerAlFrente(id),
        ('verFuera', final String id) => switch (ComoVerFuera.values
            .asNameMap()[mapa['como']]) {
          final como? => VerFuera(id, como),
          null => null,
        },
        ('botonera', _) => switch (mapa['pedido']) {
          final Map<Object?, Object?> pedido => DeLaBotonera(pedido),
          _ => null,
        },
        _ => null,
      };
}

class ElegirDispositivo extends PedidoDelHub {
  const ElegirDispositivo(this.id);
  final String id;

  @override
  Map<String, Object?> toMap() => {'que': 'elegir', 'id': id};

  @override
  bool operator ==(Object other) =>
      other is ElegirDispositivo && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Arrancar un emulador o un simulador apagado. [frio] solo existe en Android:
/// es `--cold`, ver `ComandoDeEmuladores.argumentosDeLanzar`.
class ArrancarDispositivo extends PedidoDelHub {
  const ArrancarDispositivo(this.id, {this.frio = false});
  final String id;
  final bool frio;

  @override
  Map<String, Object?> toMap() => {'que': 'arrancar', 'id': id, 'frio': frio};

  @override
  bool operator ==(Object other) =>
      other is ArrancarDispositivo && other.id == id && other.frio == frio;

  @override
  int get hashCode => Object.hash(id, frio);
}

class CerrarDispositivo extends PedidoDelHub {
  const CerrarDispositivo(this.id);
  final String id;

  @override
  Map<String, Object?> toMap() => {'que': 'cerrar', 'id': id};

  @override
  bool operator ==(Object other) =>
      other is CerrarDispositivo && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class RefrescarLaLista extends PedidoDelHub {
  const RefrescarLaLista();

  @override
  Map<String, Object?> toMap() => {'que': 'refrescar'};

  @override
  bool operator ==(Object other) => other is RefrescarLaLista;

  @override
  int get hashCode => 0;
}

/// Lo que se pulsó en la botonera de la cabecera, tal cual: lo atiende
/// `atenderLaBotoneraProvider`, como cuando flota.
class DeLaBotonera extends PedidoDelHub {
  const DeLaBotonera(this.pedido);
  final Map<Object?, Object?> pedido;

  @override
  Map<String, Object?> toMap() => {'que': 'botonera', 'pedido': pedido};

  @override
  bool operator ==(Object other) =>
      other is DeLaBotonera && mapEquals(other.pedido, pedido);

  @override
  int get hashCode => Object.hashAll(pedido.entries.map((e) => e.key));
}

/// Elegir la app: [ruta] es la carpeta, que es lo que viaja en `id`.
class ElegirApp extends PedidoDelHub {
  const ElegirApp(this.ruta);
  final String ruta;

  @override
  Map<String, Object?> toMap() => {'que': 'app', 'id': ruta};

  @override
  bool operator ==(Object other) => other is ElegirApp && other.ruta == ruta;

  @override
  int get hashCode => ruta.hashCode;
}

class ElegirConfig extends PedidoDelHub {
  const ElegirConfig(this.nombre);
  final String nombre;

  @override
  Map<String, Object?> toMap() => {'que': 'config', 'id': nombre};

  @override
  bool operator ==(Object other) =>
      other is ElegirConfig && other.nombre == nombre;

  @override
  int get hashCode => nombre.hashCode;
}

/// ▶: correr la app elegida, con su configuración, en el dispositivo elegido
/// —arrancándolo antes si está apagado—.
class Correr extends PedidoDelHub {
  const Correr();

  @override
  Map<String, Object?> toMap() => {'que': 'correr'};

  @override
  bool operator ==(Object other) => other is Correr;

  @override
  int get hashCode => 1;
}

class DuplicarConConsola extends PedidoDelHub {
  const DuplicarConConsola();

  @override
  Map<String, Object?> toMap() => {'que': 'duplicar'};

  @override
  bool operator ==(Object other) => other is DuplicarConConsola;

  @override
  int get hashCode => 2;
}

class QuitarLaCopia extends PedidoDelHub {
  const QuitarLaCopia();

  @override
  Map<String, Object?> toMap() => {'que': 'quitarCopia'};

  @override
  bool operator ==(Object other) => other is QuitarLaCopia;

  @override
  int get hashCode => 3;
}

/// Traer al frente la ventana donde está su pantalla: Simulator, o la del
/// emulador cuando no deja verla dentro.
class TraerAlFrente extends PedidoDelHub {
  const TraerAlFrente(this.id);
  final String id;

  @override
  Map<String, Object?> toMap() => {'que': 'traer', 'id': id};

  @override
  bool operator ==(Object other) => other is TraerAlFrente && other.id == id;

  @override
  int get hashCode => Object.hash('traer', id);
}

/// Abrir su pantalla en otra ventana: scrcpy, Duplicado de iPhone, QuickTime.
class VerFuera extends PedidoDelHub {
  const VerFuera(this.id, this.como);
  final String id;
  final ComoVerFuera como;

  @override
  Map<String, Object?> toMap() => {
    'que': 'verFuera',
    'id': id,
    'como': como.name,
  };

  @override
  bool operator ==(Object other) =>
      other is VerFuera && other.id == id && other.como == como;

  @override
  int get hashCode => Object.hash(id, como);
}
