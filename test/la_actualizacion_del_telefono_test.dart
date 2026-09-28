import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/remote/data/las_releases_del_telefono.dart';
import 'package:nexus/features/remote/domain/la_actualizacion_del_telefono.dart';
import 'package:nexus/features/remote/presentation/providers/la_actualizacion_del_telefono_provider.dart';
import 'package:nexus/features/remote/presentation/widgets/aviso_de_actualizacion_del_telefono.dart';

/// La app del teléfono se actualiza sola (fase 03 del plan).
void main() {
  Map<String, Object?> release({
    String nombre = 'Nexus-movil-1.35.0.apk',
    String url =
        'https://github.com/DiegoHCH/Nexus/releases/download/v1.35.0/Nexus-movil-1.35.0.apk',
    bool prerelease = false,
  }) => {
    'prerelease': prerelease,
    'draft': false,
    'assets': [
      {'name': 'Nexus-1.35.0.dmg', 'browser_download_url': 'https://x/d.dmg'},
      {'name': nombre, 'browser_download_url': url, 'size': 1234},
    ],
  };

  group('lo que trae la release', () {
    test('el APK del teléfono, con su versión', () {
      final nueva = LaVersionNueva.deLaRelease(release())!;
      expect(nueva.version, '1.35.0');
      expect(nueva.bytes, 1234);
      expect(nueva.url.host, 'github.com');
    });

    test('sin APK —las de antes—, nada', () {
      expect(LaVersionNueva.deLaRelease(release(nombre: 'otro.apk')), isNull);
      expect(LaVersionNueva.deLaRelease({'assets': <Object>[]}), isNull);
      expect(LaVersionNueva.deLaRelease('no es json'), isNull);
    });

    test('una interna no le llega a nadie', () {
      expect(LaVersionNueva.deLaRelease(release(prerelease: true)), isNull);
    });

    test('solo por https', () {
      expect(
        LaVersionNueva.deLaRelease(release(url: 'http://x/a.apk')),
        isNull,
      );
    });

    test('más nueva por números, no por texto', () {
      expect(LaVersionNueva.esMasNueva('1.10.0', '1.9.0'), isTrue);
      expect(LaVersionNueva.esMasNueva('1.35.0', '1.34.2'), isTrue);
      expect(LaVersionNueva.esMasNueva('1.34.2', '1.34.2'), isFalse);
      expect(LaVersionNueva.esMasNueva('1.34.1', '1.34.2'), isFalse);
      expect(LaVersionNueva.esMasNueva('2.0.0', '1.99.99+7'), isTrue);
    });
  });

  group('en el teléfono', () {
    ({ProviderContainer c, _Releases r}) montar({
      String instalada = '1.34.2',
      bool permiso = true,
    }) {
      final r = _Releases(permiso: permiso);
      final c = ProviderContainer(
        overrides: [
          seBuscanActualizacionesProvider.overrideWithValue(true),
          lasReleasesDelTelefonoProvider.overrideWithValue(r),
          laVersionInstaladaProvider.overrideWith((ref) async => instalada),
        ],
      );
      addTearDown(c.dispose);
      return (c: c, r: r);
    }

    EstadoDeLaActualizacion estado(ProviderContainer c) =>
        c.read(laActualizacionDelTelefonoProvider);

    Future<void> arrancar(ProviderContainer c) async {
      c.read(laActualizacionDelTelefonoProvider);
      await pumpEventQueue();
    }

    test('si hay una más nueva, la ofrece', () async {
      final m = montar();
      await arrancar(m.c);
      expect(estado(m.c), isA<HayActualizacion>());
    });

    test('si ya la tiene, nada', () async {
      final m = montar(instalada: '1.35.0');
      await arrancar(m.c);
      expect(estado(m.c), isA<SinActualizacion>());
    });

    test('«luego» no la vuelve a ofrecer; una más nueva, sí', () async {
      final m = montar();
      await arrancar(m.c);
      m.c.read(laActualizacionDelTelefonoProvider.notifier).luego();
      await m.c.read(laActualizacionDelTelefonoProvider.notifier).mirar();
      expect(estado(m.c), isA<SinActualizacion>());

      m.r.version = '1.36.0';
      await m.c.read(laActualizacionDelTelefonoProvider.notifier).mirar();
      expect(estado(m.c), isA<HayActualizacion>());
    });

    test('baja, contando, y abre el instalador', () async {
      final m = montar();
      await arrancar(m.c);
      final vistos = <EstadoDeLaActualizacion>[];
      m.c.listen(laActualizacionDelTelefonoProvider, (_, e) => vistos.add(e));
      await m.c.read(laActualizacionDelTelefonoProvider.notifier).actualizar();

      expect(vistos.whereType<BajandoActualizacion>(), isNotEmpty);
      expect(m.r.instalados, ['/cache/Nexus-movil-1.35.0.apk']);
      expect(estado(m.c), isA<HayActualizacion>());
    });

    test('sin permiso lo pide, y al volver con él instala', () async {
      final m = montar(permiso: false);
      await arrancar(m.c);
      final control = m.c.read(laActualizacionDelTelefonoProvider.notifier);
      await control.actualizar();
      expect(estado(m.c), isA<FaltaElPermiso>());
      expect(m.r.permisosPedidos, 1);
      expect(m.r.instalados, isEmpty);

      m.r.permiso = true;
      await control.alVolver();
      expect(m.r.instalados, hasLength(1));
      expect(m.r.bajadas, 1, reason: 'no se vuelve a bajar');
    });

    test('al volver sin darlo, no insiste', () async {
      final m = montar(permiso: false);
      await arrancar(m.c);
      final control = m.c.read(laActualizacionDelTelefonoProvider.notifier);
      await control.actualizar();
      await control.alVolver();
      expect(estado(m.c), isA<FaltaElPermiso>());
      expect(m.r.permisosPedidos, 1);
    });

    test('si la bajada falla, se dice en la tarjeta', () async {
      final m = montar();
      m.r.falla = true;
      await arrancar(m.c);
      await m.c.read(laActualizacionDelTelefonoProvider.notifier).actualizar();
      expect((estado(m.c) as HayActualizacion).problema, contains('sin red'));
    });

    test('fuera de Android no mira', () async {
      final r = _Releases(permiso: true);
      final c = ProviderContainer(
        overrides: [
          seBuscanActualizacionesProvider.overrideWithValue(false),
          lasReleasesDelTelefonoProvider.overrideWithValue(r),
        ],
      );
      addTearDown(c.dispose);
      c.read(laActualizacionDelTelefonoProvider);
      await pumpEventQueue();
      expect(r.miradas, 0);
    });
  });

  testWidgets('la tarjeta: ofrece, y «luego» la quita', (tester) async {
    final r = _Releases(permiso: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          seBuscanActualizacionesProvider.overrideWithValue(true),
          lasReleasesDelTelefonoProvider.overrideWithValue(r),
          laVersionInstaladaProvider.overrideWith((ref) async => '1.34.2'),
        ],
        child: MaterialApp(
          theme: NexusTheme.dark(),
          builder: (context, child) =>
              StringsScope(strings: const NexusStringsEs(), child: child!),
          home: const Scaffold(body: AvisoDeActualizacionDelTelefono()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(AvisoDeActualizacionDelTelefono.laTarjeta), findsOne);
    expect(find.textContaining('1.35.0'), findsOne);

    await tester.tap(find.text('LUEGO'));
    await tester.pumpAndSettle();
    expect(find.byKey(AvisoDeActualizacionDelTelefono.laTarjeta), findsNothing);
  });
}

class _Releases implements LasReleasesDelTelefono {
  _Releases({required this.permiso});

  bool permiso;
  bool falla = false;
  String version = '1.35.0';
  int miradas = 0, bajadas = 0, permisosPedidos = 0;
  final instalados = <String>[];

  @override
  Future<LaVersionNueva?> laUltima() async {
    miradas++;
    return LaVersionNueva(
      version: version,
      url: Uri.https('github.com', '/a.apk'),
      bytes: 10,
    );
  }

  @override
  Future<String> bajar(
    LaVersionNueva nueva, {
    void Function(double? fraccion)? alAvanzar,
  }) async {
    bajadas++;
    if (falla) throw Exception('sin red');
    alAvanzar?.call(0.5);
    alAvanzar?.call(1);
    return '/cache/Nexus-movil-${nueva.version}.apk';
  }

  @override
  Future<bool> puedeInstalar() async => permiso;

  @override
  Future<void> pedirPermiso() async => permisosPedidos++;

  @override
  Future<String?> instalar(String apk) async {
    instalados.add(apk);
    return null;
  }
}
