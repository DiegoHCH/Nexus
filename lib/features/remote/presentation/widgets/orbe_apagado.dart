import 'package:flutter/material.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';

/// El orbe cuando **no hay nadie al otro lado**: brasas sin color, quietas y sin el
/// anillo del oído.
///
/// Es el estado que el mockup llama «apagado», y no es el dormido. Dormido dice
/// «estoy aquí, esperando, y te oigo si dices mi nombre»; con el Mac inalcanzable
/// eso es mentira en las tres partes —no está, no espera nada y no oye—. Por eso se
/// le quitan las tres cosas que lo hacían parecer vivo:
///
/// - **el color**, con una matriz de saturación a cero: las brasas siguen siendo
///   suyas, pero grises. Es un filtro sobre lo que ya se pinta y no un color escrito
///   a mano, así que el tema claro y el oscuro se apagan igual;
/// - **el movimiento**, con la misma pose fija que el orbe usa cuando el sistema
///   pide reducir animaciones: sin ticker, que además es no gastar batería pintando
///   a sesenta fotogramas algo que dice «aquí no pasa nada»;
/// - **el oído**, porque no hay nadie oyendo.
///
/// Vive en el móvil y no como una bandera del orbe: el escritorio no tiene un estado
/// en que el Mac no esté, y un parámetro que solo usa un cliente acaba siendo el que
/// nadie mantiene.
class OrbeApagado extends StatelessWidget {
  const OrbeApagado({super.key});

  /// Luminancia de Rec. 709: el gris que sale se parece en brillo al color que
  /// había, así que el orbe no se vuelve una mancha más clara u oscura que antes.
  static const _sinColor = <double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ];

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: const IgnorePointer(
      child: Opacity(
        // Tenue y no invisible: el hueco del orbe es lo que hace que esta pantalla se
        // lea como la misma presencia sin fuerza, y no como otra pantalla.
        opacity: 0.45,
        child: ColorFiltered(
          colorFilter: ColorFilter.matrix(_sinColor),
          child: NexusOrb(state: NexusOrbState.sleep, oido: false),
        ),
      ),
    ),
  );
}
