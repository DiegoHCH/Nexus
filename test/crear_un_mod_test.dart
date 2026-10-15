import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/superpowers/data/datasources/mis_mods_data_source.dart';
import 'package:nexus/features/superpowers/presentation/providers/superpowers_providers.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Crear un mod: el catálogo se empareja con escritura solo para él, y con
/// Nexus en «solo leer» **se pregunta antes de subir el permiso**.
///
/// Lo que se protege es el permiso general: dar escritura a una carpeta lo
/// sube, y eso reabre la escritura de las carpetas que la tenían propia. No
/// puede pasar por pulsar un botón de otra cosa sin decirlo.
const _home = '/Users/alguien';

/// El espacio de trabajo, apuntando lo que se le pide.
class _Espacio extends WorkspaceController {
  _Espacio(this._inicial);

  final Workspace _inicial;
  final permisos = <({String ruta, bool puedeEditar})>[];
  final cuentas = <({String ruta, String? cuenta})>[];

  @override
  Workspace build() => _inicial;

  @override
  Future<String?> emparejar(String path) async {
    if (!state.folders.any((folder) => folder.path == path)) {
      state = Workspace(
        folders: [
          ...state.folders,
          PairedFolder(path: path, modality: FolderModality.textOnly),
        ],
        activePath: path,
        permission: state.permission,
      );
    }
    return path;
  }

  @override
  Future<void> setClaudeProfile(String path, String? profile) async =>
      cuentas.add((ruta: path, cuenta: profile));

  @override
  Future<void> setPermisoDeCarpeta(String path, bool puedeEditar) async =>
      permisos.add((ruta: path, puedeEditar: puedeEditar));
}

void main() {
  late Directory soporte;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    soporte = Directory.systemTemp.createTempSync('soporte');
  });
  tearDown(() => soporte.deleteSync(recursive: true));

  ProviderContainer montar(_Espacio espacio) {
    final c = ProviderContainer(
      overrides: [
        workspaceControllerProvider.overrideWith(() => espacio),
        misModsDataSourceProvider.overrideWithValue(
          MisModsDataSource(soporte: () async => soporte),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('con Nexus en «solo leer» se pregunta, y un no no toca nada', () async {
    final espacio = _Espacio(const Workspace());
    final c = montar(espacio);
    var preguntado = false;

    final quedo = await c.read(crearUnModProvider)(
      configDir: '$_home/.claude-private',
      queHace: 'avísame cuando falle un test',
      home: _home,
      puedeSubirElPermiso: () async {
        preguntado = true;
        return false;
      },
    );

    expect(quedo, ComoQuedoElMod.sinPermiso);
    expect(preguntado, isTrue);
    expect(espacio.permisos, isEmpty, reason: 'sin un sí, nada se sube');
    expect(
      Directory('${soporte.path}/mis-mods/.pedidos').existsSync(),
      isFalse,
      reason: 'ni se apunta un pedido que no va a ir a ninguna parte',
    );
  });

  test('el catálogo trabaja con la cuenta que se está mirando', () async {
    final espacio = _Espacio(const Workspace());
    final c = montar(espacio);

    await c.read(crearUnModProvider)(
      configDir: '$_home/.claude-private',
      queHace: 'x',
      home: _home,
      puedeSubirElPermiso: () async => false,
    );
    await c.read(crearUnModProvider)(
      configDir: '$_home/.claude',
      queHace: 'x',
      home: _home,
      puedeSubirElPermiso: () async => false,
    );

    expect(espacio.cuentas.map((c) => c.cuenta), [
      '$_home/.claude-private',
      null,
    ], reason: 'la de siempre es la carpeta sin cuenta elegida');
  });
}
