import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/core/i18n/strings_scope.dart';
import 'package:nexus/core/design_system/nexus_colors.dart';
import 'package:nexus/features/remote/presentation/providers/mirror_providers.dart';
import 'package:nexus/core/design_system/nexus_typography.dart';
import 'package:nexus/features/remote/presentation/widgets/mobile_chrome.dart';

/// Abrir la escritura con la frase.
///
/// Es la decisión 2.4 del contrato, ya corregida: el diseño original pedía confirmar
/// **en el escritorio**, y eso volvía imposible el caso principal —estando fuera no
/// hay nadie delante del Mac—. La frase cumple el requisito de verdad, exigir algo
/// que quien robe el teléfono no tenga, sin exigir además tu presencia.
///
/// **El teléfono no la guarda nunca.** Se teclea cuando hace falta y la verifica el
/// Mac; eso es lo que hace que llevarse el teléfono no baste para escribir.
///
/// Con la hoja del teléfono y no la de Material: ver [mostrarHojaDelMovil].
Future<void> mostrarFraseDeEscritura(BuildContext context, WidgetRef ref) =>
    mostrarHojaDelMovil<void>(context, (_) => const _Hoja());

class _Hoja extends ConsumerStatefulWidget {
  const _Hoja();

  @override
  ConsumerState<_Hoja> createState() => _HojaState();
}

class _HojaState extends ConsumerState<_Hoja> {
  final _frase = TextEditingController();
  String? _codigo;
  var _probando = false;

  @override
  void dispose() {
    _frase.dispose();
    super.dispose();
  }

  Future<void> _probar() async {
    setState(() => _probando = true);
    final codigo = await ref
        .read(writePermissionProvider.notifier)
        .abrir(_frase.text);
    if (!mounted) return;
    setState(() {
      _codigo = codigo;
      _probando = false;
    });
    if (codigo == null) Navigator.of(context).pop();
  }

  /// Cada código dice **algo distinto que hacer**. Un solo «no se pudo» dejaría a
  /// quien lo lee sin saber si teclear otra vez, ir al Mac, o esperar.
  String _decir(NexusStrings strings, String codigo) => switch (codigo) {
    'noPhrase' => strings.mobileNoPhrase,
    'wrongPhrase' => strings.mobileWrongPhrase,
    'tooManyAttempts' => strings.mobileTooManyAttempts,
    _ => strings.mobileUnlockFailed,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;

    return HojaDelMovil(
      children: [
        // Un rótulo y no un titular, como las demás pantallas: el nombre de lo que
        // se hace en la letra del instrumento, y la frase de debajo es la que habla.
        Text(
          strings.mobileUnlockTitle.toUpperCase(),
          style: NexusTypography.label.copyWith(color: colors.mute),
        ),
        // En sans y no en mono: es una explicación de qué pasa con la frase, no un
        // dato, y en mono se leía como un log.
        Text(
          strings.mobileUnlockExplainer,
          style: NexusTypography.nota.copyWith(
            color: colors.mute,
            fontSize: 13.5,
          ),
        ),
        MobileInput(
          campoKey: const ValueKey('frase'),
          controlador: _frase,
          pista: strings.mobilePhraseHint,
          oculto: true,
          autofocus: true,
          alMandar: (_) => _probar(),
        ),
        // El error **en la misma hoja** y debajo del campo, como el mockup: la
        // frase se vuelve a teclear ahí mismo, sin cerrar ni abrir nada.
        if (_codigo != null)
          Text(
            _decir(strings, _codigo!),
            key: const ValueKey('fallo-de-la-frase'),
            style: NexusTypography.nota.copyWith(
              color: colors.err,
              fontSize: 12.5,
            ),
          ),
        WideAction(
          key: const ValueKey('abrir-escritura'),
          texto: _probando ? strings.mobileChecking : strings.mobileOpen,
          principal: true,
          alTocar: _probando ? null : _probar,
        ),
      ],
    );
  }
}
