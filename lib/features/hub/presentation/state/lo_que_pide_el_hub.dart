import 'package:flutter/foundation.dart';
import 'package:nexus/features/emulators/domain/entities/linea_de_registro.dart';
import 'package:nexus/features/hub/presentation/state/lo_que_ensena_el_hub.dart';

/// **Lo que se pulsa en el hub**, de vuelta a la app.
///
/// El motor del hub no hace nada por su cuenta: dice qué se pulsó y la app,
/// que es la que tiene el estado, lo hace. Es el mismo reparto que la
/// botonera de fuera, y por eso lo de la botonera viaja dentro tal cual
/// ([DeLaBotonera]): copiar aquí su lista de pedidos sería tener dos que
/// mantener de acuerdo.
@immutable
sealed class PedidoDelHub {
  const PedidoDelHub();

  Map<String, Object?> toMap();

  static PedidoDelHub? fromMap(Map<Object?, Object?> mapa) =>
      switch ((mapa['que'], mapa['id'])) {
        ('elegir', final String id) => ElegirDispositivo(id),
        ('arrancar', final String id) => ArrancarDispositivo(
          id,
          frio: mapa['frio'] == true,
        ),
        ('cerrar', final String id) => CerrarDispositivo(id),
        ('refrescar', _) => const RefrescarLaLista(),
        ('app', final String ruta) => ElegirApp(ruta),
        ('config', final String nombre) => ElegirConfig(nombre),
        ('correr', _) => const Correr(),
        ('duplicar', _) => const DuplicarConConsola(),
        ('quitarCopia', _) => const QuitarLaCopia(),
        ('traer', final String id) => TraerAlFrente(id),
        ('correrPrueba', final String ruta) => CorrerPrueba(
          ruta,
          delRepo: mapa['delRepo'] == true,
        ),
        ('pararPrueba', _) => const PararPrueba(),
        ('verPruebaEnVivo', _) => const VerPruebaEnVivo(),
        ('repetirPasada', final String carpeta) => RepetirPasada(carpeta),
        ('verPasada', final String carpeta) => VerPasada(carpeta),
        ('borrarPrueba', final String ruta) => BorrarPrueba(ruta),
        ('borrarPasada', final String carpeta) => BorrarPasada(carpeta),
        ('reintentarRepo', _) => const ReintentarElRepo(),
        ('prepararPublicacion', final String ruta) => PrepararPublicacion(ruta),
        ('publicar', final String ruta) => PublicarPrueba(
          ruta,
          mensaje: mapa['mensaje'] is String ? mapa['mensaje']! as String : '',
        ),
        ('cerrarPublicacion', _) => const CerrarPublicacion(),
        ('verPruebas', _) => VerPruebas(mapa['si'] == true),
        ('verSistema', _) => VerElSistema(mapa['si'] == true),
        ('nivelSistema', _) => switch (NivelDeRegistro.values
            .asNameMap()[mapa['nivel']]) {
          final nivel? => FiltrarElSistema(nivel),
          null => null,
        },
        ('buscarSistema', _) => BuscarEnElSistema(
          mapa['texto'] is String ? mapa['texto']! as String : '',
        ),
        ('verFuera', final String id) => switch (ComoVerFuera.values
            .asNameMap()[mapa['como']]) {
          final como? => VerFuera(id, como),
          null => null,
        },
        ('botonera', _) => switch (mapa['pedido']) {
          final Map<Object?, Object?> pedido => DeLaBotonera(pedido),
          _ => null,
        },
        _ => null,
      };
}

class ElegirDispositivo extends PedidoDelHub {
  const ElegirDispositivo(this.id);
  final String id;

  @override
  Map<String, Object?> toMap() => {'que': 'elegir', 'id': id};

  @override
  bool operator ==(Object other) =>
      other is ElegirDispositivo && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Arrancar un emulador o un simulador apagado. [frio] solo existe en Android:
/// es `--cold`, ver `ComandoDeEmuladores.argumentosDeLanzar`.
class ArrancarDispositivo extends PedidoDelHub {
  const ArrancarDispositivo(this.id, {this.frio = false});
  final String id;
  final bool frio;

  @override
  Map<String, Object?> toMap() => {'que': 'arrancar', 'id': id, 'frio': frio};

  @override
  bool operator ==(Object other) =>
      other is ArrancarDispositivo && other.id == id && other.frio == frio;

  @override
  int get hashCode => Object.hash(id, frio);
}

class CerrarDispositivo extends PedidoDelHub {
  const CerrarDispositivo(this.id);
  final String id;

  @override
  Map<String, Object?> toMap() => {'que': 'cerrar', 'id': id};

  @override
  bool operator ==(Object other) =>
      other is CerrarDispositivo && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class RefrescarLaLista extends PedidoDelHub {
  const RefrescarLaLista();

  @override
  Map<String, Object?> toMap() => {'que': 'refrescar'};

  @override
  bool operator ==(Object other) => other is RefrescarLaLista;

  @override
  int get hashCode => 0;
}

/// Lo que se pulsó en la botonera de la cabecera, tal cual: lo atiende
/// `atenderLaBotoneraProvider`, como cuando flota.
class DeLaBotonera extends PedidoDelHub {
  const DeLaBotonera(this.pedido);
  final Map<Object?, Object?> pedido;

  @override
  Map<String, Object?> toMap() => {'que': 'botonera', 'pedido': pedido};

  @override
  bool operator ==(Object other) =>
      other is DeLaBotonera && mapEquals(other.pedido, pedido);

  @override
  int get hashCode => Object.hashAll(pedido.entries.map((e) => e.key));
}

/// Elegir la app: [ruta] es la carpeta, que es lo que viaja en `id`.
class ElegirApp extends PedidoDelHub {
  const ElegirApp(this.ruta);
  final String ruta;

  @override
  Map<String, Object?> toMap() => {'que': 'app', 'id': ruta};

  @override
  bool operator ==(Object other) => other is ElegirApp && other.ruta == ruta;

  @override
  int get hashCode => ruta.hashCode;
}

class ElegirConfig extends PedidoDelHub {
  const ElegirConfig(this.nombre);
  final String nombre;

  @override
  Map<String, Object?> toMap() => {'que': 'config', 'id': nombre};

  @override
  bool operator ==(Object other) =>
      other is ElegirConfig && other.nombre == nombre;

  @override
  int get hashCode => nombre.hashCode;
}

/// ▶: correr la app elegida, con su configuración, en el dispositivo elegido
/// —arrancándolo antes si está apagado—.
class Correr extends PedidoDelHub {
  const Correr();

  @override
  Map<String, Object?> toMap() => {'que': 'correr'};

  @override
  bool operator ==(Object other) => other is Correr;

  @override
  int get hashCode => 1;
}

class DuplicarConConsola extends PedidoDelHub {
  const DuplicarConConsola();

  @override
  Map<String, Object?> toMap() => {'que': 'duplicar'};

  @override
  bool operator ==(Object other) => other is DuplicarConConsola;

  @override
  int get hashCode => 2;
}

class QuitarLaCopia extends PedidoDelHub {
  const QuitarLaCopia();

  @override
  Map<String, Object?> toMap() => {'que': 'quitarCopia'};

  @override
  bool operator ==(Object other) => other is QuitarLaCopia;

  @override
  int get hashCode => 3;
}

/// Traer al frente la ventana donde está su pantalla: Simulator, o la del
/// emulador cuando no deja verla dentro.
class TraerAlFrente extends PedidoDelHub {
  const TraerAlFrente(this.id);
  final String id;

  @override
  Map<String, Object?> toMap() => {'que': 'traer', 'id': id};

  @override
  bool operator ==(Object other) => other is TraerAlFrente && other.id == id;

  @override
  int get hashCode => Object.hash('traer', id);
}

/// Abrir su pantalla en otra ventana: scrcpy, Duplicado de iPhone, QuickTime.
class VerFuera extends PedidoDelHub {
  const VerFuera(this.id, this.como);
  final String id;
  final ComoVerFuera como;

  @override
  Map<String, Object?> toMap() => {
    'que': 'verFuera',
    'id': id,
    'como': como.name,
  };

  @override
  bool operator ==(Object other) =>
      other is VerFuera && other.id == id && other.como == como;

  @override
  int get hashCode => Object.hash(id, como);
}

/// Correr un flow en el dispositivo elegido: de `.maestro` de la app, o del
/// repositorio de pruebas ([delRepo]) con su cuenta.
class CorrerPrueba extends PedidoDelHub {
  const CorrerPrueba(this.ruta, {this.delRepo = false});
  final String ruta;
  final bool delRepo;

  @override
  Map<String, Object?> toMap() => {
    'que': 'correrPrueba',
    'id': ruta,
    'delRepo': delRepo,
  };

  @override
  bool operator ==(Object other) =>
      other is CorrerPrueba && other.ruta == ruta && other.delRepo == delRepo;

  @override
  int get hashCode => Object.hash(ruta, delRepo);
}

class PararPrueba extends PedidoDelHub {
  const PararPrueba();

  @override
  Map<String, Object?> toMap() => {'que': 'pararPrueba'};

  @override
  bool operator ==(Object other) => other is PararPrueba;

  @override
  int get hashCode => 11;
}

/// La ventana en vivo de la prueba que corre, como el «Ver» del panel.
class VerPruebaEnVivo extends PedidoDelHub {
  const VerPruebaEnVivo();

  @override
  Map<String, Object?> toMap() => {'que': 'verPruebaEnVivo'};

  @override
  bool operator ==(Object other) => other is VerPruebaEnVivo;

  @override
  int get hashCode => 12;
}

class RepetirPasada extends PedidoDelHub {
  const RepetirPasada(this.carpeta);
  final String carpeta;

  @override
  Map<String, Object?> toMap() => {'que': 'repetirPasada', 'id': carpeta};

  @override
  bool operator ==(Object other) =>
      other is RepetirPasada && other.carpeta == carpeta;

  @override
  int get hashCode => Object.hash('repetir', carpeta);
}

class VerPasada extends PedidoDelHub {
  const VerPasada(this.carpeta);
  final String carpeta;

  @override
  Map<String, Object?> toMap() => {'que': 'verPasada', 'id': carpeta};

  @override
  bool operator ==(Object other) =>
      other is VerPasada && other.carpeta == carpeta;

  @override
  int get hashCode => Object.hash('ver', carpeta);
}

// Lo que antes se hacía en el panel completo de pruebas, abierto en la
// ventana de Nexus (11 nov: «el panel de pruebas quedó en Nexus y no en la
// ventana de dispositivos»). Ahora se pide desde el hub y lo hace la app.

/// Borrar una prueba de la app. El hub pide confirmación antes: dos toques.
class BorrarPrueba extends PedidoDelHub {
  const BorrarPrueba(this.ruta);
  final String ruta;

  @override
  Map<String, Object?> toMap() => {'que': 'borrarPrueba', 'id': ruta};

  @override
  bool operator ==(Object other) => other is BorrarPrueba && other.ruta == ruta;

  @override
  int get hashCode => Object.hash('borrarPrueba', ruta);
}

/// Borrar una pasada del historial, con sus capturas. Dos toques también.
class BorrarPasada extends PedidoDelHub {
  const BorrarPasada(this.carpeta);
  final String carpeta;

  @override
  Map<String, Object?> toMap() => {'que': 'borrarPasada', 'id': carpeta};

  @override
  bool operator ==(Object other) =>
      other is BorrarPasada && other.carpeta == carpeta;

  @override
  int get hashCode => Object.hash('borrarPasada', carpeta);
}

/// Volver a sincronizar el repositorio de pruebas, cuando falló.
class ReintentarElRepo extends PedidoDelHub {
  const ReintentarElRepo();

  @override
  Map<String, Object?> toMap() => {'que': 'reintentarRepo'};

  @override
  bool operator ==(Object other) => other is ReintentarElRepo;

  @override
  int get hashCode => 14;
}

/// Abrir el diálogo de publicar una prueba: la app mira a dónde iría y si
/// reemplaza algo, y el hub lo enseña.
class PrepararPublicacion extends PedidoDelHub {
  const PrepararPublicacion(this.ruta);
  final String ruta;

  @override
  Map<String, Object?> toMap() => {'que': 'prepararPublicacion', 'id': ruta};

  @override
  bool operator ==(Object other) =>
      other is PrepararPublicacion && other.ruta == ruta;

  @override
  int get hashCode => Object.hash('prepararPublicacion', ruta);
}

/// Publicarla, con [mensaje] para el commit: rama y PR en el repo del equipo.
class PublicarPrueba extends PedidoDelHub {
  const PublicarPrueba(this.ruta, {required this.mensaje});
  final String ruta;
  final String mensaje;

  @override
  Map<String, Object?> toMap() => {
    'que': 'publicar',
    'id': ruta,
    'mensaje': mensaje,
  };

  @override
  bool operator ==(Object other) =>
      other is PublicarPrueba && other.ruta == ruta && other.mensaje == mensaje;

  @override
  int get hashCode => Object.hash('publicar', ruta, mensaje);
}

/// Cerrar el diálogo de publicar.
class CerrarPublicacion extends PedidoDelHub {
  const CerrarPublicacion();

  @override
  Map<String, Object?> toMap() => {'que': 'cerrarPublicacion'};

  @override
  bool operator ==(Object other) => other is CerrarPublicacion;

  @override
  int get hashCode => 15;
}

/// Desde qué nivel se enseña el registro del sistema: los cuatro de la
/// ventana del sistema —todo, desde avisos, solo errores, solo fatales—. El
/// filtro es uno solo, el de esa ventana: ver `FiltroDelRegistro`.
class FiltrarElSistema extends PedidoDelHub {
  const FiltrarElSistema(this.nivel);
  final NivelDeRegistro nivel;

  @override
  Map<String, Object?> toMap() => {'que': 'nivelSistema', 'nivel': nivel.name};

  @override
  bool operator ==(Object other) =>
      other is FiltrarElSistema && other.nivel == nivel;

  @override
  int get hashCode => Object.hash('nivelSistema', nivel);
}

/// Qué texto tiene que traer una línea del registro del sistema para verse.
/// Vacío, todas.
class BuscarEnElSistema extends PedidoDelHub {
  const BuscarEnElSistema(this.texto);
  final String texto;

  @override
  Map<String, Object?> toMap() => {'que': 'buscarSistema', 'texto': texto};

  @override
  bool operator ==(Object other) =>
      other is BuscarEnElSistema && other.texto == texto;

  @override
  int get hashCode => Object.hash('buscarSistema', texto);
}

/// En el panel de abajo, el registro del sistema del elegido ([si]) o el de
/// su corrida. Lo pide la pestaña (11 nov).
class VerElSistema extends PedidoDelHub {
  const VerElSistema(this.si);
  final bool si;

  @override
  Map<String, Object?> toMap() => {'que': 'verSistema', 'si': si};

  @override
  bool operator ==(Object other) => other is VerElSistema && other.si == si;

  @override
  int get hashCode => Object.hash('verSistema', si);
}

/// Pasar a la cara de pruebas ([si]) o volver a la pantalla.
class VerPruebas extends PedidoDelHub {
  const VerPruebas(this.si);
  final bool si;

  @override
  Map<String, Object?> toMap() => {'que': 'verPruebas', 'si': si};

  @override
  bool operator ==(Object other) => other is VerPruebas && other.si == si;

  @override
  int get hashCode => Object.hash('verPruebas', si);
}
