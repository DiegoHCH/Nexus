import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/features/assistant/domain/usecases/a_donde_va_lo_que_se_escribe.dart';
import 'package:nexus/features/assistant/domain/usecases/los_comandos_de_la_casa.dart';
import 'package:nexus/core/i18n/nexus_strings.dart';

/// **`/programadas`: verlas, apagarlas y borrarlas.**
///
/// Pedido con nombre y apellido: «cuando ya no necesite esa tarea, poder
/// borrarla o cancelarla… o desactivarla».
///
/// En el chat y no en Ajustes por lo mismo que el listado de MCP: apagar algo
/// que está a punto de correr no puede costar cruzar la pantalla.
void main() {
  group('el comando', () {
    test('se reconoce, y también por su otra forma', () {
      for (final forma in ['/programadas', '/tareas']) {
        expect(
          ADondeVaLoQueSeEscribe.de(
            forma,
            esElParte: false,
            hayAdjuntos: false,
          ),
          isA<ALasProgramadas>(),
          reason: forma,
        );
      }
    });

    // 🔴 **La ayuda sale del catálogo, no de un texto a mano.** Y tiene dos
    // sitios: el enum y el orden de [enLaAyuda]. Añadir el comando y olvidar el
    // orden lo deja existiendo y sin poder descubrirse, que es como no
    // existir — pasó al escribir esto, y lo cazó la prueba de la ayuda.
    test('sale en la lista de la ayuda', () {
      expect(
        ElComandoDeLaCasa.enLaAyuda,
        contains(ElComandoDeLaCasa.programadas),
      );

      const textos = NexusStringsEs();
      final lista = ElComandoDeLaCasa.laLista(
        textos.ayudaTitulo,
        (comando) => comando == ElComandoDeLaCasa.programadas
            ? textos.ayudaProgramadas
            : 'lo que sea',
      );

      expect(lista, contains('/programadas'));
      expect(
        lista,
        contains('/tareas'),
        reason: 'la otra forma, entre paréntesis',
      );
    });

    // No lleva nada escrito detrás: `/programadas` a secas o nada.
    test('no admite texto detrás', () {
      expect(ElComandoDeLaCasa.programadas.conTexto, isFalse);
    });
  });

  group('los textos, en los dos idiomas', () {
    // 🔴 La app tiene que servir en español e inglés, y una cadena que falta no
    // rompe: deja un hueco o enseña el otro idioma en mitad de la frase.
    test('están todos y no se quedan en blanco', () {
      for (final textos in <NexusStrings>[
        const NexusStringsEs(),
        const NexusStringsEn(),
      ]) {
        for (final texto in [
          textos.laListaDeProgramadas,
          textos.ningunaProgramada,
          textos.ayudaProgramadas,
          textos.apagarla,
          textos.encenderla,
          textos.borrarla,
          textos.estaApagada,
          textos.propuestaDeProgramar,
          textos.programarlo,
          textos.soloEstaVez,
          textos.yaProgramada,
          textos.seHizoSoloEstaVez,
          textos.sinCarpetaParaProgramar,
          textos.todosLosDiasDicho,
          textos.laProximaCita('mar 17:00'),
        ]) {
          expect(texto.trim(), isNotEmpty);
        }
        expect(
          textos.diasCortos,
          hasLength(7),
          reason: 'los siete días, o `ComoSeLeeLaCita` pinta interrogantes',
        );
      }
    });

    // Apagar y borrar no son lo mismo, y el botón tiene que decirlo: uno deja
    // la tarea escrita para volver a encenderla y el otro la quita.
    test('apagar y borrar no se llaman igual', () {
      for (final textos in <NexusStrings>[
        const NexusStringsEs(),
        const NexusStringsEn(),
      ]) {
        expect(textos.apagarla, isNot(textos.borrarla));
        expect(textos.encenderla, isNot(textos.apagarla));
      }
    });
  });
}
