import 'package:nexus/features/programadas/domain/entities/encargo_programado.dart';

/// Dónde viven los encargos programados.
///
/// Un puerto y no una función suelta porque lo van a mirar dos sitios que no se
/// conocen: el reloj que los dispara y la lista que los enseña. Y porque lo que
/// hay debajo —hoy las preferencias, como el resto del estado de la app— no
/// tiene por qué saberlo ninguno de los dos.
abstract interface class LasProgramadas {
  /// Todas, activas y apagadas. La lista completa: quien la enseñe decide cómo
  /// se ven las apagadas, y quien las dispare ya sabe saltárselas.
  Future<List<EncargoProgramado>> leer();

  /// Guarda una nueva o reemplaza la que tenga su mismo `id`.
  Future<void> guardar(EncargoProgramado encargo);

  /// La borra para siempre.
  ///
  /// 🔴 **Es lo contrario de [apagar], y las dos hacen falta.** Pedido así:
  /// «cuando ya no necesite esa tarea, poder borrarla o cancelarla… o
  /// desactivarla». Borrar es para lo que ya no va a volver; apagar es para
  /// volver a encenderlo el mes que viene sin tener que acordarse de cómo se
  /// escribía. Ofrecer solo una de las dos obliga a usarla para todo.
  Future<void> borrar(String id);

  /// La deja quieta sin perder lo escrito. Ver [borrar].
  Future<void> apagar(String id, {required bool apagada});

  /// Apunta que acaba de correr, que es lo que impide que corra dos veces.
  ///
  /// Dos veces la misma tarea es peor que ninguna: la segunda pisa lo que hizo
  /// la primera. Ver `LoQueTocaLanzar`.
  Future<void> apuntarCorrida(String id, DateTime cuando);
}
