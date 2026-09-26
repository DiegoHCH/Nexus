import 'package:flutter/foundation.dart';

/// Lo que hace falta saber de una conversación **sin abrirla**: quién la tuvo,
/// cuándo, sobre qué carpeta y cuántos turnos.
///
/// Existe porque listar y leer no cuestan lo mismo. Antes toda la app hablaba
/// de [ConversationRecord], que lleva los mensajes dentro, así que enseñar una
/// lista de treinta conversaciones obligaba a leer y parsear las treinta
/// enteras — y eso pasa **en cada turno**, porque al archivar se refresca la
/// lista. Con esto, la lista cuesta la cabecera de cada nota y el detalle se
/// paga solo al abrir una.
///
/// [ConversationRecord] sigue siendo la conversación de verdad. Esto es su
/// ficha.
@immutable
class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.folderPath,
    required this.startedAt,
    required this.title,
    required this.turns,
    DateTime? usadaEn,
    this.profileName,
    this.sourcePath,
    this.model,
    this.contextTokens,
    this.loUltimoQuePediste,
    this.loUltimoQueDijo,
    this.documentos = const [],
  }) : usadaEn = usadaEn ?? startedAt;

  final String id;
  final String folderPath;
  final DateTime startedAt;

  /// **Cuándo se usó por última vez**, que es lo que la lista tiene que decir.
  ///
  /// 🔴 **La lista enseñaba y ordenaba por [startedAt], y eso la hacía mentir.**
  /// Reportado tal cual: «las últimas conversaciones que he hecho en
  /// front-mobile-b2c no se están guardando». Estaban todas guardadas —se
  /// comprobó archivo por archivo—: lo que pasaba es que la que tenía el trabajo
  /// de hoy **había empezado ayer**, así que aparecía con la fecha de ayer y
  /// varias posiciones más abajo, debajo de conversaciones más nuevas y más
  /// cortas. Una conversación que se retoma tres días seguidos se hunde en la
  /// lista justo por usarse mucho.
  ///
  /// Nace igual a [startedAt] para las fichas viejas, que no lo guardaban: es lo
  /// único honesto que se puede decir de ellas.
  final DateTime usadaEn;

  /// La misma ficha, sellada como usada [cuando]. Es lo que hace el almacén al
  /// guardar: guardar una conversación **es** usarla.
  ConversationSummary usadaAhora(DateTime cuando) => ConversationSummary(
    id: id,
    folderPath: folderPath,
    startedAt: startedAt,
    title: title,
    turns: turns,
    usadaEn: cuando,
    profileName: profileName,
    sourcePath: sourcePath,
    model: model,
    contextTokens: contextTokens,
    loUltimoQuePediste: loUltimoQuePediste,
    loUltimoQueDijo: loUltimoQueDijo,
    documentos: documentos,
  );

  /// Ya resuelto, no deducido al vuelo. Quien escribe la ficha tiene los
  /// mensajes delante; quien la lee, no.
  final String title;

  /// Cuántos mensajes tiene. Es lo que enseña la lista para distinguir «esto
  /// fue una pregunta» de «esto fue una tarde entera».
  final int turns;

  /// Con qué cuenta de Claude se trabajó — `work`, `private`— o `null` con la
  /// de siempre.
  final String? profileName;

  /// El archivo del que se leyó, cuando vino de una carpeta o un vault. Es lo
  /// que distingue una ficha que se completa leyendo una nota del disco de una
  /// que se completa con el almacén de la app.
  final String? sourcePath;

  final String? model;
  final int? contextTokens;

  /// Lo último que se le pidió y lo último que contestó, **recortado**.
  ///
  /// Van en la ficha y no se leen al abrir porque el historial busca también
  /// por lo que se habló, no solo por el título: «la de las pantallas de
  /// CRED-310» casi nunca es el título, es lo que se dijo dentro. Buscar abriendo
  /// cada conversación sería devolver el coste que el índice vino a quitar; con
  /// esto buscar cuesta lo que ya costaba listar, y la vista previa sale sin
  /// tocar el disco.
  ///
  /// `null` en las fichas de antes —y en las del vault, que no lo escriben—: ahí
  /// la vista previa lee la conversación entera, que es lo único honesto.
  final String? loUltimoQuePediste;
  final String? loUltimoQueDijo;

  /// Las rutas de los documentos que salieron de esta conversación, en el orden
  /// en que salieron.
  ///
  /// Es **el origen de cada documento**: la lista de documentos agrupa por aquí.
  /// El dato ya se guardaba —cada turno lleva su `documento`—, pero dentro del
  /// JSON de la conversación; aquí se sube a la ficha para que agrupar la
  /// carpeta entera no obligue a abrir todas las conversaciones.
  final List<String> documentos;

  /// El nombre de la carpeta, que es como se llama el proyecto en todos lados.
  String get projectName => projectNameOf(folderPath);

  /// Compartido con [ConversationRecord]: las dos cosas nombran el proyecto por
  /// la última carpeta de la ruta, y tenerlo escrito dos veces era pedir que un
  /// día dejaran de coincidir.
  static String projectNameOf(String folderPath) {
    final parts = folderPath.split('/').where((part) => part.isNotEmpty);
    return parts.isEmpty ? 'sin-proyecto' : parts.last;
  }
}
