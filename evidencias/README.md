# Evidências

Os scripts em `scripts/` salvam aqui as saídas em texto. Os prints de tela vão
junto, com os nomes abaixo (PNG ou JPG).

| Arquivo | Passo | O que mostra |
|---|---|---|
| `01-ambiente.txt` / `01-ambiente.png` | 1 | `sam --version`, `docker --version`, `python --version` |
| `02-sam-build.txt` / `02-sam-build.png` | 2 | `sam build` concluído |
| `03-invoke-1.txt` / `03-invoke-1.png` | 3 | 1ª invocação com `events/pedido.json` (com `Init Duration`) |
| `03-invoke-2.txt` / `03-invoke-2.png` | 3 | 2ª invocação e tempo |
| `04-curl-sem-warm.txt` / `04-curl-sem-warm.png` | 4 | 3 chamadas com `sam local start-api` |
| `04-curl-lazy.txt` / `04-curl-lazy.png` | 4 | 3 chamadas com `--warm-containers LAZY` |
| `05-timeout-3s.txt` / `05-timeout-3s.png` | 5 | Erro de tempo limite com `Timeout: 3` (terminal do start-api + curl) |
| `05-timeout-10s.txt` / `05-timeout-10s.png` | 5 | Mesma chamada com `Timeout: 10` |
