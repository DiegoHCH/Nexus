import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/features/remote/domain/actualizacion_del_mac.dart';

// Lo que el canal pregunta del actualizador del Mac.
//
// 🔴 **Declarado aquí y respondido desde fuera**, igual que «si se está trabajando»
// en el actualizador. Quien sabe si hay versión nueva es la feature de
// actualizaciones, y que el canal la importara sería colgar el canal de Sparkle; y al
// revés, el actualizador no tiene por qué saber que existe un teléfono. Así que aquí
// se pregunta con «no hay» por defecto, y la raíz de la app conecta las dos
// (`main.dart`). Sin conectar —en las pruebas del canal, o en el teléfono— el canal
// funciona igual: solo no ofrece actualizar.

/// La actualización que el Mac ofrece ahora, vista como la ve el teléfono. `null`
/// si no hay ninguna.
final actualizacionDelMacProvider = Provider<ActualizacionDelMac?>(
  (ref) => null,
);

/// Quien cumple el sí y el «luego» del teléfono. `null` si no hay actualizador.
final actualizadorRemotoProvider = Provider<ActualizadorRemoto?>((ref) => null);

/// La versión de Nexus que corre en este Mac, para el saludo. `null` si no se sabe.
///
/// Se dice en el saludo para que el teléfono pueda **comprobar** que la
/// actualización salió bien en vez de suponerlo: es lo único que prueba que el Mac
/// volvió en la versión nueva.
///
/// 🔴 **Un `Future` y no un valor**, y el canal lo espera antes de escuchar. Leerla
/// del paquete es asíncrono, y justo después de un reinicio el teléfono llama a la
/// puerta cada pocos segundos: el primer saludo de la versión nueva —el que decide
/// si salió bien— llegaba con la versión todavía por leer, y el teléfono se quedaba
/// sin poder afirmar nada.
final versionDelMacProvider = FutureProvider<String?>((ref) async => null);
