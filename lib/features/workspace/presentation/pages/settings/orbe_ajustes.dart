import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/accent_preference.dart';
import 'package:nexus/core/design_system/accent_wheel.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/design_system/orbe_preference.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb_plasma_painter.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/personaje/presentation/el_personaje.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/appearance_section.dart';

/// Apariencia › Orbe: de qué está hecho y, si es de plasma, su carácter; si
/// es el personaje, su luz y sus ojos.
///
/// **Con el orbe delante mientras se ajusta**, y escuchando: un deslizador
/// que cambia algo que no se ve es adivinar. Es la misma disposición del
/// mockup del escenario, donde estos siete ajustes se eligieron a mano.
///
/// Va en su propio archivo y no dentro de [AppearanceSection] porque es la
/// parte que más crece, y el tema y el acento no tienen por qué leerse con ella.
class OrbeAjustes extends ConsumerWidget {
  const OrbeAjustes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final estilo = ref.watch(orbeEstiloProvider);
    final control = ref.read(orbeEstiloProvider.notifier);
    final sinPlasma = PlasmaDelOrbe.programa == null;

    // Un bloque de la sección, con su rótulo: la forma primero —como en el
    // mockup, dos opciones con nombre— y debajo el orbe con sus siete
    // ajustes, que solo existen si es de plasma.
    return BloqueDeAjustes(
      rotulo: strings.orbeTitle,
      hijos: [
        // Tres opciones y dos ajustes detrás: Plasma y Puntos son la forma del
        // orbe; Personaje es lo que va en la sala, y deja la forma como
        // estaba para el Dock, el orbe flotante y los orbes pequeños —ver
        // [OrbeEstilo.personaje]—.
        ElegirDeAjustes<_LoQueVa>(
          llave: 'forma-del-orbe',
          opciones: _LoQueVa.values,
          elegida: _LoQueVa.de(estilo),
          nombre: (opcion) => switch (opcion) {
            _LoQueVa.plasma => strings.orbePlasma,
            _LoQueVa.puntos => strings.orbePuntos,
            _LoQueVa.personaje => strings.orbePersonaje,
          },
          onElegir: (opcion) => control.elegir(opcion.en(estilo)),
        ),
        if (!estilo.personaje &&
            estilo.forma == FormaDelOrbe.plasma &&
            sinPlasma)
          EstadoDeAjustes(
            tono: TonoDeAjustes.atencion,
            texto: strings.orbeSinPlasma,
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // La vista previa lee el estilo de aquí y no del scope de la app:
            // así cambia con cada movimiento del deslizador, sin esperar a que
            // se guarde.
            SizedBox.square(
              dimension: 150,
              child: OrbeEstiloScope(
                estilo: estilo,
                // El personaje de pie, como en la sala: lo que se ajusta aquí
                // —su luz, sus ojos— se ve en él.
                child: estilo.personaje
                    ? const ElPersonaje(state: NexusOrbState.listen, nivel: 0.3)
                    : const NexusOrb(state: NexusOrbState.listen),
              ),
            ),
            if (estilo.personaje) ...[
              const SizedBox(width: NexusSpacing.s5),
              Expanded(
                child: _LoDelPersonaje(
                  estilo: estilo,
                  alElegir: control.elegir,
                ),
              ),
            ],
            // Los siete ajustes son del plasma: con puntos no mueven nada, y
            // enseñarlos sería ofrecer mandos sin cable.
            if (!estilo.personaje && estilo.forma == FormaDelOrbe.plasma) ...[
              const SizedBox(width: NexusSpacing.s5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final ajuste in _ajustes(strings))
                      _Deslizador(
                        nombre: ajuste.nombre,
                        valor: ajuste.leer(estilo),
                        rango: OrbeEstilo.rangos[ajuste.clave]!,
                        alMover: (v) => control.elegir(ajuste.poner(estilo, v)),
                      ),
                    const SizedBox(height: NexusSpacing.s2),
                    BotonDeAjustes(
                      texto: strings.orbeFabrica,
                      onPulsar: control.restablecer,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  static List<_Ajuste> _ajustes(NexusStrings s) => [
    _Ajuste(
      'filamentos',
      s.orbeFilamentos,
      (e) => e.filamentos,
      (e, v) => e.copyWith(filamentos: v),
    ),
    _Ajuste(
      'turbulencia',
      s.orbeTurbulencia,
      (e) => e.turbulencia,
      (e, v) => e.copyWith(turbulencia: v),
    ),
    _Ajuste(
      'finura',
      s.orbeFinura,
      (e) => e.finura,
      (e, v) => e.copyWith(finura: v),
    ),
    _Ajuste(
      'velocidad',
      s.orbeVelocidad,
      (e) => e.velocidad,
      (e, v) => e.copyWith(velocidad: v),
    ),
    _Ajuste(
      'nucleo',
      s.orbeNucleo,
      (e) => e.nucleo,
      (e, v) => e.copyWith(nucleo: v),
    ),
    _Ajuste(
      'tamano',
      s.orbeTamano,
      (e) => e.tamano,
      (e, v) => e.copyWith(tamano: v),
    ),
    _Ajuste(
      'intensidad',
      s.orbeIntensidad,
      (e) => e.intensidad,
      (e, v) => e.copyWith(intensidad: v),
    ),
  ];
}

/// Las tres opciones de arriba: dos formas del orbe y el personaje.
enum _LoQueVa {
  plasma,
  puntos,
  personaje;

  static _LoQueVa de(OrbeEstilo estilo) => estilo.personaje
      ? personaje
      : switch (estilo.forma) {
          FormaDelOrbe.plasma => plasma,
          FormaDelOrbe.puntos => puntos,
        };

  /// [estilo] con esta opción elegida. El personaje no toca la forma: es la
  /// que siguen pintando los orbes de fuera de la sala.
  OrbeEstilo en(OrbeEstilo estilo) => switch (this) {
    plasma => estilo.copyWith(forma: FormaDelOrbe.plasma, personaje: false),
    puntos => estilo.copyWith(forma: FormaDelOrbe.puntos, personaje: false),
    personaje => estilo.copyWith(personaje: true),
  };
}

/// Su luz y sus ojos, al lado del personaje de muestra.
class _LoDelPersonaje extends StatelessWidget {
  const _LoDelPersonaje({required this.estilo, required this.alElegir});

  final OrbeEstilo estilo;
  final ValueChanged<OrbeEstilo> alElegir;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final color = estilo.colorDeLosOjos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextoDeAjustes(strings.personajeExplica, tamano: 13),
        const SizedBox(height: NexusSpacing.s4),
        RotuloDeAjustes(strings.personajeLuz),
        const SizedBox(height: NexusSpacing.s2),
        ElegirDeAjustes<LuzDelPersonaje>(
          llave: 'luz-del-personaje',
          opciones: LuzDelPersonaje.values,
          elegida: estilo.luz,
          nombre: (luz) => switch (luz) {
            LuzDelPersonaje.traje => strings.personajeLuzTraje,
            LuzDelPersonaje.aura => strings.personajeLuzAura,
            LuzDelPersonaje.horizonte => strings.personajeLuzHorizonte,
          },
          onElegir: (luz) => alElegir(estilo.copyWith(luz: luz)),
        ),
        const SizedBox(height: NexusSpacing.s4),
        RotuloDeAjustes(strings.personajeOjos),
        const SizedBox(height: NexusSpacing.s2),
        // 🔴 **«Otro color» abre la misma rueda que el acento**, y no una lista:
        // el acento dejó de ser una lista cerrada porque es identidad, y los
        // ojos también lo son. Elegido, la opción lleva el nombre del color.
        ElegirDeAjustes<OjosDelPersonaje>(
          llave: 'ojos-del-personaje',
          opciones: OjosDelPersonaje.values,
          elegida: estilo.ojos,
          nombre: (ojos) => switch (ojos) {
            OjosDelPersonaje.comoEstan => strings.personajeOjosComoEstan,
            OjosDelPersonaje.delAcento => strings.personajeOjosDelAcento,
            OjosDelPersonaje.deColor =>
              estilo.ojos == OjosDelPersonaje.deColor
                  ? '${nombreDelAcento(Accent(color).name, strings)} · '
                        '${Accent(color).hex}'
                  : strings.personajeOjosOtroColor,
          },
          onElegir: (ojos) => ojos == OjosDelPersonaje.deColor
              ? _LaRuedaDeLosOjos.abrir(context, estilo, alElegir)
              : alElegir(estilo.copyWith(ojos: ojos)),
        ),
        // Elegido un color, se puede cambiar por otro: la opción elegida no
        // se vuelve a pulsar.
        if (estilo.ojos == OjosDelPersonaje.deColor) ...[
          const SizedBox(height: NexusSpacing.s2),
          BotonDeAjustes(
            texto: strings.accentPick,
            onPulsar: () => _LaRuedaDeLosOjos.abrir(context, estilo, alElegir),
          ),
        ],
      ],
    );
  }
}

/// La rueda del acento, para los ojos. Como la del acento, el color se ve
/// mientras se arrastra y se guarda al soltar.
class _LaRuedaDeLosOjos extends StatefulWidget {
  const _LaRuedaDeLosOjos({required this.estilo, required this.alElegir});

  final OrbeEstilo estilo;
  final ValueChanged<OrbeEstilo> alElegir;

  static Future<void> abrir(
    BuildContext context,
    OrbeEstilo estilo,
    ValueChanged<OrbeEstilo> alElegir,
  ) => showDialog<void>(
    context: context,
    builder: (_) => _LaRuedaDeLosOjos(estilo: estilo, alElegir: alElegir),
  );

  @override
  State<_LaRuedaDeLosOjos> createState() => _LaRuedaDeLosOjosState();
}

class _LaRuedaDeLosOjosState extends State<_LaRuedaDeLosOjos> {
  late Color _color = widget.estilo.colorDeLosOjos;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    return Dialog(
      backgroundColor: colors.rise,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.rule2),
        borderRadius: BorderRadius.circular(NexusRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NexusSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.personajeOjos,
              style: NexusTypography.subtitle.copyWith(color: colors.ink),
            ),
            const SizedBox(height: NexusSpacing.s5),
            Center(
              child: AccentWheel(
                value: _color,
                onChanged: (color) => setState(() => _color = color),
                onSettled: (color) {
                  setState(() => _color = color);
                  widget.alElegir(
                    widget.estilo.copyWith(
                      ojos: OjosDelPersonaje.deColor,
                      colorDeLosOjos: color,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: NexusSpacing.s5),
            Row(
              children: [
                Text(
                  nombreDelAcento(Accent(_color).name, strings),
                  style: NexusTypography.control.copyWith(color: colors.ink),
                ),
                const SizedBox(width: NexusSpacing.s3),
                Text(
                  Accent(_color).hex,
                  style: NexusTypography.mono.copyWith(color: colors.faint),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(strings.close.toUpperCase()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Ajuste {
  const _Ajuste(this.clave, this.nombre, this.leer, this.poner);

  final String clave;
  final String nombre;
  final double Function(OrbeEstilo) leer;
  final OrbeEstilo Function(OrbeEstilo, double) poner;
}

class _Deslizador extends StatelessWidget {
  const _Deslizador({
    required this.nombre,
    required this.valor,
    required this.rango,
    required this.alMover,
  });

  final String nombre;
  final double valor;
  final (double, double) rango;
  final ValueChanged<double> alMover;

  // Como los del escenario: el nombre y su valor en una línea, y la barra
  // debajo a todo el ancho. En una sola fila, con el nombre y el número a los
  // lados, la barra se quedaba en un tercio del ancho y el recorrido era tan
  // corto que moverla con precisión costaba.
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (min, max) = rango;
    return Padding(
      padding: const EdgeInsets.only(bottom: NexusSpacing.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  nombre,
                  style: NexusTypography.nota.copyWith(color: colors.ink),
                ),
              ),
              Text(
                valor.toStringAsFixed(2),
                style: NexusTypography.data.copyWith(color: colors.mute),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              padding: EdgeInsets.zero,
            ),
            child: SizedBox(
              height: 20,
              child: Slider(
                value: valor.clamp(min, max),
                min: min,
                max: max,
                onChanged: alMover,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
