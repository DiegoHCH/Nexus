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
class FolderErrandQueue {
  FolderErrandQueue();

  /// El último de la fila de cada carpeta: quien llegue detrás espera a esto.
  final _fila = <String, Future<void>>{};

  /// Cuántos hay dentro o esperando, por carpeta. Es lo que dice si la carpeta
  /// está ocupada —el último de la fila no sirve para eso: puede ser alguien
  /// que se fue sin llegar a entrar—.
  final _cuantos = <String, int>{};

  /// Pide el turno para [folder].
  ///
  /// - `hayQueEsperar` dice si alguien está delante, para poder contarlo: una
  ///   espera sin explicación se ve igual que un cuelgue.
  /// - `cuandoToque` completa cuando le toca.
  /// - `soltar` lo suelta, y hay que llamarlo **siempre**: al terminar, al
  ///   fallar, y también si te vas antes de que te toque. Llamarlo dos veces no
  ///   hace nada.
  ({bool hayQueEsperar, Future<void> cuandoToque, void Function() soltar})
  pedirTurno(String folder) {
    final anterior = _fila[folder];
    final mio = Completer<void>();
    _cuantos[folder] = (_cuantos[folder] ?? 0) + 1;

    // 🔴 **Lo que hereda el siguiente es «cuando acabe el de delante y después
    // yo», no «cuando yo acabe».** Con lo segundo, uno que se va mientras
    // espera adelantaría a los de detrás: soltaría su sitio con el primero
    // todavía dentro, y el tercero entraría a trabajar sobre la misma carpeta
    // al mismo tiempo — que es justo lo que esta cola existe para impedir.
    _fila[folder] = anterior == null
        ? mio.future
        : anterior.then((_) => mio.future);

    var soltado = false;
    void soltar() {
      if (soltado) return;
      soltado = true;
      // Completar es lo que deja pasar al siguiente, y por eso vale igual
      // soltando a mitad de la espera: el de detrás no tiene por qué esperar a
      // un turno que su dueño ya abandonó.
      if (!mio.isCompleted) mio.complete();
      final quedan = (_cuantos[folder] ?? 1) - 1;
      if (quedan > 0) {
        _cuantos[folder] = quedan;
        return;
      }
      // El último apaga la luz: si no, estos mapas acumulan una entrada por
      // cada carpeta que se haya usado en la vida de la app.
      _cuantos.remove(folder);
      _fila.remove(folder);
    }

    return (
      hayQueEsperar: anterior != null,
      // Esperar al anterior, pase lo que pase con él: si el encargo de la otra
      // conversación revienta, el siguiente tiene que entrar igual.
      cuandoToque: anterior ?? Future<void>.value(),
      soltar: soltar,
    );
  }

  /// Si hay alguien trabajando —o esperando para hacerlo— en esa carpeta.
  /// Sirve para poder decirlo en pantalla y para las pruebas: dentro de un
  /// encargo, lo que dice si había cola es `hayQueEsperar`, que se contesta sin
  /// carreras.
  bool isBusy(String folder) => _cuantos.containsKey(folder);
}
