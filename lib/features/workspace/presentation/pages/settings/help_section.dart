import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/core/platform/system_files.dart';
import 'package:nexus/core/diagnostico/registro_providers.dart';
import 'package:nexus/features/onboarding/presentation/providers/tour_providers.dart';
import 'package:nexus/features/updates/presentation/providers/updates_providers.dart';

/// Ayuda: la versión con su actualización, el registro y la guía en frío.
///
/// 🔴 **Tres bloques cortos, como el mockup, y la guía como índice.** Eran el
/// tour, la versión, el registro y los cinco textos de la guía enteros, uno
/// detrás de otro: la sección más larga de Ajustes con diferencia, y lo que se
/// viene a buscar —qué versión hay, dónde está el registro— quedaba enterrado
/// debajo de la prosa. Ahora la guía son cinco filas que se abren al pulsarlas.
class HelpSection extends ConsumerWidget {
  const HelpSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;

    return BloquesDeAjustes(
      bloques: [
        // La versión y, si hay una nueva, el aviso. Aquí y no en un diálogo:
        // un aviso modal por una actualización interrumpe justo a quien está
        // trabajando, y esto no es urgente — es información.
        const _LaVersion(),
        // El registro. Aquí y no en una pantalla propia: se busca el día que
        // algo falla, y ese día se busca en Ayuda.
        const _ElRegistro(),
        // La guía en frío. Cinco bloques y en este orden: qué hace falta, qué
        // sale de tu Mac, qué hace cada pieza, para qué **no** es, y qué hacer
        // cuando algo falla.
        //
        // El segundo va tan arriba a propósito: es lo único de aquí que **no
        // se puede deducir mirando la app**, y decidirlo mal tiene
        // consecuencias fuera de ella. Y el cuarto existe porque una
        // herramienta que se recomienda a sí misma para todo no se puede
        // comprobar por dentro: decir en qué es peor que el terminal es lo que
        // hace creíble el resto.
        BloqueDeAjustes(
          rotulo: strings.guiaTitle,
          hijos: [
            _LaGuia(
              apartados: [
                (strings.guideNeedsTitle, strings.guideNeedsBody),
                (strings.guidePrivacyTitle, strings.guidePrivacyBody),
                (strings.guidePiecesTitle, strings.guidePiecesBody),
                (strings.guideNotForTitle, strings.guideNotForBody),
                (strings.guideTroubleTitle, strings.guideTroubleBody),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// La versión que corre y, si la hay, la que está publicada; y el tour.
///
/// Ya descarga e instala: el motor es Sparkle y la modal es la de la app. Lo que
/// **no** hace es reiniciarse por su cuenta —eso mataría un `claude -p` a media
/// escritura—, así que el último paso siempre lo confirma quien está delante.
class _LaVersion extends ConsumerWidget {
  const _LaVersion();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final aviso = ref.watch(updatesControllerProvider).notice;
    final actual = aviso?.current ?? ref.watch(currentVersionProvider).value;
    final hayNueva = aviso != null && aviso.isNewer;

    return BloqueDeAjustes(
      rotulo: strings.versionLabel,
      hijos: [
        // En verde solo si se sabe que está al día: sin haber preguntado, la
        // versión va sola y con el punto apagado, porque «al día» sería una
        // suposición.
        EstadoDeAjustes(
          tono: hayNueva
              ? TonoDeAjustes.atencion
              : aviso == null
              ? TonoDeAjustes.apagado
              : TonoDeAjustes.bien,
          texto: switch (actual) {
            null => '—',
            final version when hayNueva => strings.helpVersionConNueva(
              version,
              aviso.latest ?? '',
            ),
            final version when aviso != null => strings.helpVersionAlDia(
              version,
            ),
            final version => strings.helpVersion(version),
          },
        ),
        AccionesDeAjustes(
          botones: [
            // Un solo botón para preguntar: el aviso de que hay una nueva sale
            // arriba a la derecha por su cuenta, incluso estando aquí.
            BotonDeAjustes(
              texto: strings.updateCheckNow,
              tono: TonoDeBoton.principal,
              onPulsar: ref
                  .read(updatesControllerProvider.notifier)
                  .comprobarAhora,
            ),
            // El tour, junto a la versión como en el mockup: los dos son «qué
            // es esto que tengo delante».
            BotonDeAjustes(
              texto: strings.helpTourAction,
              onPulsar: () {
                ref.read(tourControllerProvider.notifier).replay();
                Navigator.of(context).maybePop();
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// Dónde vive el registro, y el botón para abrirlo donde está.
///
/// La ruta se enseña entera y no se esconde detrás del botón: quien vaya a
/// pedir ayuda con esto necesita poder copiarla, y quien no tenga Finder a mano
/// —una sesión por SSH, un `tail -f`— necesita saber dónde mirar.
class _ElRegistro extends ConsumerWidget {
  const _ElRegistro();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final ruta = ref.watch(rutaDelRegistroProvider).value;

    return BloqueDeAjustes(
      rotulo: strings.logTitle,
      hijos: [
        CampoDeAjustes(ruta, vacio: strings.logMissing),
        AccionesDeAjustes(
          botones: [
            BotonDeAjustes(
              texto: strings.logAction,
              tono: TonoDeBoton.principal,
              // Sin ruta no hay nada que enseñar, y un botón que no hace nada
              // es peor que uno apagado.
              onPulsar: ruta == null ? null : () => SystemFiles.revelar(ruta),
            ),
          ],
        ),
      ],
    );
  }
}

/// La guía como filas que se abren: el título se ve siempre y el texto al
/// pulsarlo.
///
/// El cuerpo llega como un solo texto con saltos dobles y se parte aquí. Es a
/// propósito: un bloque por párrafo multiplicaría por cuatro los textos que hay
/// que traducir sin añadir nada, y lo que se traduce es prosa, no maquetación.
class _LaGuia extends StatefulWidget {
  const _LaGuia({required this.apartados});

  final List<(String, String)> apartados;

  @override
  State<_LaGuia> createState() => _LaGuiaState();
}

class _LaGuiaState extends State<_LaGuia> {
  /// Cuál está abierto. Uno a la vez: dos textos largos abiertos a la vez son
  /// la pared de prosa que esto venía a quitar.
  int? _abierto;

  @override
  Widget build(BuildContext context) {
    return FilasDeAjustes(
      filas: [
        for (final (i, (titulo, cuerpo)) in widget.apartados.indexed)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilaDeAjustes(
                tono: _abierto == i
                    ? TonoDeAjustes.activo
                    : TonoDeAjustes.apagado,
                titulo: titulo,
                onPulsar: () =>
                    setState(() => _abierto = _abierto == i ? null : i),
              ),
              if (_abierto == i)
                Padding(
                  padding: const EdgeInsets.only(left: 24, bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final parrafo in cuerpo.split('\n\n'))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: TextoDeAjustes(parrafo),
                        ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
