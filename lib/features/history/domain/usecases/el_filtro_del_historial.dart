import 'package:flutter/foundation.dart';
import 'package:nexus/features/history/domain/entities/conversation_summary.dart';

/// Una carpeta por la que se puede filtrar el historial, con cuántas
/// conversaciones tiene.
///
/// Se identifica por la **ruta** y se enseña por el **nombre**: dos proyectos
/// pueden llamarse igual en sitios distintos, y filtrar por el nombre los
/// mezclaría.
@immutable
class UnaCarpetaDelHistorial {
  const UnaCarpetaDelHistorial({
    required this.carpeta,
    required this.nombre,
    required this.cuantas,
  });

  final String carpeta;
  final String nombre;
  final int cuantas;
}

/// Una cuenta por la que se puede filtrar, con cuántas conversaciones tiene.
///
/// [cuenta] vacía es la cuenta de siempre: las conversaciones sin perfil, que
/// son las de antes de que hubiera perfiles o las de un Mac con una sola.
@immutable
class UnaCuentaDelHistorial {
  const UnaCuentaDelHistorial({required this.cuenta, required this.cuantas});

  final String cuenta;
  final int cuantas;
}

/// Buscar y filtrar el historial.
///
/// 🔴 **Antes no había ni lo uno ni lo otro**: con decenas de conversaciones por
/// semana, retomar «la de las pantallas de CRED-310» era bajar por la lista
/// hasta encontrarla. Y las cuentas iban en pestañas que partían la lista en
/// dos, así que buscar en las dos a la vez no se podía.
///
/// Todo aquí es puro —recibe fichas, devuelve fichas— para que la regla de qué
/// coincide se pruebe sin montar la pantalla, y para que la pantalla no tenga
/// ninguna decisión dentro.
abstract final class ElFiltroDelHistorial {
  /// Las fichas que pasan la búsqueda y los dos filtros, en el orden en que
  /// llegan.
  ///
  /// [carpeta] es la ruta, o `null` para todas. [cuenta] es el nombre del
  /// perfil —vacío para la de siempre— o `null` para todas.
  static List<ConversationSummary> filtra(
    List<ConversationSummary> fichas, {
    String busqueda = '',
    String? carpeta,
    String? cuenta,
  }) {
    final palabras = _palabras(busqueda);
    return [
      for (final ficha in fichas)
        if ((carpeta == null || ficha.folderPath == carpeta) &&
            (cuenta == null || cuentaDe(ficha) == cuenta) &&
            _coincide(ficha, palabras))
          ficha,
    ];
  }

  /// Si la ficha contiene **todas** las palabras de [busqueda], en cualquier
  /// orden y en cualquiera de sus textos.
  ///
  /// Todas y no alguna: quien escribe dos palabras está acotando, y con «alguna»
  /// cada palabra de más ensancharía la lista en vez de estrecharla.
  static bool coincide(ConversationSummary ficha, String busqueda) =>
      _coincide(ficha, _palabras(busqueda));

  static bool _coincide(ConversationSummary ficha, List<String> palabras) {
    if (palabras.isEmpty) return true;
    // Dónde se busca: lo que se ve en la fila —título, proyecto, cuenta— y lo
    // que se dijo dentro. El proyecto entra porque el mensaje de «nada» invita
    // a buscar por él, y la cuenta porque se escribe igual que se lee.
    final texto = pliega(
      [
        ficha.title,
        ficha.projectName,
        ficha.profileName ?? '',
        ficha.loUltimoQuePediste ?? '',
        ficha.loUltimoQueDijo ?? '',
      ].join(' '),
    );
    return palabras.every(texto.contains);
  }

  static List<String> _palabras(String busqueda) => pliega(
    busqueda,
  ).split(RegExp(r'\s+')).where((palabra) => palabra.isNotEmpty).toList();

  /// El texto en minúsculas y **sin tildes**.
  ///
  /// Sin tildes porque se busca como se teclea, y con prisa «cancion» es
  /// «canción». La `ñ` se queda: «ano» y «año» no son la misma palabra.
  static String pliega(String texto) {
    const conTilde = 'áàäâãéèëêíìïîóòöôõúùüû';
    const sinTilde = 'aaaaaeeeeiiiiooooouuuu';
    final minusculas = texto.toLowerCase();
    final salida = StringBuffer();
    for (final letra in minusculas.split('')) {
      final donde = conTilde.indexOf(letra);
      salida.write(donde == -1 ? letra : sinTilde[donde]);
    }
    return salida.toString();
  }

  /// La cuenta de una ficha tal como la usan los filtros: el perfil, o vacío
  /// para la de siempre.
  static String cuentaDe(ConversationSummary ficha) =>
      ficha.profileName?.trim() ?? '';

  /// Las carpetas que hay, de la **usada más recientemente** a la más vieja.
  ///
  /// Por uso y no por nombre: el filtro que se busca es el del proyecto en el
  /// que se está trabajando estos días, y ese es el que se usó hace un rato.
  static List<UnaCarpetaDelHistorial> lasCarpetas(
    List<ConversationSummary> fichas,
  ) {
    final ordenadas = [...fichas]
      ..sort((a, b) => b.usadaEn.compareTo(a.usadaEn));
    final cuantas = <String, int>{};
    final nombres = <String, String>{};
    for (final ficha in ordenadas) {
      cuantas.update(ficha.folderPath, (n) => n + 1, ifAbsent: () => 1);
      nombres.putIfAbsent(ficha.folderPath, () => ficha.projectName);
    }
    return [
      for (final carpeta in cuantas.keys)
        UnaCarpetaDelHistorial(
          carpeta: carpeta,
          nombre: nombres[carpeta]!,
          cuantas: cuantas[carpeta]!,
        ),
    ];
  }

  /// Las cuentas que hay, por orden alfabético y con la de siempre al final.
  ///
  /// Alfabético porque son pocas y fijas —`private`, `work`—: que cambiaran de
  /// sitio según cuál se usó la última haría que se pulsara la de al lado.
  static List<UnaCuentaDelHistorial> lasCuentas(
    List<ConversationSummary> fichas,
  ) {
    final cuantas = <String, int>{};
    for (final ficha in fichas) {
      cuantas.update(cuentaDe(ficha), (n) => n + 1, ifAbsent: () => 1);
    }
    final nombres = cuantas.keys.toList()
      ..sort((a, b) {
        if (a.isEmpty != b.isEmpty) return a.isEmpty ? 1 : -1;
        return a.compareTo(b);
      });
    return [
      for (final cuenta in nombres)
        UnaCuentaDelHistorial(cuenta: cuenta, cuantas: cuantas[cuenta]!),
    ];
  }
}
