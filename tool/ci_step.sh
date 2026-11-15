#!/usr/bin/env bash
# Uso: bash tool/ci_step.sh "<titolo>" <comando...>
# Se il comando fallisce, stampa le righe utili come annotazione leggibile via API.
title="$1"; shift
set -o pipefail
if ! "$@" 2>&1 | tee step.log; then
  grep -n -i -E 'error|what went wrong|failed|exception|Expected|Actual|Which|\.dart[: ][0-9]+' step.log | tail -40 \
    | sed 's/%/%25/g' | awk 'BEGIN{ORS="%0A"} {print}' > err.txt
  echo "::error title=${title}::$(cat err.txt)"
  exit 1
fi
