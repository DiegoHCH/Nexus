import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/i18n/language_preference.dart';
import 'package:nexus/features/assistant/data/datasources/conversations_data_source.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/oido/presentation/providers/el_oido_que_espera.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El oído escucha **en el idioma de la app**, el mismo en que habla ella.
///
/// 🔴 Salió al escribir la guía de configuración de la voz (30 sep): el oído
/// reconocía con el idioma del sistema —`Locale.preferredLanguages`, en Swift—
/// y la voz hablaba el de Ajustes › Idioma. Con el Mac en español y la app en
/// inglés, ella contestaba en inglés y el oído esperaba oírte en español.
void main() {
  const canal = MethodChannel('com.katanalabs.nexus/escucha');

  late List<MethodCall> llamadas;

  Future<ProviderContainer> armar(
    WidgetTester tester, {
    required String idioma,
  }) async {
    SharedPreferences.setMockInitialValues({
      'oido_encendido': true,
      'language': idioma,
    });
    llamadas = [];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(canal, (
      llamada,
    ) async {
      llamadas.add(llamada);
      return switch (llamada.method) {
        'empezar' || 'idioma' => true,
        _ => null,
      };
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
    // El idioma se lee del disco, como en la app: primero él, luego el oído.
    contenedor.read(languageControllerProvider);
    await tester.pump(const Duration(milliseconds: 50));
    // Escuchado, como lo tiene la app —`main.dart` lo vigila—: un proveedor
    // sin nadie que lo escuche no atiende a lo que cambia.
    contenedor.listen(elOidoQueEsperaProvider, (_, _) {});
    await tester.pump(const Duration(milliseconds: 100));
    return contenedor;
  }

  Object? elIdiomaDe(String metodo) =>
      (llamadas.lastWhere((l) => l.method == metodo).arguments
          as Map)['idioma'];

  testWidgets('se pone con el idioma de la app', (tester) async {
    await armar(tester, idioma: 'en');
    expect(elIdiomaDe('empezar'), 'en');
  });

  testWidgets('y en español si la app va en español', (tester) async {
    await armar(tester, idioma: 'es');
    expect(elIdiomaDe('empezar'), 'es');
  });

  testWidgets('cambiarlo en Ajustes › Idioma se lo pasa al oído', (
    tester,
  ) async {
    final contenedor = await armar(tester, idioma: 'es');
    expect(llamadas.where((l) => l.method == 'idioma'), isEmpty);

    await contenedor
        .read(languageControllerProvider.notifier)
        .select(LanguageChoice.english);
    await tester.pump(const Duration(milliseconds: 50));

    expect(elIdiomaDe('idioma'), 'en');
  });

  testWidgets('elegir el mismo idioma no lo reinicia', (tester) async {
    final contenedor = await armar(tester, idioma: 'en');

    await contenedor
        .read(languageControllerProvider.notifier)
        .select(LanguageChoice.english);
    await tester.pump(const Duration(milliseconds: 50));

    expect(llamadas.where((l) => l.method == 'idioma'), isEmpty);
  });
}

class _SinNada implements ConversationsDataSource {
  @override
  Future<Map<String, dynamic>> read() async => {'items': <Object>[]};
  @override
  Future<void> write(Map<String, dynamic> json) async {}
}
