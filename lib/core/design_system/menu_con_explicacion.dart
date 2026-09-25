import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/nexus_colors.dart';
import 'package:nexus/core/design_system/nexus_spacing.dart';
import 'package:nexus/core/design_system/nexus_typography.dart';

// La cabecera y el pie de los menús que se abren desde el compositor y el
// muelle. En el sistema de diseño porque los usan los dos, y así ninguno tiene
// que importar al otro para decir lo mismo con la misma forma.

/// La cabecera de un menú: de qué es lo que se elige.
///
/// Todos siguen la misma regla —opciones con nombre y, debajo, lo que cuesta o
/// lo que cambia— y la cabecera es la mitad de esa regla: «Permiso en nexus»
/// dice de quién es el permiso antes de elegirlo, que es justo lo que hizo
/// creer que era de la app cuando el menú decía «Permiso» a secas.
PopupMenuItem<T> cabeceraDelMenu<T>(BuildContext context, String texto) =>
    PopupMenuItem<T>(
      enabled: false,
      height: 28,
      child: Text(
        texto,
        style: NexusTypography.label.copyWith(color: context.colors.mute),
      ),
    );

/// El pie de un menú: lo que implica elegir aquí, en una frase. En sans y en
/// `mute`, que se lee: es una explicación, no un dato.
PopupMenuItem<T> pieDelMenu<T>(BuildContext context, String texto) =>
    PopupMenuItem<T>(
      enabled: false,
      height: 0,
      padding: const EdgeInsets.fromLTRB(
        NexusSpacing.s4,
        NexusSpacing.s2,
        NexusSpacing.s4,
        NexusSpacing.s3,
      ),
      child: ConstrainedBox(
        // Estrecho a propósito: sin tope, una frase larga ensancha el menú
        // entero hasta lo que ocupe ella sola.
        constraints: const BoxConstraints(maxWidth: 280),
        child: Text(
          texto,
          style: NexusTypography.nota.copyWith(color: context.colors.mute),
        ),
      ),
    );
