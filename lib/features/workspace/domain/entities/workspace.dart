import 'package:flutter/foundation.dart';
import 'package:nexus/features/workspace/domain/entities/config_del_repo.dart';
import 'package:nexus/features/workspace/domain/entities/paired_folder.dart';

/// Qué puede **hacer** Nexus con tus archivos. Es el interruptor que el diseño
/// pone siempre visible en la barra superior, y va a nivel de app, no de
/// carpeta: es la pregunta «¿hoy estás dejando que toque cosas?».
///
/// Cómo se traduce a la herramienta concreta es asunto de la capa de datos:
/// aquí solo existe la pregunta «¿puede escribir?».
enum FilePermission {
  readOnly,
  canEdit;

  bool get canWrite => this == FilePermission.canEdit;
}

/// El estado completo de los permisos: qué carpetas hay emparejadas, en cuál
/// se está trabajando, y qué puede hacer Nexus con los archivos.
@immutable
class Workspace {
  const Workspace({
    this.folders = const [],
    this.activePath,
    this.permission = FilePermission.readOnly,
    this.delRepo = const {},
    this.leeTodoElMac = false,
  });

  final List<PairedFolder> folders;

  /// La carpeta sobre la que trabaja Claude ahora mismo. `null` mientras no
  /// haya ninguna emparejada, y entonces **no hay dónde trabajar**: sin esto,
  /// `claude -p` heredaba el directorio de la app, que para un bundle lanzado
  /// por launchd es `/`, y cualquier encargo respondía sobre la raíz del disco.
  final String? activePath;

  final FilePermission permission;

  /// Si Claude puede **leer** cualquier archivo de tu carpeta personal sin
  /// preguntar, esté en la carpeta que esté la conversación.
  ///
  /// Apagado de fábrica: quien llega a Nexus encuentra la promesa del README
  /// —cada conversación ve solo su carpeta— tal cual. Encenderlo es una
  /// decisión tuya, y **solo abre la lectura**: escribir fuera de la carpeta
  /// sigue dependiendo de su permiso, como siempre. Ver [lecturasPara].
  ///
  /// Lo pidió quien usa Nexus a diario y lo repitió alguien de fuera: «ando
  /// acostumbrado a que Claude entre a donde le dé la gana». Tener que
  /// emparejar cada carpeta antes de que pueda echarle un vistazo era la
  /// diferencia con la terminal que más se notaba.
  final bool leeTodoElMac;

  /// Lo que declara cada repositorio sobre sí mismo, por la ruta de la carpeta
  /// emparejada a la que pertenece.
  ///
  /// Va aquí y no dentro de [PairedFolder] porque no es configuración tuya: la
  /// carpeta guardada tiene que poder ir al disco tal cual, y esto no se guarda
  /// nunca — se relee del repositorio, que es de donde manda.
  final Map<String, ConfigDelRepo> delRepo;

  /// Lo que declara el repositorio sobre el que se trabaja ahora.
  ConfigDelRepo? get configActiva =>
      activePath == null ? null : delRepo[activePath];

  PairedFolder? get active {
    if (activePath == null) return null;
    for (final folder in folders) {
      if (folder.path == activePath) return folder;
    }
    return null;
  }

  bool get isEmpty => folders.isEmpty;

  /// Si se puede abrir una sesión de voz ahora mismo. Sin carpeta activa no se
  /// abre: hablarle a Nexus sin sitio donde trabajar solo produce respuestas
  /// sobre la nada.
  bool get allowsVoice => active?.modality.allowsVoice ?? false;

  /// La carpeta de **solo texto** que contiene [path], si alguna.
  ///
  /// Existe por el único hueco que le quedaba a i5. La carpeta de artefactos —el
  /// cajón de salida— es la única excepción a «ninguna otra carpeta»: viaja como
  /// `--add-dir` en **todos** los encargos. Si cae dentro de una carpeta
  /// emparejada en solo texto, una conversación con voz podría leer de ahí y
  /// Gemini narrarlo, que es exactamente lo que ese modo viene a impedir.
  ///
  /// Se mira por prefijo y no por igualdad porque `--add-dir` da acceso a **todo
  /// el subárbol**: el cajón puesto en una subcarpeta abre la misma puerta que
  /// puesto en la raíz.
  /// Las reglas de lectura que lleva un encargo hecho desde [carpeta]: lo que
  /// puede leer sin preguntar y lo que no puede leer nunca.
  ///
  /// Vacías con [leeTodoElMac] apagado, que es lo de siempre.
  ///
  /// 🔴 **Las carpetas de solo texto se niegan desde una conversación con voz.**
  /// Es la promesa de ese modo: nada de esa carpeta viaja a Gemini. Abrir la
  /// lectura de todo el home la rompería por la puerta de al lado —una
  /// conversación con voz lee la carpeta de solo texto y Gemini lo narra—, que
  /// es el mismo hueco que [textOnlyOwnerOf] tapa para la carpeta de
  /// artefactos. Medido contra el CLI: la negación gana al permiso, y frena
  /// tanto `Read` como un `cat` por Bash.
  ///
  /// Desde una conversación de solo texto no se niega nada: ahí no hay voz a la
  /// que se le pueda escapar.
  ///
  /// [cerradas] son las rutas de lo negado, para poder decírselo a Claude.
  ({List<String> permitir, List<String> negar, List<String> cerradas})
  lecturasPara(String? carpeta, {required String home}) {
    if (!leeTodoElMac || home.isEmpty) {
      return (permitir: [], negar: [], cerradas: []);
    }
    final propia = folders.where((f) => f.path == carpeta).firstOrNull;
    final conVoz = propia?.modality.allowsVoice ?? false;
    final cerradas = [
      if (conVoz)
        for (final f in folders)
          if (!f.modality.allowsVoice) f.path,
    ];
    return (
      // La doble barra es como el CLI escribe una ruta absoluta en una regla:
      // con una sola, la tomaría como relativa a la carpeta de trabajo.
      permitir: ['Read(/$home/**)'],
      negar: [for (final ruta in cerradas) 'Read(/$ruta/**)'],
      cerradas: cerradas,
    );
  }

  PairedFolder? textOnlyOwnerOf(String? path) {
    if (path == null || path.isEmpty) return null;
    final limpio = path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;

    for (final folder in folders) {
      if (folder.modality.allowsVoice) continue;
      if (limpio == folder.path || limpio.startsWith('${folder.path}/')) {
        return folder;
      }
    }
    return null;
  }

  Workspace copyWith({
    List<PairedFolder>? folders,
    String? activePath,
    bool clearActive = false,
    FilePermission? permission,
    Map<String, ConfigDelRepo>? delRepo,
    bool? leeTodoElMac,
  }) {
    return Workspace(
      folders: folders ?? this.folders,
      activePath: clearActive ? null : (activePath ?? this.activePath),
      permission: permission ?? this.permission,
      delRepo: delRepo ?? this.delRepo,
      leeTodoElMac: leeTodoElMac ?? this.leeTodoElMac,
    );
  }
}
