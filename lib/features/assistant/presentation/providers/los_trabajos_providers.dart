import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus/features/assistant/data/datasources/los_trabajos_aparte.dart';
import 'package:nexus/features/assistant/domain/usecases/el_trabajo_aparte.dart';

/// Un trabajo largo, con lo que hace falta para enseñarlo y para cerrarlo.
@immutable
class UnTrabajo {
  const UnTrabajo({
    required this.comando,
    required this.carpeta,
    this.lineas = const [],
    this.codigo,
    this.enMarcha,
  });

  final String comando;
  final String carpeta;

  /// Las últimas líneas que dijo. Ver [ElTrabajoAparte.tope].
  final List<String> lineas;

  /// Con qué código salió, o `null` mientras corre.
  final int? codigo;

  /// Lo que permite pararlo. Fuera del estado que se pinta no cabría: es lo
  /// único que no es un dato.
  final UnTrabajoEnMarcha? enMarcha;

  bool get corriendo => codigo == null;

  UnTrabajo conLinea(String linea) => UnTrabajo(
    comando: comando,
    carpeta: carpeta,
    lineas: [
      ...lineas.length >= ElTrabajoAparte.tope
          ? lineas.sublist(lineas.length - ElTrabajoAparte.tope + 1)
          : lineas,
      linea,
    ],
    codigo: codigo,
    enMarcha: enMarcha,
  );

  UnTrabajo terminado(int codigo) => UnTrabajo(
    comando: comando,
    carpeta: carpeta,
    lineas: lineas,
    codigo: codigo,
  );
}

/// Los trabajos largos que corren **con Nexus de padre**, por conversación.
///
/// 🔴 Ver [ElTrabajoAparte]: lo que se lanza en segundo plano dentro de un
/// encargo se muere con el turno, porque es hijo del `claude -p` que Nexus
/// cierra al terminar. Esto vive aquí, en la app, así que sobrevive al turno, a
/// que la conversación se cierre y a que Claude se vaya.
///
/// **Uno por conversación**: dos gates a la vez sobre el mismo repositorio se
/// pisan el directorio de build, que es la misma razón por la que no se dejan
/// dos corridas de la misma plataforma.
class LosTrabajos extends Notifier<Map<String, UnTrabajo>> {
  @override
  Map<String, UnTrabajo> build() => const {};

  /// Arranca uno. `false` si ya había otro corriendo en esa conversación o si
  /// no se pudo ni lanzar.
  Future<bool> arrancar({
    required String conversacion,
    required String comando,
    required String carpeta,
  }) async {
    if (state[conversacion]?.corriendo ?? false) return false;

    state = {
      ...state,
      conversacion: UnTrabajo(comando: comando, carpeta: carpeta),
    };

    final enMarcha = await ref
        .read(losTrabajosAparteProvider)
        .arrancar(
          comando: comando,
          carpeta: carpeta,
          alDecir: (linea) => _anota(conversacion, linea),
          alTerminar: (codigo) => _acabo(conversacion, codigo),
        );
    if (enMarcha == null) {
      state = {...state}..remove(conversacion);
      return false;
    }
    final actual = state[conversacion];
    if (actual == null) return true;
    state = {
      ...state,
      conversacion: UnTrabajo(
        comando: actual.comando,
        carpeta: actual.carpeta,
        lineas: actual.lineas,
        enMarcha: enMarcha,
      ),
    };
    return true;
  }

  /// Lo para. Lo que se pierde es el resto de la salida, no lo dicho.
  Future<void> parar(String conversacion) async {
    final trabajo = state[conversacion];
    if (trabajo == null || !trabajo.corriendo) return;
    await trabajo.enMarcha?.parar();
  }

  /// Se lo lleva de la lista, ya contado. Lo llama quien lo cuenta.
  void recoger(String conversacion) => state = {...state}..remove(conversacion);

  void _anota(String conversacion, String linea) {
    final trabajo = state[conversacion];
    if (trabajo == null) return;
    state = {...state, conversacion: trabajo.conLinea(linea)};
  }

  void _acabo(String conversacion, int codigo) {
    final trabajo = state[conversacion];
    if (trabajo == null) return;
    state = {...state, conversacion: trabajo.terminado(codigo)};
  }
}

final losTrabajosAparteProvider = Provider<LosTrabajosAparte>(
  (ref) => const LosTrabajosAparte(),
);

final losTrabajosProvider =
    NotifierProvider<LosTrabajos, Map<String, UnTrabajo>>(LosTrabajos.new);
