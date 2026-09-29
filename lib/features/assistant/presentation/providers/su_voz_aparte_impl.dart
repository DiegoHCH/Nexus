import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/i18n/language_preference.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/assistant/domain/usecases/el_ritmo_del_progreso.dart';
import 'package:nexus/features/assistant/domain/usecases/el_verbo_de_un_paso.dart';
import 'package:nexus/features/assistant/presentation/providers/lo_contesta_ella.dart';
import 'package:nexus/features/personalidad/domain/la_personalidad.dart';
import 'package:nexus/features/personalidad/presentation/providers/la_personalidad_provider.dart';
import 'package:nexus/features/assistant/data/datasources/gemini_text_data_source.dart';
import 'package:nexus/features/agenda/presentation/providers/el_vigilante_de_la_agenda.dart';
import 'package:nexus/features/assistant/data/datasources/las_frases_hechas_data_source.dart';
import 'package:nexus/features/assistant/domain/repositories/su_voz_aparte.dart';
import 'package:nexus/features/assistant/presentation/providers/voice_preference_providers.dart';
import 'package:nexus/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

final lasFrasesHechasDataSourceProvider = Provider<LasFrasesHechasDataSource>(
  (ref) => const LasFrasesHechasDataSource(),
);

/// Su voz fuera del turno del modelo, cableada: las frases guardadas, y el
/// servicio de voz para decir al vuelo lo que no lo está. Ver [SuVozAparte].
///
/// ## Qué se guarda y cuándo
///
/// Los acuses de [ConversacionFluidaStrings.acuses] y el saludo al llamarla,
/// **dichos por la misma sesión de aviso que los avisos hablados** —el mismo
/// timbre del `setup`, el mismo acento en la instrucción—, así que suenan con
/// su voz de ahora y no con una de fábrica. Se generan una vez y se guardan
/// por firma —ver [LasFrasesHechasDataSource]—: cambiar la voz, el idioma o
/// cómo te llama cambia la firma, y se vuelven a generar solas.
///
/// Se preparan **al arrancar**, un rato después y de fondo, y otra vez al
/// cambiar cualquiera de esas tres cosas. No al llamarla: lo que se quiere es
/// que en ese momento ya estén.
class LasFrasesHechas implements SuVozAparte {
  LasFrasesHechas(this._ref, {Random? azar}) : _azar = azar ?? Random();

  final Ref _ref;
  final Random _azar;

  /// Lo guardado de la firma de ahora, en memoria: el acuse se pide y tiene
  /// que sonar **ya**, sin disco de por medio. Son unos pocos segundos de
  /// audio, menos de un megabyte.
  final _hechas = <String, Uint8List>{};
  String? _firmaCargada;

  /// La última que dijo, para no repetirla dos encargos seguidos.
  String? _ultima;

  Future<void>? _preparando;

  String get _firma => LasFrasesHechasDataSource.firma(
    voz: _ref.read(voicePreferenceProvider).name,
    idioma: _ref
        .read(elAcentoProvider)
        .conElIdioma(_ref.read(stringsProvider).languageName),
    tuyo: _ref.read(losNombresProvider).tuyo,
  );

  List<String> get _acuses =>
      _ref.read(stringsProvider).acuses(_ref.read(losNombresProvider).tuyo);

  String get _saludo =>
      _ref.read(stringsProvider).alLlamarla(_ref.read(losNombresProvider).tuyo);

  /// Las de ahora, si lo guardado es de la firma de ahora.
  Map<String, Uint8List> get _vigentes =>
      _firmaCargada == _firma ? _hechas : const {};

  @override
  FraseHecha? unAcuse() {
    final todas = _acuses;
    if (todas.isEmpty) return null;
    final vigentes = _vigentes;
    final hechas = [
      for (final t in todas)
        if (vigentes.containsKey(t)) t,
    ];
    // Sin ninguna hecha todavía —la primera vez, o recién cambiada la voz— se
    // dice al vuelo, y de paso se preparan para la próxima.
    if (hechas.isEmpty) unawaited(preparar());
    final entre = hechas.isEmpty ? todas : hechas;
    final sinRepetir = entre.length > 1
        ? [
            for (final t in entre)
              if (t != _ultima) t,
          ]
        : entre;
    final texto = sinRepetir[_azar.nextInt(sinRepetir.length)];
    _ultima = texto;
    return FraseHecha(texto, vigentes[texto]);
  }

  @override
  FraseHecha? elSaludo(String frase) {
    final pcm = _vigentes[frase];
    if (pcm == null) {
      unawaited(preparar());
      return null;
    }
    return FraseHecha(frase, pcm);
  }

  /// Por dónde va: la redacta el modelo de texto rápido y, si no contesta a
  /// tiempo, sale de plantilla.
  ///
  /// 🔴 **Las dos, y en ese orden, porque es lo más rápido que además no
  /// falla.** Una plantilla sale al instante pero suena a máquina —«sigo con
  /// ello: estoy leyendo pubspec»— y no sabe **para qué** es el paso; el modelo
  /// junta los pasos con lo que Claude va contando y dice «ya tengo Jira
  /// abierto; estoy comparando las tareas», que es lo que se pidió (29 sep).
  /// Tarda un segundo largo, y con un tope de tres —un intento, sin reintento:
  /// ver [GeminiTextDataSource.redactar]—, lo peor que puede pasar es que
  /// salga la plantilla. La frase se dice al vuelo después, así que esto no
  /// va con prisa de acuse: va con prisa de «antes de que sea vieja».
  @override
  Future<String?> porDondeVa(LoQueLlevaHecho hecho) async {
    if (hecho.pasos.isEmpty) return null;
    final strings = _ref.read(stringsProvider);
    final plantilla = deplantilla(strings, hecho);
    try {
      final llave = await _ref.read(geminiKeyStoreProvider).read();
      if (llave == null || llave.isEmpty || !_ref.mounted) return plantilla;
      final nombres = _ref.read(losNombresProvider);
      final redactada = await _ref
          .read(geminiTextDataSourceProvider)
          .redactar(
            llave: llave,
            peticion: laPeticion(
              hecho,
              agente: nombres.agente,
              tuyo: nombres.tuyo,
              idioma: _ref
                  .read(elAcentoProvider)
                  .conElIdioma(strings.languageName),
              personalidad: _ref.read(laPersonalidadProvider),
            ),
          );
      return comoSeDice(redactada) ?? plantilla;
    } on Object catch (error) {
      debugPrint('voz · por dónde va sin redactar: $error');
      return plantilla;
    }
  }

  /// Lo que se le pide al modelo de texto. **Material para un modelo**, como
  /// la instrucción de la voz: va en español y dice en qué idioma contestar.
  @visibleForTesting
  static String laPeticion(
    LoQueLlevaHecho hecho, {
    required String? agente,
    required String? tuyo,
    required String idioma,
    required String? personalidad,
  }) =>
      'Eres ${agente ?? 'Nexus'}, una asistente de voz. '
      '${LaPersonalidad.paraElPrompt(personalidad)}\n'
      'Estás haciendo un encargo para ${tuyo ?? 'quien te habla'} y llevas un '
      'rato en silencio. Dile por dónde vas en UNA frase hablada, de doce '
      'palabras como mucho, en $idioma, en primera persona y en presente '
      '—por ejemplo: «Ya tengo Jira abierto; estoy comparando las tareas»—.\n'
      'Di de qué se trata, no lo literal: nada de rutas, comandos, nombres de '
      'herramientas ni archivos con su extensión. Sin saludar, sin preguntar, '
      'sin prometer cuánto falta y sin decir quién hace el trabajo.\n'
      '${hecho.yaDicho.isEmpty ? '' : 'Ya dijiste esto, no lo repitas: ${hecho.yaDicho.map((d) => '«$d»').join(', ')}.\n'}'
      'Los pasos reales, del más viejo al más nuevo:\n'
      '${hecho.pasos.map((p) => '- $p').join('\n')}\n'
      '${hecho.loQueCuenta.trim().isEmpty ? '' : 'Lo último que has escrito mientras trabajabas: «${hecho.loQueCuenta.trim()}»\n'}'
      'Contesta solo con la frase.';

  /// Lo redactado, listo para decirse: una línea, sin comillas, y corta. Si
  /// se fue de largo, no vale —se dice la plantilla—: una frase de por dónde
  /// va que dura diez segundos ya no es una frase.
  @visibleForTesting
  static String? comoSeDice(String? redactada) {
    final linea = redactada
        ?.split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');
    if (linea == null || linea.isEmpty) return null;
    final limpia = linea.replaceAll(RegExp('^[«"“]+|[»"”]+\$'), '').trim();
    if (limpia.isEmpty || limpia.split(RegExp(r'\s+')).length > 20) return null;
    return limpia;
  }

  /// La de plantilla, con el último paso dicho en voz alta.
  @visibleForTesting
  static String deplantilla(NexusStrings strings, LoQueLlevaHecho hecho) {
    final (:verbo, :objeto) = ElPasoEnVozAlta.de(hecho.pasos.last);
    if (objeto.isEmpty) return strings.progresoSigo;
    return switch (verbo) {
      VerboDelPaso.lee => strings.progresoLee(objeto),
      VerboDelPaso.escribe ||
      VerboDelPaso.edita => strings.progresoEdita(objeto),
      VerboDelPaso.ejecuta => strings.progresoEjecuta(objeto),
      VerboDelPaso.busca => strings.progresoBusca(objeto),
      VerboDelPaso.delega => strings.progresoDelega(objeto),
      VerboDelPaso.consulta => strings.progresoConsulta(objeto),
      VerboDelPaso.otro => strings.progresoUsa(objeto),
    };
  }

  @override
  Stream<Uint8List> decir(String frase) {
    late final StreamController<Uint8List> fuera;
    fuera = StreamController<Uint8List>(
      onListen: () async {
        final dicho = await _ref
            .read(laVozDelAvisoProvider)
            .decir(
              frase,
              alLlegar: (trozo) {
                if (!fuera.isClosed) fuera.add(trozo);
              },
            );
        if (!dicho.salio) {
          debugPrint('voz · aparte no salió: ${dicho.problema}');
        }
        if (!fuera.isClosed) await fuera.close();
      },
    );
    return fuera.stream;
  }

  /// Carga lo guardado y genera lo que falte. Una sola a la vez: si ya se está
  /// preparando, se espera a esa.
  Future<void> preparar() =>
      _preparando ??= _preparar().whenComplete(() => _preparando = null);

  Future<void> _preparar() async {
    try {
      await Future.wait([
        _ref.read(voicePreferenceProvider.notifier).leida,
        _ref.read(elAcentoProvider.notifier).leido,
        _ref.read(losNombresProvider.notifier).leidos,
      ]);
      if (!_ref.mounted) return;
      final firma = _firma;
      final textos = [..._acuses, _saludo];
      final disco = _ref.read(lasFrasesHechasDataSourceProvider);
      if (_firmaCargada != firma) {
        _hechas
          ..clear()
          ..addAll(await disco.leer(firma, textos));
        _firmaCargada = firma;
        await disco.olvidarLasDemas(firma);
      }
      final faltan = [
        for (final t in textos)
          if (!_hechas.containsKey(t)) t,
      ];
      if (faltan.isEmpty) return;
      // Sin llave no hay con qué decirlas: ni se intenta, ni se reintenta en
      // bucle. Se vuelve a probar en la próxima preparación.
      final llave = await _ref.read(geminiKeyStoreProvider).read();
      if (llave == null || llave.isEmpty || !_ref.mounted) return;
      debugPrint('frases hechas · faltan ${faltan.length}, se generan');
      final voz = _ref.read(laVozDelAvisoProvider);
      for (final texto in faltan) {
        final dicho = await voz.decir(texto);
        if (!_ref.mounted || _firma != firma) return;
        final pcm = dicho.pcm;
        if (pcm == null) {
          debugPrint('frases hechas · «$texto» no salió: ${dicho.problema}');
          continue;
        }
        _hechas[texto] = pcm;
        await disco.guardar(firma, texto, pcm);
      }
      debugPrint(
        'frases hechas · listas ${_hechas.length} de ${textos.length}',
      );
    } on Object catch (error) {
      // 🔴 **Preparar no puede tumbar nada.** Aquí se toca el llavero, el disco
      // y la red; sin frases guardadas el acuse se dice al vuelo, que es más
      // lento pero sigue siendo un acuse.
      debugPrint('frases hechas · no se pudieron preparar: $error');
    }
  }
}

/// El que se usa en la app. Se arma al arrancar —ver `main.dart`— y se vuelve
/// a preparar solo al cambiar lo que suena.
final suVozAparteProvider = Provider<LasFrasesHechas>((ref) {
  final frases = LasFrasesHechas(ref);
  void otraVez() => unawaited(frases.preparar());
  ref.listen(voicePreferenceProvider, (_, _) => otraVez());
  ref.listen(elAcentoProvider, (_, _) => otraVez());
  ref.listen(stringsProvider, (_, _) => otraVez());
  ref.listen(losNombresProvider.select((n) => n.tuyo), (_, _) => otraVez());
  return frases;
});

/// La preparación del arranque, **un rato después**: lo primero que hace la
/// app al abrirse —leer conversaciones, la agenda, el oído— no tiene que
/// competir con seis sesiones de voz de fondo.
final lasFrasesHechasAlArrancarProvider = Provider<void>((ref) {
  final espera = Timer(const Duration(seconds: 8), () {
    unawaited(ref.read(suVozAparteProvider).preparar());
  });
  ref.onDispose(espera.cancel);
});
