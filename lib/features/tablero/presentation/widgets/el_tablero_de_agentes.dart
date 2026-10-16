import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/design_system/hoja_de_la_sala.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/domain/entities/conversation.dart';
import 'package:nexus/features/assistant/domain/entities/peticion_de_permiso.dart';
import 'package:nexus/features/assistant/domain/usecases/el_verbo_de_un_paso.dart';
import 'package:nexus/features/assistant/presentation/providers/assistant_controller.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/assistant/presentation/providers/la_ventana_de_actividad.dart';
import 'package:nexus/features/assistant/presentation/state/assistant_hud_state.dart';
import 'package:nexus/features/assistant/presentation/state/lo_que_dicen_las_etiquetas.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/observador/domain/entities/la_terminal.dart';
import 'package:nexus/features/observador/presentation/providers/la_terminal_provider.dart';

/// **El tablero de agentes**: todas las conversaciones y las sesiones de la
/// terminal a la vez, cada una con su estado, su paso y sus permisos.
///
/// Del análisis del reel del «Agentic OS» (16 oct): «todos tus agentes, a la
/// vista y controlados desde un único sitio». La isla ya lo hacía en pequeño;
/// esto es lo mismo a lo grande, para cuando hay seis abiertas y no sabes cuál
/// te necesita. Lo que pide permiso se contesta aquí mismo, y pulsar una
/// conversación lleva a ella.
class ElTableroDeAgentes extends ConsumerWidget {
  const ElTableroDeAgentes({super.key});

  static Future<void> open(BuildContext context) =>
      HojaDeLaSala.abrir(context, const ElTableroDeAgentes(), cual: 'agentes');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final conversaciones = ref.watch(conversationsProvider);
    final terminal = ref.watch(laTerminalProvider);
    final cuantas = [
      for (final una in conversaciones.items)
        ref.watch(assistantControllerProvider(una.id).select(_loQueCuenta)),
    ];
    final trabajando =
        cuantas.where((una) => una.trabaja).length +
        terminal.sesiones.where((una) => una.trabajando).length;
    final pidenPermiso =
        cuantas.fold<int>(0, (suma, una) => suma + una.permisos) +
        terminal.permisos.length;

    return HojaDeLaSala(
      rotulo: strings.tableroTitulo,
      lado: _ElResumen(
        trabajando: trabajando,
        pidenPermiso: pidenPermiso,
        sesiones: terminal.sesiones.length,
      ),
      // Los tiempos cuentan solos: una tarjeta quieta diría que se colgó.
      vista: StreamBuilder<void>(
        stream: Stream<void>.periodic(const Duration(seconds: 1)),
        builder: (context, _) => _LasTarjetas(
          conversaciones: conversaciones.items,
          enFoco: conversaciones.focused?.id,
          terminal: terminal,
        ),
      ),
    );
  }
}

/// Lo que una conversación cuenta en el tablero, con `select`: cada trozo de
/// texto que llega cambia el estado, y el tablero repintaría por letra.
typedef _Cuenta = ({
  NexusOrbState estado,
  VerboDelPaso? verbo,
  String? objeto,
  bool escribe,
  DateTime? desde,
  int hechos,
  int pasos,
  int permisos,
});

_Cuenta _loQueCuenta(AssistantHudState hud) {
  final trabaja =
      hud.orbState == NexusOrbState.think ||
      hud.orbState == NexusOrbState.ponder;
  final etiquetas = trabaja
      ? loQueDicenLasEtiquetas(hud.activity)
      : LasEtiquetas.nada;
  return (
    estado: hud.orbState,
    verbo: etiquetas.paso?.verbo,
    objeto: etiquetas.paso?.objeto,
    escribe: etiquetas.paso?.escribe ?? false,
    desde: etiquetas.desde,
    hechos: etiquetas.hechos,
    pasos: etiquetas.pasos.length,
    permisos: hud.messages.where((m) => m.esperaPermiso).length,
  );
}

extension on _Cuenta {
  bool get trabaja =>
      estado == NexusOrbState.think || estado == NexusOrbState.ponder;
}

String _laPalabra(NexusOrbState estado, NexusStrings strings) =>
    switch (estado) {
      NexusOrbState.sleep => strings.asleep,
      NexusOrbState.listen => strings.listening,
      NexusOrbState.think => strings.working,
      NexusOrbState.ponder => strings.pensando,
      NexusOrbState.speak => strings.speaking,
    };

String _nombreDe(Conversation conversacion) =>
    conversacion.name ??
    conversacion.folderPath.replaceAll(RegExp(r'/+$'), '').split('/').last;

class _ElResumen extends StatelessWidget {
  const _ElResumen({
    required this.trabajando,
    required this.pidenPermiso,
    required this.sesiones,
  });

  final int trabajando;
  final int pidenPermiso;
  final int sesiones;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    return Padding(
      padding: const EdgeInsets.all(NexusSpacing.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.tableroExplica,
            style: NexusTypography.nota.copyWith(
              color: colors.mute,
              fontSize: 14,
              height: 1.55,
            ),
          ),
          const SizedBox(height: NexusSpacing.s5),
          for (final (texto, color) in [
            (strings.tableroTrabajando(trabajando), colors.accent),
            if (pidenPermiso > 0)
              (strings.tableroPidenPermiso(pidenPermiso), colors.warn),
            if (sesiones > 0) (strings.terminalSesiones(sesiones), colors.mute),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: NexusSpacing.s2),
              child: Text(
                texto.toUpperCase(),
                style: NexusTypography.label.copyWith(color: color),
              ),
            ),
        ],
      ),
    );
  }
}

class _LasTarjetas extends StatelessWidget {
  const _LasTarjetas({
    required this.conversaciones,
    required this.enFoco,
    required this.terminal,
  });

  final List<Conversation> conversaciones;
  final String? enFoco;
  final LaTerminal terminal;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = context.colors;
    if (conversaciones.isEmpty && terminal.sesiones.isEmpty) {
      return Center(
        child: Text(
          strings.tableroNada,
          style: NexusTypography.nota.copyWith(color: colors.faint),
        ),
      );
    }
    final ahora = DateTime.now();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(NexusSpacing.s6),
      child: Wrap(
        spacing: NexusSpacing.s4,
        runSpacing: NexusSpacing.s4,
        children: [
          for (final conversacion in conversaciones)
            _LaDeUnaConversacion(
              key: ValueKey('tablero-${conversacion.id}'),
              conversacion: conversacion,
              enFoco: conversacion.id == enFoco,
              ahora: ahora,
            ),
          for (final sesion in terminal.sesiones)
            _LaDeUnaSesion(
              key: ValueKey('tablero-terminal-${sesion.id}'),
              sesion: sesion,
              permisos: [
                for (final permiso in terminal.permisos)
                  if (permiso.sesion == sesion.id) permiso,
              ],
            ),
        ],
      ),
    );
  }
}

/// La caja de cada tarjeta: el mismo ancho para todas, y la franja de color
/// a la izquierda que dice de lejos si trabaja o espera un permiso.
class _LaTarjeta extends StatelessWidget {
  const _LaTarjeta({required this.tono, required this.child, this.onPulsar});

  final Color tono;
  final Widget child;
  final VoidCallback? onPulsar;

  static const ancho = 300.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tarjeta = Container(
      width: ancho,
      padding: const EdgeInsets.all(NexusSpacing.s4),
      decoration: BoxDecoration(
        color: colors.deep,
        border: Border(
          left: BorderSide(color: tono, width: 2.5),
          top: BorderSide(color: colors.rule),
          right: BorderSide(color: colors.rule),
          bottom: BorderSide(color: colors.rule),
        ),
      ),
      child: child,
    );
    if (onPulsar == null) return tarjeta;
    return InkWell(onTap: onPulsar, child: tarjeta);
  }
}

class _LaCabecera extends StatelessWidget {
  const _LaCabecera({
    required this.nombre,
    required this.rotulo,
    required this.tono,
    this.dato,
  });

  final String nombre;
  final String rotulo;
  final Color tono;
  final String? dato;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Expanded(
          child: Text(
            nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: NexusTypography.data.copyWith(color: colors.ink),
          ),
        ),
        const SizedBox(width: NexusSpacing.s2),
        Text(
          rotulo.toUpperCase(),
          style: NexusTypography.label.copyWith(color: tono),
        ),
        if (dato != null) ...[
          const SizedBox(width: NexusSpacing.s2),
          Text(
            dato!,
            style: NexusTypography.data.copyWith(
              color: tono,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}

class _LaDeUnaConversacion extends ConsumerWidget {
  const _LaDeUnaConversacion({
    super.key,
    required this.conversacion,
    required this.enFoco,
    required this.ahora,
  });

  final Conversation conversacion;
  final bool enFoco;
  final DateTime ahora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final cuenta = ref.watch(
      assistantControllerProvider(conversacion.id).select(_loQueCuenta),
    );
    // El detalle de lo que espera, leído entero solo si espera algo.
    final esperan = cuenta.permisos == 0
        ? const <PeticionDePermiso>[]
        : [
            for (final mensaje
                in ref
                    .read(assistantControllerProvider(conversacion.id))
                    .messages)
              if (mensaje.esperaPermiso) mensaje.permiso!,
          ];
    final tono = esperan.isNotEmpty
        ? colors.warn
        : cuenta.estado == NexusOrbState.sleep
        ? colors.rule2
        : colors.accent;
    final verbo = cuenta.verbo;
    final desde = cuenta.desde;

    return _LaTarjeta(
      tono: tono,
      onPulsar: () {
        ref.read(conversationsProvider.notifier).focus(conversacion.id);
        Navigator.of(context).maybePop();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LaCabecera(
            nombre: _nombreDe(conversacion),
            rotulo: _laPalabra(cuenta.estado, strings),
            tono: tono,
            dato: desde == null
                ? null
                : elTiempoDeUnaEtiqueta(ahora.difference(desde)),
          ),
          if (cuenta.pasos > 0) ...[
            const SizedBox(height: NexusSpacing.s2),
            Text(
              strings
                  .escenarioPasoDe(
                    (cuenta.hechos + 1).clamp(1, cuenta.pasos),
                    cuenta.pasos,
                  )
                  .toUpperCase(),
              style: NexusTypography.label.copyWith(color: colors.mute),
            ),
          ],
          if (cuenta.objeto case final objeto?) ...[
            const SizedBox(height: NexusSpacing.s1),
            Text(
              [
                if (verbo != null && verbo != VerboDelPaso.otro)
                  textosDeActividad(strings).verbo(verbo, hecho: false),
                objeto,
              ].join(' '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: NexusTypography.data.copyWith(
                fontSize: 12,
                color: cuenta.escribe ? colors.warn : colors.ink,
              ),
            ),
          ],
          for (final permiso in esperan)
            _ElPermiso(
              llave: ValueKey('tablero-permiso-${permiso.id}'),
              herramienta: permiso.nombreVisible,
              detalle: permiso.resumen,
              conTerminal: false,
              onContestar: (como) => ref
                  .read(assistantControllerProvider(conversacion.id).notifier)
                  .responderPermiso(
                    permiso.id,
                    como == ContestacionDePermiso.permitir
                        ? DecisionDePermiso.concedido
                        : DecisionDePermiso.denegado,
                  ),
            ),
        ],
      ),
    );
  }
}

class _LaDeUnaSesion extends ConsumerWidget {
  const _LaDeUnaSesion({
    super.key,
    required this.sesion,
    required this.permisos,
  });

  final SesionDeLaTerminal sesion;
  final List<PermisoDeLaTerminal> permisos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final tono = permisos.isNotEmpty
        ? colors.warn
        : sesion.trabajando
        ? colors.accent
        : colors.rule2;
    final contexto = sesion.contexto;
    return _LaTarjeta(
      tono: tono,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LaCabecera(
            nombre: sesion.nombre,
            rotulo: strings.tableroTerminal,
            tono: tono,
            dato: contexto == null ? null : '$contexto %',
          ),
          const SizedBox(height: NexusSpacing.s2),
          Text(
            sesion.trabajando
                ? [?sesion.herramienta, ?sesion.detalle].join(' · ')
                : strings.terminalLibre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: NexusTypography.data.copyWith(
              fontSize: 12,
              color: sesion.trabajando ? colors.ink : colors.faint,
            ),
          ),
          for (final permiso in permisos)
            _ElPermiso(
              llave: ValueKey('tablero-permiso-${permiso.id}'),
              herramienta: permiso.herramienta,
              detalle: permiso.detalle,
              conTerminal: true,
              onContestar: (como) => ref
                  .read(laTerminalProvider.notifier)
                  .contestar(permiso.id, como),
            ),
        ],
      ),
    );
  }
}

/// Un permiso que espera, con sus botones. El de devolverle la pregunta a la
/// terminal solo en las sesiones de la terminal: una conversación de Nexus no
/// tiene otro sitio donde preguntar.
class _ElPermiso extends StatelessWidget {
  const _ElPermiso({
    required this.llave,
    required this.herramienta,
    required this.detalle,
    required this.conTerminal,
    required this.onContestar,
  });

  final Key llave;
  final String herramienta;
  final String detalle;
  final bool conTerminal;
  final ValueChanged<ContestacionDePermiso> onContestar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    return Container(
      key: llave,
      margin: const EdgeInsets.only(top: NexusSpacing.s3),
      padding: const EdgeInsets.only(top: NexusSpacing.s3),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.rule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            herramienta,
            style: NexusTypography.data.copyWith(color: colors.warn),
          ),
          if (detalle.isNotEmpty) ...[
            const SizedBox(height: NexusSpacing.s1),
            Text(
              detalle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: NexusTypography.mono.copyWith(
                fontSize: 11.5,
                color: colors.ink,
              ),
            ),
          ],
          const SizedBox(height: NexusSpacing.s2),
          Wrap(
            spacing: NexusSpacing.s2,
            runSpacing: NexusSpacing.s2,
            children: [
              BotonDeAjustes(
                texto: strings.terminalPermitir,
                tono: TonoDeBoton.principal,
                onPulsar: () => onContestar(ContestacionDePermiso.permitir),
              ),
              BotonDeAjustes(
                texto: strings.terminalDenegar,
                onPulsar: () => onContestar(ContestacionDePermiso.denegar),
              ),
              if (conTerminal)
                BotonDeAjustes(
                  texto: strings.terminalEnLaTerminal,
                  onPulsar: () =>
                      onContestar(ContestacionDePermiso.enLaTerminal),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
