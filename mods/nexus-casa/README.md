# nexus-casa

Un mod opcional del catálogo de Nexus. Nadie lo tiene sin instalarlo: se pone
en toda la cuenta de Claude o solo en las carpetas que quieras.

## Instalarlo

Desde Nexus: **Ajustes › Superpoderes › Plugins**, añade el *Catálogo de Nexus*
e instala `nexus-casa` en toda la cuenta o solo en la carpeta activa.

Desde la terminal:

```sh
claude plugin marketplace add DiegoHCH/Nexus --sparse .claude-plugin mods
claude plugin install nexus-casa@nexus            # toda la cuenta
claude plugin install nexus-casa@nexus -s local   # solo esta carpeta
```

## Qué hace

- **Recorta las salidas ruidosas que salieron bien**: pruebas, compilaciones,
  instalaciones y logs de CI de más de 150 líneas y 6.000 caracteres. Deja el
  principio, el final y las líneas que hablan de errores, con un aviso delante
  que dice dónde está la salida completa. Medido con una sesión real: 801 líneas
  de Gradle (22.000 caracteres) llegaron como 93 (3.200).
- **Pregunta antes de lo que no tiene vuelta atrás**: `rm -rf` fuera de la
  carpeta del encargo, push forzado, push directo a `develop`, `master` o
  `main`, borrar una rama remota, `reset --hard`, `clean -f`, descartar los
  cambios de toda la carpeta, `branch -D` y `stash clear`. Con alguien delante,
  la pregunta llega por el canal de permisos; sin nadie, el comando no corre y
  Claude lee por qué.

## Qué no hace, a propósito

- **No toca la salida de un comando que falló.** Le llega ya cortada por Claude
  Code —el final no llega—, y recortarla más solo quitaría. Ver el comentario
  del hook en `hooks/register.js`.

## Probarlo

Con Claude Code 2.1.287 o posterior; probado con la 2.1.296:

```sh
claude plugin validate mods/nexus-casa
(cd mods/nexus-casa && claude plugin test)
```
