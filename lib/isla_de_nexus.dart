import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexus/core/design_system/nexus_theme.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/isla/presentation/state/la_foto_de_la_isla.dart';
import 'package:nexus/features/isla/presentation/widgets/la_isla.dart';

/// **La isla en su propia ventana**: Nexus en pequeño, arriba en el centro.
///
/// Corre en un motor de Flutter **aparte**, dentro del panel sin marco que
/// monta `NexusIsla`, como la botonera. Aquí no hay app: hay una foto que llega
/// por un canal y el mismo canal para decir qué se pulsó. Qué hace cada cosa lo
/// decide la app, que es la que tiene las conversaciones y la terminal.
///
/// 🔴 **El punto de entrada vive en `lib/main.dart`** y esto es solo el cuerpo:
/// el motor busca la función en la librería principal.
void arrancarLaIsla() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _LaIslaSola());
}

class _LaIslaSola extends StatefulWidget {
  const _LaIslaSola();

  @override
  State<_LaIslaSola> createState() => _LaIslaSolaState();
}

class _LaIslaSolaState extends State<_LaIslaSola> {
  static const _canal = MethodChannel('com.katanalabs.nexus/isla.ventana');

  /// `null` hasta que llega la primera foto: una isla vacía pintada un
  /// instante se leería como «no pasa nada».
  LaFotoDeLaIsla? _foto;

  /// Lo que mide la isla, para que la ventana crezca con ella.
  final _laLlave = GlobalKey();
  double? _altoDicho;

  @override
  void initState() {
    super.initState();
    _canal.setMethodCallHandler((llamada) async {
      if (llamada.method == 'pinta') _recibe(llamada.arguments);
      return null;
    });
    // La primera se pide, no se espera: la app la manda al abrir, cuando este
    // motor todavía arranca y nadie escucha. El lado nativo se la guarda.
    unawaited(
      _canal
          .invokeMethod<Object?>('lista')
          .then(_recibe, onError: (Object _) {}),
    );
  }

  void _recibe(Object? datos) {
    if (datos is! Map<Object?, Object?> || !mounted) return;
    setState(() => _foto = LaFotoDeLaIsla.fromMap(datos));
  }

  void _decir(String que, [Object? datos]) => unawaited(
    _canal.invokeMethod<void>(que, datos).catchError((Object _) {}),
  );

  /// Un permiso que llega o una conversación que se pone a trabajar, y la
  /// ventana tiene que crecer. Se mide después de pintar, como la botonera.
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
      theme: foto?.claro ?? false
          ? NexusTheme.light(accent: acento)
          : NexusTheme.dark(accent: acento),
      builder: (context, child) => StringsScope(
        strings: NexusStrings.of(Locale(foto?.idioma ?? 'es')),
        child: child!,
      ),
      // Sin `Scaffold`, por lo que se aprendió con el orbe: pinta el fondo del
      // tema aunque se le pida transparente, y en las esquinas redondas tiene
      // que verse lo que hay detrás.
      home: ColoredBox(
        color: Colors.transparent,
        child: foto == null
            ? const SizedBox.shrink()
            : OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: 0,
                maxHeight: double.infinity,
                child: KeyedSubtree(
                  key: _laLlave,
                  // `Material` para que las filas tengan su tinta al pulsar.
                  child: Material(
                    type: MaterialType.transparency,
                    child: LaIsla(
                      foto: foto,
                      onPedido: (pedido) => _decir('pide', pedido.toMap()),
                      onVolver: () => _decir('abrirNexus'),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
