import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:nexus/core/design_system/orbe_preference.dart';

/// Qué icono lleva Nexus en el Dock mientras está abierta.
///
/// Con la app cerrada manda siempre el del paquete —el de `AppIcon.appiconset`—:
/// esto solo decide qué se pinta **mientras corre**, que es lo único que macOS
/// deja cambiar sin un plugin del Dock.
enum IconoDelDock {
  /// El del paquete, el mismo con la app abierta y cerrada.
  deSiempre,

  /// Dibujado con tu orbe: tu acento y tu forma.
  comoTuOrbe;

  static IconoDelDock fromStored(String? valor) =>
      valor == 'deSiempre' ? deSiempre : comoTuOrbe;

  String get stored => name;
}

/// Todo lo que decide el dibujo del icono.
///
/// Es un valor con igualdad porque **es la llave de no volver a pintar**: si lo
/// que se pediría es igual a lo último que se pintó, no se pinta.
///
/// 🔴 **Sin el estado del orbe, y es una decisión.** Se probó: dormido —que es
/// como está la app casi todo el día— el orbe de puntos pierde la malla y se
/// queda en brasas tenues, y a tamaño de Dock el icono es una placa negra con
/// polvo. Además el estado cambia varias veces por turno, y cada cambio sería
/// un dibujo entero (ver `ElIconoDelDock`). Lo que hace el orbe ya lo cuenta la
/// barra de estado, que es lo que se mira de reojo; el Dock dice **de quién**
/// es la app, no en qué anda.
@immutable
class LoQueSePinta {
  const LoQueSePinta._({required this.acento, required this.estilo});

  /// Lo que se pinta con [acento] y [estilo], quitando lo que no se ve en una
  /// foto fija del icono.
  ///
  /// El tamaño lo fija la rejilla del icono y la velocidad no existe en una
  /// foto; con puntos, ninguno de los siete ajustes del plasma mueve nada.
  /// Quitarlos aquí es lo que hace que arrastrar esos deslizadores **no
  /// repinte** un icono que iba a salir igual.
  ///
  /// 🔴 **Y sin nada del personaje**: el Dock pinta el orbe aunque en la sala
  /// vaya el personaje —ver [OrbeEstilo.personaje]—, así que elegirlo, o
  /// cambiarle la luz o los ojos, no tiene por qué repintar el icono.
  factory LoQueSePinta({required Color acento, required OrbeEstilo estilo}) =>
      LoQueSePinta._(
        acento: acento,
        estilo: estilo.forma == FormaDelOrbe.puntos
            ? const OrbeEstilo(forma: FormaDelOrbe.puntos)
            : OrbeEstilo(
                filamentos: estilo.filamentos,
                turbulencia: estilo.turbulencia,
                finura: estilo.finura,
                nucleo: estilo.nucleo,
                intensidad: estilo.intensidad,
              ),
      );

  /// El tono ya ajustado para el fondo oscuro de la placa.
  final Color acento;
  final OrbeEstilo estilo;

  @override
  bool operator ==(Object other) =>
      other is LoQueSePinta && other.acento == acento && other.estilo == estilo;

  @override
  int get hashCode => Object.hash(acento, estilo);

  @override
  String toString() =>
      'LoQueSePinta(${acento.toARGB32().toRadixString(16)}, '
      '${estilo.forma.name})';
}

/// Convierte lo que se pinta en un PNG cuadrado. `null` si no se pudo.
typedef PintorDelIcono = Future<Uint8List?> Function(LoQueSePinta pedido);

/// La puerta al Dock del sistema.
abstract interface class PuertaDelDock {
  /// Pone [png] como icono de la app. Si no se entiende, se queda el que había.
  Future<void> poner(Uint8List png);

  /// Vuelve al icono del paquete.
  Future<void> quitar();
}
