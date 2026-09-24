import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/platform/presencia_channel.dart';
import 'package:nexus/core/platform/notifications_channel.dart';
import 'package:nexus/features/avisos/domain/usecases/lo_que_merece_decirse.dart';
import 'package:nexus/features/avisos/presentation/providers/la_voz_que_avisa.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **Nexus hablando primero.**
///
/// Lo que ya pasaba —un encargo que termina, uno que falla— se contaba con una
/// notificación muda del sistema. Esto es lo mismo, pero **dicho**, cuando
/// merece la pena: te fuiste a otra cosa y lo que pediste ya está.
///
/// Todo el criterio vive en [LoQueMereceDecirse], aparte y probado, porque lo
/// difícil de una voz que habla sola no es hablar: es callarse bien. Aquí solo
/// queda lo que esa decisión necesita saber y que no se puede calcular sin
/// mirar el mundo — si la estás mirando, si hay voz abierta, qué se dijo hace
/// un momento.
///
/// **El aviso escrito no se pierde nunca.** Se diga o no se diga, la
/// notificación del sistema sale igual: hablar es un extra, no un sustituto —
/// si estabas en otra sala, la frase se la lleva el aire.
class ElQueHablaPrimero {
  ElQueHablaPrimero(this._ref);

  final Ref _ref;

  /// El interruptor, guardado como el de los PR.
  ///
  /// **Nace encendido**: es lo que se pidió, y solo habla cuando no estás
  /// mirando la pantalla — así que la primera vez que suene será porque te
  /// fuiste a otra cosa, que es justo el caso para el que existe.
  static const encendido = 'avisos_en_voz_alta';

  /// Si la están mirando. Inyectable para poder probar los dos lados sin una
  /// ventana de verdad delante.
  @visibleForTesting
  static Future<bool> Function() miraSiLaMiran =
      PresenciaChannel.laEstanMirando;

  Future<bool> _laEstanMirando() => miraSiLaMiran();

  /// Lo último que se dijo y cuándo, para no repetirse ni ametrallar.
  String? _loUltimo;
  DateTime? _cuando;

  /// Cuenta algo que acaba de pasar. [llave] es lo que distingue un aviso de
  /// otro: dos iguales seguidos no se dicen dos veces.
  Future<void> avisa({
    required String titulo,
    required String frase,
    required String llave,
    required String escrito,
  }) async {
    final ahora = DateTime.now();
    // 🔴 **Las dos esperas, antes de tocar nada.** Esto leía la presencia
    // **dentro** de la lista de argumentos de la regla, y ahí hay un hueco: en
    // lo que el sistema contesta, la conversación puede cerrarse y entonces lo
    // de la línea siguiente —preguntarle a la voz— usa un proveedor muerto.
    // Lo pescaron las pruebas de los permisos, que cierran la conversación con
    // el aviso en vuelo, que es exactamente lo que pasa al pulsar la X.
    final prefs = await SharedPreferences.getInstance();
    if (!_ref.mounted) return;
    final mirando = await _laEstanMirando();
    if (!_ref.mounted) return;

    final voz = _ref.read(laVozQueAvisaProvider);
    final seDice = LoQueMereceDecirse.seDice(
      encendido: prefs.getBool(encendido) ?? true,
      mirando: mirando,
      hablando: voz.hablando || voz.hayVozAbierta(),
      que: llave,
      loUltimo: _loUltimo,
      desdeLoUltimo: _cuando == null ? null : ahora.difference(_cuando!),
    );

    if (!seDice) {
      await NotificationsChannel.notify(title: titulo, body: escrito);
      return;
    }

    // Se apunta **antes** de hablar y no después: decirlo tarda segundos, y en
    // ese rato puede terminar el encargo de al lado. Apuntándolo al final, los
    // dos pasarían el filtro y hablarían encima.
    _loUltimo = llave;
    _cuando = ahora;
    await voz.decir(titulo: titulo, frase: frase);
  }
}

final elQueHablaPrimeroProvider = Provider<ElQueHablaPrimero>(
  ElQueHablaPrimero.new,
);

/// Si está encendido que hable solo, para pintarlo en Ajustes.
final losAvisosEnVozAltaProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(ElQueHablaPrimero.encendido) ?? true;
});
