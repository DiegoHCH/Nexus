import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/language_preference.dart';
import 'package:nexus/core/i18n/strings_scope.dart';

/// El idioma de la app, que no es el del sistema salvo que se elija así.
///
/// Sin rótulo, como en el mockup: la sección se llama «Idioma» y un rótulo
/// «IDIOMA» justo debajo del título decía lo mismo dos veces. Las tres opciones
/// a la vista, en su propio idioma —«English» y no «Inglés»—, que es como
/// se encuentra el suyo quien no lee el que está puesto.
class LanguageSection extends ConsumerWidget {
  const LanguageSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final choice = ref.watch(languageControllerProvider);

    return BloquesDeAjustes(
      bloques: [
        BloqueDeAjustes(
          hijos: [
            TextoDeAjustes(strings.languageExplainer),
            ElegirDeAjustes<LanguageChoice>(
              llave: 'idioma',
              opciones: LanguageChoice.values,
              elegida: choice,
              nombre: (option) => switch (option) {
                LanguageChoice.system => strings.languageSystem,
                LanguageChoice.spanish => strings.languageSpanish,
                LanguageChoice.english => strings.languageEnglish,
              },
              onElegir: ref.read(languageControllerProvider.notifier).select,
            ),
          ],
        ),
      ],
    );
  }
}
