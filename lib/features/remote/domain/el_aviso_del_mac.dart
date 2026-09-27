import 'package:flutter/foundation.dart';
import 'package:nexus/features/remote/domain/actualizacion_del_mac.dart';
import 'package:nexus/features/updates/domain/entities/release_check.dart';

/// Lo que el teléfono enseña de la actualización del Mac.
///
/// Más estados que los que cuenta el Mac, y el motivo es que **el tramo difícil es
/// el que el Mac no puede contar**: mientras se reinicia no hay Mac que hable, y al
/// volver es otro proceso que no recuerda haberse ido. Esa parte —se fue, está
/// volviendo, volvió en la nueva o no volvió— solo la puede llevar el teléfono.
///
/// `sealed` para que el aviso decida qué pinta con un `switch` y el compilador
/// señale el sitio exacto el día que se añada un estado.
@immutable
sealed class AvisoDelMac {
  const AvisoDelMac();
}

/// No hay nada que decir. Es como nace, y como se queda casi siempre.
class SinAvisoDelMac extends AvisoDelMac {
  const SinAvisoDelMac();
}

/// El Mac ofrece una versión nueva, y el teléfono enseña lo mismo que su aviso.
class ActualizacionEnElMac extends AvisoDelMac {
  const ActualizacionEnElMac(
    this.vista, {
    this.pidiendo = false,
    this.problema,
  });

  final ActualizacionDelMac vista;

  /// Se pulsó «actualizar y reiniciar» y el Mac todavía no ha contestado.
  final bool pidiendo;

  /// Por qué no se pudo aceptar, si no se pudo.
  final ProblemaAlActualizar? problema;
}

/// Por qué un sí del teléfono no llegó a cumplirse.
enum ProblemaAlActualizar {
  /// El Mac ya no tiene esa versión pendiente: se instaló, se descartó o falló allí.
  yaNoEsta,

  /// El Mac ofrece ya otra versión, y el sí se dio a la que se vio.
  otraVersion,

  /// Esa copia de Nexus no puede reemplazarse sin moverla a Aplicaciones.
  noSePuede,

  /// No se llegó al Mac para decírselo.
  sinEnlace,
}

/// El Mac se está reiniciando en la versión nueva: se fue y se le espera.
class ReiniciandoElMac extends AvisoDelMac {
  const ReiniciandoElMac({required this.version, this.desde});

  /// La que se está instalando.
  final String version;

  /// La que corría antes. Sirve para distinguir, al volver, «volvió en la nueva» de
  /// «volvió igual que se fue».
  final String? desde;
}

/// El Mac volvió, y en la versión nueva: lo ha dicho él al saludar.
class MacDeVuelta extends AvisoDelMac {
  const MacDeVuelta(this.version);

  final String version;
}

/// El Mac no volvió como se esperaba.
class MacNoVolvio extends AvisoDelMac {
  const MacNoVolvio({required this.version, this.desde, required this.porQue});

  final String version;
  final String? desde;
  final PorQueNoVolvio porQue;
}

enum PorQueNoVolvio {
  /// Pasó el plazo sin que contestara. Puede seguir instalando o haberse dormido:
  /// se puede volver a intentar.
  sinRespuesta,

  /// Contestó, pero en la versión de antes y sin nada pendiente: la instalación no
  /// llegó a hacerse.
  sinActualizar,
}

/// Cómo cambia el aviso con cada cosa que pasa.
///
/// **Funciones puras**, y es lo que permite probar el tramo en el que el Mac no
/// está sin tener que reiniciar ningún Mac: qué se enseña si el enlace cae con la
/// versión lista, qué si vuelve con la de antes, qué si no vuelve. Los tiempos y
/// las peticiones los pone quien las llama.
abstract final class ElAvisoDelMac {
  /// El Mac contó algo de su actualización: en un saludo, con la versión que corre
  /// ([saludo] y [versionDelMac]), o en un evento suelto.
  static AvisoDelMac alSaber(
    AvisoDelMac antes,
    ActualizacionDelMac? vista, {
    bool saludo = false,
    String? versionDelMac,
  }) {
    // Instalando es irse: da igual cómo estuviera antes el aviso.
    if (vista?.fase == FaseDelMac.instalando) {
      return switch (antes) {
        final ReiniciandoElMac ya => ya,
        _ => ReiniciandoElMac(version: vista!.version, desde: vista.actual),
      };
    }

    switch (antes) {
      // **Esperando a que vuelva.** Lo que decide es el saludo: es el único mensaje
      // que dice qué versión corre, así que un evento suelto no prueba nada.
      case ReiniciandoElMac(:final version, :final desde) ||
          MacNoVolvio(
            :final version,
            :final desde,
            porQue: PorQueNoVolvio.sinRespuesta,
          ):
        if (!saludo) {
          // Lo que diga antes de irse —un fallo de Sparkle— sí cuenta: es que no se
          // fue. Un «ya no hay nada» suelto no: puede ser el último aliento del
          // proceso viejo, y lo que diga el saludo lo confirmará.
          return vista == null ? antes : ActualizacionEnElMac(vista);
        }
        final corre = versionDelMac;
        if (corre != null && ReleaseCheck.compare(corre, version) >= 0) {
          return MacDeVuelta(corre);
        }
        // Volvió igual y con la versión todavía pendiente: no llegó a irse —el
        // enlace se cayó por otra cosa mientras esperaba—. Se sigue enseñando lo que
        // enseña el Mac.
        if (vista != null) return ActualizacionEnElMac(vista);
        // Sin saber qué versión corre —un Mac que no lo dice— no se puede afirmar
        // ni que salió bien ni que salió mal. Lo honesto es callar.
        if (corre == null) return const SinAvisoDelMac();
        return MacNoVolvio(
          version: version,
          desde: desde,
          porQue: PorQueNoVolvio.sinActualizar,
        );

      // Ya se dijo cómo acabó. Un «no hay nada» no lo borra —es lo esperado tras
      // volver—; una versión nueva, sí: es otra noticia.
      case MacDeVuelta() || MacNoVolvio():
        return vista == null ? antes : ActualizacionEnElMac(vista);

      case SinAvisoDelMac() || ActualizacionEnElMac():
        return vista == null
            ? const SinAvisoDelMac()
            : ActualizacionEnElMac(vista);
    }
  }

  /// Se cayó el enlace.
  ///
  /// Si el Mac estaba comprometido a reiniciarse, **es lo esperado** y se dice así:
  /// «actualizando el Mac», no «se perdió el enlace». Si no, el aviso se queda como
  /// estaba — lo que el Mac ofrece no cambia porque el teléfono pierda cobertura.
  static AvisoDelMac alPerderElEnlace(AvisoDelMac antes) => switch (antes) {
    ActualizacionEnElMac(:final vista, :final pidiendo)
        when vista.vaAReiniciarse || (pidiendo && vista.reiniciaYa) =>
      ReiniciandoElMac(version: vista.version, desde: vista.actual),
    _ => antes,
  };

  /// El Mac contestó al sí.
  static AvisoDelMac alContestar(
    AvisoDelMac antes,
    TrasAceptarEnElMac? tras,
  ) => switch (antes) {
    ActualizacionEnElMac(:final vista) => switch (tras) {
      TrasAceptarEnElMac.reinicia => ReiniciandoElMac(
        version: vista.version,
        desde: vista.actual,
      ),
      // Esperando o bajando: lo cuenta el propio Mac en su siguiente evento, así
      // que aquí solo se suelta el botón.
      _ => ActualizacionEnElMac(vista),
    },
    _ => antes,
  };

  /// El sí no llegó a cumplirse.
  ///
  /// [confirmada] es que el Mac acusó recibo y luego se calló. Con la versión ya
  /// bajada eso es justo lo que pasa cuando se va a reiniciar antes de contestar, así
  /// que se lee como reinicio y no como fallo.
  static AvisoDelMac alFallar(
    AvisoDelMac antes, {
    String? codigo,
    bool confirmada = false,
  }) => switch (antes) {
    ActualizacionEnElMac(:final vista) when confirmada && vista.reiniciaYa =>
      ReiniciandoElMac(version: vista.version, desde: vista.actual),
    ActualizacionEnElMac(:final vista) => ActualizacionEnElMac(
      vista,
      problema: switch (codigo) {
        'noUpdate' => ProblemaAlActualizar.yaNoEsta,
        'updateChanged' => ProblemaAlActualizar.otraVersion,
        'cannotInstall' => ProblemaAlActualizar.noSePuede,
        _ => ProblemaAlActualizar.sinEnlace,
      },
    ),
    _ => antes,
  };

  /// Pasó el plazo de volver.
  static AvisoDelMac alPasarElPlazo(AvisoDelMac antes) => switch (antes) {
    ReiniciandoElMac(:final version, :final desde) => MacNoVolvio(
      version: version,
      desde: desde,
      porQue: PorQueNoVolvio.sinRespuesta,
    ),
    _ => antes,
  };

  /// «Volver a intentar» tras no volver: se le vuelve a esperar, con plazo nuevo.
  static AvisoDelMac alReintentar(AvisoDelMac antes) => switch (antes) {
    MacNoVolvio(
      :final version,
      :final desde,
      porQue: PorQueNoVolvio.sinRespuesta,
    ) =>
      ReiniciandoElMac(version: version, desde: desde),
    _ => antes,
  };
}
