import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/la_hoja_viva_de_las_paginas.dart';
import 'package:nexus/core/i18n/language_preference.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/platform/lo_que_pide_la_pagina.dart';
import 'package:nexus/core/platform/ventana_del_visor.dart';
import 'package:nexus/features/assistant/domain/usecases/el_verbo_de_un_paso.dart';
import 'package:nexus/features/assistant/domain/usecases/la_actividad_como_html.dart';
import 'package:nexus/features/assistant/presentation/orb/nexus_orb_layers_painter.dart';
import 'package:nexus/features/assistant/presentation/providers/assistant_controller.dart';
import 'package:nexus/features/assistant/presentation/state/activity_layout.dart';
import 'package:nexus/features/assistant/presentation/state/assistant_hud_state.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:path_provider/path_provider.dart';

final laVentanaDeActividadProvider = Provider(LaVentanaDeActividad.new);

/// Cómo se pinta y se abre una ventana del visor, como un dato.
///
/// La misma costura que los lanzadores de procesos del punto 3 del repaso: sin
/// ella, comprobar **cuándo se pide abrir** pediría un canal nativo y una
/// ventana de verdad — y lo que se rompe aquí es justo eso, cuándo se pide.
typedef PintarLaVentana =
    Future<bool> Function({
      required String raiz,
      required String nombre,
      required String html,
      required bool primeraVez,
      double ancho,
      double alto,
    });

/// Abre lo que está haciendo el encargo **en una ventana aparte**.
///
/// Esto empezó siendo un diálogo dentro de la app, y estaba mal: un diálogo se
/// pone encima y **no deja hacer otra cosa** mientras lo miras, que es
/// exactamente lo contrario de lo que hace falta con algo que tarda minutos. La
/// pasada de pruebas ya lo había resuelto —se escribe una página y se abre con
/// el visor de documentos, que es una ventana del sistema de verdad— y aquí se
/// usa lo mismo.
///
/// Se puede mover, dejar al lado y seguir trabajando; y como el visor vigila el
/// archivo y se recarga solo, la de un encargo en curso **avanza sola** sin que
/// haya que sincronizar nada.
class LaVentanaDeActividad {
  LaVentanaDeActividad(this._ref, {this.pinta = VentanaDelVisor.pinta});

  final Ref _ref;

  /// Con qué se escribe y se abre. Ver [PintarLaVentana].
  final PintarLaVentana pinta;

  /// A qué conversaciones se les está repintando la ventana. Una por
  /// conversación: la ruta es estable, así que reescribirla actualiza la que ya
  /// está delante en vez de abrir otra en cada paso.
  final Map<String, ProviderSubscription<AssistantHudState>> _siguiendo = {};

  /// El botón de parar de la ventana llega por aquí.
  ///
  /// La página es estática y su botón un enlace `nexus://detener/<id>`; el
  /// visor lo intercepta y lo reenvía. El identificador viaja en la ruta porque
  /// **puede haber varias ventanas abiertas** —una por conversación— y «parar»
  /// a secas no diría cuál.
  ///
  /// Se pone una sola vez y no por ventana: el despachador reparte por lo que
  /// se pide, así que dos oyentes de `detener` serían dos respuestas a un clic.
  void _atiendeElParar() {
    if (_atendiendo) return;
    _atendiendo = true;
    LoQuePideLaPagina.escuchar('detener', (ruta) {
      final id = ruta.replaceAll('/', '');
      if (id.isEmpty || !_siguiendo.containsKey(id)) return;
      unawaited(_ref.read(assistantControllerProvider(id).notifier).stopWork());
    });
  }

  bool _atendiendo = false;

  /// El encargo en curso, avanzando en su ventana.
  Future<void> seguir(String conversationId) async {
    _atiendeElParar();
    final yaSeSeguia = _siguiendo.containsKey(conversationId);
    // 🔴 **Pulsar el botón abre, siempre.** Antes `primeraVez` quería decir «la
    // primera vez de esta conversación», así que en cuanto **cerrabas** la
    // ventana el botón se quedaba muerto: nadie se entera de que la cerraste
    // —es una ventana del sistema, no nuestra— y a partir de ahí el botón solo
    // reescribía el archivo. Reportado tal cual: «abrí el paso a paso, lo cerré,
    // y ahora le doy y no puedo abrirlo».
    //
    // Abrir la que ya está abierta no molesta: el visor la trae al frente, que
    // es lo que quiere quien la busca debajo de otras ventanas. Lo que sigue
    // distinguiéndose es el **repintado automático**, que no abre nada.
    await _pinta(conversationId, primeraVez: true);
    if (yaSeSeguia) return;

    // 🔴 **Se escucha por el contenedor, no con `watch`.** Esto no es un widget:
    // nadie lo reconstruye, así que la suscripción se abre a mano y se guarda —
    // `Ref.listen` está pensado para usarse mientras se construye un proveedor,
    // y esto ocurre cuando alguien pulsa un botón, mucho después.
    //
    // Y se filtra por lo que se pinta —los pasos y si sigue viva— porque el
    // estado cambia por veinte motivos más (el subtítulo, cada trozo de texto
    // que llega) y repintar en todos sería un archivo por letra.
    _siguiendo[conversationId] = _ref.container.listen(
      assistantControllerProvider(conversationId),
      (AssistantHudState? antes, AssistantHudState ahora) {
        final cambio =
            !identical(antes?.activity, ahora.activity) ||
            (antes?.orbState == NexusOrbState.think) !=
                (ahora.orbState == NexusOrbState.think);
        if (cambio) unawaited(_pinta(conversationId, primeraVez: false));
      },
    );
  }

  /// Deja de seguir una conversación y suelta lo suyo.
  ///
  /// 🔴 **Esta suscripción no se cerraba nunca, y era la que sujetaba el resto.**
  /// El mapa de arriba solo se consultaba y se llenaba: no había un `remove` en
  /// todo el archivo. Cada conversación seguida dejaba viva su suscripción y,
  /// con ella, **el `assistantControllerProvider` de esa conversación** —con sus
  /// mensajes, sus pasos y sus búferes— aunque la hubieras cerrado hacía horas.
  ///
  /// Abrir y cerrar conversaciones durante una jornada no liberaba ni una.
  void olvidar(String conversationId) {
    _siguiendo.remove(conversationId)?.close();
  }

  /// Lo que dio de sí un turno que ya terminó.
  ///
  /// No se sigue nada: esa lista no va a cambiar nunca más. Y lleva **su
  /// propio archivo** —el del primer paso, que es único— para que dos turnos
  /// puedan estar abiertos a la vez y compararse, que es media razón para
  /// querer una ventana en vez de un diálogo.
  Future<void> ver(List<ActivityItem> pasos) async {
    if (pasos.isEmpty) return;
    await _escribe(
      nombre: 'pasos-${_limpio(pasos.first.id)}',
      pasos: pasos,
      viva: false,
      primeraVez: true,
    );
  }

  Future<void> _pinta(String conversationId, {required bool primeraVez}) {
    final hud = _ref.read(assistantControllerProvider(conversationId));
    return _escribe(
      nombre: 'actividad-${_limpio(conversationId)}',
      pasos: hud.activity,
      viva: hud.orbState == NexusOrbState.think,
      primeraVez: primeraVez,
      // Solo la ventana en vivo lleva botón de parar. La de un turno cerrado no
      // tiene nada que parar, y un botón que no hace nada enseña a no pulsarlo.
      detenerEn: conversationId,
    );
  }

  Future<void> _escribe({
    required String nombre,
    required List<ActivityItem> pasos,
    required bool viva,
    required bool primeraVez,
    String? detenerEn,
  }) async {
    // **Fuera de la carpeta emparejada, y no por orden.** Escribir aquí dentro
    // del repo dejaría un archivo sin trackear en el árbol, y eso lo recoge el
    // resumen de «lo que tocó este encargo» — la ventana que enseña lo que hizo
    // acabaría contándose a sí misma.
    final soporte = await getApplicationSupportDirectory();
    final s = _ref.read(stringsProvider);
    final hoja = await laHojaViva(_ref);

    await pinta(
      raiz: soporte.path,
      nombre: nombre,
      primeraVez: primeraVez,
      // La pantalla del mockup, con el orbe a la izquierda y los pasos a la
      // derecha, **en pequeño**: el mockup la dibuja a 1280 × 800, y a ese
      // tamaño taparía la app que se quiere seguir usando al lado. La página
      // se reparte igual a este ancho y, si se estrecha, pone el orbe encima.
      ancho: 1040,
      alto: 680,
      html: LaActividadComoHtml.escribe(
        filas: layoutActivity(pasos),
        // El mismo aro que el orbe trabajando, con su mismo reparto: lo que se
        // ve de lejos en la sala y de cerca en esta ventana tiene que coincidir.
        reactor: _elReactor(pasos),
        viva: viva,
        detenerEn: detenerEn,
        textos: textosDeActividad(s),
        hoja: hoja,
      ),
    );
  }

  static ({int total, int encendidos}) _elReactor(List<ActivityItem> pasos) {
    final cuenta = laCuentaDelTurno(pasos);
    final aro = reactorEncendido(pasos: cuenta.pasos, hechos: cuenta.hechos);
    return (total: aro.total, encendidos: aro.encendidos);
  }

  /// El nombre va a una ruta de archivo, así que lo que no sea seguro se cae.
  static String _limpio(String crudo) =>
      crudo.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
}

/// Los textos de la ventana en el idioma elegido. Aparte para que las pruebas
/// pinten la página con los mismos que la app.
TextosDeActividad textosDeActividad(NexusStrings s) => TextosDeActividad(
  titulo: s.rightNow,
  rotulo: s.actividadRotulo,
  paso: s.pasoDeTotal,
  verbo: (verbo, {required hecho}) {
    final par = switch (verbo) {
      VerboDelPaso.lee => s.verboLee,
      VerboDelPaso.escribe => s.verboEscribe,
      VerboDelPaso.edita => s.verboEdita,
      VerboDelPaso.ejecuta => s.verboEjecuta,
      VerboDelPaso.busca => s.verboBusca,
      VerboDelPaso.delega => s.verboDelega,
      VerboDelPaso.consulta => s.verboConsulta,
      VerboDelPaso.otro => s.verboOtro,
    };
    return hecho ? par.hecho : par.ahora;
  },
  seEjecuto: s.ranLabel,
  devolvio: s.returnedLabel,
  todaviaCorriendo: s.stillRunning,
  sinPasos: s.noStepsYet,
  detener: s.stopNow,
  espera: s.pasoEspera,
);
