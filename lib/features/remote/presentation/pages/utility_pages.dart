import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/artifacts/domain/usecases/html_del_visor.dart';
import 'package:nexus/core/design_system/nexus_colors.dart';
import 'package:nexus/core/design_system/nexus_spacing.dart';
import 'package:nexus/core/design_system/nexus_typography.dart';
import 'package:nexus/features/remote/presentation/pages/conversation_page.dart';
import 'package:nexus/features/remote/presentation/providers/utility_providers.dart';
import 'package:nexus/features/remote/presentation/widgets/mobile_chrome.dart';

/// El molde de las pantallas del menú.
///
/// **Sin orbe.** El orbe es la presencia del asistente, y estas no son el asistente
/// haciendo algo: son un archivo, unos documentos y un selector. Ponerle uno lo
/// convertiría en decoración.
///
/// Y todas tienen la misma forma porque hacen lo mismo: pedir una lista, enseñarla,
/// y dejar elegir. Un molde común es lo que hace que la tercera no se parezca a otra
/// app — es lo que faltó la primera vez que se escribieron estas pantallas.
///
/// **La cabecera de siempre y no un `AppBar`**, con la vuelta `‹` del mockup: el
/// `AppBar` traía su flecha, su alto y su margen, y la cabecera cambiaba de sitio al
/// entrar. Y la nota de abajo **pegada al fondo**, como el mockup: debajo de la lista
/// se leía como una fila más.
class _ListaDeUtilidad extends StatelessWidget {
  const _ListaDeUtilidad({
    required this.cuerpo,
    required this.pie,
    this.rotulo,
    this.titulo,
    this.alRefrescar,
    this.arriba,
  });

  /// El rótulo encima de la lista, cuando la lista necesita decir qué es: «Sobre qué
  /// carpeta». `null` donde lo que hay arriba ya lo dice —el buscador del historial—
  /// o donde lo dice la cabecera.
  final String? rotulo;

  /// El nombre del sitio en la cabecera, con la letra del wordmark: «DOCUMENTOS».
  /// `null` deja `NEXUS`, como el mockup en el historial y en conversación nueva.
  final String? titulo;

  final Widget cuerpo;

  /// La nota de abajo. **Obligatoria**: en todas hay algo que conviene saber antes
  /// de tocar —qué pasa al retomar, qué pesa un documento, dónde se empareja una
  /// carpeta— y dejarlo a la intuición es lo que hace que la gente toque y se
  /// arrepienta.
  final String pie;

  final Future<void> Function()? alRefrescar;

  /// Lo que va **entre el rótulo y la lista**: el buscador, los botones de cuenta.
  /// Va en el molde y no en cada pantalla para que estén a la misma altura en todas:
  /// el archivo y las carpetas se recorren seguidas, y un filtro que salta de sitio se
  /// vuelve a buscar cada vez.
  final Widget? arriba;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // `SliverFillRemaining` para la nota: le da el alto que sobra y la deja abajo
    // cuando la lista es corta, y detrás de la lista cuando es larga — sin meter un
    // `Spacer` dentro de un scroll, que es la contradicción que ya rompió tres
    // pantallas de esta app.
    final lista = CustomScrollView(
      // Siempre desplazable, o el tirón para refrescar no funciona cuando la lista es
      // corta — que es justo cuando más se tira.
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: MedidasDelMovil.margen,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rotulo case final rotulo?) ...[
                  const SizedBox(height: 14),
                  Text(
                    rotulo.toUpperCase(),
                    style: NexusTypography.label.copyWith(color: colors.mute),
                  ),
                  const SizedBox(height: NexusSpacing.s1),
                ],
                if (arriba case final fila?)
                  Padding(padding: const EdgeInsets.only(top: 10), child: fila),
                cuerpo,
              ],
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                MedidasDelMovil.margen,
                NexusSpacing.s5,
                MedidasDelMovil.margen,
                MedidasDelMovil.pie,
              ),
              // En sans y `mute`: es una explicación, y en mono tenue no pasaba AA.
              child: Text(
                pie,
                style: NexusTypography.nota.copyWith(
                  color: colors.mute,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: colors.void_,
      body: SafeArea(
        child: Column(
          children: [
            // Sin hamburguesa: desde aquí se vuelve, no se abre otro menú.
            MobileChrome(
              alVolver: () => Navigator.of(context).maybePop(),
              titulo: titulo,
            ),
            Expanded(
              child: alRefrescar == null
                  ? lista
                  : RefreshIndicator(
                      onRefresh: alRefrescar!,
                      color: colors.accent,
                      backgroundColor: colors.deep,
                      child: lista,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una fila de las tres listas: título, un dato debajo, y un chip opcional.
/// Los cubos que hay **en lo que se está enseñando**: «general» y uno por cuenta.
///
/// `null` es general —lo que no es de ningún perfil— y va primero. No hay un botón de
/// «todas»: mezclar cuentas en una sola lista es justo lo que obliga a leer treinta y
/// seis nombres para dar con el de esta mañana, y quien trabaja con dos mundos los
/// mira por separado.
///
/// Salen de los propios datos y no de una lista fija: un botón para un cubo vacío
/// ofrece un sitio donde mirar en el que no hay nada.
List<String?> _cubos(Iterable<String?>? valores) {
  final todos = (valores ?? const <String?>[]).toList();
  return [
    if (todos.any((c) => c == null)) null,
    ...todos.nonNulls.toSet().toList()..sort(),
  ];
}

/// Lo del cubo elegido, y nada más. `null` trae lo que no tiene cuenta.
List<T> _soloDe<T>(
  List<T> todo,
  String? cuenta,
  String? Function(T) cuentaDe,
) => [
  for (final e in todo)
    if (cuentaDe(e) == cuenta) e,
];

/// El cubo preferido al abrir, cuando existe.
///
/// Es una preferencia, no una regla del dominio: se abre en el mundo en el que se
/// trabaja casi siempre, y de ahí un nombre concreto en el código. Cambiarlo es
/// cambiar esta constante; el resto no sabe nada de ella.
const _cuboPreferido = 'work';

/// Qué cubo sale elegido al abrir.
///
/// [_cuboPreferido] si está entre los que hay; si no, el del primero de la lista, que
/// al venir ordenada de lo más reciente a lo más antiguo es el mundo en el que se
/// estaba trabajando. Empezar siempre en «general» abriría el archivo en el cubo casi
/// vacío y obligaría a un toque antes de ver nada.
String? _cuboDePartida<T>(
  List<T>? datos,
  String? Function(T) cuentaDe,
  List<String?> cubos,
) {
  if (cubos.contains(_cuboPreferido)) return _cuboPreferido;
  return (datos == null || datos.isEmpty) ? null : cuentaDe(datos.first);
}

/// Los botones de cuenta, arriba de la lista.
///
/// **Solo existen si hay más de una.** Con una sola cuenta configurada, dividir en
/// botones dibuja una elección que no existe y encima miente sobre que hubiera otra
/// parte donde mirar. Es la misma regla que las pestañas del escritorio, por el mismo
/// motivo.
///
/// Y hay un «todas» porque la lista viene ordenada por fecha: lo último que hiciste
/// suele ser lo que buscas, y saber de qué cuenta era es a menudo lo que se quiere
/// **descubrir**, no lo que se sabe de antemano.
class _CuentasArriba extends StatelessWidget {
  const _CuentasArriba({
    required this.cubos,
    required this.elegida,
    required this.alElegir,
  });

  /// `null` entre ellos es «general».
  final List<String?> cubos;

  final String? elegida;
  final ValueChanged<String?> alElegir;

  @override
  Widget build(BuildContext context) {
    // Con un solo cubo no hay elección que hacer, y un botón único solo ocupa sitio.
    if (cubos.length < 2) return const SizedBox.shrink();
    final strings = context.strings;

    return Wrap(
      spacing: NexusSpacing.s2,
      runSpacing: NexusSpacing.s2,
      children: [
        for (final cubo in cubos)
          _Boton(
            key: ValueKey('cuenta-${cubo ?? 'general'}'),
            rotulo: cubo ?? strings.mobileGeneral,
            activo: elegida == cubo,
            alTocar: () => alElegir(cubo),
          ),
      ],
    );
  }
}

class _Boton extends StatelessWidget {
  const _Boton({
    super.key,
    required this.rotulo,
    required this.activo,
    required this.alTocar,
  });

  final String rotulo;
  final bool activo;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // El acento, que es lo que quiere decir «esta es la opción elegida».
    final marca = colors.accent;

    return InkWell(
      onTap: alTocar,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: NexusSpacing.s3,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          // El activo se marca con el acento en el borde y en la letra, no con un
          // relleno: un botón macizo aquí pesa más que la propia lista.
          border: Border.all(color: activo ? marca : colors.rule),
        ),
        child: Text(
          rotulo.toUpperCase(),
          style: NexusTypography.label.copyWith(
            color: activo ? marca : colors.mute,
          ),
        ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    super.key,
    required this.titulo,
    required this.dato,
    this.delante,
    this.chip,
    this.chipVivo = false,
    this.alTocar,
    this.apagada = false,
  });

  final String titulo;
  final String dato;

  /// Lo que va a la izquierda, cuando hace falta: el tipo de un documento.
  final Widget? delante;

  final String? chip;
  final bool chipVivo;
  final VoidCallback? alTocar;

  /// Se ve pero no se toca. **Se enseña igual**: esconder lo que no se puede elegir
  /// deja a quien mira preguntándose si falta algo.
  final bool apagada;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: apagada ? null : alTocar,
      child: Opacity(
        // Tenue como el mockup, y no solo el título en gris: la fila entera dice «esto
        // está, pero aquí no se abre».
        opacity: apagada ? 0.55 : 1,
        child: Container(
          width: double.infinity,
          // s3 y no s4: en una lista de teléfono, 16 px arriba y abajo por fila
          // convierten cuatro elementos en una pantalla entera. Con 12 caben seis sin
          // que se toquen.
          padding: const EdgeInsets.symmetric(vertical: NexusSpacing.s3),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.rule)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (delante case final algo?) ...[
                algo,
                const SizedBox(width: NexusSpacing.s3),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Lo que se lee, en sans y a tamaño de fila: con `lead` cuatro
                    // filas ya llenaban la pantalla.
                    Text(
                      titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: NexusTypography.body.copyWith(
                        color: colors.ink,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Y el dato en mono, en `mute`: en `faint` sobre el fondo no pasaba
                    // AA, y es lo que distingue una fila de su vecina.
                    Text(
                      dato,
                      style: NexusTypography.data.copyWith(color: colors.mute),
                    ),
                  ],
                ),
              ),
              if (chip != null) ...[
                const SizedBox(width: NexusSpacing.s3),
                StateChip(texto: chip!, vivo: chipVivo),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// La caja de buscar del teléfono: el campo del compositor, con su pista.
///
/// **No la del Mac** (`CampoDeBusqueda`): aquella lleva el atajo `⌘F` al lado, que en
/// un teléfono es una tecla que no existe. Lo que se comparte con el Mac es lo que
/// dice —«Buscar en lo que se habló»— y cómo busca, no el dibujo.
class _Buscador extends StatelessWidget {
  const _Buscador({required this.pista, required this.alCambiar});

  final String pista;
  final ValueChanged<String> alCambiar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: NexusSpacing.s3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: colors.rule2),
      ),
      child: TextField(
        key: const ValueKey('buscar-en-el-historial'),
        onChanged: alCambiar,
        style: NexusTypography.body.copyWith(color: colors.ink, fontSize: 14),
        cursorColor: colors.accent,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: pista,
          hintStyle: NexusTypography.body.copyWith(
            color: colors.faint,
            fontSize: 14,
          ),
          // Sin el relleno del tema: dentro de la caja salía un segundo
          // rectángulo más claro, un campo dentro de otro.
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

/// El rótulo de un grupo: «Hoy», «Ayer», «De: CRED-310 · desenlaces».
class _Grupo extends StatelessWidget {
  const _Grupo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: NexusSpacing.s1),
    child: Text(
      texto.toUpperCase(),
      style: NexusTypography.label.copyWith(color: context.colors.mute),
    ),
  );
}

/// Las del archivo que casan con lo buscado, **con la misma regla que el Mac**: todas
/// las palabras, en el título, la carpeta o la cuenta, sin mayúsculas.
///
/// Lo que el Mac busca además —lo último que se pidió y se contestó— no viaja con la
/// lista del teléfono: traerlo sería mandar por 4G el final de treinta conversaciones
/// para buscar en una.
List<ArchiveEntry> _buscadas(List<ArchiveEntry> todas, String busqueda) {
  final palabras = busqueda
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (palabras.isEmpty) return todas;
  return [
    for (final c in todas)
      if (palabras.every(
        '${c.title} ${c.folder} ${c.account ?? ''}'.toLowerCase().contains,
      ))
        c,
  ];
}

/// El archivo por días, del más reciente al más viejo: la misma forma que el
/// historial del Mac, donde el día se dice **una vez** en su cabecera.
///
/// Las que no traen fecha —un Mac de antes— van al final y sin cabecera: ponerlas en
/// «hoy» sería mentir sobre cuándo fueron.
List<(DateTime?, List<ArchiveEntry>)> _porDias(List<ArchiveEntry> entradas) {
  final dias = <DateTime, List<ArchiveEntry>>{};
  final sinDia = <ArchiveEntry>[];
  for (final e in entradas) {
    final cuando = e.when;
    if (cuando == null) {
      sinDia.add(e);
      continue;
    }
    dias
        .putIfAbsent(DateTime(cuando.year, cuando.month, cuando.day), () => [])
        .add(e);
  }
  final orden = dias.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final dia in orden)
      (dia, dias[dia]!..sort((a, b) => b.when!.compareTo(a.when!))),
    if (sinDia.isNotEmpty) (null, sinDia),
  ];
}

/// «Hoy», «Ayer» o la fecha, con las mismas palabras que el historial del Mac.
String _nombreDelDia(NexusStrings strings, DateTime dia, DateTime ahora) {
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  if (dia == hoy) return strings.historialHoy;
  // Con el constructor y no restando 24 h: el día que cambia la hora, ayer a las
  // 00:00 está a 23 o 25 horas.
  if (dia == DateTime(ahora.year, ahora.month, ahora.day - 1)) {
    return strings.historialAyer;
  }
  return strings.historialDia(dia, conElAno: dia.year != ahora.year);
}

/// Los documentos **por la conversación que los produjo**, como el Mac: del grupo con
/// el documento más reciente al más viejo, y «Sin conversación» siempre al final —
/// no es una conversación, es lo que no se sabe de dónde vino—.
List<(String?, List<ArtifactEntry>)> _porConversacion(
  List<ArtifactEntry> documentos,
) {
  final epoca = DateTime.fromMillisecondsSinceEpoch(0);
  final ordenados = [...documentos]
    ..sort((a, b) => (b.when ?? epoca).compareTo(a.when ?? epoca));
  final grupos = <String, List<ArtifactEntry>>{};
  final titulos = <String, String>{};
  final sueltos = <ArtifactEntry>[];
  for (final d in ordenados) {
    final id = d.conversation;
    if (id == null) {
      sueltos.add(d);
      continue;
    }
    grupos.putIfAbsent(id, () => []).add(d);
    titulos.putIfAbsent(id, () => d.conversationTitle ?? '');
  }
  return [
    for (final id in grupos.keys) (titulos[id], grupos[id]!),
    if (sueltos.isNotEmpty) (null, sueltos),
  ];
}

/// El tipo de un documento, en la caja de la izquierda: su extensión, que es un dato.
class _Tipo extends StatelessWidget {
  const _Tipo(this.nombre);

  final String nombre;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final punto = nombre.lastIndexOf('.');
    final extension = punto == -1 ? '' : nombre.substring(punto + 1);
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(border: Border.all(color: colors.rule2)),
      child: Text(
        extension.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: NexusTypography.data.copyWith(color: colors.mute, fontSize: 8),
      ),
    );
  }
}

/// El archivo: retomar una conversación de antes.
class ArchivePage extends ConsumerStatefulWidget {
  const ArchivePage({super.key});

  @override
  ConsumerState<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends ConsumerState<ArchivePage> {
  /// `null` es «todas». La elección **no se guarda**: al volver a entrar se ve todo,
  /// que es lo que se quiere el 90 % de las veces. Un filtro que sobrevive es un
  /// filtro que se olvida, y entonces «no aparece» se lee como «no está».
  String? _cuenta;

  /// Si ya se eligió a mano. Hace falta un flag aparte porque `null` **es un cubo de
  /// verdad** —«general»— y por tanto no puede significar también «sin elegir».
  bool _elegido = false;

  /// Lo que se busca. Tampoco se guarda, por lo mismo que la cuenta.
  var _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final archivo = ref.watch(archiveProvider);
    final cubos = _cubos(archivo.value?.map((c) => c.account));
    final cuenta = _elegido
        ? _cuenta
        : _cuboDePartida(archivo.value, (e) => e.account, cubos);

    // Sin rótulo, como el mockup: el buscador de arriba —«Buscar en lo que se
    // habló»— ya dice qué es esto, y un «HISTORIAL» encima era decirlo dos veces.
    return _ListaDeUtilidad(
      alRefrescar: () => ref.refresh(archiveProvider.future),
      // El buscador **antes** que las cuentas, como el mockup: se viene a buscar una
      // concreta, y la cuenta es un filtro que se toca después si hace falta.
      arriba: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Buscador(
            pista: strings.historialBuscar,
            alCambiar: (texto) => setState(() => _busqueda = texto),
          ),
          if (cubos.length > 1) const SizedBox(height: NexusSpacing.s3),
          _CuentasArriba(
            cubos: cubos,
            elegida: cuenta,
            alElegir: (cubo) => setState(() {
              _cuenta = cubo;
              _elegido = true;
            }),
          ),
        ],
      ),
      pie: strings.mobileHistoryFooter,
      cuerpo: switch (archivo) {
        AsyncData(:final value) when value.isEmpty => _Vacia(
          texto: strings.mobileHistoryEmpty,
        ),
        AsyncData(:final value)
            when _soloDe(value, cuenta, (c) => c.account).isEmpty =>
          _Vacia(
            texto: strings.mobileHistoryEmptyFor(
              cuenta ?? strings.mobileGeneral,
            ),
          ),
        // Sin resultados se dice **qué se buscó**, con la frase del Mac: una lista
        // vacía a secas se lee como «no hay historial», y lo hay.
        AsyncData(:final value)
            when _buscadas(
              _soloDe(value, cuenta, (c) => c.account),
              _busqueda,
            ).isEmpty =>
          _Vacia(texto: strings.historialNadaDe(_busqueda.trim())),
        AsyncData(:final value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (dia, fichas) in _porDias(
              _buscadas(_soloDe(value, cuenta, (c) => c.account), _busqueda),
            )) ...[
              if (dia != null)
                _Grupo(_nombreDelDia(strings, dia, DateTime.now())),
              for (final c in fichas) _archivada(context, c),
            ],
          ],
        ),
        AsyncError() => _Vacia(texto: strings.mobileHistoryUnavailable),
        _ => const _Cargando(),
      },
    );
  }

  Widget _archivada(BuildContext context, ArchiveEntry c) {
    final strings = context.strings;
    return _Fila(
      key: ValueKey('archivada-${c.id}'),
      titulo: c.title,
      // La cuenta primero cuando la hay: en un archivo con veintitrés de `private` y
      // siete de `work`, la carpeta sola no distingue —dos cuentas pueden trabajar
      // sobre el mismo repo—. El escritorio lo resuelve con pestañas; aquí, sin sitio
      // para pestañas, va en la propia fila.
      dato: [
        ?c.account,
        _cola(c.folder),
        strings.mobileTurns(c.turns),
      ].join(' · '),
      // Se dice cuál está viva para no ofrecer «retomar» algo que ya lo está — y se
      // deja tocar igual, porque llevar a la abierta es exactamente lo correcto.
      chip: c.open ? strings.mobileOpenChip : null,
      chipVivo: c.open,
      alTocar: () async {
        final id = await ref.read(archiveProvider.notifier).retomar(c.id);
        if (id == null || !context.mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => ConversationPage(conversationId: id),
          ),
        );
      },
    );
  }
}

/// Los documentos: lo que produjo Claude.
class ArtifactsPage extends ConsumerStatefulWidget {
  const ArtifactsPage({super.key});

  @override
  ConsumerState<ArtifactsPage> createState() => _ArtifactsPageState();
}

class _ArtifactsPageState extends ConsumerState<ArtifactsPage> {
  String? _cuenta;

  /// Si ya se eligió a mano. Hace falta un flag aparte porque `null` **es un cubo de
  /// verdad** —«general»— y por tanto no puede significar también «sin elegir».
  bool _elegido = false;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final lista = ref.watch(artifactsListProvider);
    final cubos = _cubos(lista.value?.map((a) => a.account));
    final cuenta = _elegido
        ? _cuenta
        : _cuboDePartida(lista.value, (e) => e.account, cubos);

    // El nombre en la cabecera y no encima de la lista, como el mockup: así el
    // primer grupo —«De: …»— es lo primero que se lee.
    return _ListaDeUtilidad(
      titulo: strings.mobileDocuments,
      alRefrescar: () => ref.refresh(artifactsListProvider.future),
      arriba: _CuentasArriba(
        cubos: cubos,
        elegida: cuenta,
        alElegir: (cubo) => setState(() {
          _cuenta = cubo;
          _elegido = true;
        }),
      ),
      pie: strings.mobileDocumentsFooter,
      cuerpo: switch (lista) {
        AsyncData(:final value) when value.isEmpty => _Vacia(
          texto: strings.mobileDocumentsEmpty,
        ),
        AsyncData(:final value)
            when _soloDe(value, cuenta, (a) => a.account).isEmpty =>
          _Vacia(
            texto: strings.mobileDocumentsEmptyFor(
              cuenta ?? strings.mobileGeneral,
            ),
          ),
        // **Cada documento cuelga de la conversación que lo pidió**, con las
        // palabras del Mac: «De: …» y «Sin conversación». Un Finder no dice de dónde
        // salió cada cosa, y cinco `mockup-algo.html` seguidos solo se distinguen
        // por eso.
        AsyncData(:final value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (titulo, documentos) in _porConversacion(
              _soloDe(value, cuenta, (e) => e.account),
            )) ...[
              _Grupo(
                titulo == null
                    ? strings.artifactsSinConversacion
                    : '${strings.artifactsDe} $titulo',
              ),
              for (final a in documentos) _documento(context, a),
            ],
          ],
        ),
        AsyncError() => _Vacia(texto: strings.mobileDocumentsUnavailable),
        _ => const _Cargando(),
      },
    );
  }

  Widget _documento(BuildContext context, ArtifactEntry a) => _Fila(
    key: ValueKey('artifact-${a.id}'),
    delante: _Tipo(a.name),
    titulo: a.name,
    // El peso va delante porque abrir uno grande con datos móviles es una decisión.
    // Y lo que no es texto se dice **en la misma línea**: un `.png` por un canal de
    // texto no da una imagen, da un error, y una fila que solo puede fallar es peor
    // que una fila que avisa.
    dato: [
      ?a.account,
      _peso(a.bytes),
      if (!a.text) context.strings.mobileOnlyOnMac,
    ].join(' · '),
    apagada: !a.text,
    alTocar: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ArtifactPage(id: a.id, nombre: a.name),
      ),
    ),
  );
}

/// El contenido de un artifact.
class ArtifactPage extends ConsumerStatefulWidget {
  const ArtifactPage({super.key, required this.id, required this.nombre});

  final String id;
  final String nombre;

  @override
  ConsumerState<ArtifactPage> createState() => _ArtifactPageState();
}

class _ArtifactPageState extends ConsumerState<ArtifactPage> {
  /// El documento puede ejecutar sus scripts y salir a la red.
  ///
  /// **Nace apagado, y por documento.** Lo escribió Claude, y lo que Claude
  /// escribe puede venir influido por lo que leyó en un repositorio; un `fetch`
  /// desde un mockup convierte el visor en un canal de salida. No se recuerda
  /// entre documentos a propósito: el permiso es de este, no del visor.
  bool _permitido = false;

  /// Si hay que pintarlo en vez de leerlo en crudo.
  ///
  /// Por la extensión del nombre y no por mirar el contenido: un documento que empieza
  /// con `<!doctype` casi seguro es HTML, pero uno que no empieza así también puede
  /// serlo, y adivinar acabaría enseñando etiquetas a veces. La extensión es lo que el
  /// Mac ya usa para decidir qué es un documento.
  bool get _sePinta {
    final punto = widget.nombre.lastIndexOf('.');
    if (punto == -1) return false;
    const html = {'.html', '.htm'};
    return html.contains(widget.nombre.substring(punto).toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final contenido = ref.watch(artifactProvider(widget.id));

    // **Pantalla propia para lo que se pinta, y no un hueco dentro de la lista.**
    //
    // Metido en el molde no servía de nada, por dos motivos a la vez: el molde envuelve
    // todo en un `SingleChildScrollView`, y el scroll de fuera se queda los gestos —así
    // que el documento no se podía mover—; y su padding lateral le robaba el ancho, con
    // lo que un mockup de 390 px no cabía en un teléfono de 360.
    //
    // Aquí no hay nada alrededor: el visor ocupa el cuerpo entero y el que hace scroll
    // es él, que es quien sabe cuánto mide su contenido.
    if (_sePinta) {
      return Scaffold(
        backgroundColor: colors.void_,
        body: SafeArea(
          child: Column(
            children: [
              MobileChrome(alVolver: () => Navigator.of(context).maybePop()),
              // El nombre sigue arriba: en una pila de mockups parecidos es lo único
              // que dice cuál se está mirando. A su derecha, la correa: la misma fila
              // dice qué se mira y con cuánta correa.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MedidasDelMovil.margen,
                  NexusSpacing.s1,
                  MedidasDelMovil.margen,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.nombre.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NexusTypography.label.copyWith(
                          color: colors.mute,
                        ),
                      ),
                    ),
                    _Correa(
                      suelta: _permitido,
                      alTocar: () => setState(() => _permitido = !_permitido),
                    ),
                  ],
                ),
              ),
              // El documento **en su caja**, como el mockup: un marco fino y el
              // fondo `deep`. Sin él, un mockup oscuro se confundía con la propia
              // pantalla y no se sabía dónde acababa la app y empezaba el documento.
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(
                    MedidasDelMovil.margen,
                    NexusSpacing.s3,
                    MedidasDelMovil.margen,
                    MedidasDelMovil.pie,
                  ),
                  decoration: BoxDecoration(
                    color: colors.deep,
                    border: Border.all(color: colors.rule),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: switch (contenido) {
                    AsyncData(:final value) => _Pintado(
                      html: value,
                      permitido: _permitido,
                      // La llave lleva el permiso: cambiarlo tiene que construir
                      // un `WebViewController` nuevo, porque el modo de JavaScript
                      // se fija al crearlo y un documento ya pintado no cambia de
                      // idea por sí solo.
                      key: ValueKey('artifact-pintado-$_permitido'),
                    ),
                    AsyncError() => _Vacia(texto: strings.mobileCouldNotRead),
                    _ => const _Cargando(),
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _ListaDeUtilidad(
      rotulo: widget.nombre,
      pie: strings.mobileFetchedOnOpen,
      cuerpo: switch (contenido) {
        AsyncData(:final value) => SelectableText(
          value,
          key: const ValueKey('contenido-del-artifact'),
          // En mono: son documentos que Claude escribió, casi siempre markdown, y
          // leerlos en proporcional pierde la alineación que tienen dentro.
          style: NexusTypography.mono.copyWith(color: colors.ink, height: 1.6),
        ),
        AsyncError() => _Vacia(texto: strings.mobileCouldNotRead),
        _ => const _Cargando(),
      },
    );
  }
}

/// «Scripts y red»: la correa del documento, **en ámbar y con su punto**, como el
/// mockup.
///
/// Un estado que se toca y no un botón más: el documento se abre con scripts y red
/// apagados, y lo que hay que ver sin leerlo es **eso** —que hay una correa y en qué
/// punto está—. Ámbar siempre, porque soltarla no es la opción buena; el acento diría
/// que sí. Suelta, el punto se enciende y la palabra gana un borde: se ve de lejos que
/// el documento puede salir a la red.
class _Correa extends StatelessWidget {
  const _Correa({required this.suelta, required this.alTocar});

  final bool suelta;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      toggled: suelta,
      child: InkWell(
        key: const ValueKey('correa-del-documento'),
        onTap: alTocar,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(
              color: suelta ? colors.warn : Colors.transparent,
            ),
          ),
          child: StateChip(
            texto: context.strings.allowScriptsShort,
            tono: TonoDelChip.atencion,
            punto: true,
          ),
        ),
      ),
    );
  }
}

/// Un documento HTML, pintado **dentro de la app**.
///
/// No se abre en el navegador del sistema, y es el punto: salir de la app para ver un
/// mockup que la propia app acaba de traer por su canal rompe la vuelta —se pierde el
/// sitio en la lista— y encima el navegador no tiene el documento: lo tiene esto.
///
/// El HTML llega por el canal como una cadena porque **un HTML es texto**: no hay
/// fichero que servir ni URL que autorizar, así que el visor no abre ninguna puerta
/// nueva. Sin navegación: lo que se pinta es lo que llegó, y un enlace que saliera a
/// la red convertiría un visor de documentos en un navegador.
///
/// **Y sin scripts ni red mientras nadie lo permita.** Que no haya archivo cierra
/// una puerta —no se puede leer al vecino— pero no la otra: un `fetch` desde el
/// documento sigue siendo una salida, y lo que lleve dentro lo decidió un HTML
/// que puede venir influido por lo que Claude leyó en un repositorio.
class _Pintado extends StatefulWidget {
  const _Pintado({super.key, required this.html, required this.permitido});

  final String html;

  /// Con la correa suelta: los scripts corren y la red se abre. Llega de fuera
  /// porque el interruptor vive en la cabecera, junto al nombre del documento.
  final bool permitido;

  @override
  State<_Pintado> createState() => _PintadoState();
}

class _PintadoState extends State<_Pintado> {
  late final WebViewController _control;

  @override
  void initState() {
    super.initState();
    _control = WebViewController()
      // Apagado salvo que se pida. Va junto a la muralla de abajo y no en su
      // lugar: son dos capas y se rompen por sitios distintos —el modo lo aplica
      // el motor del webview, la `Content-Security-Policy` la aplica el parser—.
      ..setJavaScriptMode(
        widget.permitido
            ? JavaScriptMode.unrestricted
            : JavaScriptMode.disabled,
      )
      // Transparente detrás: un mockup con fondo oscuro sobre el blanco de por
      // defecto se ve con un marco blanco alrededor.
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          // Solo se carga lo que se le dio. Un `about:blank` o el propio contenido
          // pasan; cualquier navegación a la red se bloquea, que es lo que separa un
          // visor de un navegador metido con calzador.
          onNavigationRequest: (peticion) =>
              peticion.url.startsWith('http') && peticion.isMainFrame
              ? NavigationDecision.prevent
              : NavigationDecision.navigate,
        ),
      )
      // Zoom permitido: los mockups vienen con su `viewport`, pero algunos están
      // pensados para una ventana ancha, y en un teléfono acercar es la diferencia
      // entre mirarlo y adivinarlo.
      ..enableZoom(true)
      ..loadHtmlString(
        widget.permitido ? widget.html : HtmlDelVisor.encerrado(widget.html),
      );
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(
    controller: _control,
    // Los gestos verticales son suyos. Sin esto —y con un scroll por encima— el
    // documento se queda quieto y parece que el visor no funciona.
    gestureRecognizers: {
      Factory<VerticalDragGestureRecognizer>(VerticalDragGestureRecognizer.new),
    },
  );
}

/// Elegir carpeta para una conversación nueva.
class FoldersPage extends ConsumerStatefulWidget {
  const FoldersPage({super.key});

  @override
  ConsumerState<FoldersPage> createState() => _FoldersPageState();
}

class _FoldersPageState extends ConsumerState<FoldersPage> {
  String? _cuenta;

  /// Si ya se eligió a mano. Hace falta un flag aparte porque `null` **es un cubo de
  /// verdad** —«general»— y por tanto no puede significar también «sin elegir».
  bool _elegido = false;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final carpetas = ref.watch(foldersProvider);
    final cubos = _cubos(carpetas.value?.map((f) => f.account));
    final cuenta = _elegido
        ? _cuenta
        : _cuboDePartida(carpetas.value, (e) => e.account, cubos);

    // «Sobre qué carpeta» y no «Conversación nueva»: la pantalla pregunta una cosa,
    // y el rótulo es esa pregunta.
    return _ListaDeUtilidad(
      rotulo: strings.mobileWhichFolder,
      alRefrescar: () => ref.refresh(foldersProvider.future),
      arriba: _CuentasArriba(
        cubos: cubos,
        elegida: cuenta,
        alElegir: (cubo) => setState(() {
          _cuenta = cubo;
          _elegido = true;
        }),
      ),
      pie: strings.mobileFoldersFooter,
      cuerpo: switch (carpetas) {
        AsyncData(:final value) when value.isEmpty => _Vacia(
          texto: strings.mobileNoFolders,
        ),
        AsyncData(:final value)
            when _soloDe(value, cuenta, (f) => f.account).isEmpty =>
          _Vacia(
            texto: strings.mobileNoFoldersFor(cuenta ?? strings.mobileGeneral),
          ),
        AsyncData(:final value) => Column(
          children: [
            for (final f in _soloDe(value, cuenta, (e) => e.account))
              _Fila(
                key: ValueKey('carpeta-${f.path}'),
                titulo: _cola(f.path),
                // La cuenta, que es lo que abrir aquí **elige**: hasta ahora se elegía
                // sin verlo. La ruta entera ya no va debajo, como el mockup: el
                // título ya dice cuál es, y la cabeza de la ruta es lo que todas
                // tienen en común. Sin cuenta, la ruta es lo único que distingue.
                dato: f.account ?? f.path,
                // Las dos cosas se dicen **antes** de abrir: empezar en una de solo
                // lectura y descubrirlo al primer encargo es trabajo para tirar, y
                // una ocupada no se puede abrir dos veces.
                chip: f.busy
                    ? strings.mobileBusy
                    : (f.canWrite ? null : strings.mobileReadOnlyChip),
                apagada: f.busy,
                alTocar: () async {
                  final id = await ref
                      .read(foldersProvider.notifier)
                      .abrir(f.path);
                  if (id == null || !context.mounted) return;
                  await Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => ConversationPage(conversationId: id),
                    ),
                  );
                },
              ),
          ],
        ),
        AsyncError() => _Vacia(texto: strings.mobileFoldersUnavailable),
        _ => const _Cargando(),
      },
    );
  }
}

/// Vacío o error, con la misma forma.
///
/// **Ni un spinner centrado ni una disculpa**: dice qué hay y se calla. Y vacío y
/// error se ven distintos porque son cosas distintas — uno es «no hay nada» y el otro
/// «no pude preguntar».
class _Vacia extends StatelessWidget {
  const _Vacia({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: NexusSpacing.s6),
    child: Text(
      texto,
      key: const ValueKey('lista-vacia'),
      style: NexusTypography.body.copyWith(color: context.colors.mute),
    ),
  );
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: NexusSpacing.s6),
    // En sans: es lo que está pasando, no un dato.
    child: Text(
      context.strings.mobileAskingMac,
      style: NexusTypography.nota.copyWith(color: context.colors.mute),
    ),
  );
}

/// Los dos últimos tramos de una ruta: en una pantalla estrecha, el principio es lo
/// que todas tienen en común y el final lo que las distingue.
String _cola(String ruta) {
  final tramos = ruta.split('/').where((t) => t.isNotEmpty).toList();
  if (tramos.length <= 2) return ruta;
  return '…/${tramos.sublist(tramos.length - 2).join('/')}';
}

String _peso(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
