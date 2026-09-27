import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/data/datasources/conversations_data_source.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/oido/presentation/providers/el_oido_que_espera.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Si al ponerse el micrófono estaba ocupado, el oído vuelve a probar solo.
///
/// 🔴 Visto el 27 sep: al reiniciar la app el micrófono seguía en uso, la
/// escucha no se puso, y nadie volvió a intentarlo. El ajuste decía que
/// escuchaba y llamarla no hacía nada.
void main() {
  const canal = MethodChannel('com.katanalabs.nexus/escucha');

  testWidgets('con el micrófono ocupado, vuelve a probar y se pone', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'oido_encendido': true});
    final intentos = <List<Object?>>[];
    var ocupado = true;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(canal, (
      llamada,
    ) async {
      if (llamada.method == 'empezar') {
        intentos.add(
          ((llamada.arguments as Map)['palabras'] as List).cast<Object?>(),
        );
        return !ocupado;
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        canal,
        null,
      ),
    );

    final contenedor = ProviderContainer(
      overrides: [
        conversationsDataSourceProvider.overrideWithValue(_SinNada()),
      ],
    );
    addTearDown(contenedor.dispose);

    contenedor.read(elOidoQueEsperaProvider);
    await tester.pump(const Duration(milliseconds: 100));
    expect(intentos, hasLength(1), reason: 'lo intenta al arrancar');

    // Se libera el micrófono: al rato lo vuelve a intentar, y ahora sí.
    ocupado = false;
    await tester.pump(ElOidoQueEspera.entreIntentos);
    await tester.pump(const Duration(milliseconds: 100));
    expect(intentos, hasLength(2));

    // Puesta, ya no insiste.
    await tester.pump(ElOidoQueEspera.entreIntentos * 2);
    expect(intentos, hasLength(2));
  });
}

class _SinNada implements ConversationsDataSource {
  @override
  Future<Map<String, dynamic>> read() async => {'items': <Object>[]};
  @override
  Future<void> write(Map<String, dynamic> json) async {}
}
