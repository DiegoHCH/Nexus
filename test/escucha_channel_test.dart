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

  test(
    '«teLlamaron» abre, y «seCallo» solo avisa de que ya no escucha',
    () async {
      final oido = <String>[];
      EscuchaChannel.cuandoTeLlamen(
        () => oido.add('llamada'),
        siSeCalla: () => oido.add('calla'),
      );

      await comoSiDijera('teLlamaron');
      await comoSiDijera('seCallo');

      expect(oido, ['llamada', 'calla']);
    },
  );

  test('sin quien escuche el silencio, «seCallo» no revienta', () async {
    final oido = <String>[];
    EscuchaChannel.cuandoTeLlamen(() => oido.add('llamada'));

    await comoSiDijera('seCallo');

    expect(oido, isEmpty);
  });
}
