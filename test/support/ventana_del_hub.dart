import 'package:nexus/features/hub/data/la_ventana_del_hub.dart';

/// La ventana del hub, de mentira: apunta lo que se le pide y deja simular lo
/// que llega de ella —un pedido, que la cierren—.
class VentanaDelHubQueApunta implements LaVentanaDelHub {
  VentanaDelHubQueApunta({this.sale = true});

  final bool sale;

  final llamadas = <String>[];

  Map<String, Object?>? foto;

  void Function(Map<Object?, Object?> pedido)? _atender;
  void Function()? _alCerrarse;

  @override
  Future<bool> abrir(Map<String, Object?> foto) async {
    llamadas.add('abrir');
    this.foto = foto;
    return sale;
  }

  @override
  Future<void> pintar(Map<String, Object?> foto) async {
    llamadas.add('pintar');
    this.foto = foto;
  }

  @override
  Future<void> cerrar() async => llamadas.add('cerrar');

  @override
  void alPedir(void Function(Map<Object?, Object?> pedido) atender) =>
      _atender = atender;

  @override
  void alCerrarse(void Function() hacer) => _alCerrarse = hacer;

  final traidas = <({List<String> apps, List<String> ejecutables})>[];

  @override
  Future<bool> traerAlFrente({
    List<String> apps = const [],
    List<String> ejecutables = const [],
  }) async {
    traidas.add((apps: apps, ejecutables: ejecutables));
    return true;
  }

  void pulsan(Map<Object?, Object?> pedido) => _atender?.call(pedido);

  void laCierran() => _alCerrarse?.call();
}
