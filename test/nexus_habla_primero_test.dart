import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/avisos/presentation/providers/el_que_habla_primero.dart';
import 'package:nexus/features/avisos/presentation/providers/la_voz_que_avisa.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **Nexus hablando primero.**
///
/// Lo que ya pasaba —un encargo que termina, uno que falla— se contaba con una
/// notificación muda del sistema, y una notificación muda no te saca de donde
/// estés: el caso para el que existe ese aviso es justamente que te fuiste a
/// otra cosa.
///
/// Lo que se prueba aquí es el cableado; el criterio vive aparte y tiene sus
/// propias pruebas —ver `lo_que_merece_decirse_test.dart`—, que es lo que
/// permite que esto sea corto.
class _VozDeMentira extends LaVozQueAvisa {
  _VozDeMentira(super.ref, {this.conVozAbierta = false});

  final bool conVozAbierta;
  final dichas = <String>[];

  @override
  bool get hablando => false;

  @override
  bool hayVozAbierta() => conVozAbierta;

  @override
  Future<bool> decir({required String titulo, required String frase}) async {
    dichas.add(frase);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _VozDeMentira voz;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ElQueHablaPrimero.miraSiLaMiran = () async => false;
  });

  tearDown(() {
    ElQueHablaPrimero.miraSiLaMiran = () async => true;
  });

  ElQueHablaPrimero conLaVoz({bool conVozAbierta = false}) {
    final contenedor = ProviderContainer(
      overrides: [
        laVozQueAvisaProvider.overrideWith((ref) {
          voz = _VozDeMentira(ref, conVozAbierta: conVozAbierta);
          return voz;
        }),
      ],
    );
    addTearDown(contenedor.dispose);
    return contenedor.read(elQueHablaPrimeroProvider);
  }

  Future<void> avisa(ElQueHablaPrimero quien, {String llave = 'a'}) =>
      quien.avisa(
        titulo: 'nexus',
        frase: 'En nexus, el encargo terminó.',
        escrito: 'El encargo terminó.',
        llave: llave,
      );

  test('de espaldas, lo dice', () async {
    final quien = conLaVoz();

    await avisa(quien);

    expect(voz.dichas, ['En nexus, el encargo terminó.']);
  });

  // Lo que iba a decir ya está escrito delante: hablar ahí es leerte en voz
  // alta lo que estás leyendo. El aviso del sistema sale igual.
  test('mirando la pantalla, no', () async {
    ElQueHablaPrimero.miraSiLaMiran = () async => true;
    final quien = conLaVoz();

    await avisa(quien);

    expect(voz.dichas, isEmpty);
  });

  test('con una conversación de voz abierta, tampoco', () async {
    final quien = conLaVoz(conVozAbierta: true);

    await avisa(quien);

    expect(voz.dichas, isEmpty);
  });

  test('apagado en Ajustes, se calla', () async {
    SharedPreferences.setMockInitialValues({
      ElQueHablaPrimero.encendido: false,
    });
    final quien = conLaVoz();

    await avisa(quien);

    expect(voz.dichas, isEmpty);
  });

  // 🔴 Lo mismo dos veces seguidas suena a loro, y dos encargos que acaban
  // juntos se pisarían la frase.
  test('y no se repite ni se ametralla', () async {
    final quien = conLaVoz();

    await avisa(quien);
    await avisa(quien);
    await avisa(quien, llave: 'otro');

    expect(voz.dichas, hasLength(1));
  });
}
