import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/memoria/domain/entities/las_preguntas_de_quien_eres.dart';
import 'package:nexus/features/memoria/domain/entities/lo_que_se_sabe_de_ti.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lo que Nexus sabe de ti, guardado y a mano.
///
/// En preferencias y no en un archivo propio: son veinte líneas de texto con su
/// fecha, y montarles un almacén aparte sería más código que datos. Ver
/// [LoQueSeSabeDeTi] para el tope y el porqué.
class LoQueRecuerdaDeTi extends Notifier<List<UnaCosaQueSeSabe>> {
  static const llave = 'lo_que_se_sabe_de_ti';

  final _leida = Completer<void>();

  /// Cuando ya se leyó del disco. Quien escribe encima de la lista tiene que
  /// esperarla: escribir antes y que la lectura llegue después borraría lo
  /// recién escrito con lo que había.
  Future<void> get leida => _leida.future;

  @override
  List<UnaCosaQueSeSabe> build() {
    unawaited(_leer());
    return const [];
  }

  Future<void> _leer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getStringList(llave) ?? const [];
      final leidas = [
        for (final linea in crudo)
          if (jsonDecode(linea) case final Map<String, dynamic> json)
            ?UnaCosaQueSeSabe.fromJson(json),
      ];
      if (!ref.mounted) return;
      state = leidas;
    } on Object catch (error) {
      // Una memoria que no se puede leer es una memoria vacía, no una app rota.
      debugPrint('memoria · no se pudo leer: $error');
    } finally {
      if (!_leida.isCompleted) _leida.complete();
    }
  }

  Future<void> _guardar(List<UnaCosaQueSeSabe> cosas) async {
    state = cosas;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(llave, [
        for (final cosa in cosas) jsonEncode(cosa.toJson()),
      ]);
    } on Object catch (error) {
      debugPrint('memoria · no se pudo guardar: $error');
    }
  }

  /// Apunta algo. Devuelve `false` si no había nada que apuntar.
  Future<bool> recuerda(String texto, DateTime cuando) async {
    final limpio = texto.trim();
    if (limpio.isEmpty) return false;
    await _guardar(
      LoQueSeSabeDeTi.con(
        state,
        UnaCosaQueSeSabe(texto: limpio, cuando: cuando),
      ),
    );
    return true;
  }

  /// Las respuestas del arranque guiado. Ver [LasPreguntasDeQuienEres.con].
  Future<void> contesta(
    List<({String tema, Set<String> temas, String respuesta})> respuestas,
    DateTime cuando,
  ) async {
    await leida;
    if (!ref.mounted) return;
    await _guardar(
      LasPreguntasDeQuienEres.con(state, respuestas, cuando: cuando),
    );
  }

  /// Quita la que ocupa ese sitio en la lista que se está enseñando.
  Future<void> olvida(int cual) => _guardar(LoQueSeSabeDeTi.sin(state, cual));
}

final loQueRecuerdaDeTiProvider =
    NotifierProvider<LoQueRecuerdaDeTi, List<UnaCosaQueSeSabe>>(
      LoQueRecuerdaDeTi.new,
    );

/// Los temas de cada pregunta **en todos los idiomas**: con ellos se reconoce
/// la respuesta de antes aunque se diera en el otro.
List<Set<String>> losTemasDeQuienEres() => [
  for (var i = 0; i < PreguntaDeQuienEres.values.length; i++)
    {
      for (final idioma in NexusStrings.supported)
        NexusStrings.of(idioma).quienEresPreguntas[i].tema,
    },
];
