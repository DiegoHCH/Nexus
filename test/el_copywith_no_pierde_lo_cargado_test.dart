import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/domain/entities/conversation.dart';

/// **Un `copyWith` que se deja un campo tumba la pantalla entera.**
///
/// 🔴 Reportado con la captura delante: «tenía una conversación, fui a abrir
/// otra de la misma carpeta, le di empezar de cero y me dejó así, y no me deja
/// hacer nada» — sin muelle, sin caja de escribir, solo el orbe.
///
/// `copyWith` construía un `Conversations` sin pasar `cargado`, así que volvía
/// a su valor de fábrica y la app creía que **todavía no había leído el disco**.
/// Lo que se enseña entonces es la pantalla de primera vez. Es el mismo fallo
/// que el comentario de `cargado` describe —vacío y «todavía no sé» no son lo
/// mismo— entrando por otra puerta.
void main() {
  const cargadas = Conversations(
    items: [Conversation(id: 'c1', folderPath: '/repos/uno')],
    focusedId: 'c1',
    cargado: true,
  );

  test('cambiar la lista no desmarca lo ya leído', () {
    final despues = cargadas.copyWith(
      items: const [Conversation(id: 'c2', folderPath: '/repos/dos')],
    );

    expect(
      despues.cargado,
      isTrue,
      reason: 'sin esto, la app vuelve a la pantalla de primera vez',
    );
  });

  test('ni cambiar el foco', () {
    expect(cargadas.copyWith(focusedId: 'c9').cargado, isTrue);
  });

  test('y lo que no se toca se conserva', () {
    final despues = cargadas.copyWith(focusedId: 'c9');

    expect(despues.items, cargadas.items);
    expect(despues.focusedId, 'c9');
  });

  // Y se puede decir a propósito, que es para lo que está el parámetro.
  test('pero se puede desmarcar si alguien lo pide', () {
    expect(cargadas.copyWith(cargado: false).cargado, isFalse);
  });
}
