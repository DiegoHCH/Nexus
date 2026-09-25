import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/accent_preference.dart';
import 'package:nexus/core/i18n/language_preference.dart';
import 'package:nexus/core/platform/escucha_channel.dart';
import 'package:nexus/core/platform/orbe_channel.dart';
import 'package:nexus/features/assistant/presentation/state/assistant_hud_state.dart';
import 'package:nexus/features/assistant/presentation/state/orb_state.dart';
import 'package:nexus/features/assistant/presentation/providers/assistant_controller.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/avisos/presentation/providers/la_voz_que_avisa.dart';
import 'package:nexus/features/oido/domain/usecases/como_se_le_llama.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **Estar, en vez de que te abran.**
///
/// Decir su nombre y que se abra la conversación de voz, sin tocar el orbe. Es
/// la última pata de lo que separa una app que se abre de alguien que está en
/// la casa.
///
/// ## Nace apagado, y eso no es timidez
///
/// Mientras escucha, el indicador naranja del micrófono de macOS está
/// encendido. Eso es el sistema contando la verdad —hay una app con la entrada
/// abierta— y encender eso por defecto sería tomar por alguien una decisión que
/// es suya. Se enciende en Ajustes › Voz, con lo que cuesta dicho al lado.
///
/// ## Se calla cuando hay conversación
///
/// Con la voz abierta, el motor de audio de verdad necesita la entrada entera
/// para cancelar el eco, y dos capturas peleándose por el micrófono no es un
/// problema que merezca la pena resolver: **quien ya está hablando no necesita
/// que lo llamen**. Así que esto se apaga al abrirse una sesión y vuelve al
/// cerrarse.
///
/// ## Y solo abre lo que ya está abierto
///
/// Llamarla lleva la voz a la conversación en foco. Sin ninguna abierta no
/// hace nada: abrir una carpeta al azar porque alguien dijo un nombre es
/// exactamente la clase de iniciativa que no se quiere.
class ElOidoQueEspera {
  ElOidoQueEspera(this._ref) {
    EscuchaChannel.cuandoTeLlamen(
      _teLlamaron,
      alOirTuNombre: _teOyo,
      siSeCalla: _seCallo,
    );
    _ref.onDispose(() {
      EscuchaChannel.cuandoTeLlamen(null);
      unawaited(EscuchaChannel.parar());
      _mirando?.close();
      unawaited(OrbeChannel.ocultar());
    });
  }

  final Ref _ref;

  static const encendido = 'oido_encendido';

  var _puesto = false;

  /// Enciende o apaga según el ajuste y según si hay voz abierta.
  Future<void> cuadrar() async {
    final debe = await _debeEscuchar();
    if (!_ref.mounted) return;
    // 🔴 **Decir por qué no escucha, que era el agujero.** Cuando decidía que
    // no, salía por aquí en silencio: el registro no distinguía «apagado» de
    // «encendido y no pudo», y con el micrófono de por medio esa es justo la
    // pregunta que hay que poder contestar sin adivinar.
    if (debe == _puesto) {
      if (!debe) debugPrint('escucha · no toca escuchar ahora');
      return;
    }
    if (!debe) {
      _puesto = false;
      await EscuchaChannel.parar();
      return;
    }
    // 🔴 **Esperar a los nombres antes de decidir cuál se escucha.** Nacen
    // vacíos y el disco se lee después —ver `LosNombresController.leidos`—, y
    // esto se cuadra en el arranque: sin esperar, la palabra salía «nexus»
    // aunque la hubieras llamado Hestia, y se quedaba así toda la sesión.
    await _ref.read(losNombresProvider.notifier).leidos;
    if (!_ref.mounted) return;
    _puesto = await EscuchaChannel.empezar(_lasPalabras());
    debugPrint('escucha · ${_puesto ? 'puesta' : 'no se pudo poner'}');
  }

  /// Le cambiaste el nombre: si estaba escuchando, vuelve a empezar con el
  /// nuevo. Sin esto seguiría abriendo con el de antes hasta reiniciar la app.
  Future<void> renombrar() async {
    if (!_puesto) return;
    _puesto = false;
    await EscuchaChannel.parar();
    await cuadrar();
  }

  Future<bool> _debeEscuchar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(encendido) != true) return false;
    } on Object {
      return false;
    }
    if (!_ref.mounted) return false;
    return !_hayVozAbierta();
  }

  bool _hayVozAbierta() => _ref
      .read(conversationsProvider)
      .items
      .any((c) => _ref.read(assistantControllerProvider(c.id)).voiceActive);

  /// Cómo hay que llamarla. Ver [ComoSeLeLlama].
  List<String> _lasPalabras() =>
      ComoSeLeLlama.lasPalabras(_ref.read(losNombresProvider).agente);

  /// La escucha se renovó sola y no pudo volver: el micrófono lo tomó otra
  /// app, o se desenchufó.
  ///
  /// Se intenta **una vez** al rato, no en bucle: si sigue sin poder, `empezar`
  /// devuelve que no y ahí se queda, igual que al arrancar. Lo que no se hace
  /// es seguir creyendo que escucha.
  void _seCallo() {
    _puesto = false;
    debugPrint('escucha · se calló sola; se prueba otra vez en un rato');
    unawaited(
      Future<void>.delayed(_reintento, () async {
        if (_ref.mounted) await cuadrar();
      }),
    );
  }

  /// Cuánto se espera antes de volver a probar tras callarse sola.
  static const _reintento = Duration(seconds: 5);

  /// Oyó el nombre y todavía te está escuchando el resto: el orbe sale ya.
  /// Montar la voz tarda un segundo largo, y en ese rato lo único que sabe que
  /// la llamaste eres tú.
  void _teOyo() {
    if (_ref.read(conversationsProvider).focused == null) return;
    unawaited(OrbeChannel.mostrar(NexusOrbState.listen.name, _elAcento()));
  }

  /// [resto] es lo que dijiste después del nombre. Si dijiste algo, es tu
  /// primer turno y **no saluda**: «Hestia, ¿qué reuniones tengo?» se
  /// contesta, no se recibe con un «¿Sí?» que te obligaría a repetirlo.
  void _teLlamaron(String resto) {
    _puesto = false;
    final cual = _ref.read(conversationsProvider).focused?.id;
    if (cual == null) {
      // 🔴 **Antes no pasaba nada**: un `debugPrint` y a seguir esperando. La
      // llamabas desde el otro lado de la habitación y el silencio no decía si
      // no te oyó o si no podía. Ahora contesta qué falta, en voz alta, y si
      // no puede hablar lo deja como aviso.
      debugPrint('escucha · te llamaron y no hay conversación abierta');
      unawaited(_decirQueNoHayConversacion());
      return;
    }
    // El orbe sale **antes** de abrir la sesión, no después: montar la voz
    // tarda un segundo largo —el motor de audio, el socket— y en ese rato lo
    // único que sabe que la llamaste eres tú. Un asistente que tarda en
    // contestar y mientras tanto no da señales es indistinguible de uno que no
    // te oyó.
    unawaited(OrbeChannel.mostrar(NexusOrbState.listen.name, _elAcento()));
    _seguirLaConversacion(cual);
    unawaited(
      _ref
          .read(assistantControllerProvider(cual).notifier)
          .toggleVoice(
            saludo: resto.isEmpty ? _elSaludo() : null,
            primeraFrase: resto.isEmpty ? null : resto,
          ),
    );
  }

  Future<void> _decirQueNoHayConversacion() async {
    final strings = _ref.read(stringsProvider);
    await _ref
        .read(laVozQueAvisaProvider)
        .decir(
          titulo: _ref.read(losNombresProvider).agente ?? 'Nexus',
          frase: strings.alLlamarlaSinConversacion(
            _ref.read(losNombresProvider).tuyo,
          ),
        );
    if (_ref.mounted) await cuadrar();
  }

  /// Lo que contesta a la llamada: «¿Sí, Argonauta?».
  ///
  /// 🔴 **Porque abría la voz callada.** Con el atajo o el orbe está bien —lo
  /// acabas de pulsar y sabes que te oye—, pero llamándola desde el otro lado
  /// de la habitación el silencio no dice si te oyó, ni **cuándo** empezar: lo
  /// que dijeras mientras la voz se montaba —medido, de 0,6 a 3,6 s— se
  /// perdía. El saludo contesta a las dos cosas: te oyó, y ya puedes hablar.
  String _elSaludo() =>
      _ref.read(stringsProvider).alLlamarla(_ref.read(losNombresProvider).tuyo);

  /// El acento elegido, que viaja con cada aviso: el orbe de fuera corre en
  /// otro motor y no puede leer los ajustes por su cuenta.
  int _elAcento() => _ref.read(accentControllerProvider).chosen.toARGB32();

  ProviderSubscription<AssistantHudState>? _mirando;

  /// Mientras dure la sesión, el orbe de fuera dice lo mismo que el de dentro.
  ///
  /// Se suelta en cuanto la voz se cierra, y entonces el orbe se recoge: lo que
  /// se pidió es que **no se vea si no está haciendo nada**.
  void _seguirLaConversacion(String cual) {
    var llegoAAbrirse = false;
    _mirando?.close();
    _mirando = _ref.listen(assistantControllerProvider(cual), (antes, ahora) {
      if (ahora.voiceActive) {
        llegoAAbrirse = true;
        unawaited(OrbeChannel.estado(ahora.orbState.name, _elAcento()));
        return;
      }
      // El primer estado que llega puede ser el de antes de abrirse: sin esto,
      // el orbe saldría y se recogería en el mismo parpadeo.
      if (!llegoAAbrirse) return;
      _mirando?.close();
      _mirando = null;
      unawaited(OrbeChannel.ocultar());
      unawaited(cuadrar());
    });
  }
}

/// El oído, armado. Se lee una vez al arrancar —como el vigía de los PR— y se
/// cuadra solo cada vez que cambia lo que le importa: el ajuste no, que ese lo
/// avisa quien lo toca; pero sí abrirse o cerrarse una conversación de voz.
final elOidoQueEsperaProvider = Provider<ElOidoQueEspera>((ref) {
  final oido = ElOidoQueEspera(ref);
  unawaited(oido.cuadrar());
  ref.listen(conversationsProvider, (_, _) => unawaited(oido.cuadrar()));
  ref.listen(losNombresProvider.select((nombres) => nombres.agente), (
    antes,
    ahora,
  ) {
    if (antes != ahora) unawaited(oido.renombrar());
  });
  return oido;
});

/// Si está encendido, para pintarlo en Ajustes.
final elOidoEstaEncendidoProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(ElOidoQueEspera.encendido) ?? false;
});
