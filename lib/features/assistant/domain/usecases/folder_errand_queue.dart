import 'dart:async';

/// Un encargo a la vez por carpeta.
///
/// Existe por una medición, no por prudencia: dos conversaciones sobre la misma
/// carpeta comparten la sesión de Claude —esa es la regla del producto— y
/// lanzar las dos a la vez **pierde una**. Medido contra el binario: dos
/// `--resume` simultáneos sobre la misma sesión responden bien los dos, pero al
/// preguntar después qué se había dicho, solo constaba el último. El turno del
/// otro había desaparecido del historial.
///
/// Serializar es la salida barata y la correcta: se conserva la regla —misma
/// carpeta, mismo contexto— y lo único que cambia es que el segundo espera. La
/// alternativa sería darle sesión propia a cada conversación, que es justo el
/// contexto compartido que se pidió.
///
/// Carpetas distintas no se estorban: cada una tiene su cola.
///
/// ## Por qué el turno se pide y no se espera
///
/// 🔴 **Quien se iba mientras esperaba dejaba la carpeta tomada para siempre.**
/// Reportado así: «tenía 2 conversaciones sobre la misma carpeta, pero le di
/// empezar de 0 porque me salía que tenía que esperar a que terminara el
/// trabajo de una conversación para arrancar el de la otra».
///
/// Antes esto era un `Future<void Function()> acquire(...)`: el sitio en la
/// cola se apuntaba al entrar y **la forma de soltarlo solo llegaba al final de
/// la espera**. Cancelar el encargo mientras esperaba —cerrar la conversación,
/// detenerla, empezar de cero, mandar un `/imagen`— abandonaba ese `await` para
/// siempre, así que nadie soltaba nada. Medido:
///
/// ```
/// ¿ocupada después de que A soltó y B se fue? → true
/// ¿entró el siguiente? → false
/// ```
///
/// La carpeta quedaba bloqueada para **todas** las conversaciones hasta
/// reiniciar la app, y encima lo que se hace al verlo —empezar de cero— es
/// justo lo que lo provoca.
///
/// Ahora el turno se pide y se entrega **en el mismo instante** la forma de
/// soltarlo. Quien lo pide puede ponerla en un `finally` antes de esperar nada,
/// que es lo único que sobrevive a una cancelación.
///
/// ## Y quién lo tiene, no solo si está ocupado
///
/// Porque no es lo mismo esperar a **otra** conversación que a la tuya: la
/// compresión de un chat corre por aquí igual que un encargo, así que «la
/// carpeta está ocupada» puede significar «te estás comprimiendo tú». Lo
/// primero se resuelve trabajando en paralelo con un hilo propio; lo segundo
/// solo se puede esperar, porque es el mismo hilo.
class FolderErrandQueue {
  FolderErrandQueue();

  /// Quién está en la fila de cada carpeta, en orden de llegada.
  final _fila = <String, List<_Puesto>>{};

  /// Pide el turno para [folder]. [de] es la conversación que lo pide.
  ///
  /// - `hayQueEsperar` dice si alguien está delante, para poder contarlo: una
  ///   espera sin explicación se ve igual que un cuelgue.
  /// - `laTieneOtra` dice si quien está delante es **otra** conversación. Es lo
  ///   que separa «trabajad en paralelo» de «espera a que acabes tú».
  /// - `cuandoToque` completa cuando le toca.
  /// - `soltar` lo suelta, y hay que llamarlo **siempre**: al terminar, al
  ///   fallar, y también si te vas antes de que te toque. Llamarlo dos veces no
  ///   hace nada.
  ({
    bool hayQueEsperar,
    bool laTieneOtra,
    bool hayQueEsperarLoTuyo,
    Future<void> cuandoToque,
    Future<void> cuandoToqueLoTuyo,
    void Function() soltar,
  })
  pedirTurno(String folder, {String? de}) {
    final puestos = _fila.putIfAbsent(folder, () => []);
    final delante = [
      for (final puesto in puestos)
        if (!puesto.soltado) puesto,
    ];
    final mio = _Puesto(de);
    puestos.add(mio);

    void soltar() {
      if (mio.soltado) return;
      mio.soltado = true;
      // Completar es lo que deja pasar al siguiente, y por eso vale igual
      // soltando a mitad de la espera: el de detrás no tiene por qué esperar a
      // un turno que su dueño ya abandonó.
      if (!mio.suTurno.isCompleted) mio.suTurno.complete();
      // El último apaga la luz: si no, este mapa acumula una entrada por cada
      // carpeta que se haya usado en la vida de la app.
      if (puestos.every((puesto) => puesto.soltado)) _fila.remove(folder);
    }

    final mios = [
      for (final puesto in delante)
        if (puesto.de == de) puesto,
    ];

    return (
      hayQueEsperar: delante.isNotEmpty,
      laTieneOtra: delante.any((puesto) => puesto.de != de),
      hayQueEsperarLoTuyo: mios.isNotEmpty,
      // A **todos** los que están delante, no solo al último: uno que se va a
      // mitad de la espera no puede adelantar a los de detrás, o entrarían con
      // el primero todavía dentro — dos encargos a la vez sobre la misma
      // sesión, que es justo lo que esta cola existe para impedir.
      //
      // Y se espera pase lo que pase con ellos: si el encargo de la otra
      // conversación revienta, el siguiente tiene que entrar igual.
      cuandoToque: Future.wait([
        for (final puesto in delante) puesto.suTurno.future,
      ]),
      // 🔴 **Solo los tuyos, para quien ya trabaja en su propio hilo.**
      // Bifurcarse libra de esperar a las demás conversaciones —el hilo es
      // suyo y no se lo pisa nadie— pero **no de esperarse a sí misma**: ese
      // hilo sigue siendo uno, y dos `--resume` a la vez sobre él pierden un
      // turno. Está medido arriba, y se pagó: la compresión de una carpeta
      // corrió a la vez que el mensaje siguiente del usuario y **el resultado
      // de la compresión fue el que se perdió** — nueve veces seguidas sin que
      // el contexto bajara, con la app diciendo que estaba comprimiendo.
      cuandoToqueLoTuyo: Future.wait([
        for (final puesto in mios) puesto.suTurno.future,
      ]),
      soltar: soltar,
    );
  }

  /// Si hay alguien trabajando —o esperando para hacerlo— en esa carpeta.
  /// Sirve para poder decirlo en pantalla y para las pruebas: dentro de un
  /// encargo, lo que dice si había cola es `hayQueEsperar`, que se contesta sin
  /// carreras.
  bool isBusy(String folder) => _fila.containsKey(folder);
}

/// Un sitio en la fila de una carpeta: de quién es y si ya lo soltó.
class _Puesto {
  _Puesto(this.de);

  /// La conversación que lo pidió. `null` cuando quien lo pide no dice cuál es
  /// —la agenda, una prueba—, y entonces cuenta como una más.
  final String? de;

  final suTurno = Completer<void>();
  var soltado = false;
}
