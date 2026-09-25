import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/i18n/language_preference.dart';
import 'package:nexus/features/agenda/data/datasources/agenda_data_source.dart';
import 'package:nexus/features/agenda/data/datasources/avisos_preferencias_data_source.dart';
import 'package:nexus/features/agenda/domain/usecases/la_voz_del_aviso.dart';
import 'package:nexus/features/assistant/presentation/providers/voice_session_providers.dart';
import 'package:nexus/features/avisos/presentation/providers/la_voz_que_avisa.dart';
import 'package:nexus/features/agenda/domain/entities/reunion.dart';
import 'package:nexus/features/agenda/domain/usecases/la_lectura_que_toca.dart';
import 'package:nexus/features/agenda/domain/usecases/lo_que_se_contesta_de_la_agenda.dart';
import 'package:nexus/features/agenda/domain/usecases/lo_que_toca_avisar.dart';
import 'package:nexus/features/assistant/domain/repositories/la_agenda_de_hoy.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

/// Cómo están los avisos de agenda.
@immutable
class Avisos {
  const Avisos({
    this.encendidos = false,
    this.minutos = 5,
    this.carpeta,
    this.cargado = false,
    this.ultimaLectura,
  });

  final bool encendidos;
  final int minutos;

  /// La carpeta emparejada cuya cuenta de Claude se usa para mirar el
  /// calendario. El conector vive en la cuenta, y en Nexus la cuenta la decide
  /// la carpeta.
  final String? carpeta;

  final bool cargado;

  /// Cuándo se leyó el calendario por última vez, para poder enseñarlo.
  ///
  /// Se enseña porque **la agenda en memoria envejece sin avisar**: si programas
  /// algo a media mañana, lo que hay guardado no lo sabe. Ver la hora de la
  /// lectura es lo que convierte eso en algo que puedes corregir en vez de en
  /// una ausencia silenciosa.
  final DateTime? ultimaLectura;

  bool get listos => encendidos && (carpeta?.isNotEmpty ?? false);

  Avisos copyWith({
    bool? encendidos,
    int? minutos,
    Object? carpeta = _nada,
    Object? ultimaLectura = _nada,
  }) => Avisos(
    encendidos: encendidos ?? this.encendidos,
    minutos: minutos ?? this.minutos,
    carpeta: carpeta == _nada ? this.carpeta : carpeta as String?,
    cargado: true,
    ultimaLectura: ultimaLectura == _nada
        ? this.ultimaLectura
        : ultimaLectura as DateTime?,
  );

  static const _nada = Object();
}

/// Lo único de Nexus que ocurre sin que se lo pidas.
///
/// 🔴 Y por eso nace **apagado**. Toda la app está construida sobre que el
/// trabajo lo disparas tú; una que empieza a hablarte sola el día que se
/// actualiza asusta, aunque lo que diga sea útil.
///
/// El reloj es local y la agenda se lee **una vez al día**: preguntar cada
/// pocos minutos serían casi trescientos `claude -p` diarios gastando tokens de
/// tu suscripción para releer lo mismo.
class ElVigilanteDeLaAgenda extends Notifier<Avisos> {
  Timer? _reloj;

  /// El ancla de la última lectura, no la hora en que ocurrió.
  ///
  /// 🔴 **Se lee al arrancar y otra vez al pasar por las ocho**, y no solo una
  /// vez al día. Anclarlo únicamente a las ocho dejaría sin avisos a quien abre
  /// la app a las siete; leer solo al arrancar deja fuera todo lo que se
  /// programe después. Con las dos, son como mucho dos consultas diarias y la
  /// mañana entra completa.
  ///
  /// Lo que ninguna de las dos arregla es lo que se programa a media mañana:
  /// para eso está [releer], que se pide a mano.
  DateTime? _leidoDesde;
  List<Reunion> _agenda = const [];

  /// Las reuniones leídas de hoy, para quien las quiera enseñar —el escenario
  /// dormido dice la próxima—. Se lee junto a este provider: el estado cambia
  /// cada vez que se relee la agenda.
  List<Reunion> get agenda => _agenda;
  final _yaAvisadas = <String>{};

  /// La hora, por el proveedor y no por `DateTime.now()` directo.
  ///
  /// 🔴 **Sin esto las pruebas de este archivo solo pasarían entre semana y
  /// antes de las seis.** Media decisión de aquí cuelga de la jornada —fuera de
  /// ella la agenda se borra— así que una suite anclada al reloj de la máquina
  /// se pondría roja sola cada sábado, y en CI, que corre a cualquier hora.
  DateTime _ahora() => ref.read(relojProvider)();

  /// Cada cuánto se mira el reloj. Treinta segundos: con la ventana de cinco
  /// minutos, es imposible que una reunión entre y salga sin que se vea.
  static const _cadencia = Duration(seconds: 30);

  /// Cuánto se espera a que una sesión de voz calle antes de rendirse y dejarlo
  /// en notificación.
  static const esperaMaxima = Duration(seconds: 60);

  @override
  Avisos build() {
    ref.onDispose(() => _reloj?.cancel());
    unawaited(_cargar());
    return const Avisos();
  }

  Future<void> _cargar() async {
    final guardado = await ref.read(avisosPreferenciasProvider).leer();
    if (!ref.mounted) return;
    state = Avisos(
      encendidos: guardado.encendidos,
      minutos: guardado.minutos,
      carpeta: guardado.carpeta,
      cargado: true,
    );
    _arrancarOParar();
  }

  Future<void> cambiar({
    bool? encendidos,
    int? minutos,
    Object? carpeta,
  }) async {
    state = state.copyWith(
      encendidos: encendidos,
      minutos: minutos,
      carpeta: carpeta ?? Avisos._nada,
    );
    await ref
        .read(avisosPreferenciasProvider)
        .escribir(
          encendidos: state.encendidos,
          minutos: state.minutos,
          carpeta: state.carpeta,
        );
    // La agenda de la cuenta anterior ya no vale.
    if (carpeta != null) {
      _olvidarLaAgenda();
    }
    _arrancarOParar();
  }

  void _arrancarOParar() {
    _reloj?.cancel();
    if (!state.listos) return;
    _reloj = Timer.periodic(_cadencia, (_) => unawaited(_mirar()));
    unawaited(_mirar());
  }

  Future<void> _mirar() async {
    if (!state.listos || ref.read(laVozQueAvisaProvider).hablando) return;
    final ahora = _ahora();
    await _leerSiHaceFalta(ahora);
    if (!ref.mounted) return;

    final tocan = LoQueTocaAvisar.ahora(
      _agenda,
      cuando: ahora,
      antes: Duration(minutes: state.minutos),
      yaAvisadas: _yaAvisadas,
    );
    if (tocan.isEmpty) return;

    // Una cada vez. Dos reuniones a la misma hora son dos avisos seguidos, no
    // dos voces encima.
    final reunion = tocan.first;
    _yaAvisadas.add(reunion.id);
    await _avisar(reunion, ahora);
  }

  /// Vuelve a preguntarle al calendario ahora mismo.
  ///
  /// Existe porque la agenda en memoria **no se entera de lo que se programe
  /// después**: una reunión puesta a media mañana no está en lo que se leyó al
  /// arrancar. Se pide a mano en vez de sondear cada pocos minutos, que serían
  /// casi trescientas consultas diarias para releer lo mismo.
  Future<void> releer() async {
    _olvidarLaAgenda();
    await _leerSiHaceFalta(_ahora());
  }

  /// Lo que hay hoy, sin salir a preguntarlo otra vez.
  ///
  /// La agenda ya está leída —hizo falta para poder avisar— así que contestar
  /// es mirar en memoria. `null` si no hay nada que mirar: con los avisos
  /// apagados o sin carpeta no hay agenda, y entonces quien pregunta sigue por
  /// el camino largo en vez de recibir un «no tengo» que sería mentira.
  ///
  /// 🔴 **«Sin salir a preguntarlo otra vez» no es «al momento».** Pasa por
  /// `_leerSiHaceFalta`, y si la lectura del día no está hecha o va en vuelo,
  /// esto la espera: son los 32 s del `claude -p` del arranque. Ahí es donde se
  /// quedó muda la voz preguntando la agenda a los 34 s de abrir la app.
  Future<String?> loDeHoy() async {
    if (!state.listos) return null;
    final ahora = _ahora();
    await _leerSiHaceFalta(ahora);
    if (!ref.mounted) return null;

    final s = ref.read(stringsProvider);
    return LoQueSeContestaDeLaAgenda.respuesta(
      _agenda,
      cuando: ahora,
      fueraDeJornada: s.agendaFueraDeJornada,
      vacia: s.agendaVacia,
      cabecera: s.agendaDeHoy,
    );
  }

  /// Suelta un aviso de mentira, ahora mismo.
  ///
  /// 🔴 **Existe porque esto no se puede probar de otra forma.** Un aviso
  /// depende de que tengas una reunión dentro de cinco minutos, así que sin
  /// esto la única manera de saber si funciona —o de oír a qué volumen suena, o
  /// de descubrir que falta la llave— es esperar a que te pase de verdad. Y el
  /// día que te pase de verdad es justo el día en que no quieres descubrir que
  /// no funcionaba.
  ///
  /// Recorre el mismo camino que uno real: la misma llave, la misma voz, los
  /// mismos dos altavoces y la misma espera si estás hablando. Lo único que se
  /// salta es el calendario.
  Future<void> probar() {
    final ahora = _ahora();
    return _avisar(
      Reunion(
        id: 'prueba-${ahora.microsecondsSinceEpoch}',
        titulo: ref.read(stringsProvider).avisoDePrueba,
        comienza: ahora.add(Duration(minutes: state.minutos)),
        invitados: 1,
      ),
      ahora,
    );
  }

  void _olvidarLaAgenda() {
    _leidoDesde = null;
    _agenda = const [];
    _yaAvisadas.clear();
  }

  /// Una sola lectura en vuelo, y quien llegue en medio **espera a esa**.
  ///
  /// 🔴 Sin esto se leía el calendario dos veces por arranque, medido: el reloj
  /// tira cada treinta segundos, la lectura tarda entre veintiséis y cuarenta, y
  /// el tic siguiente entraba mientras el primero todavía esperaba —el ancla se
  /// marca **después** del `await`, así que el segundo la veía sin marcar y
  /// arrancaba su propia consulta—. Dos `claude -p` por arranque, o sea el doble
  /// de cupo de la suscripción para leer la misma agenda.
  ///
  /// Se guarda el futuro en vez de un `bool` porque hay dos clases de llamante y
  /// necesitan cosas distintas. Al reloj le basta con no duplicar. Pero
  /// [loDeHoy] **usa el resultado**: con una bandera que solo saltara la
  /// lectura, preguntar «¿qué reuniones tengo hoy?» durante la lectura del
  /// arranque contestaría «no tienes» —con la agenda a medio llegar— y eso es
  /// mentir, no esperar. Esperando al mismo futuro, contesta bien y tarde.
  Future<void> _leerSiHaceFalta(DateTime ahora) =>
      _enVuelo ??= _leerAhora(ahora).whenComplete(() => _enVuelo = null);

  /// La lectura que está ocurriendo, si hay alguna.
  Future<void>? _enVuelo;

  Future<void> _leerAhora(DateTime ahora) async {
    final carpeta = state.carpeta;
    final emparejada = carpeta == null ? null : _laCarpeta(carpeta);
    final toca = LaLecturaQueToca.para(
      ahora: ahora,
      leidoDesde: _leidoDesde,
      carpeta: carpeta,
      carpetaEmparejada: emparejada != null,
    );

    switch (toca.que) {
      // Fuera de jornada no se lee y **no se conserva**: lo que quedara en
      // memoria sería la lista de un día que terminó.
      case QueHacerConLaAgenda.olvidarla:
        if (_agenda.isNotEmpty) _olvidarLaAgenda();
        return;
      case QueHacerConLaAgenda.dejarlaComoEsta:
      // El workspace se carga solo y en paralelo, y el vigilante le gana la
      // carrera al arrancar. Leer ahí sacaría la agenda de la cuenta por
      // defecto en vez de la de la carpeta — que es otra cuenta, con otro
      // calendario o con ninguno. Se espera al siguiente tic.
      case QueHacerConLaAgenda.esperarALaCarpeta:
        return;
      case QueHacerConLaAgenda.leerla:
        break;
    }

    final leida = await ref
        .read(agendaDataSourceProvider)
        .delDia(
          DateTime(ahora.year, ahora.month, ahora.day),
          carpeta: carpeta!,
          configDir: emparejada!.claudeProfile,
        );
    if (!ref.mounted) return;
    _agenda = leida;
    _leidoDesde = toca.ancla;
    state = state.copyWith(ultimaLectura: _ahora());
    // El local **antes** del `clear`: en un cascade el argumento se evalúa
    // después, así que `..clear()..addAll(loQueSigueVivo(_yaAvisadas, …))`
    // vaciaría el conjunto y volvería a avisar de todo.
    final siguenVivos = LoQueTocaAvisar.loQueSigueVivo(_yaAvisadas, leida);
    _yaAvisadas
      ..clear()
      ..addAll(siguenVivos);
  }

  /// Lo dice en voz alta, o lo deja escrito si no se puede.
  ///
  /// 🔴 **Decirlo ya no vive aquí.** Todo lo que costó aprenderlo —pedir el
  /// altavoz antes de sintetizar, el silencio de cabecera, esperar a que suene
  /// antes de parar el motor, soltarlo pase lo que pase— se fue a
  /// [LaVozQueAvisa] el día que hubo un segundo sitio que quería hablar. Tener
  /// dos copias de eso habría sido tener dos copias de sus fallos, que además
  /// se pagaron uno a uno.
  Future<void> _avisar(Reunion reunion, DateTime ahora) async {
    final s = ref.read(stringsProvider);
    await ref
        .read(laVozQueAvisaProvider)
        .decir(
          titulo: reunion.titulo,
          frase: LoQueTocaAvisar.comoSeDice(
            reunion,
            cuando: ahora,
            plantilla: s.reunionEnMinutos,
            ahoraMismo: s.reunionAhora,
          ),
        );
  }

  /// La carpeta emparejada, o `null` si todavía no está en el workspace.
  ///
  /// **Devuelve la carpeta y no su cuenta a propósito**: quien lee necesita
  /// distinguir «la carpeta no está todavía» de «está y usa la cuenta por
  /// defecto». Las dos daban `null` cuando esto devolvía la cuenta, y la primera
  /// se leía como la segunda.
  ///
  /// 🔴 De aquí salía el bug que dejó los avisos mudos desde el primer día: se
  /// devolvía `ClaudeProfile.nameFromPath(...)`, o sea `work` donde hacía falta
  /// `/Users/…/.claude-work`. Eso acababa en `CLAUDE_CONFIG_DIR=work`, una ruta
  /// **relativa**: `claude -p` se creaba una cuenta nueva y vacía dentro de la
  /// carpeta emparejada, contestaba «Not logged in · Please run /login» y el
  /// `catch` de la lectura lo convertía en una agenda vacía. Sin conector, sin
  /// reuniones y sin un solo error a la vista. El resto de la app —el puente de
  /// los encargos— siempre pasó la ruta; esto era el único sitio que pasaba el
  /// nombre, y también el único que nadie podía probar a mano.
  PairedFolder? _laCarpeta(String carpeta) => ref
      .read(workspaceControllerProvider)
      .folders
      .where((f) => f.path == carpeta)
      .firstOrNull;
}

/// El reloj. Se sustituye en las pruebas; en la app es el de la máquina.
final relojProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Las tres fuentes del vigilante, cada una en su proveedor.
///
/// 🔴 **Estaban construidas a mano dentro del notificador** —`const
/// AgendaDataSource()`, la del servicio de voz—, o sea presentation
/// alcanzando `data` sin pasar por ningún sitio. El resto del repositorio no
/// hace eso, y aquí costaba lo de siempre: sin una costura por donde entrar,
/// las 160 líneas de este archivo no se podían probar sin llamar de verdad al
/// calendario y al servicio de voz.
///
/// Son `Provider` y no parámetros del constructor porque un `Notifier` de
/// Riverpod no los tiene: la costura del framework es sobrescribir el proveedor.
final avisosPreferenciasProvider = Provider<AvisosPreferenciasDataSource>(
  (ref) => const AvisosPreferenciasDataSource(),
);

final agendaDataSourceProvider = Provider<AgendaDataSource>(
  (ref) => const AgendaDataSource(),
);

/// Quien dice el aviso en voz alta.
///
/// Por la sesión de voz —la misma de las conversaciones— y no por el TTS, cuyo
/// cupo diario se agota con dos o tres avisos. Ver [LaVozDelAviso].
final laVozDelAvisoProvider = Provider<LaVozDelAviso>(
  (ref) => LaVozDelAviso(ref.watch(voiceGatewayProvider), debugPrint),
);

final elVigilanteDeLaAgendaProvider =
    NotifierProvider<ElVigilanteDeLaAgenda, Avisos>(ElVigilanteDeLaAgenda.new);

/// El puerto que usa la conversación, hablando o escribiendo.
final laAgendaDeHoyProvider = Provider<LaAgendaDeHoy>(
  (ref) => _LaAgendaDelVigilante(ref),
);

class _LaAgendaDelVigilante implements LaAgendaDeHoy {
  const _LaAgendaDelVigilante(this._ref);

  final Ref _ref;

  @override
  Future<String?> deHoy() =>
      _ref.read(elVigilanteDeLaAgendaProvider.notifier).loDeHoy();
}
