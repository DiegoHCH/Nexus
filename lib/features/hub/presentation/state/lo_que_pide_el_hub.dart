import 'package:flutter/foundation.dart';

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
