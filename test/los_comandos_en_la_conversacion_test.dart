import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/domain/usecases/los_comandos_de_la_casa.dart';
import 'package:nexus/features/assistant/presentation/state/chat_message.dart';
import 'package:nexus/features/assistant/presentation/state/lo_que_hace_cada_comando.dart';
import 'package:nexus/features/assistant/presentation/widgets/chat_panel.dart';
import 'package:nexus/features/history/presentation/providers/slack_providers.dart';
import 'package:nexus/features/programadas/domain/entities/encargo_programado.dart';
import 'package:nexus/features/programadas/presentation/providers/el_vigilante_de_las_programadas.dart';

/// Lo que Nexus contesta sin Claude, **como se pinta**: la ayuda en dos
/// columnas, lo que se repite en filas con su próxima vez, y el parte con su
/// botón y lo que pasó al pulsarlo.
///
/// Que el enrutado lleve cada comando a su sitio ya lo prueban
/// `la_ayuda_en_la_conversacion_test.dart` y `la_lista_de_programadas_test.dart`;
/// aquí va lo que se ve.
const _es = NexusStringsEs();

class _Citas extends ElVigilanteDeLasProgramadas {
  _Citas(this.todas);

  final List<EncargoProgramado> todas;

  @override
  LasCitas build() => LasCitas(todas: todas);
}

class _Slack extends SlackController {
  final mandados = <String>[];

  @override
  SlackConfig build() =>
      const SlackConfig(hayToken: true, destino: 'U01ABCDEFG');

  @override
  Future<String?> mandar(String texto) async {
    mandados.add(texto);
    return null;
  }
}

Future<void> _pump(
  WidgetTester tester,
  List<ChatMessage> mensajes, {
  List<EncargoProgramado> citas = const [],
  _Slack? slack,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        lasCitasProvider.overrideWith(() => _Citas(citas)),
        slackControllerProvider.overrideWith(() => slack ?? _Slack()),
      ],
      child: MaterialApp(
        theme: NexusTheme.dark(),
        builder: (context, child) => StringsScope(strings: _es, child: child!),
        home: Scaffold(
          body: SizedBox(width: 700, child: ChatPanel(messages: mensajes)),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder _conTexto(String texto) => find.byWidgetPredicate(
  (widget) => widget is RichText && widget.text.toPlainText().contains(texto),
);

void main() {
  group('/ayuda', () {
    testWidgets('en dos columnas: cada comando con lo que hace', (
      tester,
    ) async {
      await _pump(tester, const [
        ChatMessage(
          author: ChatAuthor.nexus,
          text: 'la lista',
          esLaAyuda: true,
        ),
      ]);

      expect(find.text(_es.ayudaTitulo), findsOne);
      for (final comando in ElComandoDeLaCasa.enLaAyuda) {
        if (comando == ElComandoDeLaCasa.ayuda) continue;
        expect(
          _conTexto(
            '${comando.comoSeEscribe}  ${loQueHaceElComando(_es, comando)}',
          ),
          findsOne,
          reason: comando.name,
        );
      }
      // Lo que se acaba de escribir no se repite en la tabla.
      expect(_conTexto('/ayuda  '), findsNothing);
      // Y el texto del mensaje —lo que queda al releerla— no se pinta encima.
      expect(find.textContaining('la lista'), findsNothing);

      // Dos columnas de verdad: la segunda celda empieza a la derecha de la
      // primera, a la misma altura.
      final primera = tester.getTopLeft(_conTexto('/recuerda'));
      final segunda = tester.getTopLeft(_conTexto('/olvida'));
      expect(segunda.dx, greaterThan(primera.dx));
      expect(segunda.dy, primera.dy);
      expect(tester.takeException(), isNull);
    });

    testWidgets('releída del disco, sin marca, queda su texto', (tester) async {
      await _pump(tester, const [
        ChatMessage(author: ChatAuthor.nexus, text: 'la lista'),
      ]);

      expect(find.textContaining('la lista'), findsOne);
      expect(find.text(_es.ayudaTitulo), findsNothing);
    });
  });

  group('/programadas', () {
    testWidgets('cada una dice cuándo vuelve; la apagada, que lo está', (
      tester,
    ) async {
      await _pump(
        tester,
        const [
          ChatMessage(
            author: ChatAuthor.nexus,
            text: 'Lo que se repite:',
            esLaListaDeProgramadas: true,
          ),
        ],
        citas: [
          EncargoProgramado(
            id: 'a',
            carpeta: '/Users/alguien/nexus',
            tarea: 'Revisar el CI de todos los repos',
            dias: const {1},
            hora: 9,
            minuto: 0,
            creado: DateTime(2026, 9, 1),
          ),
          EncargoProgramado(
            id: 'b',
            carpeta: '/Users/alguien/nexus',
            tarea: 'Resumen de PR parados',
            dias: const {5},
            hora: 17,
            minuto: 0,
            creado: DateTime(2026, 9, 1),
            activo: false,
          ),
        ],
      );

      expect(find.text('Revisar el CI de todos los repos'), findsOne);
      expect(find.textContaining(_es.laProximaCita('')), findsOne);
      expect(find.textContaining('${_es.estaApagada} · '), findsOne);
      expect(find.text(_es.apagarla), findsOne);
      expect(find.text(_es.encenderla), findsOne);
      expect(find.text(_es.borrarla), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });

  group('/parte', () {
    testWidgets('lo dice en su rótulo', (tester) async {
      await _pump(tester, const [
        ChatMessage(author: ChatAuthor.nexus, text: 'Ayer…', esElParte: true),
      ]);

      expect(find.text('${_es.nexus} · ${_es.parteDelDia}'), findsOne);
    });

    // «El parte no sale solo»: se manda al pulsar, y después se dice a dónde
    // llegó — «Enviado» a secas no deja comprobar que fue al canal que tocaba.
    testWidgets('se manda al pulsar, y dice a dónde llegó', (tester) async {
      final slack = _Slack();
      await _pump(tester, const [
        ChatMessage(author: ChatAuthor.nexus, text: 'Ayer…', esElParte: true),
      ], slack: slack);

      expect(slack.mandados, isEmpty, reason: 'nunca sin pulsarlo');
      await tester.tap(find.text(_es.parteAlSlack));
      await tester.pumpAndSettle();

      expect(slack.mandados, ['Ayer…']);
      expect(find.text(_es.parteEnviadoA('U01ABCDEFG')), findsOne);
      // El botón sigue ahí, para que se vea qué se pulsó.
      expect(find.text(_es.parteAlSlack), findsOne);
    });
  });
}
