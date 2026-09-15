import 'dart:async';

/// Cuándo se acaba de leer lo que dice un proceso.
///
/// 🔴 **Que el proceso muera no cierra su salida, y por ahí se colgaba un turno
/// entero.** Reportado como «envié un mensaje y se quedó pegado ahí»: el chat
/// alcanzó a escribir una frase, el orbe siguió girando para siempre y en la
/// máquina no había **ni un solo `claude` vivo**. Ni error, ni «el turno se
/// cortó», ni nada archivado —el registro se escribe al terminar el turno, y
/// ese turno no terminaba nunca—.
///
/// La pipa de salida no se cierra cuando muere quien la abrió: se cierra cuando
/// la suelta **el último** que la tiene. Y `claude` reparte la suya entre sus
/// servidores MCP, que son nietos nuestros y le sobreviven —medido al limpiar:
/// 52 procesos se llevaron 195 hijos—. Muerto el padre, los nietos quedan
/// huérfanos sujetando la pipa, y quien lee espera a que hable un proceso que
/// ya no existe.
///
/// Medido aparte, sin Claude de por medio:
///
/// ```
/// [14 ms] línea: hola
/// [17 ms] el proceso salió con 0
/// cinco segundos después de morir el proceso · stdout cerrado: false
/// ```
///
/// Por eso el final lo marca **el proceso**, no la pipa.
abstract final class ElFinalDeLaSalida {
  /// Lo que se espera después de que el proceso muera antes de dar por cerrada
  /// la salida.
  ///
  /// No es cero a propósito: lo que el proceso escribió justo antes de morir
  /// sigue en la pipa y llega un instante después. Cerrar en seco se comería
  /// justo la última línea, que es la que importa —el `result` de un turno, el
  /// veredicto de un gate—. Es el mismo motivo por el que un trabajo aparte
  /// termina de leer antes de contar que acabó.
  static const gracia = Duration(seconds: 2);

  /// [lineas] hasta que se cierren solas o hasta que [elProcesoSeFue], lo que
  /// pase antes.
  ///
  /// **Cada línea que llegue reinicia la gracia**: mientras siga saliendo algo
  /// de la pipa, hay cola que entregar y no se cierra a mitad.
  static Stream<String> cuandoMuera(
    Stream<String> lineas,
    Future<void> elProcesoSeFue, {
    Duration gracia = ElFinalDeLaSalida.gracia,
  }) {
    final salida = StreamController<String>();
    late final StreamSubscription<String> oyendo;
    Timer? cierre;
    var cerrado = false;

    Future<void> cerrar() async {
      if (cerrado) return;
      cerrado = true;
      cierre?.cancel();
      cierre = null;
      await oyendo.cancel();
      if (!salida.isClosed) await salida.close();
    }

    oyendo = lineas.listen(
      (linea) {
        if (cerrado) return;
        salida.add(linea);
        // Solo cuenta si el proceso ya murió: mientras vive, no hay prisa.
        if (cierre != null) {
          cierre?.cancel();
          cierre = Timer(gracia, cerrar);
        }
      },
      onError: salida.addError,
      onDone: cerrar,
    );

    unawaited(
      elProcesoSeFue.then((_) {
        if (cerrado) return;
        cierre = Timer(gracia, cerrar);
      }),
    );

    // Y si quien lee se va —se canceló el encargo, se cerró la conversación—,
    // se suelta la pipa igual: el nieto que la sujeta no es motivo para
    // quedarse escuchando.
    salida.onCancel = cerrar;

    return salida.stream;
  }
}
