import 'package:nexus/features/onboarding/domain/entities/pasos_del_arranque.dart';

/// Los pasos del arranque que se dejaron para luego.
///
/// Se guardan para que Ajustes pueda ofrecer retomarlos: saltar un paso tiene
/// que ser **aplazarlo**, no perderlo. Sin esto, «Ahora no» era «nunca», porque
/// el arranque no vuelve a salir en cuanto hay una carpeta.
abstract class LoQueQuedoParaLuego {
  Future<Set<QueSePide>> leer();

  Future<void> guardar(Set<QueSePide> pasos);
}
