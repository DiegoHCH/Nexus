import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/features/hub/data/el_emulador_conectado.dart';
import 'package:nexus/features/hub/data/el_sonido_del_telefono.dart';
import 'package:nexus/features/hub/data/la_textura_del_telefono.dart';
import 'package:nexus/features/hub/domain/el_protocolo_del_emulador.dart';

/// **La pantalla de un emulador, dentro del hub** (T6).
///
/// Se conecta al gRPC del propio emulador —el puerto y el token los dejó en su
/// `.ini` al arrancar— y pide los fotogramas encajados en la caja que tiene,
/// por memoria compartida. Si la caja cambia —se redimensiona la ventana, se
/// pliega el registro— los pide otra vez a la nueva medida, con un respiro
/// para no reabrir la llamada en cada píxel del arrastre.
///
/// Si el emulador no da gRPC (uno viejo, o arrancado sin él) o algo se corta,
/// enseña [sinPantalla]: el aviso de siempre, con la pantalla en su ventana y
/// los mandos en el hub (T9).
class LaPantallaDelEmulador extends StatefulWidget {
  const LaPantallaDelEmulador({
    super.key,
    required this.deviceId,
    required this.sinPantalla,
    this.alrededor,
    this.textura = const LaTexturaNativaDelTelefono(),
    this.sonido = const ElSonidoNativoDelTelefono(),
  });

  /// `emulator-5554`.
  final String deviceId;

  final Widget sinPantalla;

  /// Lo que va pegado a la pantalla —la columna de botones—, con la conexión
  /// para que lo que se pulse vaya al emulador. Ver `LaColumnaDelTelefono`.
  final Widget Function(LaConexionDeLaPantalla conexion, Widget pantalla)?
  alrededor;

  final LaTexturaDelTelefono textura;
  final ElSonidoDelTelefono sonido;

  @override
  State<LaPantallaDelEmulador> createState() => _LaPantallaDelEmuladorState();
}

/// Lo que la pantalla deja usar a quien la rodea: el emulador conectado y el
/// tamaño real de su pantalla y de lo que se ve.
class LaConexionDeLaPantalla {
  const LaConexionDeLaPantalla({
    required this.emulador,
    required this.nativo,
    required this.imagen,
    required this.sonido,
    required this.alternarSonido,
    required this.girar,
  });

  final ElEmuladorConectado emulador;

  /// El tamaño de la pantalla del teléfono en píxeles (`hw.lcd.*`).
  final ({int ancho, int alto})? nativo;

  /// El último fotograma: su tamaño y su giro.
  final ImagenDelEmulador imagen;

  /// Si el sonido del teléfono suena en el Mac.
  final bool sonido;
  final VoidCallback alternarSonido;

  /// Un cuarto de vuelta: de vertical a apaisado y vuelta.
  final VoidCallback girar;
}

class _LaPantallaDelEmuladorState extends State<LaPantallaDelEmulador> {
  ElEmuladorConectado? _emulador;
  ({int ancho, int alto})? _nativo;
  ({int textura, String archivo})? _textura;
  ImagenDelEmulador? _imagen;
  bool _noSePuede = false;

  StreamSubscription<ImagenDelEmulador>? _fotos;
  Timer? _respiro;
  ({int ancho, int alto})? _pedido;
  ({int ancho, int alto})? _caja;

  ImagenDelEmulador? _porSubir;
  bool _subiendo = false;

  /// El sonido, encendido de entrada (B1: oírlo es parte de usarlo).
  bool _conSonido = true;
  StreamSubscription<Uint8List>? _oido;

  /// Lo más grande que se pide: más no se ve mejor y cuesta memoria por
  /// fotograma (RGBA: 1080 × 2400 son 10 MB).
  static const _tope = 1600;

  @override
  void initState() {
    super.initState();
    unawaited(_conectar());
  }

  Future<void> _conectar() async {
    final info = await ElEmuladorConectado.buscar(widget.deviceId);
    if (!mounted) return;
    if (info == null) {
      setState(() => _noSePuede = true);
      return;
    }
    final emulador = ElEmuladorConectado.a(info);
    _emulador = emulador;
    final nativo = await emulador.tamanoDeLaPantalla();
    final textura = await widget.textura.crear();
    if (!mounted) {
      if (textura != null) unawaited(widget.textura.soltar(textura.textura));
      return;
    }
    if (textura == null) {
      setState(() => _noSePuede = true);
      return;
    }
    setState(() {
      _nativo = nativo;
      _textura = textura;
    });
    if (_caja case final caja?) _empezar(caja);
    if (_conSonido) unawaited(_oir());
  }

  /// El sonido del teléfono al Mac. Sin tiempo límite: un teléfono en silencio
  /// no manda nada, y eso no es un fallo (medido).
  Future<void> _oir() async {
    final emulador = _emulador;
    if (emulador == null || _oido != null) return;
    if (!await widget.sonido.empezar()) return;
    if (!mounted || !_conSonido) {
      unawaited(widget.sonido.parar());
      return;
    }
    _oido = emulador.sonido().listen(
      widget.sonido.pcm,
      onError: (Object _) => _oido = null,
    );
  }

  Future<void> _callar() async {
    await _oido?.cancel();
    _oido = null;
    await widget.sonido.parar();
  }

  void _alternarSonido() {
    setState(() => _conSonido = !_conSonido);
    unawaited(_conSonido ? _oir() : _callar());
  }

  /// De vertical a apaisado y vuelta, girando el teléfono —con su sensor—
  /// como en la prueba del 10 nov: z = 90 apaisado, z = 0 vertical.
  void _girar() {
    final imagen = _imagen;
    if (imagen == null) return;
    unawaited(
      _emulador
          ?.girar(imagen.cuartosDeGiro.isOdd ? 0 : 90)
          .catchError((Object _) {}),
    );
  }

  void _medir(Size caja, double densidad) {
    final ancho = math.min((caja.width * densidad).round(), _tope);
    final alto = math.min((caja.height * densidad).round(), _tope);
    if (ancho <= 0 || alto <= 0) return;
    final nueva = (ancho: ancho, alto: alto);
    if (nueva == _caja) return;
    _caja = nueva;
    _respiro?.cancel();
    _respiro = Timer(const Duration(milliseconds: 200), () {
      if (mounted && _textura != null) _empezar(nueva);
    });
  }

  void _empezar(({int ancho, int alto}) caja) {
    final emulador = _emulador;
    final textura = _textura;
    if (emulador == null || textura == null || caja == _pedido) return;
    _pedido = caja;
    unawaited(_fotos?.cancel());
    _fotos = emulador
        .fotogramas(ancho: caja.ancho, alto: caja.alto, mmap: textura.archivo)
        .listen(
          _llega,
          onError: (Object _) {
            if (mounted) setState(() => _noSePuede = true);
          },
        );
  }

  /// Uno a la vez hacia la textura: si llega otro mientras se sube el de
  /// antes, se sube solo el último —el archivo ya tiene ese—.
  void _llega(ImagenDelEmulador imagen) {
    _porSubir = imagen;
    if (!_subiendo) unawaited(_subir());
  }

  Future<void> _subir() async {
    final textura = _textura;
    while (_porSubir != null && textura != null && mounted) {
      _subiendo = true;
      final imagen = _porSubir!;
      _porSubir = null;
      final ok = await widget.textura.fotograma(
        textura.textura,
        ancho: imagen.ancho,
        alto: imagen.alto,
      );
      final antes = _imagen;
      // Solo se reconstruye cuando cambia la forma: los fotogramas de igual
      // tamaño los pinta la textura sola.
      if (ok &&
          mounted &&
          (antes == null ||
              antes.ancho != imagen.ancho ||
              antes.alto != imagen.alto ||
              antes.cuartosDeGiro != imagen.cuartosDeGiro)) {
        setState(() => _imagen = imagen);
      }
    }
    _subiendo = false;
  }

  @override
  void dispose() {
    _respiro?.cancel();
    unawaited(_fotos?.cancel());
    unawaited(_callar());
    unawaited(_emulador?.cerrar());
    if (_textura case final t?) unawaited(widget.textura.soltar(t.textura));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_noSePuede) return widget.sinPantalla;
    final colors = context.colors;
    final densidad = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, caja) {
        // La caja menos el margen y la columna de botones de al lado.
        final util = Size(
          math.max(0, caja.maxWidth - 2 * NexusSpacing.s4 - 52),
          math.max(0, caja.maxHeight - 2 * NexusSpacing.s4),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _medir(util, densidad);
        });
        final imagen = _imagen;
        final textura = _textura;
        if (imagen == null || textura == null) {
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
          // La pantalla desnuda, con su filete: sin marco de teléfono (ver la
          // maqueta), que miente el tamaño y gasta sitio en decoración.
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border.all(color: colors.rule),
            borderRadius: BorderRadius.circular(NexusRadius.sm),
          ),
          child: AspectRatio(
            aspectRatio: imagen.ancho / imagen.alto,
            child: Texture(textureId: textura.textura),
          ),
        );
        final conexion = LaConexionDeLaPantalla(
          emulador: _emulador!,
          nativo: _nativo,
          imagen: imagen,
          sonido: _conSonido,
          alternarSonido: _alternarSonido,
          girar: _girar,
        );
        return Padding(
          padding: const EdgeInsets.all(NexusSpacing.s4),
          child: Center(
            child: widget.alrededor?.call(conexion, pantalla) ?? pantalla,
          ),
        );
      },
    );
  }
}
