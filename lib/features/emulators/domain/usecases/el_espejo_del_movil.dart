/// Ver la pantalla de un móvil de verdad en el escritorio, con scrcpy.
///
/// **Se lanza scrcpy en vez de hacerlo nosotros**, y eso se midió antes de
/// decidirlo: la alternativa sin dependencias es `adb exec-out screencap`, y tarda
/// **~690 ms por fotograma** —628 kB cada uno— o sea 1,4 por segundo. Eso no es un
/// espejo, es un pase de diapositivas. Lo otro sería meter FFmpeg en Nexus para
/// decodificar H.264 y reimplementar peor algo que ya existe.
///
/// Y encaja con cómo Nexus trata a `adb`, `flutter` y `maestro`: un proceso externo
/// con su propia ventana del sistema, que no bloquea la app.
///
/// **Solo para móviles físicos Android.** Un emulador ya tiene su ventana, así que
/// duplicarla no aporta nada; y scrcpy no habla con iOS. Quien pinta el botón se
/// encarga de eso — ver `sePuedeVerLaPantalla`.
abstract final class ElEspejoDelMovil {
  static const binario = 'scrcpy';

  /// Si ya hay un espejo de **este** dispositivo entre los procesos vivos.
  ///
  /// 🔴 Hace falta desde que el espejo se abre solo al correr la app: sin esto,
  /// volver a correr con la ventana anterior todavía abierta deja dos espejos
  /// del mismo teléfono. Y la alternativa —no reabrirlo nunca dentro de la misma
  /// sesión— es peor: cierras la ventana, vuelves a correr y no vuelve.
  ///
  /// Se mira la línea de comandos y no una lista nuestra, porque el espejo
  /// también se abre a mano desde los paneles: una cuenta propia no sabría nada
  /// de esos y volvería a duplicar.
  static bool yaEstaEspejando(String deviceId, Iterable<String> procesos) =>
      procesos.any(
        (linea) => linea.contains(binario) && linea.contains(deviceId),
      );

  /// Con qué se llama a scrcpy.
  ///
  /// Aparte para poder comprobarlo, igual que los de Maestro: lo que importa aquí
  /// no es el proceso, es que [conControl] llegue bien.
  ///
  /// Los flags están comprobados contra scrcpy 3.3.3:
  ///
  /// - `--window-title` con el nombre legible, que un número de serie no dice cuál
  ///   de los dos móviles es.
  /// - `--no-audio` porque aquí no aporta y añade latencia.
  /// - `-m 1024` acota el lado mayor: menos que mandar por el cable, y va más fino.
  /// - `-w` mantiene la pantalla despierta, que si no se apaga a mitad de lo que
  ///   estabas mirando.
  static List<String> argumentos({
    required String deviceId,
    required String titulo,
    required bool conControl,
    bool encima = true,
  }) => [
    '--serial',
    deviceId,
    '--window-title',
    titulo,
    '--no-audio',
    '--max-size',
    '1024',
    '--stay-awake',
    // **Sin control mientras corre una prueba, y esto no es una precaución
    // menor.** Maestro inyecta eventos en el mismo dispositivo: si tocas la
    // pantalla a la vez, los dos estáis peleando por él y el fallo que salga no
    // será real. Se habrá inventado entre los dos.
    if (!conControl) '--no-control',
    // 🔴 **Encima, que es a lo que se abre.** Esto era solo para las pruebas
    // —«fuera de eso, una ventana que se pone encima de todo estorba»— y lo que
    // pasaba de verdad es lo contrario: scrcpy nace **detrás** de Nexus, así que
    // abrías el espejo y no veías nada hasta apartar la app a mano, cada vez.
    // Reportado así: «cuando se abre el espejo del teléfono siempre se abre
    // debajo y debería abrirse arriba de Nexus, como lo hace el dashboard».
    //
    // Es un flag de scrcpy y no traer la ventana al frente desde el sistema
    // porque lo segundo no es lo mismo: activar el proceso exige acertar el
    // instante en que su ventana existe —scrcpy tarda en empujar su servidor al
    // teléfono— y un fallo ahí deja la ventana donde estaba, detrás. Este llega
    // con la ventana.
    if (encima) '--always-on-top',
  ];
}
