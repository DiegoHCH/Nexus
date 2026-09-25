import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/platform/escucha_channel.dart';

/// Lo que llega del lado nativo, y a quién le toca.
///
/// 🔴 **`seCallo` es el aviso que faltaba.** La escucha se renueva sola cada
/// cierto tiempo y, cuando no podía volver a empezar, se apagaba sin decírselo
/// a nadie: la app seguía creyendo que escuchaba. Si este aviso acabara en
/// `alOir`, llamarla se abriría sola; si no llegara a nadie, volvería el
/// silencio de antes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const canal = MethodChannel('com.katanalabs.nexus/escucha');

  Future<void> comoSiDijera(String que) => TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .handlePlatformMessage(
        canal.name,
        canal.codec.encodeMethodCall(MethodCall(que)),
        (_) {},
      );

  tearDown(() => EscuchaChannel.cuandoTeLlamen(null));

  Future<void> comoSiLlamaran(String resto) => TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .handlePlatformMessage(
        canal.name,
        canal.codec.encodeMethodCall(
          MethodCall('teLlamaron', {'resto': resto}),
        ),
        (_) {},
      );

  test(
    '«teOyo» saca el orbe, «teLlamaron» abre, «seCallo» solo avisa',
    () async {
      final oido = <String>[];
      EscuchaChannel.cuandoTeLlamen(
        (resto) => oido.add('llamada:$resto'),
        alOirTuNombre: () => oido.add('nombre'),
        siSeCalla: () => oido.add('calla'),
      );

      await comoSiDijera('teOyo');
      await comoSiDijera('teLlamaron');
      await comoSiDijera('seCallo');

      expect(oido, ['nombre', 'llamada:', 'calla']);
    },
  );

  // 🔴 Lo que dices después del nombre se perdía: «Hestia, ¿qué reuniones
  // tengo?» llegaba como «Hestia». Ahora viaja con el aviso.
  test('lo dicho después del nombre llega con la llamada', () async {
    String? recibido;
    EscuchaChannel.cuandoTeLlamen((resto) => recibido = resto);

    await comoSiLlamaran(' ¿qué reuniones tengo? ');

    expect(recibido, '¿qué reuniones tengo?');
  });

  test('sin quien escuche el silencio, «seCallo» no revienta', () async {
    final oido = <String>[];
    EscuchaChannel.cuandoTeLlamen((_) => oido.add('llamada'));

    await comoSiDijera('seCallo');

    expect(oido, isEmpty);
  });
}
