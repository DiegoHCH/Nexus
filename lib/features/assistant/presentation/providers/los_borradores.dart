import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lo que se está escribiendo en una conversación y todavía no se mandó.
typedef Borrador = ({String texto, List<String> adjuntos});

/// Los borradores, **uno por conversación**.
///
/// 🔴 **La caja de escribir es una sola para todas**, y guardaba lo escrito
/// dentro de sí: al pasar a otra conversación, el texto a medio escribir se iba
/// con ella. Reportado así: «si escribo un mensaje en una conversación y no lo
/// envío, al pasarme a otra conversación el mensaje se va a esa conversación
/// nueva, cuando debería ser solo de la conversación donde se escribió». Y
/// mandarlo ahí era trabajar en la carpeta que no era.
///
/// Vive en memoria: es lo de ahora, no algo que tenga que sobrevivir a cerrar
/// la app.
class LosBorradores extends Notifier<Map<String, Borrador>> {
  @override
  Map<String, Borrador> build() => const {};

  static const _vacio = (texto: '', adjuntos: <String>[]);

  Borrador de(String conversacion) => state[conversacion] ?? _vacio;

  void guardar(String conversacion, Borrador borrador) {
    if (borrador.texto.isEmpty && borrador.adjuntos.isEmpty) {
      if (!state.containsKey(conversacion)) return;
      state = {...state}..remove(conversacion);
      return;
    }
    state = {...state, conversacion: borrador};
  }
}

final losBorradoresProvider =
    NotifierProvider<LosBorradores, Map<String, Borrador>>(LosBorradores.new);
