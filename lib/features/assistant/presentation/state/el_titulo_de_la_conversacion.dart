import 'package:nexus/features/assistant/presentation/state/chat_message.dart';

/// Con qué se reconoce una conversación.
///
/// **El primer encargo**, que es lo que ya usa el archivo del escritorio y resulta ser
/// el mejor título que nadie ha escrito. Se aplana a una línea porque un encargo puede
/// tener tres párrafos y esto va en una barra de título.
///
/// Si todavía no se ha pedido nada, la cola de la carpeta. Y el id solo como último
/// recurso — que es justo lo que se veía en el teléfono al abrir una conversación
/// nueva, y no dice nada de nada.
///
/// Función aparte y pura porque lo otro no se podía probar: dejar que el publicador
/// mandara el id se colaba entero, con todas las pruebas en verde.
///
/// **Y una sola para las dos pantallas**: el teléfono la recibe por el canal y el
/// orbe pequeño del escenario la enseña al pasar por encima. Dos cuentas distintas
/// de cómo se llama una conversación acabarían diciendo dos nombres.
String tituloDeConversacion({
  required List<ChatMessage> mensajes,
  required String? carpeta,
  required String id,
  String? puesto,
}) {
  // **Lo que puso el usuario manda sobre todo lo demás.** Si se ha tomado la molestia
  // de ponerle nombre, ningún derivado puede pisarlo — y menos el primer encargo, que
  // cambia al retomarla del archivo.
  if (puesto != null && puesto.trim().isNotEmpty) return puesto.trim();

  final primero = mensajes
      .where((m) => m.author == ChatAuthor.user && m.text.trim().isNotEmpty)
      .firstOrNull;
  if (primero != null) {
    final plano = primero.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return plano.length <= 60 ? plano : '${plano.substring(0, 59)}…';
  }

  if (carpeta == null || carpeta.isEmpty) return id;
  return carpeta.split('/').where((p) => p.isNotEmpty).lastOrNull ?? id;
}
