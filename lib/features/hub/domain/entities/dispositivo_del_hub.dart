/// Un dispositivo tal como lo enseña el hub: uno de la lista de la izquierda.
///
/// **Junta tres fuentes que hoy van por separado**: el catálogo de emuladores
/// (`flutter emulators` cruzado con `adb` y `simctl`), los teléfonos enchufados
/// (`flutter devices`) y las corridas. Ver `LosDispositivosDelHub`.
library;

/// De qué clase es: decide qué se puede hacer con él.
///
/// Un emulador o un simulador se arranca y se cierra; uno enchufado ya está, y
/// lo único que cabe es usarlo. Es la misma frontera que `Emulador` frente a
/// `DispositivoConectado`.
enum ClaseDeDispositivo { emulador, simulador, enchufado }

/// En qué está. Es lo que pinta el punto de la lista.
///
/// - [corre]: la app corre en él (verde).
/// - [encendido]: está arriba, sin corrida (tinta media).
/// - [arrancando]: se pidió arrancarlo y todavía no está (ámbar que late).
/// - [apagado]: existe en el catálogo y no está arriba (solo contorno).
enum EstadoDelDispositivo { apagado, arrancando, encendido, corre }

class DispositivoDelHub {
  const DispositivoDelHub({
    required this.id,
    required this.nombre,
    required this.android,
    required this.clase,
    required this.estado,
    this.deviceId,
    this.catalogo,
    this.configuracion,
  });

  /// Lo que lo identifica en la lista: el [deviceId] si está arriba, el id del
  /// catálogo si no. Cuando se arranca **cambia** —de `Medium_Phone_API_36.1` a
  /// `emulator-5554`— y quien lo tenía elegido lo sigue por [catalogo].
  final String id;

  final String nombre;
  final bool android;
  final ClaseDeDispositivo clase;
  final EstadoDelDispositivo estado;

  /// El que pide `-d`: `emulator-5554`, el UDID del simulador, el serial del
  /// teléfono. `null` mientras está apagado.
  final String? deviceId;

  /// El id de `flutter emulators`, con el que se arranca y se cierra. `null` en
  /// los enchufados, que no se arrancan.
  final String? catalogo;

  /// La configuración de su corrida, si [estado] es [EstadoDelDispositivo.corre].
  final String? configuracion;

  bool get encendido =>
      estado == EstadoDelDispositivo.encendido ||
      estado == EstadoDelDispositivo.corre;

  Map<String, Object?> toMap() => {
    'id': id,
    'nombre': nombre,
    'android': android,
    'clase': clase.name,
    'estado': estado.name,
    'deviceId': ?deviceId,
    'catalogo': ?catalogo,
    'configuracion': ?configuracion,
  };

  /// `null` si le falta lo que lo identifica: una fila sin id no se puede
  /// elegir, y pintarla sería ofrecer algo que no hace nada.
  static DispositivoDelHub? fromMap(Map<Object?, Object?> mapa) {
    final id = mapa['id'];
    final nombre = mapa['nombre'];
    if (id is! String || id.isEmpty || nombre is! String) return null;
    return DispositivoDelHub(
      id: id,
      nombre: nombre,
      android: mapa['android'] == true,
      clase:
          ClaseDeDispositivo.values.asNameMap()[mapa['clase']] ??
          ClaseDeDispositivo.enchufado,
      estado:
          EstadoDelDispositivo.values.asNameMap()[mapa['estado']] ??
          EstadoDelDispositivo.apagado,
      deviceId: mapa['deviceId'] as String?,
      catalogo: mapa['catalogo'] as String?,
      configuracion: mapa['configuracion'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DispositivoDelHub &&
      other.id == id &&
      other.nombre == nombre &&
      other.android == android &&
      other.clase == clase &&
      other.estado == estado &&
      other.deviceId == deviceId &&
      other.catalogo == catalogo &&
      other.configuracion == configuracion;

  @override
  int get hashCode => Object.hash(
    id,
    nombre,
    android,
    clase,
    estado,
    deviceId,
    catalogo,
    configuracion,
  );

  @override
  String toString() => 'DispositivoDelHub($id, ${estado.name})';
}
