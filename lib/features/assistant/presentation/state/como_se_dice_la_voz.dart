import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/assistant/domain/entities/el_acento.dart';
import 'package:nexus/features/assistant/domain/entities/nexus_voice.dart';

/// Cómo se dicen en pantalla las voces y los acentos, **en el idioma de la
/// app**.
///
/// 🔴 **Estaban solo en español.** Las voces eran cadenas —«informativa»,
/// «firme»— con un comentario que decía «se traduce», y los acentos se pintaban
/// con la frase que se le dice al modelo —«de Colombia»— con mayúscula. Con la
/// app en inglés, Ajustes › Voz seguía en español. Salió al escribir la guía de
/// configuración de la voz (30 sep).
///
/// El `switch` es exhaustivo a propósito: una cualidad nueva en [ComoSuena] no
/// compila hasta que alguien le ponga su texto en los dos idiomas.
abstract final class ComoSeDiceLaVoz {
  static String comoSuena(ComoSuena como, NexusStrings strings) =>
      switch (como) {
        ComoSuena.brillante => strings.vozBrillante,
        ComoSuena.animada => strings.vozAnimada,
        ComoSuena.informativa => strings.vozInformativa,
        ComoSuena.firme => strings.vozFirme,
        ComoSuena.excitable => strings.vozExcitable,
        ComoSuena.juvenil => strings.vozJuvenil,
        ComoSuena.ligera => strings.vozLigera,
        ComoSuena.tranquila => strings.vozTranquila,
        ComoSuena.susurrada => strings.vozSusurrada,
        ComoSuena.clara => strings.vozClara,
        ComoSuena.suave => strings.vozSuave,
        ComoSuena.aspera => strings.vozAspera,
        ComoSuena.delicada => strings.vozDelicada,
        ComoSuena.templada => strings.vozTemplada,
        ComoSuena.madura => strings.vozMadura,
        ComoSuena.directa => strings.vozDirecta,
        ComoSuena.cercana => strings.vozCercana,
        ComoSuena.informal => strings.vozInformal,
        ComoSuena.amable => strings.vozAmable,
        ComoSuena.viva => strings.vozViva,
        ComoSuena.docta => strings.vozDocta,
        ComoSuena.calida => strings.vozCalida,
      };

  /// «Kore · firme», o «Kore · firm».
  static String laVoz(NexusVoice voz, NexusStrings strings) =>
      '${voz.name} · ${comoSuena(voz.character, strings)}';

  /// El botón de un acento. Lo que se guarda y se le dice al modelo sigue
  /// siendo [ElAcento.variante]: esto es solo cómo se lee.
  ///
  /// Una variante guardada que ya no está en la lista se respeta —ver
  /// [ElAcento.porNombre]— y se enseña tal cual, con mayúscula: es lo único que
  /// se sabe de ella.
  static String elAcento(ElAcento acento, NexusStrings strings) =>
      switch (acento.variante) {
        null => strings.elAcentoAutomatico,
        'latinoamericano' => strings.acentoLatinoamericano,
        'de Colombia' => strings.acentoDeColombia,
        'de México' => strings.acentoDeMexico,
        'de Argentina' => strings.acentoDeArgentina,
        'de Chile' => strings.acentoDeChile,
        'de España' => strings.acentoDeEspana,
        final otra => '${otra[0].toUpperCase()}${otra.substring(1)}',
      };
}
