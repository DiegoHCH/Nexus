import 'package:nexus/features/run/domain/usecases/como_va_la_corrida.dart';

/// **Lo que se pulsa en la botonera**, dicho de forma que pueda cruzar motores.
///
/// La ventana de fuera no puede recargar nada: no tiene la corrida, ni el
/// daemon, ni un solo provider —es otro isolate—. Lo que sí puede es decir qué
/// se pulsó, y quien lo hace es la app, con los mismos casos de uso que usaba
/// la botonera de dentro. Ver `atenderLaBotoneraProvider`.
///
/// Y la de dentro, cuando la hay, pide exactamente lo mismo por el mismo
/// camino: así los dos sitios donde puede vivir la barra no pueden hacer cosas
/// distintas al pulsar el mismo botón.
sealed class PedidoDeLaBotonera {
  const PedidoDeLaBotonera();

  Map<String, Object?> toMap();

  /// `null` si no se entiende: un pedido raro que llega de fuera se ignora, no
  /// se adivina.
  static PedidoDeLaBotonera? fromMap(Map<Object?, Object?> mapa) =>
      switch (mapa['que']) {
        'corrida' => switch ((
          mapa['deviceId'],
          AccionDeCorrida.values
              .where((a) => a.name == mapa['accion'])
              .firstOrNull,
        )) {
          (final String deviceId, final AccionDeCorrida accion) =>
            AccionEnLaCorrida(deviceId: deviceId, accion: accion),
          _ => null,
        },
        'pararTrabajo' => switch (mapa['conversacion']) {
          final String conversacion => PararElTrabajo(conversacion),
          _ => null,
        },
        'recargaSola' => const CambiarLaRecargaSola(),
        'esconder' => const EsconderLaBotonera(),
        _ => null,
      };
}

/// Un botón de la fila de una corrida: recargar, parar, pasarle el error…
final class AccionEnLaCorrida extends PedidoDeLaBotonera {
  const AccionEnLaCorrida({required this.deviceId, required this.accion});

  final String deviceId;
  final AccionDeCorrida accion;

  @override
  Map<String, Object?> toMap() => {
    'que': 'corrida',
    'deviceId': deviceId,
    'accion': accion.name,
  };

  @override
  bool operator ==(Object other) =>
      other is AccionEnLaCorrida &&
      other.deviceId == deviceId &&
      other.accion == accion;

  @override
  int get hashCode => Object.hash(deviceId, accion);
}

/// Parar un trabajo largo.
final class PararElTrabajo extends PedidoDeLaBotonera {
  const PararElTrabajo(this.conversacion);

  final String conversacion;

  @override
  Map<String, Object?> toMap() => {
    'que': 'pararTrabajo',
    'conversacion': conversacion,
  };

  @override
  bool operator ==(Object other) =>
      other is PararElTrabajo && other.conversacion == conversacion;

  @override
  int get hashCode => conversacion.hashCode;
}

/// «⚡ Recargar sola al terminar», encender o apagar.
final class CambiarLaRecargaSola extends PedidoDeLaBotonera {
  const CambiarLaRecargaSola();

  @override
  Map<String, Object?> toMap() => {'que': 'recargaSola'};

  @override
  bool operator ==(Object other) => other is CambiarLaRecargaSola;

  @override
  int get hashCode => (CambiarLaRecargaSola).hashCode;
}

/// Quitar la ventana de en medio mientras siga corriendo lo mismo.
final class EsconderLaBotonera extends PedidoDeLaBotonera {
  const EsconderLaBotonera();

  @override
  Map<String, Object?> toMap() => {'que': 'esconder'};

  @override
  bool operator ==(Object other) => other is EsconderLaBotonera;

  @override
  int get hashCode => (EsconderLaBotonera).hashCode;
}
