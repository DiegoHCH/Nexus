import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexus/core/design_system/la_apariencia_de_fuera.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_ensena_el_hub.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_pide_el_hub.dart';
import 'package:nexus/features/hub/domain/entities/dispositivo_del_hub.dart';
import 'package:nexus/features/hub/presentation/widgets/el_hub.dart';
import 'package:nexus/features/hub/presentation/widgets/la_columna_del_telefono.dart';
import 'package:nexus/features/hub/presentation/widgets/la_pantalla_del_emulador.dart';
import 'package:nexus/features/hub/presentation/widgets/la_pantalla_del_enchufado.dart';

/// **El motor del hub de dispositivos**, el de su ventana. Ver `NexusHub`.
///
/// Como el de la botonera: no tiene los providers de la app ni sus plugins.
/// Pinta lo que le llega en la foto y dice lo que se pulsa.
void arrancarElHub() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ElHubSolo());
}

class ElHubSolo extends StatefulWidget {
  const ElHubSolo({super.key});

  @override
  State<ElHubSolo> createState() => _ElHubSoloState();
}

class _ElHubSoloState extends State<ElHubSolo> {
  static const _canal = MethodChannel('com.katanalabs.nexus/hub.ventana');

  LoQueEnsenaElHub? _foto;

  /// El alto del registro que se dejó la última vez: lo guarda el lado nativo,
  /// que este motor no tiene los plugins de la app. `null` hasta que contesta.
  double? _altoDelRegistro;

  @override
  void initState() {
    super.initState();
    _canal.setMethodCallHandler((llamada) async {
      if (llamada.method == 'pinta') _recibe(llamada.arguments);
      return null;
    });
    // La primera se pide: la app la manda al abrir, cuando este motor todavía
    // está arrancando y nadie escucha; el lado nativo se la guarda.
    unawaited(
      _canal
          .invokeMethod<Object?>('lista')
          .then(_recibe, onError: (Object _) {}),
    );
    unawaited(
      _canal.invokeMethod<double>('altoDelRegistro').then((alto) {
        if (alto != null && mounted) setState(() => _altoDelRegistro = alto);
      }, onError: (Object _) {}),
    );
  }

  void _recibe(Object? datos) {
    if (datos is! Map<Object?, Object?> || !mounted) return;
    setState(() => _foto = LoQueEnsenaElHub.fromMap(datos));
  }

  void _guardaElAltoDelRegistro(double alto) => unawaited(
    _canal
        .invokeMethod<void>('guardaElAltoDelRegistro', alto)
        .catchError((Object _) {}),
  );

  void _pide(PedidoDelHub pedido) => unawaited(
    _canal.invokeMethod<void>('pide', pedido.toMap()).catchError((Object _) {}),
  );

  /// La pantalla de dentro (T6–T8): por ahora, la del emulador de Android por
  /// su gRPC. Lo demás —iOS, el físico sin su historia— sigue con su aviso.
  Widget? _pantalla(DispositivoDelHub d, Widget aviso) {
    final deviceId = d.deviceId;
    if (!d.android || deviceId == null) return null;
    Widget columna(LaConexionDeLaPantalla conexion, Widget pantalla) =>
        LaColumnaDelTelefono(
          conexion: conexion,
          pantalla: pantalla,
          onVerEnSuVentana: conexion.conVentana
              ? () => _pide(
                  d.clase == ClaseDeDispositivo.enchufado
                      ? VerFuera(d.id, ComoVerFuera.scrcpy)
                      : TraerAlFrente(d.id),
                )
              : null,
          onApagar: d.clase == ClaseDeDispositivo.emulador
              ? () => _pide(CerrarDispositivo(d.id))
              : null,
          onGirar: conexion.girar,
          sonido: conexion.sonido,
          onSonido: conexion.alternarSonido,
        );
    // Un Android enchufado, por scrcpy (T12).
    if (d.clase == ClaseDeDispositivo.enchufado) {
      return LaPantallaDelEnchufado(
        key: ValueKey('enchufado-$deviceId'),
        serial: deviceId,
        sinPantalla: aviso,
        alrededor: columna,
      );
    }
    return LaPantallaDelEmulador(
      // Otro dispositivo, otra conexión.
      key: ValueKey(deviceId),
      deviceId: deviceId,
      sinPantalla: aviso,
      alrededor: columna,
    );
  }

  @override
  Widget build(BuildContext context) {
    final foto = _foto;
    final apariencia = foto?.apariencia;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // La apariencia de Nexus, tal como venga en la foto: tema, acento e
      // idioma. Ver `LaAparienciaDeFuera`.
      //
      // 🔴 **Siempre un tema de Nexus, y sin animar el cambio** (11 nov). Con
      // `null` hasta la primera foto, la ventana tenía el tema de fábrica de
      // Flutter; al llegar la foto, `MaterialApp` animaba el cambio y su
      // primer fotograma (`t = 0`) es el tema de antes tal cual, sin
      // `NexusColors`: el hub salía en rojo («context.colors no encontró
      // NexusColors»), y se quedaba así si la ventana aún no estaba a la vista.
      // Sin animar, tampoco asoma el oscuro de fábrica a quien usa el claro.
      theme: (apariencia ?? LaAparienciaDeFuera.deFabrica).tema,
      themeAnimationStyle: AnimationStyle.noAnimation,
      builder: (context, child) => StringsScope(
        strings: NexusStrings.of(apariencia?.locale ?? const Locale('es')),
        child: child!,
      ),
      home: foto == null
          ? const SizedBox.shrink()
          : Material(
              type: MaterialType.transparency,
              child: ElHub(
                foto: foto,
                onPedido: _pide,
                pantalla: _pantalla,
                altoDelRegistro: _altoDelRegistro,
                onAltoDelRegistro: _guardaElAltoDelRegistro,
              ),
            ),
    );
  }
}
