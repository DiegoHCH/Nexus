import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/i18n/language_preference.dart';
import 'package:nexus/features/agenda/data/datasources/agenda_data_source.dart';
import 'package:nexus/features/agenda/domain/entities/reunion.dart';
import 'package:nexus/features/agenda/presentation/providers/el_vigilante_de_la_agenda.dart';
import 'package:nexus/features/assistant/data/datasources/claude_usage_data_source.dart';
import 'package:nexus/features/assistant/presentation/providers/model_providers.dart';
import 'package:nexus/features/lo_que_te_espera/presentation/providers/lo_que_te_espera_provider.dart';
import 'package:nexus/features/prs/data/datasources/los_pr_data_source.dart';
import 'package:nexus/features/prs/domain/entities/pr_por_revisar.dart';
import 'package:nexus/features/prs/presentation/providers/el_vigilante_de_los_pr.dart';
import 'package:nexus/features/workspace/domain/entities/los_nombres.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/domain/entities/workspace.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lo que te espera hoy, contado al llamarla: una vez al día y nada más.
///
/// Lo que se protege es lo que se rompe sin que nadie se entere: que se
/// repita en cada llamada —y entonces se deja de llamarla—, o que se gaste el
/// día contándolo sin las reuniones.
const carpeta = '/Users/alguien/repo';

class _Workspace extends WorkspaceController {
  @override
  Workspace build() => const Workspace(
    folders: [PairedFolder(path: carpeta, modality: FolderModality.voice)],
    activePath: carpeta,
  );
}

class _Nombres extends LosNombresController {
  @override
  LosNombres build() => const LosNombres(tuyo: 'Diego');
}

class _Calendario extends AgendaDataSource {
  @override
  Future<List<Reunion>> delDia(
    DateTime dia, {
    required String carpeta,
    String? configDir,
  }) async => [
    Reunion(
      id: 'g',
      titulo: 'Growth',
      comienza: DateTime(2026, 10, 12, 14),
      invitados: 3,
    ),
  ];
}

class _Gh extends LosPrDataSource {
  const _Gh();

  @override
  Future<List<PrPorRevisar>?> porRevisar() async => const [
    PrPorRevisar(repo: 'org/app', numero: 1, titulo: 'Fix login', autor: 'a'),
  ];
}

void main() {
  // Lunes 12 de octubre de 2026, a las nueve.
  final lunes = DateTime(2026, 10, 12, 9);

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({
      'avisos_agenda_encendidos': true,
      'avisos_agenda_minutos': 5,
      'avisos_agenda_carpeta': carpeta,
    });
  });

  ProviderContainer montar({DateTime? cuando}) {
    final container = ProviderContainer(
      overrides: [
        relojProvider.overrideWithValue(() => cuando ?? lunes),
        agendaDataSourceProvider.overrideWithValue(_Calendario()),
        workspaceControllerProvider.overrideWith(_Workspace.new),
        losNombresProvider.overrideWith(_Nombres.new),
        losPrDataSourceProvider.overrideWithValue(const _Gh()),
        claudeUsageProvider.overrideWith(
          (ref, configDir) async => (
            usage: const ClaudeUsage(
              account: 'work',
              fiveHourPercent: 10,
              weeklyPercent: 42,
            ),
            state: UsageState.ok,
          ),
        ),
        localeProvider.overrideWithValue(const Locale('es')),
      ],
    );
    addTearDown(container.dispose);
    // El vigilante carga sus ajustes del disco al nacer.
    container.read(elVigilanteDeLaAgendaProvider);
    return container;
  }

  Future<String?> llamarla(ProviderContainer container) async {
    await Future<void>.delayed(Duration.zero);
    return container
        .read(elDiaQueTeEsperaProvider)
        .alLlamarlaHoy(configDir: null);
  }

  test('la primera llamada del día lo cuenta, con saludo y pregunta', () async {
    final dicho = await llamarla(montar());

    expect(dicho, startsWith('Buenos días, Diego.'));
    expect(dicho, contains('Te queda una reunión: Growth, a las 14:00.'));
    expect(dicho, contains('Un PR espera tu revisión: Fix login.'));
    expect(dicho, contains('Llevas el 42 % del cupo de la semana.'));
    expect(dicho, endsWith('¿Por dónde empezamos?'));
  });

  test('la segunda del mismo día ya no: contesta como siempre', () async {
    final container = montar();

    await llamarla(container);
    final segunda = await llamarla(container);

    expect(segunda, isNull);
  });

  test('con el ajuste apagado no lo cuenta nunca', () async {
    SharedPreferences.setMockInitialValues({
      ElDiaQueTeEspera.alLlamarla: false,
    });

    expect(await llamarla(montar()), isNull);
  });

  test('el sábado no hay jornada que contar', () async {
    final dicho = await llamarla(montar(cuando: DateTime(2026, 10, 10, 10)));

    expect(dicho, isNull);
  });

  test('pedirlo da lo mismo, sin saludo y aunque ya se haya dicho', () async {
    final container = montar();
    await llamarla(container);

    final pedido = await container
        .read(elDiaQueTeEsperaProvider)
        .deHoy(configDir: null);

    expect(pedido, startsWith('Te queda una reunión: Growth'));
    expect(pedido, isNot(contains('Buenos días')));
  });
}
