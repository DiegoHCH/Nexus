import 'package:flutter/foundation.dart';

/// Una conversación viva: una carpeta y el hilo que se lleva con ella.
///
/// Puede haber varias a la vez —hasta [Conversations.max]— y **trabajan en
/// paralelo**: cada una lanza sus propios procesos de Claude. Lo que no se
/// multiplica es la voz: hay una boca y dos oídos, así que el micrófono sirve
/// a la que tenga el foco y las demás avanzan de fondo.
@immutable
class Conversation {
  const Conversation({
    required this.id,
    required this.folderPath,
    this.name,
    this.recordId,
    this.memoriaPropia = false,
  });

  final String id;
  final String folderPath;

  /// Esta conversación dejó de compartir la sesión de la carpeta.
  ///
  /// Lo pone «empezar de cero». Vive en la ficha y no solo en el estado de su
  /// pantalla porque **lo pregunta otra conversación**: el chip de memoria
  /// compartida cuenta con quién se comparte, y para eso hay que poder mirar a
  /// las demás sin construirles el controlador — que es caro y fue el origen de
  /// una fuga ya medida.
  ///
  /// 🔴 **Y se guarda.** Empezó sin guardarse, y eso dejaba a quien lo usaba
  /// atrapado: reiniciar la app devolvía la conversación al hilo de la carpeta,
  /// y el botón de empezar de cero solo aparece dentro del aviso de «continué
  /// donde quedé» — que ya no sale, porque la sesión se había olvidado. Sin
  /// sesión que olvidar no había forma de volver a separarse. Reportado tal
  /// cual: «di empezar de cero, abro otra y me aparece el chip en las dos».
  ///
  /// Guardarlo cambia también el otro lado: al cargar, la conversación marcada
  /// le dice a su `AskClaude` que siga sola, así que la decisión sobrevive al
  /// reinicio como cualquier otra que se toma una vez.
  final bool memoriaPropia;

  /// El nombre que le puso el usuario, si le puso uno.
  ///
  /// **Nulo es lo normal**, y entonces el nombre se deriva —el primer encargo, o la
  /// cola de la carpeta—. Guardar un nombre derivado como si fuera elegido haría
  /// imposible distinguir «no lo has llamado de ninguna forma» de «lo llamaste así»,
  /// y con eso el título dejaría de seguir a la conversación cuando cambia el primer
  /// encargo al retomarla.
  final String? name;

  /// Con qué identidad se guarda, si adoptó una del archivo.
  ///
  /// Al retomar una del historial, la pestaña **adopta el id de ese registro** para
  /// seguir escribiendo en él en vez de crear otro. Ese dato vivía solo en memoria, así
  /// que al reabrir la app la recuperación buscaba un registro con el id de la
  /// conversación —que no existe— y la pestaña volvía **vacía** con sus turnos intactos
  /// en disco.
  final String? recordId;

  Conversation conNombre(String? nuevo) => Conversation(
    id: id,
    folderPath: folderPath,
    name: nuevo,
    recordId: recordId,
  );

  Conversation conRegistro(String? adoptado) => Conversation(
    id: id,
    folderPath: folderPath,
    name: name,
    recordId: adoptado,
  );

  Conversation conMemoriaPropia() => Conversation(
    id: id,
    folderPath: folderPath,
    name: name,
    recordId: recordId,
    memoriaPropia: true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'folderPath': folderPath,
    if (name != null) 'name': name,
    if (recordId != null) 'recordId': recordId,
    if (memoriaPropia) 'memoriaPropia': true,
  };

  static Conversation? fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final folderPath = json['folderPath'] as String?;
    if (id == null || id.isEmpty || folderPath == null || folderPath.isEmpty) {
      return null;
    }
    return Conversation(
      id: id,
      folderPath: folderPath,
      name: json['name'] as String?,
      recordId: json['recordId'] as String?,
      memoriaPropia: json['memoriaPropia'] == true,
    );
  }
}

/// Las conversaciones abiertas y cuál tiene el foco.
@immutable
class Conversations {
  const Conversations({
    this.items = const [],
    this.focusedId,
    this.cargado = false,
  });

  /// El tope no es técnico, es de atención. Estuvo en tres con ese argumento, y el
  /// uso lo corrigió: seis caben porque **no se siguen todas a la vez** — se dejan
  /// corriendo y se vuelve a ellas, que es justo para lo que sirve tener varias.
  ///
  /// Seis y no siete por la rejilla: se apilan en columnas de [porColumna], así que un
  /// número que no sea múltiplo deja una columna coja.
  static const max = 6;

  /// Cuántas fichas caben en una columna del muelle antes de empezar otra al lado.
  ///
  /// Tres es lo que cabe sin que la columna llegue al orbe grande, que es el centro de
  /// la pantalla y no se tapa.
  static const porColumna = 3;

  final List<Conversation> items;
  final String? focusedId;

  /// Si ya se leyó del disco lo que había abierto.
  ///
  /// **Vacío y «todavía no sé» no son lo mismo**, y confundirlos es lo que hacía que la
  /// app enseñara la pantalla de primera vez justo después de arrancar: la lista nace
  /// vacía y el disco se lee después, así que durante esa ventana parecía que no había
  /// ninguna conversación. Quien tocaba el orbe ahí se llevaba una conversación nueva
  /// en vez de la que tenía abierta.
  final bool cargado;

  /// La misma lista, ya marcada como leída del disco.
  Conversations copyCargado() =>
      Conversations(items: items, focusedId: focusedId, cargado: true);

  bool get isEmpty => items.isEmpty;
  bool get isFull => items.length >= max;

  Conversation? get focused {
    for (final item in items) {
      if (item.id == focusedId) return item;
    }
    return items.isEmpty ? null : items.first;
  }

  /// Una carpeta, una conversación. Dos hilos sobre el mismo repo compartirían
  /// la sesión de Claude y acabarían pisándose el contexto.
  bool hasFolder(String path) => items.any((item) => item.folderPath == path);

  Conversation? byId(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  Conversations copyWith({List<Conversation>? items, String? focusedId}) =>
      Conversations(
        items: items ?? this.items,
        focusedId: focusedId ?? this.focusedId,
      );
}
