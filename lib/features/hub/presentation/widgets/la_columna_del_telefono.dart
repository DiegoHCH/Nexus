import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/hub/domain/al_telefono.dart';
import 'package:nexus/features/hub/domain/el_protocolo_del_emulador.dart';
import 'package:nexus/features/hub/presentation/widgets/la_pantalla_del_emulador.dart';

/// **Usar el teléfono desde el hub** (T7 y T8): la pantalla atiende el ratón,
/// el trackpad y el teclado, y a su lado va la columna de botones —atrás,
/// inicio, recientes; girar y sonido; encender; verla en su ventana y apagar
/// el emulador—.
///
/// Todo va al emulador por la misma llamada abierta (`streamInputEvent`): al
/// arrastrar son decenas de eventos por segundo.
class LaColumnaDelTelefono extends StatefulWidget {
  const LaColumnaDelTelefono({
    super.key,
    required this.conexion,
    required this.pantalla,
    this.onVerEnSuVentana,
    this.onApagar,
    this.onGirar,
    this.sonido,
    this.onSonido,
  });

  final LaConexionDeLaPantalla conexion;
  final Widget pantalla;

  /// Verlo en su ventana. `null` si no la tiene —un emulador que arrancó el
  /// hub, sin ventana—: entonces el botón no se pinta, porque solo podría
  /// fallar.
  final VoidCallback? onVerEnSuVentana;

  /// Apagar el emulador. `null` para lo que no es un emulador. Sin su ventana
  /// no queda otra cruz con la que cerrarlo, y por eso va aquí (11 nov).
  final VoidCallback? onApagar;

  /// Girar un cuarto (T8).
  final VoidCallback? onGirar;

  /// Si el sonido del teléfono suena en el Mac (T8). `null` sin sonido.
  final bool? sonido;
  final VoidCallback? onSonido;

  @override
  State<LaColumnaDelTelefono> createState() => _LaColumnaDelTelefonoState();
}

class _LaColumnaDelTelefonoState extends State<LaColumnaDelTelefono> {
  final _foco = FocusNode(debugLabel: 'pantalla del teléfono');
  final _llave = GlobalKey();

  /// El dedo del ratón: uno. El trackpad no pone varios dedos en Flutter; el
  /// gesto de pellizco no se traduce (fuera de esta versión).
  static const _dedo = 1;

  @override
  void dispose() {
    _foco.dispose();
    super.dispose();
  }

  void _toque(Offset local, {required bool abajo}) {
    final caja = _llave.currentContext?.size;
    final nativo = widget.conexion.nativo;
    if (caja == null || caja.isEmpty) return;
    final imagen = widget.conexion.imagen;
    // Sin el tamaño de su pantalla, el de la imagen en su posición natural.
    final girado = imagen.cuartosDeGiro.isOdd;
    final ancho = nativo?.ancho ?? (girado ? imagen.alto : imagen.ancho);
    final alto = nativo?.alto ?? (girado ? imagen.ancho : imagen.alto);
    final p = AlTelefono.punto(
      u: local.dx / caja.width,
      v: local.dy / caja.height,
      ancho: ancho,
      alto: alto,
      cuartosDeGiro: imagen.cuartosDeGiro,
    );
    widget.conexion.telefono.toque(
      ToqueEnElTelefono(x: p.x, y: p.y, dedo: _dedo, presion: abajo ? 1 : 0),
    );
  }

  void _rueda(PointerScrollEvent e) {
    // Una vuelta de rueda por evento, en su sentido: el emulador cuenta
    // muescas, no píxeles.
    final dy = e.scrollDelta.dy == 0 ? 0 : (e.scrollDelta.dy > 0 ? -1 : 1);
    final dx = e.scrollDelta.dx == 0 ? 0 : (e.scrollDelta.dx > 0 ? -1 : 1);
    if (dx == 0 && dy == 0) return;
    widget.conexion.telefono.rueda(dx: dx, dy: dy);
  }

  KeyEventResult _tecla(FocusNode _, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.handled;
    final telefono = widget.conexion.telefono;
    final especial = AlTelefono.tecla(e.logicalKey.keyLabel);
    if (especial != null) {
      telefono.tecla(especial);
      return KeyEventResult.handled;
    }
    final caracter = e.character;
    final conComando =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    if (caracter != null && caracter.isNotEmpty && !conComando) {
      telefono.texto(caracter);
      return KeyEventResult.handled;
    }
    // ⌘ con algo: es de la ventana (⌘W cierra), no del teléfono.
    return KeyEventResult.ignored;
  }

  void _boton(String tecla) => widget.conexion.telefono.tecla(tecla);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final pantalla = Focus(
      focusNode: _foco,
      onKeyEvent: _tecla,
      child: Listener(
        key: _llave,
        onPointerDown: (e) {
          _foco.requestFocus();
          _toque(e.localPosition, abajo: true);
        },
        onPointerMove: (e) => _toque(e.localPosition, abajo: true),
        onPointerUp: (e) => _toque(e.localPosition, abajo: false),
        onPointerSignal: (e) {
          if (e is PointerScrollEvent) _rueda(e);
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.precise,
          child: widget.pantalla,
        ),
      ),
    );

    Widget boton(
      IconData icono,
      String titulo,
      VoidCallback? alPulsar, {
      bool activo = false,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: NexusSpacing.s1 + 2),
      child: Tooltip(
        message: titulo,
        child: InkWell(
          onTap: alPulsar,
          borderRadius: BorderRadius.circular(NexusRadius.sm),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: colors.deep,
              border: Border.all(color: activo ? colors.accent : colors.rule),
              borderRadius: BorderRadius.circular(NexusRadius.sm),
            ),
            child: Icon(
              icono,
              size: 15,
              color: alPulsar == null
                  ? colors.faint
                  : activo
                  ? colors.accent
                  : colors.mute,
            ),
          ),
        ),
      ),
    );
    Widget filete() => Container(
      width: 30,
      height: 1,
      margin: const EdgeInsets.only(bottom: NexusSpacing.s1 + 2),
      color: colors.rule,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: pantalla),
        const SizedBox(width: NexusSpacing.s3 + 2),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            boton(
              Icons.arrow_back_ios_new_rounded,
              strings.hubAtras,
              () => _boton('GoBack'),
            ),
            boton(
              Icons.circle_outlined,
              strings.hubInicio,
              () => _boton('GoHome'),
            ),
            boton(
              Icons.crop_square_rounded,
              strings.hubRecientes,
              () => _boton('AppSwitch'),
            ),
            filete(),
            boton(
              Icons.screen_rotation_rounded,
              strings.hubGirar,
              widget.onGirar,
            ),
            if (widget.sonido != null)
              boton(
                widget.sonido!
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                widget.sonido! ? strings.hubSilenciar : strings.hubOirlo,
                widget.onSonido,
                activo: widget.sonido!,
              ),
            filete(),
            boton(
              Icons.power_settings_new_rounded,
              strings.hubEncender,
              () => _boton('Power'),
            ),
            if (widget.onVerEnSuVentana case final ver?)
              boton(Icons.open_in_new_rounded, strings.hubVerEnSuVentana, ver),
            if (widget.onApagar case final apagar?)
              boton(
                Icons.power_off_rounded,
                strings.hubApagarElEmulador,
                apagar,
              ),
          ],
        ),
      ],
    );
  }
}
