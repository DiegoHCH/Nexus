import 'package:nexus/features/prs/domain/entities/pr_mezclado.dart';

/// De qué PR hay que avisar y qué hay que recordar después.
///
/// 🔴 **Lo difícil aquí no es ver los mezclados, es no gritarlos todos.** La
/// primera vuelta encuentra el historial entero: sin una primera vez que calle,
/// encender el vigía soltaría veinte avisos de PRs que cerraste la semana
/// pasada, y el aviso perdería el sentido en el mismo minuto en que se estrena.
abstract final class LosPrQueSeMezclaron {
  /// Cuántas señas se guardan.
  ///
  /// No crece sin fin: lo que se recuerda es para no repetir un aviso, y un PR
  /// mezclado hace meses no va a volver a aparecer en una búsqueda de los
  /// últimos. Se quedan los más recientes, que son los que pueden repetirse.
  static const cuantasSeRecuerdan = 200;

  /// [vistos] a `null` es **la primera vuelta**: no se avisa de nada y se
  /// apunta todo. `null` y no una lista vacía a propósito — vacía significa
  /// «miré y no había ninguno», y ahí sí hay que avisar de lo que aparezca.
  static ({List<PrMezclado> queDecir, List<String> queRecordar}) loQueToca({
    required List<PrMezclado> ahora,
    required List<String>? vistos,
  }) {
    final recordados = vistos ?? const <String>[];
    final nuevos = vistos == null
        ? const <PrMezclado>[]
        : [
            for (final pr in ahora)
              if (!recordados.contains(pr.sena)) pr,
          ];

    // Los de ahora delante: al recortar, lo que se tira es lo más viejo.
    final queRecordar = <String>[
      for (final pr in ahora) pr.sena,
      for (final sena in recordados)
        if (!ahora.any((pr) => pr.sena == sena)) sena,
    ];

    return (
      queDecir: nuevos,
      queRecordar: queRecordar.length <= cuantasSeRecuerdan
          ? queRecordar
          : queRecordar.sublist(0, cuantasSeRecuerdan),
    );
  }
}
