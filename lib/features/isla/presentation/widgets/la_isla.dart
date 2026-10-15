import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/presentation/providers/la_ventana_de_actividad.dart';
import 'package:nexus/features/assistant/presentation/state/lo_que_dicen_las_etiquetas.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/isla/presentation/state/la_foto_de_la_isla.dart';
import 'package:nexus/features/observador/domain/entities/la_terminal.dart';

/// **La isla**: el rótulo de Nexus, lo que trabaja y los permisos que esperan.
///
/// Solo pinta: lo que llega es una foto y lo que se pulsa sale por
/// [onPedido] y [onVolver]. Vive en el motor de la isla, que no tiene `ref`, y
/// así se prueba sin él.
class LaIsla extends StatefulWidget {
  const LaIsla({
    super.key,
    required this.foto,
    required this.onPedido,
    required this.onVolver,
    this.ahora = DateTime.now,
  });

  final LaFotoDeLaIsla foto;
  final ValueChanged<PedidoDeLaIsla> onPedido;

  /// De vuelta a la ventana entera.
  final VoidCallback onVolver;

  /// El reloj de los cronómetros. Aparte para las pruebas.
  final DateTime Function() ahora;

  static const llaveVolver = ValueKey('isla-volver');

  @override
  State<LaIsla> createState() => _LaIslaState();
}

class _LaIslaState extends State<LaIsla> {
  /// El segundero, **solo mientras algo cuenta**: una isla quieta no tiene por
  /// qué repintarse cada segundo.
  Timer? _segundero;

  @override
  void initState() {
    super.initState();
    _ajustaElSegundero();
  }

  @override
  void didUpdateWidget(LaIsla antes) {
    super.didUpdateWidget(antes);
    _ajustaElSegundero();
  }

  void _ajustaElSegundero() {
    final cuenta = widget.foto.despiertas.any((una) => una.desde != null);
    if (cuenta && _segundero == null) {
      _segundero = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {}),
      );
    } else if (!cuenta) {
      _segundero?.cancel();
      _segundero = null;
    }
  }

  @override
  void dispose() {
    _segundero?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foto = widget.foto;
    final despiertas = foto.despiertas;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.deep,
        border: Border.all(color: colors.rule2),
        // Redonda, como una isla: es lo que la distingue de la botonera, que
        // es una barra de herramientas y lleva sus esquinas.
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: NexusSpacing.s4,
          vertical: NexusSpacing.s2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ElRotulo(foto: foto, onVolver: widget.onVolver),
            for (final fila in despiertas)
              _LaFila(
                fila: fila,
                ahora: widget.ahora(),
                onAbrir: () {
                  widget.onPedido(AbrirLaConversacion(fila.id));
                  widget.onVolver();
                },
              ),
            for (final permiso in foto.permisos)
              _ElPermiso(permiso: permiso, onPedido: widget.onPedido),
            if (despiertas.isNotEmpty || foto.permisos.isNotEmpty)
              const SizedBox(height: NexusSpacing.s2),
          ],
        ),
      ),
    );
  }
}

String _laPalabra(NexusOrbState estado, NexusStrings strings) =>
    switch (estado) {
      NexusOrbState.sleep => strings.asleep,
      NexusOrbState.listen => strings.listening,
      NexusOrbState.think => strings.working,
      NexusOrbState.ponder => strings.pensando,
      NexusOrbState.speak => strings.speaking,
    };

class _ElRotulo extends StatelessWidget {
  const _ElRotulo({required this.foto, required this.onVolver});

  final LaFotoDeLaIsla foto;
  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final enMarcha = foto.enMarcha;
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enMarcha ? colors.accent : colors.faint,
              boxShadow: [
                if (enMarcha)
                  BoxShadow(
                    color: colors.accent.withValues(alpha: 0.8),
                    blurRadius: 10,
                  ),
              ],
            ),
          ),
          const SizedBox(width: NexusSpacing.s3),
          Text(
            strings.brand,
            style: NexusTypography.brand.copyWith(color: colors.mute),
          ),
          const SizedBox(width: NexusSpacing.s4),
          Flexible(
            child: Text(
              _laPalabra(foto.elEstado, strings).toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: NexusTypography.label.copyWith(
                color: colors.accent.withValues(alpha: enMarcha ? 1 : 0.75),
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(width: NexusSpacing.s3),
          // Lo de la terminal a la derecha, y lo primero que cede si no cabe:
          // el rótulo es lo que no se puede perder.
          Expanded(
            child: foto.enLaTerminal == 0
                ? const SizedBox.shrink()
                : Text(
                    [
                      strings.terminalSesiones(foto.enLaTerminal),
                      if (foto.trabajandoEnLaTerminal > 0)
                        strings.islaTrabajandoEnLaTerminal(
                          foto.trabajandoEnLaTerminal,
                        ),
                    ].join(' · ').toUpperCase(),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NexusTypography.label.copyWith(color: colors.mute),
                  ),
          ),
          IconButton(
            key: LaIsla.llaveVolver,
            onPressed: onVolver,
            tooltip: strings.islaVolver,
            iconSize: 15,
            visualDensity: VisualDensity.compact,
            color: colors.mute,
            icon: const Icon(Icons.open_in_full),
          ),
        ],
      ),
    );
  }
}

/// Una conversación que trabaja, escucha o habla. Pulsarla lleva a ella.
class _LaFila extends StatelessWidget {
  const _LaFila({
    required this.fila,
    required this.ahora,
    required this.onAbrir,
  });

  final FilaDeLaIsla fila;
  final DateTime ahora;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final verbo = fila.verbo;
    final que = verbo == null
        ? _laPalabra(fila.estado, strings)
        : [
            textosDeActividad(strings).verbo(verbo, hecho: false),
            ?fila.objeto,
          ].join(' ');
    final desde = fila.desde;
    return InkWell(
      key: ValueKey('isla-fila-${fila.id}'),
      onTap: onAbrir,
      borderRadius: BorderRadius.circular(NexusRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: NexusSpacing.s1),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(
                fila.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NexusTypography.data.copyWith(color: colors.ink),
              ),
            ),
            const SizedBox(width: NexusSpacing.s3),
            Expanded(
              child: Text(
                que,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NexusTypography.nota.copyWith(color: colors.mute),
              ),
            ),
            if (desde != null) ...[
              const SizedBox(width: NexusSpacing.s3),
              Text(
                elTiempoDeUnaEtiqueta(ahora.difference(desde)),
                style: NexusTypography.mono.copyWith(color: colors.faint),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Un permiso de la terminal: quién lo pide, qué quiere hacer y la respuesta.
class _ElPermiso extends StatelessWidget {
  const _ElPermiso({required this.permiso, required this.onPedido});

  final PermisoDeLaIsla permiso;
  final ValueChanged<PedidoDeLaIsla> onPedido;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    void contestar(ContestacionDePermiso como) =>
        onPedido(ContestarElPermiso(permiso.id, como));
    return Container(
      key: ValueKey('isla-permiso-${permiso.id}'),
      margin: const EdgeInsets.only(top: NexusSpacing.s2),
      padding: const EdgeInsets.only(top: NexusSpacing.s2),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.rule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${permiso.nombre} · ${permiso.herramienta}',
            style: NexusTypography.data.copyWith(color: colors.warn),
          ),
          if (permiso.detalle.isNotEmpty) ...[
            const SizedBox(height: NexusSpacing.s1),
            Text(
              permiso.detalle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: NexusTypography.mono.copyWith(color: colors.ink),
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
                onPulsar: () => contestar(ContestacionDePermiso.permitir),
              ),
              BotonDeAjustes(
                texto: strings.terminalDenegar,
                onPulsar: () => contestar(ContestacionDePermiso.denegar),
              ),
              BotonDeAjustes(
                texto: strings.terminalEnLaTerminal,
                onPulsar: () => contestar(ContestacionDePermiso.enLaTerminal),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
