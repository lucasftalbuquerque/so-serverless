#!/usr/bin/env bash
# Passo 5: chamada com demorar=true (a função dorme 5 s).
# Com a API local no ar (sam local start-api), rode com o Timeout atual do template:
#   ./scripts/passo5-timeout.sh timeout-3s
# Depois troque Timeout: 3 por Timeout: 10 em template.yaml, rode sam build,
# reinicie o start-api e repita:
#   ./scripts/passo5-timeout.sh timeout-10s
set -uo pipefail
cd "$(dirname "$0")/.."
source scripts/_comum.sh
mkdir -p evidencias
rotulo="${1:?informe o rótulo: timeout-3s ou timeout-10s}"
saida="evidencias/05-$rotulo.txt"
URL="${SAM_API_URL:-http://127.0.0.1:3000}/guias"
command -v curl >/dev/null || { echo "ERRO: curl não encontrado." >&2; exit 1; }
checar_api "$URL"

{
  echo "== demorar=true ($rotulo) - $(date '+%Y-%m-%d %H:%M:%S') =="
  grep -n "Timeout" template.yaml
} | tee "$saida"
curl -s -X POST "$URL" -H "Content-Type: application/json" \
     -d '{"requisicaoId":"R-003","demorar":true}' \
     -w '\nHTTP %{http_code} em %{time_total} s\n' | tee -a "$saida"
