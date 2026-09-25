import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/i18n/language_preference.dart';
import 'package:nexus/features/agenda/presentation/providers/el_vigilante_de_la_agenda.dart';
import 'package:nexus/features/opinion/data/datasources/lo_que_dice_gh.dart';
import 'package:nexus/features/opinion/domain/usecases/lo_que_veo_de_tu_trabajo.dart';
import 'package:nexus/features/workspace/data/datasources/git_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mirar el trabajo de una carpeta y decidir si hay algo que decir.
///
/// La decisión vive en [LoQueVeoDeTuTrabajo], aparte y probada. Aquí está lo
/// que esa decisión no puede saber sin tocar el mundo: cómo está el repositorio
/// y **qué se dijo ya**.
///
/// 🔴 **Una vez al día por cosa, y esto es la mitad del invento.** Una
/// observación repetida cada vez que abres la carpeta deja de ser una
/// observación: se convierte en un rótulo, se aprende a no verlo, y a partir de
/// ahí da igual lo acertado que sea. Lo dicho se recuerda con su llave y su
/// día, así que «llevas tres commits sin subir» se dice una vez y no vuelve
/// hasta mañana — y si mañana ya los subiste, no vuelve nunca.
class LoQueVeoDeLaCarpeta {
  LoQueVeoDeLaCarpeta(this._ref);

  final Ref _ref;

  static const yaDicho = 'lo_que_veo_ya_dicho';

  /// La frase que toca decir de esta carpeta, o `null`.
  ///
  /// No lanza nunca: esto corre al abrir una conversación y una opinión no
  /// puede impedir que se abra.
  Future<String?> deLaCarpeta(String carpeta) async {
    try {
      final estado = await const GitDataSource().comoEsta(carpeta);
      if (estado == null || !_ref.mounted) return null;

      // Lo de fuera, que cuesta una llamada cada una: el CI solo si hay rama, y
      // los PR solo los de **este** repositorio — uno parado en otro sitio no
      // es lo que has venido a mirar aquí.
      final rama = estado.rama;
      final ciRoto = rama == null
          ? null
          : await const LoQueDiceGh().elCiRoto(carpeta, rama);
      if (!_ref.mounted) return null;
      final parado = await _elPrMasParado(carpeta);
      if (!_ref.mounted) return null;

      final s = _ref.read(stringsProvider);
      final visto = LoQueVeoDeTuTrabajo.loQueDiria(
        estado,
        ahora: _ref.read(relojProvider)(),
        carpeta: carpeta,
        sinCommitear: s.veoSinCommitear,
        sinSubir: s.veoSinSubir,
        sinBajar: s.veoSinBajar,
        ciRoto: ciRoto,
        elCiEstaRoto: s.veoElCiRoto,
        prParado: parado?.numero,
        prDesde: parado?.ultimoMovimiento,
        elPrEstaParado: s.veoUnPrParado,
      );
      if (visto == null) return null;

      final prefs = await SharedPreferences.getInstance();
      final hoy = _elDiaDeHoy();
      final ya = prefs.getStringList(yaDicho) ?? const [];
      final marca = '${visto.llave}@$hoy';
      if (ya.contains(marca)) return null;

      // Solo se guarda lo de hoy: lo de ayer ya no puede callar nada, y sin
      // esta poda la lista crece una línea por carpeta y día para siempre.
      await prefs.setStringList(yaDicho, [
        marca,
        for (final otra in ya)
          if (otra.endsWith('@$hoy')) otra,
      ]);
      return visto.decir;
    } on Object catch (error) {
      debugPrint('lo que veo · no se pudo mirar: $error');
      return null;
    }
  }

  /// El PR abierto de **esta** carpeta que lleva más tiempo quieto.
  ///
  /// Se compara por el nombre del repositorio y no por la ruta: la carpeta
  /// emparejada puede ser un subdirectorio, y `gh` habla de repositorios.
  Future<UnPrAbierto?> _elPrMasParado(String carpeta) async {
    final abiertos = await const LoQueDiceGh().abiertos();
    if (abiertos == null || abiertos.isEmpty) return null;
    final info = await const GitDataSource().read(carpeta);
    final repo = info?.repository;
    if (repo == null) return null;
    UnPrAbierto? masQuieto;
    for (final pr in abiertos) {
      if (pr.repo != repo) continue;
      if (masQuieto == null ||
          pr.ultimoMovimiento.isBefore(masQuieto.ultimoMovimiento)) {
        masQuieto = pr;
      }
    }
    return masQuieto;
  }

  String _elDiaDeHoy() {
    final ahora = _ref.read(relojProvider)();
    return '${ahora.year}-${ahora.month}-${ahora.day}';
  }
}

final loQueVeoDeLaCarpetaProvider = Provider<LoQueVeoDeLaCarpeta>(
  LoQueVeoDeLaCarpeta.new,
);
