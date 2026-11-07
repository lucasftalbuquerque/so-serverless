"""Testes contra a API local (sam local start-api).

Suba a API antes:  sam build && sam local start-api
A URL pode ser trocada com a variável SAM_API_URL (padrão http://127.0.0.1:3000).
"""
import os

import pytest
import requests

URL = os.environ.get("SAM_API_URL", "http://127.0.0.1:3000").rstrip("/") + "/guias"


@pytest.fixture(scope="module", autouse=True)
def api_no_ar():
    try:
        requests.post(URL, json={"requisicaoId": "PING"}, timeout=60)
    except requests.exceptions.ConnectionError:
        pytest.skip(f"API local não está rodando em {URL}")


def test_post_guias_cria_guia():
    r = requests.post(URL, json={"requisicaoId": "R-002", "hospital": "H-Caruaru"}, timeout=60)
    assert r.status_code == 201
    corpo = r.json()
    assert corpo["guia"] == "G-R-002"
    assert corpo["hospital"] == "H-Caruaru"
    assert corpo["invocacaoNesteAmbiente"] >= 1


def test_post_guias_sem_requisicao_id_retorna_400():
    r = requests.post(URL, json={"hospital": "H-Caruaru"}, timeout=60)
    assert r.status_code == 400
