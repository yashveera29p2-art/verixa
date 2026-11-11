"""Job description analysis and matching (feature 8)."""

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.matching import match_profile
from app.matching.jd import analyze_jd
from app.matching.matcher import semantic_available
from app.matching.profile import ExperienceIn, ProfileIn, ProjectIn

BACKEND_JD = """\
Software Engineer – Backend (Fresher)
About us
We are a fintech startup in Bengaluru building payment products.
What you'll do
- Build and maintain REST APIs for our payments platform
- Write unit tests and take part in code reviews
Requirements
- B.Tech/B.E. in Computer Science or a related field
- Strong programming skills in Java or Python
- Good understanding of SQL databases
- Hands-on with Spring Boot
- 0-1 years of experience
Nice to have
- Exposure to Docker and Kubernetes
- Familiarity with AWS
Benefits
- Health insurance and flexible hours
"""

SENIOR_DATA_JD = """\
Senior Data Scientist
Requirements
- 5+ years of experience in machine learning
- Master's degree or PhD in Statistics or Computer Science
- Expert in TensorFlow, PyTorch and Spark
- Experience deploying models on GCP
"""

PARAPHRASE_JD = """\
Junior Developer
Requirements
- Experience designing backend web services and HTTP endpoints for other teams
- Comfortable writing automated checks for the code you ship
"""


@pytest.fixture
def student() -> ProfileIn:
    return ProfileIn(
        status="student",
        targetRole="Backend Developer",
        degree="B.Tech",
        branch="CSE",
        skills=["Java", "Python", "SQL", "Flutter", "Spring Boot", "Dart"],
        tools=["Git", "Postman"],
        projects=[ProjectIn(title="Verixa", description="Resume app with a parser.",
                            techStack=["Flutter", "Firebase", "Python"])],
        experience=[ExperienceIn(
            type="internship", company="Acme Technologies", role="Software Intern",
            description="Developed REST APIs using Spring Boot. Wrote JUnit unit "
                        "tests. Reduced report generation time by 30%.")],
    )


# ── JD analysis ────────────────────────────────────────────────────────────

def test_reads_title_level_years_and_education():
    job = analyze_jd(BACKEND_JD)
    assert job.title == "Software Engineer – Backend (Fresher)"
    assert job.seniority == "Entry level"
    assert job.years_required == 0
    assert "B.Tech" in job.education


def test_separates_required_and_preferred_skills():
    job = analyze_jd(BACKEND_JD)
    assert {"Java", "Python", "SQL", "Spring Boot"} <= set(job.skills("required"))
    assert {"Docker", "Kubernetes", "AWS"} <= set(job.skills("preferred"))
    assert not set(job.skills("preferred")) & {"Java", "SQL"}


def test_ignores_company_blurb_and_benefits():
    texts = " ".join(r.text for r in analyze_jd(BACKEND_JD).requirements)
    assert "Health insurance" not in texts
    assert "fintech startup" not in texts


def test_inline_preferred_hint():
    job = analyze_jd("Requirements\n- Java is required\n- Kafka experience is a plus\n")
    importance = {r.skills[0]: r.importance for r in job.requirements if r.skills}
    assert importance == {"Java": "required", "Kafka": "preferred"}


# ── Matching ───────────────────────────────────────────────────────────────

def test_good_fit_scores_high(student):
    report = match_profile(BACKEND_JD, student)
    assert report.matchScore >= 70
    assert report.verdict in ("strong", "good")
    by_kind = {r.kind: r for r in report.requirements}
    assert by_kind["education"].status == "met"
    assert by_kind["experience"].status == "met"
    assert set(report.matchedSkills) >= {"Java", "Python", "SQL", "Spring Boot"}
    assert [(m.skill, m.importance) for m in report.missingSkills] == [
        ("Docker", "preferred"), ("Kubernetes", "preferred"), ("AWS", "preferred")]
    assert report.skillCoverage is not None and report.skillCoverage >= 50


def test_poor_fit_scores_low_with_honest_advice(student):
    report = match_profile(SENIOR_DATA_JD, student)
    assert report.matchScore < 35
    assert report.verdict == "low"
    [exp] = [r for r in report.requirements if r.kind == "experience"]
    assert exp.status == "missing" and "5+" in exp.evidence or exp.evidence == ""
    assert any("genuinely" in s for s in report.suggestions)
    assert {"TensorFlow", "PyTorch"} <= {m.skill for m in report.missingSkills}


def test_met_requirements_name_their_evidence(student):
    report = match_profile(BACKEND_JD, student)
    spring = next(r for r in report.requirements if "Spring Boot" in r.text)
    assert spring.status == "met"
    assert "Spring Boot" in spring.evidence


@pytest.mark.skipif(not semantic_available(), reason="sentence-transformers model not available")
def test_semantic_match_without_shared_keywords(student):
    report = match_profile(PARAPHRASE_JD, student)
    assert report.semantic is True
    services = report.requirements[0]
    # No dictionary skill in common — matched purely by meaning to the
    # internship ("Developed REST APIs using Spring Boot").
    assert services.kind == "responsibility"
    assert services.status in ("met", "partial")
    assert "Internship" in services.evidence


ONE_PARAGRAPH_JD = (
    "Backend Developer Fresher role. Requirements: Strong programming skills in "
    "Java or Python. Hands-on with Spring Boot. Experience building REST APIs. "
    "Nice to have: exposure to Docker and Kubernetes. Familiarity with AWS is a plus."
)


def test_one_paragraph_jd_strips_inline_labels(student):
    job = analyze_jd(ONE_PARAGRAPH_JD)
    texts = [r.text for r in job.requirements]
    assert "Strong programming skills in Java or Python." in texts
    assert not any(t.lower().startswith(("requirements:", "nice to have:")) for t in texts)
    docker = next(r for r in job.requirements if "Docker" in r.text)
    assert docker.importance == "preferred"


def test_named_tools_get_no_credit_from_loose_similarity(student):
    # Regression: "Docker and Kubernetes" was "partly met" by an AWS
    # certificate. With none of the named tools in the profile it's missing.
    student.certifications = ["AWS Cloud Practitioner (2025)"]
    report = match_profile(ONE_PARAGRAPH_JD, student)
    docker = next(r for r in report.requirements if "Docker" in r.text)
    assert docker.status == "missing"


def test_some_named_tools_give_partial_credit(student):
    student.tools = ["Docker"]
    report = match_profile(BACKEND_JD, student)
    docker = next(r for r in report.requirements if "Docker" in r.text)
    assert docker.status == "partial"
    assert docker.evidence == "Skills: Docker"


def test_empty_profile_is_handled():
    report = match_profile(BACKEND_JD, ProfileIn())
    assert report.matchScore < 35
    assert all(r.status != "met" or r.kind == "experience" for r in report.requirements)


# ── API ────────────────────────────────────────────────────────────────────

def test_match_endpoint(student):
    client = TestClient(app)
    r = client.post("/v1/jobs/match",
                    json={"jobDescription": BACKEND_JD, "profile": student.model_dump()})
    assert r.status_code == 200
    body = r.json()
    assert body["job"]["seniority"] == "Entry level"
    assert body["requirements"] and "matchScore" in body


def test_match_endpoint_rejects_tiny_jd(student):
    client = TestClient(app)
    r = client.post("/v1/jobs/match",
                    json={"jobDescription": "Java dev", "profile": student.model_dump()})
    assert r.status_code == 422
