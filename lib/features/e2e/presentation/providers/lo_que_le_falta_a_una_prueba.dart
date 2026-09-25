import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/features/e2e/domain/usecases/las_variables_del_proyecto.dart';
import 'package:nexus/features/e2e/presentation/providers/e2e_providers.dart';

/// Las variables que un flow nombra y el `.env.local` de su proyecto no trae.
///
/// 🔴 **Existe para que el motivo llegue antes que el botón.** La comprobación
/// ya estaba, pero se hacía al tocar «Correr»: el botón se veía encendido, se
/// pulsaba, y entonces salía «Faltan en .env.local: PIN_1» debajo de la lista.
/// El mockup lo pide al revés —«si una prueba no puede correr, se dice por qué
/// en su fila y el botón queda apagado»—, y para eso hay que saberlo al pintar.
///
/// Por prueba y no por proyecto porque cada flow nombra las suyas: que falte
/// `PIN_1` no impide correr el de login. Se recalcula solo cuando cambian las
/// credenciales del proyecto, que es lo único que puede arreglarlo desde aquí.
///
/// Solo los nombres, nunca un valor: esto acaba escrito en la pantalla.
final loQueLeFaltaAUnaPruebaProvider =
    FutureProvider.family<List<String>, ({String proyecto, String ruta})>((
      ref,
      clave,
    ) async {
      final yaml = await File(clave.ruta).readAsString().catchError((_) => '');
      final credenciales = await ref.watch(
        credencialesProvider(clave.proyecto).future,
      );
      return LasVariablesDelProyecto.faltan(
        yaml: yaml,
        tiene: credenciales.claves,
      );
    });
