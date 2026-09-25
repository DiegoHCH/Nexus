import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/design_system/orbe_preference.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb_plasma_painter.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';

/// Apariencia › Orbe: de qué está hecho y, si es de plasma, su carácter.
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
        ElegirDeAjustes<FormaDelOrbe>(
          llave: 'forma-del-orbe',
          opciones: FormaDelOrbe.values,
          elegida: estilo.forma,
          nombre: (forma) => switch (forma) {
            FormaDelOrbe.plasma => strings.orbePlasma,
            FormaDelOrbe.puntos => strings.orbePuntos,
          },
          onElegir: (forma) => control.elegir(estilo.copyWith(forma: forma)),
        ),
        if (estilo.forma == FormaDelOrbe.plasma && sinPlasma)
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
                child: const NexusOrb(state: NexusOrbState.listen),
              ),
            ),
            // Los siete ajustes son del plasma: con puntos no mueven nada, y
            // enseñarlos sería ofrecer mandos sin cable.
            if (estilo.forma == FormaDelOrbe.plasma) ...[
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
