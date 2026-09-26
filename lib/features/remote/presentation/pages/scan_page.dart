import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/core/design_system/nexus_colors.dart';
import 'package:nexus/core/design_system/nexus_spacing.dart';
import 'package:nexus/core/design_system/nexus_typography.dart';
import 'package:nexus/features/remote/domain/pairing.dart';
import 'package:nexus/features/remote/domain/pairing_code.dart';
import 'package:nexus/features/remote/domain/tailscale.dart';
import 'package:nexus/features/remote/presentation/pages/pairing_page.dart';
import 'package:nexus/features/remote/presentation/providers/pairing_providers.dart';
import 'package:nexus/features/remote/presentation/widgets/corner_frame.dart';
import 'package:nexus/features/remote/presentation/widgets/mobile_chrome.dart';

/// Si este teléfono está en Tailscale, y con qué dirección.
///
/// Ocupa el sitio donde el mockup pone «Mac detectado en la red · 192.168.1.42». Eso
/// era descubrimiento por red local, que la decisión `lo1` descartó — pero el hueco
/// merece llevar algo cierto, y esto lo es: **es la comprobación que faltaba**. La
/// primera vez que se probó el canal de verdad, el teléfono no tenía Tailscale y la
/// pantalla solo podía decir «reconectando» sin fin. Aquí se ve antes de escanear.
final tailscaleDelTelefonoProvider = FutureProvider<String?>((ref) async {
  final dir = await Tailscale.buscar();
  return dir?.address;
});

/// Emparejar apuntando al código del Mac.
///
/// Sigue la **forma** del mockup Móvil 01 —rótulo arriba, la frase centrada, el visor
/// con escuadras, el chip, el dato en mono, el botón ancho abajo y el pie— y **no su
/// mecanismo**: allí hay descubrimiento por red local y aquí solo hay Tailscale.
///
/// **Escribirlo a mano no es el plan B: es la misma ruta.** Las dos producen el mismo
/// emparejamiento y validan con la misma función, así que el escáner solo ahorra
/// teclear 43 caracteres.
class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  final _camara = MobileScannerController(
    // Solo QR. Con todos los formatos activos, el código de barras de un producto en
    // la mesa dispara una lectura que hay que descartar — y cada descarte es un
    // mensaje de error que nadie pidió.
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  /// Se para en cuanto uno vale: sin esto la cámara sigue leyendo mientras la pantalla
  /// navega, y llegan tres emparejamientos iguales.
  var _yaVale = false;
  PairingProblem? _problema;

  @override
  void dispose() {
    _camara.dispose();
    super.dispose();
  }

  Future<void> _leido(BarcodeCapture captura) async {
    if (_yaVale) return;
    final texto = captura.barcodes.firstOrNull?.rawValue;
    if (texto == null || texto.isEmpty) return;

    final leido = PairingCode.leer(texto);
    if (leido.problema != null) {
      // Se dice y **se sigue escaneando**: lo más probable es que la cámara viera otro
      // QR de la mesa, y cerrar el escáner por eso obligaría a volver a abrirlo.
      if (mounted) setState(() => _problema = leido.problema);
      return;
    }

    _yaVale = true;
    await _camara.stop();
    final pareja = leido.emparejamiento!;
    await ref
        .read(pairingControllerProvider.notifier)
        .emparejar(url: pareja.url.toString(), token: pareja.token.value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final tailscale = ref.watch(tailscaleDelTelefonoProvider);

    return Scaffold(
      backgroundColor: colors.void_,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // La cabecera de siempre, diciendo lo que es verdad aquí: **todavía no
            // hay Mac**. Sin ella esta era la única pantalla sin marca ni estado, y
            // parecía de otra app justo en la puerta.
            const MobileChrome(sinEmparejar: true),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  MedidasDelMovil.margen,
                  0,
                  MedidasDelMovil.margen,
                  MedidasDelMovil.pie,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: NexusSpacing.s4),
                    // Un rótulo y no un titular, alineado a la izquierda como el
                    // resto de pantallas: el nombre de la pantalla en la letra del
                    // instrumento, y la frase de debajo es la que habla.
                    Text(
                      strings.mobilePairTitle,
                      style: NexusTypography.label.copyWith(color: colors.mute),
                    ),
                    const SizedBox(height: NexusSpacing.s2),
                    // En `nota` y no en titular: es una indicación —dónde está el
                    // código en el Mac— y el mockup la da la ruta entera de Ajustes,
                    // que en letra grande ocupaba media pantalla.
                    Text(
                      strings.mobilePointAtCode,
                      style: NexusTypography.nota.copyWith(
                        color: colors.mute,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    // El visor cuadrado y con escuadras. Cuadrado porque un QR lo es:
                    // un visor ancho invita a encuadrarlo mal. Se encoge si no cabe,
                    // que es lo único que puede encoger sin perder nada.
                    Flexible(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 250,
                            maxHeight: 250,
                          ),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: LayoutBuilder(
                              builder: (context, caja) => Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Sin imagen de la cámara todavía, el hueco se
                                  // pinta con el degradado del mockup y no en negro:
                                  // un cuadrado negro se lee como un fallo.
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [colors.rise, colors.deep],
                                      ),
                                    ),
                                    child: MobileScanner(
                                      key: const ValueKey('el-visor'),
                                      controller: _camara,
                                      onDetect: _leido,
                                      placeholderBuilder: (_) =>
                                          const SizedBox.expand(),
                                      errorBuilder: (context, error) =>
                                          _SinCamara(error: error),
                                    ),
                                  ),
                                  IgnorePointer(
                                    child: CornerFrame(
                                      lado: caja.maxWidth,
                                      largo: 28,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(child: _Tailscale(estado: tailscale)),
                    if (_problema != null) ...[
                      const SizedBox(height: NexusSpacing.s3),
                      Text(
                        _decir(strings, _problema!),
                        key: const ValueKey('problema-del-codigo'),
                        textAlign: TextAlign.center,
                        style: NexusTypography.nota.copyWith(
                          color: colors.warn,
                        ),
                      ),
                    ],
                    const Spacer(),
                    // Ancho y abajo, como en el mockup: es la otra ruta entera, no un
                    // enlace de socorro escondido.
                    WideAction(
                      key: const ValueKey('a-mano'),
                      texto: strings.mobileTypeCodeByHand,
                      alTocar: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PairingPage(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // En sans: es una explicación de lo que es esta app, no un dato.
                    Text(
                      strings.mobilePhoneRunsNothing,
                      textAlign: TextAlign.center,
                      style: NexusTypography.nota.copyWith(
                        color: colors.mute,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _decir(
    NexusStrings strings,
    PairingProblem problema,
  ) => switch (problema) {
    // El caso frecuente, y por eso el mensaje no culpa a nadie: la cámara vio otro
    // código antes que el bueno.
    PairingProblem.noEsDeNexus => strings.mobileScanNotNexus,
    PairingProblem.tokenCorto => strings.mobileScanIncomplete,
    PairingProblem.urlIlegible ||
    PairingProblem.esquemaEquivocado ||
    PairingProblem.faltaElPuerto => strings.mobileScanUnreadable,
  };
}

/// Si este teléfono está en Tailscale, en **una sola línea** con su punto de color,
/// como el mockup: «● TAILSCALE ACTIVO · 100.73.35.12».
///
/// Estuvo en una caja con borde y la dirección debajo, y la caja se leía como un botón
/// que no hacía nada. Es un estado —como el chip de la cabecera— y se dice igual: el
/// punto y el color con la palabra, en verde si está y en ámbar si no.
class _Tailscale extends StatelessWidget {
  const _Tailscale({required this.estado});

  final AsyncValue<String?> estado;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    final (texto, dato, pista, bien) = switch (estado) {
      AsyncData(value: final String dir) => (
        strings.mobileTailscaleActive,
        dir,
        null,
        true,
      ),
      // **Sin Tailscale no va a conectar**, y decirlo aquí es lo que evita el
      // «reconectando» sin explicación que costó una tarde de depuración.
      AsyncData() => (
        strings.mobileNoTailscale,
        null,
        strings.mobileNoTailscaleHint,
        false,
      ),
      AsyncError() => (
        strings.mobileTailscaleUnknown,
        null,
        strings.mobileTailscaleUnknownHint,
        false,
      ),
      _ => (strings.mobileCheckingTailscale, null, null, false),
    };
    final color = bien ? colors.ok : colors.warn;

    return Column(
      key: const ValueKey('tailscale-del-telefono'),
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(texto, style: NexusTypography.label.copyWith(color: color)),
            // La dirección en mono, que es el dato; el rótulo en la letra del
            // instrumento, que es lo que dice qué es.
            if (dato != null)
              Text(
                ' · $dato',
                style: NexusTypography.data.copyWith(color: color),
              ),
          ],
        ),
        if (pista != null) ...[
          const SizedBox(height: NexusSpacing.s1),
          Text(
            pista,
            textAlign: TextAlign.center,
            style: NexusTypography.nota.copyWith(
              color: colors.mute,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

/// Cuando no hay cámara o no se da permiso.
///
/// **Es un estado de verdad y no un hueco negro**, que es lo que sale por defecto. El
/// mockup dedica una pantalla entera a «sin micrófono» con esta forma —qué pasó, por
/// qué y qué se puede hacer— y esto es su equivalente para la cámara. La salida
/// existe justo debajo: escribirlo a mano no necesita permisos.
class _SinCamara extends StatelessWidget {
  const _SinCamara({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return ColoredBox(
      color: colors.deep,
      child: Padding(
        padding: const EdgeInsets.all(NexusSpacing.s4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              strings.mobileNoCamera,
              key: const ValueKey('sin-camara'),
              style: NexusTypography.label.copyWith(color: colors.warn),
            ),
            const SizedBox(height: NexusSpacing.s3),
            Text(
              error.errorCode == MobileScannerErrorCode.permissionDenied
                  ? strings.mobileCameraDenied
                  : strings.mobileCameraUnavailable,
              textAlign: TextAlign.center,
              style: NexusTypography.nota.copyWith(color: colors.mute),
            ),
          ],
        ),
      ),
    );
  }
}
