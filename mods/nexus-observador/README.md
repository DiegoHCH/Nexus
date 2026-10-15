# nexus-observador

Un mod del catálogo de Nexus que le cuenta a Nexus qué hacen tus sesiones de
`claude` en la terminal, y te deja contestar sus permisos desde Nexus sin
volver a la terminal.

## Instalarlo

En toda la cuenta, para que entre en todas tus sesiones:

- Desde Nexus: **Ajustes › Superpoderes › Plugins**, añade el *Catálogo de
  Nexus* e instala `nexus-observador` **en toda la cuenta**.
- Desde la terminal:

  ```sh
  claude plugin marketplace add DiegoHCH/Nexus --sparse .claude-plugin mods
  claude plugin install nexus-observador@nexus
  ```

## Qué hace

- **Cuenta** a Nexus cuándo empieza y acaba cada turno, qué herramienta usa y
  sobre qué, y cuánto contexto lleva. Nexus lo enseña en la barra de arriba
  («2 EN LA TERMINAL · 1 PIDE PERMISO») y en su hoja.
- **Pasa los permisos** que la terminal iba a preguntar: los contestas en Nexus
  —Permitir, Denegar o «Que pregunte la terminal»— y te avisa con una
  notificación y, si la voz está libre, dicho. Lo que ya permiten o deniegan tus
  reglas no pasa por Nexus.
- **Medio minuto**: mientras Nexus retiene un permiso, la terminal no enseña su
  pregunta. Pasado ese rato sin respuesta, pregunta la terminal como siempre.

## Cómo habla con Nexus

Por un canal local: solo `127.0.0.1`, con un token. Nexus lo anuncia en
`~/Library/Application Support/com.katanalabs.nexus/observador.json` con
permisos `600`, y lo borra al cerrarse. Si Nexus no está abierto, el mod no hace
nada y la sesión sigue como sin él.

**En los encargos del propio Nexus se aparta**: Nexus los marca con
`NEXUS_ENCARGO`, ya los ve y sus permisos ya los pregunta él.

## Probarlo

```sh
claude plugin validate mods/nexus-observador
(cd mods/nexus-observador && claude plugin test)
```
