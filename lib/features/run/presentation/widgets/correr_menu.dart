import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/emulators/domain/entities/emulador.dart';
import 'package:nexus/features/emulators/presentation/providers/emuladores_providers.dart';
import 'package:nexus/features/run/domain/entities/config_de_arranque.dart';
import 'package:nexus/features/run/domain/usecases/la_config_de_casa.dart';
import 'package:nexus/features/run/domain/entities/corrida.dart';
import 'package:nexus/features/run/domain/usecases/lector_de_configs.dart';
import 'package:nexus/features/run/presentation/providers/corridas_providers.dart';
import 'package:nexus/features/run/presentation/providers/run_providers.dart';

/// Correr la app: elegir entorno y dispositivo, y gobernarla.
///
/// **En el compositor y no en Ajustes**, por lo mismo que los dispositivos: una
/// app corriendo es estado vivo, no configuración. Y aquí es donde se mira
/// mientras se trabaja.
///
/// El icono cambia de significado según lo que haya: sin nada corriendo es
/// «correr», y con algo corriendo es «esto está pasando» — con su punto, como el
/// de los dispositivos.
class CorrerMenu extends ConsumerWidget {
  const CorrerMenu({super.key, required this.proyecto});

  /// La carpeta de trabajo de esta conversación. `null` si no hay proyecto.
  ///
  /// Las configuraciones son **de este proyecto**: van por aquí y no por una
  /// lista global, porque la de un repo no significa nada en otro.
  final String? proyecto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final corridas = ref.watch(corridasProvider);
    final mia = proyecto == null
        ? <Corrida>[]
        : corridas.values.where((c) => c.proyecto == proyecto).toList();

    return PopupMenuButton<void>(
      color: colors.deep,
      tooltip: '',
      // **Sin esto el panel no puede pasar de 280 px.** Es el
      // `_kMenuMaxWidth` de Material —cinco pasos de 56— y recorta en silencio
      // lo que se le pida: un `SizedBox` de 620 se quedaba en 280 y salía un
      // desplegable con «Global66…» y otro con «E». Y explica los desbordes de 9
      // y 71 px de antes: eran contra 280, no contra el ancho que yo creía.
      constraints: const BoxConstraints(minWidth: 620, maxWidth: 620),
      onOpened: () {
        if (proyecto case final p?) ref.invalidate(configsProvider(p));
        ref.invalidate(emuladoresProvider);
        ref.invalidate(dispositivosProvider);
      },
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          enabled: false,
          // Relleno propio en vez del de fábrica: el del `PopupMenuItem` son 16
          // a cada lado que no se descuentan del ancho que se le pide, y el panel
          // desbordaba por menos de un píxel — suficiente para pintar la franja
          // amarilla de aviso encima de la barra.
          padding: const EdgeInsets.symmetric(
            horizontal: NexusSpacing.s3,
            vertical: NexusSpacing.s2,
          ),
          child: SizedBox(
            // **Ancho y bajo, no cuadrado.** Con las opciones a la vista, los
            // nombres de configuración son largos —«Global66 (ci + mock PayIn
            // Colombia)»— y a 620 caben dos o tres por línea: el panel crece
            // hacia abajo lo justo en vez de volverse una columna.
            width: 620,
            child: _Panel(proyecto: proyecto),
          ),
        ),
      ],
      child: Semantics(
        label: strings.runTitle,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.play_arrow_rounded,
                size: 17,
                color: mia.isEmpty ? colors.faint : colors.accent,
              ),
            ),
            if (mia.isNotEmpty)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.void_, width: 1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends ConsumerStatefulWidget {
  const _Panel({required this.proyecto});

  final String? proyecto;

  @override
  ConsumerState<_Panel> createState() => _PanelState();
}

class _PanelState extends ConsumerState<_Panel> {
  String? _config;
  String? _dispositivo;
  var _ocupado = false;
  String? _error;

  /// El nombre del emulador apagado que se está arrancando porque se eligió.
  String? _arrancando;

  Future<void> _correr() async {
    final proyecto = widget.proyecto;
    final configs = ref.read(configsProvider(proyecto ?? '')).value ?? const [];
    final nombre = _elegida(configs);
    final deviceId = _dispositivo;
    if (proyecto == null || nombre == null || deviceId == null) return;

    final elegida = configs.where((c) => c.nombre == nombre).firstOrNull;
    if (elegida == null) return;

    final (:dispositivo, :plataforma) = _datosDelDispositivo(deviceId);
    if (plataforma == null) return;

    setState(() {
      _ocupado = true;
      _error = null;
    });
    final error = await ref
        .read(corridasProvider.notifier)
        .correr(
          proyecto: proyecto,
          configuracion: nombre,
          args: LectorDeConfigs.argumentos(elegida, proyecto: proyecto),
          deviceId: deviceId,
          dispositivo: dispositivo,
          plataforma: plataforma,
        );
    if (!mounted) return;
    setState(() {
      _ocupado = false;
      _error = error;
    });
    // 🔴 **Arrancó: fuera de en medio.** El panel es una barra de elegir, y una
    // vez elegido no queda nada que mirar aquí — lo que pasa a partir de ahora
    // lo cuenta la botonera flotante, que además no tapa la conversación.
    //
    // Solo si arrancó. Un fallo —«ya está corriendo en ese dispositivo», «no se
    // encontró Flutter»— se lee aquí abajo, y cerrar lo dejaría sin sitio donde
    // decirse.
    if (error == null) Navigator.of(context).pop();
  }

  /// De dónde sale el nombre y la plataforma de un dispositivo elegido.
  ///
  /// De las dos listas que ya existen: los emuladores arrancados y los teléfonos
  /// enchufados. No hay una tercera fuente porque no debe haberla — sería otra
  /// verdad que mantener.
  ({String dispositivo, PlataformaEmulador? plataforma}) _datosDelDispositivo(
    String deviceId,
  ) {
    for (final e
        in ref.read(emuladoresProvider).value?.emuladores ?? const []) {
      if (e.deviceId == deviceId) {
        return (dispositivo: e.nombre, plataforma: e.plataforma);
      }
    }
    for (final d in ref.read(dispositivosProvider).value ?? const []) {
      if (d.id == deviceId) {
        return (dispositivo: d.nombre, plataforma: d.plataforma);
      }
    }
    return (dispositivo: deviceId, plataforma: null);
  }

  /// Cuál va puesta: lo elegido en esta sesión, o lo recordado de este proyecto.
  String? _elegida(List<ConfigDeArranque> configs) {
    final nombres = {for (final c in configs) c.nombre};
    if (_config case final elegido? when nombres.contains(elegido)) {
      return elegido;
    }
    final recordado = ref.watch(
      configsPorDefectoProvider,
    )[widget.proyecto ?? ''];
    return recordado != null && nombres.contains(recordado) ? recordado : null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final proyecto = widget.proyecto;

    if (proyecto == null) {
      return Text(
        strings.runNoProject,
        style: NexusTypography.nota.copyWith(color: colors.faint),
      );
    }

    final configs = ref.watch(configsProvider(proyecto)).value ?? const [];
    final dispositivos = _losDispositivos();
    final elegida = _elegida(configs);
    // El elegido tiene que seguir estando: un emulador que se cerró por fuera
    // no puede quedar marcado y encender «Correr» hacia un `-d` que ya no existe.
    final dispositivo =
        dispositivos.destinos.any((d) => d.id == _dispositivo && d.id != null)
        ? _dispositivo
        : null;

    // **El motivo, antes que el botón.** «Correr» apagado sin decir por qué deja
    // mirándolo; esto dice qué falta, en el orden en que se elige.
    final falta = elegida == null
        ? strings.runEligeConfig
        : dispositivos.buscando
        ? strings.runSearchingDevices
        : dispositivos.destinos.isEmpty
        ? strings.runNoDevices
        : dispositivo == null
        ? strings.runChooseDevice
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // De qué repo: las configuraciones son de este proyecto y de ningún
        // otro, y el panel se abre desde una conversación que puede tener otro
        // nombre en la cabeza.
        Text(
          '${strings.runTitle} · ${proyecto.split('/').last}',
          style: NexusTypography.label.copyWith(color: colors.mute),
        ),
        const SizedBox(height: NexusSpacing.s3),

        if (configs.isEmpty)
          Text(
            strings.runNoConfigs,
            style: NexusTypography.nota.copyWith(color: colors.faint),
          )
        else ...[
          // 🔴 **Opciones a la vista y no desplegables.** Con los dos
          // desplegables había que abrirlos para saber qué había: qué
          // configuraciones trae el repo y, sobre todo, qué dispositivo está
          // encendido. El mockup los pone a la vista, y así se ve qué hay antes
          // de elegir.
          _Rotulo(strings.runConfiguracion),
          Wrap(
            spacing: NexusSpacing.s2,
            runSpacing: NexusSpacing.s2,
            children: [
              for (final config in configs)
                Opcion(
                  key: ValueKey('config-${config.nombre}'),
                  titulo: config.nombre,
                  // La tuya se distingue de las del repo: vive en Nexus, y
                  // borrarla no toca el `launch.json`.
                  detalle: config.local ? strings.runEsTuyaCorto : null,
                  // **La recordada, si sigue existiendo.** Se guarda el nombre
                  // y no un índice: los índices bailan al añadir una
                  // configuración al `launch.json`, y ese día estarías corriendo
                  // otro entorno sin enterarte.
                  elegida: config.nombre == elegida,
                  onPulsar: () {
                    setState(() => _config = config.nombre);
                    ref
                        .read(configsPorDefectoProvider.notifier)
                        .elegir(proyecto, config.nombre);
                  },
                ),
            ],
          ),
          const SizedBox(height: NexusSpacing.s3),

          _Rotulo(strings.runDispositivo),
          if (dispositivos.buscando && dispositivos.destinos.isEmpty)
            // Buscando no es lo mismo que no haber: los dos estados iban
            // aplanados a uno y el panel parecía colgado. Ver [_losDispositivos].
            Row(
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: colors.accent,
                  ),
                ),
                const SizedBox(width: NexusSpacing.s2),
                Text(
                  strings.runSearchingDevices,
                  style: NexusTypography.nota.copyWith(color: colors.mute),
                ),
              ],
            )
          else if (dispositivos.destinos.isEmpty)
            Text(
              strings.runNoDevices,
              style: NexusTypography.nota.copyWith(color: colors.mute),
            )
          else
            Wrap(
              spacing: NexusSpacing.s2,
              runSpacing: NexusSpacing.s2,
              children: [
                for (final destino in dispositivos.destinos)
                  Opcion(
                    key: ValueKey('destino-${destino.id ?? destino.nombre}'),
                    titulo: destino.nombre,
                    detalle: destino.detalle,
                    elegida: destino.id != null && destino.id == dispositivo,
                    // 🔴 **El apagado se ofrece, atenuado, y elegirlo lo
                    // arranca.** Antes no aparecía para no ofrecer un
                    // `flutter run -d` que iba a fallar, y eso obligaba a ir al
                    // panel de dispositivos a encenderlo primero. Ahora el paso
                    // lo da Nexus, y el `-d` no se usa hasta que está arriba.
                    atenuada: destino.apagado != null,
                    onPulsar: _ocupado || _arrancando != null
                        ? null
                        : _alElegir(destino),
                  ),
              ],
            ),
          if (_arrancando case final nombre?)
            Padding(
              padding: const EdgeInsets.only(top: NexusSpacing.s2),
              child: Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: colors.accent,
                    ),
                  ),
                  const SizedBox(width: NexusSpacing.s2),
                  Expanded(
                    child: Text(
                      strings.runArrancando(nombre),
                      style: NexusTypography.nota.copyWith(color: colors.mute),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: NexusSpacing.s4),

          Row(
            children: [
              if (_ocupado)
                Padding(
                  padding: const EdgeInsets.only(right: NexusSpacing.s3),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: colors.accent,
                    ),
                  ),
                )
              else
                BotonDeFila(
                  key: const ValueKey('correr'),
                  texto: strings.runStart,
                  tono: TonoDeBoton.principal,
                  onPulsar: falta == null ? _correr : null,
                ),
              const SizedBox(width: NexusSpacing.s2),
              // 🔴 **La copia con el panel de depuración, sin tocar el repo.**
              // Pedida con un caso: el repo del trabajo trae «ci + Debug
              // Dashboard» y no la misma con `prod` ni la de `profile`. Añadirla
              // al `launch.json` es tocar un archivo versionado y compartido — y
              // en un repo del trabajo, la regla es no comitear nada. Ver
              // [LaConfigDeCasa], donde está de dónde se aprenden los defines.
              if (_laElegida(configs) case final config?)
                if (config.local)
                  BotonDeFila(
                    texto: strings.runQuitarCopia,
                    onPulsar: _ocupado ? null : () => _quitarLaCopia(config),
                  )
                else if (LaConfigDeCasa.sePuedeDuplicar(config))
                  BotonDeFila(
                    texto: strings.runDuplicarConConsola,
                    onPulsar: _ocupado
                        ? null
                        : () => _duplicarConLaConsola(config, configs),
                  ),
              const SizedBox(width: NexusSpacing.s3),
              // El motivo al lado del botón apagado, no en su tooltip: un
              // tooltip solo lo lee quien ya sospecha que hay algo que leer.
              if (falta != null && !_ocupado)
                Expanded(
                  child: Text(
                    falta,
                    key: const ValueKey('lo-que-falta'),
                    style: NexusTypography.nota.copyWith(
                      color: colors.mute,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),

          if (_laElegida(configs) case final config?)
            Padding(
              padding: const EdgeInsets.only(top: NexusSpacing.s2),
              child: Text(
                config.local
                    ? strings.runEsTuya
                    : LaConfigDeCasa.sePuedeDuplicar(config)
                    ? strings.runDuplicarNota
                    : strings.runYaTraeConsola,
                style: NexusTypography.nota.copyWith(
                  color: colors.mute,
                  fontSize: 12,
                ),
              ),
            ),
        ],

        if (_error case final mensaje?) ...[
          const SizedBox(height: NexusSpacing.s3),
          Text(
            mensaje,
            style: NexusTypography.mono.copyWith(color: colors.err),
          ),
        ],
      ],
    );
  }

  /// La configuración elegida, entera y no solo su nombre: hace falta saber si
  /// es tuya y qué argumentos lleva.
  ConfigDeArranque? _laElegida(List<ConfigDeArranque> configs) {
    final nombre = _elegida(configs);
    if (nombre == null) return null;
    for (final config in configs) {
      if (config.nombre == nombre) return config;
    }
    return null;
  }

  /// Duplica la elegida con la consola encendida y **la deja elegida**: quien
  /// pulsa esto quiere correr esa, no volver a buscarla en el desplegable.
  Future<void> _duplicarConLaConsola(
    ConfigDeArranque elegida,
    List<ConfigDeArranque> configs,
  ) async {
    final proyecto = widget.proyecto;
    if (proyecto == null) return;
    final copia = LaConfigDeCasa.conLaConsola(
      elegida,
      // De la del propio repo que ya la enciende: los defines que hacen falta
      // los sabe el repo, no Nexus.
      modelo: LaConfigDeCasa.laQueEnciendeLaConsola(configs),
    );
    setState(() => _ocupado = true);
    final ok = await ref.read(lasConfigsDeCasaProvider).anadir(proyecto, copia);
    if (!mounted) return;
    ref.invalidate(configsProvider(proyecto));
    setState(() {
      _ocupado = false;
      _error = ok ? null : context.strings.runCopiaFallo;
      if (ok) _config = copia.nombre;
    });
    if (ok) {
      ref
          .read(configsPorDefectoProvider.notifier)
          .elegir(proyecto, copia.nombre);
    }
  }

  Future<void> _quitarLaCopia(ConfigDeArranque cual) async {
    final proyecto = widget.proyecto;
    if (proyecto == null) return;
    setState(() => _ocupado = true);
    await ref.read(lasConfigsDeCasaProvider).quitar(proyecto, cual.nombre);
    if (!mounted) return;
    ref.invalidate(configsProvider(proyecto));
    setState(() {
      _ocupado = false;
      _config = null;
    });
    ref.read(configsPorDefectoProvider.notifier).olvidar(proyecto);
  }

  /// Qué hace elegir un destino: marcarlo, o arrancarlo si está apagado.
  VoidCallback _alElegir(_Destino destino) {
    final apagado = destino.apagado;
    if (apagado != null) return () => _arrancarYElegir(apagado);
    return () => setState(() => _dispositivo = destino.id);
  }

  /// Arranca un emulador apagado y, cuando está arriba, lo deja elegido.
  ///
  /// **Espera a que exista**, que el comando vuelve antes que el aparato: eso
  /// ya lo sabe hacer el `lanzar` de los emuladores, y correr contra un `-d`
  /// que todavía no aparece es el fallo que había que evitar ofreciéndolo.
  Future<void> _arrancarYElegir(Emulador emulador) async {
    setState(() {
      _arrancando = emulador.nombre;
      _error = null;
    });
    final error = await ref.read(emuladoresDataSourceProvider).lanzar(emulador);
    ref.invalidate(emuladoresProvider);
    String? arriba;
    try {
      final lista = await ref.read(emuladoresProvider.future);
      for (final e in lista.emuladores) {
        if (e.id == emulador.id && e.corriendo) arriba = e.deviceId;
      }
    } on Exception {
      // El propio provider cuenta el fallo; aquí solo importaba no elegir mal.
    }
    if (!mounted) return;
    setState(() {
      _arrancando = null;
      _error = error;
      if (arriba != null) _dispositivo = arriba;
    });
  }

  /// Lo que hay para correr: emuladores arrancados, teléfonos enchufados y,
  /// al final, los emuladores apagados —que elegirlos los arranca—.
  ///
  /// Y **si todavía se están buscando**, que es la mitad que faltaba.
  ///
  /// 🔴 Los dos estados iban aplanados a uno con un `?? const []`, así que
  /// «todavía no sé» y «no hay ninguno» se pintaban igual. Reportado mirando la
  /// pantalla —«parece que se quedó pegada la interfaz»— y no lo parecía:
  /// estaba buscando.
  ///
  /// Se mira `isLoading` **junto con** `hasValue` a propósito: al refrescar ya
  /// hay una respuesta anterior que enseñar, y vaciarla para volver a llenarla
  /// sería parpadear por nada.
  ///
  /// **El nombre delante y el id en el detalle**: un id no dice cuál es cuál,
  /// pero es lo que pide `-d` y a veces hay dos aparatos con el mismo nombre.
  ({bool buscando, List<_Destino> destinos}) _losDispositivos() {
    final strings = context.strings;
    final emuladores = ref.watch(emuladoresProvider);
    final conectados = ref.watch(dispositivosProvider);
    final todos = emuladores.value?.emuladores ?? const <Emulador>[];

    return (
      buscando:
          (emuladores.isLoading && !emuladores.hasValue) ||
          (conectados.isLoading && !conectados.hasValue),
      destinos: [
        for (final e in todos)
          if (e.corriendo && e.deviceId != null)
            _Destino(
              id: e.deviceId,
              nombre: e.nombre,
              detalle:
                  '${e.plataforma == PlataformaEmulador.ios ? strings.runSimulador : strings.runEmulador} · ${e.deviceId}',
            ),
        for (final d in conectados.value ?? const <DispositivoConectado>[])
          _Destino(
            id: d.id,
            nombre: d.nombre,
            detalle: '${strings.runEnchufado} · ${d.id}',
          ),
        for (final e in todos)
          if (!e.corriendo)
            _Destino(nombre: e.nombre, detalle: strings.runApagado, apagado: e),
      ],
    );
  }
}

/// Un sitio donde correr, con lo que lo distingue.
class _Destino {
  const _Destino({
    required this.nombre,
    required this.detalle,
    this.id,
    this.apagado,
  });

  /// Lo que se le pasa a `-d`. Nulo mientras está apagado: todavía no existe.
  final String? id;
  final String nombre;
  final String detalle;

  /// El emulador que hay que arrancar para poder usarlo, si está apagado.
  final Emulador? apagado;
}

/// El rótulo de un grupo de opciones: «Configuración», «Dispositivo».
class _Rotulo extends StatelessWidget {
  const _Rotulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: NexusSpacing.s2),
    child: Text(
      texto,
      style: NexusTypography.label.copyWith(color: context.colors.faint),
    ),
  );
}
