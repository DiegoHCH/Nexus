import 'package:flutter/widgets.dart';

/// **El navegador de la ventana principal de Nexus**, para lo que tiene que
/// abrir algo en ella sin tener un `BuildContext` suyo a mano: el hub de
/// dispositivos, que corre en su propio motor, abre aquí el panel completo de
/// pruebas (T15).
final navegadorDeLaApp = GlobalKey<NavigatorState>();
