import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/data/datasources/conversations_data_source.dart';
import 'package:nexus/features/assistant/presentation/pages/home_page.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/assistant/presentation/widgets/composer/composer_chips.dart';
import 'package:nexus/features/assistant/presentation/widgets/composer_bar.dart';
import 'package:nexus/features/assistant/presentation/widgets/el_escenario.dart';
import 'package:nexus/features/assistant/presentation/widgets/el_riel_de_la_sala.dart';
import 'package:nexus/features/history/data/datasources/local_conversation_store.dart';
import 'package:nexus/features/history/domain/entities/conversation_summary.dart';
import 'package:nexus/features/history/presentation/providers/archive_providers.dart';
import 'package:nexus/features/workspace/data/datasources/claude_profiles_data_source.dart';
import 'package:nexus/features/workspace/data/datasources/git_data_source.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screen_harness.dart';

/// **El chat ya no pinta la fila de fichas**: carpeta, repo, rama y cuenta
/// están en la esquina de arriba a la izquierda de la sala.
///
/// 🔴 Reportado con captura, el 30 sep: encima de la caja del chat salían
/// «FRONT-MOBILE-B2C» dos veces —carpeta y repo—, la rama y «WORK», y el motivo
/// para quitarlas fue «ya en la pantalla principal, en la parte superior
/// izquierda, ya sale». Lo que se comprueba aquí es la otra mitad del arreglo:
/// **que lo que hacían se mudó con ellas** y no se perdió por el camino —elegir
/// otra carpeta y separar la memoria compartida—, y que la esquina dice todo lo
/// que decían.
void main() {
  const carpeta = '/Users/alguien/front-mobile-b2c';
  late Directory support;

  setUp(() {
    support = prepareScreenTest();
    // Con el tour visto: su velo cubre la sala y se comería el ratón.
    SharedPreferences.setMockInitialValues({'tour_seen': true});
  });
  tearDown(() => support.deleteSync(recursive: true));

  Future<ProviderContainer> abrir(
    WidgetTester tester, {
    int conversaciones = 1,
  }) async {
    final ids = [for (var i = 0; i < conversaciones; i++) 'c$i'];
    await pumpScreen(
      tester,
      const HomePage(),
      overrides: [
        // De solo texto: la conversación abre con el panel a la vista.
        workspaceControllerProvider.overrideWith(
          () => FixedWorkspace(
            const Workspace(
              folders: [
                PairedFolder(
                  path: carpeta,
                  modality: FolderModality.textOnly,
                  claudeProfile: '/Users/alguien/.claude-work',
                ),
                PairedFolder(
                  path: '/Users/alguien/otra',
                  modality: FolderModality.textOnly,
                ),
              ],
              activePath: carpeta,
            ),
          ),
        ),
        // El repo con otro nombre que la carpeta —un subdirectorio—, que es
        // cuando decirlo aporta algo.
        gitInfoProvider(carpeta).overrideWith(
          (ref) async => const GitInfo(
            repository: 'nexus-monorepo',
            branch: 'feat/CRED-312-implement-eligible-collateral',
          ),
        ),
        reposInsideProvider(
          carpeta,
        ).overrideWith((ref) async => const <String>[]),
        // Dos cuentas: con una sola, la cuenta no se dice.
        claudeProfilesProvider.overrideWith(
          (ref) async => const [
            ClaudeProfile(
              path: '/Users/alguien/.claude-work',
              name: 'work',
              signedIn: true,
            ),
            ClaudeProfile(
              path: '/Users/alguien/.claude-private',
              name: 'private',
              signedIn: true,
            ),
          ],
        ),
        localConversationStoreProvider.overrideWithValue(_ConAlgoDicho(ids)),
        conversationsDataSourceProvider.overrideWithValue(
          _Disco({
            'items': [
              for (final id in ids) {'id': id, 'folderPath': carpeta},
            ],
            'focusedId': 'c0',
          }),
        ),
      ],
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 800));
    return ProviderScope.containerOf(tester.element(find.byType(HomePage)));
  }

  testWidgets('el panel del chat tiene su caja, sin la fila de fichas', (
    tester,
  ) async {
    await abrir(tester);

    expect(find.byType(ComposerBar), findsOneWidget);
    expect(
      find.byType(ComposerChips),
      findsNothing,
      reason: 'la carpeta, el repo, la rama y la cuenta ya salen en la sala',
    );
    // Ni una sola ficha en versales: ni la carpeta, ni la rama, ni la cuenta.
    expect(find.text('FRONT-MOBILE-B2C'), findsNothing);
    expect(find.text('WORK'), findsNothing);
    expect(
      find.text('FEAT/CRED-312-IMPLEMENT-ELIGIBLE-COLLATERAL'),
      findsNothing,
    );
  });

  testWidgets('la esquina de la sala dice carpeta, repo, rama y cuenta', (
    tester,
  ) async {
    await abrir(tester);

    expect(find.text('front-mobile-b2c'), findsOneWidget);
    expect(find.text('nexus-monorepo'), findsOneWidget);
    expect(
      find.text('feat/CRED-312-implement-eligible-collateral'),
      findsOneWidget,
    );
    expect(find.text('cuenta work'), findsOneWidget);
  });

  testWidgets('y con el chat recogido, la esquina sigue diciéndolo', (
    tester,
  ) async {
    await abrir(tester);
    // El botón del riel recoge la conversación: queda la sala sola.
    await tester.tap(find.byKey(ElRielDeLaSala.laLlaveDelChat));
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.byTooltip('Abrir la conversación · ⌘E'),
      findsOneWidget,
      reason: 'el riel ya ofrece abrirla: está recogida',
    );
    expect(find.text('front-mobile-b2c'), findsOneWidget);
    expect(
      find.text('feat/CRED-312-implement-eligible-collateral'),
      findsOneWidget,
    );
    expect(find.text('cuenta work'), findsOneWidget);
  });

  testWidgets('la carpeta de la esquina abre el menú que abría la ficha', (
    tester,
  ) async {
    await abrir(tester);

    await tester.tap(find.byKey(ElEscenario.laLlaveDeLaCarpeta));
    await tester.pump(const Duration(milliseconds: 400));

    // Las carpetas emparejadas, «sin proyecto» y emparejar otra: lo mismo que
    // ofrecía la ficha de la carpeta.
    expect(find.text('otra'), findsOneWidget);
    expect(find.text('Sin proyecto'), findsOneWidget);
    expect(find.text('Emparejar otra carpeta'), findsOneWidget);
  });

  testWidgets('la memoria compartida se separa desde la esquina', (
    tester,
  ) async {
    final estado = await abrir(tester, conversaciones: 2);

    // Sin sesión guardada todavía: «compartirán memoria». Ver
    // [laMemoriaCompartida].
    final memoria = find.textContaining('compartirán memoria');
    expect(memoria, findsOneWidget);
    await tester.tap(memoria);
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      estado
          .read(conversationsProvider)
          .items
          .firstWhere((c) => c.id == 'c0')
          .memoriaPropia,
      isTrue,
      reason:
          'la ficha decía el problema y al tocarla lo resolvía; ahora lo '
          'hace la esquina',
    );
  });
}

class _Disco implements ConversationsDataSource {
  _Disco(this.contenido);

  Map<String, dynamic> contenido;

  @override
  Future<Map<String, dynamic>> read() async {
    await Future<void>.delayed(Duration.zero);
    return contenido;
  }

  @override
  Future<void> write(Map<String, dynamic> json) async => contenido = json;
}

/// Un archivo que dice que todas hablaron: sin esto, el arranque cierra las
/// conversaciones que no dijeron nada antes de que se pinten.
class _ConAlgoDicho implements LocalConversationStore {
  const _ConAlgoDicho(this.ids);

  final List<String> ids;

  @override
  Future<List<ConversationSummary>> list(String folderPath) async => [
    for (final id in ids)
      ConversationSummary(
        id: id,
        folderPath: folderPath,
        startedAt: DateTime(2026, 9, 5),
        title: 'algo',
        turns: 2,
      ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
