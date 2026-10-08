#!/usr/bin/env bash
# Mata los `flutter_tester` de **este** proyecto que se quedaron huérfanos.
#
# 🔴 `flutter test` deja a veces uno vivo al terminar: padre `launchd`, dormido
# sobre un socket muerto, para siempre. Medido el 8 oct 2026 con
# `test/el_turno_que_se_corta_test.dart`: 1 de cada 4 corridas, aun con todas
# las pruebas en verde. No sale del código de Nexus —el log de `flutter test -v`
# registra un solo proceso de pruebas, que termina bien— y se acumulaban: se
# encontraron doce de varios días.
#
# Solo los de este proyecto (su `package_config.json` va en los argumentos) y
# solo los huérfanos: uno con padre vivo es de una corrida en marcha.
#
# Uso: `scripts/limpiar_testers.sh` — dice cuántos mató.
set -uo pipefail
cd "$(dirname "$0")/.."

paquetes="$(pwd)/.dart_tool/package_config.json"
muertos=0
while read -r pid ppid; do
  [ "$ppid" = 1 ] || continue
  if ps -ww -o command= -p "$pid" | grep -qF -- "--packages=$paquetes"; then
    kill "$pid" 2>/dev/null && muertos=$((muertos + 1))
  fi
done < <(ps -axo pid=,ppid=,comm= | awk '$3 ~ /flutter_tester$/ {print $1, $2}')

echo "flutter_tester huérfanos de este proyecto: $muertos"
