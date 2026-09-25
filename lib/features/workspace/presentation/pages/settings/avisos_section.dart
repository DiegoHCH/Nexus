import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/agenda/presentation/providers/el_vigilante_de_la_agenda.dart';
import 'package:nexus/features/avisos/presentation/providers/el_que_habla_primero.dart';
import 'package:nexus/features/prs/presentation/providers/el_vigilante_de_los_pr.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/apagado_o_encendido.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/settings_chooser.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Los avisos de agenda: lo único de Nexus que ocurre sin que se lo pidas.
///
/// Nace apagado y la elección es lo primero de la sección, no lo último:
/// toda la app está construida sobre que el trabajo lo disparas tú, así que
/// esto es la excepción y se enseña como tal.
///
/// Cada cosa que habla sola se elige con «Apagado · Encendido» y lo que cuesta
/// al lado, no con un interruptor: un interruptor no dice qué es el otro
/// estado, y aquí el otro estado es justo lo que se está decidiendo.
class AvisosSection extends ConsumerWidget {
  const AvisosSection({super.key});

  /// Las opciones de cuánto antes. Cortas y cerradas: un campo de minutos
  /// invita a escribir 90, y un aviso hora y media antes no saca a nadie de
  /// donde está.
  static const minutos = [2, 5, 10, 15];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final avisos = ref.watch(elVigilanteDeLaAgendaProvider);
    final vigilante = ref.read(elVigilanteDeLaAgendaProvider.notifier);
    final carpetas = ref.watch(workspaceControllerProvider).folders;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Rotulo(strings.avisosOn),
          Text(
            strings.avisosExplainer,
            style: NexusTypography.nota.copyWith(color: colors.mute),
          ),
          const SizedBox(height: NexusSpacing.s3),
          ApagadoOEncendido(
            llave: 'avisos-reuniones',
            encendido: avisos.encendidos,
            costeApagado: strings.avisosCosteApagado,
            costeEncendido: strings.avisosCosteEncendido(
              minutos.contains(avisos.minutos) ? avisos.minutos : 5,
            ),
            onCambiar: (on) => vigilante.cambiar(encendidos: on),
          ),
          const SizedBox(height: NexusSpacing.s5),
          // Los PR mezclados: el otro aviso que ocurre sin que lo pidas, y por
          // eso va aquí y no en una sección propia — quien viene a esta pantalla
          // viene a decidir de qué quiere enterarse solo.
          _Rotulo(strings.avisosPrOn),
          Text(
            strings.avisosPrExplainer,
            style: NexusTypography.nota.copyWith(color: colors.mute),
          ),
          const SizedBox(height: NexusSpacing.s3),
          ApagadoOEncendido(
            llave: 'avisos-pr',
            encendido: ref.watch(losAvisosDePrProvider).value ?? false,
            costeApagado: strings.avisosPrCosteApagado,
            costeEncendido: strings.avisosPrCosteEncendido,
            onCambiar: (on) async {
              await ElVigilanteDeLosPr.cambiar(a: on);
              ref.invalidate(losAvisosDePrProvider);
            },
          ),
          const SizedBox(height: NexusSpacing.s5),
          // Que hable solo: el interruptor de lo único que Nexus hace **sin**
          // que se lo pidan y **con voz**. Va aquí por lo mismo que el de los
          // PR — quien viene a esta pantalla viene a decidir de qué quiere
          // enterarse solo— y va el último porque es el más ruidoso.
          _Rotulo(strings.avisosEnVozAltaOn),
          Text(
            strings.avisosEnVozAltaExplainer,
            style: NexusTypography.nota.copyWith(color: colors.mute),
          ),
          const SizedBox(height: NexusSpacing.s3),
          ApagadoOEncendido(
            llave: 'avisos-en-voz-alta',
            encendido: ref.watch(losAvisosEnVozAltaProvider).value ?? true,
            costeApagado: strings.avisosEnVozAltaCosteApagado,
            costeEncendido: strings.avisosEnVozAltaCosteEncendido,
            onCambiar: (on) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(ElQueHablaPrimero.encendido, on);
              ref.invalidate(losAvisosEnVozAltaProvider);
            },
          ),
          // Y si habla **también** con Nexus delante. Va debajo y no al lado
          // porque solo tiene sentido con lo de arriba encendido, y porque lo
          // que decide es algo que la app no puede saber: con tres pantallas,
          // tenerla delante y estar mirándola dejan de ser lo mismo.
          const SizedBox(height: NexusSpacing.s4),
          _Rotulo(strings.avisosAunqueLaMiresOn),
          ApagadoOEncendido(
            llave: 'avisos-aunque-la-mires',
            encendido: ref.watch(losAvisosAunqueLaMiresProvider).value ?? true,
            costeApagado: strings.avisosAunqueLaMiresCosteApagado,
            costeEncendido: strings.avisosAunqueLaMiresCosteEncendido,
            onCambiar: (on) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(ElQueHablaPrimero.aunqueLaMires, on);
              ref.invalidate(losAvisosAunqueLaMiresProvider);
            },
          ),
          const SizedBox(height: NexusSpacing.s5),
          Text(
            strings.avisosCarpeta,
            style: NexusTypography.label.copyWith(color: colors.faint),
          ),
          const SizedBox(height: NexusSpacing.s2),
          SettingsChooser<String>(
            value: _elegida(avisos.carpeta, carpetas),
            options: ['', for (final carpeta in carpetas) carpeta.path],
            label: (ruta) =>
                ruta.isEmpty ? strings.avisosSinCarpeta : ruta.split('/').last,
            detail: (ruta) => ruta.isEmpty ? '' : ruta,
            onSelected: (ruta) =>
                vigilante.cambiar(carpeta: ruta.isEmpty ? null : ruta),
          ),
          const SizedBox(height: NexusSpacing.s5),
          Text(
            strings.avisosCuanto,
            style: NexusTypography.label.copyWith(color: colors.faint),
          ),
          const SizedBox(height: NexusSpacing.s2),
          SettingsChooser<int>(
            value: minutos.contains(avisos.minutos) ? avisos.minutos : 5,
            options: minutos,
            label: (m) => '$m min',
            onSelected: (m) => vigilante.cambiar(minutos: m),
          ),
          const SizedBox(height: NexusSpacing.s5),
          // 🔴 El botón y la hora juntos, y no el botón solo.
          //
          // La agenda en memoria **envejece sin avisar**: lo que programes a
          // media mañana no está en lo que se leyó al arrancar. Ver a qué hora
          // se leyó es lo que convierte eso en algo que puedes corregir, en vez
          // de en una ausencia de la que nadie se entera.
          //
          // En un `Wrap` y no en una fila: en la columna de la hoja los dos
          // botones y la hora no caben en una línea —117 px de más, medidos— y
          // la hora es lo que se caería, que es justo lo que no puede faltar.
          Wrap(
            spacing: NexusSpacing.s3,
            runSpacing: NexusSpacing.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: avisos.listos
                    ? () => ref
                          .read(elVigilanteDeLaAgendaProvider.notifier)
                          .releer()
                    : null,
                child: Text(strings.avisosReleer),
              ),
              // Oírlo cuando quieras, y no cuando te toque una reunión.
              //
              // Sin esto, la única forma de saber si funciona —o a qué volumen
              // suena, o si falta la llave— es esperar a que pase de verdad. Y
              // ese día es justo el peor para descubrir que no funcionaba.
              //
              // No pide carpeta: no mira el calendario, así que se puede pulsar
              // antes de haber configurado nada.
              OutlinedButton(
                onPressed: () =>
                    ref.read(elVigilanteDeLaAgendaProvider.notifier).probar(),
                child: Text(strings.avisosProbar),
              ),
              Text(switch (avisos.ultimaLectura) {
                final cuando? => strings.avisosLeidoA(_laHora(cuando)),
                null => strings.avisosSinLeer,
              }, style: NexusTypography.data.copyWith(color: colors.faint)),
            ],
          ),
          const SizedBox(height: NexusSpacing.s5),
          Text(
            strings.avisosNota,
            style: NexusTypography.nota.copyWith(color: colors.mute),
          ),
        ],
      ),
    );
  }

  /// La guardada, si sigue emparejada. Una carpeta que se desemparejó dejaría
  /// el selector apuntando a algo que ya no existe, y el vigilante mirando un
  /// calendario que no se puede leer.
  static String _laHora(DateTime cuando) =>
      '${cuando.hour.toString().padLeft(2, '0')}:'
      '${cuando.minute.toString().padLeft(2, '0')}';

  static String _elegida(String? guardada, List<PairedFolder> carpetas) =>
      carpetas.any((c) => c.path == guardada) ? guardada! : '';
}

/// El nombre de cada aviso, encima de su explicación: sin el interruptor, que
/// lo llevaba de título, la elección necesita decir de qué es.
class _Rotulo extends StatelessWidget {
  const _Rotulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: NexusSpacing.s2),
    child: Text(
      texto.toUpperCase(),
      style: NexusTypography.label.copyWith(color: context.colors.faint),
    ),
  );
}
