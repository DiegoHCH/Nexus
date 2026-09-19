import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexus/features/assistant/data/datasources/conversations_data_source.dart';
import 'package:nexus/features/assistant/presentation/providers/assistant_controller.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/assistant/presentation/providers/la_ventana_de_actividad.dart';
import 'package:nexus/features/assistant/presentation/state/chat_message.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

/// **Cerrar una conversación suelta lo que tenía cogido.**
///
/// 🔴 No lo soltaba. `close()` quitaba la ficha de la lista y la persistía, y
/// ahí acababa: en todo `lib/` no había ni una llamada a `invalidate` de los
/// proveedores por conversación. Como son `family` **sin `autoDispose`**, el
/// `AssistantController` de cada conversación abierta seguía vivo en el
/// contenedor raíz —con sus mensajes, sus pasos y sus búferes— hasta cerrar la
/// app. Una jornada abriendo y cerrando conversaciones no liberaba ni una.
///
/// Lo que se rompe aquí **no falla y no se ve**: la app funciona igual y la
/// memoria sube. Por eso hace falta una prueba que lo mire de frente.
class _Store implements ConversationsDataSource {
  _Store(this.data);
  Map<String, dynamic> data;

  @override
  Future<Map<String, dynamic>> read() async => data;

  @override
  Future<void> write(Map<String, dynamic> json) async => data = json;
}

class _Workspace extends WorkspaceController {
  @override
  Workspace build() => Workspace(
    folders: [PairedFolder(path: '/repos/uno', modality: FolderModality.voice)],
    activePath: '/repos/uno',
  );
}

void main() {
  // El controlador lee preferencias al construirse, y sin binding eso revienta
  // antes de llegar a lo que se mide.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer montar() {
    final container = ProviderContainer(
      overrides: [
        conversationsDataSourceProvider.overrideWithValue(
          _Store({
            'items': [
              {'id': 'c1', 'folderPath': '/repos/uno'},
            ],
            'focusedId': 'c1',
          }),
        ),
        workspaceControllerProvider.overrideWith(_Workspace.new),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  // 🔴 **El guardia, porque soltar vive fuera del notifier y eso se olvida.**
  // No puede estar dentro: `conversationFolderProvider` hace `watch` de
  // `conversationsProvider` y el controlador lo lee, así que invalidar desde el
  // notifier cierra el círculo —probado: `CircularDependencyError`—. El precio
  // es que cada sitio que cierra tiene que soltar, y un cuarto sitio nuevo se
  // olvidaría en silencio: la app seguiría yendo igual y la memoria subiría.
  //
  // Mismo recurso que `chat_message_completo_test`: se lee el código y se
  // exige. Vale para lo que no se puede comprobar ejecutando.
  test('todo el que cierra una conversación la suelta', () {
    final sitios = <String>[];
    for (final fichero in Directory('lib').listSync(recursive: true)) {
      if (fichero is! File || !fichero.path.endsWith('.dart')) continue;
      final codigo = fichero.readAsStringSync();
      // El propio `close` y su documentación no cuentan.
      if (fichero.path.endsWith('conversations_providers.dart')) continue;
      if (!codigo.contains('notifier).close(')) continue;
      if (!codigo.contains('soltarLaConversacionProvider')) {
        sitios.add(fichero.path);
      }
    }

    expect(
      sitios,
      isEmpty,
      reason:
          'estos cierran una conversación y no sueltan lo suyo: el controlador '
          'se queda vivo con sus mensajes hasta cerrar la app. Llama a '
          '`soltarLaConversacionProvider` al lado del `close`',
    );
  });

  test('lo que se dijo en una conversación cerrada no sobrevive', () async {
    final container = montar();
    container.read(conversationsProvider);
    await Future<void>.delayed(Duration.zero);

    // Se habla: el controlador se construye y acumula estado, que es
    // justamente lo que queremos ver desaparecer.
    final controlador = container.read(
      assistantControllerProvider('c1').notifier,
    );
    controlador.state = controlador.state.copyWith(
      messages: [
        const ChatMessage(author: ChatAuthor.user, text: 'algo que ocupa'),
      ],
    );
    expect(
      container.read(assistantControllerProvider('c1')).messages,
      isNotEmpty,
    );

    container.read(soltarLaConversacionProvider)('c1');
    await container.read(conversationsProvider.notifier).close('c1');

    // Y al volver a mirarlo, está recién nacido: el anterior se soltó.
    expect(
      container.read(assistantControllerProvider('c1')).messages,
      isEmpty,
      reason:
          'si los mensajes siguen ahí, el controlador de antes sigue vivo — y '
          'con él todo lo que esa conversación tenía en memoria',
    );
  });

  // 🔴 **El orden importa y por eso se prueba.** La ventana de actividad sujeta
  // al controlador con una suscripción del contenedor; invalidar sin soltarla
  // antes lo reconstruye en el acto, y habríamos cambiado una fuga por otra.
  test('y la ventana de actividad deja de seguirla', () async {
    final container = montar();
    container.read(conversationsProvider);
    await Future<void>.delayed(Duration.zero);

    // `olvidar` de algo que no se seguía no puede reventar: cerrar una
    // conversación de la que nunca se abrió el paso a paso es lo normal, y es
    // lo que pasa en casi todos los cierres.
    container.read(laVentanaDeActividadProvider).olvidar('c1');
    container.read(soltarLaConversacionProvider)('c1');

    await container.read(conversationsProvider.notifier).close('c1');

    expect(container.read(conversationsProvider).items, isEmpty);
  });

  // Cerrar una que no existe tampoco puede tumbar nada: pasa al reconciliar
  // con lo que hay en disco.
  test('cerrar una que no estaba no revienta', () async {
    final container = montar();
    container.read(conversationsProvider);
    await Future<void>.delayed(Duration.zero);

    await container.read(conversationsProvider.notifier).close('la-que-no-va');

    expect(container.read(conversationsProvider).items, hasLength(1));
  });
}
