import 'package:nexus/features/workspace/data/datasources/git_data_source.dart';

/// Una cosa que Nexus ve y cree que merece decirse.
class LoQueVeo {
  const LoQueVeo({required this.llave, required this.decir});

  /// Qué observación es. Sirve para no repetirla: «tienes tres commits sin
  /// subir» dicho cada vez que abres la carpeta deja de ser una observación y
  /// pasa a ser un ruido de fondo.
  final String llave;

  /// La frase, ya compuesta.
  final String decir;
}

/// **Tener opinión sobre tu trabajo, sin ponerse pesado.**
///
/// Es la tercera pata de lo que separa a alguien que contesta bien de alguien
/// que te acompaña: hasta aquí Nexus reaccionaba —contestaba lo que le pedías y
/// avisaba de lo que terminaba— y esto es lo primero que **mira por su cuenta**
/// y se pronuncia.
///
/// ## Lo que mira
///
/// Dos cosas locales —lo que no has commiteado y lo que no has subido— y dos
/// que hay que ir a preguntar: si el CI de tu rama está en rojo y si tienes un
/// PR parado. Las de fuera cuestan una llamada a `gh` cada una y por eso van
/// donde van: se miran al abrir una conversación, no cada dos minutos.
///
/// ## Las tres reglas que lo hacen soportable
///
/// 1. **Una sola cosa cada vez.** Hay tres observaciones posibles y se elige la
///    más urgente, no se sueltan las tres: una lista de reproches al abrir una
///    carpeta se aprende a ignorar el segundo día, y a partir de ahí da igual lo
///    que diga.
/// 2. **Solo lo que lleva tiempo parado.** Lo que acabas de hacer no se comenta
///    —tener cambios sin commitear mientras trabajas es lo normal, no un
///    descuido—. Se habla de lo que lleva [elPlazo] quieto, que es cuando deja
///    de ser trabajo en curso y empieza a ser un olvido.
/// 3. **No se recomienda nada.** Se cuenta lo que hay. «Llevas tres días con
///    cinco archivos sin commitear» es un hecho que tú sabes interpretar;
///    «deberías commitear» es un consejo que nadie pidió, y esa diferencia es
///    justo la que separa un asistente de una alarma.
abstract final class LoQueVeoDeTuTrabajo {
  /// Cuánto tiene que llevar algo parado para que valga la pena mencionarlo.
  ///
  /// Un día: por debajo de eso es la tarde de hoy, y de la tarde de hoy ya te
  /// acuerdas tú.
  static const elPlazo = Duration(days: 1);

  /// Lo que se diría de este repositorio, o `null` si no hay nada que decir.
  ///
  /// [comoSeDice] recibe los datos ya elegidos y devuelve la frase: el texto
  /// vive en el diccionario y esta decisión no tiene por qué saber de idiomas.
  /// Cuánto lleva un PR sin moverse para que se mencione.
  ///
  /// Tres días y no dos: uno abierto el viernes y mirado el lunes no está
  /// parado, está esperando a que vuelva la gente. Lo que se busca es el que
  /// se quedó atrás de verdad — en la máquina donde se midió esto había uno de
  /// veintiocho días.
  static const elPlazoDeUnPr = Duration(days: 3);

  static LoQueVeo? loQueDiria(
    ComoEstaElRepo estado, {
    required DateTime ahora,
    required String carpeta,
    required String Function(int cuantos, int dias) sinCommitear,
    required String Function(int cuantos, int dias) sinSubir,
    required String Function(int cuantos) sinBajar,

    /// El flujo que falló en tu rama, si falló alguno.
    String? ciRoto,
    required String Function(String flujo) elCiEstaRoto,

    /// El PR tuyo de esta carpeta que lleva más tiempo sin moverse.
    int? prParado,
    DateTime? prDesde,
    required String Function(int numero, int dias) elPrEstaParado,
  }) {
    // 🔴 **Lo primero, porque es lo único que ya está roto para los demás.** Lo
    // demás son cosas tuyas que puedes decidir cuándo atender; esto es trabajo
    // tuyo que ya salió de tu máquina y no funciona, y cuanto más tarde te
    // enteres, peor: encima de eso se construye.
    if (ciRoto != null) {
      return LoQueVeo(
        llave: '$carpeta·ci·$ciRoto',
        decir: elCiEstaRoto(ciRoto),
      );
    }

    final quieto = estado.ultimoCommit == null
        ? null
        : ahora.difference(estado.ultimoCommit!);
    final dias = (quieto?.inDays ?? 0);
    final parado = quieto != null && quieto >= elPlazo;

    // Lo primero, porque es lo único que se puede perder: lo que no está
    // commiteado no está en ninguna parte.
    if (estado.sinCommitear > 0 && parado) {
      return LoQueVeo(
        llave: '$carpeta·sin-commitear',
        decir: sinCommitear(estado.sinCommitear, dias),
      );
    }

    // Después lo que está a salvo pero no ha salido de tu máquina.
    if (estado.sinSubir > 0 && parado) {
      return LoQueVeo(
        llave: '$carpeta·sin-subir',
        decir: sinSubir(estado.sinSubir, dias),
      );
    }

    // El PR que se quedó atrás. Va detrás de lo tuyo sin subir porque eso solo
    // depende de ti, y esto depende también de quien tenga que revisarlo — pero
    // delante de lo que falta por bajar, porque un PR parado sí es trabajo que
    // ya hiciste y no está sirviendo de nada.
    if (prParado != null && prDesde != null) {
      final quieto = ahora.difference(prDesde);
      if (quieto >= elPlazoDeUnPr) {
        return LoQueVeo(
          llave: '$carpeta·pr·$prParado',
          decir: elPrEstaParado(prParado, quieto.inDays),
        );
      }
    }

    // Y por último lo que te falta por traer, que no es un olvido tuyo: es que
    // el mundo siguió. Por eso no lleva plazo — si hay diez commits nuevos,
    // saberlo **antes** de ponerte a trabajar es justamente el momento.
    if (estado.sinBajar > 0) {
      return LoQueVeo(
        llave: '$carpeta·sin-bajar·${estado.sinBajar}',
        decir: sinBajar(estado.sinBajar),
      );
    }

    return null;
  }
}
