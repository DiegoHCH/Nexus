/// Un modelo que el menú ofrece arriba, por el nombre con que se pide.
typedef ModeloDelCatalogo = ({
  /// Lo que se escribe en el perfil, igual que `/model` o `--model`: un alias
  /// —`opus`— o un nombre entero.
  String valor,

  /// A qué apunta hoy, con su nombre entero —`claude-opus-5-5`—, para poder
  /// rotularlo con su versión antes de usarlo. `null` si no se sabe.
  String? modelo,
});

/// Los modelos que ofrece el menú, **sin que haga falta sacar una versión de
/// Nexus cada vez que sale uno**.
///
/// 🔴 **Pedido así:** «salió el nuevo modelo Sonnet 5.5 pero no lo veo… no
/// quiero que cada vez que salga un modelo nuevo tenga que sacar una versión
/// nueva». La lista vivía en el código: cuatro alias y las versiones anteriores
/// escritas a mano, y al salir Sonnet 5.5 nadie movió Sonnet 5 a las
/// anteriores, así que el alias se rotulaba «Sonnet 5» y Sonnet 5 no se podía
/// elegir.
///
/// El CLI no publica su lista —`claude --help` no tiene cómo pedirla, y lo que
/// guarda en disco es un trozo interno—, así que la lista sale de `modelos.json`
/// en la raíz del repositorio de Nexus: cambiarla es un commit a `master`, y la
/// ven todas las instalaciones al abrir. Si no se puede leer, vale [deFabrica].
///
/// **Cómo se añade un modelo:** un PR contra `master` que solo toque
/// `modelos.json` —y su vuelta a `develop`, como siempre—. El workflow de
/// Release no publica nada si la versión del `pubspec` ya existe, así que eso no
/// saca versión. Y [deFabrica] se pone al día en la siguiente release, cuando
/// toque: hasta entonces solo importa a una instalación sin red ni copia.
class ElCatalogoDeModelos {
  const ElCatalogoDeModelos({required this.alias, required this.anteriores});

  /// Arriba del menú, el último de cada familia.
  final List<ModeloDelCatalogo> alias;

  /// Debajo, las versiones anteriores por su nombre entero.
  final List<String> anteriores;

  /// Lo que trae Nexus dentro, por si no hay red ni copia guardada.
  ///
  /// `modelos.json` puede ir **por delante** —un modelo que salió después de
  /// esta versión— pero no quitarle familias: lo comprueba una prueba.
  static const deFabrica = ElCatalogoDeModelos(
    alias: [
      (valor: 'opus', modelo: 'claude-opus-5-5'),
      (valor: 'fable', modelo: 'claude-fable-5-1'),
      (valor: 'sonnet', modelo: 'claude-sonnet-5-5'),
      (valor: 'haiku', modelo: 'claude-haiku-4-5'),
    ],
    anteriores: [
      'claude-opus-5',
      'claude-fable-5',
      'claude-sonnet-5',
      'claude-opus-4-8',
      'claude-opus-4-7',
      'claude-opus-4-6',
      'claude-sonnet-4-6',
    ],
  );

  /// Cuántos se aceptan de cada lista. Un archivo con cientos no es un
  /// catálogo, es un error —o alguien probando—, y el menú no cabría.
  static const maximoDeAlias = 12;
  static const maximoDeAnteriores = 40;

  /// Lo que se puede escribir como modelo: lo mismo que acepta `--model`, sin
  /// espacios ni nada que no sea de un nombre. Vale también para lo que se
  /// escribe a mano en «Otro modelo…».
  static final nombreValido = RegExp(r'^[a-z0-9][a-z0-9._\-]{0,79}(\[1m\])?$');

  static final _nombreEntero = RegExp(r'^claude-[a-z0-9._\-]{1,70}$');

  /// El catálogo que dice [json], o `null` si no es uno.
  ///
  /// **Entero o nada**: un archivo a medias —un alias sin valor, una versión con
  /// un espacio— no se arregla a trozos, se descarta y vale lo que había. Lo que
  /// se escribe en el perfil sale de aquí, así que no entra nada que no sea un
  /// nombre de modelo.
  static ElCatalogoDeModelos? deJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final alias = json['alias'];
    final anteriores = json['anteriores'];
    if (alias is! List || anteriores is! List) return null;
    if (alias.isEmpty || alias.length > maximoDeAlias) return null;
    if (anteriores.length > maximoDeAnteriores) return null;

    final arriba = <ModeloDelCatalogo>[];
    for (final uno in alias) {
      if (uno is! Map<String, dynamic>) return null;
      final valor = uno['valor'];
      final modelo = uno['modelo'];
      if (valor is! String || !nombreValido.hasMatch(valor)) return null;
      if (modelo != null &&
          (modelo is! String || !_nombreEntero.hasMatch(modelo))) {
        return null;
      }
      arriba.add((valor: valor, modelo: modelo as String?));
    }

    final abajo = <String>[];
    for (final una in anteriores) {
      if (una is! String || !_nombreEntero.hasMatch(una)) return null;
      abajo.add(una);
    }
    return ElCatalogoDeModelos(alias: arriba, anteriores: abajo);
  }

  Map<String, dynamic> toJson() => {
    'alias': [
      for (final (:valor, :modelo) in alias)
        {'valor': valor, 'modelo': ?modelo},
    ],
    'anteriores': anteriores,
  };

  /// Si [valor] ya sale en el menú, arriba o abajo.
  bool loTiene(String valor) =>
      alias.any((a) => a.valor == valor) || anteriores.contains(valor);
}
