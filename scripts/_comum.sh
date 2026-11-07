# Funções compartilhadas pelos scripts dos passos (carregado com "source").

# No Windows o SAM CLI é instalado como sam.cmd, que o Git Bash nem sempre
# encontra pelo nome "sam". Procura nas opções conhecidas.
achar_sam() {
  local c
  for c in sam sam.cmd sam.exe \
           "/c/Program Files/Amazon/AWSSAMCLI/bin/sam.cmd" \
           "/c/Program Files (x86)/Amazon/AWSSAMCLI/bin/sam.cmd" \
           "/mnt/c/Program Files/Amazon/AWSSAMCLI/bin/sam.cmd"; do
    if command -v "$c" >/dev/null 2>&1 || [ -f "$c" ]; then
      SAM="$c"; return 0
    fi
  done
  echo "ERRO: SAM CLI não encontrado." >&2
  echo "  - Confira no PowerShell: sam --version" >&2
  echo "  - Se funcionar lá, rode no Git Bash: export SAM=\"\$(cygpath -u \"\$(where.exe sam.cmd | head -1 | tr -d '\\r')\")\"" >&2
  echo "  - Se não funcionar, instale: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html" >&2
  echo "  - Depois feche e abra o Git Bash de novo." >&2
  exit 1
}

# Garante que "sam" funcione. Permite forçar o caminho com: export SAM=/caminho/sam.cmd
exigir_sam() {
  if [ -n "${SAM:-}" ]; then
    command -v "$SAM" >/dev/null 2>&1 || [ -f "$SAM" ] || { echo "ERRO: SAM=$SAM não existe." >&2; exit 1; }
  else
    achar_sam
  fi
  sam() { "$SAM" "$@"; }
}

checar_docker() {
  if ! docker info >/dev/null 2>&1; then
    echo "ERRO: Docker não está rodando. Abra o Docker Desktop e espere ficar 'running'." >&2
    exit 1
  fi
}

checar_api() {
  # curl só falha (código != 0) se não conseguir conectar; qualquer resposta HTTP serve.
  if ! curl -s -o /dev/null --max-time 5 "$1"; then
    echo "ERRO: a API local não respondeu em $1." >&2
    echo "  Suba antes, em OUTRO terminal: sam local start-api" >&2
    exit 1
  fi
}
