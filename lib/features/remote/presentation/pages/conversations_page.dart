import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/remote/domain/el_subtitulo_de_la_voz.dart';
import 'package:nexus/core/design_system/nexus_colors.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/remote/domain/remote_mirror.dart';
import 'package:nexus/features/remote/presentation/pages/conversation_page.dart';
import 'package:nexus/features/remote/presentation/providers/mirror_providers.dart';
import 'package:nexus/features/remote/presentation/pages/utility_pages.dart';
import 'package:nexus/features/remote/presentation/widgets/mobile_chrome.dart';
import 'package:nexus/features/remote/presentation/widgets/mobile_drawer.dart';
import 'package:nexus/core/design_system/nexus_spacing.dart';
import 'package:nexus/core/design_system/nexus_typography.dart';

/// Lo que hay abierto en el Mac.
///
/// Es la pantalla de entrada porque **hay hasta tres conversaciones a la vez y
/// trabajan en paralelo**: entrar directo a una escondería que las otras dos están
/// avanzando, que es justo lo que un teléfono viene a resolver — mirar cómo va lo que
/// dejaste corriendo.
class ConversationsPage extends ConsumerStatefulWidget {
  const ConversationsPage({super.key});

  @override
  ConsumerState<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends ConsumerState<ConversationsPage> {
  /// El cajón se abre desde aquí y no desde un `Builder` en la cabecera: con la llave
  /// en el estado, quien abre el menú es la pantalla y la cabecera solo avisa.
  final _llave = GlobalKey<ScaffoldState>();

  void _ir(Widget pantalla) {
    // Se cierra el menú **antes** de navegar: si se deja abierto, al volver aparece
    // encima de la pantalla nueva y parece que no se hizo nada.
    Navigator.of(context).pop();
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => pantalla));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final espejo = ref.watch(mirrorProvider);

    return Scaffold(
      key: _llave,
      backgroundColor: colors.void_,
      // El velo del mockup y no el negro de Material: el fondo al 70 %, así que en
      // claro se vela en claro y la pantalla de detrás se sigue leyendo.
      drawerScrimColor: MedidasDelMovil.velo(colors),
      drawer: MobileDrawer(
        alAbrirNueva: () => _ir(const FoldersPage()),
        alAbrirArchivo: () => _ir(const ArchivePage()),
        alAbrirArtifacts: () => _ir(const ArtifactsPage()),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // La cabecera del sistema, con el hamburguesa. «Olvidar» se fue al menú:
            // era la única acción destructiva y estaba en la esquina de la pantalla
            // principal, a un toque de todo lo demás.
            MobileChrome(alMenu: () => _llave.currentState?.openDrawer()),
            Expanded(
              child: RefreshIndicator(
                // Tirar hacia abajo vuelve a pedir la lista. Existe porque el móvil
                // pasa ratos en segundo plano y volver no siempre trae un evento:
                // sin esto la única forma de refrescar sería reconectar.
                onRefresh: () => ref.read(mirrorProvider.notifier).refrescar(),
                color: colors.accent,
                backgroundColor: colors.deep,
                child: espejo.vacio
                    // Vacío **no siempre significa lo mismo**: puede que el Mac no
                    // tenga nada abierto, o que no se haya podido preguntar. Se
                    // dibujaban idénticos, y son dos cosas distintas.
                    ? _Vacio(
                        preguntado: ref
                            .read(mirrorProvider.notifier)
                            .preguntado,
                        // La salida va desde aquí porque **es la pantalla la que sabe
                        // navegar**, y porque sin ella el vacío era un callejón: «nada
                        // abierto en el Mac» y ninguna forma de abrir algo, salvo que
                        // ya supieras que estaba detrás del menú.
                        alEmpezar: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const FoldersPage(),
                          ),
                        ),
                        alReintentar: () =>
                            ref.read(mirrorProvider.notifier).refrescar(),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: MedidasDelMovil.margen,
                        ),
                        // Una más al principio: la cabecera va dentro de la lista y
                        // no encima, para que el tirón para refrescar la arrastre
                        // con todo lo demás.
                        itemCount: espejo.visibles.length + 1,
                        itemBuilder: (context, i) => i == 0
                            ? _Cabecera(cuantas: espejo.visibles.length)
                            : _Tarjeta(conversacion: espejo.visibles[i - 1]),
                      ),
              ),
            ),
            // Abajo, a todo el ancho y en acento, como el mockup: empezar otra es lo
            // que más se hace desde aquí después de mirar, y estaba escondido detrás
            // del menú en cuanto había una abierta.
            if (!espejo.vacio)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MedidasDelMovil.margen,
                  NexusSpacing.s3,
                  MedidasDelMovil.margen,
                  MedidasDelMovil.pie,
                ),
                child: WideAction(
                  key: const ValueKey('conversacion-nueva'),
                  texto: context.strings.mobileNewConversation,
                  principal: true,
                  alTocar: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FoldersPage(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({
    required this.preguntado,
    required this.alEmpezar,
    required this.alReintentar,
  });

  /// Si el Mac contestó a la última petición de la lista.
  final bool preguntado;

  /// Abrir una conversación nueva sobre una carpeta que el Mac ya tiene.
  final VoidCallback alEmpezar;

  final Future<void> Function() alReintentar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    // Una lista vacía **no es un error**: es un Mac sin conversaciones abiertas, y
    // eso pasa a diario. Se dibuja como un estado y no como un fallo.
    //
    // **Y las tres partes que el mockup exige, no dos.** Tenía qué pasó y por qué, y
    // le faltaba qué se puede hacer: la pantalla decía «nada abierto en el Mac» y no
    // ofrecía abrir nada, así que empezar dependía de saber que estaba detrás del
    // menú. Un estado vacío sin salida es un callejón con buenos modales.
    //
    // `SliverFillRemaining` y no un `ListView` con huecos a dedo: hace falta que la
    // columna tenga **alto de verdad** para que los `Spacer` reparten el sitio —el
    // orbe centrado arriba, el botón pegado abajo— y a la vez que siga habiendo algo
    // que se pueda arrastrar, o el tirón para refrescar deja de funcionar justo aquí,
    // que es la pantalla donde más se tira. Un `Expanded` dentro de un scroll normal
    // es la contradicción que ya rompió tres pantallas de esta app.
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          // `true` y no `false`: con `false` el sliver mide el **alto intrínseco** del
          // hijo, y una columna con espacio flexible dentro no tiene ninguno —eso es
          // lo que revienta—. Con `true` la columna recibe el alto de la ventana ya
          // fijado, que es lo que hace falta para repartirlo.
          hasScrollBody: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              MedidasDelMovil.margen,
              0,
              MedidasDelMovil.margen,
              MedidasDelMovil.pie,
            ),
            // **Arriba el orbe con lo que pasa, abajo lo que se puede hacer**, como el
            // mockup: el orbe dormido a 30 del borde y el título pegado a él —son una
            // sola cosa, «aquí está, esperando»—, y el botón en el fondo, donde está
            // el pulgar. Con el orbe estirado en todo el hueco libre, el título caía
            // a dos tercios de la pantalla, lejos de lo que lo explicaba.
            //
            // `spaceBetween` reparte lo que sobra **entre** los dos grupos, y el orbe
            // en un `Flexible` es lo único que encoge en una pantalla pequeña o con
            // la letra del sistema en grande.
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 30),
                      // Sin horizonte, como el mockup: la línea lo convierte en un
                      // paisaje, y aquí el orbe es una presencia y no un decorado.
                      // Cuadrado: el orbe se dibuja con el lado corto de su caja,
                      // y en una franja ancha el que manda es el alto.
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 260),
                          child: const AspectRatio(
                            aspectRatio: 1,
                            child: IgnorePointer(
                              child: NexusOrb(state: NexusOrbState.sleep),
                            ),
                          ),
                        ),
                      ),
                      TextoEquilibrado(
                        preguntado
                            ? strings.mobileNothingOpen
                            : strings.mobileCouldNotAsk,
                        clave: const ValueKey('titulo-del-vacio'),
                        // El mismo título que las pantallas de estado —`.grande` en
                        // el mockup—: esto es un estado, y se tiene que leer como tal.
                        style: NexusTypography.title.copyWith(
                          color: colors.ink,
                          fontSize: 24,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: NexusSpacing.s1),
                      Text(
                        preguntado
                            // Se dice **sobre qué** se abre, que es la parte que no
                            // es obvia: una conversación no nace de la nada, nace
                            // sobre una carpeta que el Mac ya tenía emparejada.
                            ? strings.mobileNothingOpenBody
                            : strings.mobileCouldNotAskBody,
                        textAlign: TextAlign.center,
                        style: NexusTypography.nota.copyWith(
                          color: colors.mute,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: NexusSpacing.s5),
                // Abajo, y no debajo del texto: es donde está el pulgar, y es lo
                // último que se lee después de saber qué pasa.
                if (preguntado)
                  WideAction(
                    key: const ValueKey('empezar-desde-el-vacio'),
                    texto: strings.mobileNewConversation,
                    principal: true,
                    alTocar: alEmpezar,
                  )
                else
                  // Sin respuesta del Mac la salida **no** es abrir una carpeta —eso
                  // fallaría igual—: es volver a preguntar.
                  WideAction(
                    key: const ValueKey('reintentar-desde-el-vacio'),
                    texto: strings.mobileAskAgain,
                    principal: true,
                    alTocar: alReintentar,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// «Abiertas en el Mac · 3», el rótulo de la lista.
class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.cuantas});

  final int cuantas;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 6),
    child: Text(
      context.strings.mobileOpenOnMac(cuantas).toUpperCase(),
      style: NexusTypography.label.copyWith(color: context.colors.mute),
    ),
  );
}

class _Tarjeta extends ConsumerWidget {
  const _Tarjeta({required this.conversacion});

  final MirroredConversation conversacion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    // Con la regla del enlace puesta, igual que el orbe grande: sin Mac no gira
    // ninguno, diga lo que diga lo último que llegó.
    final orbe = ref.watch(orbeProvider(conversacion.id));
    final paso = ElPasoDeAhora.de(conversacion.steps);
    final loQueHace = _loQueHace(strings, orbe, paso);

    // **Una fila con hairline, no una tarjeta.** Una `Card` trae elevación, esquinas
    // de 12 y su propio color de superficie: tres cosas que este sistema no usa en
    // ninguna otra parte, y que hacían que esta pantalla se leyera como otra app. Las
    // demás listas del teléfono —el historial, los documentos, el menú— ya son filas
    // separadas por una línea de un píxel.
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.rule)),
      ),
      child: InkWell(
        key: ValueKey('abrir-${conversacion.id}'),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ConversationPage(conversationId: conversacion.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: NexusSpacing.s3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // **Un miniorbe por fila, con su estado.** Es lo que el mockup pide
              // para esta pantalla: de un vistazo, cuál habla, cuál trabaja y cuál
              // piensa — sin leer ninguna fila. El mismo orbe que el grande, con las
              // mismas capas, porque un icono de estado aparte sería un segundo
              // idioma para decir lo mismo.
              //
              // 22 dentro de una columna de 26, como el mockup: el miniorbe es una
              // marca al lado de la ruta y no una ilustración, y a 26 pesaba más
              // que el texto que acompaña.
              Container(
                width: 26,
                height: 22,
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: IgnorePointer(
                    child: NexusOrb(
                      key: ValueKey('miniorbe-${conversacion.id}'),
                      state: orbe,
                      pasos: paso?.total,
                      hechos: paso?.hechos,
                      // El anillo del oído, solo en la que el Mac escucha: es la que
                      // oye si dices su nombre.
                      oido: conversacion.focused,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // La ruta, que es lo que un humano reconoce, y en mono
                        // porque es un dato. Se enseña el final y no el principio:
                        // `/Users/…/proyectos/api` se distingue por la cola, no por
                        // la cabeza.
                        Flexible(
                          child: Text(
                            _cola(conversacion.nombre),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: NexusTypography.data.copyWith(
                              color: colors.mute,
                            ),
                          ),
                        ),
                        if (conversacion.focused) ...[
                          const SizedBox(width: NexusSpacing.s2),
                          // Pegado a la ruta y en acento, como el mockup: la que te
                          // escucha es una propiedad de **esta** fila, no una
                          // columna aparte. Con la palabra y no con un micrófono:
                          // un glifo habría que saber qué significa.
                          Text(
                            strings.mobileListening.toUpperCase(),
                            style: NexusTypography.label.copyWith(
                              color: colors.accent,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (loQueHace != null) ...[
                      const SizedBox(height: NexusSpacing.s1),
                      Text(
                        loQueHace,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: NexusTypography.body.copyWith(
                          color: colors.ink,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (conversacion.error != null) ...[
                      const SizedBox(height: NexusSpacing.s1),
                      Text(
                        conversacion.error!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: NexusTypography.nota.copyWith(color: colors.err),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Lo que dice la fila, **con las palabras del estado de su orbe**.
  ///
  /// El orbe dice de un vistazo en qué anda; esta línea dice lo mismo con palabras,
  /// para quien lo lee de cerca: qué está diciendo, en qué paso va, o que piensa. Sin
  /// estado que contar, lo último que contestó, que es lo que se viene a mirar.
  String? _loQueHace(
    NexusStrings strings,
    NexusOrbState orbe,
    ElPasoDeAhora? paso,
  ) {
    final respuesta = SubtituloDeLaVoz.laUltimaFrase(conversacion.reply);
    return switch (orbe) {
      NexusOrbState.speak when respuesta.isNotEmpty =>
        strings.mobileRowSpeaking(respuesta),
      NexusOrbState.listen => strings.mobileRowListening,
      NexusOrbState.ponder => strings.mobileRowThinking,
      // Trabajando, o con el turno en pie aunque el orbe no lo haya dicho todavía:
      // el paso es lo único que cuenta cuánto le falta.
      _ when orbe == NexusOrbState.think || conversacion.streaming =>
        paso == null
            ? strings.mobileWorking
            : '${strings.mobileStepOf(paso.paso, paso.total)} · ${paso.texto}',
      _ => respuesta.isEmpty ? null : respuesta,
    };
  }

  /// Los dos últimos tramos de la ruta. Con una pantalla estrecha, el principio de
  /// una ruta absoluta es lo que todas tienen en común y lo último es lo que las
  /// distingue.
  static String _cola(String ruta) {
    final tramos = ruta.split('/').where((t) => t.isNotEmpty).toList();
    if (tramos.length <= 2) return ruta;
    return '…/${tramos.sublist(tramos.length - 2).join('/')}';
  }
}
