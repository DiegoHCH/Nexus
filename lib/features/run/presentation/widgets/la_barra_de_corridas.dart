import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/run/domain/usecases/como_va_la_corrida.dart';
import 'package:nexus/features/run/presentation/state/lo_que_ensena_la_botonera.dart';
import 'package:nexus/features/run/presentation/state/lo_que_pide_la_botonera.dart';

/// **La barra de corridas, sin saber dónde vive.** Solo pinta y avisa.
///
/// 🔴 **Sin un solo provider, y es lo que la deja salir de la ventana.** La
/// botonera vive ahora en su propia ventana nativa, con otro motor de Flutter,
/// y ahí no hay Riverpod que leer: hay una foto que llega por un canal
/// ([LoQueEnsenaLaBotonera]) y un canal por donde decir qué se pulsó
/// ([PedidoDeLaBotonera]). Con los `ref.watch` dentro, esta barra solo podía
/// existir en el motor de la app — y reescribirla para la ventana serían dos
/// barras que alguien tendría que mantener iguales para siempre.
///
/// Así que la misma barra se pinta en los dos sitios: en la ventana de fuera,
/// que es donde va, y dentro de Nexus solo si esa ventana no se pudo abrir.
/// Ver `LaBotoneraDeCorridas`.
///
/// **Solo se ofrece lo que tiene plomería**: un botón antes que su tubería
/// sería enseñar algo que no hace nada. Qué se ofrece y en qué orden lo decide
/// [ComoVaLaCorridaDe] al hacer la foto, que es donde está la regla del mockup
/// —la acción que toca, primero—.
class LaBarraDeCorridas extends StatelessWidget {
  const LaBarraDeCorridas({
    super.key,
    required this.lo,
    required this.onPedido,
    this.onEmpezarArrastre,
    this.onArrastrar,
    this.onSoltar,
    this.sePuedeEsconder = false,
    this.conSombra = true,
    this.pedirPermisoDelEspejo = false,
  });

  final LoQueEnsenaLaBotonera lo;

  /// Lo que se pulsó. Quien lo atiende es la app, esté la barra donde esté.
  final ValueChanged<PedidoDeLaBotonera> onPedido;

  /// El asa. Dentro de Nexus la barra se mueve con [onArrastrar]; fuera se
  /// mueve la ventana entera, y a quien la mueve le basta saber cuándo empieza
  /// y cuándo se suelta.
  final VoidCallback? onEmpezarArrastre;
  final ValueChanged<Offset>? onArrastrar;
  final VoidCallback? onSoltar;

  /// La cruz del asa. Solo fuera: dentro de Nexus no hay dónde esconderla que
  /// no sea dejar la corrida sin mandos, y fuera se trae de vuelta desde la
  /// barra de estado.
  final bool sePuedeEsconder;

  /// Dentro de Nexus la sombra es lo único que dice que la barra está encima y
  /// no dentro de la pantalla. Fuera la pone el sistema, que la dibuja fuera
  /// del marco: una sombra de Flutter ahí se cortaría en el borde de la ventana.
  final bool conSombra;

  /// La pregunta por el permiso de Accesibilidad, al pie. Ver
  /// [LaFotoDeLaBotonera.pedirPermisoDelEspejo].
  final bool pedirPermisoDelEspejo;

  /// Ancho fijo y no el del contenido: con el ancho al gusto, la barra cambia
  /// de tamaño al cambiar el texto del progreso —«Running Gradle task…»— y se
  /// mueve sola debajo del ratón.
  ///
  /// 430 y no los 380 de antes: es la medida del mockup, y la que deja caber
  /// «Corriendo · 2» y «Recargar sola al terminar» en el asa sin cortar
  /// ninguna de las dos. Las acciones ya no cuentan, que van debajo y se parten
  /// en líneas. **La ventana de fuera mide lo mismo**: ver `NexusBotonera`.
  static const ancho = 430.0;

  /// El punto de estado de cada corrida, para que las pruebas miren su color.
  static const elPunto = ValueKey('el-punto-de-la-corrida');

  /// La opción de recargar sola, en el asa.
  static const laRecargaSola = ValueKey('recargar-sola');

  /// La cruz que la esconde, solo fuera.
  static const laCruz = ValueKey('esconder-la-botonera');

  /// La pregunta por el permiso del espejo.
  static const elPermiso = ValueKey('el-permiso-del-espejo');

  /// La barra en sí, para poder medir **dónde acabó**.
  static const laLlave = ValueKey('la-botonera-de-corridas');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      key: laLlave,
      color: Colors.transparent,
      child: Container(
        width: ancho,
        decoration: BoxDecoration(
          color: colors.deep,
          // `rule2`, el filo de lo que va encima, como el panel de correr.
          border: Border.all(color: colors.rule2),
          borderRadius: BorderRadius.circular(NexusRadius.md),
          boxShadow: [
            if (conSombra)
              BoxShadow(
                color: colors.void_.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ElAsa(
              cuantas: lo.cuantas,
              recargaSola: lo.recargaSola,
              onPedido: onPedido,
              onEmpezarArrastre: onEmpezarArrastre,
              onArrastrar: onArrastrar,
              onSoltar: onSoltar,
              sePuedeEsconder: sePuedeEsconder,
            ),
            for (final corrida in lo.corridas)
              _Corrida(fila: corrida, onPedido: onPedido),
            for (final trabajo in lo.trabajos)
              _UnTrabajo(fila: trabajo, onPedido: onPedido),
            for (final tarea in lo.deFondo) _UnaTareaDeFondo(fila: tarea),
            if (pedirPermisoDelEspejo) _ElPermisoDelEspejo(onPedido: onPedido),
          ],
        ),
      ),
    );
  }
}

/// **La pregunta por el permiso**, al pie: es lo más cerca del espejo, que es
/// de lo que habla.
///
/// 🔴 **En la barra y no en un diálogo.** Se pregunta en el momento en que
/// hace falta —hay un espejo que pegar— y donde ya estás mirando, sin tapar
/// nada. Y **una sola vez**: con «Ahora no» el espejo sigue siendo su ventana
/// de siempre, que es exactamente lo que había antes, y volver a preguntar en
/// cada corrida sería insistir en algo que ya se contestó.
class _ElPermisoDelEspejo extends StatelessWidget {
  const _ElPermisoDelEspejo({required this.onPedido});

  final ValueChanged<PedidoDeLaBotonera> onPedido;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return Container(
      key: LaBarraDeCorridas.elPermiso,
      padding: const EdgeInsets.all(NexusSpacing.s3),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.rule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.runEspejoPermiso,
            style: NexusTypography.nota.copyWith(
              fontSize: 12,
              color: colors.mute,
            ),
          ),
          const SizedBox(height: NexusSpacing.s2),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              BotonDeFila(
                texto: strings.runEspejoPermitir,
                tono: TonoDeBoton.principal,
                onPulsar: () => onPedido(const PermitirElEspejo()),
              ),
              BotonDeFila(
                texto: strings.runEspejoAhoraNo,
                onPulsar: () => onPedido(const NoPegarElEspejo()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Una tarea que Claude dejó corriendo aparte.
///
/// 🔴 **Sin botón de parar, y es a propósito.** Lo de al lado —[_UnTrabajo]—
/// corre con Nexus de padre y por eso se puede matar desde aquí; esto vive
/// **dentro del proceso de Claude** y quien lo gobierna es él. Un botón que
/// dijera «parar» y no parase nada sería peor que no tenerlo: para eso está
/// «detener», que se lleva el turno entero.
class _UnaTareaDeFondo extends StatelessWidget {
  const _UnaTareaDeFondo({required this.fila});

  final FilaDeFondo fila;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        NexusSpacing.s3,
        NexusSpacing.s2,
        NexusSpacing.s3,
        NexusSpacing.s2,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.rule)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 7,
            height: 7,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: colors.accent,
            ),
          ),
          const SizedBox(width: NexusSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fila.que,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NexusTypography.data.copyWith(color: colors.ink),
                ),
                Text(
                  context.strings.laTareaDeFondo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NexusTypography.control.copyWith(color: colors.accent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// El asa, con cuántas cosas corren y lo que vale para todas a la vez.
///
/// **«Corriendo · 2» y no solo «Corriendo»**, como el mockup: el número dice sin
/// contar filas si lo que tienes delante es una corrida o tres, y es lo primero
/// que se mira al volver a la ventana.
///
/// **Se arrastra solo por aquí** y no por toda la barra: si se arrastra desde
/// cualquier parte, el primer clic torcido sobre «parar» mueve la barra en vez
/// de parar, y lo que se busca es lo contrario.
class _ElAsa extends StatelessWidget {
  const _ElAsa({
    required this.cuantas,
    required this.recargaSola,
    required this.onPedido,
    required this.sePuedeEsconder,
    this.onEmpezarArrastre,
    this.onArrastrar,
    this.onSoltar,
  });

  final int cuantas;
  final bool recargaSola;
  final ValueChanged<PedidoDeLaBotonera> onPedido;
  final bool sePuedeEsconder;
  final VoidCallback? onEmpezarArrastre;
  final ValueChanged<Offset>? onArrastrar;
  final VoidCallback? onSoltar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.rule)),
      ),
      child: Row(
        children: [
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: GestureDetector(
                onPanStart: (_) => onEmpezarArrastre?.call(),
                onPanUpdate: (detalle) => onArrastrar?.call(detalle.delta),
                onPanEnd: (_) => onSoltar?.call(),
                // Sin esto el asa solo agarra donde hay tinta, que son cuatro
                // puntos de un icono de 14 px.
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: NexusSpacing.s3,
                    vertical: NexusSpacing.s2,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.drag_indicator, size: 14, color: colors.faint),
                      const SizedBox(width: NexusSpacing.s2),
                      Flexible(
                        child: Text(
                          '${strings.runToolbarDrag} · $cuantas'.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NexusTypography.label.copyWith(
                            color: colors.mute,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // **Una opción con nombre y no un rayo suelto.** El icono solo no decía
          // qué hacía ni si estaba encendido: había que pararse encima. Ahora se
          // lee, y el relleno de acento dice si está puesta. **Apagada de
          // fábrica**: recargar sin que nadie lo pida es una sorpresa la primera
          // vez. Va en el asa y no en cada fila porque es una preferencia de
          // quien mira, no una propiedad de una corrida.
          //
          // Flexible y no a su ancho: si el nombre no cabe se corta él, y el asa
          // —que es por donde se agarra la barra— nunca se queda sin sitio.
          Flexible(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.only(
                right: sePuedeEsconder ? NexusSpacing.s1 : NexusSpacing.s2,
              ),
              child: Tooltip(
                message: strings.runAuto,
                child: Filtro(
                  key: LaBarraDeCorridas.laRecargaSola,
                  texto: '⚡ ${strings.runAutoCorto}',
                  activo: recargaSola,
                  onPulsar: () => onPedido(const CambiarLaRecargaSola()),
                ),
              ),
            ),
          ),
          // Fuera, la ventana no tiene marco ni botón de cerrar: sin esto, la
          // única forma de quitarla de en medio sería parar lo que corre.
          if (sePuedeEsconder)
            Padding(
              padding: const EdgeInsets.only(right: NexusSpacing.s2),
              child: BotonMini(
                key: LaBarraDeCorridas.laCruz,
                icono: Icons.close_rounded,
                titulo: strings.runToolbarEsconder,
                onPulsar: () => onPedido(const EsconderLaBotonera()),
              ),
            ),
        ],
      ),
    );
  }
}

/// El color del punto de una corrida. Va con su frase al lado, nunca solo.
Color colorDeLaCorrida(ComoVaLaCorrida como, NexusColors colors) =>
    switch (como) {
      ComoVaLaCorrida.corriendo => colors.ok,
      ComoVaLaCorrida.conErrores => colors.err,
      ComoVaLaCorrida.parada => colors.warn,
      // El acento y no el ámbar: compilar no es «atención», es «está
      // pasando». Antes salía ámbar y se confundía con la app parada en un
      // punto de ruptura.
      ComoVaLaCorrida.arrancando => colors.accent,
      ComoVaLaCorrida.parando => colors.faint,
    };

/// Una corrida: qué es, cómo va y qué se le puede pedir.
///
/// Una fila por corrida y no una barra que apunte a la elegida: el código ya
/// contempla varias a la vez, y con una sola barra el botón de parar es una
/// ruleta salvo que se añada un selector.
///
/// 🔴 **El estado va en el punto, y el punto dice la verdad.** Antes solo sabía
/// de verde y ámbar: una app rompiéndose en cada fotograma salía verde, con el
/// contador rojo escondido entre los iconos, y una compilando salía del mismo
/// ámbar que una parada en un punto de ruptura. Ahora son los tres del mockup
/// —verde corriendo, rojo con errores, ámbar parada— y la segunda línea lo dice
/// con palabras. Ver [ComoVaLaCorridaDe].
///
/// **Las acciones van debajo del nombre, escritas**, y la que toca primero. Al
/// lado del nombre solo cabían iconos, y ocho iconos grises seguidos se pulsan a
/// ciegas.
class _Corrida extends StatelessWidget {
  const _Corrida({required this.fila, required this.onPedido});

  final FilaDeCorrida fila;
  final ValueChanged<PedidoDeLaBotonera> onPedido;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    final detalle = switch (fila.como) {
      ComoVaLaCorrida.parada => switch (fila.paradaEn) {
        final donde? => strings.runParadaEn(donde),
        null => strings.runParadaSinSitio,
      },
      ComoVaLaCorrida.arrancando => fila.progreso ?? strings.runCompiling,
      ComoVaLaCorrida.conErrores => strings.runErroresDesdeLaRecarga(
        fila.errores,
      ),
      ComoVaLaCorrida.corriendo => strings.runRunning,
      ComoVaLaCorrida.parando => strings.runStopping,
    };
    // El progreso de Gradle es un dato —«Running Gradle task
    // 'assembleCiDebug'…»— y se lee en mono; el resto es una frase de estado.
    final comoDato =
        fila.como == ComoVaLaCorrida.arrancando && fila.progreso != null;

    return Container(
      key: ValueKey('corrida-${fila.deviceId}'),
      padding: const EdgeInsets.fromLTRB(
        NexusSpacing.s3,
        NexusSpacing.s2,
        NexusSpacing.s3,
        NexusSpacing.s3,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.rule)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, right: NexusSpacing.s3),
            child: PuntoDeEstado(
              key: LaBarraDeCorridas.elPunto,
              color: colorDeLaCorrida(fila.como, colors),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // **Con qué y dónde**, como el mockup: «ci · POCO F6». Solo el
                // dispositivo no contestaba «¿esto es ci o preprod?», que es lo
                // que se pregunta con dos corridas a la vez.
                //
                // En la voz de lo que se dice y no en mono: son dos nombres, y
                // en mono se leían como un identificador.
                Text(
                  '${fila.configuracion} · ${fila.dispositivo}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NexusTypography.body.copyWith(
                    fontSize: 13,
                    color: colors.ink,
                  ),
                ),
                // **El estado en su propia línea.** Detrás del nombre se cortaba
                // —«Medium Phone API 36.1 · R…», con la R de «Running Gradle
                // task»— y es lo único que dice que algo está pasando.
                Text(
                  detalle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (comoDato
                              ? NexusTypography.data
                              : NexusTypography.nota.copyWith(fontSize: 12))
                          .copyWith(color: colors.mute),
                ),
                const SizedBox(height: NexusSpacing.s2),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final accion in fila.acciones)
                      _LaAccion(fila: fila, accion: accion, onPedido: onPedido),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Un botón de la fila de una corrida.
///
/// Aparte de la fila para que el orden —que decide [ComoVaLaCorridaDe]— y cómo
/// se ve cada uno no vivan mezclados. **Lo que hace** ya no está aquí: lo hace
/// la app al recibir el pedido, esté la barra dentro o fuera. Ver
/// `atenderLaBotoneraProvider`.
class _LaAccion extends StatelessWidget {
  const _LaAccion({
    required this.fila,
    required this.accion,
    required this.onPedido,
  });

  final FilaDeCorrida fila;
  final AccionDeCorrida accion;
  final ValueChanged<PedidoDeLaBotonera> onPedido;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = context.colors;
    // La primera de la fila es la que toca, y se marca con el acento: «esto es
    // lo que hay que hacer ahora». Solo la del error y la de seguir, que son
    // las dos que el estado pide; el resto son disponibles.
    final esLaQueToca =
        fila.acciones.firstOrNull == accion &&
        (accion == AccionDeCorrida.pasarleElError ||
            accion == AccionDeCorrida.seguir);

    // 🔴 **Iconos, con su nombre en el tooltip.** La pasada de fidelidad los
    // cambió por palabras —«RECARGAR», «REINICIAR», «PARSE EN LOS ERRORES»—, y
    // en la botonera eso es una fila de dos o tres líneas que se lee en vez de
    // pulsarse. Pedido de vuelta el 28 sep: «me gustaban más cuando eran
    // iconos». Son los de una barra de depuración, y el color separa los que
    // no se pueden confundir: reiniciar en verde, parar en rojo.
    BotonMini boton(
      IconData icono,
      String titulo, {
      Color? color,
      bool activo = false,
    }) => BotonMini(
      key: ValueKey('accion-${accion.name}'),
      icono: icono,
      titulo: titulo,
      color: esLaQueToca ? colors.accent : color,
      activo: activo,
      onPulsar: () =>
          onPedido(AccionEnLaCorrida(deviceId: fila.deviceId, accion: accion)),
    );

    return switch (accion) {
      AccionDeCorrida.pasarleElError => boton(
        Icons.bolt_outlined,
        strings.runPasarloAClaude,
        color: colors.err,
      ),
      AccionDeCorrida.seguir => boton(
        Icons.play_arrow_rounded,
        strings.runSeguir,
        color: colors.ok,
      ),
      AccionDeCorrida.siguienteLinea => boton(
        Icons.redo_rounded,
        strings.runPasoSiguiente,
      ),
      AccionDeCorrida.entrar => boton(
        Icons.subdirectory_arrow_right_rounded,
        strings.runPasoEntrar,
      ),
      AccionDeCorrida.salir => boton(
        Icons.subdirectory_arrow_left_rounded,
        strings.runPasoSalir,
      ),
      AccionDeCorrida.recargar => boton(Icons.refresh, strings.runReload),
      AccionDeCorrida.reiniciar => boton(
        Icons.restart_alt,
        strings.runRestart,
        color: colors.ok,
      ),
      AccionDeCorrida.freno => boton(
        Icons.pause_circle_outline,
        strings.runFreno,
        activo: fila.frenoPuesto,
      ),
      AccionDeCorrida.consola => boton(
        Icons.dashboard_customize_outlined,
        strings.runConsole,
      ),
      AccionDeCorrida.registro => boton(
        Icons.article_outlined,
        strings.runLogs,
        activo: fila.registroAbierto,
      ),
      AccionDeCorrida.registroDelSistema => boton(
        Icons.phonelink_ring_outlined,
        strings.runSystemLog,
        activo: fila.sistemaAbierto,
      ),
      AccionDeCorrida.parar => boton(
        Icons.stop_rounded,
        strings.runStop,
        color: colors.err,
      ),
    };
  }
}

/// Un trabajo largo corriendo, con lo último que dijo y cómo pararlo.
///
/// 🔴 **Enseña la última línea y no una barra.** Un gate no tiene porcentaje —
/// no sabe cuánto le queda— pero sí dice por dónde va: «✅ barrels», «analyze».
/// Eso es lo que contesta la pregunta de quien mira, que no es «cuánto falta»
/// sino «sigue vivo».
class _UnTrabajo extends StatelessWidget {
  const _UnTrabajo({required this.fila, required this.onPedido});

  final FilaDeTrabajo fila;
  final ValueChanged<PedidoDeLaBotonera> onPedido;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        NexusSpacing.s3,
        NexusSpacing.s2,
        NexusSpacing.s2,
        NexusSpacing.s2,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.rule)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 7,
            height: 7,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: colors.accent,
            ),
          ),
          const SizedBox(width: NexusSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fila.comando,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NexusTypography.data.copyWith(color: colors.ink),
                ),
                Text(
                  fila.ultimaLinea ?? strings.elTrabajoArrancando,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NexusTypography.mono.copyWith(color: colors.accent),
                ),
              ],
            ),
          ),
          BotonMini(
            icono: Icons.stop_rounded,
            titulo: strings.elTrabajoParar,
            color: colors.err,
            onPulsar: () => onPedido(PararElTrabajo(fila.conversacion)),
          ),
        ],
      ),
    );
  }
}
