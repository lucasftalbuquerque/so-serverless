import base64, json, time

contador = 0     # variável global: só sobrevive se o ambiente for reaproveitado

def lambda_handler(event, context):
    global contador
    contador += 1
    corpo = event.get("body") or "{}"
    if event.get("isBase64Encoded"):  # o sam local generate-event grava o body em base64
        corpo = base64.b64decode(corpo).decode("utf-8")
    pedido = json.loads(corpo)
    if "requisicaoId" not in pedido:
        return {"statusCode": 400,
                "body": json.dumps({"erro": "requisicaoId obrigatório"})}
    if pedido.get("demorar"):
        time.sleep(5) # passa do Timeout de 3 s do template
    guia = {"guia": "G-" + pedido["requisicaoId"],
            "hospital": pedido.get("hospital"),
            "bolsas": pedido.get("bolsas", []),
            "invocacaoNesteAmbiente": contador}
    return {"statusCode": 201, "body": json.dumps(guia)}
