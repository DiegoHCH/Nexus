import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexus/core/design_system/nexus_theme.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/run/presentation/state/lo_que_ensena_la_botonera.dart';
import 'package:nexus/features/run/presentation/widgets/la_barra_de_corridas.dart';

/// **La botonera en su propia ventana, fuera de Nexus.**
///
/// Corre en un motor de Flutter **aparte**, dentro del panel sin marco que
/// monta `NexusBotonera`, como el orbe del escritorio. Aquí no hay app: hay una
/// barra, una foto de lo que corre que llega por un canal, y el mismo canal
/// para decir qué se pulsó.
///
/// 🔴 **Y no decide nada.** Ni qué botones van, ni en qué orden, ni qué hace
/// cada uno: eso lo sabe la app, que es la que tiene las corridas. Si este
/// motor aplicara alguna regla habría dos sitios donde mantenerla —y dos
/// motores que pueden no estar de acuerdo sobre si «Recargar» se ofrece—.
///
/// 🔴 **El punto de entrada vive en `lib/main.dart`** y esto es solo el cuerpo,
/// por lo mismo que el orbe: el motor busca la función en la librería principal.
void arrancarLaBotoneraDeFuera() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _LaBotoneraSola());
}

class _LaBotoneraSola extends StatefulWidget {
  const _LaBotoneraSola();

  @override
  State<_LaBotoneraSola> createState() => _LaBotoneraSolaState();
}

class _LaBotoneraSolaState extends State<_LaBotoneraSola> {
  static const _canal = MethodChannel('com.katanalabs.nexus/botonera.ventana');

  /// Lo que hay que enseñar. `null` hasta que llega la primera foto: una barra
  /// vacía pintada un instante se leería como «no corre nada».
  LaFotoDeLaBotonera? _foto;

  /// Lo que mide la barra, para que la ventana crezca con ella.
  final _laLlave = GlobalKey();
  double? _altoDicho;

  @override
  void initState() {
    super.initState();
    _canal.setMethodCallHandler((llamada) async {
      if (llamada.method == 'pinta') _recibe(llamada.arguments);
      return null;
    });
    // 🔴 **Y la primera se pide, no se espera.** La app la manda al abrir,
    // cuando este motor todavía está arrancando y nadie escucha el canal; el
    // lado nativo se la guarda, y aquí se recoge en cuanto hay alguien.
    unawaited(
      _canal
          .invokeMethod<Object?>('lista')
          .then(_recibe, onError: (Object _) {}),
    );
  }

  void _recibe(Object? datos) {
    if (datos is! Map<Object?, Object?> || !mounted) return;
    setState(() => _foto = LaFotoDeLaBotonera.fromMap(datos));
  }

  void _decir(String que, [Object? datos]) => unawaited(
    _canal.invokeMethod<void>(que, datos).catchError((Object _) {}),
  );

  /// Una fila más —otra corrida, un trabajo— y la ventana tiene que crecer.
  /// Se mide después de pintar, como la de dentro: calcularlo a mano se queda
  /// viejo el día que alguien añada una fila.
  void _mide() {
    final alto = _laLlave.currentContext?.size?.height;
    if (alto == null || alto == _altoDicho) return;
    _altoDicho = alto;
    _decir('mide', {'alto': alto});
  }

  @override
  Widget build(BuildContext context) {
    final foto = _foto;
    final acento = foto?.acento == null ? null : Color(foto!.acento!);
    WidgetsBinding.instance.addPostFrameCallback((_) => _mide());

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Con el tema de la casa, que sin él los botones no se pintan, y con el
      // claro o el oscuro que se ve en la app: fuera sigue siendo Nexus.
      theme: foto?.claro ?? false
          ? NexusTheme.light(accent: acento)
          : NexusTheme.dark(accent: acento),
      // Por encima del Navigator, como en la app: los tooltips se pintan en el
      // `Overlay`, fuera del `home`, y también hablan.
      builder: (context, child) => StringsScope(
        strings: NexusStrings.of(Locale(foto?.idioma ?? 'es')),
        child: child!,
      ),
      // Sin fondo y sin `Scaffold`, por lo que se aprendió con el orbe: el
      // `Scaffold` pinta el fondo del tema aunque se le pida transparente, y
      // aquí lo que tiene que verse en las esquinas es lo que hay detrás.
      home: ColoredBox(
        color: Colors.transparent,
        child: foto == null
            ? const SizedBox.shrink()
            // Sin tope de alto: la barra mide lo que midan sus filas y la
            // ventana la sigue. Con el alto de la ventana como tope, una fila
            // nueva desbordaba un fotograma antes de que la ventana creciera.
            : OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: 0,
                maxHeight: double.infinity,
                child: KeyedSubtree(
                  key: _laLlave,
                  child: LaBarraDeCorridas(
                    lo: foto.lo,
                    onPedido: (pedido) => _decir('pide', pedido.toMap()),
                    // La ventana se mueve entera y la mueve el lado nativo, con
                    // la posición del ratón en la pantalla: con los deltas de
                    // aquí, que se cuentan dentro de una ventana que se está
                    // moviendo, se perseguiría a sí misma.
                    onEmpezarArrastre: () =>
                        _decir('arrastre', {'fase': 'empieza'}),
                    onArrastrar: (_) => _decir('arrastre', {'fase': 'sigue'}),
                    onSoltar: () => _decir('arrastre', {'fase': 'suelta'}),
                    sePuedeEsconder: true,
                    conSombra: false,
                  ),
                ),
              ),
      ),
    );
  }
}
