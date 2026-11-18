"""Context-aware ranking in both directions (matching v2).

* rank_jobs: many job listings for one student (Jobs tab).
* rank_candidates: many opted-in students for one job (recruiter mode).

Both reuse match_profile (requirements compared with the profile's
sentences by meaning) and add:
* proof over listing: a skill shown in a project, internship or job counts
  fully; a skill that is only listed counts 85 %;
* plain-language reasons ("Project: Verixa covers 'REST API design'") and
  gaps (required skills the profile doesn't show);
* for recruiters, an optional work-style fit from the student's quiz.
"""

from __future__ import annotations

import re

from pydantic import BaseModel, Field

from ..models import MatchReport
from .matcher import WEIGHT, match_profile
from .profile import ProfileIn

LISTED_ONLY = 0.85
TRAITS = ("teamwork", "ownership", "structure", "communication", "adaptability")


class JobIn(BaseModel):
    id: str = Field(max_length=120)
    title: str = Field(default="", max_length=300)
    description: str = Field(default="", max_length=8000)


class RankItem(BaseModel):
    id: str
    score: int  # 0–100
    verdict: str  # strong | good | partial | low
    reasons: list[str] = []
    gaps: list[str] = []
    traitFit: int | None = None  # 0–100, recruiters only


class RankJobsRequest(BaseModel):
    profile: ProfileIn
    jobs: list[JobIn] = Field(max_length=40)


class CandidateIn(BaseModel):
    id: str = Field(max_length=120)
    profile: ProfileIn
    traits: dict[str, float] = {}  # trait -> 0..100 from the work-style quiz


class RankCandidatesRequest(BaseModel):
    job: JobIn
    wantedTraits: dict[str, float] = {}  # trait -> importance 0..1
    candidates: list[CandidateIn] = Field(max_length=60)


def _proven_text(profile: ProfileIn) -> str:
    parts = []
    for p in profile.projects:
        parts += [p.title, p.description, " ".join(p.techStack)]
    for e in profile.experience:
        parts += [e.role, e.description]
    return " ".join(parts).lower()


def _verdict(score: int) -> str:
    return ("strong" if score >= 75 else "good" if score >= 55
            else "partial" if score >= 35 else "low")


def _score(report: MatchReport, profile: ProfileIn) -> int:
    """Weighted credit like match_profile, but skills that are only listed
    (never shown in a project or job) earn a little less."""
    proven = _proven_text(profile)
    total = earned = 0.0
    for r in report.requirements:
        w = WEIGHT[r.importance]
        total += w
        credit = {"met": 1.0, "partial": 0.5}.get(r.status, 0.0)
        if credit and r.evidence.startswith("Skills: "):
            named = [s.strip().lower() for s in r.evidence[8:].split(",")]
            if not any(re.search(rf"(?<![a-z]){re.escape(s)}(?![a-z])", proven) for s in named):
                credit *= LISTED_ONLY
        earned += w * credit
    return round(100 * earned / total) if total else 0


def _reasons(report: MatchReport) -> list[str]:
    shown, listed = [], []
    for r in report.requirements:
        if r.status != "met" or not r.evidence:
            continue
        need = r.text if len(r.text) <= 70 else r.text[:67].rstrip() + "…"
        if r.evidence.startswith(("Project:", "Internship:", "Job:", "Certification:")):
            shown.append(f"{r.evidence} covers “{need}”")
        elif r.evidence.startswith("Skills: "):
            listed.append(r.evidence[8:])
        elif r.evidence.startswith("Education:"):
            listed.append(r.evidence[11:])
    out = shown[:2]
    if listed:
        out.append("Has " + "; ".join(dict.fromkeys(listed))[:120])
    return out[:3]


def _gaps(report: MatchReport) -> list[str]:
    return [m.skill for m in report.missingSkills if m.importance == "required"][:4]


def _job_text(job: JobIn) -> str:
    text = f"{job.title}\n{job.description}".strip()
    # match_profile needs a little text to work with.
    return text if len(text) >= 50 else (text + "\n" + job.title) * 2


def rank_jobs(req: RankJobsRequest) -> list[RankItem]:
    out = []
    for job in req.jobs:
        report = match_profile(_job_text(job), req.profile)
        score = _score(report, req.profile)
        out.append(RankItem(id=job.id, score=score, verdict=_verdict(score),
                            reasons=_reasons(report), gaps=_gaps(report)))
    return sorted(out, key=lambda r: r.score, reverse=True)


def _trait_fit(wanted: dict[str, float], have: dict[str, float]) -> int | None:
    weights = {t: max(0.0, min(1.0, w)) for t, w in wanted.items() if t in TRAITS}
    if not sum(weights.values()) or not have:
        return None
    fit = sum(w * max(0.0, min(100.0, have.get(t, 50.0))) for t, w in weights.items())
    return round(fit / sum(weights.values()))


def rank_candidates(req: RankCandidatesRequest) -> list[RankItem]:
    text = _job_text(req.job)
    out = []
    for c in req.candidates:
        report = match_profile(text, c.profile)
        skill_score = _score(report, c.profile)
        fit = _trait_fit(req.wantedTraits, c.traits)
        # Skills and evidence decide; work style refines (20 %).
        score = skill_score if fit is None else round(0.8 * skill_score + 0.2 * fit)
        out.append(RankItem(id=c.id, score=score, verdict=_verdict(score),
                            reasons=_reasons(report), gaps=_gaps(report), traitFit=fit))
    return sorted(out, key=lambda r: r.score, reverse=True)
