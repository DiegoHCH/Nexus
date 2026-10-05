/// Las carpetas del Mac, para abrir una conversación en una que no está
/// emparejada. Ver `DondeAbrirLaConversacion`.
abstract interface class LasCarpetasDelDisco {
  /// Si [ruta] es una carpeta que existe.
  Future<bool> existe(String ruta);

  /// Las carpetas de tu home que se llaman [nombre], tolerando cómo se diga:
  /// «front mobile b2c» encuentra `front-mobile-b2c`.
  Future<List<String>> lasQueSeLlaman(String nombre);

  /// Si [ruta] es la raíz de un repositorio git. Es el desempate cuando varias
  /// carpetas se llaman igual: la que es un proyecto suele ser la que se dice.
  Future<bool> esUnRepo(String ruta);
}
