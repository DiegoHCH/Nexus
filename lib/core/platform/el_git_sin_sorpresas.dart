/// Lo que un repo **no puede** hacer ejecutar con su `.git/config`.
///
/// 🔴 Un `git diff` o un `git status` se leen como lecturas, y lo son… hasta
/// que el `.git/config` del repo dice `diff.external = programa`,
/// `core.fsmonitor = programa` o `core.pager = programa`: entonces «mirar» es
/// ejecutar lo que el repo quiera. Nexus y Claude corren git sobre repos que
/// no escribieron ellos.
///
/// Se fija en el **entorno** con `GIT_CONFIG_COUNT`, que manda sobre toda la
/// configuración de archivos —la del repo incluida— sin tocar los comandos:
/// así vale también para los que escribe Claude.
///
/// 🔴 **`diff.external` no se puede apagar así**, y se probó: fijarlo vacío
/// hace que git intente ejecutar un programa sin nombre y muera —«cannot run
/// : No such file or directory»—, y no hay forma de *borrar* una clave desde el
/// entorno, solo de darle otro valor. Así que los `git diff` de Nexus llevan
/// `--no-ext-diff`, y los que escribe Claude quedan sin cubrir. El riesgo es
/// bajo: el `.git/config` no viaja al clonar, así que alguien tendría que
/// haberlo escrito antes en esta máquina. Tampoco se apagan los `textconv` de
/// un driver de `.gitattributes`, por lo mismo.
abstract final class ElGitSinSorpresas {
  static const claves = {'core.fsmonitor': 'false', 'core.pager': 'cat'};

  /// [entorno] con las claves puestas, **detrás** de las que ya trajera.
  static Map<String, String> en(Map<String, String> entorno) {
    final env = Map<String, String>.from(entorno);
    var n = int.tryParse(env['GIT_CONFIG_COUNT'] ?? '') ?? 0;
    for (final MapEntry(:key, :value) in claves.entries) {
      env['GIT_CONFIG_KEY_$n'] = key;
      env['GIT_CONFIG_VALUE_$n'] = value;
      n++;
    }
    env['GIT_CONFIG_COUNT'] = '$n';
    return env;
  }
}
