import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/accent_preference.dart';
import 'package:nexus/core/design_system/theme_preference.dart';
import 'package:nexus/core/i18n/language_preference.dart';
import 'package:nexus/features/assistant/presentation/providers/las_tareas_de_fondo.dart';
import 'package:nexus/features/assistant/presentation/providers/los_trabajos_providers.dart';
import 'package:nexus/features/run/data/datasources/la_ventana_de_la_botonera.dart';
import 'package:nexus/features/run/domain/entities/corrida.dart';
import 'package:nexus/features/run/domain/usecases/como_va_la_corrida.dart';
import 'package:nexus/features/run/domain/usecases/el_freno_de_la_app.dart';
import 'package:nexus/features/run/domain/usecases/la_consola_de_la_app.dart';
import 'package:nexus/features/run/presentation/providers/corridas_providers.dart';
import 'package:nexus/features/run/presentation/providers/la_consola_que_se_abre.dart';
import 'package:nexus/features/run/presentation/providers/la_ventana_del_registro.dart';
import 'package:nexus/features/run/presentation/providers/pasarle_el_error_a_claude.dart';
import 'package:nexus/features/run/presentation/providers/run_providers.dart';
import 'package:nexus/features/run/presentation/state/lo_que_ensena_la_botonera.dart';
import 'package:nexus/features/run/presentation/state/lo_que_pide_la_botonera.dart';

/// La ventana nativa. Aparte para que las pruebas pongan una que apunta.
final laVentanaDeLaBotoneraProvider = Provider<LaVentanaDeLaBotonera>(
  (ref) => const LaVentanaNativaDeLaBotonera(),
);

/// **Lo que corre, en la forma en que la botonera lo enseña.**
///
/// Es lo único que miraba la barra antes —las corridas, los trabajos largos, lo
/// de fondo y la recarga sola— hecho foto en un sitio. Así la barra de dentro y
/// la de fuera no pueden enseñar cosas distintas: las dos se pintan con esto.
final loQueEnsenaLaBotoneraProvider = Provider<LoQueEnsenaLaBotonera>((ref) {
  final abiertas = ref.watch(lasVentanasDelRegistroProvider);
  bool abierta(String deviceId, {required bool sistema}) => abiertas.contains(
    LasVentanasDelRegistro.nombreDe(deviceId, sistema: sistema),
  );

  return LoQueEnsenaLaBotonera(
    corridas: [
      for (final corrida in ref.watch(corridasProvider).values)
        FilaDeCorrida.de(
          corrida,
          registroAbierto: abierta(corrida.deviceId, sistema: false),
          sistemaAbierto: abierta(corrida.deviceId, sistema: true),
        ),
    ],
    // 🔴 **Y los trabajos largos, que también corren con vida propia.**
    // Reportado al usarlo: «¿cómo sé que está corriendo si no hay nada en la
    // vista que lo diga?». Un `/gate` puede tardar minutos y lo único que lo
    // decía era el mensaje de cuando arrancó, que se va hacia arriba en cuanto
    // sigues hablando. Terminado ya no está: lo cuenta la conversación.
    trabajos: [
      for (final MapEntry(key: conversacion, value: trabajo)
          in ref.watch(losTrabajosProvider).entries)
        if (trabajo.corriendo)
          FilaDeTrabajo(
            conversacion: conversacion,
            comando: trabajo.comando,
            ultimaLinea: trabajo.lineas.lastOrNull,
          ),
    ],
    // Y lo que Claude dejó corriendo aparte, que antes no se veía en ninguna
    // parte. La llave del mapa y no el `id` de la tarea: dos conversaciones
    // pueden tener cada una su `t1`.
    deFondo: [
      for (final MapEntry(key: llave, value: tarea)
          in ref.watch(lasTareasDeFondoProvider).entries)
        FilaDeFondo(id: llave, que: tarea.que),
    ],
    recargaSola: ref.watch(autoRecargaProvider),
  );
});

/// Lo que cruza a la ventana: la botonera y **cómo pintarla**.
///
/// El acento se manda ya ajustado al tema, igual que lo recibe la app en su
/// `MaterialApp`: con el color sin ajustar, la de fuera tendría otro tono que
/// la de dentro justo en el tema claro, que es donde se ajusta.
final laFotoDeLaBotoneraProvider = Provider<LaFotoDeLaBotonera>((ref) {
  final claro = !ref.watch(isDarkProvider);
  final acento = ref
      .watch(accentControllerProvider)
      .forBrightness(claro ? Brightness.light : Brightness.dark);
  return LaFotoDeLaBotonera(
    lo: ref.watch(loQueEnsenaLaBotoneraProvider),
    claro: claro,
    acento: acento.toARGB32(),
    idioma: ref.watch(localeProvider).languageCode,
  );
});

/// **Lo que hace cada botón**, esté la barra donde esté.
///
/// Vivía repartido por los widgets de la barra, cada botón con su `ref.read`.
/// Ahora la barra no tiene `ref` —fuera no hay de dónde sacarlo— así que lo que
/// hacen vive aquí, en el motor de la app, y los dos sitios donde puede pintarse
/// la barra piden por el mismo camino.
final atenderLaBotoneraProvider =
    Provider<Future<void> Function(PedidoDeLaBotonera pedido)>(
      (ref) => (pedido) async {
        switch (pedido) {
          case AccionEnLaCorrida(:final deviceId, :final accion):
            final corrida = ref.read(corridasProvider)[deviceId];
            // 🔴 **Solo si ahora mismo se ofrece.** La foto de fuera llega por
            // un canal y puede ir un paso por detrás: un «Recargar» pulsado
            // justo cuando la app pasaba a «parando» no puede mandar una recarga
            // a algo que se está muriendo. Es la misma regla que decide qué
            // botones se pintan, aplicada otra vez al pulsar.
            if (corrida == null ||
                !ComoVaLaCorridaDe.acciones(corrida).contains(accion)) {
              return;
            }
            await _laAccion(ref, corrida, accion);
          case PararElTrabajo(:final conversacion):
            await ref.read(losTrabajosProvider.notifier).parar(conversacion);
          case CambiarLaRecargaSola():
            await ref.read(autoRecargaProvider.notifier).cambiar();
          case EsconderLaBotonera():
            ref.read(laBotoneraDeFueraProvider.notifier).esconder();
        }
      },
    );

Future<void> _laAccion(Ref ref, Corrida corrida, AccionDeCorrida accion) async {
  final controller = ref.read(corridasProvider.notifier);
  final registros = ref.read(lasVentanasDelRegistroProvider.notifier);
  final id = corrida.deviceId;

  switch (accion) {
    // 🔴 **El puente que faltaba, y en el sentido que faltaba.** Al terminar un
    // encargo la app se recarga sola; al revés no había nada, así que un error
    // se veía y arreglarlo pasaba por copiar el bloque a mano. Ahora el error,
    // su traza y la corrida donde pasó se van de un toque a la carpeta de ese
    // proyecto. Ver [ElErrorQueSeLePasa].
    case AccionDeCorrida.pasarleElError:
      await ref.read(pasarleElErrorAClaudeProvider)(corrida);
    case AccionDeCorrida.seguir:
      await controller.seguir(id);
    case AccionDeCorrida.siguienteLinea:
      await controller.seguir(id, paso: PasoDelDepurador.siguiente);
    case AccionDeCorrida.entrar:
      await controller.seguir(id, paso: PasoDelDepurador.entrar);
    case AccionDeCorrida.salir:
      await controller.seguir(id, paso: PasoDelDepurador.salir);
    case AccionDeCorrida.recargar:
      await controller.recargar(deviceId: id);
    case AccionDeCorrida.reiniciar:
      await controller.recargar(deviceId: id, completa: true);
    // 🔴 **El freno se pide, no viene puesto.** Pararse solo es lo que hace un
    // depurador conectado, y una app que se congela sin haberlo pedido se lee
    // como que se colgó.
    case AccionDeCorrida.freno:
      await controller.frenar(id);
    // Solo si esta corrida declaró consola; la ventana se abre sola al arrancar
    // —ver [LaConsolaQueSeAbre]—, así que esto es para volver a ella.
    case AccionDeCorrida.consola:
      final strings = ref.read(stringsProvider);
      await ref.read(abreLaConsolaProvider)(
        url: LaConsolaDeLaApp.urlDe(corrida.consola!),
        // «Consola · ci · POCO F6», como el mockup: la barra de la ventana dice
        // qué es antes que de dónde.
        titulo:
            '${strings.runConsoleCorto} · ${corrida.configuracion} · '
            '${corrida.dispositivo}',
      );
    // Con errores, **abrir** y no alternar: quien viene del aviso quiere leer el
    // error, y un segundo toque que la cierra sería esconderlo.
    case AccionDeCorrida.registro:
      if (corrida.errores > 0) {
        await registros.abre(corrida, sistema: false);
      } else {
        registros.alterna(corrida, sistema: false);
      }
    // 🔴 **Aparte del registro de la corrida, y no dentro.** Aquél es lo que
    // imprime la app; este es lo que dice el sistema del teléfono: el crash
    // nativo, el ANR, el `Fatal signal 11`.
    case AccionDeCorrida.registroDelSistema:
      registros.alterna(corrida, sistema: true);
    case AccionDeCorrida.parar:
      await controller.parar(id);
  }
}

/// Dónde está la botonera ahora mismo.
class ComoEstaLaBotonera {
  const ComoEstaLaBotonera({
    this.fuera = false,
    this.escondida = false,
    this.sinVentana = false,
  });

  /// La ventana nativa está puesta.
  final bool fuera;

  /// Se quitó con la cruz. Vuelve con «Mostrar la botonera» o cuando arranca
  /// algo nuevo.
  final bool escondida;

  /// La ventana no se pudo abrir, y la barra se pinta dentro de Nexus.
  final bool sinVentana;

  ComoEstaLaBotonera copyWith({
    bool? fuera,
    bool? escondida,
    bool? sinVentana,
  }) => ComoEstaLaBotonera(
    fuera: fuera ?? this.fuera,
    escondida: escondida ?? this.escondida,
    sinVentana: sinVentana ?? this.sinVentana,
  );

  @override
  bool operator ==(Object other) =>
      other is ComoEstaLaBotonera &&
      other.fuera == fuera &&
      other.escondida == escondida &&
      other.sinVentana == sinVentana;

  @override
  int get hashCode => Object.hash(fuera, escondida, sinVentana);

  @override
  String toString() =>
      'ComoEstaLaBotonera(fuera: $fuera, escondida: $escondida, '
      'sinVentana: $sinVentana)';
}

/// Lo que toca hacerle a la ventana con una foto nueva.
enum QueHaceLaVentana { abrir, pintar, cerrar, nada }

/// **La botonera en su ventana aparte**: cuándo sale, qué enseña, cuándo se va.
///
/// 🔴 **Pedido así**: «la ventana que muestra corriendo en el dispositivo
/// quisiera que fuera una ventana independiente como los documentos y demás, lo
/// digo porque al no poder salir ocupa espacio de la ventana normal y si está en
/// modo ventana Nexus ocupa mucho espacio». Dentro de Nexus la barra solo podía
/// ir encima de la conversación; fuera va donde la dejes, en otra pantalla
/// también.
///
/// **La regla de cuándo está es la de siempre**: sale cuando algo empieza a
/// correr y se va cuando no queda nada. Lo único nuevo es la cruz —una ventana
/// sin marco no tiene otra forma de quitarse—, y lo escondido vuelve solo
/// cuando **arranca algo nuevo**: esconder la barra de una corrida no es
/// renunciar a enterarse de la siguiente.
///
/// **La app manda, la ventana obedece.** Todo el estado vive aquí; a la ventana
/// se le manda la foto entera cada vez que cambia algo, y lo que se pulsa en
/// ella vuelve como un [PedidoDeLaBotonera] que atiende
/// [atenderLaBotoneraProvider]. Ninguna regla vive en el otro motor.
///
/// 🔴 **Y si la ventana no sale, la barra se queda dentro.** Es lo único que
/// gobierna una app corriendo —pararla, recargarla, pasarle el error—; si el
/// segundo motor no arranca, quedarse sin ella sería dejar la app viva y sin
/// mandos. Por eso [ComoEstaLaBotonera.sinVentana] existe y la pantalla lo mira.
class LaBotoneraDeFuera extends Notifier<ComoEstaLaBotonera> {
  /// La regla entera, aparte para poder probarla sin canal.
  static QueHaceLaVentana decidir({
    required bool hayAlgo,
    required ComoEstaLaBotonera como,
  }) {
    final debeEstar = hayAlgo && !como.escondida && !como.sinVentana;
    if (debeEstar) {
      return como.fuera ? QueHaceLaVentana.pintar : QueHaceLaVentana.abrir;
    }
    return como.fuera ? QueHaceLaVentana.cerrar : QueHaceLaVentana.nada;
  }

  late LaVentanaDeLaBotonera _ventana;

  /// Lo mismo que [ComoEstaLaBotonera.fuera], para cuando ya no hay estado.
  bool _fuera = false;

  @override
  set state(ComoEstaLaBotonera nuevo) {
    _fuera = nuevo.fuera;
    super.state = nuevo;
  }

  /// Quién estaba en la última foto, para saber si arrancó algo nuevo.
  Set<String> _quienes = const {};

  /// Lo último que se le mandó, para no mandar dos veces lo mismo: una línea
  /// nueva de un trabajo rehace la foto aunque la fila diga lo mismo.
  String? _loUltimo;

  @override
  ComoEstaLaBotonera build() {
    _ventana = ref.watch(laVentanaDeLaBotoneraProvider);
    _ventana.alPedir(_atender);
    ref.listen(laFotoDeLaBotoneraProvider, (_, foto) => _sigue(foto));
    // Si la app suelta esto, la ventana no se queda huérfana en la pantalla.
    // Con un campo y no con el estado: al soltarse ya no se puede leer.
    ref.onDispose(() {
      if (_fuera) unawaited(_ventana.cerrar());
    });
    // La primera pasada fuera del `build`: aquí todavía no se puede cambiar el
    // estado, y si al arrancar ya había algo corriendo tiene que salir igual.
    scheduleMicrotask(() {
      if (ref.mounted) _sigue(ref.read(laFotoDeLaBotoneraProvider));
    });
    return const ComoEstaLaBotonera();
  }

  /// La cruz de la ventana.
  void esconder() {
    state = state.copyWith(escondida: true);
    _sigue(ref.read(laFotoDeLaBotoneraProvider));
  }

  /// «Mostrar la botonera», desde la barra de estado. Vuelve a intentar la
  /// ventana aunque la última vez no saliera: lo que falló puede haber sido
  /// de un rato.
  void mostrarOtraVez() {
    state = state.copyWith(escondida: false, sinVentana: false);
    _sigue(ref.read(laFotoDeLaBotoneraProvider));
  }

  void _atender(Map<Object?, Object?> mapa) {
    final pedido = PedidoDeLaBotonera.fromMap(mapa);
    if (pedido == null) return;
    unawaited(ref.read(atenderLaBotoneraProvider)(pedido));
  }

  void _sigue(LaFotoDeLaBotonera foto) {
    final lo = foto.lo;
    final nuevos = lo.quienes.difference(_quienes);
    _quienes = lo.quienes;

    var como = state;
    if (lo.vacia) {
      // Sin nada corriendo se olvida lo de esta tanda: la próxima corrida
      // sale fuera aunque esta se escondiera o la ventana fallara.
      como = como.copyWith(escondida: false, sinVentana: false);
    } else if (nuevos.isNotEmpty) {
      como = como.copyWith(escondida: false);
    }

    final mapa = foto.toMap();
    switch (decidir(hayAlgo: !lo.vacia, como: como)) {
      case QueHaceLaVentana.abrir:
        state = como.copyWith(fuera: true);
        _loUltimo = jsonEncode(mapa);
        unawaited(_abrir(mapa));
      case QueHaceLaVentana.pintar:
        state = como;
        final texto = jsonEncode(mapa);
        if (texto == _loUltimo) return;
        _loUltimo = texto;
        unawaited(_ventana.pintar(mapa));
      case QueHaceLaVentana.cerrar:
        state = como.copyWith(fuera: false);
        _loUltimo = null;
        unawaited(_ventana.cerrar());
      case QueHaceLaVentana.nada:
        state = como;
    }
  }

  Future<void> _abrir(Map<String, Object?> mapa) async {
    final salio = await _ventana.abrir(mapa);
    if (salio || !ref.mounted || !state.fuera) return;
    _loUltimo = null;
    state = state.copyWith(fuera: false, sinVentana: true);
  }
}

final laBotoneraDeFueraProvider =
    NotifierProvider<LaBotoneraDeFuera, ComoEstaLaBotonera>(
      LaBotoneraDeFuera.new,
    );
