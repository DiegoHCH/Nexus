/// Las dos partes del primer arranque.
///
/// 🔴 **Dos y no una lista de siete**, porque piden cosas de distinta clase. La
/// primera es lo que hace falta para **trabajar** —oírte, dónde, con qué cuenta,
/// con qué voz—; la segunda es **quién es ella** —cómo se llama, cómo te llama,
/// cómo habla—. Juntas eran una pantalla que había que desplazar tres veces, y
/// lo único obligatorio —la carpeta— quedaba enterrado entre nombres y una caja
/// de texto de ocho líneas.
enum EtapaDelArranque {
  /// Lo que hace falta para que haga su trabajo.
  trabajar,

  /// Quién es: su nombre, el tuyo y su personalidad.
  ella,
}

/// Lo que se pide en el primer arranque, **en orden**.
///
/// 🔴 **El orden es información, por eso está aquí y no en la pantalla.** El
/// micrófono va antes que la llave porque sin él la llave no sirve de nada —la
/// voz es oír y contestar, y la llave solo paga lo segundo—; la carpeta va
/// antes que la cuenta porque **la cuenta es de la carpeta** —se elige por
/// carpeta, en Ajustes › Permisos—, y sin carpeta no hay de quién ser. Y su
/// nombre va antes que el tuyo porque es también la palabra que la despierta.
enum QueSePide {
  /// Para que te oiga. Opcional: la voz está apagada en toda carpeta hasta que
  /// alguien la encienda.
  microfono(EtapaDelArranque.trabajar),

  /// Dónde trabaja. **La única obligatoria**: sin ella `claude -p` hereda el
  /// directorio de la app —`/` para un bundle lanzado por launchd— y el primer
  /// encargo respondería sobre la raíz del disco.
  carpeta(EtapaDelArranque.trabajar, opcional: false),

  /// Con qué cuenta de Claude trabaja esa carpeta. Solo existe con dos cuentas
  /// o más en la máquina: con una, no hay nada que elegir.
  cuenta(EtapaDelArranque.trabajar),

  /// Para darle voz. Opcional: sin llave se trabaja por texto.
  llave(EtapaDelArranque.trabajar),

  /// Cómo se llama quien contesta, que es también **cómo se la despierta**.
  suNombre(EtapaDelArranque.ella),

  /// Cómo te llama a ti.
  tuNombre(EtapaDelArranque.ella),

  /// Cómo habla: `personalidad.md`, con la de la casa como plantilla.
  personalidad(EtapaDelArranque.ella);

  const QueSePide(this.etapa, {this.opcional = true});

  final EtapaDelArranque etapa;

  /// Si se puede dejar para luego. Todo menos la carpeta.
  final bool opcional;
}

/// Cómo está la app ahora mismo, leído de donde vive cada cosa.
///
/// Es el dato del que sale **qué falta**: el arranque pide solo lo que aquí
/// sale en falso, y lo que ya estaba —una llave en el llavero de una
/// instalación anterior, un nombre ya puesto— no se vuelve a pedir.
///
/// Todo por defecto en «no está», que es lo que tiene una instalación nueva: si
/// algo no se pudo leer, se pregunta —y preguntar de más se arregla saltando el
/// paso—, en vez de dar por hecho algo que falta.
class ComoEstaLaConfiguracion {
  const ComoEstaLaConfiguracion({
    this.microfonoConcedido = false,
    this.hayCarpeta = false,
    this.cuentasDeClaude = 0,
    this.cuentaElegida = false,
    this.hayLlave = false,
    this.haySuNombre = false,
    this.hayTuNombre = false,
    this.hayPersonalidad = false,
  });

  /// Solo se sabe en la sesión que lo pidió: preguntarlo al sistema **es**
  /// pedirlo, con su diálogo. Ver [LoQueFaltaPorConfigurar.enAjustes].
  final bool microfonoConcedido;
  final bool hayCarpeta;

  /// Cuántas cuentas de Claude hay en esta máquina.
  final int cuentasDeClaude;

  /// Si la carpeta tiene una cuenta elegida —o se eligió la de siempre a
  /// sabiendas en este arranque—.
  final bool cuentaElegida;
  final bool hayLlave;
  final bool haySuNombre;
  final bool hayTuNombre;

  /// Si hay un `personalidad.md` escrito. Sin él habla con la de la casa.
  final bool hayPersonalidad;

  /// Si ese paso tiene sentido en esta máquina.
  ///
  /// Hoy solo la cuenta puede no tenerlo: con una sola, elegir no es una
  /// elección, y preguntarlo sería un paso de adorno.
  bool aplica(QueSePide que) => switch (que) {
    QueSePide.cuenta => cuentasDeClaude >= 2,
    _ => true,
  };

  /// Si ese paso ya está.
  bool hecho(QueSePide que) => switch (que) {
    QueSePide.microfono => microfonoConcedido,
    QueSePide.carpeta => hayCarpeta,
    QueSePide.cuenta => cuentaElegida,
    QueSePide.llave => hayLlave,
    QueSePide.suNombre => haySuNombre,
    QueSePide.tuNombre => hayTuNombre,
    QueSePide.personalidad => hayPersonalidad,
  };
}

/// Un paso del arranque, con su número y cómo está.
class PasoDelArranque {
  const PasoDelArranque({
    required this.numero,
    required this.que,
    required this.hecho,
    this.saltado = false,
  });

  /// Desde 1 dentro de su parte, que es como se lee.
  final int numero;
  final QueSePide que;

  /// Hecho: se marca y **no se vuelve a pedir**.
  final bool hecho;

  /// Dejado para luego: no cuenta para entrar, y Ajustes lo recuerda.
  final bool saltado;

  bool get opcional => que.opcional;
}

/// Los pasos de una parte, **en orden** y numerados.
abstract final class LosPasosDelArranque {
  /// Los pasos de [etapa] que hay que enseñar.
  ///
  /// [solo] es **lo que faltaba al abrir** —ver [LoQueFaltaPorConfigurar]—: un
  /// paso que se completa mientras la pantalla está abierta se queda, marcado en
  /// verde, porque verlo hecho es la confirmación; uno que ya estaba hecho al
  /// llegar no aparece, porque pedirlo sería preguntar lo que ya se sabe.
  static List<PasoDelArranque> de(
    ComoEstaLaConfiguracion como, {
    required EtapaDelArranque etapa,
    required Set<QueSePide> solo,
    Set<QueSePide> saltados = const {},
  }) {
    final pasos = <PasoDelArranque>[];
    for (final que in QueSePide.values) {
      if (que.etapa != etapa || !solo.contains(que) || !como.aplica(que)) {
        continue;
      }
      pasos.add(
        PasoDelArranque(
          numero: pasos.length + 1,
          que: que,
          hecho: como.hecho(que),
          // Lo obligatorio no se salta, se pida como se pida.
          saltado: que.opcional && saltados.contains(que),
        ),
      );
    }
    return pasos;
  }

  /// Si se puede seguir: **los obligatorios hechos**, y nada más.
  static bool sePuedeEntrar(List<PasoDelArranque> pasos) =>
      pasos.every((paso) => paso.opcional || paso.hecho);
}

/// Qué falta por configurar: lo que el arranque pide y lo que Ajustes recuerda.
///
/// 🔴 **Detectar y no suponer.** El arranque pedía siempre lo mismo —micrófono,
/// carpeta, llave— hubiera lo que hubiera: a quien reinstalaba con la llave en
/// el llavero se la volvía a pedir. Ahora se mira qué hay y se pide lo que no.
abstract final class LoQueFaltaPorConfigurar {
  /// Lo que se pide al arrancar: todo lo que aplica y no está.
  static Set<QueSePide> alArrancar(ComoEstaLaConfiguracion como) => {
    for (final que in QueSePide.values)
      if (como.aplica(que) && !como.hecho(que)) que,
  };

  /// Lo que Ajustes ofrece retomar: **lo que se dejó para luego** y sigue sin
  /// estar.
  ///
  /// Solo lo dejado para luego, y no todo lo que falta, porque a quien nunca
  /// pasó por este arranque —o dejó su nombre en blanco a propósito— no hay que
  /// recordarle nada cada vez que abre Ayuda.
  ///
  /// El micrófono no entra nunca: fuera de la sesión que lo pidió no se sabe si
  /// está concedido sin **pedirlo** —el diálogo del sistema—, y un recordatorio
  /// que no puede saber si ya está hecho acaba diciendo algo falso. Lo pide la
  /// propia voz la primera vez que se abre.
  static Set<QueSePide> enAjustes(
    ComoEstaLaConfiguracion como, {
    required Set<QueSePide> paraLuego,
  }) => {
    for (final que in QueSePide.values)
      if (que != QueSePide.microfono &&
          paraLuego.contains(que) &&
          como.aplica(que) &&
          !como.hecho(que))
        que,
  };

  /// Las partes que tienen algo que pedir, en orden.
  static List<EtapaDelArranque> etapas(Set<QueSePide> solo) => [
    for (final etapa in EtapaDelArranque.values)
      if (solo.any((que) => que.etapa == etapa)) etapa,
  ];
}
