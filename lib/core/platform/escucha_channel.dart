import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Por qué no se pudo poner la escucha. Los nombres son los de
/// `PorQueNoEscucha` en `NexusEscucha.swift`: es lo que viaja por el canal.
enum PorQueNoEscucha {
  sinPalabras,
  sinPermisoDeVoz,
  sinPermisoDelMicrofono,
  microfonoOcupado,
  sinReconocedorLocal,
  sinMicrofono,
  fallaElMotor,

  /// Uno que el lado nativo mandó y aquí no se conoce, o ninguno: el canal no
  /// contestó o contestó a la antigua, con un `false` a secas.
  desconocido;

  static PorQueNoEscucha porNombre(Object? nombre) => values.firstWhere(
    (motivo) => motivo.name == nombre,
    orElse: () => desconocido,
  );
}

/// Cómo quedó la escucha al ponerla: puesta —y en qué idioma— o no, y por qué.
///
/// 🔴 **Existe porque el porqué se quedaba en macOS.** El lado nativo sabía si
/// faltaba el permiso, si el micrófono lo tenía una reunión o si no había
/// reconocedor local, y lo escribía en el registro unificado; a la app le
/// llegaba un `false` y `nexus.log` decía «no se pudo poner». Salió al escribir
/// la guía de configuración de la voz (30 sep).
@immutable
class ComoQuedoLaEscucha {
  const ComoQuedoLaEscucha.puesta({this.idioma}) : puesta = true, motivo = null;

  const ComoQuedoLaEscucha.noPuesta(PorQueNoEscucha this.motivo)
    : puesta = false,
      idioma = null;

  /// Lo que contestó el canal: un mapa con `puesta`, `idioma` y `motivo`, o —a
  /// la antigua— un booleano.
  factory ComoQuedoLaEscucha.de(Object? respuesta) => switch (respuesta) {
    true => const ComoQuedoLaEscucha.puesta(),
    {'puesta': true} && final Map<Object?, Object?> m =>
      ComoQuedoLaEscucha.puesta(idioma: m['idioma'] as String?),
    final Map<Object?, Object?> m => ComoQuedoLaEscucha.noPuesta(
      PorQueNoEscucha.porNombre(m['motivo']),
    ),
    _ => const ComoQuedoLaEscucha.noPuesta(PorQueNoEscucha.desconocido),
  };

  final bool puesta;

  /// El del reconocedor con el que escucha —`es-MX`—, si está puesta.
  final String? idioma;

  /// Por qué no, si no está puesta.
  final PorQueNoEscucha? motivo;

  /// Cómo se dice en el registro.
  @override
  String toString() => puesta
      ? 'puesta${idioma == null ? '' : ' · $idioma'}'
      : 'no se pudo poner · ${motivo?.name}';

  @override
  bool operator ==(Object other) =>
      other is ComoQuedoLaEscucha &&
      other.puesta == puesta &&
      other.idioma == idioma &&
      other.motivo == motivo;

  @override
  int get hashCode => Object.hash(puesta, idioma, motivo);
}

/// Oír tu nombre sin que le des a nada.
///
/// El trabajo lo hace el reconocedor de voz de macOS **en el dispositivo** —ver
/// `NexusEscucha`—; aquí solo se enciende, se apaga y se recoge el aviso.
abstract final class EscuchaChannel {
  static const _canal = MethodChannel('com.katanalabs.nexus/escucha');

  /// Empieza a escuchar esas palabras, y dice cómo quedó: puesta, o por qué
  /// no —sin permiso, sin reconocedor, sin reconocimiento local, que es el único
  /// con el que esto se enciende—.
  ///
  /// [idioma] es el de la app —`es`, `en`—: el reconocedor escucha en ese, con
  /// el del sistema de respaldo si ese no tiene modelo local. Ver
  /// `NexusEscucha.elReconocedor`.
  static Future<ComoQuedoLaEscucha> empezar(
    List<String> palabras, {
    String? idioma,
  }) async {
    try {
      return ComoQuedoLaEscucha.de(
        await _canal.invokeMethod<Object?>('empezar', {
          'palabras': palabras,
          'idioma': ?idioma,
        }),
      );
    } on Object catch (error) {
      debugPrint('escucha · no se pudo empezar: $error');
      return const ComoQuedoLaEscucha.noPuesta(PorQueNoEscucha.desconocido);
    }
  }

  /// Cambió el idioma de la app: si está escuchando, vuelve a empezar con el
  /// reconocedor del nuevo. Dice cómo quedó.
  static Future<ComoQuedoLaEscucha> cambiarIdioma(String idioma) async {
    try {
      return ComoQuedoLaEscucha.de(
        await _canal.invokeMethod<Object?>('idioma', {'idioma': idioma}),
      );
    } on Object catch (error) {
      debugPrint('escucha · no se pudo cambiar el idioma: $error');
      return const ComoQuedoLaEscucha.noPuesta(PorQueNoEscucha.desconocido);
    }
  }

  static Future<void> parar() async {
    try {
      await _canal.invokeMethod<void>('parar');
    } on Object catch (error) {
      debugPrint('escucha · no se pudo parar: $error');
    }
  }

  /// Qué hacer cuando te oiga, y cuando deje de escuchar sin que nadie lo
  /// pidiera: la tarea de reconocimiento se renueva sola y, si no pudo volver
  /// a empezar, lo avisa —con el porqué— en vez de apagarse en silencio. `null`
  /// lo desengancha.
  ///
  /// Oírte son dos avisos: [alOirTuNombre] en cuanto se oye el nombre —para
  /// que el orbe salga ya— y [alOir] cuando terminas la frase, con **lo que
  /// dijiste después del nombre** (vacío si solo la llamaste).
  static void cuandoTeLlamen(
    void Function(String resto)? alOir, {
    void Function()? alOirTuNombre,
    void Function(ComoQuedoLaEscucha como)? siSeCalla,
  }) {
    _canal.setMethodCallHandler((llamada) async {
      switch (llamada.method) {
        case 'teOyo':
          alOirTuNombre?.call();
        case 'teLlamaron':
          final args = llamada.arguments;
          final resto = args is Map ? args['resto'] : null;
          alOir?.call(resto is String ? resto.trim() : '');
        // Con el porqué, si lo trae: al callarse sola, lo que falla al volver
        // a empezar es lo mismo que al ponerse.
        case 'seCallo':
          siSeCalla?.call(ComoQuedoLaEscucha.de(llamada.arguments));
      }
      return null;
    });
  }
}
