import 'package:nexus/features/assistant/presentation/state/chat_message.dart';

/// **De qué va una conversación**, para clasificar su nota en el vault.
///
/// Del documento «Qué le sirve a Nexus»: etiquetar las notas y colorear el
/// grafo de Obsidian por categorías. Se clasifica **por lo que pasó**, no por
/// lo que se habló: tocó el repositorio, dejó un documento, fue el parte o
/// fue una charla. Son hechos que la conversación ya guarda —los cambios, el
/// documento, la marca del parte—, así que la clase no se equivoca ni cuesta
/// un turno de modelo.
///
/// En orden de precedencia: una conversación que tocó código y además dejó un
/// documento es de código, que es lo que más pesa al buscarla después.
enum ClaseDeNota {
  codigo,
  documento,
  parte,
  charla;

  /// La etiqueta anidada, bajo `nexus/` para no pisar las tuyas.
  String get etiqueta => 'nexus/$name';

  /// La clase de [mensajes].
  static ClaseDeNota de(List<ChatMessage> mensajes) {
    bool alguno(bool Function(ChatMessage) que) => mensajes.any(que);
    if (alguno(
      (m) =>
          (m.cambios?.fileCount ?? 0) > 0 ||
          m.actividad.any((paso) => paso.writes),
    )) {
      return codigo;
    }
    if (alguno((m) => m.documento != null)) return documento;
    if (alguno((m) => m.esElParte)) return parte;
    return charla;
  }
}

/// Si en la conversación se habló por voz: va como etiqueta aparte, porque no
/// es de qué va sino por dónde llegó.
bool seHabloPorVoz(List<ChatMessage> mensajes) =>
    mensajes.any((mensaje) => mensaje.spoken);

/// La etiqueta de la voz, junto a las de clase.
const etiquetaDeLaVoz = 'nexus/voz';

/// La de las notas de proyecto, el centro de cada grafo.
const etiquetaDelProyecto = 'nexus/proyecto';
