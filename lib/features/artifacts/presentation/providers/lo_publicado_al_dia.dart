import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nexus/features/artifacts/domain/entities/la_publicacion.dart';

/// Que lo publicado en claude.ai siga al documento: si el documento cambia, se
/// vuelve a publicar en el mismo enlace sin que nadie pulse nada.
///
/// Da igual quién lo cambie —Claude en una conversación de Nexus, otra
/// terminal, un editor—: se vigila el archivo, no a quien escribe. Y lo que
/// cambió con la app cerrada se pone al día al arrancar.
/// Ver `PublicarUnDocumento.siCambio`.
class LoPublicadoAlDia {
  LoPublicadoAlDia({
    required this.publicados,
    required this.ponerAlDia,
    required this.alTerminar,
    this.calma = const Duration(seconds: 10),
  });

  /// Lo que ya está publicado.
  final Future<List<LoPublicado>> Function() publicados;

  /// Vuelve a publicar un documento si cambió; `null` si no hacía falta.
  final Future<LoQueSalioDePublicar?> Function(
    String archivo, {
    required String html,
  })
  ponerAlDia;

  /// Lo que salió de volver a publicar [archivo], cuyo HTML era [html].
  final void Function(String archivo, String html, LoQueSalioDePublicar salio)
  alTerminar;

  /// Cuánto tiene que pasar sin cambios para publicar.
  ///
  /// 🔴 **Se espera a que el documento deje de moverse.** Claude lo cambia en
  /// varios pasos —un `Edit` y unos `sed` en diez segundos, en el caso que lo
  /// pidió— y publicar en cada uno es lanzar una sesión oculta por paso para
  /// enseñar versiones a medias.
  final Duration calma;

  /// Los nombres vigilados, por carpeta.
  final _porCarpeta = <String, Set<String>>{};
  final _vigias = <String, StreamSubscription<FileSystemEvent>>{};
  final _esperas = <String, Timer>{};

  /// De una en una: dos sesiones ocultas a la vez sobre el mismo enlace se
  /// pisarían, y publicar no corre prisa.
  Future<void> _cola = Future.value();

  /// Vigila todo lo publicado y pone al día lo que cambió con la app cerrada.
  Future<void> empezar() async {
    for (final publicado in await publicados()) {
      vigilar(publicado.archivo);
      _revisarTrasLaCalma(publicado.archivo);
    }
  }

  /// Vigila [archivo] desde ahora: se llama al publicarlo por primera vez.
  void vigilar(String archivo) {
    final corte = archivo.lastIndexOf('/');
    if (corte <= 0) return;
    final carpeta = archivo.substring(0, corte);
    final nombres = _porCarpeta.putIfAbsent(carpeta, () => {});
    if (!nombres.add(archivo.substring(corte + 1))) return;
    if (_vigias.containsKey(carpeta)) return;
    if (_vigilarLaCarpeta(carpeta) case final vigia?) _vigias[carpeta] = vigia;
  }

  /// Deja de vigilar.
  void olvidar() {
    for (final vigia in _vigias.values) {
      unawaited(vigia.cancel());
    }
    for (final espera in _esperas.values) {
      espera.cancel();
    }
    _vigias.clear();
    _esperas.clear();
    _porCarpeta.clear();
  }

  /// 🔴 Se vigila **la carpeta y no el archivo**, como con el `HEAD` del repo:
  /// quien guarda escribiendo uno nuevo y renombrándolo encima deja a un vigía
  /// del archivo mirando un inodo que ya no es de nadie.
  StreamSubscription<FileSystemEvent>? _vigilarLaCarpeta(String carpeta) {
    final directorio = Directory(carpeta);
    if (!directorio.existsSync()) return null;
    return directorio.watch().listen(
      (evento) {
        for (final ruta in [
          evento.path,
          if (evento is FileSystemMoveEvent) evento.destination,
        ]) {
          final nombre = ruta?.split('/').last;
          if (nombre != null &&
              _porCarpeta[carpeta]?.contains(nombre) == true) {
            _revisarTrasLaCalma('$carpeta/$nombre');
          }
        }
      },
      // Una carpeta que se borra o deja de poderse leer no tumba la app: se
      // deja de vigilar, y al arrancar otra vez se pone al día.
      onError: (Object error) => debugPrint('publicar · sin vigía en $carpeta'),
      cancelOnError: true,
    );
  }

  void _revisarTrasLaCalma(String archivo) {
    _esperas.remove(archivo)?.cancel();
    _esperas[archivo] = Timer(calma, () {
      _esperas.remove(archivo);
      _cola = _cola.then((_) => _revisar(archivo));
    });
  }

  Future<void> _revisar(String archivo) async {
    try {
      final html = await File(archivo).readAsString();
      final salio = await ponerAlDia(archivo, html: html);
      if (salio != null) alTerminar(archivo, html, salio);
    } on FileSystemException {
      // Borrado, o a medio renombrar: si vuelve, el vigía lo verá llegar.
    } on Object catch (error) {
      debugPrint('publicar · no se pudo poner al día $archivo: $error');
    }
  }
}
