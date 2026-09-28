import 'dart:io';

/// Si esta app se abrió **como anfitriona de las pruebas nativas** y no para
/// usarla.
///
/// `xcodebuild test` lanza la app entera para cargar dentro las pruebas de
/// Swift, y la app, al arrancar, leía la llave del llavero. Cada compilación
/// es un binario nuevo, así que macOS pedía permiso cada vez.
///
/// 🔴 Visto el 28 sep: «se abren un montón de Nexus, cada uno pide el permiso,
/// y después se cierran solos». Eran las corridas de las pruebas nativas.
///
/// La marca la pone el propio XCTest en el entorno del proceso anfitrión.
abstract final class ElAnfitrionDeLasPruebas {
  static bool get esEste => esEsteEntorno(Platform.environment);

  static bool esEsteEntorno(Map<String, String> entorno) =>
      entorno.containsKey('XCTestConfigurationFilePath') ||
      entorno.containsKey('XCTestSessionIdentifier');
}
