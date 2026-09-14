#import "NexusSinReventar.h"

@implementation NexusSinReventar

+ (BOOL)correr:(NS_NOESCAPE void (^)(void))bloque error:(NSError **)error {
  @try {
    bloque();
    return YES;
  } @catch (NSException *excepcion) {
    if (error != NULL) {
      // El nombre y el motivo juntos: `NSInternalInconsistencyException` dice
      // de qué clase es y «required condition is false: …» dice cuál era la
      // condición, que es lo único que permite arreglarla sin adivinar.
      NSString *motivo = excepcion.reason ?: @"sin motivo";
      *error = [NSError errorWithDomain:@"NexusSinReventar"
                                   code:1
                               userInfo:@{
                                 NSLocalizedDescriptionKey:
                                   [NSString stringWithFormat:@"%@: %@",
                                                              excepcion.name,
                                                              motivo]
                               }];
    }
    return NO;
  }
}

@end
