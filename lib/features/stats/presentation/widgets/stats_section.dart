import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/stats/domain/entities/usage_stats.dart';
import 'package:nexus/features/stats/domain/usecases/compute_stats.dart';
import 'package:nexus/features/stats/domain/usecases/model_label.dart';
import 'package:nexus/features/stats/presentation/providers/stats_providers.dart';
import 'package:nexus/features/stats/presentation/widgets/activity_heatmap.dart';
import 'package:nexus/features/stats/presentation/widgets/models_chart.dart';
import 'package:nexus/features/workspace/domain/usecases/el_nombre_de_la_cuenta.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

/// Qué se ha hecho con Claude, por cuenta.
///
/// Sale de los transcritos que el propio CLI deja en el disco, que es la única
/// fuente que hay: el endpoint de cuota dice cuánto te queda de la suscripción
/// —eso ya está en la barra—, no qué has hecho con ella.
///
/// 🔴 **Cuatro cifras y una frase, como el mockup.** Eran ocho fichas del mismo
/// peso, y la vista tenía que leerlas todas para encontrar las dos que se
/// miran. Las cuatro que se comparan de un vistazo —sesiones, mensajes,
/// tokens, racha— van en la franja; lo que se lee de pasada —hora punta,
/// modelo favorito, lo cacheado— va en la frase de debajo.
class StatsSection extends ConsumerStatefulWidget {
  const StatsSection({super.key});

  @override
  ConsumerState<StatsSection> createState() => _StatsSectionState();
}

class _StatsSectionState extends ConsumerState<StatsSection> {
  String? _profile;

  /// En 30 días de entrada, como el mockup: «todo» mezcla meses que ya no
  /// dicen nada de cómo se trabaja ahora.
  var _range = StatsRange.days30;
  var _models = false;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    // 🔴 **Con la de siempre dentro**, igual que Superpoderes y por lo mismo:
    // `claudeProfilesProvider` solo lista las `.claude-*`, y en un Mac sin
    // perfiles con nombre esto decía «no hay ninguna cuenta» con el chat
    // funcionando. Ver [lasCuentasParaMirarProvider].
    final profiles = ref.watch(lasCuentasParaMirarProvider).value ?? const [];
    if (profiles.isEmpty) return TextoDeAjustes(strings.statsNoAccounts);
    final nombres = ElNombreDeLaCuenta.paraTodas(
      profiles,
      general: strings.cuentaGeneral,
      mia: strings.cuentaMia,
    );

    // Como en el historial: la cuenta se elige **solo si hay más de una** en
    // el Mac. Con una sola, elegir inventa una frontera donde no la hay.
    final current = profiles.any((profile) => profile.path == _profile)
        ? _profile!
        : profiles.first.path;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (profiles.length > 1) ...[
          ElegirDeAjustes<String>(
            llave: 'cuenta-de-estadisticas',
            opciones: [for (final profile in profiles) profile.path],
            elegida: current,
            nombre: (path) =>
                nombres[profiles.indexWhere((profile) => profile.path == path)],
            onElegir: (path) => setState(() => _profile = path),
          ),
          const SizedBox(height: 9),
        ],
        Wrap(
          spacing: 16,
          runSpacing: 9,
          children: [
            ElegirDeAjustes<StatsRange>(
              llave: 'tramo',
              opciones: StatsRange.values,
              elegida: _range,
              nombre: (range) => switch (range) {
                StatsRange.all => strings.statsRangeAll,
                StatsRange.days30 => strings.statsRange30,
                StatsRange.days7 => strings.statsRange7,
              },
              onElegir: (range) => setState(() => _range = range),
            ),
            // Los modelos, aparte y a la derecha: el mockup no los enseña, y
            // son la otra pregunta —en qué se te va el trabajo— que merece su
            // gráfico sin empujar el resumen hacia abajo.
            ElegirDeAjustes<bool>(
              llave: 'vista',
              opciones: const [false, true],
              elegida: _models,
              nombre: (modelos) =>
                  modelos ? strings.statsModels : strings.statsOverview,
              onElegir: (modelos) => setState(() => _models = modelos),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ref
              .watch(transcriptTurnsProvider(current))
              .when(
                // Leer 186 MB lleva un par de segundos y se hace en otro
                // isolate: la ventana sigue viva, así que aquí basta con decir
                // que se está leyendo.
                loading: () => Align(
                  alignment: Alignment.topLeft,
                  child: EstadoDeAjustes(
                    tono: TonoDeAjustes.apagado,
                    texto: strings.statsReading,
                  ),
                ),
                error: (_, _) => Align(
                  alignment: Alignment.topLeft,
                  child: EstadoDeAjustes(
                    tono: TonoDeAjustes.atencion,
                    texto: strings.statsUnreadable,
                  ),
                ),
                data: (turns) {
                  final stats = ComputeStats.from(
                    turns,
                    _range,
                    now: DateTime.now(),
                  );
                  if (stats.isEmpty) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: TextoDeAjustes(strings.statsNothingYet),
                    );
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: _models
                        ? ModelsChart(stats: stats)
                        : _Overview(stats: stats),
                  );
                },
              ),
        ),
      ],
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.stats});

  final UsageStats stats;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final favorite = stats.favoriteModel;
    final cifra = _Cifra(strings);

    // Lo que se lee de pasada, en una frase. Los tokens en caché van aquí y no
    // como cifra: son de verdad y son enormes —dos órdenes de magnitud por
    // encima de todo lo demás—, así que sumarlos al total convertiría cualquier
    // gráfico en una barra sola, y esconderlos sería contar la mitad.
    final frase = [
      if (stats.peakHour case final hora?)
        strings.statsHoraPunta('${hora.toString().padLeft(2, '0')}:00'),
      if (favorite != null) strings.statsModeloFavorito(modelLabel(favorite)),
      strings.statsRachaMasLarga(stats.longestStreak),
      strings.statsCachedFootnote(cifra.compacta(stats.cached)),
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Cifras(
          cifras: [
            (cifra.entera(stats.sessions), strings.statsSessions),
            (cifra.entera(stats.messages), strings.statsMessages),
            (cifra.compacta(stats.tokens), strings.statsTotalTokens),
            (cifra.entera(stats.currentStreak), strings.statsDiasDeRacha),
          ],
        ),
        const SizedBox(height: 9),
        ActivityHeatmap(days: stats.days),
        const SizedBox(height: 9),
        TextoDeAjustes(frase),
      ],
    );
  }
}

/// Cómo se escribe un número en el idioma elegido: «9.310» y «61 M» en
/// español, «9,310» y «61 M» en inglés.
///
/// Antes iba siempre con coma de miles y «61.0M», que en español se lee como
/// sesenta y uno **con decimales**.
class _Cifra {
  const _Cifra(this.strings);

  final NexusStrings strings;

  String entera(int valor) {
    final digitos = valor.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digitos.length; i++) {
      if (i > 0 && (digitos.length - i) % 3 == 0) {
        buffer.write(strings.separadorDeMiles);
      }
      buffer.write(digitos[i]);
    }
    return buffer.toString();
  }

  String compacta(int valor) {
    String con(double n, String unidad) {
      // Sin decimal a partir de diez: «61 M» y no «61,0 M», que no dice más.
      final texto = n >= 10
          ? n.round().toString()
          : n.toStringAsFixed(1).replaceAll('.', strings.separadorDecimal);
      return '$texto $unidad';
    }

    if (valor >= 1000000) return con(valor / 1000000, 'M');
    if (valor >= 1000) return con(valor / 1000, 'k');
    return '$valor';
  }
}

/// La franja de cifras: cuatro celdas separadas por una línea, cada una con
/// su número grande y su rótulo debajo.
///
/// Una franja y no cuatro tarjetas: la tabla de formas del mockup reserva la
/// tarjeta para lo que se coge, y esto se lee. Las líneas de 1 px son lo que
/// dice que son cuatro medidas de lo mismo.
class _Cifras extends StatelessWidget {
  const _Cifras({required this.cifras});

  final List<(String, String)> cifras;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: colors.rule)),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, (valor, rotulo)) in cifras.indexed)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: i == 0
                      ? null
                      : BoxDecoration(
                          border: Border(left: BorderSide(color: colors.rule)),
                        ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // El número en sans ligera y con cifras tabulares: es lo
                      // que se compara, y en mono de 15 se leía como un
                      // registro y no como una medida.
                      Text(
                        valor,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NexusTypography.subtitleMobile.copyWith(
                          fontSize: 22,
                          height: 1.1,
                          letterSpacing: 0,
                          color: colors.ink,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rotulo.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NexusTypography.label.copyWith(
                          fontSize: 9.5,
                          letterSpacing: 1.1,
                          color: colors.mute,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
