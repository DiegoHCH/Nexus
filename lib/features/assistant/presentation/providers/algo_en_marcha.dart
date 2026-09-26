import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/features/assistant/presentation/providers/assistant_controller.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';

/// Si alguna de las conversaciones abiertas está en mitad de algo: escuchando,
/// hablando o trabajando.
///
/// Lo usa el actualizador para no reiniciar encima de una frase o de un
/// encargo: «Reiniciar» espera a que esto vuelva a ser `false`. Se mira el
/// orbe de **todas** las conversaciones y no solo la que está delante,
/// porque la que trabaja en segundo plano es justo la que no ves cortarse.
final algoEnMarchaProvider = Provider<bool>((ref) {
  final ids = ref.watch(
    conversationsProvider.select(
      (c) => [for (final item in c.items) item.id].join('\n'),
    ),
  );
  if (ids.isEmpty) return false;
  var enMarcha = false;
  for (final id in ids.split('\n')) {
    // Todas vigiladas, sin cortar en la primera: si se dejara de mirar las
    // de detrás, que una empiece a trabajar no despertaría a nadie.
    final esta = ref.watch(
      assistantControllerProvider(
        id,
      ).select((s) => s.orbState != NexusOrbState.sleep),
    );
    enMarcha = enMarcha || esta;
  }
  return enMarcha;
});
