import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/core/design_system/nexus_colors.dart';
import 'package:nexus/core/design_system/nexus_spacing.dart';
import 'package:nexus/core/design_system/nexus_typography.dart';
import 'package:nexus/features/remote/data/channel_link.dart';
import 'package:nexus/features/remote/presentation/providers/pairing_providers.dart';

/// Las medidas del teléfono, sacadas del mockup (`#movil`, a 390 de ancho).
///
/// **Una sola vez y con nombre**: cada pantalla ponía su propio margen —20 en la lista,
/// 24 en las de estado, 16 en el compositor— y al pasar de una a otra el contenido
/// saltaba de sitio. El mockup usa el mismo en todas, y el ojo lo nota cuando falta.
abstract final class MedidasDelMovil {
  /// El margen lateral de todo: la cabecera, las listas, los botones.
  static const double margen = 18;

  /// Lo que queda libre debajo de la última acción, encima del borde del teléfono.
  static const double pie = 28;

  /// El alto de la cabecera por debajo de la barra de estado del sistema: el mockup
  /// la dibuja de 96 con 50 para la barra de estado, y la zona segura ya pone los 47.
  static const double cabecera = 49;

  /// El velo que tapa la pantalla detrás del menú y de las hojas: el fondo al 70 %, no
  /// el negro de Material. Así el tema claro se vela en claro.
  static Color velo(NexusColors colors) => colors.void_.withValues(alpha: 0.7);
}

/// La cabecera del teléfono: de dónde se viene, qué se mira y en qué anda el enlace.
///
/// **Sale de los mockups y no de Material**, y ese fue el error de la primera versión
/// de estas pantallas: se construyeron con `Theme.of(context).textTheme` y widgets de
/// Material —`Card`, `AppBar`, burbujas redondeadas— cuando el proyecto ya tenía su
/// propio sistema con los tokens exactos. El resultado no se parecía en nada a lo
/// dibujado, y la regla del repositorio dice justamente que los mockups se revisan
/// **antes** de implementar la UI.
///
/// **Una sola cabecera para todas las pantallas**, con el mismo alto y el mismo margen:
/// la conversación y las utilidades tenían un `AppBar` cada una, con su propia flecha
/// y su propio chip, y al entrar en ellas la cabecera cambiaba de forma. El mockup
/// dibuja siempre la misma fila —el menú o la vuelta `‹`, el nombre y el chip— y lo
/// único que cambia es qué nombre se dice.
///
/// `NEXUS` es el wordmark con su tracking de .42em, y el estado va a la derecha
/// como un chip. No es un adorno — es la única forma que tiene el teléfono de decir
/// que lo que enseña es un reflejo y no autonomía.
class MobileChrome extends ConsumerWidget {
  const MobileChrome({
    super.key,
    this.alMenu,
    this.alVolver,
    this.titulo,
    this.nombre,
    this.alFinal,
    this.enVezDe,
    this.sinEmparejar = false,
  });

  /// Abre el menú. `null` en las pantallas donde no hay menú que abrir —emparejar,
  /// conectando— porque un hamburguesa que no lleva a ningún sitio es peor que ninguno.
  final VoidCallback? alMenu;

  /// La vuelta, con el `‹` del mockup. En las pantallas a las que se llega desde otra.
  final VoidCallback? alVolver;

  /// Lo que se dice con la letra del wordmark en vez de `NEXUS`: «DOCUMENTOS». Es el
  /// nombre de un **sitio** de la app, así que va con la voz de la marca.
  final String? titulo;

  /// Lo que se dice en sans en vez del wordmark: el nombre de una conversación. Es
  /// algo que escribió alguien —la carpeta, el título que le puso—, no un sitio de la
  /// app, y por eso no va con la letra de la marca.
  final String? nombre;

  /// Lo que va a la derecha del chip, si hace falta algo más.
  final Widget? alFinal;

  /// Un estado que **manda sobre el real**.
  ///
  /// Existe por un fallo concreto: la pantalla de «buscando tu Mac» se retiene cinco
  /// segundos a propósito para que se vea el orbe, y en una red rápida el enlace ya
  /// está conectado antes de que acabe. El chip decía la verdad —`CONECTADO`— debajo
  /// de un título que decía «buscando». **La pantalla mentía, no el chip.**
  ///
  /// Así que quien retiene una pantalla dice también qué estado afirma. No se resuelve
  /// escondiendo el chip: un rechazo o un «no llego» que ocurran durante esos cinco
  /// segundos tienen que verse igual, y para eso el sustituto solo se usa cuando el
  /// estado real es `conectado`.
  final LinkState? enVezDe;

  /// Sin emparejar todavía: el chip dice eso y no el estado de un enlace que no
  /// existe. «Sin conexión» ahí mandaría a mirar la red, y lo que falta es emparejar.
  final bool sinEmparejar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final real = ref.watch(linkStateProvider).value ?? LinkState.sinConexion;
    // El sustituto **solo cuando el real es «conectado»**: si mientras se retiene la
    // pantalla apareciera un rechazo, taparlo sería el mismo error al revés.
    final estado = (enVezDe != null && real == LinkState.conectado)
        ? enVezDe!
        : real;
    final (texto, tono) = sinEmparejar
        ? (strings.mobileUnpaired, TonoDelChip.apagado)
        : _decir(strings, estado);

    final Widget queSeMira = switch ((titulo, nombre)) {
      (_, final String nombre) => Text(
        nombre,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: NexusTypography.body.copyWith(
          color: colors.ink,
          fontSize: 14,
          height: 1.2,
        ),
      ),
      (final String titulo, _) => Text(
        titulo.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
        style: NexusTypography.brand.copyWith(color: colors.mute),
      ),
      // `NEXUS` y no `N E X U S`: el tracking de .42em ya separa las letras, y con los
      // espacios encima la marca salía el doble de ancha que en el mockup.
      _ => Text(
        'NEXUS',
        style: NexusTypography.brand.copyWith(color: colors.mute),
      ),
    };

    return Container(
      height: MedidasDelMovil.cabecera,
      padding: const EdgeInsets.fromLTRB(
        MedidasDelMovil.margen,
        3,
        MedidasDelMovil.margen,
        0,
      ),
      child: Row(
        children: [
          if (alMenu != null) ...[
            // Tres líneas dibujadas y no `Icons.menu`: el icono de Material tiene su
            // propio grosor y sus propios remates, y al lado de las hairlines de 1px
            // de esta app se ve grueso. Estas son del mismo peso que todo lo demás.
            InkWell(
              key: const ValueKey('abrir-el-menu'),
              onTap: alMenu,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: NexusSpacing.s3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      Container(width: 18, height: 1, color: colors.mute),
                      if (i < 2) const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: NexusSpacing.s3),
          ],
          if (alVolver != null) ...[
            // El `‹` del mockup y no la flecha de Material: la flecha es el idioma de
            // otra app, y este glifo pesa lo mismo que el wordmark de al lado. El
            // toque es más grande que el glifo, que solo mide lo que se ve.
            Semantics(
              button: true,
              label: strings.mobileBack,
              child: InkWell(
                key: const ValueKey('volver'),
                onTap: alVolver,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                  child: Text(
                    '‹',
                    style: NexusTypography.control.copyWith(
                      color: colors.mute,
                      fontSize: 16,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: queSeMira),
          ),
          const SizedBox(width: NexusSpacing.s3),
          StateChip(
            key: const ValueKey('estado-del-enlace'),
            texto: texto,
            // El acento **solo cuando está conectado**. Un chip siempre encendido no
            // dice nada; el color es la información — y con el punto delante, como
            // el mockup: «estado con su color, y el texto al lado, nunca solo el
            // color».
            tono: tono,
            punto: true,
          ),
          if (alFinal != null) ...[
            const SizedBox(width: NexusSpacing.s2),
            alFinal!,
          ],
        ],
      ),
    );
  }

  /// Los estados, con las palabras del mockup donde las hay.
  ///
  /// «Reconectando» y «sin conexión» siguen siendo distintos aunque las dos digan que
  /// ahora no hay Mac: una es «el teléfono está en ello» y la otra «mira si está
  /// encendido». Y los dos que salieron de la primera prueba real —no llego, no
  /// acepta el token— piden cosas distintas: instalar Tailscale o volver a emparejar.
  (String, TonoDelChip) _decir(NexusStrings strings, LinkState estado) =>
      switch (estado) {
        LinkState.conectado => (strings.mobileLinkConnected, TonoDelChip.vivo),
        // En ámbar lo que el teléfono **está resolviendo**: buscar, reconectar,
        // ponerse al día y no llegar —que se reintenta solo—. Es «atención», no
        // «fallo»: no hay nada que tocar todavía.
        LinkState.conectando => (
          strings.mobileLinkConnecting,
          TonoDelChip.atencion,
        ),
        LinkState.reconectando => (
          strings.mobileLinkReconnecting,
          TonoDelChip.atencion,
        ),
        LinkState.resincronizando => (
          strings.mobileLinkResyncing,
          TonoDelChip.atencion,
        ),
        LinkState.noSeLlega => (
          strings.mobileLinkUnreachable,
          TonoDelChip.atencion,
        ),
        LinkState.sinConexion => (
          strings.mobileLinkOffline,
          TonoDelChip.apagado,
        ),
        // En rojo los dos que esperar no arregla: hay que hacer algo.
        LinkState.rechazado => (strings.mobileLinkRejected, TonoDelChip.fallo),
        LinkState.hayQueActualizar => (
          strings.mobileLinkMustUpdate,
          TonoDelChip.fallo,
        ),
      };
}

/// Con qué color habla un chip: los cuatro estados del mockup —bien, atención,
/// fallo, apagado— y ninguno más. Un quinto tono sería un quinto significado que
/// nadie ha aprendido.
enum TonoDelChip { vivo, atencion, fallo, apagado }

/// El chip del mockup: Oxanium en mayúsculas, con tracking, y su punto de color
/// delante cuando dice un estado.
///
/// Existe como pieza suya porque se usa para más cosas que el estado —«Interrumpido»
/// en una respuesta cortada, «Esperando» en un encargo sin salir, «Abierta» en una
/// fila del historial— y esas cosas tienen que verse iguales o el ojo las lee como
/// niveles distintos.
///
/// **Sin borde**, como el mockup: el borde lo convertía en un botón que no se podía
/// tocar. Lo que dice que es un estado es el punto; las filas lo llevan sin punto,
/// porque allí la palabra ya está pegada a lo que describe.
class StateChip extends StatelessWidget {
  const StateChip({
    super.key,
    required this.texto,
    this.vivo = false,
    this.tono,
    this.punto = false,
  });

  final String texto;

  /// En acento. Se reserva para lo que está pasando ahora. Atajo de
  /// `tono: TonoDelChip.vivo`.
  final bool vivo;

  /// El tono, cuando no es solo «vivo o no». Manda sobre [vivo].
  final TonoDelChip? tono;

  /// El punto de 6 px delante. Para el estado del enlace, que es un estado y no una
  /// etiqueta.
  final bool punto;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = switch (tono ??
        (vivo ? TonoDelChip.vivo : TonoDelChip.apagado)) {
      TonoDelChip.vivo => colors.accent,
      TonoDelChip.atencion => colors.warn,
      TonoDelChip.fallo => colors.err,
      TonoDelChip.apagado => colors.mute,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (punto) ...[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
        ],
        // Un punto más pequeño que el rótulo y con menos tracking, como el mockup
        // (9,5 px a .14em): el chip acompaña a lo que se mira y no compite con ello.
        Text(
          texto.toUpperCase(),
          style: NexusTypography.label.copyWith(
            color: color,
            fontSize: 9.5,
            letterSpacing: 1.33,
          ),
        ),
      ],
    );
  }
}

/// El botón ancho del mockup: borde fino, todo el ancho.
///
/// Vive aquí y no dentro de una pantalla porque lo usan todas —escanear, escribir a
/// mano, conectando, los estados, las hojas— y **copias del mismo botón se separan**:
/// la primera vez que alguien cambie el radio o el grosor, dos de las tres se quedan
/// atrás y el ojo lo nota sin saber por qué.
///
/// Los tres del mockup y ninguno más: el normal en `ink` sobre `rule2`, el principal
/// con el acento **en el borde y en la letra**, y el peligroso igual en rojo. El normal
/// iba en `mute`, y al lado del principal se leía como apagado — como un botón que no
/// se puede tocar.
class WideAction extends StatelessWidget {
  const WideAction({
    super.key,
    required this.texto,
    required this.alTocar,
    this.principal = false,
    this.peligrosa = false,
  });

  final String texto;
  final VoidCallback? alTocar;

  /// En acento. Para la acción que la pantalla viene a hacer.
  final bool principal;

  /// En rojo, borde y letra: la que no tiene vuelta atrás sin trabajo —cerrar la
  /// conversación, olvidar el Mac—. Es lo que dibuja el mockup, y el color va
  /// **con** la palabra, nunca en su lugar.
  final bool peligrosa;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final apagado = alTocar == null;
    final color = apagado
        ? colors.faint
        : peligrosa
        ? colors.err
        : (principal ? colors.accent : colors.ink);

    return SizedBox(
      width: double.infinity,
      child: InkWell(
        onTap: alTocar,
        // Sin `alignment` en la caja: con él se estira a todo el alto que le den, y
        // al fondo de una pantalla con scroll el botón ocupaba media pantalla. El
        // ancho ya es entero, y el texto se centra solo.
        child: Container(
          // 12 arriba y abajo: el botón del mockup mide 38, y con los 16 de antes
          // cada pantalla con dos botones se comía un tercio más de alto.
          padding: const EdgeInsets.symmetric(
            vertical: NexusSpacing.s3,
            horizontal: NexusSpacing.s3,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: apagado || !(principal || peligrosa)
                  ? colors.rule2
                  : color,
            ),
          ),
          // En mayúsculas y con tracking, como el `.tel .btn` del mockup: Oxanium a
          // 10,5 y .14em. Es la voz del instrumento para los mandos del teléfono —el
          // chip, el permiso y estos botones hablan igual—, y con la frase en
          // minúscula el botón se leía como una nota más de la pantalla. Flutter no
          // tiene `text-transform`, así que se pasa a mayúsculas aquí.
          child: Text(
            texto.toUpperCase(),
            textAlign: TextAlign.center,
            style: NexusTypography.label.copyWith(
              color: color,
              fontSize: 10.5,
              letterSpacing: 1.47,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}

/// La caja de un campo del teléfono: 44 de alto, borde `rule2`, sin relleno.
///
/// **La misma en todas partes** —emparejar, la frase, el nombre, el compositor, el
/// buscador—, porque es lo que dibuja el mockup y porque cada una tenía la suya: unas
/// con fondo `rise`, otras con la línea de Material, otra con el borde de foco en
/// acento. Cinco campos distintos en una app de ocho pantallas se leen como cinco
/// sitios que hacen cosas distintas.
///
/// La letra es la de lo que se escribe (sans a 14) y no mono, como el mockup: lo que se
/// teclea aquí es una frase, un nombre o un encargo, y las dos cosas que sí son datos
/// —la dirección y el token— se pegan más que se leen.
class MobileInput extends StatelessWidget {
  const MobileInput({
    super.key,
    required this.controlador,
    required this.pista,
    this.alEscribir,
    this.alMandar,
    this.oculto = false,
    this.autofocus = false,
    this.lineas = 1,
    this.campoKey,
    this.accion,
  });

  final TextEditingController controlador;
  final String pista;
  final ValueChanged<String>? alEscribir;
  final ValueChanged<String>? alMandar;

  /// Para la frase: se escribe sin verse.
  final bool oculto;
  final bool autofocus;

  /// Cuántas líneas puede crecer. El compositor crece hasta cuatro; los demás, una.
  final int lineas;

  /// La llave del `TextField` de dentro, para quien necesite escribir en él.
  final Key? campoKey;

  final TextInputAction? accion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final letra = NexusTypography.body.copyWith(fontSize: 14, height: 1.4);

    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(
        horizontal: NexusSpacing.s3,
        vertical: NexusSpacing.s2,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: colors.rule2),
      ),
      child: TextField(
        key: campoKey,
        controller: controlador,
        onChanged: alEscribir,
        onSubmitted: alMandar,
        obscureText: oculto,
        autofocus: autofocus,
        autocorrect: false,
        enableSuggestions: false,
        minLines: 1,
        maxLines: oculto ? 1 : lineas,
        textInputAction: accion,
        cursorColor: colors.accent,
        style: letra.copyWith(color: colors.ink),
        decoration: InputDecoration(
          hintText: pista,
          hintStyle: letra.copyWith(color: colors.faint),
          // Sin las líneas ni el relleno de Material: la caja ya es el borde, y dos
          // bordes dibujan un campo dentro de otro.
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

/// Un campo con su rótulo arriba y, si hace falta, lo que está mal **debajo**.
///
/// **Sin botón de pegar a la derecha.** La primera versión ponía un icono de pegar en
/// cada campo, razonando que nadie teclea 43 caracteres — y era ruido: una pulsación
/// larga sobre el campo ya da el menú de pegar del sistema, que además es el gesto que
/// la gente ya conoce. El icono ocupaba sitio para ofrecer algo que ya estaba.
///
/// **El error va pegado al campo que lo tiene**, en una frase entera y en rojo, como
/// el mockup: «Falta el puerto. El canal escucha en el 7845.» debajo de la dirección.
/// Estuvo en una caja aparte al final del formulario, y con dos campos había que
/// adivinar de cuál hablaba.
class MobileField extends StatelessWidget {
  const MobileField({
    super.key,
    required this.etiqueta,
    required this.pista,
    required this.controlador,
    this.alEscribir,
    this.error,
    this.aviso,
  });

  final String etiqueta;
  final String pista;
  final TextEditingController controlador;
  final VoidCallback? alEscribir;

  /// Lo que está mal en este campo, en rojo.
  final String? error;

  /// Lo que conviene saber sin que esté mal, en ámbar: avisa y no bloquea.
  final String? aviso;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final debajo = error ?? aviso;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta.toUpperCase(),
          style: NexusTypography.label.copyWith(color: colors.mute),
        ),
        const SizedBox(height: 6),
        MobileInput(
          controlador: controlador,
          pista: pista,
          alEscribir: (_) => alEscribir?.call(),
        ),
        if (debajo != null) ...[
          const SizedBox(height: NexusSpacing.s1),
          Text(
            debajo,
            key: ValueKey(error != null ? 'problema' : 'aviso-tailscale'),
            style: NexusTypography.nota.copyWith(
              color: error != null ? colors.err : colors.warn,
              fontSize: 12.5,
            ),
          ),
        ],
      ],
    );
  }
}

/// El permiso, como el control segmentado del mockup.
///
/// **Es un eje de dos posiciones y no un interruptor**: «solo leer» y «puede editar»
/// se ven a la vez, y cuál está activo se lee de un vistazo. Un `Switch` obligaría a
/// recordar qué significa encendido — y aquí lo que está en juego es si algo va a
/// escribir en tus archivos.
///
/// **Solo se enciende «puede editar»**, y en ámbar, como el mockup: leer es lo normal y
/// no hay nada que avisar; poder escribir en tus archivos sí lo es. Y la hora va
/// **dentro** del segmento —«Puede editar · hasta 11:40»—, que es la parte que el
/// interruptor solo no puede decir: sin ella invita a confiar en que sigue abierto.
///
/// Pequeño y a la izquierda, no a todo el ancho: es un ajuste del compositor, no la
/// acción de la pantalla.
class PermissionToggle extends StatelessWidget {
  const PermissionToggle({
    super.key,
    required this.puedeEditar,
    required this.alTocar,
    this.hasta,
  });

  final bool puedeEditar;
  final VoidCallback alTocar;

  /// La hora a la que se cierra la escritura, ya escrita: «11:40».
  final String? hasta;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final hora = hasta;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Lado(
          key: const ValueKey('solo-leer'),
          texto: strings.mobileReadOnly,
          activo: false,
          // Bajar a solo lectura no necesita frase: **quitarse permiso siempre se
          // puede**. Subir es lo que la pide.
          alTocar: puedeEditar ? alTocar : null,
        ),
        _Lado(
          key: const ValueKey('puede-editar'),
          texto: puedeEditar && hora != null
              ? '${strings.mobileCanEdit} · ${strings.mobileWritableUntil(hora)}'
              : strings.mobileCanEdit,
          activo: puedeEditar,
          alTocar: puedeEditar ? null : alTocar,
        ),
      ],
    );
  }
}

class _Lado extends StatelessWidget {
  const _Lado({
    super.key,
    required this.texto,
    required this.activo,
    required this.alTocar,
  });

  final String texto;
  final bool activo;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = activo ? colors.warn : colors.mute;

    return InkWell(
      onTap: alTocar,
      child: Container(
        // Cada lado con su borde, como el mockup: encenderse cambia **el color** del
        // borde y de la letra, y no el fondo ni el peso, así que el que se enciende no
        // mueve al de al lado.
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: activo ? colors.warn : colors.rule2),
        ),
        child: Text(
          texto.toUpperCase(),
          style: NexusTypography.label.copyWith(
            color: color,
            fontSize: 9.5,
            letterSpacing: 1.14,
          ),
        ),
      ),
    );
  }
}

/// Abre una hoja del teléfono: la de la frase y la de «···».
///
/// **Las dos con la misma forma, la del mockup**: pegada abajo, sin esquinas
/// redondeadas, con una raya `rule2` encima y el velo del fondo detrás. La de la frase
/// era la hoja de Material —esquinas de 28, sombra, velo negro— y la de acciones otra
/// cosa distinta; dos hojas de la misma app, a un toque una de otra, con dos formas.
///
/// `isScrollControlled` porque las dos tienen un campo: con el teclado abierto, una
/// hoja que no puede crecer se queda debajo de él.
Future<T?> mostrarHojaDelMovil<T>(BuildContext context, WidgetBuilder hoja) {
  final colors = context.colors;
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: colors.deep,
    barrierColor: MedidasDelMovil.velo(colors),
    isScrollControlled: true,
    elevation: 0,
    shape: Border(top: BorderSide(color: colors.rule2)),
    builder: hoja,
  );
}

/// El relleno de una hoja: los márgenes del mockup (20 arriba, 18 a los lados, 34
/// abajo) y 10 entre cada pieza, **más el teclado** cuando está abierto.
class HojaDelMovil extends StatelessWidget {
  const HojaDelMovil({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      MedidasDelMovil.margen,
      20,
      MedidasDelMovil.margen,
      34 + MediaQuery.of(context).viewInsets.bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: children,
    ),
  );
}

/// Un texto centrado **con las líneas equilibradas**: el `text-wrap: balance` del
/// mockup, que Flutter no trae.
///
/// Los títulos de estado y el subtítulo de la voz se centran, y centrados se ve lo que
/// en un párrafo alineado a la izquierda no importa: «Esta conversación ya no está /
/// abierta» deja una palabra huérfana debajo de una línea llena, y se lee como un
/// corte. El mockup parte por el medio —«Esta conversación / ya no está abierta»—, y
/// eso es lo que se hace aquí: se busca el ancho más estrecho que **no añade líneas**,
/// y el texto se pinta en ese ancho.
///
/// Solo cambia dónde se parte, nunca el número de líneas: en una pantalla estrecha el
/// texto sigue ocupando lo mismo de alto que sin equilibrar.
class TextoEquilibrado extends StatelessWidget {
  const TextoEquilibrado(
    this.texto, {
    super.key,
    required this.style,
    this.clave,
  }) : partes = null;

  const TextoEquilibrado.rich(
    TextSpan this.partes, {
    super.key,
    required this.style,
    this.clave,
  }) : texto = null;

  final String? texto;
  final TextSpan? partes;
  final TextStyle style;

  /// La llave del `Text` de dentro, para quien necesite leerlo.
  final Key? clave;

  @override
  Widget build(BuildContext context) {
    final span = partes ?? TextSpan(text: texto);
    final escala = MediaQuery.textScalerOf(context);
    final direccion = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, caja) {
        var ancho = caja.maxWidth;
        if (ancho.isFinite) {
          final medir = TextPainter(
            text: TextSpan(style: style, children: [span]),
            textAlign: TextAlign.center,
            textDirection: direccion,
            textScaler: escala,
          );
          int lineas(double w) {
            medir.layout(maxWidth: w);
            return medir.computeLineMetrics().length;
          }

          final cuantas = lineas(ancho);
          if (cuantas > 1) {
            // Búsqueda binaria del ancho más estrecho con las mismas líneas: diez
            // vueltas bastan para quedarse a menos de un píxel en cualquier teléfono.
            var bajo = ancho / 2;
            var alto = ancho;
            for (var i = 0; i < 10; i++) {
              final medio = (bajo + alto) / 2;
              if (lineas(medio) > cuantas) {
                bajo = medio;
              } else {
                alto = medio;
              }
            }
            ancho = alto.ceilToDouble();
          }
          medir.dispose();
        }

        // `heightFactor: 1`: centrado a lo ancho, y de alto lo que mide el texto.
        // Sin él el `Center` se estira a todo el alto que le den y la frase se iba
        // al medio del hueco, lejos del orbe que la dice.
        return Center(
          heightFactor: 1,
          child: SizedBox(
            width: ancho.isFinite ? ancho : null,
            child: Text.rich(
              span,
              key: clave,
              textAlign: TextAlign.center,
              style: style,
            ),
          ),
        );
      },
    );
  }
}
