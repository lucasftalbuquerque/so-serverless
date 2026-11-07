#!/usr/bin/env bash
# Passo 4: três chamadas HTTP para a API local.
# Antes, em OUTRO terminal:  sam local start-api                       (rótulo: sem-warm)
#                       ou:  sam local start-api --warm-containers LAZY (rótulo: lazy)
# Uso: ./scripts/passo4-curl.sh sem-warm   |   ./scripts/passo4-curl.sh lazy
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p evidencias
rotulo="${1:?informe o rótulo: sem-warm ou lazy}"
saida="evidencias/04-curl-$rotulo.txt"
URL="${SAM_API_URL:-http://127.0.0.1:3000}/guias"

echo "== start-api ($rotulo) - $(date '+%Y-%m-%d %H:%M:%S') ==" | tee "$saida"
for i in 1 2 3; do
  echo "-- chamada $i" | tee -a "$saida"
  curl -s -X POST "$URL" -H "Content-Type: application/json" \
       -d '{"requisicaoId":"R-002","hospital":"H-Caruaru"}' \
       -w '\nHTTP %{http_code} em %{time_total} s\n' | tee -a "$saida"
done
