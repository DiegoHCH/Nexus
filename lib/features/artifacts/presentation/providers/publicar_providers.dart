import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/i18n/language_preference.dart';
import 'package:nexus/core/platform/lo_que_pide_la_pagina.dart';
import 'package:nexus/core/platform/notifications_channel.dart';
import 'package:nexus/features/artifacts/data/datasources/el_publicador_por_la_terminal.dart';
import 'package:nexus/features/artifacts/data/datasources/los_enlaces_publicados_en_disco.dart';
import 'package:nexus/features/artifacts/domain/entities/la_publicacion.dart';
import 'package:nexus/features/artifacts/domain/repositories/el_publicador.dart';
import 'package:nexus/features/artifacts/domain/usecases/publicar_un_documento.dart';
import 'package:nexus/features/artifacts/presentation/providers/artifacts_providers.dart';
import 'package:nexus/features/artifacts/presentation/providers/lo_publicado_al_dia.dart';
import 'package:path_provider/path_provider.dart';

final elPublicadorProvider = Provider<ElPublicador>(
  (ref) => ElPublicadorPorLaTerminal(soporte: getApplicationSupportDirectory),
);

final losEnlacesPublicadosProvider = Provider<LosEnlacesPublicados>(
  (ref) => LosEnlacesPublicadosEnDisco(
    () async => File(
      '${(await getApplicationSupportDirectory()).path}/publicados.json',
    ),
  ),
);

final publicarUnDocumentoProvider = Provider<PublicarUnDocumento>(
  (ref) => PublicarUnDocumento(
    ref.watch(elPublicadorProvider),
    ref.watch(losEnlacesPublicadosProvider),
    home: Platform.environment['HOME'] ?? '',
    existe: (ruta) => Directory(ruta).existsSync(),
  ),
);

/// Lo que vuelve a publicar un documento cuando cambia. Vive lo que la app: se
/// lee una vez al arrancar, pone al día lo que cambió con la app cerrada y
/// vigila desde ahí.
final loPublicadoAlDiaProvider = Provider<LoPublicadoAlDia>((ref) {
  final alDia = LoPublicadoAlDia(
    publicados: ref.read(losEnlacesPublicadosProvider).todos,
    ponerAlDia: ref.read(publicarUnDocumentoProvider).siCambio,
    alTerminar: (archivo, html, salio) {
      switch (salio) {
        case Publicado(:final url):
          debugPrint('publicar · al día · $url');
          return;
        case HayQueConfiarEnLaCarpeta(:final carpeta):
          debugPrint(
            'publicar · sin poner al día $archivo: confiar en $carpeta',
          );
        case NoSePudoPublicar(:final motivo):
          debugPrint('publicar · sin poner al día $archivo: $motivo');
      }
      // Un enlace que se quedó atrás sin decirlo es peor que no publicar: quien
      // lo compartió cree que enseña lo último.
      final strings = ref.read(stringsProvider);
      unawaited(
        NotificationsChannel.notify(
          title: strings.publicadoSinActualizarTitulo,
          body: strings.publicadoSinActualizarDetalle(
            PublicarUnDocumento.elTituloDelDocumento(html, archivo),
          ),
        ),
      );
    },
  );
  unawaited(alDia.empezar());
  ref.onDispose(alDia.olvidar);
  return alDia;
});

/// Lo que atiende el botón «Publicar en claude.ai» del visor. Vive lo que la
/// app: se lee una vez al arrancar y escucha desde ahí.
final laPublicacionDesdeElVisorProvider = Provider<LaPublicacionDesdeElVisor>((
  ref,
) {
  final publicacion = LaPublicacionDesdeElVisor(ref)..escuchar();
  ref.onDispose(publicacion.olvidar);
  return publicacion;
});

/// Lo que pasa entre el botón del visor y claude.ai.
///
/// El visor pide `publicar` con la ruta del documento; aquí se publica y se le
/// devuelve cómo fue, para que lo diga en un aviso pegado a su ventana. Si
/// Claude Code no confía aún en la carpeta de publicación, el visor ofrece
/// abrir la terminal y pide `confiarParaPublicar`.
class LaPublicacionDesdeElVisor {
  LaPublicacionDesdeElVisor(this._ref);

  final Ref _ref;

  /// Las que están en marcha: un segundo clic no lanza otra sesión oculta.
  final _enCurso = <String>{};

  /// Lo que quedó pendiente de aceptar, por documento.
  final _porConfiar = <String, HayQueConfiarEnLaCarpeta>{};

  void escuchar() {
    LoQuePideLaPagina.escuchar('publicar', (ruta) => unawaited(publicar(ruta)));
    LoQuePideLaPagina.escuchar(
      'confiarParaPublicar',
      (ruta) => unawaited(confiar(ruta)),
    );
  }

  void olvidar() {
    LoQuePideLaPagina.olvidar('publicar');
    LoQuePideLaPagina.olvidar('confiarParaPublicar');
  }

  Future<void> publicar(String ruta) async {
    if (ruta.isEmpty || !_enCurso.add(ruta)) return;
    final strings = _ref.read(stringsProvider);
    final visor = _ref.read(artifactsDataSourceProvider);
    try {
      final html = File(ruta).readAsStringSync();
      final salio = await _ref.read(publicarUnDocumentoProvider)(
        ruta,
        html: html,
      );
      switch (salio) {
        case Publicado(:final url, :final nuevo):
          debugPrint('publicar · ${nuevo ? 'nuevo' : 'mismo enlace'} · $url');
          // Y desde ahora, cada cambio del documento va a este enlace solo.
          _ref.read(loPublicadoAlDiaProvider).vigilar(ruta);
          await visor.publicacion(
            ruta: ruta,
            estado: 'publicado',
            titulo: nuevo ? strings.publicadoTitulo : strings.actualizadoTitulo,
            detalle: nuevo
                ? strings.publicadoDetalle
                : strings.actualizadoDetalle,
            url: url,
          );
        case HayQueConfiarEnLaCarpeta():
          debugPrint('publicar · falta confiar en ${salio.carpeta}');
          _porConfiar[ruta] = salio;
          await visor.publicacion(
            ruta: ruta,
            estado: 'confiar',
            titulo: strings.publicarFaltaConfiarTitulo,
            detalle: strings.publicarFaltaConfiarDetalle,
          );
        case NoSePudoPublicar(:final motivo):
          debugPrint('publicar · no se pudo: $motivo');
          await visor.publicacion(
            ruta: ruta,
            estado: 'error',
            titulo: strings.publicarNoSePudo,
            detalle: motivo,
          );
      }
    } on FileSystemException catch (error) {
      await visor.publicacion(
        ruta: ruta,
        estado: 'error',
        titulo: strings.publicarNoSePudo,
        detalle: error.message,
      );
    } finally {
      _enCurso.remove(ruta);
    }
  }

  Future<void> confiar(String ruta) async {
    final pedido = _porConfiar.remove(ruta);
    if (pedido == null) return;
    await _ref
        .read(elPublicadorProvider)
        .confiarEnLaCarpeta(
          pedido,
          aviso: _ref.read(stringsProvider).publicarAvisoEnLaTerminal,
        );
  }
}
