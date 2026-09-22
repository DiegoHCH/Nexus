#!/usr/bin/env bash
# ¿Esta rama cambia **solo** el número de versión?
#
# 🔴 El CI corría dos veces el mismo código: entero en el PR de la
# funcionalidad, y entero otra vez en el PR de release, que sobre lo ya probado
# añade una línea del `pubspec`. Seis minutos y medio para verificar que
# `1.19.5+64` pasó a ser `1.19.6+65`.
#
# Se mira el **contenido y no el nombre de la rama**: una rama llamada
# `release/…` que traiga código de verdad tiene que probarse como cualquier
# otra, y una que solo suba el número no necesita probarse aunque se llame de
# otro modo. Lo que autoriza a saltarse la suite no es cómo se llama, es que el
# árbol sea el mismo que ya pasó.
#
# Devuelve 0 si solo sube la versión, 1 si cambia algo más. Se corre igual en
# local: `scripts/solo_sube_la_version.sh origin/develop`.
set -euo pipefail

base="${1:-origin/develop}"

# Dos puntos y no tres: compara los dos árboles directamente, sin necesitar el
# ancestro común. En un `checkout` superficial —el del CI— no hay ancestro que
# encontrar, y con tres puntos esto no se podría calcular allí.
cambiados="$(git diff --name-only "$base" HEAD)"

if [ "$cambiados" != "pubspec.yaml" ]; then
  echo "no: cambia más que el número de versión"
  printf '%s\n' "$cambiados" | sed 's/^/  · /'
  exit 1
fi

# Y dentro del pubspec, que no venga nada más de paseo.
otras="$(git diff -U0 "$base" HEAD -- pubspec.yaml \
  | grep -E '^[+-]' \
  | grep -vE '^(\+\+\+|---)' \
  | grep -vE '^[+-]version:' || true)"

if [ -n "$otras" ]; then
  echo "no: el pubspec cambia algo más que la versión"
  printf '%s\n' "$otras" | sed 's/^/  · /'
  exit 1
fi

echo "sí: solo sube la versión, y esto ya se probó en $base"
