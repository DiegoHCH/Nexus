// Lo que te espera hoy. Ver `LoQueTeEsperaHoy`.

import 'package:nexus/core/i18n/franja_del_dia.dart';

mixin ElDiaStrings {
  /// Lo que dice al llamarla la primera vez del día: el saludo, el día y la
  /// pregunta para seguir.
  String elDiaAlLlamarla(FranjaDelDia franja, String? nombre, String dia);
  String elDiaReuniones(int cuantas, String titulo, String hora);
  String get elDiaSinReuniones;
  String elDiaPrs(int cuantos, String titulo);
  String elDiaPerdidas(int cuantas, String carpeta);
  String elDiaProxima(String carpeta, String hora);
  String elDiaCupo(int porcentaje);
  String get elDiaNada;

  /// Lo que hace `/hoy`, en la lista de comandos.
  String get ayudaHoy;

  /// El bloque de Ajustes › Avisos.
  String get elDiaAlLlamarlaOn;
  String get elDiaAlLlamarlaExplainer;
}

mixin ElDiaStringsEs implements ElDiaStrings {
  @override
  String elDiaAlLlamarla(FranjaDelDia franja, String? nombre, String dia) {
    final hora = switch (franja) {
      FranjaDelDia.manana => 'Buenos días',
      FranjaDelDia.tarde => 'Buenas tardes',
      FranjaDelDia.noche => 'Buenas noches',
    };
    final aQuien = (nombre == null || nombre.isEmpty) ? '' : ', $nombre';
    return '$hora$aQuien. $dia ¿Por dónde empezamos?';
  }

  @override
  String elDiaReuniones(int cuantas, String titulo, String hora) => cuantas == 1
      ? 'Te queda una reunión: $titulo, a las $hora.'
      : 'Te quedan $cuantas reuniones; la próxima, $titulo, a las $hora.';
  @override
  String get elDiaSinReuniones => 'No te quedan reuniones hoy.';
  @override
  String elDiaPrs(int cuantos, String titulo) => cuantos == 1
      ? 'Un PR espera tu revisión: $titulo.'
      : '$cuantos PR esperan tu revisión; el que más lleva, $titulo.';
  @override
  String elDiaPerdidas(int cuantas, String carpeta) => cuantas == 1
      ? 'Una programada de $carpeta no se lanzó porque la app estaba cerrada.'
      : '$cuantas programadas no se lanzaron porque la app estaba cerrada.';
  @override
  String elDiaProxima(String carpeta, String hora) =>
      'La próxima programada corre a las $hora en $carpeta.';
  @override
  String elDiaCupo(int porcentaje) =>
      'Llevas el $porcentaje % del cupo de la semana.';
  @override
  String get elDiaNada => 'Por ahora no tengo nada que contarte del día.';
  @override
  String get ayudaHoy => 'lo que te espera hoy';
  @override
  String get elDiaAlLlamarlaOn => 'Lo que te espera hoy';
  @override
  String get elDiaAlLlamarlaExplainer =>
      'La primera vez que la llamas en un día laborable, en vez de «¿Sí?» te '
      'cuenta lo que viene: las reuniones que te quedan, los PR que esperan tu '
      'revisión, las programadas y el cupo de la semana. Se lo puedes pedir '
      'cuando quieras: «¿qué me espera hoy?» o /hoy.';
}

mixin ElDiaStringsEn implements ElDiaStrings {
  @override
  String elDiaAlLlamarla(FranjaDelDia franja, String? nombre, String dia) {
    final hora = switch (franja) {
      FranjaDelDia.manana => 'Good morning',
      FranjaDelDia.tarde => 'Good afternoon',
      FranjaDelDia.noche => 'Good evening',
    };
    final aQuien = (nombre == null || nombre.isEmpty) ? '' : ', $nombre';
    return '$hora$aQuien. $dia Where do we start?';
  }

  @override
  String elDiaReuniones(int cuantas, String titulo, String hora) => cuantas == 1
      ? 'You have one meeting left: $titulo, at $hora.'
      : 'You have $cuantas meetings left; the next one, $titulo, at $hora.';
  @override
  String get elDiaSinReuniones => 'No meetings left today.';
  @override
  String elDiaPrs(int cuantos, String titulo) => cuantos == 1
      ? 'One PR is waiting for your review: $titulo.'
      : '$cuantos PRs are waiting for your review; the longest waiting, '
            '$titulo.';
  @override
  String elDiaPerdidas(int cuantas, String carpeta) => cuantas == 1
      ? 'A scheduled task in $carpeta did not run because the app was closed.'
      : '$cuantas scheduled tasks did not run because the app was closed.';
  @override
  String elDiaProxima(String carpeta, String hora) =>
      'The next scheduled task runs at $hora in $carpeta.';
  @override
  String elDiaCupo(int porcentaje) =>
      "You have used $porcentaje% of this week's quota.";
  @override
  String get elDiaNada => 'Nothing to tell you about the day for now.';
  @override
  String get ayudaHoy => "what's ahead today";
  @override
  String get elDiaAlLlamarlaOn => "What's ahead today";
  @override
  String get elDiaAlLlamarlaExplainer =>
      'The first time you call her on a workday, instead of “Yes?” she tells '
      'you what is coming: the meetings you have left, the PRs waiting for '
      'your review, scheduled tasks and this week’s quota. You can ask for it '
      'any time: “what’s ahead today” or /hoy.';
}
