import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/agenda/presentation/providers/el_vigilante_de_la_agenda.dart';
import 'package:nexus/features/avisos/presentation/providers/el_que_habla_primero.dart';
import 'package:nexus/features/prs/presentation/providers/el_vigilante_de_los_pr.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/apagado_o_encendido.dart';
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
    final strings = context.strings;
    final avisos = ref.watch(elVigilanteDeLaAgendaProvider);
    final vigilante = ref.read(elVigilanteDeLaAgendaProvider.notifier);
    final carpetas = ref.watch(workspaceControllerProvider).folders;
    final cuanto = minutos.contains(avisos.minutos) ? avisos.minutos : 5;
    final enVozAlta = ref.watch(losAvisosEnVozAltaProvider).value ?? true;

    return BloquesDeAjustes(
      bloques: [
        BloqueDeAjustes(
          rotulo: strings.avisosOn,
          hijos: [
            TextoDeAjustes(strings.avisosExplainer),
            // Lo que cuesta, solo en «Encendido» y en minutos: es lo único que
            // cambia de un día a otro, y «ninguna reunión suena» al lado de
            // «Apagado» decía lo mismo dos veces.
            ApagadoOEncendido(
              llave: 'avisos-reuniones',
              encendido: avisos.encendidos,
              costeEncendido: strings.avisosCosteEncendido(cuanto),
              onCambiar: (on) => vigilante.cambiar(encendidos: on),
            ),
          ],
        ),
        BloqueDeAjustes(
          rotulo: strings.avisosCuanto,
          hijos: [
            // Cortas y cerradas: un campo de minutos invita a escribir 90, y un
            // aviso hora y media antes no saca a nadie de donde está.
            ElegirDeAjustes<int>(
              llave: 'avisos-cuanto',
              opciones: minutos,
              elegida: cuanto,
              nombre: (m) => '$m min',
              onElegir: (m) => vigilante.cambiar(minutos: m),
            ),
          ],
        ),
        // Dónde mira: el calendario es el de la cuenta de Claude de una
        // carpeta. No está en el mockup, que supone una sola cuenta; con dos,
        // sin elegirla no hay calendario que leer.
        BloqueDeAjustes(
          rotulo: strings.avisosCarpeta,
          hijos: [
            ElegirDeAjustes<String>(
              llave: 'avisos-carpeta',
              opciones: ['', for (final carpeta in carpetas) carpeta.path],
              elegida: _elegida(avisos.carpeta, carpetas),
              nombre: (ruta) => ruta.isEmpty
                  ? strings.avisosSinCarpeta
                  : ruta.split('/').last,
              onElegir: (ruta) =>
                  vigilante.cambiar(carpeta: ruta.isEmpty ? null : ruta),
            ),
          ],
        ),
        // Los PR mezclados: el otro aviso que ocurre sin que lo pidas, y por
        // eso va aquí y no en una sección propia — quien viene a esta pantalla
        // viene a decidir de qué quiere enterarse solo.
        BloqueDeAjustes(
          rotulo: strings.avisosPrOn,
          hijos: [
            TextoDeAjustes(strings.avisosPrExplainer),
            ApagadoOEncendido(
              llave: 'avisos-pr',
              encendido: ref.watch(losAvisosDePrProvider).value ?? false,
              onCambiar: (on) async {
                await ElVigilanteDeLosPr.cambiar(a: on);
                ref.invalidate(losAvisosDePrProvider);
              },
            ),
          ],
        ),
        // Lo único que Nexus hace **sin** que se lo pidan y **con voz**, dicho
        // como el mockup: dos maneras de enterarse, con su nombre, en vez de
        // «que me lo diga en voz alta: apagado».
        BloqueDeAjustes(
          rotulo: strings.avisosEnVozAltaOn,
          hijos: [
            ElegirDeAjustes<bool>(
              llave: 'avisos-en-voz-alta',
              opciones: const [true, false],
              elegida: enVozAlta,
              nombre: (alta) => alta
                  ? strings.avisosEnVozAlta
                  : strings.avisosSoloNotificacion,
              onElegir: (on) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool(ElQueHablaPrimero.encendido, on);
                ref.invalidate(losAvisosEnVozAltaProvider);
              },
            ),
            // Y si habla **también** con Nexus delante. Va debajo y solo con
            // la voz alta elegida, porque sin ella no hay nada que callar, y
            // porque decide algo que la app no puede saber: con tres
            // pantallas, tenerla delante y estar mirándola no son lo mismo.
            if (enVozAlta) ...[
              RotuloDeAjustes(strings.avisosAunqueLaMiresOn),
              ApagadoOEncendido(
                llave: 'avisos-aunque-la-mires',
                encendido:
                    ref.watch(losAvisosAunqueLaMiresProvider).value ?? true,
                costeApagado: strings.avisosAunqueLaMiresCosteApagado,
                costeEncendido: strings.avisosAunqueLaMiresCosteEncendido,
                onCambiar: (on) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool(ElQueHablaPrimero.aunqueLaMires, on);
                  ref.invalidate(losAvisosAunqueLaMiresProvider);
                },
              ),
            ],
            // 🔴 La hora y los botones juntos, y no los botones solos.
            //
            // La agenda en memoria **envejece sin avisar**: lo que programes a
            // media mañana no está en lo que se leyó al arrancar. Ver a qué
            // hora se leyó es lo que convierte eso en algo que puedes
            // corregir, en vez de en una ausencia de la que nadie se entera.
            EstadoDeAjustes(
              tono: avisos.ultimaLectura == null
                  ? TonoDeAjustes.apagado
                  : TonoDeAjustes.bien,
              texto: switch (avisos.ultimaLectura) {
                final cuando? => strings.avisosLeidoA(_laHora(cuando)),
                null => strings.avisosSinLeer,
              },
            ),
            AccionesDeAjustes(
              botones: [
                BotonDeAjustes(
                  texto: strings.avisosReleer,
                  tono: TonoDeBoton.principal,
                  onPulsar: avisos.listos ? vigilante.releer : null,
                ),
                // Oírlo cuando quieras, y no cuando te toque una reunión.
                //
                // Sin esto, la única forma de saber si funciona —o a qué
                // volumen suena, o si falta la llave— es esperar a que pase de
                // verdad. Y ese día es justo el peor para descubrirlo.
                //
                // No pide carpeta: no mira el calendario, así que se puede
                // pulsar antes de haber configurado nada.
                BotonDeAjustes(
                  texto: strings.avisosProbar,
                  onPulsar: vigilante.probar,
                ),
              ],
            ),
          ],
        ),
      ],
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
