# commits-personales

Un mod opcional del catálogo de Nexus con unas reglas de commits concretas:

- el mensaje va **en inglés** y su primera línea sigue **Conventional Commits**
  (`<tipo>[(scope)]: descripción`);
- **sin `Co-Authored-By`** ni ninguna firma de la herramienta;
- lo que se publica en GitHub —PRs, issues, comentarios, releases— **sin el pie
  «Generated with Claude Code»**.

No son reglas universales: hay equipos que exigen el `Co-Authored-By` en cada
commit. Por eso se instala **solo en las carpetas donde valen**.

## Instalarlo

Desde Nexus: **Ajustes › Superpoderes › Plugins**, añade el *Catálogo de Nexus*
e instala `commits-personales` **solo en la carpeta activa**.

Desde la terminal, dentro de la carpeta:

```sh
claude plugin marketplace add DiegoHCH/Nexus --sparse .claude-plugin mods
claude plugin install commits-personales@nexus -s local
```

`-s local` lo apunta en el `.claude/settings.local.json` de esa carpeta, que git
no sigue: tus reglas no viajan al repo.

## Cómo lo hace

- **Para que Claude no lo intente**: la firma le llega en un recordatorio que
  Claude Code le adjunta («End git commit messages with: Co-Authored-By…»), y el
  mod lo cambia por estas reglas. `attribution.text`, el evento pensado para
  esto, no se dispara en `claude -p`; el adjunto sí.
- **Por si lo intenta igual**: rechaza el commit o la publicación antes de que
  corra, con el porqué y todas las reglas juntas, y Claude lo rehace bien.

Medido con sesiones reales: sin el cambio del recordatorio, un commit costaba
tres intentos rechazados; con él, sale bien a la primera.

## Probarlo

```sh
claude plugin validate mods/commits-personales
(cd mods/commits-personales && claude plugin test)
```
