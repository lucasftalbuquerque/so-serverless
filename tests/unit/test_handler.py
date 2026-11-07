import base64
import json
from pathlib import Path

import pytest

from hello_world import app

EVENTOS = Path(__file__).resolve().parents[2] / "events"


def evento_http(corpo):
    """Evento mínimo no formato do API Gateway (proxy), com body em texto."""
    return {"httpMethod": "POST", "path": "/guias",
            "body": None if corpo is None else json.dumps(corpo),
            "isBase64Encoded": False}


@pytest.fixture(autouse=True)
def zera_contador():
    app.contador = 0
    yield


def test_gera_guia_a_partir_do_evento_gerado_pelo_sam():
    evento = json.loads((EVENTOS / "pedido.json").read_text(encoding="utf-8"))
    assert evento["isBase64Encoded"] is True

    ret = app.lambda_handler(evento, None)
    guia = json.loads(ret["body"])

    assert ret["statusCode"] == 201
    assert guia == {"guia": "G-R-001", "hospital": "H-Recife",
                    "bolsas": ["O-NEG-0142"], "invocacaoNesteAmbiente": 1}


def test_aceita_body_em_texto_como_no_start_api():
    ret = app.lambda_handler(evento_http({"requisicaoId": "R-002", "hospital": "H-Caruaru"}), None)
    guia = json.loads(ret["body"])

    assert ret["statusCode"] == 201
    assert guia["guia"] == "G-R-002"
    assert guia["bolsas"] == []


def test_body_base64_manual():
    corpo = base64.b64encode(b'{"requisicaoId":"R-009"}').decode()
    ret = app.lambda_handler({"body": corpo, "isBase64Encoded": True}, None)
    assert json.loads(ret["body"])["guia"] == "G-R-009"


@pytest.mark.parametrize("corpo", [None, {}, {"hospital": "H-Recife"}])
def test_sem_requisicao_id_retorna_400(corpo):
    ret = app.lambda_handler(evento_http(corpo), None)
    assert ret["statusCode"] == 400
    assert json.loads(ret["body"]) == {"erro": "requisicaoId obrigatório"}


def test_contador_global_cresce_no_mesmo_ambiente():
    """Dentro do mesmo processo (ambiente reaproveitado) a variável global persiste."""
    valores = [json.loads(app.lambda_handler(evento_http({"requisicaoId": f"R-{i}"}), None)["body"])
               ["invocacaoNesteAmbiente"] for i in range(3)]
    assert valores == [1, 2, 3]


def test_demorar_dorme_cinco_segundos(monkeypatch):
    dormiu = []
    monkeypatch.setattr(app.time, "sleep", dormiu.append)
    ret = app.lambda_handler(evento_http({"requisicaoId": "R-003", "demorar": True}), None)
    assert dormiu == [5]
    assert ret["statusCode"] == 201
