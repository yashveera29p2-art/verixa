"""HTTP-level tests for the FastAPI app."""

from fastapi.testclient import TestClient

from app import auth as auth_module
from app.config import Settings
from app.main import app

from .samples import STUDENT, make_docx, make_pdf

client = TestClient(app)


def _upload(data: bytes, name="resume.pdf", headers=None):
    return client.post("/v1/resumes/parse",
                       files={"file": (name, data, "application/octet-stream")},
                       headers=headers or {})


def test_health():
    r = client.get("/health")
    assert r.status_code == 200 and r.json()["status"] == "ok"


def test_parses_pdf_upload():
    r = _upload(make_pdf(STUDENT))
    assert r.status_code == 200
    body = r.json()
    assert body["contact"]["fullName"] == "Priya Sharma"
    assert body["meta"]["fileType"] == "pdf"


def test_parses_docx_upload():
    r = _upload(make_docx(STUDENT), name="resume.docx")
    assert r.status_code == 200
    assert r.json()["education"]["degree"]["degree"] == "B.Tech"


def test_rejects_other_file_types():
    r = _upload(b"plain text, not a resume file", name="resume.txt")
    assert r.status_code == 415


def test_rejects_empty_file():
    assert _upload(b"").status_code == 400


def test_rejects_files_over_the_limit(monkeypatch):
    import app.main as main_module
    monkeypatch.setattr(main_module, "settings", Settings(max_upload_bytes=1000))
    r = _upload(make_pdf(STUDENT))
    assert r.status_code == 413


def test_requires_sign_in_when_auth_is_on(monkeypatch):
    monkeypatch.setattr(auth_module, "settings", Settings(auth_mode="firebase"))
    assert _upload(make_pdf(STUDENT)).status_code == 401
    bad = _upload(make_pdf(STUDENT), headers={"Authorization": "Bearer not-a-real-token"})
    assert bad.status_code == 401
