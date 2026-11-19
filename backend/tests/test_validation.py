"""Rejecting documents and text that aren't what the screen asks for."""

import json
from pathlib import Path

from fastapi.testclient import TestClient

from app.main import app
from app.validation import is_job_description, is_resume, review_problem

from .samples import FRESHER, PROFESSIONAL, STUDENT

INVOICE = """TAX INVOICE
Sharma Electronics Pvt Ltd  GSTIN: 36ABCDE1234F1Z5
Invoice No: INV-2025-0091   Date: 12/08/2025   Bill To: Ravi Kumar, Hyderabad
Item  Qty  Rate  Amount
Samsung Monitor 24 inch  1  12,500  12,500     HDMI cable  2  350  700
Subtotal 13,200  CGST 9% 1,188  SGST 9% 1,188  Grand Total 15,576
Payment terms: due within 15 days. Thank you for your business. HSN 8528."""

CERTIFICATE = """CERTIFICATE OF COMPLETION
This is to certify that Priya Sharma has successfully completed the course Python for
Data Science conducted by ABC Academy from June 2024 to August 2024 with grade A. In
recognition of her dedication this certificate is hereby awarded on 30 August 2024.
Signed, Director, ABC Academy, Hyderabad. Certificate ID 77812."""

QUESTION_PAPER = """B.Tech III Year I Semester Examinations
Subject: Database Management Systems   Time allowed: 3 hours   Maximum Marks: 70
Answer all questions. Section A carries 20 marks. Section B carries 50 marks.
1. Explain normalisation with examples. (10 marks)
2. What is a transaction? Explain ACID properties. (10 marks)
3. Write SQL queries for the given schema. (10 marks)"""

JD = json.loads((Path(__file__).parents[1] / "app/jobs/samples.json").read_text("utf-8"))[5]


def test_resumes_accepted():
    for text in (STUDENT, FRESHER, PROFESSIONAL):
        assert is_resume(text).ok


def test_other_documents_rejected_with_their_type():
    for text, kind in ((INVOICE, "invoice"), (CERTIFICATE, "certificate"),
                       (QUESTION_PAPER, "question paper")):
        v = is_resume(text)
        assert not v.ok and kind in v.message
        assert "upload your resume" in v.message


def test_job_descriptions():
    assert is_job_description(JD["title"] + "\n" + JD["description"]).ok
    v = is_job_description(STUDENT)
    assert not v.ok and "resume" in v.message
    assert not is_job_description("python developer needed").ok
    assert not is_job_description(
        "Grocery list: rice 5kg, dal 2kg, sugar 1kg, oil 2 litres, milk, eggs, bread, "
        "tomatoes, onions, potatoes, salt, chilli powder and tea.").ok


def test_reviews():
    assert review_problem("Good learning, supportive manager, long hours in releases.").ok
    assert review_problem("").ok  # star ratings only
    assert not review_problem("worst idiot managers").ok
    assert not review_problem("call 9876543210 now").ok
    assert not review_problem(
        "The movie last night was great and the food was tasty and amazing too").ok


def test_text_check_endpoint():
    client = TestClient(app)
    r = client.post("/v1/text/check", json={"kind": "review", "text": "idiot company"})
    assert r.status_code == 200 and r.json()["ok"] is False


def test_writing_checker_flags_weak_bullets():
    from app.writing import check_writing
    weak = ("PROJECTS\n"
            "• Responsible for the backend of a college app which was developed using Django.\n"
            "• Worked on the database and helped with testing.\n"
            "• I am a hardworking team player and I learned a lot in my internship.\n")
    strong = ("EXPERIENCE\n"
              "• Built a REST API serving 2,000 daily users and cut response time by 40%.\n"
              "• Automated weekly reports in Python, saving the team 6 hours a week.\n")
    w, s = check_writing(weak), check_writing(strong)
    kinds = {i.kind for i in w.issues}
    assert {"weak_phrase", "passive", "buzzword", "no_impact"} <= kinds
    assert s.score > w.score and s.quantifiedPercent == 100


def test_review_sentiment():
    from app.sentiment import analyze_reviews, sentence_polarity
    assert sentence_polarity("Salary is not good") < 0
    assert sentence_polarity("Very supportive manager and great learning") > 0.5
    r = analyze_reviews(["Great learning and supportive mentors. Pay is low though.",
                         "Long hours and weekend work. Not recommended."], [4, 2])
    by = {a.aspect: a.label for a in r.aspects}
    assert by["Learning"] == "positive" and by["Pay"] == "negative"
    assert by["Work-life balance"] == "negative"
    client = TestClient(app)
    res = client.post("/v1/reviews/analyze", json={"texts": ["Good culture"], "ratings": [5]})
    assert res.status_code == 200 and res.json()["overall"] == "Mostly positive"
