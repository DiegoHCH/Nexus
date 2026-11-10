import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/features/hub/data/el_scrcpy_conectado.dart';
import 'package:nexus/features/hub/data/el_sonido_del_telefono.dart';
import 'package:nexus/features/hub/data/el_video_del_telefono.dart';
import 'package:nexus/features/hub/data/la_textura_del_telefono.dart';
import 'package:nexus/features/hub/domain/el_protocolo_del_emulador.dart';
import 'package:nexus/features/hub/presentation/widgets/la_pantalla_del_emulador.dart';

/// **La pantalla de un Android enchufado, dentro del hub** (T12), por scrcpy.
///
/// Sube el servidor que va con Nexus, conecta sus tres sockets y pinta el
/// vídeo —decodificado por VideoToolbox— en la misma textura que la pantalla
/// del emulador. Los toques van en los píxeles del vídeo, que el servidor gira
/// solo: aquí no hay que deshacer ningún giro. El sonido llega sin comprimir.
///
/// Si no conecta —sin `adb`, un teléfono que no lo deja—, enseña
/// [sinPantalla]: el aviso con «Ver con scrcpy» fuera, si está instalado (T9).
class LaPantallaDelEnchufado extends StatefulWidget {
  const LaPantallaDelEnchufado({
    super.key,
    required this.serial,
    required this.sinPantalla,
    this.alrededor,
    this.textura = const LaTexturaNativaDelTelefono(),
    this.video = const ElVideoNativoDelTelefono(),
    this.sonido = const ElSonidoNativoDelTelefono(),
  });

  final String serial;
  final Widget sinPantalla;
  final Widget Function(LaConexionDeLaPantalla conexion, Widget pantalla)?
  alrededor;
  final LaTexturaDelTelefono textura;
  final ElVideoDelTelefono video;
  final ElSonidoDelTelefono sonido;

  /// El servidor de scrcpy que va con la app. Ver `pubspec.yaml`.
  static const servidor = 'assets/scrcpy/scrcpy-server';

  @override
  State<LaPantallaDelEnchufado> createState() => _LaPantallaDelEnchufadoState();
}

class _LaPantallaDelEnchufadoState extends State<LaPantallaDelEnchufado> {
  ElScrcpyConectado? _scrcpy;
  int? _textura;
  ({int ancho, int alto})? _tamano;
  bool _noSePuede = false;
  bool _conSonido = true;
  bool _cerrado = false;
  StreamSubscription<Uint8List>? _oido;

  @override
  void initState() {
    super.initState();
    unawaited(_conectar());
  }

  Future<void> _conectar() async {
    final Uint8List servidor;
    try {
      servidor = (await rootBundle.load(
        LaPantallaDelEnchufado.servidor,
      )).buffer.asUint8List();
    } on Object {
      if (mounted) setState(() => _noSePuede = true);
      return;
    }
    final (:conexion, :problema) = await ElScrcpyConectado.conectar(
      serial: widget.serial,
      servidor: servidor,
    );
    if (!mounted || _cerrado) {
      unawaited(conexion?.cerrar());
      return;
    }
    if (conexion == null) {
      debugPrint('hub · scrcpy: $problema');
      setState(() => _noSePuede = true);
      return;
    }
    final textura = await widget.textura.crear();
    if (!mounted || textura == null) {
      unawaited(conexion.cerrar());
      if (mounted) setState(() => _noSePuede = true);
      return;
    }
    _scrcpy = conexion;
    _textura = textura.textura;
    unawaited(_verVideo(conexion, textura.textura));
    if (_conSonido) unawaited(_oir());
  }

  /// Los paquetes, en orden, al decodificador: el de configuración primero.
  Future<void> _verVideo(ElScrcpyConectado scrcpy, int textura) async {
    try {
      await for (final p in scrcpy.video()) {
        if (!mounted) return;
        final tamano = await widget.video.paquete(
          textura,
          configuracion: p.configuracion,
          datos: p.datos,
        );
        if (tamano != null && tamano != _tamano && mounted) {
          scrcpy
            ..ancho = tamano.ancho
            ..alto = tamano.alto;
          setState(() => _tamano = tamano);
        }
      }
    } on Object {
      // Se desenchufó o se cerró: el aviso de siempre.
    }
    if (mounted && !_cerrado) setState(() => _noSePuede = true);
  }

  Future<void> _oir() async {
    final scrcpy = _scrcpy;
    if (scrcpy == null || !scrcpy.conSonido || _oido != null) return;
    if (!await widget.sonido.empezar(frecuencia: 48000)) return;
    _oido = scrcpy.sonido().listen(
      widget.sonido.pcm,
      onError: (Object _) => _oido = null,
    );
  }

  Future<void> _callar() async {
    await _oido?.cancel();
    _oido = null;
    await widget.sonido.parar();
  }

  @override
  void dispose() {
    _cerrado = true;
    unawaited(_callar());
    unawaited(_scrcpy?.cerrar());
    if (_textura case final t?) {
      unawaited(widget.video.soltar(t));
      unawaited(widget.textura.soltar(t));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_noSePuede) return widget.sinPantalla;
    final colors = context.colors;
    final tamano = _tamano;
    final textura = _textura;
    final scrcpy = _scrcpy;
    if (tamano == null || textura == null || scrcpy == null) {
      return Center(
        child: SizedBox(
          width: 120,
          height: 2,
          child: LinearProgressIndicator(
            backgroundColor: colors.rule,
            color: colors.accent,
          ),
        ),
      );
    }
    final pantalla = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(color: colors.rule),
        borderRadius: BorderRadius.circular(NexusRadius.sm),
      ),
      child: AspectRatio(
        aspectRatio: tamano.ancho / math.max(1, tamano.alto),
        child: Texture(textureId: textura),
      ),
    );
    final conexion = LaConexionDeLaPantalla(
      telefono: scrcpy,
      // Los toques van en los píxeles del vídeo, que ya viene girado.
      nativo: tamano,
      imagen: ImagenDelEmulador(ancho: tamano.ancho, alto: tamano.alto, seq: 0),
      sonido: _conSonido && scrcpy.conSonido,
      alternarSonido: () {
        setState(() => _conSonido = !_conSonido);
        unawaited(_conSonido ? _oir() : _callar());
      },
      girar: () =>
          unawaited(scrcpy.girar(apaisado: tamano.ancho > tamano.alto)),
    );
    return Padding(
      padding: const EdgeInsets.all(NexusSpacing.s4),
      child: Center(
        child: widget.alrededor?.call(conexion, pantalla) ?? pantalla,
      ),
    );
  }
}
