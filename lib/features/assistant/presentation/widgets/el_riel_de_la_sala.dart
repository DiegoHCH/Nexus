import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';

/// El riel del borde derecho: la conversación y las hojas de la sala, siempre
/// a la vista y a todo lo alto.
///
/// **La conversación es un panel que se abre al lado del orbe**, no otra
/// pantalla. Recogida, el orbe vuelve a tener la sala entera y en el riel
/// queda su icono —con un punto si llegó algo mientras no se miraba—; abierta,
/// el mismo icono se enciende y el panel ocupa su sitio a la izquierda del
/// riel. Es lo mismo que ⌘E.
///
/// 🔴 **Antes era una pestaña suelta** a media altura, que se leía como un
/// adorno pegado al borde y no como el sitio de la conversación. Un riel dice
/// «aquí hay cosas que se abren», y de paso da un sitio a la vista al
/// historial, los documentos y los ajustes, que en el escenario solo se
/// alcanzaban con su atajo.
///
/// Relleno solo en lo abierto: el relleno dice «esto está pasando ahora», y el
/// resto del riel está disponible, no activo.
class ElRielDeLaSala extends StatelessWidget {
  const ElRielDeLaSala({
    super.key,
    required this.chatAbierto,
    required this.sinLeer,
    required this.onChat,
    required this.onHistorial,
    required this.onDocumentos,
    required this.onAjustes,
  });

  final bool chatAbierto;

  /// Si la conversación dijo algo desde que se recogió.
  final bool sinLeer;

  final VoidCallback onChat;
  final VoidCallback onHistorial;
  final VoidCallback onDocumentos;
  final VoidCallback onAjustes;

  static const ancho = 56.0;

  static const laLlaveDelChat = ValueKey('riel-chat');
  static const laLlaveDelPunto = ValueKey('riel-chat-sin-leer');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    String capital(String s) =>
        s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

    return Container(
      width: ancho,
      padding: const EdgeInsets.symmetric(vertical: NexusSpacing.s4),
      decoration: BoxDecoration(
        color: colors.void_,
        border: Border(left: BorderSide(color: colors.rule)),
      ),
      child: Column(
        children: [
          _Boton(
            key: laLlaveDelChat,
            icono: Icons.chat_bubble_outline,
            nombre: chatAbierto ? strings.chatRecoger : strings.chatSacar,
            atajo: '⌘E',
            encendido: chatAbierto,
            punto: sinLeer && !chatAbierto,
            onPulsar: onChat,
          ),
          const SizedBox(height: NexusSpacing.s3),
          SizedBox(width: 24, child: Divider(height: 1, color: colors.rule)),
          const SizedBox(height: NexusSpacing.s3),
          _Boton(
            icono: Icons.history,
            nombre: capital(strings.history),
            atajo: '⌘Y',
            onPulsar: onHistorial,
          ),
          const SizedBox(height: NexusSpacing.s2),
          _Boton(
            icono: Icons.description_outlined,
            nombre: capital(strings.artifacts),
            atajo: '⌘J',
            onPulsar: onDocumentos,
          ),
          const Spacer(),
          _Boton(
            icono: Icons.settings_outlined,
            nombre: capital(strings.settings),
            atajo: '⌘,',
            onPulsar: onAjustes,
          ),
        ],
      ),
    );
  }
}

class _Boton extends StatefulWidget {
  const _Boton({
    super.key,
    required this.icono,
    required this.nombre,
    required this.atajo,
    required this.onPulsar,
    this.encendido = false,
    this.punto = false,
  });

  final IconData icono;
  final String nombre;
  final String atajo;
  final VoidCallback onPulsar;
  final bool encendido;
  final bool punto;

  @override
  State<_Boton> createState() => _BotonState();
}

class _BotonState extends State<_Boton> {
  var _encima = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tinta = widget.encendido
        ? colors.accent
        : _encima
        ? colors.ink
        : colors.mute;

    return Semantics(
      button: true,
      selected: widget.encendido,
      label: widget.nombre,
      child: Tooltip(
        message: '${widget.nombre} · ${widget.atajo}',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _encima = true),
          onExit: (_) => setState(() => _encima = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPulsar,
            child: SizedBox.square(
              dimension: 36,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: widget.encendido
                            ? colors.accent.withValues(alpha: 0.16)
                            : _encima
                            ? colors.ink.withValues(alpha: 0.06)
                            : null,
                        border: Border.all(
                          color: widget.encendido
                              ? colors.accent.withValues(alpha: 0.5)
                              : Colors.transparent,
                        ),
                        borderRadius: BorderRadius.circular(NexusRadius.sm),
                      ),
                      child: Icon(widget.icono, size: 18, color: tinta),
                    ),
                  ),
                  if (widget.punto)
                    Positioned(
                      key: ElRielDeLaSala.laLlaveDelPunto,
                      top: 5,
                      right: 5,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: colors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.void_, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
