import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/workspace/data/datasources/claude_profiles_data_source.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';

void main() {
  // Claude Code guarda el token de cada perfil en el llavero con el nombre
  // `Claude Code-credentials-<sha256(directorio)[:8]>`. Comprobado contra el
  // llavero de esta máquina: `.claude` es 1a5cfcd2 y `.claude-work`, 5fd47d76.
  // Si esa fórmula cambia, todos los perfiles pasarían a verse «sin sesión».
  test('el servicio del llavero sale del directorio del perfil', () {
    expect(
      ClaudeProfilesDataSource.keychainService('/Users/diego.hoyos/.claude'),
      'Claude Code-credentials-1a5cfcd2',
    );
    expect(
      ClaudeProfilesDataSource.keychainService(
        '/Users/diego.hoyos/.claude-work',
      ),
      'Claude Code-credentials-5fd47d76',
    );
  });

  group('la cuenta va con la carpeta', () {
    test('se guarda y se vuelve a leer', () {
      const folder = PairedFolder(
        path: '/repo',
        modality: FolderModality.textOnly,
        claudeProfile: '/Users/alguien/.claude-work',
      );

      final leida = PairedFolder.fromJson(folder.toJson())!;

      expect(leida.claudeProfile, '/Users/alguien/.claude-work');
      expect(leida.modality, FolderModality.textOnly);
    });

    // Lo guardado antes de que esto existiera no trae el campo, y eso no puede
    // impedir leer la carpeta: se entiende como «la cuenta de siempre».
    test('una carpeta guardada sin cuenta usa la de siempre', () {
      final leida = PairedFolder.fromJson({
        'path': '/repo',
        'modality': 'voice',
      })!;

      expect(leida.claudeProfile, isNull);
      expect(leida.modality, FolderModality.voice);
    });

    // Modelo y esfuerzo viven donde la cuenta, y por lo mismo: un repo grande
    // pide Opus y una nota rápida se contesta con Haiku.
    test('el modelo y el esfuerzo también van con la carpeta', () {
      const folder = PairedFolder(
        path: '/repo',
        modality: FolderModality.voice,
        claudeModel: 'opus',
        claudeEffort: 'high',
      );

      final leida = PairedFolder.fromJson(folder.toJson())!;

      expect(leida.claudeModel, 'opus');
      expect(leida.claudeEffort, 'high');
    });

    test('una carpeta sin modelo deja decidir al CLI', () {
      final leida = PairedFolder.fromJson({
        'path': '/repo',
        'modality': 'voice',
      })!;

      expect(leida.claudeModel, isNull);
      expect(leida.claudeEffort, isNull);
    });

    test('cambiar de cuenta no toca el permiso de voz', () {
      const folder = PairedFolder(
        path: '/repo',
        modality: FolderModality.voice,
      );

      final cambiada = folder.copyWith(claudeProfile: '/x/.claude-private');

      expect(cambiada.modality, FolderModality.voice);
      expect(cambiada.claudeProfile, '/x/.claude-private');
    });
  });
  group('el nombre de la cuenta desde su ruta', () {
    // Existe como funcion pura porque quien arranca un encargo necesita el nombre en
    // ese mismo instante, y listar las cuentas del disco es asincrono.
    test('saca el nombre de un .claude-*', () {
      expect(ClaudeProfile.nameFromPath('/Users/alguien/.claude-work'), 'work');
    });

    test('la de siempre no es una cuenta', () {
      // `.claude` a secas significa «la por defecto», que es la opcion de arriba y no
      // una cuenta con nombre. Devolver algo aqui inventaria una subcarpeta.
      expect(ClaudeProfile.nameFromPath('/Users/alguien/.claude'), isNull);
      expect(ClaudeProfile.nameFromPath(null), isNull);
      expect(ClaudeProfile.nameFromPath(''), isNull);
    });

    test('una barra al final no lo despista', () {
      expect(
        ClaudeProfile.nameFromPath('/Users/alguien/.claude-private/'),
        'private',
      );
    });
  });

  // 🔴 El modelo y el esfuerzo son del perfil: Nexus y la consola leen el mismo
  // `settings.json`, así que cambiarlos en uno los cambia en el otro.
  group('el modelo y el esfuerzo del perfil', () {
    late Directory perfil;
    File settings() => File('${perfil.path}/settings.json');
    Map<String, dynamic> leido() =>
        jsonDecode(settings().readAsStringSync()) as Map<String, dynamic>;
    const fuente = ClaudeProfilesDataSource();

    setUp(() => perfil = Directory.systemTemp.createTempSync('perfil-'));
    tearDown(() => perfil.deleteSync(recursive: true));

    // Es lo que escribe `/effort` hoy, copiado de un perfil de verdad.
    test(
      'lee el esfuerzo por modelo, que es donde lo guarda /effort',
      () async {
        settings().writeAsStringSync(
          jsonEncode({
            'model': 'opus',
            'effortLevel': 'medium',
            'modelSettings': {
              'claude-opus-5-5': {'effortLevel': 'high'},
            },
          }),
        );

        final leidos = await fuente.defaults(perfil.path);

        expect(leidos.model, 'opus');
        expect(leidos.esfuerzoPara('claude-opus-5-5'), 'high');
        expect(
          leidos.esfuerzoPara('claude-opus-5-5[1m]'),
          'high',
          reason: 'el corchete dice la ventana, no el modelo',
        );
        expect(
          leidos.esfuerzoPara('claude-sonnet-5'),
          'medium',
          reason: 'sin el suyo, vale el general',
        );
      },
    );

    test('cambiar el modelo no toca nada más del archivo', () async {
      settings().writeAsStringSync(
        jsonEncode({
          'model': 'opus',
          'permissions': {
            'allow': ['Bash(git status)'],
          },
          'enabledPlugins': {'figma@claude-plugins-official': true},
        }),
      );

      await fuente.guardarModelo(perfil.path, 'sonnet');

      final ahora = leido();
      expect(ahora['model'], 'sonnet');
      expect(ahora['permissions'], {
        'allow': ['Bash(git status)'],
      });
      expect(ahora['enabledPlugins'], {'figma@claude-plugins-official': true});
    });

    // Es el «Default (recommended)» del `/model` del CLI.
    test('por defecto quita la clave, y el resto sigue', () async {
      settings().writeAsStringSync(
        jsonEncode({'model': 'claude-opus-5', 'effortLevel': 'high'}),
      );

      await fuente.guardarModelo(perfil.path, null);

      expect(leido().containsKey('model'), isFalse);
      expect(leido()['effortLevel'], 'high');
    });

    test(
      'el esfuerzo se guarda bajo el modelo en uso, sin pisar otros',
      () async {
        settings().writeAsStringSync(
          jsonEncode({
            'modelSettings': {
              'claude-sonnet-5': {
                'effortLevel': 'low',
                'maxEffortLevel': 'high',
              },
            },
          }),
        );

        await fuente.guardarEsfuerzo(
          perfil.path,
          'xhigh',
          modelo: 'claude-opus-5-5',
        );
        await fuente.guardarEsfuerzo(
          perfil.path,
          'medium',
          modelo: 'claude-sonnet-5',
        );

        final modelos = leido()['modelSettings'] as Map<String, dynamic>;
        expect(modelos['claude-opus-5-5'], {'effortLevel': 'xhigh'});
        expect(modelos['claude-sonnet-5'], {
          'effortLevel': 'medium',
          'maxEffortLevel': 'high',
        });
      },
    );

    test('sin saber el modelo, se guarda el general', () async {
      await fuente.guardarEsfuerzo(perfil.path, 'high');
      expect(leido()['effortLevel'], 'high');
    });

    // Ese archivo lleva permisos, hooks y plugins: reescribirlo desde cero
    // porque hoy no se pudo leer los borraría.
    test('un settings.json que no se entiende no se reescribe', () async {
      settings().writeAsStringSync('{ esto no es json');

      await expectLater(
        fuente.guardarModelo(perfil.path, 'sonnet'),
        throwsStateError,
      );
      expect(settings().readAsStringSync(), '{ esto no es json');
    });

    test('la fecha y el corchete no son parte del nombre', () {
      expect(
        PerfilDeClaude.nombreCanonico('claude-haiku-4-5-20251001'),
        'claude-haiku-4-5',
      );
      expect(
        PerfilDeClaude.nombreCanonico('claude-opus-5[1m]'),
        'claude-opus-5',
      );
      expect(
        PerfilDeClaude.nombreCanonico('claude-opus-5-5'),
        'claude-opus-5-5',
      );
    });
  });
}
