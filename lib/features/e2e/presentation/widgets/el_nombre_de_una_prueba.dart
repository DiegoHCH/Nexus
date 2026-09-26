import 'package:flutter/painting.dart';
import 'package:nexus/core/design_system/design_system.dart';

/// El nombre de una prueba en una fila: un nombre, no un dato.
///
/// En la voz de lo que se dice y a 13,5, como las filas del mockup; en mono se
/// leía como una ruta. Aparte porque lo usan las tres columnas de la hoja —lo
/// que se lanza, lo del repo y el historial— y tienen que hablar igual.
TextStyle elNombreDeUnaPrueba(NexusColors colors) =>
    NexusTypography.body.copyWith(fontSize: 13.5, color: colors.ink);
