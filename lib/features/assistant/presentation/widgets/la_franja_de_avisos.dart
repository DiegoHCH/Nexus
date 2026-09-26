import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/features/assistant/presentation/widgets/boton_del_registro.dart';
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
              enTinta: true,
              // Lo que un fallo ofrece es lo que lo arregla —entrar con la
              // cuenta—, así que va en el acento.
              principal: true,
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
              principal: true,
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

/// Una franja que se puede cerrar, del color de lo que cuenta.
///
/// La del mockup: ancha como la conversación, con un filo de 2 px a la izquierda
/// en el color del aviso, el texto, sus acciones como botones de fila y la ✕ al
/// final. **Cada aviso trae su salida** —«Entrar», «Hacerlo ahora»— y se cierra:
/// un error que no se va obliga a convivir con él aunque ya lo hayas leído.
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
    this.enTinta = false,
    this.principal = false,
  });

  final String message;
  final Color color;
  final VoidCallback onDismiss;

  /// El texto en tinta y el color solo en el filo. Es el caso del fallo: en el
  /// mockup, «la sesión caducó» se lee en tinta con el filo rojo; un aviso
  /// ámbar sí lleva el texto en su color.
  final bool enTinta;

  /// La primera acción es **la que toca**: se pinta en el acento. Es el
  /// «Entrar» de la sesión caducada, que es lo único que desbloquea.
  final bool principal;

  /// 🔴 **Una lista y no una sola.** Empezó siendo una porque el único aviso
  /// con salida era la sesión caducada; la tarea que se pasó tiene dos —hacerla
  /// ahora o saltarla— y con un hueco para una habría que elegir cuál se
  /// ofrece, que es justo la decisión que no queremos tomar por quien mira.
  final List<AccionDelAviso> acciones;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return DecoratedBox(
      decoration: BoxDecoration(
        // 🔴 **Opaco, y esta es la mitad del arreglo de «texto sobre texto».**
        // Antes era solo `color.withValues(alpha: 0.1)`: sin nada detrás, lo
        // que había debajo se leía a través del aviso. En la columna ya no tapa
        // nada, pero en el escenario sigue flotando, y ahí el fondo es lo que
        // lo separa de lo que haya debajo.
        color: colors.deep,
        border: Border(
          top: BorderSide(color: colors.rule2),
          right: BorderSide(color: colors.rule2),
          bottom: BorderSide(color: colors.rule2),
          left: BorderSide(color: color, width: 2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          NexusSpacing.s3,
          NexusSpacing.s2,
          NexusSpacing.s2,
          NexusSpacing.s2,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: NexusTypography.nota.copyWith(
                  color: enTinta ? colors.ink : color,
                  height: 1.4,
                ),
              ),
            ),
            for (final (i, accion) in acciones.indexed) ...[
              const SizedBox(width: NexusSpacing.s2),
              BotonDelRegistro(
                texto: accion.texto.toUpperCase(),
                tono: principal && i == 0
                    ? TonoDeBoton.principal
                    : TonoDeBoton.neutro,
                onPulsar: accion.alPulsar,
              ),
            ],
            const SizedBox(width: NexusSpacing.s2),
            // La ✕ con su caja, como un botón más de la fila: suelta y en
            // tenue no se veía que se pudiera cerrar.
            Tooltip(
              message: strings.cerrarElAviso,
              child: Semantics(
                button: true,
                label: strings.cerrarElAviso,
                child: InkWell(
                  onTap: onDismiss,
                  borderRadius: BorderRadius.circular(NexusRadius.sm),
                  child: Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.rule2),
                      borderRadius: BorderRadius.circular(NexusRadius.sm),
                    ),
                    child: Icon(Icons.close, size: 12, color: colors.ink),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
