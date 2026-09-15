import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/superpowers/domain/usecases/las_llamadas_a_figma.dart';

/// **Qué gasta cupo de Figma y qué no.**
///
/// Figma no publica contador: el tope está escrito —20 al mes en un plan
/// Starter, 200 al día con asiento Dev— pero no hay forma de preguntar cuánto
/// llevas. Esto es lo que permite contarlo del registro sin inventarse nada.
void main() {
  test('las de un servidor de Figma se reconocen, se llame como se llame', () {
    // Los dos que hay puestos en esta máquina: el local y el conector de
    // claude.ai, que lo escribe con mayúscula y con la marca delante.
    expect(LasLlamadasAFigma.esDeFigma('mcp__figma__get_screenshot'), isTrue);
    expect(
      LasLlamadasAFigma.esDeFigma('mcp__claude_ai_Figma__get_design_context'),
      isTrue,
    );
  });

  test('lo que no es de Figma no cuenta, aunque se le parezca', () {
    expect(LasLlamadasAFigma.esDeFigma('mcp__g66__jira_get_issue'), isFalse);
    expect(LasLlamadasAFigma.esDeFigma('Bash'), isFalse);
    expect(LasLlamadasAFigma.esDeFigma('mcp__figma'), isFalse);
    // Una herramienta propia que hablara *de* figma tampoco: se mira el
    // servidor, no el nombre.
    expect(LasLlamadasAFigma.esDeFigma('mcp__nexus__abrir_figma'), isFalse);
  });

  test('las tres exentas no gastan cupo', () {
    for (final exenta in LasLlamadasAFigma.exentas) {
      expect(
        LasLlamadasAFigma.gasta('mcp__figma__$exenta'),
        isFalse,
        reason: '$exenta está exenta según la documentación de Figma',
      );
    }
    expect(LasLlamadasAFigma.gasta('mcp__figma__get_design_context'), isTrue);
  });

  test('el mes se cuenta en hora local, que es donde vive quien mira', () {
    final mes = DateTime(2026, 9, 15);
    expect(LasLlamadasAFigma.delMes(DateTime(2026, 9, 1), mes), isTrue);
    expect(
      LasLlamadasAFigma.delMes(DateTime(2026, 9, 30, 23, 59), mes),
      isTrue,
    );
    expect(
      LasLlamadasAFigma.delMes(DateTime(2026, 8, 31, 23, 59), mes),
      isFalse,
    );
    expect(LasLlamadasAFigma.delMes(DateTime(2026, 10), mes), isFalse);
    // Y el año, que si no septiembre del año pasado sumaría.
    expect(LasLlamadasAFigma.delMes(DateTime(2025, 9, 15), mes), isFalse);
  });

  test('el primero del mes es de donde se arranca a mirar', () {
    expect(
      LasLlamadasAFigma.elPrimeroDel(DateTime(2026, 9, 15, 13, 40)),
      DateTime(2026, 9, 1),
    );
  });
}
