#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Correr algo de AVFAudio **sin que una excepción termine el proceso**.
///
/// 🔴 Existe por tres cierres inesperados en ocho días, los tres iguales de
/// fondo: AVFAudio no devuelve errores para sus precondiciones, **levanta una
/// `NSException`**, y una `NSException` no la atrapa Swift — sale por
/// `objc_exception_throw`, nadie la recoge, y `abort()`.
///
/// - 7 sep, 1.9.0: desde `installTapOnBus`, «format mismatch».
/// - 11 sep, 1.12.2: desde `-[AVAudioPlayerNode play]`, remontando por un
///   cambio de aparato.
/// - 14 sep, 1.12.3: desde `play()` otra vez, ya con el guardia de
///   `engine.isRunning` puesto — o sea que la precondición que fallaba era
///   otra, y adivinar la siguiente es el mismo error una tercera vez.
///
/// Por eso esto no comprueba nada: **atrapa y cuenta**. El mensaje de la
/// excepción —«required condition is false: …»— es exactamente el dato que
/// faltaba en los tres informes de fallo, y ahora llega al registro y al
/// `FlutterError` en vez de morir con el proceso.
@interface NexusSinReventar : NSObject

/// `YES` si el bloque terminó; `NO` si levantó una excepción, y entonces
/// [error] trae su nombre y su motivo.
+ (BOOL)correr:(NS_NOESCAPE void (^)(void))bloque error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
