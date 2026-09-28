import 'package:nexus/features/remote/domain/actualizacion_del_mac.dart';
import 'package:nexus/features/remote/domain/remote_surface.dart';
import 'package:nexus/features/remote/domain/write_phrase.dart';
import 'package:nexus_protocol/nexus_protocol.dart';

/// Atiende lo que pide el teléfono.
///
/// No sabe nada de sockets: recibe un [Call] y devuelve los marcos que hay que
/// mandar, en orden. Así se prueba el despacho entero —incluido el reenvío, que es
/// la parte peligrosa— sin levantar un servidor ni fingir un WebSocket.
///
/// Y no sabe nada de la app: habla con [RemoteSurface], que es la costura de la
/// pieza anterior.
class Dispatcher {
  Dispatcher({
    required this.surface,
    required this.unlock,
    required this.phrases,
    this.actualizador,
    Deduplicator? dedupe,
  }) : dedupe = dedupe ?? Deduplicator(ttl: const Duration(minutes: 10));

  final RemoteSurface surface;

  /// El actualizador del Mac, si lo hay.
  ///
  /// Opcional porque no siempre existe —en las pruebas, o fuera de macOS, no hay
  /// Sparkle detrás— y sin él lo honesto es contestar que no hay nada que instalar,
  /// no fingir que se instaló.
  final ActualizadorRemoto? actualizador;

  /// Quien concede y caduca el permiso de escritura.
  final WriteUnlock unlock;

  /// De donde sale la frase guardada. Se lee en cada intento y no se cachea: si se
  /// cacheara, cambiarla en Ajustes no cerraría la puerta hasta reiniciar.
  final WritePhraseStore phrases;

  final Deduplicator dedupe;

  /// El tope de cuántos mensajes puede pedir de una vez.
  ///
  /// Existe porque el límite lo manda el cliente y un cliente puede pedir cien mil.
  /// La paginación protege al teléfono de tragarse una sesión; esto protege al Mac
  /// de que se la pidan.
  static const maxPagina = 200;

  /// El tope de lo que se manda de un documento.
  ///
  /// Es el mismo tipo de límite que [maxPagina] y faltaba: leer un archivo entero
  /// en memoria es un pico en el Mac, y mandarlo entero es un marco de WebSocket
  /// que el teléfono va a tragar por 4G. Medio mega es generoso para texto —un
  /// informe largo son treinta kilobytes— y el que no quepa se abre en el Mac,
  /// que es lo que ya se contesta de un binario.
  static const maxBytesDeDocumento = 512 * 1024;

  /// Los marcos a enviar, en orden.
  Stream<Frame> attend(Call call) async* {
    // **El ack antes de ejecutar, y esto es el orden y no un detalle.**
    //
    // Un encargo tarda minutos. Si la confirmación fuera con el resultado, el móvil
    // pasaría esos minutos sin saber si su petición llegó — y un móvil que no lo
    // sabe reenvía. De ahí sale el encargo que corre dos veces.
    final primeraVez = dedupe.aceptar(call.id);
    yield Ack(id: call.id, duplicate: !primeraVez);

    // Un reenvío se confirma y **no se ejecuta**. Es la razón de ser de todo esto:
    // con `acceptEdits` de por medio, ejecutarlo dos veces escribe dos veces.
    if (!primeraVez) return;

    final metodo = call.known;
    if (metodo == null) {
      // Un método que este Mac no conoce viene de un cliente más nuevo. Se contesta
      // con un error y no se cierra la conexión: el resto de lo que sabe pedir
      // sigue funcionando.
      yield Failure.of(
        FailureCode.unknownMethod,
        id: call.id,
        message: 'este Mac no conoce «${call.method}»',
        args: {FailureArg.method: call.method},
      );
      return;
    }

    try {
      yield await _atender(metodo, call);
    } on UnknownConversation catch (error) {
      // No es un fallo del canal: el teléfono guarda ids y una conversación se
      // puede cerrar en el Mac mientras el móvil la tenía en pantalla.
      yield Failure.of(
        FailureCode.unknownConversation,
        id: call.id,
        message: 'la conversación ${error.id} ya no está abierta',
        args: {FailureArg.conversation: error.id},
      );
    } on DemasiadasConversaciones {
      yield Failure.of(
        FailureCode.tooManyConversations,
        id: call.id,
        message: 'el Mac ya tiene todas sus conversaciones abiertas',
      );
    } on BinaryArtifact catch (error) {
      yield Failure.of(
        FailureCode.binaryArtifact,
        id: call.id,
        message: 'ese documento no es texto: ${error.id} se abre en el Mac',
        args: {FailureArg.artifact: error.id},
      );
    } on ArtifactTooLarge catch (error) {
      yield Failure.of(
        FailureCode.artifactTooLarge,
        id: call.id,
        message:
            'ese documento ocupa ${error.bytes ~/ 1024} KB y no cabe por aquí: '
            '${error.id} se abre en el Mac',
        // Los kilobytes como dato y no dentro de la frase: el teléfono los dice
        // en su idioma, y la frase de arriba solo llega al registro.
        args: {
          FailureArg.artifact: error.id,
          FailureArg.kb: error.bytes ~/ 1024,
        },
      );
    } on SinActualizacionEnElMac {
      yield Failure.of(
        FailureCode.noUpdate,
        id: call.id,
        message: 'el Mac no tiene ninguna versión nueva que aceptar ahora',
      );
    } on NoSePuedeInstalarEnElMac {
      yield Failure.of(
        FailureCode.cannotInstall,
        id: call.id,
        message:
            'esta copia de Nexus no puede reemplazarse: hay que moverla '
            'a Aplicaciones en el Mac',
      );
    } on OtraVersionEnElMac catch (error) {
      // **El sí se dio a una versión concreta.** Si entre que el teléfono la vio y
      // la aceptó el Mac encontró otra, instalar la nueva sería decir que sí por
      // alguien a algo que no ha visto.
      yield Failure.of(
        FailureCode.updateChanged,
        id: call.id,
        message: 'el Mac ofrece ahora la ${error.ofrecida}',
        args: {FailureArg.version: error.ofrecida},
      );
    } on FormatException catch (error) {
      yield Failure.of(
        FailureCode.badParams,
        id: call.id,
        message: error.message,
      );
    } on Object catch (error) {
      // Lo que no se esperaba **se contesta igual**: dejar una petición sin
      // respuesta deja al teléfono esperando para siempre, que se ve como «no
      // responde» y manda a buscar el problema al sitio equivocado.
      //
      // El texto va sin detalles: lo que sabe el Mac se queda en su registro.
      yield Failure.of(
        FailureCode.internal,
        id: call.id,
        message: 'no se pudo atender',
      );
      // Y se relanza para que quede en el registro de quien lo llamó.
      throw StateError('$error');
    }
  }

  Future<Frame> _atender(RemoteMethod metodo, Call call) async {
    switch (metodo) {
      case RemoteMethod.conversations:
        final lista = await surface.conversations();
        return Result(
          id: call.id,
          data: {
            'conversations': [for (final c in lista) c.toJson()],
          },
        );

      case RemoteMethod.history:
        final pagina = await surface.history(
          _id(call),
          cursor: _entero(call, 'cursor', 0),
          limit: _entero(call, 'limit', 50).clamp(1, maxPagina),
        );
        return Result(
          id: call.id,
          data: {
            'messages': [for (final m in pagina.items) m.toJson()],
            'nextCursor': ?pagina.nextCursor,
          },
        );

      case RemoteMethod.meter:
        return Result(
          id: call.id,
          data: (await surface.meter(_id(call))).toJson(),
        );

      case RemoteMethod.permission:
        return Result(
          id: call.id,
          data: (await surface.permission(_id(call))).toJson(),
        );

      case RemoteMethod.sendErrand:
        final texto = (call.params['text'] as String?)?.trim() ?? '';
        if (texto.isEmpty) {
          throw const FormatException('el encargo llega vacío');
        }
        await surface.sendErrand(
          _id(call),
          texto,
          // **Solo la mitad remota del permiso.** La de la carpeta se aplica más
          // abajo, donde se decide el `canEdit`; hacerla también aquí sería tener
          // el mismo AND en dos sitios, y dos sitios se separan.
          allowWrites: unlock.puedeEscribir,
        );
        // El resultado dice **que arrancó**, no que terminara: un encargo dura
        // minutos y lo que pasa dentro llega como eventos.
        return Result(id: call.id, data: {'started': true});

      case RemoteMethod.renameConversation:
        // El nombre **puede venir vacío**, y eso significa «quítaselo»: sin esa
        // salida, un nombre puesto por error se quedaría para siempre.
        await surface.renameConversation(
          _id(call),
          (call.params['name'] as String?) ?? '',
        );
        return Result(id: call.id, data: {'renamed': true});

      case RemoteMethod.startVoice:
        await surface.startVoice(_id(call));
        return Result(id: call.id, data: {'listening': true});

      case RemoteMethod.stopVoice:
        await surface.stopVoice(_id(call));
        return Result(id: call.id, data: {'listening': false});

      case RemoteMethod.playbackFinished:
        await surface.playbackFinished(_id(call));
        return Result(id: call.id, data: {'playing': false});

      case RemoteMethod.silenceReply:
        await surface.silenceReply(_id(call));
        return Result(id: call.id, data: {'silenced': true});

      case RemoteMethod.closeConversation:
        await surface.closeConversation(_id(call));
        return Result(id: call.id, data: {'closed': true});

      case RemoteMethod.stopErrand:
        await surface.stopErrand(_id(call));
        return Result(id: call.id, data: {'stopped': true});

      case RemoteMethod.archive:
        final pagina = await surface.archive(
          cursor: _entero(call, 'cursor', 0),
          limit: _entero(call, 'limit', 30).clamp(1, maxPagina),
        );
        return Result(
          id: call.id,
          data: {
            'conversations': [for (final c in pagina.items) c.toJson()],
            'nextCursor': ?pagina.nextCursor,
          },
        );

      case RemoteMethod.resumeConversation:
        final vivo = await surface.resumeConversation(_texto(call, 'archived'));
        // Se devuelve el id de la conversación **viva**, que puede no ser el del
        // archivo: si ya estaba abierta, lo correcto es llevar a esa en vez de abrir
        // una segunda sobre la misma carpeta.
        return Result(id: call.id, data: {'conversation': vivo});

      case RemoteMethod.folders:
        final carpetas = await surface.folders();
        return Result(
          id: call.id,
          data: {
            'folders': [for (final f in carpetas) f.toJson()],
          },
        );

      case RemoteMethod.openConversation:
        final id = await surface.openConversation(_texto(call, 'folder'));
        return Result(id: call.id, data: {'conversation': id});

      case RemoteMethod.artifacts:
        final lista = await surface.artifacts();
        return Result(
          id: call.id,
          data: {
            'artifacts': [for (final a in lista) a.toJson()],
          },
        );

      case RemoteMethod.artifact:
        return Result(
          id: call.id,
          data: {'content': await surface.artifact(_texto(call, 'artifact'))},
        );

      case RemoteMethod.unlockWrites:
        return _abrirEscritura(call);

      // 🔴 **Actualizar el Mac no pide la frase de escritura**, y la decisión merece
      // quedar escrita porque parece que debería.
      //
      // La frase existe para una cosa: que quien se lleve el teléfono no pueda
      // **escribir en los archivos del usuario** (`acceptEdits`, 2.4). Esto no los
      // toca. Y tampoco es lo que la regla de La Oficina teme de un canal que
      // «instala cosas»: el teléfono no elige qué se instala —ni versión ni
      // dirección; no hay parámetro que llegue a Sparkle—, solo contesta al aviso
      // que el Mac ya tiene, con una versión del feed de Nexus que Sparkle comprobó
      // con su firma. Es elegir entre lo que el Mac ofrece, como abrir una
      // conversación sobre una carpeta ya emparejada.
      //
      // Lo que sí hace es **interrumpir el Mac**, y eso se cubre con la regla del
      // propio aviso y no con un secreto: reiniciar espera a que termine lo que
      // esté hablando o trabajando. Lo peor que puede hacer quien tenga el token es
      // adelantar una actualización oficial que el Mac iba a ofrecer igual — y el
      // registro de la 2.5 dice quién la pidió.
      case RemoteMethod.installUpdate:
        final actualizador = this.actualizador;
        if (actualizador == null) throw const SinActualizacionEnElMac();
        final version = call.params['version'];
        final tras = await actualizador.actualizarYReiniciar(
          version: version is String && version.isNotEmpty ? version : null,
        );
        // El resultado dice **qué va a pasar**, no que ya pasó: «reinicia» es que el
        // Mac se va ahora, y el teléfono tiene que saberlo antes de perderlo.
        return Result(id: call.id, data: {'outcome': tras.cable});

      case RemoteMethod.postponeUpdate:
        // Sin actualizador no hay nada que apartar, y decir que se apartó es cierto:
        // «luego» sobre nada deja lo mismo.
        await actualizador?.dejarParaLuego();
        return Result(id: call.id, data: {'postponed': true});
    }
  }

  /// Abrir la escritura con la frase.
  ///
  /// Lo atiende el canal y no la app: la frase es un secreto del canal, y la app no
  /// tiene por qué verla pasar.
  Future<Frame> _abrirEscritura(Call call) async {
    final recibida = call.params['phrase'] as String?;
    if (recibida == null || recibida.isEmpty) {
      throw const FormatException('falta la frase');
    }

    final negado = unlock.intentar(
      guardada: await phrases.read(),
      recibida: recibida,
    );

    if (negado != null) {
      return Failure.of(
        switch (negado) {
          WriteDenial.sinFrase => FailureCode.noPhrase,
          WriteDenial.frase => FailureCode.wrongPhrase,
          WriteDenial.demasiadosIntentos => FailureCode.tooManyAttempts,
        },
        id: call.id,
        // **Sin decir cuál falló más allá del código, y sin repetir la frase.**
        // El código lo necesita el teléfono para saber qué enseñar; el valor no lo
        // necesita nadie, y este marco podría acabar en un registro.
        message: switch (negado) {
          WriteDenial.sinFrase =>
            'no hay frase de escritura definida en el Mac',
          WriteDenial.frase => 'la frase no es',
          WriteDenial.demasiadosIntentos => 'demasiados intentos',
        },
      );
    }

    return Result(
      id: call.id,
      data: {'until': unlock.grant!.until.toIso8601String()},
    );
  }

  /// Un parámetro de texto obligatorio.
  ///
  /// Uno solo para todos en vez de una comprobación por método: la que se escribe a
  /// mano en cada sitio es la que un día se olvida, y olvidarla aquí significa pasarle
  /// un `null` a la app.
  String _texto(Call call, String clave) {
    final valor = call.params[clave] as String?;
    if (valor == null || valor.isEmpty) {
      throw FormatException('falta «$clave»');
    }
    return valor;
  }

  String _id(Call call) {
    final id = call.params['conversation'] as String?;
    if (id == null || id.isEmpty) {
      throw const FormatException('falta «conversation»');
    }
    return id;
  }

  int _entero(Call call, String clave, int porDefecto) {
    final crudo = call.params[clave];
    if (crudo == null) return porDefecto;
    if (crudo is int) return crudo;
    // Un número que llega como texto es un cliente mal escrito, no un ataque: se
    // acepta si se entiende. Lo que no se hace es adivinar y seguir con basura.
    final leido = int.tryParse('$crudo');
    if (leido == null) throw FormatException('«$clave» no es un número');
    return leido;
  }
}
