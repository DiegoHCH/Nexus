import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';

/// Lo que se puede hacer con un aviso, cuando se puede hacer algo.
///
/// La mayoría de los fallos solo se leen. Este hueco existe para los que **sí
/// tienen arreglo desde aquí**: la sesión caducada, que se resuelve abriendo el
/// navegador, o una tarea que se pasó, que se hace ahora o se salta. Un botón
/// que a veces está y a veces no es más honesto que uno permanente que casi
/// nunca sirve.
typedef AccionDelAviso = ({String texto, VoidCallback alPulsar});

/// Los avisos de la conversación, apilados y **sin flotar sobre lo que se está
/// leyendo**.
///
/// 🔴 **Nace de «queda texto sobre texto».** Reportado así: «salen encima de una
/// conversación con texto y a veces no se entiende». Eran dos defectos que se
/// sumaban, y ninguno se arreglaba retocando el texto del aviso:
///
/// - **El chip era translúcido.** El fondo iba a `alpha: 0.1` del color del
///   aviso, así que la respuesta de Claude se leía **a través** del cuadro. Dos
///   textos en el mismo sitio, los dos a medias. Ahora la base es [rise], que
///   es opaca en los dos temas, y el color va encima como tinte.
///
/// - **Y flotaba sobre la columna.** El aviso se pintaba en una capa de encima
///   con `top` fijo, tapando el primer mensaje justo cuando más se mira. La
///   conversación ya sabía apartarse para el chip de «micro abierto» —está
///   comentado en `home_page`— pero no para estos, que son los que salen a
///   diario. Así que dejan de flotar: [enColumna] los pone **dentro** del
///   flujo, encima del panel, y lo que hacen es empujar, no tapar.
///
/// Y una tercera que salió de mirar: el chip de voz y estos dos se anclaban a
/// la misma coordenada, `top: s5`. Con el micro abierto y un error a la vez se
/// dibujaban uno sobre otro, literalmente. En columna eso no puede pasar.
class LaFranjaDeAvisos extends StatelessWidget {
  const LaFranjaDeAvisos({
    required this.error,
    required this.aviso,
    super.key,
    this.perdidas = const [],
    this.enColumna = false,
  });

  /// El fallo, que es el que urge. Va arriba.
  final ({String texto, VoidCallback alCerrar, AccionDelAviso? accion})? error;

  /// Algo cambió, que no es lo mismo que algo se rompió.
  final ({String texto, VoidCallback alCerrar, AccionDelAviso? accion})? aviso;

  /// Las tareas programadas a las que les tocaba y no corrieron.
  ///
  /// 🔴 **Cada una trae su decisión, y por eso van una por fila.** No se
  /// ejecutan solas —un encargo que escribe archivos arrancando tres horas
  /// tarde no lo pidió nadie— ni se callan, que es peor: una tarea que no corrió
  /// y no deja rastro es el fallo que no se ve hasta que importa. Ver `SePaso`.
  final List<({String texto, VoidCallback hacerlaAhora, VoidCallback saltarla})>
  perdidas;

  /// `true` cuando va dentro del flujo de la conversación —el caso normal— y
  /// `false` cuando le toca flotar porque todavía no hay nada que tapar.
  ///
  /// Es lo único que cambia entre los dos sitios: flotando se separa del borde
  /// y en columna no, que ahí el hueco lo pone la propia columna.
  final bool enColumna;

  /// Si hay algo que enseñar. Lo pregunta quien monta la pantalla, para no
  /// dejar un hueco de nada cuando no hay avisos.
  bool get hayAlgo => error != null || aviso != null || perdidas.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!hayAlgo) return const SizedBox.shrink();
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.only(bottom: enColumna ? NexusSpacing.s3 : 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error case final error?)
            AvisoChip(
              message: error.texto,
              color: colors.err,
              onDismiss: error.alCerrar,
              acciones: [?error.accion],
            ),
          // Los dos pueden coincidir, así que se apilan en vez de competir por
          // el mismo hueco.
          if (error != null && aviso != null)
            const SizedBox(height: NexusSpacing.s2),
          if (aviso case final aviso?)
            AvisoChip(
              message: aviso.texto,
              // Ámbar y no rojo: algo cambió, no algo se rompió. En rojo se lee
              // como un fallo del encargo, que es justo lo que no es.
              color: colors.warn,
              onDismiss: aviso.alCerrar,
              acciones: [?aviso.accion],
            ),
          // Y las tareas que se pasaron, una por una: cada una es una decisión
          // distinta. Van las últimas porque no urgen —ya se pasaron— pero no
          // se pueden omitir.
          for (var i = 0; i < perdidas.length; i++) ...[
            if (error != null || aviso != null || i > 0)
              const SizedBox(height: NexusSpacing.s2),
            AvisoChip(
              message: perdidas[i].texto,
              color: colors.warn,
              // 🔴 **Cerrar el aviso es saltarla, y por eso se dice también con
              // un botón.** Cerrarlo sin más lo dejaría saliendo cada medio
              // minuto —la cita sigue pendiente— y un aviso que vuelve es como
              // se enseña a ignorarlos. Las dos salidas cierran la decisión.
              onDismiss: perdidas[i].saltarla,
              acciones: [
                (
                  texto: context.strings.hacerlaAhora,
                  alPulsar: perdidas[i].hacerlaAhora,
                ),
                (
                  texto: context.strings.saltarla,
                  alPulsar: perdidas[i].saltarla,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Una línea que se puede cerrar, del color de lo que cuenta.
///
/// Va acotado y con punto delante —el mismo recurso del interruptor de
/// permisos— y se puede descartar: un error que no se va obliga a convivir con
/// él aunque ya lo hayas leído.
///
/// El color entra por parámetro y no por el tipo del mensaje: son el mismo
/// objeto en pantalla y solo cambia lo que significan, así que duplicar el
/// widget para pintarlo en ámbar habría dejado dos sitios que arreglar.
class AvisoChip extends StatelessWidget {
  const AvisoChip({
    required this.message,
    required this.color,
    required this.onDismiss,
    super.key,
    this.acciones = const [],
  });

  final String message;
  final Color color;
  final VoidCallback onDismiss;

  /// 🔴 **Una lista y no una sola.** Empezó siendo una porque el único aviso
  /// con salida era la sesión caducada; la tarea que se pasó tiene dos —hacerla
  /// ahora o saltarla— y con un hueco para una habría que elegir cuál se
  /// ofrece, que es justo la decisión que no queremos tomar por quien mira.
  final List<AccionDelAviso> acciones;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: DecoratedBox(
          decoration: BoxDecoration(
            // 🔴 **Opaco, y esta es la mitad del arreglo.** Antes era solo
            // `color.withValues(alpha: 0.1)`: sin nada detrás, lo que había
            // debajo se leía a través del aviso. El tinte se queda —es lo que
            // le da el color— pero ahora va **sobre** una superficie, no sobre
            // la conversación.
            color: Color.alphaBlend(color.withValues(alpha: 0.12), colors.rise),
            border: Border.all(color: color.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(NexusRadius.sm),
            // Un aviso es una capa de encima, y decirlo con una sombra es lo
            // que lo separa del texto en vez de confundirlo con él.
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.28),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              NexusSpacing.s3,
              NexusSpacing.s2,
              NexusSpacing.s2,
              NexusSpacing.s2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
                const SizedBox(width: NexusSpacing.s3),
                Flexible(
                  child: Text(
                    message,
                    style: NexusTypography.mono.copyWith(
                      color: color,
                      height: 1.4,
                    ),
                  ),
                ),
                for (final accion in acciones) ...[
                  const SizedBox(width: NexusSpacing.s3),
                  InkWell(
                    onTap: accion.alPulsar,
                    child: Text(
                      accion.texto,
                      style: NexusTypography.mono.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: color.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: NexusSpacing.s2),
                InkWell(
                  onTap: onDismiss,
                  child: Icon(
                    Icons.close,
                    size: 13,
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
