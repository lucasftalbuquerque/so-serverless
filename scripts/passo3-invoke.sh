#!/usr/bin/env bash
# Passo 3: build + duas invocações com o evento gerado, medindo o tempo de cada uma.
# Uso (na raiz do repositório, Git Bash/WSL/Linux/macOS):  ./scripts/passo3-invoke.sh
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p evidencias

{
  echo "== Ambiente ($(date '+%Y-%m-%d %H:%M:%S')) =="
  sam --version
  docker --version
  python --version 2>/dev/null || python3 --version
} 2>&1 | tee evidencias/01-ambiente.txt

sam build 2>&1 | tee evidencias/02-sam-build.txt

for i in 1 2; do
  echo "== Invocação $i ==" | tee "evidencias/03-invoke-$i.txt"
  inicio=$(date +%s%N)
  sam local invoke -e events/pedido.json 2>&1 | tee -a "evidencias/03-invoke-$i.txt"
  fim=$(date +%s%N)
  echo "Tempo total (relógio): $(( (fim - inicio) / 1000000 )) ms" | tee -a "evidencias/03-invoke-$i.txt"
done
