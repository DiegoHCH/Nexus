import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/emulators/domain/entities/emulador.dart';
import 'package:nexus/features/emulators/domain/usecases/el_espejo_del_iphone.dart';
import 'package:nexus/features/emulators/presentation/providers/emuladores_providers.dart';

/// La lista de dispositivos con sus botones, para el sitio que sea.
///
/// **Un solo widget para las dos superficies** —la sección de Ajustes y el menú
/// del compositor— y no dos copias parecidas. No es aseo: los dos sitios enseñan
/// el mismo estado, y con dos implementaciones acabarían contradiciéndose el día
/// que una arregle un caso y la otra no. Ese fallo ya se vio aquí con la caché,
/// y una vez basta.
///
/// [compacto] es la única diferencia: en el menú no cabe la frase explicativa ni
/// hace falta repetir el título, porque el icono desde el que se abrió ya dice de
/// qué va.
class DispositivosPanel extends ConsumerStatefulWidget {
  const DispositivosPanel({super.key, this.compacto = false});

  final bool compacto;

  @override
  ConsumerState<DispositivosPanel> createState() => _DispositivosPanelState();
}

class _DispositivosPanelState extends ConsumerState<DispositivosPanel> {
  /// Cuál se está moviendo, para que solo su fila se apague.
  ///
  /// Por id y no un booleano de toda la sección: arrancar tarda, y bloquear la
  /// lista entera impediría cerrar otro mientras uno arranca.
  String? _ocupado;
  String? _error;

  @override
  void initState() {
    super.initState();
    // **Al abrir, se vuelve a preguntar.** El valor guardado hace que la lista
    // esté puesta al instante; esto hace que no sea vieja. Sin lo primero la
    // pantalla parpadea en cada visita, sin lo segundo miente.
    //
    // Después del primer fotograma: invalidar un provider mientras se construye
    // el widget que lo mira es modificarlo durante el build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(emuladoresProvider);
      ref.invalidate(dispositivosProvider);
    });
  }

  Future<void> _lanzar(Emulador emulador, {bool frio = false}) async {
    setState(() {
      _ocupado = emulador.id;
      _error = null;
    });
    final error = await ref
        .read(emuladoresDataSourceProvider)
        .lanzar(emulador, frio: frio);
    await _refrescar();
    if (!mounted) return;
    setState(() {
      _ocupado = null;
      _error = error;
    });
  }

  Future<void> _cerrar(Emulador emulador) async {
    setState(() {
      _ocupado = emulador.id;
      _error = null;
    });
    final error = await ref.read(emuladoresDataSourceProvider).cerrar(emulador);
    await _refrescar();
    if (!mounted) return;
    setState(() {
      _ocupado = null;
      _error = error;
    });
  }

  /// Vuelve a preguntar **y espera la respuesta** antes de que nadie suelte la
  /// fila.
  ///
  /// `invalidate` a secas no valía: dispara el refresco y sigue, así que al
  /// limpiar `_ocupado` justo detrás se pintaba la lista **vieja** un instante —
  /// el emulador ya arrancado apareciendo en gris con su botón de «Arrancar»
  /// antes de ponerse verde—. Se vio en vivo: «alcanza a mostrar de nuevo el
  /// estado gris con los botones pero después cambió».
  ///
  /// Un parpadeo así es peor que una espera un poco más larga: la espera se
  /// entiende, y un estado que se contradice a sí mismo hace desconfiar de toda
  /// la pantalla.
  Future<void> _refrescar() async {
    try {
      // `invalidate` y luego esperar el futuro nuevo, en vez de `refresh`: hace
      // lo mismo y no deja un resultado sin usar que el analizador reprocha.
      ref.invalidate(emuladoresProvider);
      await ref.read(emuladoresProvider.future);
    } on Exception {
      // Si el refresco falla, el propio provider ya lo cuenta en su `AsyncError`.
      // Aquí solo importaba no soltar la fila antes de tiempo.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final lista = ref.watch(emuladoresProvider);
    final fisicos = ref.watch(dispositivosProvider);

    // **`.value` y no el patrón de `AsyncData`**: al invalidar, Riverpod deja
    // el estado en «cargando **con** lo de antes», y eso es exactamente lo que se
    // quiere enseñar. Mirando solo `AsyncData` se vaciaba la pantalla en cada
    // refresco, que es el fallo que se reportó — «cada vez que salgo a otra vista
    // y vuelvo, vuelven a desaparecer para cargar».
    final valor = lista.value;
    final refrescando = lista.isLoading || fisicos.isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.compacto
                    ? strings.sectionEmulators
                    : strings.emulatorsTitle,
                style: NexusTypography.label.copyWith(color: colors.faint),
              ),
            ),
            if (refrescando)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: colors.faint,
                ),
              )
            else
              BotonDeFila(
                texto: strings.emulatorsRefresh,
                onPulsar: _ocupado != null
                    ? null
                    : () {
                        ref.invalidate(emuladoresProvider);
                        ref.invalidate(dispositivosProvider);
                      },
              ),
          ],
        ),
        if (!widget.compacto) ...[
          const SizedBox(height: NexusSpacing.s2),
          Text(
            strings.emulatorsExplainer,
            style: NexusTypography.nota.copyWith(color: colors.faint),
          ),
        ],
        SizedBox(height: widget.compacto ? NexusSpacing.s3 : NexusSpacing.s5),

        if (valor == null)
          // Solo la primera vez de la sesión: después siempre hay algo puesto.
          Text(
            strings.emulatorsRefresh,
            style: NexusTypography.nota.copyWith(color: colors.faint),
          )
        else if (valor.error case final mensaje?)
          // El error de la herramienta va **literal**: «No se encontró Flutter…»
          // dice qué hacer, y taparlo con un «no se pudo» obliga a abrir la
          // terminal para averiguarlo.
          Text(mensaje, style: NexusTypography.mono.copyWith(color: colors.err))
        else if (valor.emuladores.isEmpty)
          Text(
            strings.emulatorsEmpty,
            style: NexusTypography.nota.copyWith(color: colors.faint),
          )
        else ...[
          for (final emulador in valor.emuladores)
            _FilaDeEmulador(
              emulador: emulador,
              ocupado: _ocupado == emulador.id,
              apagado: _ocupado != null,
              onLanzar: () => _lanzar(emulador),
              onLanzarEnFrio: () => _lanzar(emulador, frio: true),
              onCerrar: () => _cerrar(emulador),
            ),

          // **Los teléfonos de verdad, en su propio grupo y sin botón.**
          //
          // Aparte porque el verbo no es el mismo: un emulador se arranca y se
          // cierra, y uno de estos ya está — lo único que se puede hacer con él
          // es usarlo. Mezclarlos obligaría a poner un botón apagado en la mitad
          // de las filas, que es enseñar un control que nunca sirve.
          //
          // Y llegan más tarde a propósito: cuestan seis veces más que todo lo
          // de arriba. La cabecera se pinta ya con su indicador para que no
          // aparezcan de golpe sin avisar.
          if (fisicos.value case final lista? when lista.isNotEmpty) ...[
            const SizedBox(height: NexusSpacing.s5),
            Text(
              strings.emulatorsConnected,
              style: NexusTypography.label.copyWith(color: colors.faint),
            ),
            const SizedBox(height: NexusSpacing.s2),
            for (final dispositivo in lista)
              _FilaDeDispositivo(dispositivo: dispositivo),
          ] else if (fisicos.isLoading) ...[
            const SizedBox(height: NexusSpacing.s5),
            Row(
              children: [
                Text(
                  strings.emulatorsConnected,
                  style: NexusTypography.label.copyWith(color: colors.faint),
                ),
                const SizedBox(width: NexusSpacing.s3),
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: colors.faint,
                  ),
                ),
              ],
            ),
          ],
        ],

        if (_error case final mensaje?) ...[
          const SizedBox(height: NexusSpacing.s3),
          Text(
            mensaje,
            style: NexusTypography.mono.copyWith(color: colors.err),
          ),
        ],

        // En el compacto no cabe la explicación entera, pero esto sí hace
        // falta decirlo: sin ello, cerrar Nexus parece que se lleva el
        // emulador por delante y nadie se atreve a cerrarlo con uno arriba.
        if (widget.compacto &&
            valor != null &&
            valor.emuladores.isNotEmpty) ...[
          const SizedBox(height: NexusSpacing.s3),
          Text(
            strings.emulatorsSiguenVivos,
            style: NexusTypography.nota.copyWith(
              color: colors.mute,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

/// Un teléfono enchufado.
///
/// No hay nada que arrancar ni que apagar —si está en la lista, está enchufado— así
/// que su única acción es **ver su pantalla**, y solo aparece si se puede: hace
/// falta scrcpy, y solo tiene sentido en Android físico. Ver
/// [sePuedeVerLaPantallaProvider].
class _FilaDeDispositivo extends ConsumerWidget {
  const _FilaDeDispositivo({required this.dispositivo});

  final DispositivoConectado dispositivo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          // El punto va siempre encendido: si está en la lista, está enchufado.
          // No hay estado intermedio que enseñar.
          Padding(
            padding: const EdgeInsets.only(right: NexusSpacing.s3),
            child: PuntoDeEstado(color: colors.ok),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dispositivo.nombre,
                  style: NexusTypography.data.copyWith(color: colors.ink),
                ),
                Text(
                  // El id detrás porque es lo que hace falta para `-d`, y en
                  // Android el nombre es el código de modelo —`24069PC21G`— que
                  // no dice nada por sí solo.
                  '${dispositivo.plataforma.name} · ${dispositivo.id}',
                  style: NexusTypography.mono.copyWith(color: colors.faint),
                ),
              ],
            ),
          ),
          // **Escrito y como acción principal**, que es lo que dice el
          // mockup: es lo único que se puede hacer con un teléfono enchufado, y
          // un icono de móvil al lado de un móvil no decía que se podía mirar.
          if (ref.watch(sePuedeVerLaPantallaProvider(dispositivo.id)))
            BotonDeFila(
              texto: strings.verLaPantallaCorto,
              tooltip: strings.verLaPantalla,
              tono: TonoDeBoton.principal,
              onPulsar: () => ref
                  .read(emuladoresDataSourceProvider)
                  .verLaPantalla(
                    deviceId: dispositivo.id,
                    titulo: dispositivo.nombre,
                    // Desde aquí sí con control: se abre para mirarlo y tocarlo.
                    // El caso sin control es el del panel de pruebas, cuando hay
                    // una corrida viva.
                    conControl: true,
                  ),
            ),
          // **Un iPhone físico se mira con lo que trae macOS**, y con las dos
          // formas porque se complementan: Duplicado da control pero exige Apple
          // ID y teléfono bloqueado; QuickTime no da control pero no exige nada de
          // eso y distingue dispositivos.
          //
          // Cada una solo si su app está en la máquina: Duplicado llegó en macOS
          // 15, y en una anterior el botón solo podría fallar.
          for (final como in ref.watch(comoVerElIphoneProvider(dispositivo.id)))
            IconButton(
              onPressed: () =>
                  ref.read(emuladoresDataSourceProvider).verElIphone(como),
              tooltip: switch (como) {
                ComoVerElIphone.duplicado => strings.verElIphoneDuplicado,
                ComoVerElIphone.quickTime => strings.verElIphoneQuickTime,
              },
              iconSize: 15,
              splashRadius: 15,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
              color: colors.faint,
              icon: Icon(switch (como) {
                ComoVerElIphone.duplicado => Icons.phone_iphone,
                ComoVerElIphone.quickTime => Icons.videocam_outlined,
              }),
            ),
        ],
      ),
    );
  }
}

class _FilaDeEmulador extends StatelessWidget {
  const _FilaDeEmulador({
    required this.emulador,
    required this.ocupado,
    required this.apagado,
    required this.onLanzar,
    required this.onLanzarEnFrio,
    required this.onCerrar,
  });

  final Emulador emulador;
  final bool ocupado;
  final bool apagado;
  final VoidCallback onLanzar;
  final VoidCallback onLanzarEnFrio;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final puede = !apagado;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          // El punto de estado antes del nombre: se lee de un barrido, sin
          // tener que llegar al botón para saber cuál está vivo.
          Padding(
            padding: const EdgeInsets.only(right: NexusSpacing.s3),
            child: PuntoDeEstado(
              color: emulador.corriendo ? colors.ok : colors.faint,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  emulador.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NexusTypography.data.copyWith(color: colors.ink),
                ),
                // **El estado se dice también apagado**: «android · apagado».
                // Antes solo se escribía «arriba», y el apagado quedaba en un
                // punto gris, que es decir el estado solo con el color.
                Text(
                  '${emulador.plataforma.name} · '
                  '${emulador.corriendo ? strings.emulatorsRunning : strings.emulatorsOff}',
                  style: NexusTypography.data.copyWith(color: colors.mute),
                ),
              ],
            ),
          ),
          // **El botón dice «cerrar» cuando ya está arriba**, en vez de ofrecer
          // arrancar algo que corre. Arrancar dos veces el mismo no duplica
          // nada, pero el botón estaría mintiendo sobre lo que va a hacer.
          if (ocupado)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: colors.accent,
              ),
            )
          else if (emulador.corriendo)
            BotonDeFila(
              texto: strings.emulatorsClose,
              onPulsar: puede ? onCerrar : null,
            )
          else ...[
            // **Arrancar primero y como principal**, que es a lo que se viene;
            // el arranque en frío es el plan B de cuando el normal se atasca.
            BotonDeFila(
              texto: strings.emulatorsLaunch,
              tono: TonoDeBoton.principal,
              onPulsar: puede ? onLanzar : null,
            ),
            // El arranque en frío solo existe en Android; en iOS no se ofrece
            // para no poner un botón que no hace nada distinto.
            if (emulador.plataforma == PlataformaEmulador.android) ...[
              const SizedBox(width: 5),
              BotonDeFila(
                texto: strings.emulatorsColdBoot,
                onPulsar: puede ? onLanzarEnFrio : null,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
