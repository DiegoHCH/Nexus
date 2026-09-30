import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/i18n/language_preference.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/assistant/data/datasources/conversations_data_source.dart';
import 'package:nexus/features/assistant/data/datasources/gemini_live_data_source.dart';
import 'package:nexus/features/assistant/data/repositories/gemini_voice_gateway.dart';
import 'package:nexus/features/assistant/domain/entities/fallo_de_la_voz.dart';
import 'package:nexus/features/assistant/domain/entities/voice_event.dart';
import 'package:nexus/features/assistant/domain/repositories/audio_output.dart';
import 'package:nexus/features/assistant/domain/repositories/claude_bridge.dart';
import 'package:nexus/features/assistant/domain/repositories/conversation_memory.dart';
import 'package:nexus/features/assistant/domain/repositories/correr_una_prueba.dart';
import 'package:nexus/features/assistant/domain/repositories/el_parte_del_dia.dart';
import 'package:nexus/features/assistant/domain/repositories/la_agenda_de_hoy.dart';
import 'package:nexus/features/assistant/domain/repositories/stays_awake.dart';
import 'package:nexus/features/assistant/domain/repositories/voice_gateway.dart';
import 'package:nexus/features/assistant/domain/repositories/voice_input.dart';
import 'package:nexus/features/assistant/domain/usecases/ask_claude.dart';
import 'package:nexus/features/assistant/domain/usecases/folder_errand_queue.dart';
import 'package:nexus/features/assistant/domain/usecases/hold_voice_conversation.dart';
import 'package:nexus/features/assistant/presentation/pages/home_page.dart';
import 'package:nexus/features/assistant/presentation/providers/assistant_controller.dart';
import 'package:nexus/features/assistant/presentation/providers/claude_bridge_providers.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/assistant/presentation/providers/voice_session_providers.dart';
import 'package:nexus/features/assistant/presentation/state/assistant_hud_state.dart';
import 'package:nexus/features/assistant/presentation/state/que_decir_del_fallo_de_la_voz.dart';
import 'package:nexus/features/history/data/datasources/local_conversation_store.dart';
import 'package:nexus/features/history/presentation/providers/archive_providers.dart';
import 'package:nexus/features/history/domain/entities/conversation_summary.dart';
import 'package:nexus/features/updates/presentation/providers/updates_providers.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/presentation/pages/settings/llaves_section.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/despacho.dart';
import 'support/microfono.dart';
import 'support/screen_harness.dart';

/// **Lo que dice la sala cuando la voz no se abre**, y que nunca sea el error
/// en crudo.
///
/// 🔴 Salió al escribir la guía de configuración de la voz (30 sep): con la
/// carpeta en voz y el micrófono concedido pero sin llave, la sala decía
/// «ParallelWaitError: Bad state: No hay llave de Gemini guardada.». Un
/// `StateError` envuelto en el error del `.wait` que arranca el audio y el
/// socket a la vez, pintado con `toString()`.
const _id = 'c1';
const _carpeta = '/Users/alguien/General';

/// Lo que sale de verdad del arranque de la voz sin llave: el `.wait` de audio
/// y socket con el socket fallando.
Future<Object> _comoSaleSinLlave() async {
  try {
    await (
      Future<void>.value(),
      Future<int>.error(const FaltaLaLlaveDeGemini()),
    ).wait;
  } on Object catch (error) {
    return error;
  }
  throw StateError('el .wait tenía que fallar');
}

void main() {
  const es = NexusStringsEs();
  const en = NexusStringsEn();

  group('el servicio', () {
    GeminiVoiceGateway conLlave(String? llave) => GeminiVoiceGateway(
      const GeminiLiveDataSource(),
      () async => llave,
      () => 'Charon',
      () => 'español',
      () => null,
      () => null,
      () => null,
      () async {},
    );

    // Sin llave no se abre ningún socket: se sabe antes, y se dice con nombre.
    test('sin llave, el fallo tiene nombre y no es un StateError', () async {
      for (final llave in [null, '', '   ']) {
        await expectLater(
          conLlave(llave).connect(),
          throwsA(isA<FaltaLaLlaveDeGemini>()),
        );
      }
    });

    test('sin conversación que retomar, tampoco', () {
      expect(
        () => conLlave('una').resume(),
        throwsA(isA<NoSePuedeRetomarLaVoz>()),
      );
    });
  });

  group('la causa', () {
    test('sale del ParallelWaitError del arranque', () async {
      final envuelto = await _comoSaleSinLlave();
      expect(envuelto, isA<ParallelWaitError<Object?, Object?>>());
      expect('$envuelto', contains('ParallelWaitError'));

      expect(laCausaDe(envuelto), isA<FaltaLaLlaveDeGemini>());
    });

    test('lo que no viene envuelto sale tal cual', () {
      const fallo = LaVozNoSeSostiene();
      expect(laCausaDe(fallo), same(fallo));
    });
  });

  group('lo que se dice', () {
    test('sin llave: su frase, en los dos idiomas, y con la acción', () async {
      final envuelto = await _comoSaleSinLlave();
      for (final textos in [es, en]) {
        final dicho = QueDecirDelFalloDeLaVoz.de(envuelto, '$envuelto', textos);
        expect(dicho.texto, textos.faltaLaLlaveParaHablar);
        expect(dicho.faltaLaLlave, isTrue);
      }
      expect(es.faltaLaLlaveParaHablar, contains('Falta la llave de Gemini'));
      expect(en.faltaLaLlaveParaHablar, contains('Gemini key'));
    });

    test('ningún fallo de la voz llega con el volcado de Dart', () {
      final fallos = <Object?>[
        StateError('algo se rompió'),
        Exception('otra cosa'),
        const NoSePuedeRetomarLaVoz(
          porque: 'el servicio cortó la conexión (1011 Internal error)',
        ),
        const LaVozNoSeSostiene(),
        const SocketException('sin red'),
        const WebSocketException('upgrade'),
        TimeoutException('tarde'),
        PlatformException(code: 'start_failed', message: 'sin micro'),
        null,
      ];
      for (final textos in [es, en]) {
        for (final fallo in fallos) {
          final texto = QueDecirDelFalloDeLaVoz.de(
            fallo,
            'Bad state: se cortó',
            textos,
          ).texto;
          expect(texto, isNot(contains('Bad state')), reason: '$fallo');
          expect(texto, isNot(contains('ParallelWaitError')), reason: '$fallo');
          expect(texto, isNot(contains('Exception')), reason: '$fallo');
          expect(texto, isNot(contains('StateError')), reason: '$fallo');
        }
      }
      // Del corte queda el código, que es lo que se busca.
      expect(
        QueDecirDelFalloDeLaVoz.de(
          const NoSePuedeRetomarLaVoz(
            porque: 'el servicio cortó la conexión (1011 Internal error)',
          ),
          '',
          en,
        ).texto,
        en.laVozNoSeRetoma('1011 Internal error'),
      );
    });

    // 🔴 La bandera va atada al aviso: otro fallo encima la apaga, o debajo de
    // un error de Claude saldría «Poner la llave».
    test('la acción no sobrevive a otro aviso', () {
      const antes = AssistantHudState();
      final sinLlave = antes.copyWith(
        errorMessage: es.faltaLaLlaveParaHablar,
        faltaLaLlaveDeGemini: true,
      );
      expect(sinLlave.faltaLaLlaveDeGemini, isTrue);
      expect(
        sinLlave
            .copyWith(errorMessage: 'Claude no contestó')
            .faltaLaLlaveDeGemini,
        isFalse,
      );
      expect(
        sinLlave.copyWith(orbState: sinLlave.orbState).faltaLaLlaveDeGemini,
        isTrue,
        reason: 'lo que no toca el aviso no toca la bandera',
      );
    });
  });

  group('en la conversación', () {
    late _Guionizada voz;
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      voz = _Guionizada();
    });

    ProviderContainer montar(NexusStrings textos) {
      final c = ProviderContainer(
        overrides: [
          conversationFolderProvider(_id).overrideWithValue(_carpeta),
          conversationMemoryProvider.overrideWithValue(const _SinMemoria()),
          workspaceControllerProvider.overrideWith(_EnVoz.new),
          holdVoiceConversationProvider(_id).overrideWithValue(voz),
          conMicrofono,
          stringsProvider.overrideWithValue(textos),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    Future<AssistantHudState> abrirYFallar(
      ProviderContainer c,
      void Function() fallar,
    ) async {
      await c.read(assistantControllerProvider(_id).notifier).toggleVoice();
      await Future<void>.delayed(Duration.zero);
      fallar();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      return c.read(assistantControllerProvider(_id));
    }

    for (final textos in [es, en]) {
      test(
        'sin llave, en ${textos.idioma}: se traduce y ofrece ponerla',
        () async {
          final c = montar(textos);
          final envuelto = await _comoSaleSinLlave();

          final hud = await abrirYFallar(c, () => voz.fallar(envuelto));

          expect(hud.errorMessage, textos.faltaLaLlaveParaHablar);
          expect(hud.faltaLaLlaveDeGemini, isTrue);
          expect(hud.voiceActive, isFalse);
        },
      );
    }

    test('lo que llega como evento también se traduce', () async {
      final c = montar(en);

      final hud = await abrirYFallar(
        c,
        () => voz.emit(
          const VoiceSessionFailed(
            'La conexión con el servicio de voz no se sostiene.',
            causa: LaVozNoSeSostiene(),
          ),
        ),
      );

      expect(hud.errorMessage, en.laVozNoSeSostiene(null));
      expect(hud.faltaLaLlaveDeGemini, isFalse);
    });
  });

  group('en la sala', () {
    late Directory support;
    setUp(() => support = prepareScreenTest());
    tearDown(() => support.deleteSync(recursive: true));

    testWidgets('«Poner la llave» abre Ajustes › Llaves', (tester) async {
      // Sin el tour de la primera vez, que tapa la sala con su velo.
      SharedPreferences.setMockInitialValues({'tour_seen': true});
      final voz = _Guionizada();
      await pumpScreen(
        tester,
        const HomePage(),
        conPuerta: true,
        overrides: [
          workspaceControllerProvider.overrideWith(
            () => FixedWorkspace(
              const Workspace(
                folders: [
                  PairedFolder(path: _carpeta, modality: FolderModality.voice),
                ],
                activePath: _carpeta,
              ),
            ),
          ),
          conversationsDataSourceProvider.overrideWithValue(
            _Disco({
              'items': [
                {'id': _id, 'folderPath': _carpeta},
              ],
              'focusedId': _id,
            }),
          ),
          holdVoiceConversationProvider(_id).overrideWithValue(voz),
          localConversationStoreProvider.overrideWithValue(_Historial()),
          // Ajustes lee la versión instalada al abrirse; en una prueba no hay
          // bundle del que leerla.
          currentVersionProvider.overrideWith((ref) async => '0.0.1'),
        ],
      );
      final c = ProviderScope.containerOf(
        tester.element(find.byType(HomePage)),
      );
      await tester.runAsync(
        () => c.read(conversationsProvider.notifier).asegurarCargado(),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final envuelto = (await tester.runAsync(_comoSaleSinLlave))!;
      await c.read(assistantControllerProvider(_id).notifier).toggleVoice();
      await tester.pump();
      voz.fallar(envuelto);
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }

      // El aviso sale de los textos del proveedor —el idioma del sistema de la
      // prueba— y el botón, del árbol: por eso cada uno con los suyos.
      expect(
        find.text(c.read(stringsProvider).faltaLaLlaveParaHablar),
        findsOneWidget,
      );
      expect(find.textContaining('ParallelWaitError'), findsNothing);
      expect(find.textContaining('Bad state'), findsNothing);

      final poner = find.text(es.ponerLaLlave.toUpperCase());
      expect(poner, findsOneWidget);
      await tester.tap(poner);
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 60));
      }

      expect(find.byType(LlavesSection), findsOneWidget);
    });
  });
}

/// La sesión de voz, movida a mano desde la prueba: `call()` entero se
/// sustituye, así que las piezas del padre no se usan.
class _Guionizada extends HoldVoiceConversation {
  _Guionizada()
    : super(
        _Nada(),
        _Nada(),
        _Nada(),
        AskClaude(
          _Nada(),
          (_) async => null,
          const _SinMemoria(),
          FolderErrandQueue(),
          _Nada(),
        ),
        (_) {},
        const _SinPruebas(),
        const _SinParte(),
        const _Agenda(),
        const SinEnrutar(),
        () => null,
        () => true,
        () => null,
      );

  final _events = StreamController<VoiceEvent>.broadcast();

  void emit(VoiceEvent event) => _events.add(event);

  void fallar(Object error) => _events.addError(error);

  @override
  Stream<VoiceEvent> call({String? saludo, String? primeraFrase}) =>
      _events.stream;
}

class _Nada
    implements VoiceInput, VoiceGateway, AudioOutput, ClaudeBridge, StaysAwake {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} no debía llamarse');
}

class _SinPruebas implements CorrerUnaPrueba {
  const _SinPruebas();

  @override
  Future<String> loQuePidieron(String pedido) async => 'no';
}

class _SinParte implements ElParteDelDia {
  const _SinParte();

  @override
  Future<String?> instruccion() async => null;

  @override
  void yaEstaEscrito(String parte) {}
}

class _Agenda implements LaAgendaDeHoy {
  const _Agenda();

  @override
  Future<String?> deHoy() async => 'Hoy no tienes reuniones.';
}

class _SinMemoria implements ConversationMemory {
  const _SinMemoria();
  @override
  Future<FolderMemory> read(String folderPath, {String? claudeProfile}) async =>
      const FolderMemory();
  @override
  Future<void> rememberSession(
    String folderPath,
    String sessionId, {
    String? claudeProfile,
  }) async {}
  @override
  Future<void> rememberPrompt(String folderPath, String prompt) async {}
  @override
  Future<void> rememberPermissionMode(
    String f,
    String mode, {
    String? claudeProfile,
  }) async {}
  @override
  Future<void> forget(String folderPath) async {}
}

class _EnVoz extends WorkspaceController {
  @override
  Workspace build() => const Workspace(
    folders: [PairedFolder(path: _carpeta, modality: FolderModality.voice)],
    activePath: _carpeta,
  );
}

class _Disco implements ConversationsDataSource {
  _Disco(this.contenido);
  Map<String, dynamic> contenido;
  @override
  Future<Map<String, dynamic>> read() async => contenido;
  @override
  Future<void> write(Map<String, dynamic> json) async => contenido = json;
}

/// El historial, sin disco: dice que la conversación tiene algo dicho, o el
/// arranque la cerraría por vacía.
class _Historial implements LocalConversationStore {
  @override
  Future<List<ConversationSummary>> list(String folderPath) async => [
    ConversationSummary(
      id: _id,
      folderPath: folderPath,
      startedAt: DateTime(2026, 9, 30),
      title: 'algo',
      turns: 2,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
