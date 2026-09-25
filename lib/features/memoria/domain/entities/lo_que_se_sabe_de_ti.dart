import 'package:flutter/foundation.dart';

/// Una cosa que Nexus sabe de ti.
@immutable
class UnaCosaQueSeSabe {
  const UnaCosaQueSeSabe({required this.texto, required this.cuando});

  final String texto;

  /// Cuándo se apuntó. Sirve para enseñarlas en orden y para que tú puedas
  /// decidir si algo que se apuntó hace dos meses sigue siendo verdad.
  final DateTime cuando;

  Map<String, dynamic> toJson() => {
    'texto': texto,
    'cuando': cuando.toIso8601String(),
  };

  static UnaCosaQueSeSabe? fromJson(Map<String, dynamic> json) {
    final texto = (json['texto'] as String?)?.trim();
    if (texto == null || texto.isEmpty) return null;
    final cuando = DateTime.tryParse(json['cuando'] as String? ?? '');
    return UnaCosaQueSeSabe(texto: texto, cuando: cuando ?? DateTime(2026));
  }
}

/// **Lo que Nexus sabe de ti, y no de la carpeta.**
///
/// 🔴 **La memoria de hoy es del repositorio, no tuya.** La sesión de Claude
/// vive en la carpeta: dos conversaciones sobre el mismo repo comparten
/// contexto y dos sobre repos distintos no se enteran la una de la otra. Eso es
/// correcto para el trabajo y es justo lo que falla para todo lo demás — en qué
/// andas esta semana, cómo te gusta que se hagan las cosas, qué te molesta. Lo
/// cuentas en una carpeta y en la de al lado no existe.
///
/// Esto es lo contrario: **viaja con todos los encargos**, de cualquier
/// carpeta, y también a la voz. Es lo que convierte a alguien que contesta bien
/// en alguien que te conoce.
///
/// ## Lo escribes tú
///
/// No se deduce de lo que hablas. Que un asistente decida solo qué recordar de
/// ti suena bien hasta que apunta algo equivocado y no hay forma de saber de
/// dónde salió: a partir de ahí arrastra un error que tú no pusiste, en cada
/// encargo, sin decírtelo. Aquí se apunta lo que le dices que apunte —con
/// `/recuerda`— y se ve entero en Ajustes.
///
/// ## Con tope, y esto no es prudencia
///
/// Esto entra en el prompt de **cada** encargo, así que lo que crezca aquí se
/// paga en cada turno de por vida. Veinte notas y dos mil caracteres: pasado
/// eso se quedan las más recientes, porque una memoria que crece sin freno
/// acaba costando más de lo que vale.
abstract final class LoQueSeSabeDeTi {
  /// Cuántas se guardan. Más allá, entra la nueva y sale la más vieja.
  static const cuantas = 20;

  /// Y cuánto ocupa el bloque que viaja. Ver arriba: se paga por turno.
  static const maxCaracteres = 2000;

  /// La lista con la nueva delante, sin repetidas y sin pasarse del tope.
  static List<UnaCosaQueSeSabe> con(
    List<UnaCosaQueSeSabe> ya,
    UnaCosaQueSeSabe nueva,
  ) {
    final texto = nueva.texto.trim();
    if (texto.isEmpty) return ya;
    return [
      UnaCosaQueSeSabe(texto: texto, cuando: nueva.cuando),
      // La misma cosa dicha dos veces no ocupa dos sitios: se queda la nueva,
      // que es la que trae la fecha buena.
      for (final vieja in ya)
        if (vieja.texto.toLowerCase().trim() != texto.toLowerCase()) vieja,
    ].take(cuantas).toList();
  }

  /// Sin la que se señale. Fuera de rango no hace nada: la lista se enseña en
  /// una pantalla y en un chat, y un índice viejo no puede borrar otra cosa.
  static List<UnaCosaQueSeSabe> sin(List<UnaCosaQueSeSabe> ya, int cual) {
    if (cual < 0 || cual >= ya.length) return ya;
    return [
      for (var i = 0; i < ya.length; i++)
        if (i != cual) ya[i],
    ];
  }

  /// El bloque que viaja en el prompt, o `null` si no hay nada que contar.
  ///
  /// Va en segunda persona y **dicho como lo que es**: cosas que la persona
  /// pidió recordar, no órdenes. La diferencia importa — una nota que diga «usa
  /// siempre tabuladores» es una preferencia suya y debe pesar; una que diga
  /// «estoy con la migración de pagos» es contexto y no debe convertirse en una
  /// tarea que nadie pidió.
  static String? paraElPrompt(List<UnaCosaQueSeSabe> cosas) {
    if (cosas.isEmpty) return null;
    final lineas = <String>[];
    var largo = 0;
    for (final cosa in cosas) {
      final linea = '- ${cosa.texto}';
      if (largo + linea.length > maxCaracteres) break;
      largo += linea.length + 1;
      lineas.add(linea);
    }
    if (lineas.isEmpty) return null;
    return [
      'Lo que esta persona te ha pedido que recuerdes de ella. Es contexto '
          'suyo, no una lista de tareas: úsalo cuando venga a cuento y no lo '
          'recites.',
      ...lineas,
    ].join('\n');
  }
}
