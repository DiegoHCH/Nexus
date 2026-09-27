import 'package:flutter/foundation.dart';

/// Por dónde va la versión nueva del Mac, tal como la ve el teléfono.
///
/// **Menos fases que el actualizador del Mac, a propósito.** «Buscando» y «estás al
/// día» solo se enseñan en el Mac tras una comprobación que pidió alguien delante
/// de él; en el teléfono serían carteles que nadie pidió. Y el reposo no es una
/// fase: es que no hay aviso, y viaja como tal.
///
/// El nombre de cable va aparte del de Dart porque el de Dart se puede renombrar
/// y el que viaja no: un teléfono instalado lo lleva escrito.
enum FaseDelMac {
  /// Hay versión nueva y nadie ha dicho nada.
  disponible('available'),

  /// Bajando.
  descargando('downloading'),

  /// Descomprimiendo. Aparte de la descarga porque su barra vuelve a empezar, y
  /// una barra que salta de lleno a vacío sin cambiar de rótulo parece un fallo.
  preparando('extracting'),

  /// Bajada y comprobada, esperando el permiso para reiniciar.
  lista('ready'),

  /// Cambiando la app. A partir de aquí el Mac se va y vuelve.
  instalando('installing'),

  /// El actualizador dijo que no.
  fallida('failed');

  const FaseDelMac(this.cable);

  final String cable;

  static FaseDelMac? leer(Object? crudo) =>
      FaseDelMac.values.where((f) => f.cable == crudo).firstOrNull;
}

/// La actualización del Mac, como viaja por el canal: en el saludo y en el evento
/// `update` (ver `docs/PROTOCOL.md`).
///
/// **Es una foto y no una orden**, por lo mismo que la vista de una conversación: el
/// teléfono pinta lo que dice y nada más, y el siguiente envío la sustituye entera.
/// Así un evento perdido se arregla solo en el siguiente, y el saludo de una
/// reconexión deja al teléfono al día sin reconstruir nada.
@immutable
class ActualizacionDelMac {
  const ActualizacionDelMac({
    required this.fase,
    required this.version,
    required this.actual,
    this.progreso,
    this.descargada = false,
    this.reiniciaAlTerminar = false,
    this.esperaATerminar = false,
    this.hayTrabajoEnMarcha = false,
    this.sePuedeInstalar = true,
    this.mensaje,
  });

  final FaseDelMac fase;

  /// A la que se va. Puede venir vacía si el feed no la dijo: entonces el aviso se
  /// pinta sin título, igual que en el Mac.
  final String version;

  /// La que corre en el Mac ahora.
  final String actual;

  /// De 0 a 100, **en pasos de cinco**. Solo al bajar y al preparar, y `null` si no
  /// se sabe el total.
  ///
  /// En pasos porque cada cambio es un evento numerado que ocupa sitio en el búfer
  /// del resync: Sparkle avisa por cada trozo que llega, y reenviar cada uno se
  /// comería el hueco que el búfer guarda para las conversaciones. Veinte pasos
  /// bastan para que una barra en un teléfono se vea moverse.
  final int? progreso;

  /// Si ya estaba bajada de antes. Cambia lo que hace el sí: no hay nada que bajar,
  /// así que reinicia en el acto.
  final bool descargada;

  /// Que ya se dijo «reiniciar al terminar» —en el Mac o aquí— y se cumplirá solo.
  final bool reiniciaAlTerminar;

  /// Aceptada, pero **esperando a que termine lo que está en marcha**. Es la regla
  /// del aviso del Mac: reiniciar no corta una frase ni un encargo.
  final bool esperaATerminar;

  /// Si ahora mismo hay algo hablando, escuchando o trabajando en el Mac.
  ///
  /// Viaja para poder decirlo **antes** de que se pulse: quien acepta desde el
  /// teléfono no ve el Mac, y tiene que saber que su sí va a esperar.
  final bool hayTrabajoEnMarcha;

  /// Si esa copia de Nexus puede reemplazarse. Si no —abierta desde Descargas sin
  /// moverla—, el Mac no ofrece instalar y el teléfono tampoco.
  final bool sePuedeInstalar;

  /// Lo que dijo el actualizador al fallar.
  final String? mensaje;

  /// Si aceptarla ahora reinicia el Mac **en el acto**, sin bajar nada antes.
  bool get reiniciaYa =>
      fase == FaseDelMac.lista || (fase == FaseDelMac.disponible && descargada);

  /// Si el Mac ya está comprometido a reiniciarse: lista y pedida, o instalando.
  ///
  /// Es lo que convierte «se cayó el enlace» en «se está actualizando»: si el Mac
  /// va a irse, perder el enlace es lo esperado y no una avería.
  bool get vaAReiniciarse =>
      fase == FaseDelMac.instalando ||
      (fase == FaseDelMac.lista && (esperaATerminar || reiniciaAlTerminar));

  Map<String, Object?> toJson() => {
    'phase': fase.cable,
    'version': version,
    'current': actual,
    'progress': ?progreso,
    if (descargada) 'downloaded': true,
    if (reiniciaAlTerminar) 'restartWhenDone': true,
    if (esperaATerminar) 'waiting': true,
    if (hayTrabajoEnMarcha) 'busy': true,
    // Al revés que los demás: lo normal es que se pueda, y lo que se dice es que no.
    if (!sePuedeInstalar) 'installable': false,
    'message': ?mensaje,
  };

  /// Lee lo que llegó. `null` es **no hay aviso**: porque el Mac lo dijo, porque no
  /// dijo nada, o porque habla de una fase que este teléfono no conoce.
  ///
  /// Lo último es la tolerancia hacia adelante del protocolo: un Mac más nuevo con
  /// una fase más no puede tumbar a este teléfono, y un aviso que no se entiende es
  /// mejor no enseñarlo que enseñarlo mal.
  static ActualizacionDelMac? fromJson(Map<String, Object?>? json) {
    if (json == null) return null;
    final fase = FaseDelMac.leer(json['phase']);
    if (fase == null) return null;
    return ActualizacionDelMac(
      fase: fase,
      version: json['version'] as String? ?? '',
      actual: json['current'] as String? ?? '',
      progreso: (json['progress'] as num?)?.round(),
      descargada: json['downloaded'] == true,
      reiniciaAlTerminar: json['restartWhenDone'] == true,
      esperaATerminar: json['waiting'] == true,
      hayTrabajoEnMarcha: json['busy'] == true,
      sePuedeInstalar: json['installable'] != false,
      mensaje: json['message'] as String?,
    );
  }

  /// Lo que viaja cuando **no** hay aviso.
  ///
  /// Explícito y no un evento vacío: «ya no hay nada» es una noticia —se instaló en
  /// el Mac, o se dejó para luego allí— y el teléfono tiene que poder distinguirla de
  /// un evento que no dice nada.
  static const Map<String, Object?> ninguna = {'phase': 'none'};

  @override
  bool operator ==(Object other) =>
      other is ActualizacionDelMac &&
      other.fase == fase &&
      other.version == version &&
      other.actual == actual &&
      other.progreso == progreso &&
      other.descargada == descargada &&
      other.reiniciaAlTerminar == reiniciaAlTerminar &&
      other.esperaATerminar == esperaATerminar &&
      other.hayTrabajoEnMarcha == hayTrabajoEnMarcha &&
      other.sePuedeInstalar == sePuedeInstalar &&
      other.mensaje == mensaje;

  @override
  int get hashCode => Object.hash(
    fase,
    version,
    actual,
    progreso,
    descargada,
    reiniciaAlTerminar,
    esperaATerminar,
    hayTrabajoEnMarcha,
    sePuedeInstalar,
    mensaje,
  );

  @override
  String toString() => 'ActualizacionDelMac(${fase.name} $version)';
}

/// Qué hizo el Mac con el sí del teléfono.
///
/// Se contesta porque el teléfono lo necesita para decir la verdad en pantalla: no
/// es lo mismo «se va ahora» que «esperará a que termine» o «primero tiene que
/// bajarla».
enum TrasAceptarEnElMac {
  /// Se va ya: el teléfono pasa a «actualizando el Mac».
  reinicia('restarting'),

  /// Aceptada, esperando a que termine lo que está en marcha.
  espera('waiting'),

  /// Aceptada, bajando primero. Reiniciará al terminar —esperando, si hace falta—.
  descarga('downloading');

  const TrasAceptarEnElMac(this.cable);

  final String cable;

  static TrasAceptarEnElMac? leer(Object? crudo) =>
      TrasAceptarEnElMac.values.where((t) => t.cable == crudo).firstOrNull;
}

/// Lo que el canal necesita del actualizador del Mac, y **nada más**.
///
/// La misma costura que `RemoteSurface` y por el mismo motivo: el canal no sabe que
/// existe Sparkle ni cómo está montado el aviso, y quien lo implementa vive donde sí
/// puede leerlo. Aparte de la superficie del asistente porque actualizar no es de
/// ninguna conversación.
abstract class ActualizadorRemoto {
  /// Lo que hace el sí del aviso del Mac, en el paso en que esté.
  ///
  /// [version] es la que vio quien aceptó. Si el Mac ofrece ahora otra, lanza
  /// [OtraVersionEnElMac]: el sí se dio a una versión concreta, no a la que toque.
  Future<TrasAceptarEnElMac> actualizarYReiniciar({String? version});

  /// Lo que hace «Más tarde» en el aviso del Mac.
  Future<void> dejarParaLuego();
}

/// No hay ninguna versión que aceptar ahora mismo.
class SinActualizacionEnElMac implements Exception {
  const SinActualizacionEnElMac();

  @override
  String toString() => 'SinActualizacionEnElMac()';
}

/// Esta copia de Nexus no puede reemplazarse a sí misma.
class NoSePuedeInstalarEnElMac implements Exception {
  const NoSePuedeInstalarEnElMac();

  @override
  String toString() => 'NoSePuedeInstalarEnElMac()';
}

/// El teléfono aceptó una versión y el Mac ofrece ya otra.
class OtraVersionEnElMac implements Exception {
  const OtraVersionEnElMac(this.ofrecida);

  final String ofrecida;

  @override
  String toString() => 'OtraVersionEnElMac($ofrecida)';
}
