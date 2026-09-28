import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/i18n/language_preference.dart';
import 'package:nexus/features/assistant/data/datasources/gemini_text_data_source.dart';
import 'package:nexus/features/assistant/data/repositories/gemini_voice_gateway.dart';
import 'package:nexus/features/assistant/presentation/providers/voice_preference_providers.dart';
import 'package:nexus/features/memoria/domain/entities/lo_que_se_sabe_de_ti.dart';
import 'package:nexus/features/memoria/presentation/providers/lo_que_recuerda_de_ti.dart';
import 'package:nexus/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:nexus/features/personalidad/presentation/providers/la_personalidad_provider.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

final geminiTextDataSourceProvider = Provider<GeminiTextDataSource>(
  (ref) => const GeminiTextDataSource(),
);

/// Contesta ella, por escrito, lo que es suyo: ver [AElla].
///
/// **Con las mismas instrucciones que la voz**, sacadas del mismo sitio
/// —[GeminiVoiceGateway.instruccionDelSistema]—: quién es, su personalidad,
/// los nombres, lo que sabe de ti y la hora. Preguntárselo hablando y
/// escribiendo tiene que dar la misma respuesta.
///
/// `null` si no puede —sin llave de Gemini, sin red, un fallo del servicio—, y
/// entonces quien llama lo manda a Claude como antes: mejor gastar un encargo
/// que no contestar.
final loContestaEllaProvider = Provider<Future<String?> Function(String frase)>(
  (ref) => (frase) async {
    await ref.read(losNombresProvider.notifier).leidos;
    await ref.read(laPersonalidadProvider.notifier).leida;
    final llave = await ref.read(geminiKeyStoreProvider).read();
    if (llave == null || llave.isEmpty) return null;
    final nombres = ref.read(losNombresProvider).paraElPrompt();
    return ref
        .read(geminiTextDataSourceProvider)
        .contestar(
          llave: llave,
          frase: frase,
          instrucciones: GeminiVoiceGateway.instruccionDelSistema(
            agente: ref.read(losNombresProvider).agente,
            idioma: ref
                .read(elAcentoProvider)
                .conElIdioma(ref.read(stringsProvider).languageName),
            nombres: nombres == null ? '' : '$nombres\n',
            loQueSeSabeDeTi: LoQueSeSabeDeTi.paraElPrompt(
              ref.read(loQueRecuerdaDeTiProvider),
            ),
            ahora: DateTime.now(),
            personalidad: ref.read(laPersonalidadProvider),
          ),
        );
  },
);
