/// Qué clase de paso fue, sin el idioma.
///
/// La ventana de actividad del mockup pone **tres palabras por paso**: el
/// verbo en su columna —«Se ejecutó», «Lee», «Escribe»— y lo que se tocó en
/// mono al lado. La frase del paso llega entera («Leyendo lib/a.dart»), así
/// que el verbo iba pegado al objeto y en un idioma fijo: la ventana en inglés
/// decía «Leyendo».
enum VerboDelPaso {
  lee,
  escribe,
  edita,
  ejecuta,
  busca,
  delega,
  consulta,
  otro,
}

/// El verbo y el objeto de un paso, separados.
///
/// **Se lee de la frase y no de la herramienta** porque la frase es lo único
/// que se guarda con la conversación: un turno de ayer vuelve de disco con su
/// descripción y nada más. La frase la escribe `ToolActivityReader` con unos
/// prefijos fijos, así que separarla es exacto para todo lo que sale de ahí;
/// lo demás —la espera de la compactación, una herramienta nueva— cae en
/// [VerboDelPaso.otro] con la frase entera, que es lo que había.
abstract final class ElVerboDeUnPaso {
  static const _prefijos = [
    ('Leyendo ', VerboDelPaso.lee),
    ('Escribiendo ', VerboDelPaso.escribe),
    ('Editando ', VerboDelPaso.edita),
    ('Corriendo ', VerboDelPaso.ejecuta),
    ('Buscando en la web ', VerboDelPaso.busca),
    ('Buscando archivos ', VerboDelPaso.busca),
    ('Buscando ', VerboDelPaso.busca),
    ('Delegando: ', VerboDelPaso.delega),
    ('Consultando ', VerboDelPaso.consulta),
  ];

  static ({VerboDelPaso verbo, String objeto}) de(String frase) {
    for (final (prefijo, verbo) in _prefijos) {
      if (frase.startsWith(prefijo) && frase.length > prefijo.length) {
        return (verbo: verbo, objeto: frase.substring(prefijo.length).trim());
      }
    }
    return (verbo: VerboDelPaso.otro, objeto: frase);
  }
}
