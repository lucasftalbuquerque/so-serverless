# so-serverless · Guia de transporte do Rota Vital

Atividade individual 1 (Serverless) · Infraestrutura de Software · ADS · CESAR School · 2026.2

Uma função serverless que gera a **guia de transporte** de uma requisição do Rota Vital.
Ela é acionada de dois jeitos: por **evento** (`sam local invoke`) e por **HTTP**
(`POST /guias` via `sam local start-api`). Com ela observei o cold start, o
reaproveitamento do ambiente, a falta de estado garantido entre chamadas e o limite
de tempo de execução.

## Caminho escolhido

**Caminho A: AWS SAM CLI local**, com Docker e Python 3.12. Tudo roda no computador,
sem conta na AWS. O Caminho B (Lambda na nuvem) é opcional e não foi feito.

## Estrutura

```
.
├── template.yaml          # Função + evento Api (POST /guias) e Timeout em Globals
├── samconfig.toml         # Config do SAM (sem warm containers por padrão)
├── hello_world/app.py     # Handler (lambda_handler)
├── events/
│   ├── pedido.json            # Evento do Passo 3 (R-001), gerado pelo SAM
│   ├── pedido-demorado.json   # R-003 com demorar=true
│   └── pedido-invalido.json   # Sem requisicaoId (deve dar 400)
├── scripts/               # Passos 3, 4 e 5 com saída salva em evidencias/
├── evidencias/            # Saídas (.txt) e prints (.png) dos comandos
└── tests/                 # Testes unitários e de integração (pytest)
```

## Mudanças em relação ao enunciado

1. **Decodificação do body em base64.** O `sam local generate-event apigateway aws-proxy`
   grava o `body` em base64 e marca `"isBase64Encoded": true`. O `json.loads` do handler
   original quebraria no Passo 3. Por isso o handler decodifica o body quando esse campo
   é `true`. O resto do código é o do enunciado.
2. **`warm_containers = "EAGER"` removido do `samconfig.toml`.** O `sam init` gera esse
   padrão para o `start-api`. Com ele, o container já seria reaproveitado sem passar
   nenhuma flag e o Passo 4 não mostraria diferença entre "sem" e "com"
   `--warm-containers`.

## Pré-requisitos

- [Docker Desktop](https://docs.docker.com/get-started/get-docker) aberto e rodando
- [AWS SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html) (`sam --version`)
- Python 3.12
- No Windows, use o **Git Bash** ou o **WSL** para os comandos funcionarem como estão escritos.

## Como rodar

### Passo 3: invocar com evento

```bash
sam build
sam local invoke -e events/pedido.json     # 1ª vez
sam local invoke -e events/pedido.json     # 2ª vez
```

Ou tudo de uma vez, salvando as saídas e os tempos em `evidencias/`:

```bash
./scripts/passo3-invoke.sh
```

Para regerar o evento (como no enunciado):

```bash
sam local generate-event apigateway aws-proxy --method POST --path guias \
    --body '{"requisicaoId":"R-001","hospital":"H-Recife","bolsas":["O-NEG-0142"]}' \
    > events/pedido.json
```

### Passo 4: acionar por HTTP

Terminal 1:

```bash
sam local start-api
```

Terminal 2, três chamadas:

```bash
curl -X POST http://127.0.0.1:3000/guias -H "Content-Type: application/json" \
    -d '{"requisicaoId":"R-002","hospital":"H-Caruaru"}'
# ou: ./scripts/passo4-curl.sh sem-warm
```

Pare o servidor (Ctrl+C), suba de novo com containers aquecidos e repita:

```bash
sam local start-api --warm-containers LAZY
./scripts/passo4-curl.sh lazy
```

### Passo 5: limite de tempo

Com o `start-api` no ar e `Timeout: 3` no `template.yaml`:

```bash
curl -X POST http://127.0.0.1:3000/guias -H "Content-Type: application/json" \
    -d '{"requisicaoId":"R-003","demorar":true}'
# ou: ./scripts/passo5-timeout.sh timeout-3s
```

Depois troque `Timeout: 3` por `Timeout: 10` em `Globals` no `template.yaml`, rode
`sam build`, reinicie o `start-api` e repita (`./scripts/passo5-timeout.sh timeout-10s`).

Também dá para testar por evento: `sam local invoke -e events/pedido-demorado.json`.

### Testes

```bash
pip install -r tests/requirements.txt
python -m pytest tests/unit            # não precisa de Docker
python -m pytest tests/integration     # precisa do sam local start-api no ar
```

## Resultados

> Preencher com os valores medidos (estão em `evidencias/`).

| Experimento | Resultado |
|---|---|
| `sam local invoke` 1ª vez | ⟨tempo⟩ s · Init Duration ⟨…⟩ ms |
| `sam local invoke` 2ª vez | ⟨tempo⟩ s · Init Duration ⟨…⟩ ms |
| `start-api` sem warm containers | `invocacaoNesteAmbiente`: ⟨…, …, …⟩ |
| `start-api --warm-containers LAZY` | `invocacaoNesteAmbiente`: ⟨…, …, …⟩ |
| `demorar=true` com `Timeout: 3` | ⟨mensagem de erro / status HTTP⟩ |
| `demorar=true` com `Timeout: 10` | ⟨status HTTP e tempo⟩ |

## Respostas

> Rascunho: reescrever com as minhas palavras e conferir com o que observei nos testes.

**1. Por que a primeira invocação demorou mais que a segunda? O que acontece na fase de Init?**

Na fase de Init o Lambda prepara o ambiente de execução antes de rodar o handler.
Ele cria o ambiente isolado (na AWS, uma microVM Firecracker; no SAM local, um container
Docker), baixa e descompacta o código e inicia o runtime do Python. Depois importa o
módulo `app.py` e roda tudo que está fora do handler, como os `import` e `contador = 0`.
Só então chama o `lambda_handler`. Isso é o **cold start**, e o log mostra o tempo dessa
fase em `Init Duration`.

No `sam local invoke`, cada execução cria um container novo, então as duas invocações
passam pelo Init e as duas retornam `invocacaoNesteAmbiente: 1`. A primeira demora mais
principalmente porque o SAM ainda precisa baixar e preparar a imagem
`public.ecr.aws/lambda/python:3.12`. Na segunda, a imagem já está em cache. Na nuvem, uma
segunda chamada pouco depois da primeira cai num ambiente **quente**: o Init não roda de
novo e só o handler executa.

**2. O que o campo `invocacaoNesteAmbiente` mostrou com e sem `--warm-containers`? O que isso diz sobre guardar estado numa variável global da função?**

Sem `--warm-containers`, cada requisição subiu um container novo e o campo veio sempre
`1`: a variável global nasceu zerada a cada chamada. Com `--warm-containers LAZY`, o
container foi criado na primeira requisição e reaproveitado nas seguintes, e o campo
mostrou `1`, `2`, `3`. O módulo continuou carregado na memória entre as chamadas.

Então uma variável global **não é um lugar confiável para guardar estado**. Ela só
sobrevive enquanto o mesmo ambiente for reaproveitado, e quem decide isso é a plataforma.
Com várias chamadas ao mesmo tempo, o Lambda cria vários ambientes, cada um com o seu
contador. O ambiente também pode ser descartado a qualquer momento. A global serve para
cache (conexão com banco, configuração já lida), mas o estado de negócio, como guias e
requisições, precisa ficar num serviço externo (DynamoDB, RDS, S3, Redis).

**3. O que aconteceu com `demorar = true`? Qual é o tempo máximo de uma execução no Lambda, e o que fazer com um trabalho mais longo?**

Com `Timeout: 3`, a função foi interrompida aos 3 segundos, antes de terminar o
`time.sleep(5)`. O SAM registrou que a função passou do tempo limite (`Function ...
timed out after 3 seconds`) e a API respondeu com erro (502) em vez da guia. Com
`Timeout: 10`, a função dormiu 5 s e devolveu a guia normalmente (201).

O tempo máximo de uma execução no Lambda é **900 segundos (15 minutos)**. Para um
trabalho mais longo dá para:

- quebrar o trabalho em etapas menores e orquestrá-las com **AWS Step Functions**;
- processar de forma assíncrona: a função recebe o pedido, coloca numa fila
  (**SQS**) e responde na hora, e outras funções processam pedaços menores;
- usar um serviço sem esse limite, como **ECS/Fargate** ou **AWS Batch**, para
  processamentos pesados ou contínuos.

**4. Quanto custa um milhão de execuções desta função com 128 MB e 100 ms?**

Preços de us-east-1 da aula: US$ 0,20 por milhão de requisições e
US$ 0,0000166667 por GB-s.

```
Requisições:  1.000.000 × (US$ 0,20 / 1.000.000)          = US$ 0,20

Computação:   memória   = 128 MB = 128 / 1024 GB           = 0,125 GB
              duração   = 100 ms                           = 0,1 s
              por exec. = 0,125 GB × 0,1 s                 = 0,0125 GB-s
              total     = 0,0125 GB-s × 1.000.000          = 12.500 GB-s
              custo     = 12.500 × US$ 0,0000166667        ≈ US$ 0,2083

Total:        US$ 0,20 + US$ 0,2083                        ≈ US$ 0,41
```

Um milhão de execuções custam cerca de **US$ 0,41**. Dentro da faixa sempre gratuita
(1 milhão de requisições e 400 mil GB-s por mês) o custo seria **zero**, porque
12.500 GB-s estão bem abaixo de 400.000 GB-s.

**5. Em que parte do Rota Vital uma função assim faria sentido, e em qual não faria?**

*Faria sentido* em tarefas curtas, sem estado e disparadas por evento: gerar a guia
de transporte quando uma requisição de bolsas é aprovada, enviar notificação ao
hospital e ao motorista, validar um pedido recebido por API ou gerar o PDF da guia.
Essas tarefas acontecem de forma irregular, com picos em emergências e quase nada de
madrugada. O Lambda escala sozinho nos picos e não cobra nada quando está parado.

*Não faria sentido* no acompanhamento em tempo real do transporte, com conexão aberta
(WebSocket) recebendo a posição do veículo o tempo todo, nem em processos longos ou
contínuos, como uma reconciliação grande de estoque, que passariam dos 15 minutos.
Também não serviria para guardar estado em memória, como o estoque de bolsas de um
hemocentro. Nesses casos, o limite de tempo, o cold start e a falta de estado
atrapalham. Um serviço sempre ligado (container/ECS) com um banco de dados combina mais.

## Uso de IA

Declaração conforme a PO-CESAR-021.

- **Ferramenta:** Claude (Anthropic).
- **Finalidade:** montar a estrutura do projeto a partir do `sam init`, ajustar o
  `template.yaml` para `POST /guias`, identificar dois problemas no fluxo do enunciado
  (body em base64 no evento gerado e `warm_containers = "EAGER"` no `samconfig.toml`),
  escrever os testes, os scripts de evidência, o rascunho do README e o rascunho das
  respostas e da conta de custo.
- **Como validei:** ⟨descrever: rodei `sam build`, `sam local invoke` e `start-api` na
  minha máquina; conferi os tempos e o campo `invocacaoNesteAmbiente` com as saídas em
  `evidencias/`; refiz a conta de custo à mão; li a documentação de ciclo de vida e de
  cotas do Lambda; reescrevi as respostas com as minhas palavras⟩.

## Referências

- [Ciclo de vida do ambiente de execução do Lambda](https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtime-environment.html)
- [Cotas do Lambda](https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html)
- [Preços do Lambda](https://aws.amazon.com/lambda/pricing/)
- [Instalação do SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html)
