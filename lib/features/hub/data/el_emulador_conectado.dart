import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:grpc/grpc.dart';
import 'package:nexus/features/hub/data/el_telefono_conectado.dart';
import 'package:nexus/features/hub/domain/el_emulador_por_grpc.dart';
import 'package:nexus/features/hub/domain/el_protocolo_del_emulador.dart';

/// **La conexión gRPC con un emulador**, desde el motor del hub (DG3).
///
/// El paquete `grpc` con serializadores crudos: los mensajes los escribe y los
/// lee [ElProtocoloDelEmulador], sin código generado. Es Dart puro, así que
/// funciona en el motor del hub, que no tiene plugins.
class ElEmuladorConectado extends Client implements ElTelefonoConectado {
  ElEmuladorConectado._(this._canal, String token)
    : super(
        _canal,
        options: CallOptions(metadata: {'authorization': 'Bearer $token'}),
      );

  factory ElEmuladorConectado.a(ElEmuladorPorGrpc emulador) =>
      ElEmuladorConectado._(
        ClientChannel(
          '127.0.0.1',
          port: emulador.puerto,
          options: const ChannelOptions(
            credentials: ChannelCredentials.insecure(),
          ),
        ),
        emulador.token,
      );

  final ClientChannel _canal;

  static ClientMethod<List<int>, List<int>> _metodo(String nombre) =>
      ClientMethod<List<int>, List<int>>(
        '${ElProtocoloDelEmulador.servicio}/$nombre',
        (v) => v,
        (v) => v,
      );

  static final _estado = _metodo('getStatus');
  static final _fotogramas = _metodo('streamScreenshot');
  static final _entrada = _metodo('streamInputEvent');
  static final _fisica = _metodo('setPhysicalModel');
  static final _sonido = _metodo('streamAudio');

  StreamController<List<int>>? _eventos;

  /// Dónde están los `.ini` de los emuladores que corren.
  static Directory get carpetaDeLosQueCorren => Directory(
    '${Platform.environment['HOME'] ?? ''}'
    '/Library/Caches/TemporaryItems/avd/running',
  );

  /// El emulador de [serial], si anunció gRPC al arrancar.
  static Future<ElEmuladorPorGrpc?> buscar(String serial) async {
    final carpeta = carpetaDeLosQueCorren;
    if (!carpeta.existsSync()) return null;
    final archivos = <String>[];
    await for (final f in carpeta.list()) {
      if (f is File && f.path.endsWith('.ini')) {
        try {
          archivos.add(await f.readAsString());
        } on FileSystemException {
          // Un emulador que se está cerrando borra su archivo: se sigue.
        }
      }
    }
    return ElEmuladorPorGrpc.de(serial, archivos);
  }

  /// El tamaño de su pantalla en píxeles, para traducir los toques.
  Future<({int ancho, int alto})?> tamanoDeLaPantalla() async {
    try {
      final estado = await $createUnaryCall(_estado, const <int>[]);
      return ElProtocoloDelEmulador.tamanoDeLaPantalla(estado);
    } on GrpcError {
      return null;
    }
  }

  /// Los fotogramas, encajados en [ancho]×[alto], escritos en [mmap].
  Stream<ImagenDelEmulador> fotogramas({
    required int ancho,
    required int alto,
    required String mmap,
  }) =>
      $createStreamingCall(
            _fotogramas,
            Stream.value(
              ElProtocoloDelEmulador.formatoDeImagen(
                ancho: ancho,
                alto: alto,
                mmap: mmap,
              ),
            ),
          )
          .map(ElProtocoloDelEmulador.leerImagen)
          .where((i) => i != null)
          .cast<ImagenDelEmulador>();

  /// Un evento de entrada (`InputEvent`) por la misma llamada abierta: una por
  /// evento serían decenas por segundo al arrastrar.
  void entrada(List<int> evento) {
    var eventos = _eventos;
    if (eventos == null || eventos.isClosed) {
      eventos = _eventos = StreamController<List<int>>();
      unawaited(
        $createStreamingCall(_entrada, eventos.stream).drain<void>().catchError(
          (Object _) {
            // Se cerró —el emulador se apagó—: el próximo evento abre otra.
            _eventos = null;
          },
        ),
      );
    }
    eventos.add(evento);
  }

  /// De vertical a apaisado y vuelta, girando el teléfono con su sensor:
  /// medido el 10 nov, z = 90 apaisado y z = 0 vertical.
  @override
  Future<void> girar({required bool apaisado}) async {
    await $createUnaryCall(
      _fisica,
      ElProtocoloDelEmulador.giro(apaisado ? 0 : 90),
    );
  }

  @override
  void toque(ToqueEnElTelefono toque) =>
      entrada(ElProtocoloDelEmulador.entradaDeToques([toque]));

  @override
  void tecla(String nombre) =>
      entrada(ElProtocoloDelEmulador.entradaDeTecla(nombre));

  @override
  void texto(String texto) =>
      entrada(ElProtocoloDelEmulador.entradaDeTexto(texto));

  @override
  void rueda({required int dx, required int dy, int x = 0, int y = 0}) =>
      entrada(ElProtocoloDelEmulador.rueda(dx: dx, dy: dy));

  /// El sonido en PCM de 16 bits estéreo. No manda nada mientras el teléfono
  /// no suena (medido): un silencio no es un fallo.
  Stream<Uint8List> sonido({int frecuencia = 44100}) =>
      $createStreamingCall(
            _sonido,
            Stream.value(
              ElProtocoloDelEmulador.formatoDeSonido(frecuencia: frecuencia),
            ),
          )
          .map(ElProtocoloDelEmulador.leerSonido)
          .where((pcm) => pcm != null && pcm.isNotEmpty)
          .cast<Uint8List>();

  @override
  Future<void> cerrar() async {
    await _eventos?.close();
    _eventos = null;
    await _canal.shutdown();
  }
}
