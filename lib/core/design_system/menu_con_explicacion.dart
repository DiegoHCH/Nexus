import 'package:flutter/material.dart';
import 'package:nexus/core/design_system/nexus_colors.dart';
import 'package:nexus/core/design_system/nexus_radius.dart';
import 'package:nexus/core/design_system/nexus_spacing.dart';
import 'package:nexus/core/design_system/nexus_typography.dart';

// Los menús que se abren desde el compositor y el muelle: el globo, su
// cabecera, sus opciones y su pie. En el sistema de diseño porque los usan los
// dos, y así ninguno tiene que importar al otro para decir lo mismo con la
// misma forma.
//
// 🔴 **La forma es la del mockup (`#menus`), no la de Material.** El menú de
// Material traía filas de 48 px, una sombra negra que se leía como un segundo
// borde grueso, el tinte de superficie de M3 y el resaltado gris de la opción
// elegida: cuatro cosas que el mockup no tiene y que hacían que los seis menús
// parecieran de otra app. Aquí el globo es `deep` con su filo `rule2`, las
// filas miden lo que su texto y lo elegido se dice con peso y un «✓», no con
// un fondo.

/// El relleno del suave de acento: lo que se pinta bajo la fila que tiene el
/// puntero o el foco. El mismo 12 % que [Opcion] y el filtro usan para «lo
/// elegido», porque en un menú lo que está bajo el puntero es lo que se va a
/// elegir.
Color _suave(NexusColors colors) => colors.accent.withValues(alpha: 0.12);

/// Un menú del compositor: el botón que lo abre y el globo que se despliega.
///
/// Envuelve un [PopupMenuButton] para que los seis menús compartan **una**
/// forma —color, filo, radio, relleno y sin sombra— en vez de repetirla en cada
/// sitio y dejar que uno se desvíe, que es lo que pasó con el de «Nueva», que
/// ni siquiera fijaba el color de fondo.
class MenuDelCompositor<T> extends StatelessWidget {
  const MenuDelCompositor({
    super.key,
    required this.itemBuilder,
    required this.child,
    this.onSelected,
    this.onOpened,
    this.enabled = true,
    this.tooltip = '',
    this.ancho,
  });

  final PopupMenuItemBuilder<T> itemBuilder;
  final Widget child;
  final PopupMenuItemSelected<T>? onSelected;
  final VoidCallback? onOpened;
  final bool enabled;

  /// Vacío por defecto: el globo de ayuda tapaba el menú al abrirlo.
  final String tooltip;

  /// El ancho del globo. **Fijo por menú**, como en el mockup —300 el «+» y el
  /// esfuerzo, 330 el permiso, el modelo y el cupo, 210 «Nueva»—: con el ancho
  /// que pida el texto, el pie de una frase larga ensanchaba el menú entero.
  final double? ancho;

  /// El relleno del globo. Las cabeceras y el pie quedan a 16 del borde y el
  /// texto de las opciones a 26, porque la opción lleva sus 10 de dentro: la
  /// misma sangría del mockup, que separa lo que se elige de lo que lo rotula.
  static const relleno = EdgeInsets.symmetric(
    horizontal: NexusSpacing.s4,
    vertical: NexusSpacing.s3,
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ancho = this.ancho;
    return PopupMenuButton<T>(
      tooltip: tooltip,
      enabled: enabled,
      onSelected: onSelected,
      onOpened: onOpened,
      itemBuilder: itemBuilder,
      color: colors.deep,
      // Sin sombra ni tinte: el filo `rule2` ya separa el globo de lo que
      // tapa, y la sombra de Material sobre el fondo `void` se leía como un
      // segundo borde negro de tres píxeles.
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NexusRadius.md),
        side: BorderSide(color: colors.rule2),
      ),
      menuPadding: relleno,
      constraints: ancho == null
          ? null
          : BoxConstraints(minWidth: ancho, maxWidth: ancho),
      child: child,
    );
  }
}

/// La cabecera de un menú: de qué es lo que se elige.
///
/// Todos siguen la misma regla —opciones con nombre y, debajo, lo que cuesta o
/// lo que cambia— y la cabecera es la mitad de esa regla: «Permiso en nexus»
/// dice de quién es el permiso antes de elegirlo, que es justo lo que hizo
/// creer que era de la app cuando el menú decía «Permiso» a secas.
///
/// En mayúsculas y con tracking, como todo rótulo del instrumento: se lee
/// como el nombre del menú y no como una opción más. Sirve también para los
/// apartados de dentro —«Versiones anteriores»—, que son lo mismo a otra
/// altura.
PopupMenuItem<T> cabeceraDelMenu<T>(
  BuildContext context,
  String texto, {
  Color? color,
}) => PopupMenuItem<T>(
  enabled: false,
  height: 26,
  padding: EdgeInsets.zero,
  child: Text(
    texto.toUpperCase(),
    style: NexusTypography.label.copyWith(color: color ?? context.colors.mute),
  ),
);

/// El pie de un menú: lo que implica elegir aquí, en una frase. En sans y en
/// `mute`, que se lee: es una explicación, no un dato.
PopupMenuItem<T> pieDelMenu<T>(BuildContext context, String texto) =>
    PopupMenuItem<T>(
      enabled: false,
      height: 0,
      padding: const EdgeInsets.only(
        top: NexusSpacing.s1,
        bottom: NexusSpacing.s1,
      ),
      child: Text(
        texto,
        style: NexusTypography.nota.copyWith(
          color: context.colors.mute,
          // Un punto por debajo de las opciones, como en el mockup: el pie
          // acompaña a lo que se elige, no compite con ello.
          fontSize: 12,
          height: 1.45,
        ),
      ),
    );

/// La raya entre grupos: el `rule` de siempre, con 4 px de aire a cada lado.
PopupMenuEntry<T> rayaDelMenu<T>() => const PopupMenuDivider(height: 9);

/// Una opción de menú con la forma del mockup: el nombre a la izquierda y, a
/// la derecha, su atajo o su valor.
///
/// **Propia y no un [PopupMenuItem]** porque éste pinta su resaltado con el
/// `hoverColor` del tema —un gris que el mockup no tiene— y a toda la anchura
/// del globo, sin radio. Aquí la fila es un [InkWell] con el suave de acento y
/// sus 4 px de radio, y sigue siendo enfocable y pulsable con el teclado.
///
/// [elegida] se dice como el mockup: el nombre en peso medio y un «✓» al
/// final. Sin fondo, porque el fondo ya es de lo que está bajo el puntero.
///
/// Con [explicacion] se pinta en su caja —el `.op` del mockup—: el nombre y,
/// debajo, qué implica. Es la forma del permiso, donde lo que se elige necesita
/// una frase para entenderse antes de pulsarlo. [tono] es el color de la
/// elegida en caja: acento por defecto, ámbar para «puede editar».
class OpcionDelMenu<T> extends PopupMenuEntry<T> {
  const OpcionDelMenu({
    super.key,
    required this.value,
    required this.titulo,
    this.alLado,
    this.elegida = false,
    this.explicacion,
    this.tono,
    this.apagada = false,
    this.alLadoEsDato = true,
    this.destacada = false,
  });

  final T value;
  final String titulo;

  /// El atajo —«⌘,», «/parte»—, la cuenta —«work»— o el extremo de una escala
  /// —«Más rápido»—. Lo que acompaña al nombre sin ser el nombre.
  final String? alLado;

  final bool elegida;
  final String? explicacion;
  final Color? tono;

  /// En gris: se puede elegir, pero pesa menos —«Sin proyecto» frente a las
  /// carpetas de verdad—.
  final bool apagada;

  /// Si [alLado] es un dato —un atajo, una cuenta— y va en mono, o una palabra
  /// —«Más rápido»— y va en sans. El mockup los pinta igual, pero la regla de
  /// la casa es que el mono es solo para datos.
  final bool alLadoEsDato;

  /// En peso medio pero sin «✓»: no es lo elegido, es lo que tienes delante
  /// —la carpeta de la conversación en foco, en «Nueva»—.
  final bool destacada;

  /// La altura de una fila sin caja: 34 del mockup (7 + texto + 7) más 4 de
  /// aire arriba y abajo, que en el mockup son los 8 de separación del globo.
  static const _alto = 42.0;

  @override
  double get height => explicacion == null ? _alto : 64;

  @override
  bool represents(T? value) => value == this.value;

  @override
  State<OpcionDelMenu<T>> createState() => _OpcionDelMenuState<T>();
}

class _OpcionDelMenuState<T> extends State<OpcionDelMenu<T>> {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final w = widget;
    void elegir() => Navigator.of(context).pop<T>(w.value);

    if (w.explicacion case final explicacion?) {
      final tono = w.tono ?? colors.accent;
      return Semantics(
        button: true,
        selected: w.elegida,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: NexusSpacing.s1),
          child: InkWell(
            onTap: elegir,
            hoverColor: _suave(colors),
            focusColor: _suave(colors),
            highlightColor: _suave(colors),
            borderRadius: BorderRadius.circular(NexusRadius.sm),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                // La elegida en acento lleva su relleno suave; la de editar,
                // en ámbar, va solo con el filo: un fondo ámbar se leería
                // como aviso, y lo que dice es «esto es lo que hay».
                color: w.elegida && w.tono == null ? _suave(colors) : null,
                border: Border.all(color: w.elegida ? tono : colors.rule2),
                borderRadius: BorderRadius.circular(NexusRadius.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    w.titulo,
                    style: NexusTypography.nota.copyWith(
                      fontSize: 12.5,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                      color: !w.elegida ? colors.mute : (w.tono ?? colors.ink),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    explicacion,
                    style: NexusTypography.nota.copyWith(
                      fontSize: 11.5,
                      height: 1.3,
                      color: w.elegida ? colors.mute : colors.faint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final alLado = w.alLado;
    return Semantics(
      button: true,
      selected: w.elegida,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: NexusSpacing.s1),
        child: InkWell(
          onTap: elegir,
          hoverColor: _suave(colors),
          focusColor: _suave(colors),
          highlightColor: _suave(colors),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    w.titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: NexusTypography.nota.copyWith(
                      height: 1.35,
                      color: w.apagada ? colors.mute : colors.ink,
                      fontWeight: w.elegida || w.destacada
                          ? FontWeight.w500
                          : null,
                    ),
                  ),
                ),
                if (alLado != null)
                  Padding(
                    padding: const EdgeInsets.only(left: NexusSpacing.s4),
                    child: Text(
                      alLado,
                      style: w.alLadoEsDato
                          ? NexusTypography.data.copyWith(color: colors.mute)
                          : NexusTypography.nota.copyWith(
                              fontSize: 12,
                              color: colors.mute,
                            ),
                    ),
                  ),
                if (w.elegida)
                  Padding(
                    padding: const EdgeInsets.only(left: NexusSpacing.s2),
                    child: Text(
                      '✓',
                      style: NexusTypography.data.copyWith(color: colors.mute),
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
