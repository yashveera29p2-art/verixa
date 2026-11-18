"""Matching v2 (ranking) and job search."""

from fastapi.testclient import TestClient

from app.jobs import search_jobs
from app.main import app
from app.matching.profile import ExperienceIn, ProfileIn, ProjectIn
from app.matching.ranking import (CandidateIn, JobIn, RankCandidatesRequest,
                                  RankJobsRequest, rank_candidates, rank_jobs)

client = TestClient(app)

BACKEND = JobIn(id="b", title="Backend Engineer (Python)", description=(
    "Required: Python, REST API design, SQL databases. "
    "Preferred: Docker. Build and own payment services."))
EMBEDDED = JobIn(id="e", title="Embedded Software Engineer", description=(
    "Required: C, C++, microcontrollers, RTOS basics. Preferred: AUTOSAR, CAN protocol."))

PYTHON_DEV = ProfileIn(
    status="student", degree="B.Tech", branch="Computer Science",
    skills=["Python", "SQL", "REST APIs"],
    projects=[ProjectIn(title="Verixa", techStack=["Python", "FastAPI", "SQL"],
                        description="Built REST APIs in Python with FastAPI and a SQL database.")],
)


def test_jobs_ranked_by_fit_with_reasons():
    results = rank_jobs(RankJobsRequest(profile=PYTHON_DEV, jobs=[EMBEDDED, BACKEND]))
    assert [r.id for r in results] == ["b", "e"]
    top = results[0]
    assert top.score > results[1].score
    assert top.reasons
    assert "C" in results[1].gaps or "C++" in results[1].gaps


def test_any_of_skills_counts_once():
    job = JobIn(id="t", title="Trainee", description=(
        "Required: programming in Java, Python or C. Good communication skills."))
    [r] = rank_jobs(RankJobsRequest(profile=PYTHON_DEV, jobs=[job]))
    assert "Java" not in r.gaps


def test_proven_skills_beat_listed_only():
    listed = ProfileIn(status="student", skills=["Python", "SQL", "REST APIs"])
    proven = rank_jobs(RankJobsRequest(profile=PYTHON_DEV, jobs=[BACKEND]))[0].score
    only_listed = rank_jobs(RankJobsRequest(profile=listed, jobs=[BACKEND]))[0].score
    assert proven > only_listed


def test_candidates_ranked_with_work_style():
    a = CandidateIn(id="a", profile=PYTHON_DEV, traits={"ownership": 90, "teamwork": 60})
    b = CandidateIn(id="b", profile=PYTHON_DEV, traits={"ownership": 20, "teamwork": 40})
    c = CandidateIn(id="c", profile=ProfileIn(status="student", skills=["Photoshop"]))
    results = rank_candidates(RankCandidatesRequest(
        job=BACKEND, wantedTraits={"ownership": 1.0}, candidates=[c, b, a]))
    assert [r.id for r in results] == ["a", "b", "c"]
    assert results[0].traitFit == 90


def test_intern_experience_is_evidence():
    p = ProfileIn(status="student", experience=[ExperienceIn(
        type="internship", company="Acme", role="Backend Intern",
        description="Designed REST APIs in Python backed by a PostgreSQL SQL database.")])
    [r] = rank_jobs(RankJobsRequest(profile=p, jobs=[BACKEND]))
    assert r.score > 0


def test_sample_search_filters():
    source, jobs = search_jobs("android", internship=True)
    assert source == "sample"
    assert jobs and all(j.contract == "internship" for j in jobs)
    _, unpaid = search_jobs("unpaid")
    assert any(j.salaryMax == 0 for j in unpaid)


def test_endpoints():
    r = client.post("/v1/jobs/search", json={"query": "python"})
    assert r.status_code == 200 and r.json()["source"] == "sample"
    r = client.post("/v1/jobs/rank", json={
        "profile": PYTHON_DEV.model_dump(), "jobs": [BACKEND.model_dump()]})
    assert r.status_code == 200 and r.json()["results"][0]["id"] == "b"
