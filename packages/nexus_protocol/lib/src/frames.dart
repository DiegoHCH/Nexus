import 'dart:convert';

import 'package:meta/meta.dart';

import 'failures.dart';
import 'methods.dart';
import 'version.dart';

/// Un mensaje del canal.
///
/// Tres formas, como dice el documento: petición/respuesta, eventos empujados y
/// snapshot. No una sola tubería por la que pase todo — eso obliga a cada extremo
/// a adivinar qué acaba de recibir.
///
/// JSON en texto y no un formato binario: el volumen es bajo **después de agrupar
/// los deltas** —ficha `lo4`— y los dos extremos son Dart, así que lo que se gana
/// con protobuf es poco y lo que se pierde, poder leer una traza con los ojos.
@immutable
sealed class Frame {
  const Frame();

  /// El discriminador va en `t`, y es corto porque viaja en **cada** mensaje.
  static const claveTipo = 't';

  Map<String, Object?> toJson();

  String encode() => jsonEncode(toJson());

  /// Lee un mensaje, y **nunca lanza por no conocerlo**.
  ///
  /// Esa es la regla que hace posible que los dos extremos se actualicen por su
  /// cuenta: lo que no se reconoce vuelve como [UnknownFrame] y quien lo recibe lo
  /// ignora. Si esto lanzara, añadir un evento nuevo al servidor rompería a todos
  /// los teléfonos que no se hubieran actualizado todavía — y entonces cada añadido
  /// sería un cambio de versión.
  ///
  /// Lo que sí lanza es el JSON que no es JSON, o el que no trae `t`: eso no es un
  /// mensaje del futuro, es un mensaje roto.
  static Frame decode(String texto) {
    final crudo = jsonDecode(texto);
    if (crudo is! Map<String, Object?>) {
      throw FormatException('un mensaje tiene que ser un objeto', texto);
    }
    final tipo = crudo[claveTipo];
    if (tipo is! String) {
      throw FormatException('falta «$claveTipo» o no es texto', texto);
    }
    return switch (tipo) {
      'hello' => Hello.fromJson(crudo),
      'welcome' => Welcome.fromJson(crudo),
      'upgrade' => UpgradeRequired.fromJson(crudo),
      'call' => Call.fromJson(crudo),
      'ack' => Ack.fromJson(crudo),
      'result' => Result.fromJson(crudo),
      'failure' => Failure.fromJson(crudo),
      'event' => Event.fromJson(crudo),
      'snapshot' => Snapshot.fromJson(crudo),
      'resume' => Resume.fromJson(crudo),
      'audio' => Audio.fromJson(crudo),
      _ => UnknownFrame(type: tipo, raw: crudo),
    };
  }
}

/// Quién habla. Hace falta para el registro append-only de la decisión 2.5: «lo
/// pidió el móvil» y «lo pidió el escritorio» no son la misma línea.
enum Peer { desktop, mobile }

// ─────────────────────────── el saludo ───────────────────────────

/// Primer mensaje del cliente.
///
/// **El token no va aquí**: viaja en una cabecera del upgrade, por la decisión 2.1.
/// Un token dentro del primer mensaje acabaría en cualquier traza que registre el
/// primer mensaje, que es justo lo que se quería evitar.
final class Hello extends Frame {
  const Hello({
    required this.protocol,
    required this.peer,
    required this.appVersion,
  });

  factory Hello.fromJson(Map<String, Object?> j) => Hello(
    protocol: ProtocolRange.fromJson(j['protocol']! as Map<String, Object?>),
    peer: Peer.values.byName(j['peer']! as String),
    appVersion: j['app'] as String? ?? '',
  );

  final ProtocolRange protocol;
  final Peer peer;

  /// La versión de la app, que es distinta de la del protocolo y solo sirve para
  /// el registro y para poder decir «actualiza» nombrando algo reconocible.
  final String appVersion;

  @override
  Map<String, Object?> toJson() => {
    Frame.claveTipo: 'hello',
    'protocol': protocol.toJson(),
    'peer': peer.name,
    'app': appVersion,
  };
}

/// El servidor acepta y dice por dónde va la numeración de eventos.
final class Welcome extends Frame {
  const Welcome({
    required this.protocol,
    required this.seq,
    this.accent,
    this.app,
    this.update,
    this.character,
  });

  factory Welcome.fromJson(Map<String, Object?> j) => Welcome(
    protocol: ProtocolRange.fromJson(j['protocol']! as Map<String, Object?>),
    seq: j['seq']! as int,
    accent: j['accent'] as int?,
    app: j['app'] as String?,
    // Solo si es un objeto: cualquier otra cosa es un Mac que no se entiende, y un
    // aviso que no se entiende no se enseña — no se revienta por él.
    update: switch (j['update']) {
      final Map<String, Object?> datos => datos,
      _ => null,
    },
    // Lo mismo: un personaje que no es un objeto no se entiende, y sin entenderlo
    // el teléfono pinta el orbe, que es lo que pintaba.
    character: switch (j['character']) {
      final Map<String, Object?> datos => datos,
      _ => null,
    },
  );

  final ProtocolRange protocol;

  /// El acento elegido en el Mac, en ARGB. `null` si este Mac es más viejo que este
  /// campo.
  ///
  /// **Viaja en el saludo y no en el QR**, y esa es la decisión. En el QR quedaría
  /// congelado en el momento de emparejar: el día que se cambia el acento en el Mac, el
  /// teléfono se quedaría con el viejo y habría **dos fuentes de verdad para algo que
  /// cambia**. En el saludo llega en cada conexión, así que cambiarlo en el Mac lo
  /// arregla solo.
  ///
  /// Y va aquí porque el saludo es el sitio de lo que es **del Mac** y no de una
  /// conversación — como el `seq` y el rango de protocolo.
  ///
  /// Opcional a propósito: añadir un campo obligatorio al saludo rompería a cualquier
  /// teléfono que no lo conozca, y la tolerancia hacia adelante del protocolo existe
  /// justo para no tener que hacer eso.
  final int? accent;

  /// La versión de Nexus que corre en el Mac. `null` si el Mac es más viejo que este
  /// campo.
  ///
  /// Hace falta para **decir que la actualización salió bien** y no suponerlo: el
  /// teléfono pide «actualizar y reiniciar», el Mac se va, y lo único que prueba que
  /// volvió en la versión nueva es que lo diga al saludar. Sin esto el teléfono solo
  /// podría creer que funcionó.
  ///
  /// Es el gemelo de [Hello.appVersion], que va en el otro sentido.
  final String? app;

  /// Si el Mac tiene una versión nueva que ofrecer, y por dónde va, en la forma que
  /// describe `docs/PROTOCOL.md` (el evento `update`). `null` si no hay nada —o si
  /// el Mac es más viejo que este campo, que para el teléfono es lo mismo: no hay
  /// aviso que enseñar—.
  ///
  /// Un mapa y no un tipo propio por lo mismo que [Event.data]: el paquete es el
  /// sobre, y lo que va dentro lo leen los dos extremos con su propio modelo.
  ///
  /// Va en el saludo **además** de en su evento porque quien conecta con la
  /// actualización ya ofrecida no vería el evento que la anunció — igual que el
  /// acento.
  final Map<String, Object?>? update;

  /// Si en la sala del Mac va el personaje en vez del orbe, y con qué luz y qué
  /// ojos, en la forma que describe `docs/PROTOCOL.md` (el evento `character`).
  /// `null` si el Mac es más viejo que este campo: el teléfono pinta el orbe.
  ///
  /// Un mapa y no un tipo propio por lo mismo que [update]: lo que va dentro son
  /// ajustes de la app, que los leen los dos extremos con su propio modelo, y el
  /// paquete solo es el sobre.
  ///
  /// En el saludo **además** de en su evento, como el acento: quien conecta
  /// después de que se eligiera no vio el evento que lo contó.
  final Map<String, Object?>? character;

  /// El último evento emitido. Con esto el cliente sabe si va al día o le faltan
  /// cosas, **sin pedir el snapshot entero**.
  final int seq;

  @override
  Map<String, Object?> toJson() => {
    Frame.claveTipo: 'welcome',
    'protocol': protocol.toJson(),
    'seq': seq,
    'accent': ?accent,
    'app': ?app,
    'update': ?update,
    'character': ?character,
  };
}

/// No se entienden, y se dice **a quién le toca actualizarse**.
final class UpgradeRequired extends Frame {
  const UpgradeRequired({required this.protocol, required this.who});

  factory UpgradeRequired.fromJson(Map<String, Object?> j) => UpgradeRequired(
    protocol: ProtocolRange.fromJson(j['protocol']! as Map<String, Object?>),
    who: Peer.values.byName(j['who']! as String),
  );

  final ProtocolRange protocol;

  /// Quién tiene que actualizarse. Va explícito porque los dos sentidos son
  /// posibles —la tienda puede empujar el móvil mientras el Mac lleva semanas sin
  /// abrirse— y decirle «actualiza» a quien no puede hacer nada es el peor error
  /// que puede tener una pantalla de error.
  final Peer who;

  @override
  Map<String, Object?> toJson() => {
    Frame.claveTipo: 'upgrade',
    'protocol': protocol.toJson(),
    'who': who.name,
  };
}

// ─────────────────────── petición y respuesta ───────────────────────

/// Una petición del cliente.
final class Call extends Frame {
  const Call({required this.id, required this.method, this.params = const {}});

  factory Call.fromJson(Map<String, Object?> j) => Call(
    id: j['id']! as String,
    method: j['m']! as String,
    params: (j['p'] as Map<String, Object?>?) ?? const {},
  );

  /// El `clientMsgId` de la ficha `lo3`: **lo genera el cliente**, y es lo que
  /// permite al servidor reconocer un reenvío.
  ///
  /// Sin esto, un WebSocket que cae después de que el escritorio recibió el encargo
  /// pero antes de confirmarlo hace que el móvil lo reenvíe y `claude -p` corra dos
  /// veces — con `acceptEdits`, escribiendo dos veces en los archivos.
  final String id;

  /// El nombre del método. Texto y no [RemoteMethod] porque **el servidor puede
  /// recibir uno que no conoce**, de un cliente más nuevo, y eso tiene que poder
  /// contestarse con un error y no reventar al decodificar.
  final String method;

  final Map<String, Object?> params;

  /// El método, si es de los que existen aquí.
  RemoteMethod? get known => RemoteMethod.tryParse(method);

  @override
  Map<String, Object?> toJson() => {
    Frame.claveTipo: 'call',
    'id': id,
    'm': method,
    if (params.isNotEmpty) 'p': params,
  };
}

/// «Lo tengo», y es lo que cierra el agujero del reenvío.
///
/// Va aparte de [Result] a propósito: un encargo tarda minutos, así que confirmar
/// la recepción y devolver el resultado no pueden ser el mismo mensaje. Si lo
/// fueran, el cliente no sabría si reenviar durante todo ese rato.
final class Ack extends Frame {
  const Ack({required this.id, this.duplicate = false});

  factory Ack.fromJson(Map<String, Object?> j) =>
      Ack(id: j['id']! as String, duplicate: j['dup'] as bool? ?? false);

  final String id;

  /// Si ya se había recibido. El cliente no tiene que hacer nada distinto —su
  /// petición está atendida— pero el registro sí quiere saberlo.
  final bool duplicate;

  @override
  Map<String, Object?> toJson() => {
    Frame.claveTipo: 'ack',
    'id': id,
    if (duplicate) 'dup': true,
  };
}

final class Result extends Frame {
  const Result({required this.id, this.data = const {}});

  factory Result.fromJson(Map<String, Object?> j) => Result(
    id: j['id']! as String,
    data: (j['d'] as Map<String, Object?>?) ?? const {},
  );

  final String id;
  final Map<String, Object?> data;

  @override
  Map<String, Object?> toJson() => {
    Frame.claveTipo: 'result',
    'id': id,
    if (data.isNotEmpty) 'd': data,
  };
}

/// Algo salió mal. [id] es nulo cuando el fallo no es de ninguna petición —el
/// saludo, por ejemplo—.
final class Failure extends Frame {
  const Failure({
    required this.code,
    required this.message,
    this.id,
    this.args = const {},
  });

  /// Con el código del contrato, que es lo que se debería usar siempre.
  ///
  /// Un constructor aparte y no cambiar el tipo de [code] porque **lo que viaja
  /// es texto**, y tiene que seguir siéndolo: un teléfono tiene que poder leer
  /// un código que no conoce sin reventar.
  factory Failure.of(
    FailureCode code, {
    String? id,
    String message = '',
    Map<String, Object?> args = const {},
  }) => Failure(code: code.name, message: message, id: id, args: args);

  factory Failure.fromJson(Map<String, Object?> j) => Failure(
    code: j['code']! as String,
    message: j['msg'] as String? ?? '',
    id: j['id'] as String?,
    args: (j['a'] as Map<String, Object?>?) ?? const {},
  );

  /// El código estable. Ver [FailureCode].
  final String code;

  /// Una frase **para el registro**, en el idioma del Mac.
  ///
  /// 🔴 No se enseña: quien la lee en pantalla la lee en el idioma de otro
  /// aparato. El teléfono traduce [code] con [args].
  final String message;
  final String? id;

  /// Los datos del código —ver [FailureArg]—. Opcionales y aditivos: un Mac
  /// viejo no los manda, y un teléfono viejo no los lee.
  final Map<String, Object?> args;

  /// El código, si este extremo lo conoce.
  FailureCode? get known => FailureCode.tryParse(code);

  @override
  Map<String, Object?> toJson() => {
    Frame.claveTipo: 'failure',
    'code': code,
    if (message.isNotEmpty) 'msg': message,
    if (id != null) 'id': id,
    if (args.isNotEmpty) 'a': args,
  };
}

// ──────────────────── eventos, snapshot y resync ────────────────────

/// Algo que pasó, numerado.
///
/// El `seq` es monotónico y **no se reinicia** mientras el servidor vive: es lo que
/// hace que reconectar sea «mándame desde el 412» en vez de «mándame todo», que en
/// 4G es la diferencia entre barato y caro.
final class Event extends Frame {
  const Event({required this.seq, required this.kind, this.data = const {}});

  factory Event.fromJson(Map<String, Object?> j) => Event(
    seq: j['seq']! as int,
    kind: j['k']! as String,
    data: (j['d'] as Map<String, Object?>?) ?? const {},
  );

  final int seq;

  /// Texto y no un enum, por lo mismo que en [Call.method]: un cliente viejo tiene
  /// que poder **ignorar** un evento que no conoce. Con un enum, decodificarlo
  /// lanzaría, y añadir un evento al servidor sería romper a todo el que no se
  /// hubiera actualizado.
  final String kind;

  final Map<String, Object?> data;

  @override
  Map<String, Object?> toJson() => {
    Frame.claveTipo: 'event',
    'seq': seq,
    'k': kind,
    if (data.isNotEmpty) 'd': data,
  };
}

/// Un trozo de micrófono del teléfono, camino del Mac.
///
/// **Sin confirmación y sin reintento**, y es la decisión de fondo de la voz remota:
/// el audio es tiempo real, así que un trozo que llega tarde es peor que un hueco —
/// reenviarlo mete en la conversación medio segundo de hace un rato. Por eso no es un
/// [Call]: un `ack` por trozo serían tres mensajes por cada 20 ms de voz, y lo que
/// protege el deduplicador —efectos que no se repiten— aquí no aplica: un trozo de
/// audio duplicado no borra un archivo, solo suena raro.
///
/// El PCM va en base64 porque el canal es de texto. Cuesta un tercio más de bytes, y a
/// 16 kHz mono de 16 bits eso son unos 43 KB/s: nada por Tailscale, y menos que
/// levantar un segundo transporte binario solo para esto.
///
/// [seq] es **por sesión de voz y no global**: sirve para saber si se perdió algo y en
/// qué orden van los trozos, no para reclamarlos. Con el `seq` de los eventos no valía
/// porque los eventos van del Mac al teléfono y esto va al revés.
final class Audio extends Frame {
  const Audio({required this.seq, required this.pcmBase64});

  factory Audio.fromJson(Map<String, Object?> j) =>
      Audio(seq: j['seq']! as int, pcmBase64: j['pcm']! as String);

  final int seq;

  /// PCM de 16 bits, 16 kHz, mono — el mismo formato que pide la Live API, para que
  /// nadie tenga que convertir nada en medio.
  final String pcmBase64;

  @override
  Map<String, Object?> toJson() => {
    Frame.claveTipo: 'audio',
    'seq': seq,
    'pcm': pcmBase64,
  };
}

/// «Mándame desde aquí».
final class Resume extends Frame {
  const Resume({required this.lastSeq});

  factory Resume.fromJson(Map<String, Object?> j) =>
      Resume(lastSeq: j['last']! as int);

  final int lastSeq;

  @override
  Map<String, Object?> toJson() => {Frame.claveTipo: 'resume', 'last': lastSeq};
}

/// El estado entero. **Camino de excepción**, no el normal: se manda cuando el
/// cliente pide desde un `seq` que ya no está en el búfer.
final class Snapshot extends Frame {
  const Snapshot({required this.seq, required this.data});

  factory Snapshot.fromJson(Map<String, Object?> j) => Snapshot(
    seq: j['seq']! as int,
    data: (j['d'] as Map<String, Object?>?) ?? const {},
  );

  final int seq;
  final Map<String, Object?> data;

  @override
  Map<String, Object?> toJson() => {
    Frame.claveTipo: 'snapshot',
    'seq': seq,
    'd': data,
  };
}

/// Un mensaje de una versión que este extremo no conoce.
///
/// No es un error: es lo que hace que el canal aguante que los dos lados se
/// actualicen por su cuenta. Quien lo recibe lo ignora — y conserva el crudo, para
/// poder registrarlo y saber qué se está perdiendo.
final class UnknownFrame extends Frame {
  const UnknownFrame({required this.type, required this.raw});

  final String type;
  final Map<String, Object?> raw;

  @override
  Map<String, Object?> toJson() => raw;
}
