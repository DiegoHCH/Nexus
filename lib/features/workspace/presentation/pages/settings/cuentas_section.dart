import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/e2e/presentation/providers/repo_de_pruebas_providers.dart';
import 'package:nexus/features/e2e/presentation/widgets/cuentas_de_un_proyecto.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

/// Las cuentas con las que corren las pruebas, por proyecto.
///
/// **Sección propia y no un trozo de Pruebas.** Aquella responde «¿qué pruebas
/// tengo y dónde viven?»; ésta, «¿con qué credenciales corren?». Son dos preguntas
/// distintas y la segunda trae un formulario con contraseñas dentro, que no es algo
/// que uno quiera encontrarse de paso.
///
/// 🔴 **Una sola lista, como el mockup, y el proyecto en cada fila.** Iban
/// agrupadas bajo el nombre y la ruta de cada repo, y con una o dos cuentas por
/// proyecto la cabecera pesaba más que lo que agrupaba. Un proyecto sin cuentas
/// no sale: lo que se viene a ver es lo que hay configurado, y los demás se
/// alcanzan desde «Añadir cuenta», donde el proyecto se elige.
class CuentasSection extends ConsumerWidget {
  const CuentasSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final carpetas = ref.watch(workspaceControllerProvider).folders;

    final filas = [
      for (final carpeta in carpetas)
        for (final (i, cuenta)
            in ref
                .watch(cuentasDePruebaProvider(carpeta.workingDirectory))
                .indexed)
          FilaDeCuentaDePruebas(
            cuenta: cuenta,
            proyecto: carpeta.workingDirectory,
            porDefecto: i == 0,
          ),
    ];

    return BloquesDeAjustes(
      bloques: [
        BloqueDeAjustes(
          hijos: [
            TextoDeAjustes(strings.e2eAccountsWhere),
            if (filas.isEmpty)
              TextoDeAjustes(strings.e2eAccountsNoneAnywhere)
            else
              FilasDeAjustes(filas: filas),
            // **Una sola acción, y el proyecto se elige dentro.** Antes había
            // un botón por proyecto sin cuentas: una lista que crece con el
            // workspace y en la que cada botón dice el nombre de un repo pero
            // no qué va a pasar al pulsarlo.
            if (carpetas.isNotEmpty)
              AccionesDeAjustes(
                botones: [
                  BotonDeAjustes(
                    texto: strings.e2eAccountAdd,
                    tono: TonoDeBoton.principal,
                    onPulsar: () => editarCuenta(
                      context,
                      // El emparejado arranca elegido: es el proyecto en el que
                      // estás.
                      ref
                              .read(workspaceControllerProvider)
                              .active
                              ?.workingDirectory ??
                          carpetas.first.workingDirectory,
                      null,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
