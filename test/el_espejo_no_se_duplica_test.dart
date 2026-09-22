import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/emulators/domain/usecases/el_espejo_del_movil.dart';

/// **Un teléfono, un espejo.**
///
/// Desde que el espejo se abre solo al correr la app, volver a correr con la
/// ventana anterior abierta dejaría dos espejos del mismo móvil. Y la salida
/// fácil —no reabrirlo nunca en la misma sesión— es peor: cierras la ventana,
/// vuelves a correr, y no vuelve.
void main() {
  const poco = '36c56d94';
  const espejoDelPoco =
      '/opt/homebrew/bin/scrcpy --serial 36c56d94 --window-title POCO F6 '
      '--no-audio -m 1024 -w';

  test('si ya hay uno de este móvil, se sabe', () {
    expect(
      ElEspejoDelMovil.yaEstaEspejando(poco, const [espejoDelPoco]),
      isTrue,
    );
  });

  test('el de otro móvil no cuenta', () {
    expect(
      ElEspejoDelMovil.yaEstaEspejando('emulator-5554', const [espejoDelPoco]),
      isFalse,
    );
  });

  // El espejo también se abre a mano desde los paneles, así que lo que se mira
  // es la línea de comandos y no una cuenta nuestra — que no sabría de esos.
  test('sin ninguno, tampoco', () {
    expect(ElEspejoDelMovil.yaEstaEspejando(poco, const []), isFalse);
  });

  // 🔴 Un `adb` cualquiera contra el mismo móvil **no** es un espejo: mirar
  // solo el identificador daría por abierto lo que no lo está, y entonces el
  // espejo no se abriría nunca en un dispositivo con `logcat` corriendo — que
  // es exactamente lo que Nexus deja corriendo al correr la app.
  test('y un adb contra el mismo móvil no es un espejo', () {
    expect(
      ElEspejoDelMovil.yaEstaEspejando(poco, const [
        '/Users/alguien/Library/Android/sdk/platform-tools/adb -s 36c56d94 '
            'shell -x logcat -v time',
      ]),
      isFalse,
    );
  });
}
