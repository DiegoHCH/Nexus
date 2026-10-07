import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/artifacts/domain/repositories/gemini_image_key_store.dart';
import 'package:nexus/features/artifacts/presentation/providers/artifacts_providers.dart';
import 'package:nexus/features/assistant/domain/entities/claude_event.dart';
import 'package:nexus/features/assistant/domain/entities/conversation.dart';
import 'package:nexus/features/assistant/domain/entities/peticion_de_permiso.dart';
import 'package:nexus/features/assistant/domain/repositories/conversation_memory.dart';
import 'package:nexus/features/assistant/domain/usecases/ask_claude.dart';
import 'package:nexus/features/assistant/presentation/providers/assistant_controller.dart';
import 'package:nexus/features/assistant/presentation/providers/claude_bridge_providers.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/history/data/datasources/local_conversation_store.dart';
import 'package:nexus/features/history/domain/entities/conversation_record.dart';
import 'package:nexus/features/history/domain/entities/conversation_summary.dart';
import 'package:nexus/features/history/presentation/providers/archive_providers.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/domain/usecases/la_modalidad_al_emparejar.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:nexus/features/assistant/domain/repositories/las_carpetas_del_disco.dart';
import 'package:nexus/features/assistant/presentation/providers/el_despacho_de_carpeta_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nombrar la carpeta hablando y que el encargo caiga donde toca.
///
/// 🔴 **Es el 80 % del spike sin pagar su nudo.** Hoy hay que elegir la carpeta a
/// mano antes de hablar, y de ella cuelgan la cuenta, el modelo, los permisos y
/// el prompt. «En el front mobile, arregla el login» ya dice dónde.
///
/// Y la regla que manda: **nunca se trabaja en la carpeta que no era** — un
/// encargo en la equivocada puede escribir con la cuenta del trabajo en un repo
/// personal, y eso no se deshace pidiéndolo.
const _aqui = '/w/nexus';
const _alla = '/w/front-mobile-b2c';

class _Claude implements AskClaude {
  _Claude(this.dondeCayo, this.conversacion, this.conPermiso);

  final Map<String, List<String>> dondeCayo;

  @override
  final String conversacion;

  /// Con qué tope llegó cada encargo. Es lo que dice si el enrutado lo respetó.
  final Map<String, List<bool>> conPermiso;

  @override
  Stream<ClaudeEvent> call(
    String instruction, {
    bool remember = true,
    bool allowWrites = true,
    Future<RespuestaDePermiso> Function(PeticionDePermiso peticion)?
    alPedirPermiso,
  }) async* {
    (dondeCayo[conversacion] ??= []).add(instruction);
    (conPermiso[conversacion] ??= []).add(allowWrites);
    yield const ClaudeTurnCompleted(result: 'ya está');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _SinLlave implements GeminiImageKeyStore {
  const _SinLlave();
  @override
  Future<String?> read(String? perfil) async => null;
  @override
  Future<void> save(String? perfil, String key) async {}
  @override
  Future<void> clear(String? perfil) async {}
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

class _SinAlmacen implements LocalConversationStore {
  const _SinAlmacen();
  @override
  Future<void> save(ConversationRecord record) async {}
  @override
  Future<List<ConversationSummary>> list(String folderPath) async => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Espacio extends WorkspaceController {
  _Espacio([this.leeTodo = false]);

  final bool leeTodo;

  @override
  Workspace build() => Workspace(
    folders: [
      PairedFolder(path: _aqui, modality: FolderModality.voice),
      PairedFolder(path: _alla, modality: FolderModality.voice),
    ],
    activePath: _aqui,
    leeTodoElMac: leeTodo,
  );
}

/// El disco de mentira: lo que existe y lo que se llama de cada forma.
class _Disco implements LasCarpetasDelDisco {
  const _Disco({this.existen = const {}});

  final Set<String> existen;

  @override
  Future<bool> existe(String ruta) async => existen.contains(ruta);

  @override
  Future<List<String>> lasQueSeLlaman(String nombre) async => const [];

  @override
  Future<bool> esUnRepo(String ruta) async => false;
}

class _Abiertas extends ConversationsController {
  _Abiertas(this._items);
  final List<Conversation> _items;
  @override
  Conversations build() =>
      Conversations(items: _items, focusedId: _items.first.id, cargado: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, List<String>> dondeCayo;
  late Map<String, List<bool>> conPermiso;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dondeCayo = {};
    conPermiso = {};
  });

  ProviderContainer montar(
    List<Conversation> abiertas, {
    bool leeTodo = false,
    _Disco disco = const _Disco(),
  }) {
    final container = ProviderContainer(
      overrides: [
        conversationMemoryProvider.overrideWithValue(const _SinMemoria()),
        workspaceControllerProvider.overrideWith(() => _Espacio(leeTodo)),
        lasCarpetasDelDiscoProvider.overrideWithValue(disco),
        // Emparejar mira el micrófono y el llavero: aquí no hay ni uno ni otro.
        loQueTieneLaVozProvider.overrideWithValue(
          () async => const LoQueTieneLaVoz.nada(),
        ),
        localConversationStoreProvider.overrideWithValue(const _SinAlmacen()),
        geminiImageKeyStoreProvider.overrideWithValue(const _SinLlave()),
        conversationsProvider.overrideWith(() => _Abiertas(abiertas)),
        for (final c in abiertas) ...[
          conversationFolderProvider(c.id).overrideWithValue(c.folderPath),
          askClaudeProvider(
            c.id,
          ).overrideWithValue(_Claude(dondeCayo, c.id, conPermiso)),
        ],
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> asentar() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  const dosAbiertas = [
    Conversation(id: 'aqui', folderPath: _aqui),
    Conversation(id: 'alla', folderPath: _alla),
  ];

  test('sin nombrar carpeta, el encargo se queda donde se escribió', () async {
    final container = montar(dosAbiertas);

    await container
        .read(assistantControllerProvider('aqui').notifier)
        .submit('arregla el login');
    await asentar();

    expect(dondeCayo['aqui'], ['arregla el login']);
    expect(dondeCayo['alla'], isNull);
  });

  // 🔴 El caso del spike.
  test('nombrando otra, el encargo cae allí y sin la mención', () async {
    final container = montar(dosAbiertas);

    await container
        .read(assistantControllerProvider('aqui').notifier)
        .submit('en el front mobile b2c, arregla el login');
    await asentar();

    expect(dondeCayo['alla'], ['arregla el login']);
    expect(
      dondeCayo['aqui'],
      isNull,
      reason: 'trabajar en la carpeta que no era es lo que esto viene a evitar',
    );
  });

  // 🔴 **Y se lleva de qué se hablaba, que si no llega en blanco.**
  //
  // Reportado así: «al escribir el nombre de la carpeta donde quiero que copie
  // eso, lo que hace es abrirme una conversación en esa carpeta». Era verdad y
  // era peor de lo que suena: el encargo llegaba allí con la tarea suelta, y una
  // tarea suelta pierde aquello de lo que hablaba. «Copia eso» sin el hilo no
  // dice qué es «eso», así que la conversación de destino nacía sin nada que
  // hacer — moverte de sitio sin llevarte el hilo es lo peor de los dos mundos.
  test('y se lleva lo que se venía diciendo donde se pidió', () async {
    final container = montar(dosAbiertas);
    final aqui = container.read(assistantControllerProvider('aqui').notifier);

    // Una conversación con pasado: esto es lo que no puede quedarse atrás.
    await aqui.submit('genera los tres diagramas');
    await asentar();

    await aqui.submit('en el front mobile b2c, copia eso');
    await asentar();

    final llego = dondeCayo['alla']!.single;
    expect(
      llego,
      contains('genera los tres diagramas'),
      reason: 'sin el hilo, allí no se sabe qué es «eso»',
    );
    expect(
      llego,
      endsWith('copia eso'),
      reason: 'el hilo acompaña a la tarea, no la sustituye',
    );
  });

  // Y una recién nacida no arrastra encabezado: no hay hilo que contar, y un
  // «esto es lo que se dijo» sin nada debajo se paga igual.
  test('pero una conversación sin pasado viaja ligera', () async {
    final container = montar(dosAbiertas);

    await container
        .read(assistantControllerProvider('aqui').notifier)
        .submit('en el front mobile b2c, arregla el login');
    await asentar();

    expect(dondeCayo['alla'], ['arregla el login']);
  });

  // El foco es la única señal de que pasó algo: sin eso, se escribe en una
  // pestaña y el trabajo aparece en otra que no se está mirando.
  test('y el foco se va con él', () async {
    final container = montar(dosAbiertas);

    await container
        .read(assistantControllerProvider('aqui').notifier)
        .submit('en front-mobile-b2c corre las pruebas');
    await asentar();

    expect(container.read(conversationsProvider).focusedId, 'alla');
  });

  test('nombrando la de aquí, no se mueve y va sin la mención', () async {
    final container = montar(dosAbiertas);

    await container
        .read(assistantControllerProvider('aqui').notifier)
        .submit('en nexus, arregla el login');
    await asentar();

    expect(dondeCayo['aqui'], ['arregla el login']);
    expect(container.read(conversationsProvider).focusedId, 'aqui');
  });

  // Cambiar de sitio sin encargo es legítimo: se mueve el foco y ya.
  test('nombrarla sola solo cambia de sitio', () async {
    final container = montar(dosAbiertas);

    await container
        .read(assistantControllerProvider('aqui').notifier)
        .submit('vete al front mobile b2c');
    await asentar();

    expect(container.read(conversationsProvider).focusedId, 'alla');
    expect(dondeCayo['alla'], isNull);
  });

  // 🔴 De la carpeta salen la cuenta y los permisos: elegir por la persona es
  // justo lo que no se puede hacer.
  test('nombrando dos, no se hace nada y se dice', () async {
    final container = montar(dosAbiertas);

    await container
        .read(assistantControllerProvider('aqui').notifier)
        .submit('pasa lo de nexus al front mobile b2c');
    await asentar();

    expect(dondeCayo, isEmpty);
    final dicho = container
        .read(assistantControllerProvider('aqui'))
        .messages
        .last
        .text;
    expect(dicho, contains('front-mobile-b2c'));
    expect(dicho, contains('nexus'));
  });

  test('un reintento no se vuelve a enrutar', () async {
    final container = montar(dosAbiertas);

    await container
        .read(assistantControllerProvider('aqui').notifier)
        .submit('en el front mobile b2c, arregla el login', reintento: true);
    await asentar();

    expect(
      dondeCayo['aqui'],
      ['en el front mobile b2c, arregla el login'],
      reason:
          'un reintento ya se enrutó en su día: volver a hacerlo lo movería',
    );
  });

  // 🔴 **El tope viaja con el encargo.** `allowWrites` baja lo que la carpeta
  // concede y nunca lo sube, y el teléfono manda `false` mientras no tenga
  // abierta la frase de escritura. Sin reenviarlo, **un teléfono en solo lectura
  // conseguía escritura nombrando otra carpeta** — justo lo que esa frase existe
  // para impedir.
  test('el enrutado no sube el permiso de escritura', () async {
    final container = montar(dosAbiertas);

    await container
        .read(assistantControllerProvider('aqui').notifier)
        .submit('en el front mobile b2c, arregla el login', allowWrites: false);
    await asentar();

    expect(conPermiso['alla'], [false]);
  });

  test('y el de aquí tampoco, cuando no se mueve', () async {
    final container = montar(dosAbiertas);

    await container
        .read(assistantControllerProvider('aqui').notifier)
        .submit('en nexus, arregla el login', allowWrites: false);
    await asentar();

    expect(conPermiso['aqui'], [false]);
  });

  // Se sueltan tres capturas, se nombra otra carpeta, y el encargo llegaba allí
  // sin ellas — con la frase pidiendo que se miren.
  test('los adjuntos viajan con el encargo', () async {
    final container = montar(dosAbiertas);

    await container
        .read(assistantControllerProvider('aqui').notifier)
        .submit(
          'en el front mobile b2c, mira estas capturas',
          attachments: const ['/tmp/una.png'],
        );
    await asentar();

    expect(
      container
          .read(assistantControllerProvider('alla'))
          .messages
          .first
          .attachments,
      ['/tmp/una.png'],
    );
  });

  // 🔴 **De quién es el foco.** Desde el Mac, que la pestaña salte es la única
  // señal de que el trabajo se fue a otra parte. Desde el teléfono no: el móvil
  // navega a una conversación concreta y no sigue al foco, así que moverlo haría
  // saltar la pantalla de quien esté delante **sin haberlo pedido** — y al móvil
  // no le serviría de nada.
  group('de quién es el foco', () {
    test('desde el Mac, el foco se va con el encargo', () async {
      final container = montar(dosAbiertas);

      await container
          .read(assistantControllerProvider('aqui').notifier)
          .submit('en el front mobile b2c, arregla el login');
      await asentar();

      expect(container.read(conversationsProvider).focusedId, 'alla');
    });

    test('desde el teléfono, el foco no se mueve', () async {
      final container = montar(dosAbiertas);

      await container
          .read(assistantControllerProvider('aqui').notifier)
          .submit(
            'en el front mobile b2c, arregla el login',
            elFocoSigue: false,
          );
      await asentar();

      expect(container.read(conversationsProvider).focusedId, 'aqui');
      expect(dondeCayo['alla'], [
        'arregla el login',
      ], reason: 'el trabajo sí se va: lo que no se mueve es la pantalla');
    });

    // Y callarse dejaría a quien lo pidió mirando una conversación donde no va
    // a pasar nada.
    test('y se dice a dónde fue, que si no es silencio', () async {
      final container = montar(dosAbiertas);

      await container
          .read(assistantControllerProvider('aqui').notifier)
          .submit(
            'en el front mobile b2c, arregla el login',
            elFocoSigue: false,
          );
      await asentar();

      expect(
        container.read(assistantControllerProvider('aqui')).messages.last.text,
        contains('front-mobile-b2c'),
      );
    });

    // 🔴 **`open()` enfoca por dentro.** El arreglo anterior solo tapó el camino
    // de «ya hay una abierta»: cuando había que **estrenar** conversación, abrir
    // la enfocaba igual y la pantalla del Mac saltaba lo mismo. La mitad del
    // arreglo se colaba por aquí.
    test(
      'estrenar conversación desde el teléfono tampoco mueve el foco',
      () async {
        final container = montar(const [
          Conversation(id: 'aqui', folderPath: _aqui),
        ]);

        await container
            .read(assistantControllerProvider('aqui').notifier)
            .submit(
              'en el front mobile b2c, arregla el login',
              elFocoSigue: false,
            );
        await asentar();

        expect(container.read(conversationsProvider).focusedId, 'aqui');
        expect(
          container.read(conversationsProvider).items,
          hasLength(2),
          reason:
              'la conversación sí se abre: lo que no se mueve es la pantalla',
        );
      },
    );
  });

  // «Solo con que yo le diga en dónde quiero que inicie la conversación debería
  // hacerlo y ya.» Para las carpetas sin emparejar, y solo con la lectura de
  // todo el Mac encendida. Ver `DondeAbrirLaConversacion`.
  group('abrir donde digas, sin emparejar', () {
    const rutaDeNotas = '/w/notas';
    const conLasNotas = [
      Conversation(id: 'aqui', folderPath: _aqui),
      // Abierta sobre una ruta suelta, que se puede: así se ve a dónde llega.
      Conversation(id: 'notas', folderPath: rutaDeNotas),
    ];

    test('la empareja y el encargo cae allí', () async {
      final container = montar(
        conLasNotas,
        leeTodo: true,
        disco: const _Disco(existen: {rutaDeNotas}),
      );

      await container
          .read(assistantControllerProvider('aqui').notifier)
          .submit('abre una conversación en /w/notas, cuenta mis tareas');
      await asentar();

      expect(dondeCayo['notas'], ['cuenta mis tareas']);
      expect(dondeCayo['aqui'], isNull);
      expect(
        container.read(workspaceControllerProvider).folders.map((f) => f.path),
        contains(rutaDeNotas),
        reason: 'emparejada sola, con las reglas de siempre',
      );
    });

    test('nace como al emparejar a mano: sin escritura', () async {
      final container = montar(
        conLasNotas,
        leeTodo: true,
        disco: const _Disco(existen: {rutaDeNotas}),
      );

      await container
          .read(assistantControllerProvider('aqui').notifier)
          .submit('abre una conversación en /w/notas');
      await asentar();

      final notas = container
          .read(workspaceControllerProvider)
          .folders
          .firstWhere((f) => f.path == rutaDeNotas);
      expect(notas.puedeEditar, isFalse);
      expect(notas.modality, FolderModality.textOnly, reason: 'sin voz lista');
    });

    // Quien no lo encendió conserva la regla de siempre: solo las emparejadas.
    test('con la lectura de todo el Mac apagada, no se mueve nada', () async {
      final container = montar(
        conLasNotas,
        disco: const _Disco(existen: {rutaDeNotas}),
      );

      await container
          .read(assistantControllerProvider('aqui').notifier)
          .submit('abre una conversación en /w/notas, cuenta mis tareas');
      await asentar();

      expect(dondeCayo['notas'], isNull);
      expect(dondeCayo['aqui'], hasLength(1));
    });

    test(
      'una ruta que no existe se dice y no se trabaja en ningún sitio',
      () async {
        final container = montar(conLasNotas, leeTodo: true);

        await container
            .read(assistantControllerProvider('aqui').notifier)
            .submit('abre una conversación en /w/fantasma');
        await asentar();

        expect(dondeCayo, isEmpty);
        expect(
          container
              .read(assistantControllerProvider('aqui'))
              .messages
              .last
              .text,
          contains('/w/fantasma'),
        );
      },
    );

    // 🔴 Una tarea con pinta de sitio no se come el encargo.
    test('«trabajemos en el bug del login» se atiende aquí', () async {
      final container = montar(conLasNotas, leeTodo: true);

      await container
          .read(assistantControllerProvider('aqui').notifier)
          .submit('trabajemos en el bug del login');
      await asentar();

      expect(dondeCayo['aqui'], ['trabajemos en el bug del login']);
    });
  });
}
