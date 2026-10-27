# nexus-publicar

Publica en claude.ai, como artifact, el documento que Nexus le deja preparado.
**No es un mod del catálogo**: no se instala. Nexus lo lleva dentro de la app y
lo carga él mismo con `--plugin-dir` en una sesión que lanza oculta, solo para
publicar.

## Por qué existe

Nexus habla con Claude por `claude -p`, y ahí la herramienta `Artifact` no
existe: la documentación la deja apagada en headless y en el Agent SDK, sin
forma de encenderla, y un mod que la llame desde `-p` recibe «no tool named
Artifact». En una sesión **interactiva** sí está. Así que Nexus lanza una dentro
de una pseudoterminal (`script`), sin servidores MCP, y este mod llama a
`Artifact` directamente al arrancar, sin pasar por el modelo: ni un turno, ni un
token. Medido: 9 s una publicación nueva, 5 s una actualización.

## Cómo habla con Nexus

En la carpeta donde corre la sesión, Nexus deja:

- `pagina.html`, la copia del documento (la herramienta solo publica lo que está
  bajo esa carpeta), y
- `pedido.json`: `{ "archivo", "titulo", "url"? }`.

El mod publica —encima de `url` si viene, leyéndolo antes, como exige la
herramienta— y deja `respuesta.json`: `{ "ok": true, "url", "nuevo" }` o
`{ "ok": false, "error" }`. Nexus la recoge y para la sesión.

Una página grande (cientos de KB) no viene en la lectura: la herramienta la
guarda en un archivo y no deja publicar encima hasta que la sesión lee **cada
línea** de esa copia. El mod la lee con `Read`, por tramos, antes de publicar.
Medido con una de 313 KB: 9 s la actualización.

**Sin `pedido.json`, o en una sesión que no es interactiva, no hace nada**:
cargado por error en otra parte, no publica nada de nadie.

## Probarlo

```sh
claude plugin test mods/nexus-publicar
```
