import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/nexus_theme.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/domain/entities/peticion_de_permiso.dart';
import 'package:nexus/features/assistant/domain/entities/pregunta_de_claude.dart';
import 'package:nexus/features/assistant/presentation/widgets/la_pregunta_de_claude.dart';

/// Las preguntas con opciones de Claude, pintadas y contestadas en el chat.
///
/// 🔴 Pedido el 27 sep, viendo las de la terminal: «no solo me responde para
/// que escriba, sino que me da opciones y me recomienda».
PeticionDePermiso _con(List<Map<String, Object>> preguntas) =>
    PeticionDePermiso(
      id: 'req-1',
      herramienta: LaPreguntaDeClaude.herramienta,
      nombreVisible: LaPreguntaDeClaude.herramienta,
      entrada: {'questions': preguntas},
    );

final _color = {
  'question': '¿Qué color prefieres?',
  'header': 'Color',
  'options': [
    {'label': 'Azul (Recomendado)', 'description': 'El de siempre'},
    {'label': 'Rojo', 'description': 'Más visible'},
  ],
  'multiSelect': false,
};

final _dias = {
  'question': '¿Qué días?',
  'options': [
    {'label': 'Lunes'},
    {'label': 'Martes'},
    {'label': 'Miércoles'},
  ],
  'multiSelect': true,
};

void main() {
  group('lo que trae', () {
    test('las preguntas, con su rótulo y sus opciones', () {
      final [pregunta] = LaPreguntaDeClaude.de(_con([_color]));
      expect(pregunta.pregunta, '¿Qué color prefieres?');
      expect(pregunta.rotulo, 'Color');
      expect(pregunta.opciones, hasLength(2));
      expect(pregunta.variasALaVez, isFalse);
    });

    test('la recomendada se reconoce, y se pinta sin el paréntesis', () {
      final [pregunta] = LaPreguntaDeClaude.de(_con([_color]));
      final [azul, rojo] = pregunta.opciones;
      expect(azul.recomendada, isTrue);
      expect(azul.sinLaMarca, 'Azul');
      expect(
        azul.etiqueta,
        'Azul (Recomendado)',
        reason: 'se devuelve tal cual',
      );
      expect(rojo.recomendada, isFalse);
    });

    test('lo que no se puede contestar se salta', () {
      expect(
        LaPreguntaDeClaude.de(
          _con([
            {'question': '', 'options': <Object>[]},
          ]),
        ),
        isEmpty,
      );
    });

    test('la respuesta va dentro del permiso, junto a las preguntas', () {
      final peticion = _con([_color]);
      final respuesta = LaPreguntaDeClaude.contestada(peticion, {
        '¿Qué color prefieres?': 'Rojo',
      });
      final entrada = (respuesta as PermisoConcedido).entrada;
      expect(entrada['answers'], {'¿Qué color prefieres?': 'Rojo'});
      expect(entrada['questions'], peticion.entrada['questions']);
    });
  });

  group('en el chat', () {
    Future<List<Object>> montar(
      WidgetTester tester,
      PeticionDePermiso peticion, {
      DecisionDePermiso? decision,
      Map<String, String>? respuestas,
    }) async {
      final dicho = <Object>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: NexusTheme.dark(),
          home: StringsScope(
            strings: const NexusStringsEs(),
            child: Scaffold(
              body: SingleChildScrollView(
                child: LaPreguntaDeClaudeEnElChat(
                  peticion: peticion,
                  decision: decision,
                  respuestas: respuestas,
                  onResponder: (id, r) => dicho.add(r),
                  onNoContestar: (id) => dicho.add('no'),
                ),
              ),
            ),
          ),
        ),
      );
      return dicho;
    }

    testWidgets('una sola, de un toque: pulsar la opción ya contesta', (
      tester,
    ) async {
      final dicho = await montar(tester, _con([_color]));
      expect(find.text('RECOMENDADA'), findsOneWidget);
      expect(
        find.byKey(LaPreguntaDeClaudeEnElChat.elBotonDeResponder),
        findsNothing,
      );

      await tester.tap(find.byKey(LaPreguntaDeClaudeEnElChat.laOpcion(0, 1)));
      expect(dicho, [
        {'¿Qué color prefieres?': 'Rojo'},
      ]);
    });

    testWidgets('varias a la vez: se eligen y se responde una vez', (
      tester,
    ) async {
      final dicho = await montar(tester, _con([_dias]));
      await tester.tap(find.byKey(LaPreguntaDeClaudeEnElChat.laOpcion(0, 2)));
      await tester.tap(find.byKey(LaPreguntaDeClaudeEnElChat.laOpcion(0, 0)));
      await tester.pump();
      expect(dicho, isEmpty);

      await tester.tap(
        find.byKey(LaPreguntaDeClaudeEnElChat.elBotonDeResponder),
      );
      expect(dicho, [
        {'¿Qué días?': 'Lunes, Miércoles'},
      ]);
    });

    testWidgets('otra respuesta, escrita, vale en lugar de una opción', (
      tester,
    ) async {
      final dicho = await montar(tester, _con([_color]));
      await tester.enterText(
        find.byKey(LaPreguntaDeClaudeEnElChat.laOtra(0)),
        'Verde',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(LaPreguntaDeClaudeEnElChat.elBotonDeResponder),
      );
      expect(dicho, [
        {'¿Qué color prefieres?': 'Verde'},
      ]);
    });

    testWidgets('con dos preguntas, no se responde hasta tener las dos', (
      tester,
    ) async {
      final dicho = await montar(tester, _con([_color, _dias]));
      await tester.tap(find.byKey(LaPreguntaDeClaudeEnElChat.laOpcion(0, 0)));
      await tester.pump();
      await tester.tap(
        find.byKey(LaPreguntaDeClaudeEnElChat.elBotonDeResponder),
      );
      expect(dicho, isEmpty);

      await tester.tap(find.byKey(LaPreguntaDeClaudeEnElChat.laOpcion(1, 1)));
      await tester.pump();
      await tester.tap(
        find.byKey(LaPreguntaDeClaudeEnElChat.elBotonDeResponder),
      );
      expect(dicho, [
        {'¿Qué color prefieres?': 'Azul (Recomendado)', '¿Qué días?': 'Martes'},
      ]);
    });

    testWidgets('«prefiero no contestar» también es una salida', (
      tester,
    ) async {
      final dicho = await montar(tester, _con([_color]));
      await tester.tap(find.text('PREFIERO NO CONTESTAR'));
      expect(dicho, ['no']);
    });

    testWidgets('contestada, queda lo que se eligió y sin botones', (
      tester,
    ) async {
      await montar(
        tester,
        _con([_color]),
        decision: DecisionDePermiso.concedido,
        respuestas: {'¿Qué color prefieres?': 'Rojo'},
      );
      expect(find.text('Rojo'), findsOneWidget);
      expect(find.text('PREFIERO NO CONTESTAR'), findsNothing);
      expect(
        find.byKey(LaPreguntaDeClaudeEnElChat.laOpcion(0, 0)),
        findsNothing,
      );
    });
  });
}
