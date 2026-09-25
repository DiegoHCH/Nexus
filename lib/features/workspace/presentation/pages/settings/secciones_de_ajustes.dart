import 'package:flutter/widgets.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';

/// Las cinco preguntas con que se agrupan las secciones de Ajustes.
///
/// Dieciocho enlaces en fila obligaban a leerlos todos para encontrar uno. Se
/// agrupan por lo que la persona viene a preguntar —cómo es ella, qué puede
/// hacer, qué te cuenta, tus aparatos, cómo va— y cada sección enseña su
/// pregunta encima del título. Ver `nexus-orbe-plasma.html`, `#ajustes`.
enum PreguntaDeAjustes {
  comoEsElla,
  quePuedeHacer,
  queTeCuenta,
  tusAparatos,
  comoVa;

  String title(NexusStrings strings) => switch (this) {
    PreguntaDeAjustes.comoEsElla => strings.preguntaComoEsElla,
    PreguntaDeAjustes.quePuedeHacer => strings.preguntaQuePuedeHacer,
    PreguntaDeAjustes.queTeCuenta => strings.preguntaQueTeCuenta,
    PreguntaDeAjustes.tusAparatos => strings.preguntaTusAparatos,
    PreguntaDeAjustes.comoVa => strings.preguntaComoVa,
  };
}

/// Las secciones de Ajustes, como claves, cada una con su pregunta.
///
/// El menú sale de `values` y **no de una lista escrita a mano**: esa lista ya
/// se olvidó dos veces —el Historial primero y los Superpoderes después—, y el
/// resultado es siempre el mismo, una sección que existe y no tiene forma de
/// abrirse. La pregunta va en la propia sección por lo mismo: una sección nueva
/// no puede entrar sin decir a qué grupo pertenece, porque no compila.
///
/// Dentro de cada pregunta, el orden de declaración es el del menú.
enum SeccionDeAjustes {
  voice(PreguntaDeAjustes.comoEsElla),

  /// Con sección propia y siempre visible: vivía dentro de «Por dónde suena»,
  /// que solo aparece con dos altavoces, y con uno no había forma de
  /// encenderlo.
  oido(PreguntaDeAjustes.comoEsElla),
  nombres(PreguntaDeAjustes.comoEsElla),
  memoria(PreguntaDeAjustes.comoEsElla),
  appearance(PreguntaDeAjustes.comoEsElla),
  language(PreguntaDeAjustes.comoEsElla),
  permissions(PreguntaDeAjustes.quePuedeHacer),

  /// «Qué sale» sube a «Qué puede hacer»: es la sección de la confianza, y
  /// antes iba al final, entre lo que se lee.
  salidas(PreguntaDeAjustes.quePuedeHacer),
  llaves(PreguntaDeAjustes.quePuedeHacer),
  imagenes(PreguntaDeAjustes.quePuedeHacer),
  superpowers(PreguntaDeAjustes.quePuedeHacer),
  avisos(PreguntaDeAjustes.queTeCuenta),
  history(PreguntaDeAjustes.queTeCuenta),
  mobile(PreguntaDeAjustes.tusAparatos),
  emulators(PreguntaDeAjustes.tusAparatos),
  pruebas(PreguntaDeAjustes.tusAparatos),
  cuentas(PreguntaDeAjustes.tusAparatos),
  stats(PreguntaDeAjustes.comoVa),
  help(PreguntaDeAjustes.comoVa);

  const SeccionDeAjustes(this.pregunta);

  final PreguntaDeAjustes pregunta;

  /// Las de una pregunta, en el orden en que se leen.
  static List<SeccionDeAjustes> de(PreguntaDeAjustes pregunta) => [
    for (final seccion in values)
      if (seccion.pregunta == pregunta) seccion,
  ];

  String title(NexusStrings strings) => switch (this) {
    SeccionDeAjustes.voice => strings.sectionVoice,
    SeccionDeAjustes.oido => strings.sectionOido,
    SeccionDeAjustes.llaves => strings.sectionKeys,
    SeccionDeAjustes.imagenes => strings.sectionImages,
    SeccionDeAjustes.avisos => strings.sectionAvisos,
    SeccionDeAjustes.nombres => strings.sectionNombres,
    SeccionDeAjustes.memoria => strings.sectionMemoria,
    SeccionDeAjustes.permissions => strings.sectionPermissions,
    SeccionDeAjustes.mobile => strings.sectionMobile,
    SeccionDeAjustes.history => strings.sectionHistory,
    SeccionDeAjustes.pruebas => strings.sectionPruebas,
    SeccionDeAjustes.cuentas => strings.sectionCuentas,
    SeccionDeAjustes.stats => strings.sectionStats,
    SeccionDeAjustes.superpowers => strings.sectionSuperpowers,
    SeccionDeAjustes.emulators => strings.sectionEmulators,
    SeccionDeAjustes.appearance => strings.sectionAppearance,
    SeccionDeAjustes.language => strings.sectionLanguage,
    SeccionDeAjustes.salidas => strings.sectionExits,
    SeccionDeAjustes.help => strings.sectionHelp,
  };
}

/// Cómo una sección lleva a otra sin salir de la hoja.
///
/// Existe por las llaves: viven todas en «Llaves», y la voz y las imágenes,
/// que las usan, enlazan allí. Un `InheritedWidget` y no un parámetro porque
/// las secciones se construyen con `const` y no deberían saber quién las pinta:
/// montadas sueltas —en una prueba— el enlace simplemente no aparece.
class IrASeccionDeAjustes extends InheritedWidget {
  const IrASeccionDeAjustes({
    super.key,
    required this.ir,
    required super.child,
  });

  final ValueChanged<SeccionDeAjustes> ir;

  static ValueChanged<SeccionDeAjustes>? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<IrASeccionDeAjustes>()?.ir;

  @override
  bool updateShouldNotify(IrASeccionDeAjustes oldWidget) => ir != oldWidget.ir;
}
