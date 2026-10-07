import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/design_system/design_system.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/assistant/domain/entities/el_catalogo_de_modelos.dart';
import 'package:nexus/features/assistant/domain/usecases/los_comandos_de_la_casa.dart';
import 'package:nexus/features/assistant/presentation/providers/model_providers.dart';
import 'package:nexus/features/workspace/presentation/pages/settings_page.dart';
import 'package:nexus/features/assistant/presentation/state/session_meter.dart';
import 'package:nexus/features/stats/domain/usecases/model_label.dart';
import 'package:nexus/features/workspace/data/datasources/claude_profiles_data_source.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';
import 'package:nexus/features/updates/presentation/widgets/pending_dot.dart';
import 'package:nexus/features/assistant/presentation/providers/assistant_controller.dart';
import 'package:nexus/features/assistant/presentation/providers/conversations_providers.dart';
import 'package:nexus/features/workspace/presentation/providers/workspace_providers.dart';

/// Los tres menús del compositor: adjuntar y ajustes, el modelo, y el esfuerzo.
///
/// Juntos porque son la misma forma repetida tres veces —un
/// [MenuDelCompositor] con sus [OpcionDelMenu]— y separarlos en tres archivos
/// habría multiplicado los imports sin que ninguno pese lo suficiente para
/// vivir solo.

/// El «+»: lo que se añade a lo que estás pidiendo.
///
/// Adjuntar es **señalar una ruta**, no subir un archivo a ningún sitio: Claude
/// trabaja en tu disco y lee lo que le señales, así que copiar el contenido
/// sería duplicarlo y perder el vínculo con el original.
///
/// Lo que se añade por aquí y lo que se suelta arrastrando acaban en el mismo
/// sitio —la tira de miniaturas—, porque son el mismo gesto dicho de dos
/// formas.
class MoreMenu extends ConsumerWidget {
  const MoreMenu({super.key, required this.onAttach});

  final void Function(Iterable<String>) onAttach;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;

    // Mismo caso que el círculo del cupo: sin globo se quedó sin etiqueta, y
    // este es el único camino para adjuntar sin arrastrar un archivo.
    return Semantics(
      button: true,
      label: context.strings.attachFile,
      child: MenuDelCompositor<String>(
        ancho: 300,
        onSelected: (value) async {
          switch (value) {
            case 'file':
              // Varios de una vez, como al arrastrar: elegir tres archivos de una
              // carpeta y tener que abrir el diálogo tres veces es de las cosas
              // que hacen que nadie use el botón.
              final files = await openFiles();
              if (files.isNotEmpty) onAttach(files.map((file) => file.path));
            case 'folder':
              await ref.read(workspaceControllerProvider.notifier).pairFolder();
            case 'parte':
              // El parte del último día con trabajo. Va en este menú y no como
              // un botón suelto: se pide una vez al día, y lo que se usa una
              // vez al día no merece sitio fijo en la barra.
              // La conversación enfocada, leída aquí y no pasada desde arriba:
              // el compositor no la conoce, y hacerla bajar dos capas para un
              // menú sería cablear media pantalla por un elemento de lista.
              final cual = ref.read(conversationsProvider).focusedId;
              if (cual == null) return;
              final hubo = await ref
                  .read(assistantControllerProvider(cual).notifier)
                  .pedirElParte();
              if (!hubo && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.strings.parteSinDia)),
                );
              }
            case 'settings':
              if (context.mounted) await SettingsPage.open(context);
          }
        },
        // Sin iconos delante, como en el mockup: cada fila ya dice lo que hace
        // con su nombre, y el icono solo empujaba el texto a una columna que
        // ningún otro menú tiene.
        itemBuilder: (context) => [
          cabeceraDelMenu(context, '+'),
          OpcionDelMenu(value: 'file', titulo: strings.attachFile),
          OpcionDelMenu(value: 'folder', titulo: strings.addFolderShort),
          // Con su atajo al lado: lo que se pide desde aquí también se puede
          // escribir, y así se aprende sin abrir la ayuda.
          OpcionDelMenu(
            value: 'parte',
            titulo: strings.parteDelDia,
            alLado: ElComandoDeLaCasa.parte.comoSeEscribe,
          ),
          rayaDelMenu(),
          OpcionDelMenu(
            value: 'settings',
            titulo: strings.openSettings,
            alLado: '⌘,',
          ),
        ],
        // Con punto rojo mientras quede una versión sin instalar: Ajustes vive
        // dentro de este menú, así que el aviso va pegado al camino que lleva a
        // la actualización.
        child: PendingDot(
          child: Icon(Icons.add, size: 16, color: colors.faint),
        ),
      ),
    );
  }
}

/// El modelo con el que va a trabajar esta carpeta: con el nombre que dio el
/// CLI si ya corrió —`claude-opus-5-5`— o con el alias pedido si no —`opus`—.
///
/// Lo que dijo el CLI vale **mientras sea de la familia que se pide**: si
/// acabas de pasar de Opus a Sonnet, el último turno sigue diciendo Opus, y
/// enseñarlo sería decir que el cambio no se hizo.
String? _modeloEnUso(WidgetRef ref, PairedFolder? folder, SessionMeter meter) {
  final perfil = ref.watch(claudeDefaultsProvider(folder?.claudeProfile)).value;
  final pedido = folder?.claudeModel ?? perfil?.model;
  // Una versión pedida por su nombre entero es exactamente esa: lo que dijera
  // el último turno es de antes de elegirla.
  if (pedido != null && pedido.startsWith('claude-')) return pedido;
  final visto =
      meter.displayModel ??
      // Un perfil puede no fijar modelo —`private` no lo hace—: entonces vale
      // el último con el que se le vio trabajar. **Solo entonces**: con un
      // modelo pedido, ese recuerdo es de otra versión —decía «Opus 5» con el
      // CLI ya en Opus 5.5—.
      (pedido == null
          ? ref.watch(seenModelsProvider)[folder?.claudeProfile ??
                'por-defecto']
          : null);
  final familia = ClaudeModel.fromCliName(pedido);
  if (visto != null &&
      (pedido == null || ClaudeModel.fromCliName(visto) == familia)) {
    return visto;
  }
  // Sin turno todavía, el alias no dice versión. Pero `/effort` guarda sus
  // ajustes con el nombre entero, así que si el perfil tiene alguno de esa
  // familia, el más nuevo es a quien apunta el alias.
  final conocidos = [
    for (final modelo in perfil?.effortPorModelo.keys ?? const <String>[])
      if (familia != null && ClaudeModel.fromCliName(modelo) == familia) modelo,
  ]..sort();
  if (conocidos.isNotEmpty) return conocidos.last;
  return pedido ?? visto;
}

/// El nombre corto del perfil de Claude de la carpeta —`work`, `private`—, o
/// `null` si usa el de siempre. Es lo que se lee en la cabecera del modelo:
/// elegir aquí cambia **ese** perfil.
String? _perfil(PairedFolder? folder) {
  final nombre = folder?.claudeProfile?.split('/').last;
  if (nombre == null || !nombre.startsWith('.claude-')) return null;
  return nombre.substring('.claude-'.length);
}

/// Qué modelo usa Claude **en este perfil**.
///
/// 🔴 **Elegir aquí es lo mismo que `/model` en la consola**: se escribe en el
/// `settings.json` del perfil, que es lo que leen los dos. Antes se guardaba
/// por carpeta y viajaba como `--model`, así que Nexus y la consola podían ir
/// cada uno con un modelo sin que ninguno lo dijera. El precio, que es el que
/// se pidió: cambia para **todas** las carpetas de ese perfil.
class ModelMenu extends ConsumerWidget {
  const ModelMenu({super.key, required this.folder, required this.meter});

  final PairedFolder? folder;
  final SessionMeter meter;

  /// El valor de «por defecto» en el menú. No puede ser `null`: un menú que
  /// devuelve `null` lo toma por cerrado sin elegir.
  static const _porDefecto = '';

  /// El valor de «Otro modelo…»: no es un modelo, abre el diálogo para
  /// escribirlo. No puede chocar con uno de verdad porque ninguno empieza así.
  static const _otro = '__otro__';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final perfil = ref
        .watch(claudeDefaultsProvider(folder?.claudeProfile))
        .value;
    final enUso = _modeloEnUso(ref, folder, meter);
    final pedido = folder?.claudeModel ?? perfil?.model;
    // Los modelos del menú: de `modelos.json` en `master`, o la última copia,
    // o los de fábrica. Ver [ElCatalogoDeModelos].
    final catalogo =
        ref.watch(elCatalogoProvider).value ?? ElCatalogoDeModelos.deFabrica;
    // Con la versión que dio el CLI —«Opus 5.5»— cuando se sabe, y si no la
    // familia: el alias no dice versión y no hay que inventarla.
    final nombre = enUso == null
        ? null
        : enUso.startsWith('claude-')
        ? modelLabel(enUso)
        : ClaudeModel.fromCliName(enUso)?.label ?? enUso;

    // Los nombres enteros que este perfil ya ha usado: de ahí sale a qué
    // versión apunta hoy cada alias, sin escribirlo a mano.
    final conocidos = {
      ...?perfil?.effortPorModelo.keys,
      ...ref.watch(seenModelsProvider).values,
      ?enUso,
    }.map(PerfilDeClaude.nombreCanonico).where((m) => m.startsWith('claude-'));
    // La etiqueta de un alias: la versión que dice el catálogo, y si no la
    // dice, la última que se le vio usar en este perfil.
    String etiquetaDe(ModeloDelCatalogo alias) {
      if (alias.modelo case final modelo?) return modelLabel(modelo);
      final familia = ClaudeModel.fromCliName(alias.valor);
      final suyos = [
        for (final modelo in conocidos)
          if (familia != null &&
              ClaudeModel.fromCliName(modelo) == familia &&
              !catalogo.anteriores.contains(modelo))
            modelo,
      ]..sort();
      if (suyos.isNotEmpty) return modelLabel(suyos.last);
      return familia?.label ?? modelLabel(alias.valor);
    }

    final elegido = pedido ?? _porDefecto;
    OpcionDelMenu<String> opcion(String valor, String etiqueta) =>
        OpcionDelMenu<String>(
          value: valor,
          titulo: etiqueta,
          elegida: valor == elegido,
        );

    return MenuDelCompositor<String>(
      ancho: 330,
      onSelected: (valor) async {
        // «Otro modelo…» no se elige: se escribe. Lo que se escriba sigue el
        // mismo camino que cualquier opción.
        final modelo = valor == _otro
            ? await escribirOtroModelo(context)
            : valor;
        if (modelo == null) return;
        await elegirModelo(
          ref,
          configDir: folder?.claudeProfile,
          carpeta: folder?.path,
          modelo: modelo == _porDefecto ? null : modelo,
        ).catchError(
          (Object error) => debugPrint('modelo · no se pudo guardar: $error'),
        );
      },
      // 🔴 **Las mismas tres partes que el `/model` del CLI**, y por el mismo
      // motivo: el de por defecto, el último de cada familia por su alias, y
      // las versiones anteriores por su nombre entero. Con solo los alias, lo
      // que la consola ofrecía no se podía elegir aquí.
      itemBuilder: (context) => [
        cabeceraDelMenu(context, strings.modeloDelPerfil(_perfil(folder))),
        opcion(_porDefecto, strings.modelPorDefecto),
        for (final alias in catalogo.alias)
          opcion(alias.valor, etiquetaDe(alias)),
        // El que escribiste a mano, si no está en la lista: que se vea elegido
        // en vez de un menú sin ninguna marca.
        if (pedido != null && pedido.isNotEmpty && !catalogo.loTiene(pedido))
          opcion(
            pedido,
            pedido.startsWith('claude-') ? modelLabel(pedido) : pedido,
          ),
        rayaDelMenu(),
        // Rotulado como un apartado y no como una opción apagada: es el
        // nombre de lo que viene debajo, con la misma voz que la cabecera.
        cabeceraDelMenu(context, strings.modelVersionesAnteriores),
        // Las de la misma familia seguidas, en una fila —«Opus 4.8 · 4.7 ·
        // 4.6»—, como en el mockup: son la misma cosa en tres fechas, y en
        // tres filas alargaban el menú hasta salirse de la ventana.
        for (final grupo in _porFamilia(catalogo.anteriores))
          if (grupo.length == 1)
            opcion(grupo.single, modelLabel(grupo.single))
          else
            _FilaDeVersiones(versiones: grupo, elegida: elegido),
        rayaDelMenu(),
        // Para lo que todavía no está en la lista: un modelo que salió hoy se
        // puede usar hoy, sin esperar a nadie.
        OpcionDelMenu<String>(value: _otro, titulo: strings.modelOtro),
        // Lo que implica elegir aquí, que no es obvio: cambia el perfil, no
        // esta conversación. Ver el 🔴 de arriba.
        pieDelMenu(context, strings.modeloComoEnLaConsola),
      ],
      child: Text(
        nombre ?? strings.modelTitle,
        style: NexusTypography.label.copyWith(
          // Más visible cuando lo fija el repo: ahí manda `.nexus/config.json`
          // y no el perfil, y conviene que se note.
          color: folder?.claudeModel == null ? colors.faint : colors.mute,
        ),
      ),
    );
  }
}

/// Cuánto razona antes de contestar, de más rápido a más listo.
///
/// Como el modelo, es **del perfil** y va **por modelo**: `/effort` lo guarda
/// en `modelSettings.<modelo>.effortLevel`, y aquí se lee y se escribe lo
/// mismo. Ver [ModelMenu].
class EffortMenu extends ConsumerWidget {
  const EffortMenu({super.key, required this.folder, required this.meter});

  final PairedFolder? folder;
  final SessionMeter meter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final strings = context.strings;
    final perfil = ref
        .watch(claudeDefaultsProvider(folder?.claudeProfile))
        .value;
    final enUso = _modeloEnUso(ref, folder, meter);
    // Solo con nombre de verdad se sabe bajo qué modelo guardarlo: con el
    // alias a secas se usa el general.
    final modelo = enUso != null && enUso.startsWith('claude-') ? enUso : null;
    // El vigente: el que fije el repo, o el que el perfil tenga para ese
    // modelo.
    final vigente = ClaudeEffort.fromStored(
      folder?.claudeEffort ?? perfil?.esfuerzoPara(modelo),
    );

    return MenuDelCompositor<ClaudeEffort>(
      ancho: 300,
      onSelected: (option) => unawaited(
        elegirEsfuerzo(
          ref,
          configDir: folder?.claudeProfile,
          carpeta: folder?.path,
          esfuerzo: option,
          modeloEnUso: modelo,
        ).catchError(
          (Object error) => debugPrint('esfuerzo · no se pudo guardar: $error'),
        ),
      ),
      itemBuilder: (context) => [
        cabeceraDelMenu(
          context,
          strings.esfuerzoDelModelo(modelo == null ? null : modelLabel(modelo)),
        ),
        for (final option in ClaudeEffort.values)
          OpcionDelMenu<ClaudeEffort>(
            value: option,
            titulo: option.flag,
            elegida: option == vigente,
            // Los extremos se nombran, a la derecha como el atajo de las
            // otras filas: «xhigh» no dice por sí solo hacia qué lado tira.
            alLado: switch (option) {
              ClaudeEffort.low => strings.effortFaster,
              ClaudeEffort.max => strings.effortSmarter,
              _ => null,
            },
            alLadoEsDato: false,
          ),
        pieDelMenu(context, strings.esfuerzoComoEnLaConsola),
      ],
      child: Text(
        vigente?.flag ?? strings.effortTitle,
        style: NexusTypography.label.copyWith(
          color: folder?.claudeEffort == null ? colors.faint : colors.mute,
        ),
      ),
    );
  }
}

/// Las versiones anteriores, juntas cuando son de la misma familia y vienen
/// seguidas: `opus-4-8, opus-4-7, opus-4-6` es un grupo; `opus-5` y `opus-4-8`
/// no, porque entre ellas va Fable. Seguidas y no todas las de la familia para
/// que el orden del catálogo —el del `/model` del CLI— se respete.
///
/// La familia sale del nombre y no de [ClaudeModel]: así una familia que
/// todavía no conoce el código —llegada por `modelos.json`— se agrupa igual.
List<List<String>> _porFamilia(List<String> modelos) {
  String familiaDe(String modelo) => modelLabel(modelo).split(' ').first;
  final grupos = <List<String>>[];
  for (final modelo in modelos) {
    if (grupos.isNotEmpty &&
        familiaDe(grupos.last.first) == familiaDe(modelo)) {
      grupos.last.add(modelo);
    } else {
      grupos.add([modelo]);
    }
  }
  return grupos;
}

/// Varias versiones de una familia en una sola fila: «Opus 4.8 · 4.7 · 4.6».
///
/// Cada número se pulsa por separado —es una opción cada uno, como en el
/// CLI—; lo que se ahorra es repetir «Opus» tres veces y tres filas de alto.
class _FilaDeVersiones extends PopupMenuEntry<String> {
  const _FilaDeVersiones({required this.versiones, required this.elegida});

  final List<String> versiones;
  final String elegida;

  @override
  double get height => 42;

  @override
  bool represents(String? value) => versiones.contains(value);

  @override
  State<_FilaDeVersiones> createState() => _FilaDeVersionesState();
}

class _FilaDeVersionesState extends State<_FilaDeVersiones> {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final familia = ClaudeModel.fromCliName(widget.versiones.first)?.label;
    String etiqueta(int i) {
      final entera = modelLabel(widget.versiones[i]);
      // Solo la primera lleva el nombre de la familia; las demás, su número.
      return i == 0 || familia == null
          ? entera
          : entera.replaceFirst('$familia ', '');
    }

    TextStyle estilo(String modelo) => NexusTypography.nota.copyWith(
      height: 1.35,
      color: colors.ink,
      fontWeight: modelo == widget.elegida ? FontWeight.w500 : null,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NexusSpacing.s1),
      child: Row(
        children: [
          for (var i = 0; i < widget.versiones.length; i++) ...[
            if (i > 0)
              Text('·', style: estilo('').copyWith(color: colors.faint)),
            Semantics(
              button: true,
              selected: widget.versiones[i] == widget.elegida,
              child: InkWell(
                onTap: () =>
                    Navigator.of(context).pop<String>(widget.versiones[i]),
                hoverColor: colors.accent.withValues(alpha: 0.12),
                focusColor: colors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  // La primera, con la sangría de las filas de siempre para
                  // que «Opus» quede alineado con los nombres de arriba.
                  padding: EdgeInsets.symmetric(
                    horizontal: i == 0 ? 10 : 5,
                    vertical: 7,
                  ),
                  child: Text(etiqueta(i), style: estilo(widget.versiones[i])),
                ),
              ),
            ),
          ],
          if (widget.versiones.contains(widget.elegida)) ...[
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                '✓',
                style: NexusTypography.data.copyWith(color: colors.mute),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// El diálogo de «Otro modelo…». Devuelve lo escrito, o `null` si se canceló.
///
/// Solo deja pasar un nombre de modelo —ver [ElCatalogoDeModelos.nombreValido]—:
/// lo que salga de aquí se escribe en el `settings.json` del perfil, y un
/// espacio o unas comillas ahí romperían el perfil también para la consola.
Future<String?> escribirOtroModelo(BuildContext context) async {
  if (!context.mounted) return null;
  return showDialog<String>(
    context: context,
    builder: (_) => const _OtroModelo(),
  );
}

/// Un widget propio y no un `StatefulBuilder` para que el campo se libere
/// cuando el diálogo **desaparece**, no cuando se cierra: entre una cosa y otra
/// está la animación de salida, que lo sigue pintando. Liberarlo antes reventaba
/// —lo encontró la prueba—.
class _OtroModelo extends StatefulWidget {
  const _OtroModelo();

  @override
  State<_OtroModelo> createState() => _OtroModeloState();
}

class _OtroModeloState extends State<_OtroModelo> {
  final _campo = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  void _usar() {
    final escrito = _campo.text.trim().toLowerCase();
    if (!ElCatalogoDeModelos.nombreValido.hasMatch(escrito)) {
      setState(() => _error = context.strings.modelOtroNoVale);
      return;
    }
    Navigator.of(context).pop(escrito);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = context.colors;
    return AlertDialog(
      backgroundColor: colors.deep,
      title: Text(
        strings.modelOtroTitulo,
        style: NexusTypography.data.copyWith(color: colors.ink),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.modelOtroPista,
              style: NexusTypography.label.copyWith(color: colors.mute),
            ),
            const SizedBox(height: NexusSpacing.s4),
            TextField(
              key: const ValueKey('otro-modelo'),
              controller: _campo,
              autofocus: true,
              autocorrect: false,
              style: NexusTypography.mono.copyWith(color: colors.ink),
              decoration: InputDecoration(
                hintText: 'claude-sonnet-5-5',
                errorText: _error,
              ),
              onSubmitted: (_) => _usar(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        TextButton(onPressed: _usar, child: Text(strings.modelOtroUsar)),
      ],
    );
  }
}
