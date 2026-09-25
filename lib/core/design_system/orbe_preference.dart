import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// De qué está hecho el orbe.
enum FormaDelOrbe {
  /// Hebras de luz en remolino, con un núcleo que quema. Ver
  /// `shaders/orbe_plasma.frag`.
  plasma,

  /// La esfera de puntos de siempre.
  puntos,
}

/// Cómo es el orbe: su forma y, si es de plasma, sus siete ajustes.
///
/// 🔴 **Son la base, no el estado.** Encima de esto cada estado se mueve a su
/// manera —dormido respira, trabajando gira rápido, hablando late con la voz—
/// y eso no se elige: es lo que permite distinguirlos a tres metros. Lo que se
/// elige es el carácter del plasma. Los valores de fábrica son los que se
/// ajustaron a mano en el mockup del escenario.
@immutable
class OrbeEstilo {
  const OrbeEstilo({
    this.forma = FormaDelOrbe.plasma,
    this.filamentos = 5.8,
    this.turbulencia = 1.4,
    this.finura = 7,
    this.velocidad = 2.5,
    this.nucleo = 3,
    this.tamano = 0.30,
    this.intensidad = 2.2,
  });

  static const fabrica = OrbeEstilo();

  final FormaDelOrbe forma;

  /// Cuántas hebras caben: la escala del ruido. De 1,2 a 8.
  final double filamentos;

  /// Cuánto se retuercen. De 0 a 3,5.
  final double turbulencia;

  /// Lo fina que es cada hebra. De 2 a 16.
  final double finura;

  /// Lo rápido que se mueve el plasma por dentro. De 0 a 4.
  final double velocidad;

  /// Lo que quema el centro. De 0,2 a 5.
  final double nucleo;

  /// El radio, como fracción del lado. De 0,15 a 0,33: más allá el halo toca
  /// el borde de su caja.
  final double tamano;

  /// Cuánta luz da. De 0,2 a 3,5.
  final double intensidad;

  /// Los límites de cada ajuste, para los deslizadores y para no aceptar de
  /// disco un valor que rompa el shader.
  static const rangos = {
    'filamentos': (1.2, 8.0),
    'turbulencia': (0.0, 3.5),
    'finura': (2.0, 16.0),
    'velocidad': (0.0, 4.0),
    'nucleo': (0.2, 5.0),
    'tamano': (0.15, 0.33),
    'intensidad': (0.2, 3.5),
  };

  OrbeEstilo copyWith({
    FormaDelOrbe? forma,
    double? filamentos,
    double? turbulencia,
    double? finura,
    double? velocidad,
    double? nucleo,
    double? tamano,
    double? intensidad,
  }) => OrbeEstilo(
    forma: forma ?? this.forma,
    filamentos: filamentos ?? this.filamentos,
    turbulencia: turbulencia ?? this.turbulencia,
    finura: finura ?? this.finura,
    velocidad: velocidad ?? this.velocidad,
    nucleo: nucleo ?? this.nucleo,
    tamano: tamano ?? this.tamano,
    intensidad: intensidad ?? this.intensidad,
  );

  Map<String, Object> toMap() => {
    'forma': forma.name,
    'filamentos': filamentos,
    'turbulencia': turbulencia,
    'finura': finura,
    'velocidad': velocidad,
    'nucleo': nucleo,
    'tamano': tamano,
    'intensidad': intensidad,
  };

  /// Lee lo guardado o lo que llega por un canal. Lo que falte o no se entienda
  /// sale de fábrica, y lo que se salga de su rango se recorta: un valor raro
  /// en disco no puede dejar el orbe en negro.
  factory OrbeEstilo.fromMap(Map<Object?, Object?>? datos) {
    if (datos == null) return fabrica;
    double leer(String clave, double porDefecto) {
      final valor = datos[clave];
      if (valor is! num) return porDefecto;
      final (min, max) = rangos[clave]!;
      return valor.toDouble().clamp(min, max);
    }

    return OrbeEstilo(
      forma:
          FormaDelOrbe.values
              .where((f) => f.name == datos['forma'])
              .firstOrNull ??
          fabrica.forma,
      filamentos: leer('filamentos', fabrica.filamentos),
      turbulencia: leer('turbulencia', fabrica.turbulencia),
      finura: leer('finura', fabrica.finura),
      velocidad: leer('velocidad', fabrica.velocidad),
      nucleo: leer('nucleo', fabrica.nucleo),
      tamano: leer('tamano', fabrica.tamano),
      intensidad: leer('intensidad', fabrica.intensidad),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OrbeEstilo &&
      other.forma == forma &&
      other.filamentos == filamentos &&
      other.turbulencia == turbulencia &&
      other.finura == finura &&
      other.velocidad == velocidad &&
      other.nucleo == nucleo &&
      other.tamano == tamano &&
      other.intensidad == intensidad;

  @override
  int get hashCode => Object.hash(
    forma,
    filamentos,
    turbulencia,
    finura,
    velocidad,
    nucleo,
    tamano,
    intensidad,
  );
}

/// El estilo elegido, guardado en este Mac.
class OrbeEstiloController extends Notifier<OrbeEstilo> {
  static const _key = 'orbe_estilo';

  @override
  OrbeEstilo build() {
    unawaited(_cargar());
    return OrbeEstilo.fabrica;
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getString(_key);
    if (crudo == null) return;
    try {
      state = OrbeEstilo.fromMap(jsonDecode(crudo) as Map<Object?, Object?>);
    } on Object {
      // Lo guardado no se entiende: se queda de fábrica, que se ve bien.
    }
  }

  Future<void> elegir(OrbeEstilo estilo) async {
    state = estilo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(estilo.toMap()));
  }

  Future<void> restablecer() => elegir(OrbeEstilo(forma: state.forma));
}

final orbeEstiloProvider = NotifierProvider<OrbeEstiloController, OrbeEstilo>(
  OrbeEstiloController.new,
);

/// El estilo del orbe para quien no tiene Riverpod a mano.
///
/// Existe por el orbe flotante, que corre en **otro motor** de Flutter y no
/// puede leer los ajustes por su cuenta: le llegan por el canal con cada aviso,
/// igual que el acento. Sin scope, [NexusOrb] pinta el de fábrica.
class OrbeEstiloScope extends InheritedWidget {
  const OrbeEstiloScope({
    super.key,
    required this.estilo,
    required super.child,
  });

  final OrbeEstilo estilo;

  static OrbeEstilo of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OrbeEstiloScope>()?.estilo ??
      OrbeEstilo.fabrica;

  @override
  bool updateShouldNotify(OrbeEstiloScope oldWidget) =>
      oldWidget.estilo != estilo;
}
