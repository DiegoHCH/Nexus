import 'package:flutter/material.dart';

import 'boton_de_fila.dart';
import 'nexus_colors.dart';
import 'nexus_radius.dart';
import 'nexus_typography.dart';

/// La gramática de una sección de Ajustes, pieza a pieza.
///
/// 🔴 **Existe porque cada sección se pintaba a su manera.** Diecinueve
/// secciones escritas en momentos distintos acabaron con diecinueve márgenes,
/// tres maneras de decir «guardado» y desplegables donde el mockup pone las
/// opciones a la vista. El mockup (`nexus-orbe-plasma.html`, `#ajustes`) las
/// describe todas con **los mismos diez bloques** —rótulo, texto, elegir,
/// apagado/encendido, campo, estado, filas, nota, botones y caja— y aquí están
/// esos diez, una vez. Una sección nueva se escribe juntándolos, no
/// inventando otro margen.
///
/// Vive en el sistema de diseño y no en `workspace` porque cinco de las
/// secciones son de otras features —memoria, móvil, emuladores, superpoderes,
/// estadísticas— y todas tienen que hablar igual.

/// El ancho de lectura de una explicación: ~62 caracteres, como el mockup.
///
/// Más allá, la vista tiene que volver demasiado lejos para encontrar el
/// principio de la línea siguiente.
const double anchoDeLecturaDeAjustes = 560;

/// Una sección entera: sus bloques uno debajo de otro, **separados por una
/// línea**, y con rueda cuando no caben.
///
/// La línea la pone esta lista y no cada bloque porque el primero no la
/// lleva —va pegado al título— y un bloque no sabe si es el primero. Por eso
/// lo que se esconde se quita de la lista con un `if`, no devolviendo un
/// hueco: un hueco dibujaría dos líneas seguidas.
class BloquesDeAjustes extends StatelessWidget {
  const BloquesDeAjustes({super.key, required this.bloques});

  final List<Widget> bloques;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, bloque) in bloques.indexed)
            Container(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 16, bottom: 16),
              decoration: i == 0
                  ? null
                  : BoxDecoration(
                      border: Border(top: BorderSide(color: colors.rule)),
                    ),
              child: bloque,
            ),
        ],
      ),
    );
  }
}

/// Un bloque: su rótulo, si lo tiene, y lo que decide debajo.
///
/// Nueve píxeles entre pieza y pieza, como el mockup: lo bastante juntas para
/// leerse como una sola pregunta, y la línea de [BloquesDeAjustes] separa una
/// pregunta de la siguiente.
class BloqueDeAjustes extends StatelessWidget {
  const BloqueDeAjustes({super.key, this.rotulo, required this.hijos});

  final String? rotulo;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    final rotulo = this.rotulo;
    final piezas = [if (rotulo != null) RotuloDeAjustes(rotulo), ...hijos];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, pieza) in piezas.indexed) ...[
          if (i > 0) const SizedBox(height: 9),
          pieza,
        ],
      ],
    );
  }
}

/// El rótulo de un bloque: «SOBRE TUS ARCHIVOS», en el instrumento y en
/// `mute`.
///
/// En `mute` y no en `faint`: el rótulo es lo que se busca al recorrer la
/// sección con la vista, y en `faint` se perdía contra el fondo.
class RotuloDeAjustes extends StatelessWidget {
  const RotuloDeAjustes(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) => Text(
    texto.toUpperCase(),
    style: NexusTypography.label.copyWith(color: context.colors.mute),
  );
}

/// Una explicación, en sans y `mute`, que se lee de corrido.
///
/// Lo que va entre `**dos asteriscos**` sale en `ink` y un punto más grueso:
/// es como el mockup marca lo que importa de la frase —«vive en **Qué puede
/// hacer › Llaves**», «lo reconoce **este Mac**»—. Antes los asteriscos se
/// pintaban tal cual, porque nada los leía.
class TextoDeAjustes extends StatelessWidget {
  const TextoDeAjustes(this.texto, {super.key, this.color, this.tamano = 14});

  final String texto;

  /// Otro color para todo el texto: el `warn` de «no hay ninguna».
  final Color? color;

  /// 14 el cuerpo de la sección; 12 las aclaraciones al pie.
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final base = NexusTypography.nota.copyWith(
      fontSize: tamano,
      height: 1.55,
      color: color ?? colors.mute,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: anchoDeLecturaDeAjustes),
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            for (final (i, trozo) in texto.split('**').indexed)
              TextSpan(
                text: trozo,
                style: i.isOdd
                    ? TextStyle(color: colors.ink, fontWeight: FontWeight.w500)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

/// Una opción con nombre, y debajo lo que cuesta si hace falta decirlo.
///
/// Contorno para «disponible» y relleno suave de acento para «elegida»: la
/// tabla de formas del mockup, al pie de la letra. El nombre en sans y no en
/// el instrumento porque es lo que se elige y se lee como palabra —«Kore ·
/// firme», «De Colombia»—, no como un mando.
///
/// 🔴 **La pista va en sans, no en mono como la dibuja el mockup.** La propia
/// postura del mockup lo prohíbe —«mono para datos, **no** para explicar»— y
/// «nada se escribe» o «punto naranja todo el rato» son explicaciones.
class OpcionDeAjustes extends StatelessWidget {
  const OpcionDeAjustes({
    super.key,
    required this.nombre,
    required this.elegida,
    required this.onPulsar,
    this.pista,
    this.discontinua = false,
    this.sePuedeSoltar = false,
  });

  final String nombre;
  final String? pista;
  final bool elegida;

  /// Nulo cuando no se puede elegir.
  final VoidCallback? onPulsar;

  /// Con el borde discontinuo: «+25 voces», que no es una opción sino la
  /// puerta a las demás.
  final bool discontinua;

  /// Elegida, se vuelve a pulsar para soltarla: una opción sola que es un sí
  /// o un no —«En todas las cuentas»—. Entre varias no hace falta, porque se
  /// suelta eligiendo otra.
  final bool sePuedeSoltar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pista = this.pista;
    final contenido = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          nombre,
          style: NexusTypography.nota.copyWith(
            fontSize: 12.5,
            height: 1.2,
            color: elegida ? colors.ink : colors.mute,
          ),
        ),
        if (pista != null && pista.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            pista,
            style: NexusTypography.nota.copyWith(
              fontSize: 11,
              height: 1.3,
              color: elegida ? colors.mute : colors.faint,
            ),
          ),
        ],
      ],
    );

    return Semantics(
      button: true,
      selected: elegida,
      enabled: onPulsar != null,
      child: InkWell(
        onTap: elegida && !sePuedeSoltar ? null : onPulsar,
        borderRadius: BorderRadius.circular(NexusRadius.sm),
        child: CustomPaint(
          foregroundPainter: discontinua
              ? _BordeDiscontinuo(color: colors.rule2)
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: elegida ? colors.accent.withValues(alpha: 0.12) : null,
              border: discontinua
                  ? null
                  : Border.all(color: elegida ? colors.accent : colors.rule2),
              borderRadius: BorderRadius.circular(NexusRadius.sm),
            ),
            child: contenido,
          ),
        ),
      ),
    );
  }
}

class _BordeDiscontinuo extends CustomPainter {
  const _BordeDiscontinuo({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const trazo = 3.0;
    void linea(Offset a, Offset b) {
      final largo = (b - a).distance;
      final paso = (b - a) / largo;
      for (var d = 0.0; d < largo; d += trazo * 2) {
        final fin = d + trazo > largo ? largo : d + trazo;
        canvas.drawLine(a + paso * d, a + paso * fin, pincel);
      }
    }

    final r = Offset.zero & size;
    final d = r.deflate(0.5);
    linea(d.topLeft, d.topRight);
    linea(d.topRight, d.bottomRight);
    linea(d.bottomRight, d.bottomLeft);
    linea(d.bottomLeft, d.topLeft);
  }

  @override
  bool shouldRepaint(_BordeDiscontinuo oldDelegate) =>
      oldDelegate.color != color;
}

/// Elegir una entre pocas, **con todas a la vista**.
///
/// Sustituye a los desplegables de Ajustes: un desplegable esconde lo que hay
/// hasta que se abre, y para saber qué acentos había o por dónde podía sonar
/// había que pulsarlo. Con las opciones en fila se ve qué hay antes de elegir.
///
/// [cuantasSeVen] recorta una lista larga —las treinta voces— a las primeras,
/// con una opción discontinua «+N» que enseña las demás. La elegida se ve
/// siempre, aunque esté más allá del recorte.
class ElegirDeAjustes<T> extends StatefulWidget {
  const ElegirDeAjustes({
    super.key,
    required this.opciones,
    required this.elegida,
    required this.nombre,
    required this.onElegir,
    this.pista,
    this.cuantasSeVen,
    this.masOpciones,
    this.llave,
  });

  final List<T> opciones;
  final T elegida;
  final String Function(T opcion) nombre;
  final String? Function(T opcion)? pista;
  final ValueChanged<T> onElegir;
  final int? cuantasSeVen;

  /// Cómo se dice «+25 voces»: recibe cuántas quedan escondidas.
  final String Function(int escondidas)? masOpciones;

  /// Prefijo de la llave de cada opción: `<llave>-<índice>`, para pulsarlas
  /// desde una prueba sin depender del texto.
  final String? llave;

  @override
  State<ElegirDeAjustes<T>> createState() => _ElegirDeAjustesState<T>();
}

class _ElegirDeAjustesState<T> extends State<ElegirDeAjustes<T>> {
  bool _todas = false;

  @override
  Widget build(BuildContext context) {
    final tope = widget.cuantasSeVen;
    final recortar =
        !_todas && tope != null && widget.opciones.length > tope + 1;
    final visibles = recortar
        ? [
            ...widget.opciones.take(tope),
            if (!widget.opciones.take(tope).contains(widget.elegida))
              widget.elegida,
          ]
        : widget.opciones;
    final escondidas = widget.opciones.length - visibles.length;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final opcion in visibles)
          OpcionDeAjustes(
            key: widget.llave == null
                ? null
                : ValueKey(
                    '${widget.llave}-${widget.opciones.indexOf(opcion)}',
                  ),
            nombre: widget.nombre(opcion),
            pista: widget.pista?.call(opcion),
            elegida: opcion == widget.elegida,
            onPulsar: () => widget.onElegir(opcion),
          ),
        if (recortar && escondidas > 0)
          OpcionDeAjustes(
            key: widget.llave == null ? null : ValueKey('${widget.llave}-mas'),
            nombre: widget.masOpciones?.call(escondidas) ?? '+$escondidas',
            elegida: false,
            discontinua: true,
            onPulsar: () => setState(() => _todas = true),
          ),
      ],
    );
  }
}

/// Qué dice un punto de estado.
enum TonoDeAjustes {
  bien,
  atencion,
  fallo,

  /// Lo que está pasando ahora mismo: la carpeta activa, el emulador que está
  /// arriba. Acento, con un poco de halo.
  activo,

  /// Apagado, sin poner, cerrado: no es un fallo, es que no hay nada.
  apagado;

  Color color(NexusColors colors) => switch (this) {
    TonoDeAjustes.bien => colors.ok,
    TonoDeAjustes.atencion => colors.warn,
    TonoDeAjustes.fallo => colors.err,
    TonoDeAjustes.activo => colors.accent,
    TonoDeAjustes.apagado => colors.faint,
  };
}

class _Punto extends StatelessWidget {
  const _Punto(this.tono);

  final TonoDeAjustes tono;

  @override
  Widget build(BuildContext context) {
    final color = tono.color(context.colors);
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: tono == TonoDeAjustes.activo
            ? [BoxShadow(color: color, blurRadius: 8)]
            : null,
      ),
    );
  }
}

/// Un estado dicho con su punto delante, y **con el texto del color del
/// punto**: «● Concedido. Habla un momento…» en verde.
///
/// El color no va solo nunca —la frase dice lo mismo—, pero pintarla entera
/// hace que el estado se lea de un barrido sin buscar el punto.
class EstadoDeAjustes extends StatelessWidget {
  const EstadoDeAjustes({super.key, required this.tono, required this.texto});

  final TonoDeAjustes tono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = tono == TonoDeAjustes.apagado
        ? colors.mute
        : tono.color(colors);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Centrado con la primera línea, que es la que nombra el estado.
        Padding(padding: const EdgeInsets.only(top: 7), child: _Punto(tono)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            texto,
            style: NexusTypography.nota.copyWith(
              fontSize: 13.5,
              height: 1.5,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Filas de un registro: una línea de 1 px entre cada una y ninguna arriba.
class FilasDeAjustes extends StatelessWidget {
  const FilasDeAjustes({super.key, required this.filas});

  final List<Widget> filas;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, fila) in filas.indexed)
          DecoratedBox(
            decoration: BoxDecoration(
              border: i == 0
                  ? null
                  : Border(top: BorderSide(color: colors.rule)),
            ),
            child: fila,
          ),
      ],
    );
  }
}

/// Una fila: su punto de estado, qué es —con el dato debajo, en mono— y la
/// acción que le toca, a la derecha.
///
/// El dato en mono porque es lo que es: «work · voz · puede editar»,
/// «100.73.35.55:7845», «12 pruebas». El nombre en sans porque se lee.
class FilaDeAjustes extends StatelessWidget {
  const FilaDeAjustes({
    super.key,
    required this.titulo,
    this.tono,
    this.dato,
    this.accion,
    this.tituloEnMono = false,
    this.onPulsar,
  });

  /// Sin tono, la fila no lleva punto: la guía de Ayuda, que no tiene estado.
  final TonoDeAjustes? tono;
  final String titulo;
  final String? dato;
  final Widget? accion;

  /// El título es un dato: una ruta, el nombre de una variable.
  final bool tituloEnMono;

  /// Toda la fila se pulsa: los enlaces de la guía.
  final VoidCallback? onPulsar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tono = this.tono;
    final dato = this.dato;
    final accion = this.accion;
    final fila = Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 14,
            child: tono == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: _Punto(tono),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: tituloEnMono
                      ? NexusTypography.mono.copyWith(color: colors.ink)
                      : NexusTypography.nota.copyWith(
                          fontSize: 13.5,
                          height: 1.5,
                          color: colors.ink,
                        ),
                ),
                if (dato != null && dato.isNotEmpty)
                  Text(
                    dato,
                    style: NexusTypography.data.copyWith(
                      height: 1.45,
                      color: colors.mute,
                    ),
                  ),
              ],
            ),
          ),
          if (accion != null) ...[const SizedBox(width: 10), accion],
        ],
      ),
    );
    if (onPulsar == null) return fila;
    return InkWell(onTap: onPulsar, child: fila);
  }
}

/// Lo que cuesta algo, con la línea `warn` a la izquierda: «Se guardan las 30
/// últimas. Lo que crezca aquí se paga en cada turno».
///
/// No es un aviso de fallo —no va en rojo ni en amarillo entero—: es la letra
/// pequeña que conviene leer antes de decidir, y la línea es lo que la
/// distingue de una explicación cualquiera.
class NotaDeAjustes extends StatelessWidget {
  const NotaDeAjustes(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: anchoDeLecturaDeAjustes),
      child: Container(
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: colors.warn, width: 2)),
        ),
        child: Text(
          texto,
          style: NexusTypography.nota.copyWith(color: colors.mute),
        ),
      ),
    );
  }
}

/// Un botón de Ajustes: el instrumento, en mayúsculas pequeñas, como «CERRAR
/// · ESC» en la barra.
///
/// Aparte de [BotonDeFila] porque el mockup los dibuja distintos: en una fila
/// de corrida la acción va en minúscula y apretada, y en Ajustes es un rótulo
/// que se pulsa —«AÑADIR CARPETA», «OLVIDAR»—, con el mismo tamaño y tracking
/// que los rótulos de bloque para que la hoja entera hable con una sola voz.
class BotonDeAjustes extends StatelessWidget {
  const BotonDeAjustes({
    super.key,
    required this.texto,
    required this.onPulsar,
    this.tono = TonoDeBoton.neutro,
    this.tooltip,
  });

  final String texto;
  final VoidCallback? onPulsar;
  final TonoDeBoton tono;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final activo = onPulsar != null;
    final color = !activo
        ? colors.faint
        : switch (tono) {
            TonoDeBoton.principal => colors.accent,
            TonoDeBoton.peligro => colors.err,
            TonoDeBoton.bien => colors.ok,
            TonoDeBoton.neutro => colors.ink,
          };
    final borde = !activo
        ? colors.rule
        : switch (tono) {
            TonoDeBoton.principal => colors.accent,
            TonoDeBoton.peligro => colors.err.withValues(alpha: 0.45),
            TonoDeBoton.bien => colors.ok.withValues(alpha: 0.45),
            TonoDeBoton.neutro => colors.rule2,
          };

    final boton = OutlinedButton(
      onPressed: onPulsar,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(color: borde),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NexusRadius.sm),
        ),
      ),
      child: Text(
        texto.toUpperCase(),
        maxLines: 1,
        style: NexusTypography.label.copyWith(
          letterSpacing: 1.4,
          height: 1,
          color: color,
        ),
      ),
    );
    if (tooltip case final mensaje? when mensaje.isNotEmpty) {
      return Tooltip(message: mensaje, child: boton);
    }
    return boton;
  }
}

/// Un estado dicho con la misma caja que un botón, pero que **no se pulsa**:
/// «SALIENDO», «CERRADA» al final de una fila de «Qué sale».
///
/// Con la forma del botón porque así lo dibuja el mockup —la columna de la
/// derecha de cada fila es siempre lo que esa fila dice de sí misma—, y sin
/// tinta ni cursor porque ahí no hay nada que decidir: esa sección se mira.
class EtiquetaDeAjustes extends StatelessWidget {
  const EtiquetaDeAjustes(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: colors.rule2),
        borderRadius: BorderRadius.circular(NexusRadius.sm),
      ),
      child: Text(
        texto.toUpperCase(),
        maxLines: 1,
        style: NexusTypography.label.copyWith(
          letterSpacing: 1.4,
          height: 1,
          color: colors.ink,
        ),
      ),
    );
  }
}

/// Los botones de un bloque, en fila y con hueco para bajar de línea.
class AccionesDeAjustes extends StatelessWidget {
  const AccionesDeAjustes({super.key, required this.botones});

  final List<Widget> botones;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: botones);
}

/// Un recuadro para lo que se enseña y no se decide: la vista previa de los
/// nombres, la onda del micrófono.
class CajaDeAjustes extends StatelessWidget {
  const CajaDeAjustes({super.key, required this.child, this.padding = 12});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: colors.void_,
        border: Border.all(color: colors.rule),
        borderRadius: BorderRadius.circular(NexusRadius.sm),
      ),
      child: child,
    );
  }
}

/// Cómo se ve un campo de Ajustes: **una línea debajo**, sin caja, y el valor
/// en mono.
///
/// En mono porque lo que se escribe aquí es un dato —una ruta, un nombre, unos
/// comandos—. Sin caja porque una caja rellena se lee como formulario web, y
/// el mockup los dibuja como una línea que se rellena.
InputDecoration decoracionDeCampoDeAjustes(
  BuildContext context, {
  String? hint,
}) {
  final colors = context.colors;
  return InputDecoration(
    hintText: hint,
    hintStyle: NexusTypography.mono.copyWith(color: colors.faint),
    filled: false,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(vertical: 6),
    border: UnderlineInputBorder(borderSide: BorderSide(color: colors.rule2)),
    enabledBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: colors.rule2),
    ),
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: colors.accent),
    ),
  );
}

/// El estilo del valor de un campo de Ajustes, a juego con
/// [decoracionDeCampoDeAjustes].
TextStyle estiloDeCampoDeAjustes(BuildContext context) =>
    NexusTypography.mono.copyWith(color: context.colors.ink);

/// Un campo que solo se lee: la ruta del registro, los comandos vetados. La
/// misma línea que uno que se escribe, para que se reconozcan como lo mismo.
class CampoDeAjustes extends StatelessWidget {
  const CampoDeAjustes(this.valor, {super.key, this.vacio});

  final String? valor;

  /// Lo que se lee cuando no hay valor, en `faint`.
  final String? vacio;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final valor = this.valor;
    final lleno = valor != null && valor.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.rule2)),
      ),
      child: SelectableText(
        lleno ? valor : (vacio ?? ''),
        style: NexusTypography.mono.copyWith(
          height: 1.3,
          color: lleno ? colors.ink : colors.faint,
        ),
      ),
    );
  }
}
