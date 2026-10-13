import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nexus/features/agenda/domain/entities/reunion.dart';
import 'package:nexus/features/assistant/data/datasources/claude_cli_data_source.dart';
import 'package:nexus/features/assistant/domain/usecases/mcp_permissions.dart';

/// Le pregunta el calendario a Claude, con el conector de Calendar.
///
/// **No hay API propia y no hace falta**: el conector ya funciona desde Nexus y
/// está medido — el mismo `claude -p` con
/// `--allowedTools mcp__claude_ai_Google_Calendar` contesta las reuniones. Lo
/// que hace esto es pedirle la respuesta en JSON en vez de en prosa, porque
/// aquí no la lee una persona.
///
/// 🔴 **Se pregunta con Haiku, no con el modelo de la cuenta.** Se relee cada
/// cuarto de hora —ver `LaJornada.cadaCuanto`— y con Opus cada lectura costaba
/// ~$0,21; con Haiku, ~$0,008, y contesta lo mismo: es sacar una lista de un
/// conector y escribirla en JSON, no hay nada que razonar. Medido el 10 oct
/// 2026 sobre un día real con dos reuniones: las dos lecturas devolvieron las
/// mismas.
class AgendaDataSource {
  const AgendaDataSource({this.cli = const ClaudeCliDataSource()});

  final ClaudeCliDataSource cli;

  static const conector = 'mcp__claude_ai_Google_Calendar';

  /// El modelo con el que se lee. Ver la cabecera de la clase.
  static const modelo = 'haiku';

  /// Las herramientas del conector que **escriben**, para negarlas.
  ///
  /// 🔴 Se pasan de verdad porque antes solo estaban prometidas en un
  /// comentario: `--allowedTools` autoriza el servidor **entero**, así que sin
  /// esto mover o borrar un evento sí entraba por aquí. Salen de la lista del
  /// canal en vez de repetirse a mano: una segunda copia se queda vieja el día
  /// que el conector estrene una escritura nueva.
  static List<String> get _loQueEscribe => [
    for (final herramienta in McpPermissions.escrituraDeFuera)
      if (herramienta.startsWith('${conector}__')) herramienta,
  ];

  /// La instrucción, escrita para que la conteste una máquina.
  ///
  /// Pide **solo lo que se va a decir** —título, hora, cuántos invitados— y no
  /// la descripción: lo que no se pide no puede acabar sonando por el altavoz
  /// con alguien delante.
  static String instruccionPara(DateTime dia) {
    final fecha = '${dia.year}-${_dos(dia.month)}-${_dos(dia.day)}';
    return 'Dame los eventos de mi calendario de hoy ($fecha) usando el conector '
        'de Google Calendar. Responde ÚNICAMENTE con un array JSON, sin texto '
        'alrededor y sin bloque de código. Cada elemento: {"id": el id del '
        'evento, "titulo": su título, "comienza": la hora de inicio en ISO 8601 '
        'con zona, "invitados": cuántas personas hay invitadas además de mí}. '
        'Si no hay eventos, responde [].';
  }

  /// Las reuniones del día, o `null` si **no se pudo leer**.
  ///
  /// 🔴 **Que falle no es que no haya nada.** Antes un fallo devolvía `[]`, y
  /// con una sola lectura al día daba igual: no había con qué compararlo. Ahora
  /// se relee y se compara, y un `[]` por un fallo se leería como «te
  /// cancelaron todas las reuniones» —dicho en voz alta—. Un fallo es una cuenta
  /// sin sesión, un `claude -p` que no arranca, o una respuesta sin array.
  Future<List<Reunion>?> delDia(
    DateTime dia, {
    required String carpeta,
    String? configDir,
  }) async {
    final buffer = StringBuffer();
    try {
      await for (final evento in cli.run(
        instruccionPara(dia),
        workingDirectory: carpeta,
        // Leer un calendario no toca el disco. Y con el modo restrictivo, la
        // lista de negación del canal deja fuera las herramientas del conector
        // que escriben — mover o borrar un evento no entra por aquí ni por
        // accidente.
        permissionMode: 'manual',
        configDir: configDir,
        model: modelo,
        herramientasMcp: const [conector],
        disallowedTools: _loQueEscribe,
      )) {
        if (evento['type'] != 'result') continue;
        // «Not logged in · Please run /login» llega como un resultado con
        // texto, y marcado como error: no es una agenda.
        if (evento['is_error'] == true) return null;
        if (evento['result'] is String) {
          buffer.write(evento['result'] as String);
        }
      }
    } on Object catch (e) {
      // Que falle mirar la agenda no puede tumbar nada: se queda con lo que
      // tenía hasta la próxima consulta, que es infinitamente mejor que
      // arrastrar el fallo a la app entera por una lectura de fondo que nadie
      // pidió.
      debugPrint('agenda · no se pudo leer el calendario: $e');
      return null;
    }
    return leerONada(buffer.toString());
  }

  /// Saca las reuniones de lo que contestó, y `[]` si no hay ninguna que sacar.
  ///
  /// **Tolerante con el envoltorio a propósito.** Se le pide JSON pelado y aun
  /// así a veces llega dentro de un bloque de código o con una frase delante:
  /// negarse por eso dejaría sin avisos un día entero por una coletilla.
  static List<Reunion> leer(String respuesta) =>
      leerONada(respuesta) ?? const [];

  /// Como [leer], pero distingue «no hay reuniones» —un `[]`— de «esto no es
  /// una agenda» —una frase sin array, JSON roto—, que es `null`.
  static List<Reunion>? leerONada(String respuesta) {
    final crudo = _elArray(respuesta);
    if (crudo == null) return null;
    final Object? leido;
    try {
      leido = jsonDecode(crudo);
    } on FormatException {
      return null;
    }
    if (leido is! List) return null;
    return [for (final evento in leido) ?Reunion.deJson(evento)];
  }

  /// El primer `[...]` que haya dentro. Sin regex sobre el JSON entero: se
  /// buscan los extremos, que es lo único que hace falta para quitar el
  /// envoltorio.
  static String? _elArray(String texto) {
    final inicio = texto.indexOf('[');
    final fin = texto.lastIndexOf(']');
    if (inicio == -1 || fin <= inicio) return null;
    return texto.substring(inicio, fin + 1);
  }

  static String _dos(int n) => n.toString().padLeft(2, '0');
}
