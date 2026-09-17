import 'dart:convert';

import 'package:nexus/features/programadas/domain/entities/encargo_programado.dart';
import 'package:nexus/features/programadas/domain/repositories/las_programadas.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Los encargos programados, en las preferencias del sistema.
///
/// Donde el resto del estado de la app: no son secretos —una hora y una frase—
/// y el llavero obligaría a desbloquearlo para saber qué toca hoy.
///
/// 🔴 **Se lee del disco en cada operación, y no se cachea.** Lo mira el reloj
/// cada medio minuto y lo escribe la lista cuando borras algo; con una copia en
/// memoria, apagar una tarea y que el reloj la lanzara igual sería cuestión de
/// treinta segundos de desajuste. Son unos pocos kilobytes leídos dos veces por
/// minuto: no hay nada que optimizar aquí todavía.
class LasProgramadasEnPreferencias implements LasProgramadas {
  const LasProgramadasEnPreferencias();

  static const _key = 'programadas';

  @override
  Future<List<EncargoProgramado>> leer() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [for (final item in decoded) ?EncargoProgramado.fromJson(item)];
    } on FormatException {
      // Preferencia corrupta: se arranca sin nada. Perder las citas es malo;
      // arrastrar un estado ilegible y lanzar cualquier cosa, peor.
      return const [];
    }
  }

  @override
  Future<void> guardar(EncargoProgramado encargo) async {
    final todas = await leer();
    final sinElla = [
      for (final otra in todas)
        if (otra.id != encargo.id) otra,
    ];
    await _escribir([...sinElla, encargo]);
  }

  @override
  Future<void> borrar(String id) async {
    final todas = await leer();
    await _escribir([
      for (final encargo in todas)
        if (encargo.id != id) encargo,
    ]);
  }

  @override
  Future<void> apagar(String id, {required bool apagada}) async {
    final todas = await leer();
    await _escribir([
      for (final encargo in todas)
        if (encargo.id == id) encargo.copyWith(activo: !apagada) else encargo,
    ]);
  }

  @override
  Future<void> apuntarCorrida(String id, DateTime cuando) async {
    final todas = await leer();
    await _escribir([
      for (final encargo in todas)
        if (encargo.id == id)
          encargo.copyWith(ultimaCorrida: cuando)
        else
          encargo,
    ]);
  }

  Future<void> _escribir(List<EncargoProgramado> encargos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final encargo in encargos) encargo.toJson()]),
    );
  }
}
