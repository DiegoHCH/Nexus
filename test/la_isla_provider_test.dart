import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/isla/data/la_ventana_de_la_isla.dart';
import 'package:nexus/features/isla/presentation/providers/la_isla_provider.dart';
import 'package:nexus/features/isla/presentation/state/la_foto_de_la_isla.dart';
import 'package:nexus/features/observador/domain/entities/la_terminal.dart';
import 'package:nexus/features/observador/presentation/providers/la_terminal_provider.dart';

/// La isla vista desde la app: cuándo sale, qué le llega mientras está fuera
/// y qué se hace con lo que se pulsa en ella.
class _LaQueApunta implements LaVentanaDeLaIsla {
  _LaQueApunta({this.sale = true});

  final bool sale;
  final abiertas = <Map<String, Object?>>[];
  final pintadas = <Map<String, Object?>>[];
  var cerradas = 0;
  void Function(Map<Object?, Object?>)? atender;
  void Function()? recogerse;

  @override
  Future<bool> abrir(Map<String, Object?> foto) async {
    abiertas.add(foto);
    return sale;
  }

  @override
  Future<void> pintar(Map<String, Object?> foto) async => pintadas.add(foto);

  @override
  Future<void> cerrar() async => cerradas++;

  @override
  void alPedir(void Function(Map<Object?, Object?> pedido) atender) =>
      this.atender = atender;

  @override
  void alRecogerse(void Function() hacer) => recogerse = hacer;
}

class _Terminal extends LaTerminalController {
  final contestados = <(String, ContestacionDePermiso)>[];

  @override
  LaTerminal build() => LaTerminal.nada;

  @override
  void contestar(String id, ContestacionDePermiso contestacion) =>
      contestados.add((id, contestacion));
}

class _Foto extends Notifier<LaFotoDeLaIsla> {
  @override
  LaFotoDeLaIsla build() => const LaFotoDeLaIsla();

  void pon(LaFotoDeLaIsla foto) => state = foto;
}

final _fotoProvider = NotifierProvider<_Foto, LaFotoDeLaIsla>(_Foto.new);

void main() {
  late _LaQueApunta ventana;
  late _Terminal terminal;
  late ProviderContainer container;

  ProviderContainer crear({bool sale = true}) {
    ventana = _LaQueApunta(sale: sale);
    terminal = _Terminal();
    return ProviderContainer(
      overrides: [
        laVentanaDeLaIslaProvider.overrideWithValue(ventana),
        laTerminalProvider.overrideWith(() => terminal),
        laFotoDeLaIslaProvider.overrideWith((ref) => ref.watch(_fotoProvider)),
      ],
    );
  }

  setUp(() => container = crear());
  tearDown(() => container.dispose());

  test('sale con la foto de ahora, y la sigue mientras está fuera', () async {
    container.read(laIslaProvider);
    container
        .read(_fotoProvider.notifier)
        .pon(const LaFotoDeLaIsla(enLaTerminal: 1));

    await container.read(laIslaProvider.notifier).sacar();

    expect(container.read(laIslaProvider), isTrue);
    expect(ventana.abiertas.single['enLaTerminal'], 1);

    container
        .read(_fotoProvider.notifier)
        .pon(const LaFotoDeLaIsla(enLaTerminal: 3));
    await Future<void>.delayed(Duration.zero);
    expect(ventana.pintadas.last['enLaTerminal'], 3);
  });

  // Dentro nadie la mira, y calcularla escucha todas las conversaciones.
  test('recogida deja de seguir la foto', () async {
    container.read(laIslaProvider);
    await container.read(laIslaProvider.notifier).sacar();

    ventana.recogerse!();
    expect(container.read(laIslaProvider), isFalse);

    container
        .read(_fotoProvider.notifier)
        .pon(const LaFotoDeLaIsla(enLaTerminal: 5));
    await Future<void>.delayed(Duration.zero);
    expect(ventana.pintadas, isEmpty);
  });

  test('si el lado nativo no la saca, todo sigue como estaba', () async {
    container.dispose();
    container = crear(sale: false);
    container.read(laIslaProvider);

    await container.read(laIslaProvider.notifier).sacar();

    expect(container.read(laIslaProvider), isFalse);
  });

  test('un permiso contestado en la isla llega a la terminal', () async {
    container.read(laIslaProvider);

    ventana.atender!(
      const ContestarElPermiso('p1', ContestacionDePermiso.permitir).toMap(),
    );
    ventana.atender!({'que': 'otra', 'id': 'x'});

    expect(terminal.contestados, [('p1', ContestacionDePermiso.permitir)]);
  });

  test('al soltarse la app, la isla no se queda huérfana', () async {
    container.read(laIslaProvider);
    await container.read(laIslaProvider.notifier).sacar();

    container.dispose();
    expect(ventana.cerradas, 1);
    container = crear();
  });
}
