import 'package:nexus/features/run/domain/entities/corrida.dart';

/// En qué está una corrida, **para el punto de su fila**.
///
/// No es [EstadoDeCorrida]: aquél es lo que dice el daemon, y una app parada en
/// un punto de ruptura o rompiéndose en cada fotograma sigue estando
/// «corriendo» para él. Esto es lo que necesita saber quien mira: si va bien,
/// si hay que atenderla, o si está esperando a que la suelten.
enum ComoVaLaCorrida {
  /// Compilando o instalando. Todavía no hay app que mirar.
  arrancando,

  /// Arriba y sin errores desde la última recarga. Verde.
  corriendo,

  /// Arriba pero con errores desde la última recarga. Rojo.
  conErrores,

  /// Detenida en un punto de ruptura o en una excepción. Ámbar.
  parada,

  /// Se pidió parar y se está esperando a que el proceso salga.
  parando,
}

/// Lo que se le puede pedir a una corrida desde su fila.
enum AccionDeCorrida {
  pasarleElError,
  seguir,
  siguienteLinea,
  entrar,
  salir,
  recargar,
  reiniciar,
  freno,
  consola,
  registro,
  registroDelSistema,
  parar,
}

/// Cómo va una corrida y, en orden, qué se le puede pedir.
///
/// **Puro y aparte del widget** porque aquí están las dos reglas que el mockup
/// fija y que se rompen sin que nadie lo note al añadir un botón: que el color
/// del punto diga lo mismo que la frase de al lado, y que **la acción que toca
/// vaya primero** —con errores, «Pasarle el error a Claude»; parada, «Seguir»—.
abstract final class ComoVaLaCorridaDe {
  /// El estado que manda en el punto.
  ///
  /// El orden de las comprobaciones es la regla: **parando** gana a todo —ya
  /// no hay nada que atender—; **parada** gana a los errores, porque una app
  /// congelada no se arregla leyendo el error, primero hay que soltarla; y los
  /// errores ganan a «corriendo», que es la mentira que había cuando el punto
  /// solo sabía de verde y ámbar.
  static ComoVaLaCorrida de(Corrida corrida) {
    if (corrida.estado == EstadoDeCorrida.parando) {
      return ComoVaLaCorrida.parando;
    }
    if (corrida.parada != null) return ComoVaLaCorrida.parada;
    if (corrida.estado == EstadoDeCorrida.arrancando) {
      return ComoVaLaCorrida.arrancando;
    }
    if (corrida.errores > 0) return ComoVaLaCorrida.conErrores;
    return ComoVaLaCorrida.corriendo;
  }

  /// Las acciones que tienen sentido ahora, **la que toca primero**.
  ///
  /// Solo las que pueden funcionar, como antes: sin `app.started` no hay a
  /// quién recargar, parada no se recarga —primero hay que soltarla— y los pasos
  /// del depurador solo existen con la app detenida. Lo que cambia es el orden,
  /// que ahora sigue al estado en vez de ser siempre el mismo.
  static List<AccionDeCorrida> acciones(Corrida corrida) {
    final como = de(corrida);
    final parada = corrida.parada != null;
    final recarga = corrida.puedeRecargar && !parada;

    final primero = <AccionDeCorrida>[
      if (parada) ...[
        AccionDeCorrida.seguir,
        AccionDeCorrida.siguienteLinea,
        AccionDeCorrida.entrar,
        AccionDeCorrida.salir,
      ],
      // Con errores se lleva el error a quien lo puede arreglar, y se lee
      // justo al lado: por eso el registro sube con él.
      if (corrida.errores > 0 && como != ComoVaLaCorrida.parando) ...[
        AccionDeCorrida.pasarleElError,
        AccionDeCorrida.registro,
        AccionDeCorrida.registroDelSistema,
      ],
    ];

    final resto = <AccionDeCorrida>[
      if (recarga) ...[AccionDeCorrida.recargar, AccionDeCorrida.reiniciar],
      if (corrida.consola != null) AccionDeCorrida.consola,
      if (corrida.sePuedeFrenar && !parada) AccionDeCorrida.freno,
      AccionDeCorrida.registro,
      AccionDeCorrida.registroDelSistema,
      if (como != ComoVaLaCorrida.parando) AccionDeCorrida.parar,
    ];

    return [
      ...primero,
      for (final accion in resto)
        if (!primero.contains(accion)) accion,
    ];
  }
}
