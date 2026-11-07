#!/usr/bin/env bash
# Passo 3: build + duas invocações com o evento gerado, medindo o tempo de cada uma.
# Uso (na raiz do repositório, no Git Bash/WSL):  ./scripts/passo3-invoke.sh
set -uo pipefail
cd "$(dirname "$0")/.."
source scripts/_comum.sh
exigir_sam
checar_docker
mkdir -p evidencias

{
  echo "== Ambiente ($(date '+%Y-%m-%d %H:%M:%S')) =="
  sam --version
  docker --version
  python --version 2>/dev/null || python3 --version
} 2>&1 | tee evidencias/01-ambiente.txt

if ! sam build 2>&1 | tee evidencias/02-sam-build.txt; then
  echo "ERRO: sam build falhou (veja evidencias/02-sam-build.txt)." >&2
  exit 1
fi

for i in 1 2; do
  saida="evidencias/03-invoke-$i.txt"
  echo "== Invocação $i ($(date '+%Y-%m-%d %H:%M:%S')) ==" | tee "$saida"
  inicio=$(date +%s%N)
  sam local invoke -e events/pedido.json 2>&1 | tee -a "$saida"
  status=${PIPESTATUS[0]}
  fim=$(date +%s%N)
  if [ "$status" -ne 0 ]; then
    echo "ERRO: sam local invoke falhou (código $status). Veja $saida." >&2
    exit 1
  fi
  echo "Tempo total (relógio): $(( (fim - inicio) / 1000000 )) ms" | tee -a "$saida"
done
