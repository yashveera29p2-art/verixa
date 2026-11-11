"""DOCX export (feature 10)."""

import io

from docx import Document
from fastapi.testclient import TestClient

from app.auth import CurrentUser, current_user
from app.export import ResumeIn, resume_docx
from app.main import app

RESUME = {
    "name": "Asha Rao",
    "headline": "Backend Developer",
    "contact": ["+91 98xxxxxxxx", "Bengaluru, Karnataka"],
    "template": "modern",
    "blocks": [
        {"title": "Skills", "items": [{"heading": "Technical", "line": "Java, Python"}]},
        {"title": "Projects", "items": [{
            "heading": "Verixa", "subheading": "Flutter, Python", "meta": "2025",
            "bullets": ["Built a resume scanner.", "Parsed PDFs with spaCy."]}]},
        {"title": "Certifications", "items": [{"line": "AWS Cloud Practitioner", "bullet": True}]},
    ],
}


def _text(data: bytes) -> str:
    return "\n".join(p.text for p in Document(io.BytesIO(data)).paragraphs)


def test_resume_docx_keeps_all_content_in_reading_order():
    text = _text(resume_docx(ResumeIn(**RESUME)))
    for expected in ["Asha Rao", "SKILLS", "Technical: Java, Python", "PROJECTS",
                     "Verixa", "Built a resume scanner.", "AWS Cloud Practitioner"]:
        assert expected in text
    assert text.index("SKILLS") < text.index("PROJECTS") < text.index("CERTIFICATIONS")


def test_export_endpoints():
    app.dependency_overrides[current_user] = lambda: CurrentUser(uid="u1")
    try:
        client = TestClient(app)
        r = client.post("/v1/export/resume.docx", json=RESUME)
        assert r.status_code == 200
        assert "Asha Rao" in _text(r.content)
        r = client.post("/v1/export/cover-letter.docx", json={
            "name": "Asha Rao", "contact": [], "text": "Dear Hiring Manager,\n\nI am applying."})
        assert r.status_code == 200
        assert "I am applying." in _text(r.content)
    finally:
        app.dependency_overrides.clear()
