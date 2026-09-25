import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/features/memoria/presentation/pages/memoria_section.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/nombres_section.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/stats/presentation/widgets/stats_section.dart';
import 'package:nexus/features/superpowers/presentation/widgets/superpowers_section.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:nexus/features/emulators/presentation/widgets/emuladores_section.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/appearance_section.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/help_section.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/salidas_section.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/history_section.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/cuentas_section.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/pruebas_section.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/language_section.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/avisos_section.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/imagenes_section.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/llaves_section.dart';
import 'package:nexus/features/remote/presentation/pages/mobile_section.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/oido_section.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/permissions_section.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/secciones_de_ajustes.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/voice_section.dart';

/// Ajustes, como hoja sobre la sala.
///
/// 🔴 **No tapa la pantalla.** A pantalla completa la presencia desaparecía y
/// Ajustes se volvía otra app pegada al lado; como hoja a la derecha, la sala
/// sigue a la vista —atenuada— y se entra, se decide y se vuelve. Pulsar la
/// sala cierra la hoja, igual que Esc. Ver `nexus-orbe-plasma.html`, `#ajustes`.
///
/// Las secciones van agrupadas en las cinco preguntas de [PreguntaDeAjustes]:
/// dieciocho enlaces en fila obligaban a leerlos todos para encontrar uno.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key, this.abreEn = SeccionDeAjustes.permissions});

  /// Dónde se abre. Por defecto en Permisos, que es la sección del día a día y
  /// la que busca quien llega sin carpeta emparejada.
  final SeccionDeAjustes abreEn;

  /// Se abre desde varios sitios —el botón de la barra, el de «empareja una
  /// carpeta», ⌘, y el menú de macOS—, y algunos pueden coincidir en la misma
  /// pulsación. Apilar dos ajustes deja al usuario cerrando la misma pantalla
  /// dos veces, así que el segundo no hace nada.
  static bool _isOpen = false;

  /// La última sección que se miró, para abrir donde se dejó.
  ///
  /// En memoria y no en disco: volver a Ajustes a los dos minutos para
  /// terminar lo que se estaba haciendo es el caso; al día siguiente, Permisos
  /// vuelve a ser mejor punto de partida que lo último que se tocó ayer.
  static SeccionDeAjustes? _dondeSeQuedo;

  /// [en] fuerza la sección: quien abre Ajustes porque no hay carpeta donde
  /// trabajar tiene que caer en Permisos, que es donde se empareja, y no en lo
  /// último que miró.
  static Future<void> open(BuildContext context, {SeccionDeAjustes? en}) async {
    if (_isOpen) return;
    _isOpen = true;
    try {
      await Navigator.of(context).push(
        _LaHoja(abreEn: en ?? _dondeSeQuedo ?? SeccionDeAjustes.permissions),
      );
    } finally {
      _isOpen = false;
    }
  }

  /// El ancho de la hoja para una ventana dada.
  ///
  /// Unos siete décimos, como el mockup —900 de 1280—, con suelo y techo: por
  /// debajo de 800 las secciones no caben en su columna, y por encima de 1040
  /// las líneas de las explicaciones se hacen tan largas que cuesta leerlas.
  /// En una ventana más estrecha que el suelo, la hoja la ocupa entera.
  @visibleForTesting
  static double anchoDeLaHoja(double ventana) =>
      (ventana * 0.72).clamp(800.0, 1040.0).clamp(0.0, ventana);

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

/// La ruta de la hoja: transparente, para que la sala se siga pintando detrás.
class _LaHoja extends PageRouteBuilder<void> {
  _LaHoja({required SeccionDeAjustes abreEn})
    : super(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 160),
        pageBuilder: (_, _, _) => SettingsPage(abreEn: abreEn),
        transitionsBuilder: (_, animacion, _, child) {
          final curva = CurvedAnimation(
            parent: animacion,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curva,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0.03, 0),
                end: Offset.zero,
              ).animate(curva),
              child: child,
            ),
          );
        },
      );
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late SeccionDeAjustes _section = widget.abreEn;

  void _ir(SeccionDeAjustes seccion) {
    SettingsPage._dondeSeQuedo = seccion;
    setState(() => _section = seccion);
  }

  void _cerrar() => Navigator.of(context).maybePop();

  @override
  void initState() {
    super.initState();
    // Se relee al abrir Ajustes, no una vez por arranque: crear o borrar un
    // perfil pasa fuera de la app, y con la lista cacheada seguía ofreciendo
    // una cuenta que ya no existía.
    //
    // Después del primer fotograma y no aquí mismo: invalidar durante la
    // construcción del árbol marca el scope como sucio en mitad de su propio
    // build, y Flutter lo corta con «setState() called during build» — la
    // pantalla entera en rojo al abrir Ajustes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(claudeProfilesProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _cerrar},
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            // Estirado a lo alto: sin esto el velo de la sala, que no tiene
            // hijo, medía cero de alto — ni atenuaba ni se podía pulsar.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // La sala, atenuada y a la vista. Pulsarla cierra: es lo que se
              // espera de algo que está encima y no ocupa el sitio.
              Expanded(
                child: GestureDetector(
                  key: const ValueKey('la-sala-detras'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _cerrar,
                  child: ColoredBox(
                    color: colors.scrim.withValues(alpha: 0.45),
                  ),
                ),
              ),
              SizedBox(
                width: SettingsPage.anchoDeLaHoja(constraints.maxWidth),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: colors.rule2)),
                  ),
                  child: Scaffold(
                    backgroundColor: colors.deep,
                    body: IrASeccionDeAjustes(
                      ir: _ir,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SettingsTopBar(onClose: _cerrar),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                NexusSpacing.s6,
                                NexusSpacing.s5,
                                NexusSpacing.s6,
                                0,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 200,
                                    child: _ElIndice(
                                      actual: _section,
                                      onElegir: _ir,
                                    ),
                                  ),
                                  const SizedBox(width: NexusSpacing.s6),
                                  Expanded(child: _LaSeccion(_section)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La sección abierta, con su pregunta encima del título.
///
/// La pregunta dice a qué grupo pertenece lo que se mira sin tener que volver
/// al índice, que es lo que hace que agrupar sirva también dentro.
class _LaSeccion extends StatelessWidget {
  const _LaSeccion(this.seccion);

  final SeccionDeAjustes seccion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          seccion.pregunta.title(strings).toUpperCase(),
          style: NexusTypography.label.copyWith(color: colors.accent),
        ),
        const SizedBox(height: NexusSpacing.s2),
        Text(
          seccion.title(strings),
          style: NexusTypography.title.copyWith(color: colors.ink),
        ),
        const SizedBox(height: NexusSpacing.s5),
        Expanded(
          child: switch (seccion) {
            SeccionDeAjustes.voice => const VoiceSection(),
            SeccionDeAjustes.oido => const OidoSection(),
            SeccionDeAjustes.llaves => const LlavesSection(),
            SeccionDeAjustes.imagenes => const ImagenesSection(),
            SeccionDeAjustes.avisos => const AvisosSection(),
            SeccionDeAjustes.nombres => const NombresSection(),
            SeccionDeAjustes.memoria => const MemoriaSection(),
            SeccionDeAjustes.permissions => const PermissionsSection(),
            SeccionDeAjustes.mobile => const MobileSection(),
            SeccionDeAjustes.history => const HistorySection(),
            SeccionDeAjustes.pruebas => const PruebasSection(),
            SeccionDeAjustes.cuentas => const CuentasSection(),
            SeccionDeAjustes.stats => const StatsSection(),
            SeccionDeAjustes.superpowers => const SuperpowersSection(),
            SeccionDeAjustes.emulators => const EmuladoresSection(),
            SeccionDeAjustes.appearance => const AppearanceSection(),
            SeccionDeAjustes.language => const LanguageSection(),
            SeccionDeAjustes.salidas => const SalidasSection(),
            SeccionDeAjustes.help => const HelpSection(),
          },
        ),
      ],
    );
  }
}

/// El índice: las cinco preguntas, y debajo de cada una sus secciones.
class _ElIndice extends StatelessWidget {
  const _ElIndice({required this.actual, required this.onElegir});

  final SeccionDeAjustes actual;
  final ValueChanged<SeccionDeAjustes> onElegir;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    // 🔴 **Rueda, porque la lista crece con cada sección.** Se pasó del alto al
    // llegar a la decimosexta —8 px medidos— y el fallo no es de esa sección:
    // es que una columna fija se acerca al borde con cada una que se añade, y
    // la que lo cruce se lleva la culpa de todas.
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, pregunta) in PreguntaDeAjustes.values.indexed) ...[
            Padding(
              key: ValueKey('pregunta-${pregunta.name}'),
              padding: EdgeInsets.only(
                top: i == 0 ? 0 : NexusSpacing.s4,
                bottom: NexusSpacing.s1,
                left: NexusSpacing.s3,
              ),
              child: Text(
                pregunta.title(strings).toUpperCase(),
                style: NexusTypography.label.copyWith(color: colors.faint),
              ),
            ),
            for (final section in SeccionDeAjustes.de(pregunta))
              _SectionLink(
                // Con nombre propio: «Voz» aparece dos veces en esta pantalla
                // —el enlace de la izquierda y la modalidad de una carpeta— y
                // sin una llave no hay forma de decir cuál se pulsa.
                key: ValueKey('seccion-${section.name}'),
                label: section.title(strings),
                active: actual == section,
                onTap: () => onElegir(section),
              ),
          ],
        ],
      ),
    );
  }
}

class _SectionLink extends StatelessWidget {
  const _SectionLink({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // El relleno **dentro** del InkWell y no fuera: por fuera, la mitad de
    // abajo de cada enlace era hueco muerto que no respondía al clic. Lo
    // destapó la prueba que abre la pantalla, y el ratón lo sufría igual.
    //
    // Y ancho completo, no el del texto: la columna mide 200 y el área que
    // respondía era del ancho de cada palabra —«Voz» daba tres letras de blanco
    // útil—, así que apuntar a la pestaña corta fallaba más que las largas. Ahora
    // todas valen lo mismo y no queda hueco muerto entre una y la siguiente.
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        // La elegida se marca con la línea de acento a la izquierda, como en el
        // mockup; las demás llevan la tenue, que es la que dibuja el grupo.
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: active ? colors.accent : colors.rule,
              width: active ? 2 : 1,
            ),
          ),
        ),
        padding: EdgeInsets.only(
          top: NexusSpacing.s2,
          bottom: NexusSpacing.s2,
          left: active ? NexusSpacing.s3 - 1 : NexusSpacing.s3,
          right: NexusSpacing.s2,
        ),
        // En `control` y en minúscula de frase, no en rótulo: los rótulos en
        // mayúsculas son ahora las preguntas, y dieciocho enlaces en mayúsculas
        // eran la lista plana que el mockup rechaza.
        child: Text(
          label,
          style: NexusTypography.control.copyWith(
            fontSize: 13,
            color: active ? colors.ink : colors.mute,
          ),
        ),
      ),
    );
  }
}

class _SettingsTopBar extends StatelessWidget {
  const _SettingsTopBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: NexusSpacing.s6,
        vertical: NexusSpacing.s4,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.rule)),
      ),
      child: Row(
        children: [
          // Sin la marca: la sala sigue a la vista a la izquierda con la suya,
          // y repetirla en la hoja la hacía parecer otra ventana.
          //
          // `Expanded` y no `Flexible`: el segundo deja al hijo quedarse
          // pequeño, así que el rótulo medía lo que su texto y «Cerrar» se
          // pegaba a él. Con restricciones ajustadas el rótulo ocupa todo el
          // sobrante y empuja el botón al borde, y en una hoja estrecha sigue
          // encogiendo con puntos suspensivos.
          Expanded(
            child: Text(
              context.strings.settings,
              overflow: TextOverflow.ellipsis,
              style: NexusTypography.label.copyWith(
                color: colors.accent,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(width: NexusSpacing.s5),
          // El interruptor de permisos ya no vive aquí: es del espacio de
          // trabajo entero, y en la cabecera salía en **todas** las secciones
          // sin nada que lo explicase. Se cambia en Permisos, con su título y
          // su explicación, y junto a la caja de escribir.
          OutlinedButton(
            onPressed: onClose,
            child: Text(context.strings.closeEsc),
          ),
        ],
      ),
    );
  }
}
