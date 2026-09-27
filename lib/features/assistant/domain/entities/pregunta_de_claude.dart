import 'package:nexus/features/assistant/domain/entities/peticion_de_permiso.dart';

/// **Cuando Claude duda, pregunta con opciones**, y se contesta en el chat.
///
/// Es la herramienta `AskUserQuestion` del CLI: en vez de escribir «¿prefieres
/// A o B?» y esperar a que se teclee, trae la pregunta con sus opciones —la
/// recomendada primero— y una respuesta libre. Pedido el 27 sep: «no solo me
/// responde para que escriba, sino que me da opciones y me recomienda».
///
/// 🔴 **Llega por el canal de los permisos**, no como mensaje: el CLI pide
/// permiso para usar la herramienta y **la respuesta viaja dentro del
/// permiso**, como `updatedInput.answers` —pregunta → lo elegido—. Medido
/// contra el binario (Claude Code 2.1.283): con eso devuelve «Your questions
/// have been answered: "¿Qué color prefieres?"="Azul"» y sigue con ello.
abstract final class LaPreguntaDeClaude {
  static const herramienta = 'AskUserQuestion';

  static bool es(PeticionDePermiso peticion) =>
      peticion.herramienta == herramienta;

  /// Las preguntas que trae, en orden. Lo que no se entienda se salta: una
  /// pregunta sin texto o sin opciones no se puede contestar.
  static List<UnaPregunta> de(PeticionDePermiso peticion) {
    final crudas = peticion.entrada['questions'];
    if (crudas is! List) return const [];
    return [
      for (final cruda in crudas)
        if (cruda is Map<String, dynamic>) ?UnaPregunta.deJson(cruda),
    ];
  }

  /// El permiso concedido con las respuestas dentro. [respuestas] va de la
  /// pregunta a lo elegido; con varias opciones, separadas por comas.
  static RespuestaDePermiso contestada(
    PeticionDePermiso peticion,
    Map<String, String> respuestas,
  ) => PermisoConcedido({...peticion.entrada, 'answers': respuestas});

  /// Las preguntas en una línea cada una, para el texto del mensaje: es lo
  /// que se lee en el historial y lo que oiría la voz.
  static String comoTexto(List<UnaPregunta> preguntas) =>
      preguntas.map((p) => p.pregunta).join('\n');
}

class UnaPregunta {
  const UnaPregunta({
    required this.pregunta,
    required this.opciones,
    this.rotulo,
    this.variasALaVez = false,
  });

  final String pregunta;

  /// La etiqueta corta —«Identidad», «Trato»—, si la trae.
  final String? rotulo;
  final List<UnaOpcion> opciones;

  /// Si se puede elegir más de una.
  final bool variasALaVez;

  static UnaPregunta? deJson(Map<String, dynamic> json) {
    final pregunta = json['question'];
    final crudas = json['options'];
    if (pregunta is! String || pregunta.trim().isEmpty || crudas is! List) {
      return null;
    }
    final opciones = [
      for (final cruda in crudas)
        if (cruda is Map<String, dynamic> && cruda['label'] is String)
          UnaOpcion(
            etiqueta: cruda['label'] as String,
            descripcion: cruda['description'] as String?,
          ),
    ];
    if (opciones.isEmpty) return null;
    final rotulo = json['header'];
    return UnaPregunta(
      pregunta: pregunta.trim(),
      rotulo: rotulo is String && rotulo.trim().isNotEmpty
          ? rotulo.trim()
          : null,
      opciones: opciones,
      variasALaVez: json['multiSelect'] == true,
    );
  }
}

class UnaOpcion {
  const UnaOpcion({required this.etiqueta, this.descripcion});

  /// Tal como la escribió Claude, marca de recomendada incluida: es lo que se
  /// le devuelve, y cambiarla le haría buscar una opción que no ofreció.
  final String etiqueta;
  final String? descripcion;

  static final _laMarca = RegExp(
    r'\s*\((recomendad[oa]|recommended)\)\s*',
    caseSensitive: false,
  );

  /// Si Claude la recomienda. Lo dice en la etiqueta —«Opción A
  /// (Recomendado)»—, que es la convención de la herramienta.
  bool get recomendada => _laMarca.hasMatch(etiqueta);

  /// La etiqueta sin la marca, para pintarla: la recomendación se enseña
  /// aparte, no como texto entre paréntesis.
  String get sinLaMarca => etiqueta.replaceAll(_laMarca, ' ').trim();
}
