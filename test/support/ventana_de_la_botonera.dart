import 'package:nexus/features/run/data/datasources/la_ventana_de_la_botonera.dart';

/// La ventana de la botonera, sin ventana: apunta lo que se le pide.
///
/// Hace falta porque en una prueba el canal nativo **no contesta nunca** —ni
/// siquiera con el «no hay plugin» de siempre—: la llamada se queda esperando y
/// la botonera no sabe si salió o no. Con esto se decide a propósito.
///
/// [sale] en `false` es el plan B: el motor de fuera no arrancó y la barra se
/// queda dentro de Nexus, que es donde miran las pruebas de geometría.
class VentanaQueApunta implements LaVentanaDeLaBotonera {
  VentanaQueApunta({this.sale = true});

  final bool sale;

  /// En orden: `abrir`, `pintar`, `cerrar`.
  final llamadas = <String>[];

  /// La última foto que se le mandó.
  Map<String, Object?>? foto;

  void Function(Map<Object?, Object?> pedido)? _atender;

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

  /// Lo que haría la ventana al pulsar algo en ella.
  void pulsan(Map<Object?, Object?> pedido) => _atender?.call(pedido);

  /// Lo que contesta al pedirle que pegue el espejo: `sinPermiso` es macOS
  /// diciendo que no se mueven ventanas ajenas sin Accesibilidad.
  EspejoPegado alPegar = EspejoPegado.buscando;

  /// Los espejos que se le pidió pegar, en orden.
  final pegados = <Map<String, Object?>>[];

  void Function()? _alPermitir;

  @override
  Future<EspejoPegado> pegarElEspejo(Map<String, Object?> busca) async {
    llamadas.add('pegar');
    pegados.add(busca);
    return alPegar;
  }

  @override
  Future<void> soltarElEspejo() async => llamadas.add('soltar');

  @override
  Future<void> pedirPermisoDelEspejo() async => llamadas.add('permiso');

  @override
  void alPermitirElEspejo(void Function() hacer) => _alPermitir = hacer;

  /// Lo que haría macOS al dar el permiso en Ajustes.
  void permiten() => _alPermitir?.call();

  /// Las llamadas a la ventana misma, sin las del espejo: las pruebas de
  /// cuándo sale y cuándo se va no hablan del espejo.
  List<String> get deLaVentana => [
    for (final l in llamadas)
      if (l == 'abrir' || l == 'pintar' || l == 'cerrar') l,
  ];
}
