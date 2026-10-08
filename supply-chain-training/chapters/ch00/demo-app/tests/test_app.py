from app import app


def test_index_returns_ok():
    client = app.test_client()
    resp = client.get("/")
    assert resp.status_code == 200
    assert resp.get_json() == {"status": "ok"}


def test_version_has_value():
    client = app.test_client()
    resp = client.get("/version")
    assert resp.status_code == 200
    assert "version" in resp.get_json()
