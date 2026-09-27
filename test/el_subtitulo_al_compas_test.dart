import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/audio/el_nivel_de_la_voz.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/features/assistant/presentation/widgets/el_subtitulo_al_compas.dart';

/// El subtítulo del Mac, al compás de la voz.
///
/// 🔴 Reportado el 27 sep con la puerta delante: «Buenas tardes, Master» en
/// blanco y «¿En dónde vamos a trabajar hoy?» en gris aunque ya lo había dicho.
/// La pregunta iba en tenue fijo; ahora el gris es lo que falta por decir.
void main() {
  tearDown(() => ElNivelDeLaVoz.avance.value = null);

  Future<(String, String)> pinta(WidgetTester tester, double? avance) async {
    ElNivelDeLaVoz.avance.value = avance;
    await tester.pumpWidget(
      MaterialApp(
        theme: NexusTheme.dark(),
        home: Scaffold(
          body: ElSubtituloAlCompas(
            texto: 'Buenas tardes, Master. ¿En dónde vamos a trabajar hoy?',
            estilo: NexusTypography.subtitle,
            entero: true,
          ),
        ),
      ),
    );
    final rico = tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
    final [ya, falta] = rico.children!.cast<TextSpan>();
    return (ya.text!, falta.text!);
  }

  testWidgets('a mitad, lo dicho y lo que falta, cortado entre palabras', (
    tester,
  ) async {
    final (ya, falta) = await pinta(tester, 0.5);
    expect(ya, isNotEmpty);
    expect(falta, isNotEmpty);
    expect(
      '$ya$falta'.replaceAll(RegExp(r'\s+'), ' ').trim(),
      'Buenas tardes, Master. ¿En dónde vamos a trabajar hoy?',
    );
    expect(
      ya.endsWith(' ') || falta.startsWith(' ') || falta.isEmpty,
      isTrue,
      reason: 'no parte una palabra en dos colores',
    );
  });

  testWidgets('sin nada sonando, todo dicho: nunca se queda en gris', (
    tester,
  ) async {
    final (ya, falta) = await pinta(tester, null);
    expect(falta.trim(), isEmpty);
    expect(ya, contains('¿En dónde vamos a trabajar hoy?'));
  });

  testWidgets('sigue a la voz mientras avanza', (tester) async {
    final (antes, _) = await pinta(tester, 0.2);
    ElNivelDeLaVoz.avance.value = 0.8;
    await tester.pump();
    final rico = tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
    final despues = (rico.children!.first as TextSpan).text!;
    expect(despues.length, greaterThan(antes.length));
  });
}
