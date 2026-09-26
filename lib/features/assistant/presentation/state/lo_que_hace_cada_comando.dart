import 'package:nexus/core/i18n/nexus_strings.dart';
import 'package:nexus/features/assistant/domain/usecases/los_comandos_de_la_casa.dart';

/// Lo que hace cada comando, en cinco palabras y en el idioma elegido.
///
/// En un solo sitio porque lo leen dos: el texto de `/ayuda` que se guarda con
/// la conversación y la tabla que se pinta en ella. Con el `switch` repetido,
/// un comando nuevo acabaría explicado en uno y mudo en el otro — y el `switch`
/// exhaustivo es lo que obliga a explicarlo al añadirlo.
String loQueHaceElComando(NexusStrings s, ElComandoDeLaCasa comando) =>
    switch (comando) {
      ElComandoDeLaCasa.aparte => s.ayudaAparte,
      ElComandoDeLaCasa.imagen => s.ayudaImagen,
      ElComandoDeLaCasa.edita => s.ayudaEdita,
      ElComandoDeLaCasa.git => s.ayudaGit,
      ElComandoDeLaCasa.parte => s.ayudaParte,
      ElComandoDeLaCasa.agenda => s.ayudaAgenda,
      ElComandoDeLaCasa.mcp => s.ayudaMcp,
      ElComandoDeLaCasa.programadas => s.ayudaProgramadas,
      ElComandoDeLaCasa.recuerda => s.ayudaRecuerda,
      ElComandoDeLaCasa.olvida => s.ayudaOlvida,
      ElComandoDeLaCasa.ayuda => s.ayudaAyuda,
    };
