"""Matches a profile against a job description (feature 8).

Skills are checked exactly first (is "Docker" in the profile?). Anything
not covered exactly is compared by meaning with MiniLM sentence embeddings
(run through fastembed/ONNX — small enough for a 512 MB server), so
"built REST services in Spring Boot" can satisfy "experience designing
APIs". If the model can't load, a simple word-overlap similarity is used
and the report says so (semantic=False).
"""

from __future__ import annotations

import logging
import os
import re
from functools import lru_cache

import numpy as np

from ..models import JobSummary, MatchReport, MissingSkill, RequirementResult
from .jd import JobAnalysis, Requirement, analyze_jd
from .profile import ProfileIn, evidence, known_skills

log = logging.getLogger("verixa.matching")

MODEL_NAME = "sentence-transformers/all-MiniLM-L6-v2"
# Cosine-similarity thresholds for MiniLM sentence embeddings, calibrated
# on sample JDs: paraphrases of the same work score ~0.5–0.8, related-but-
# different topics ~0.25–0.35, unrelated ones below 0.2.
MET = 0.55
PARTIAL = 0.38
WEIGHT = {"required": 1.0, "preferred": 0.5}
CREDIT = {"met": 1.0, "partial": 0.5, "missing": 0.0}


# ── Similarity backends ────────────────────────────────────────────────────

@lru_cache(maxsize=1)
def _model():
    """Loads MiniLM once (downloads ~90 MB on first use). None if unavailable."""
    try:
        from fastembed import TextEmbedding
        return TextEmbedding(MODEL_NAME, cache_dir=os.getenv("VERIXA_MODEL_DIR"))
    except Exception as exc:  # no package, no network on first run, …
        log.warning("Semantic model unavailable, using word overlap: %s", exc)
        return None


def _embed(model, texts: list[str]) -> np.ndarray:
    vectors = np.array(list(model.embed(texts)), dtype=np.float32)
    return vectors / np.linalg.norm(vectors, axis=1, keepdims=True).clip(min=1e-9)


def semantic_available() -> bool:
    return _model() is not None


def _tokens(text: str) -> set[str]:
    return {w for w in re.findall(r"[a-z0-9+#.]+", text.lower()) if len(w) > 2}


def _similarity(queries: list[str], docs: list[str]) -> list[list[float]]:
    if not queries or not docs:
        return [[0.0] * len(docs) for _ in queries]
    model = _model()
    if model is not None:
        return (_embed(model, queries) @ _embed(model, docs).T).tolist()
    # Fallback: Jaccard word overlap (scaled to land near the same thresholds).
    out = []
    for query in queries:
        qt = _tokens(query)
        row = []
        for doc in docs:
            dt = _tokens(doc)
            row.append(min(1.0, 1.6 * len(qt & dt) / len(qt | dt)) if qt and dt else 0.0)
        out.append(row)
    return out


# ── Requirement checks ─────────────────────────────────────────────────────

def _status(score: float) -> str:
    return "met" if score >= MET else "partial" if score >= PARTIAL else "missing"


def _years_status(req: Requirement, profile: ProfileIn) -> tuple[str, str]:
    have = profile.totalExperienceYears
    internships = sum(1 for e in profile.experience if e.type == "internship")
    jobs = sum(1 for e in profile.experience if e.type != "internship")
    if have is None:
        have = 0.0 if profile.status in ("student", "fresher") else float(jobs)
    need = req.years or 0
    if have >= need:
        return "met", f"You have {have:g} years"
    if have + 1 >= need or (need <= 1 and internships):
        return "partial", (f"You have {have:g} years" +
                           (f" plus {internships} internship(s)" if internships else ""))
    return "missing", f"You have {have:g} years; this asks for {need}+"


_POSTGRAD = re.compile(r"\b(master'?s?|m\.?\s?tech|m\.?\s?e\b|mca|mba|m\.?\s?sc|ph\.?\s?d|"
                       r"post[- ]?graduat)", re.I)


def _education_status(req: Requirement, profile: ProfileIn) -> tuple[str, str]:
    if not profile.degree:
        return "missing", "Add your degree in Profile → Current status"
    have = f"Education: {profile.degree} {profile.branch}".strip()
    # A master's/PhD requirement isn't met by a bachelor's degree.
    if _POSTGRAD.search(req.text) and not _POSTGRAD.search(profile.degree) \
            and not re.search(r"\bbachelor", req.text, re.I):
        return "partial", f"You have {profile.degree}; this asks for a postgraduate degree"
    return "met", have


def match_profile(jd_text: str, profile: ProfileIn) -> MatchReport:
    job: JobAnalysis = analyze_jd(jd_text)
    facts = evidence(profile)
    have = known_skills(profile)
    sentences = [text for text, _ in facts]
    matrix = _similarity([r.text for r in job.requirements], sentences)

    results: list[RequirementResult] = []
    for req, row in zip(job.requirements, matrix):
        best = max(range(len(row)), key=row.__getitem__) if row else None
        score = row[best] if best is not None else 0.0
        label = facts[best][1] if best is not None else ""

        if req.kind == "experience":
            status, label = _years_status(req, profile)
            score = CREDIT[status]
        elif req.kind == "education":
            status, label = _education_status(req, profile)
            score = CREDIT[status]
        elif req.kind == "skill" and req.skills:
            covered = [s for s in req.skills if s.lower() in have]
            share = len(covered) / len(req.skills)
            if share == 1:
                status, label, score = "met", "Skills: " + ", ".join(covered), 1.0
            elif covered:
                # Some of the named skills are in the profile.
                status, label, score = "partial", "Skills: " + ", ".join(covered), share
            else:
                # None of the named tools are listed. Only a strong match by
                # meaning counts (e.g. "REST APIs" shown by an internship that
                # built REST APIs); a loose similarity to some other item
                # (Docker vs an AWS certificate) must not earn partial credit.
                status = "met" if score >= MET else "missing"
        else:
            status = _status(score)
        results.append(RequirementResult(
            text=req.text[:300],
            importance=req.importance,
            kind=req.kind,
            status=status,
            score=round(float(score), 2),
            evidence=label if status != "missing" else "",
        ))

    # Overall score: weighted credit over all requirements.
    total = sum(WEIGHT[r.importance] for r in results)
    earned = sum(WEIGHT[r.importance] * CREDIT[r.status] for r in results)
    match_score = round(100 * earned / total) if total else 0

    jd_skills = [(s, "required") for s in job.skills("required")] + \
                [(s, "preferred") for s in job.skills("preferred")
                 if s not in job.skills("required")]
    # A skill also counts as covered when its requirement was met by meaning
    # (e.g. "REST APIs" shown through an internship that built REST APIs).
    shown = {s.lower() for req, res in zip(job.requirements, results)
             if res.status == "met" for s in req.skills}
    matched = [s for s, _ in jd_skills if s.lower() in have or s.lower() in shown]
    missing = [MissingSkill(skill=s, importance=i) for s, i in jd_skills
               if s not in matched]
    coverage = round(100 * len(matched) / len(jd_skills)) if jd_skills else None

    return MatchReport(
        matchScore=match_score,
        skillCoverage=coverage,
        verdict=("strong" if match_score >= 75 else "good" if match_score >= 55
                 else "partial" if match_score >= 35 else "low"),
        job=JobSummary(title=job.title, seniority=job.seniority,
                       yearsRequired=job.years_required, education=job.education),
        requirements=results,
        matchedSkills=matched,
        missingSkills=missing,
        suggestions=_suggestions(results, missing, match_score),
        semantic=semantic_available(),
    )


def _suggestions(results: list[RequirementResult], missing: list[MissingSkill],
                 score: int) -> list[str]:
    out: list[str] = []
    required_missing = [m.skill for m in missing if m.importance == "required"]
    if required_missing:
        out.append(
            f"Required skills not in your profile: {', '.join(required_missing[:6])}. "
            "If you've genuinely used them, add them to Skills and mention the "
            "project or job where you did.")
    preferred_missing = [m.skill for m in missing if m.importance == "preferred"]
    if preferred_missing:
        out.append(f"Nice-to-haves you could learn or highlight: "
                   f"{', '.join(preferred_missing[:6])}.")
    if any(r.kind == "experience" and r.status != "met" for r in results):
        out.append("The role asks for more experience than your profile shows. "
                   "Lead with internships and substantial projects, and describe "
                   "their impact with numbers.")
    partial = [r for r in results if r.status == "partial" and r.kind == "responsibility"]
    if partial:
        out.append("Some requirements are only partly covered — make the matching "
                   "projects' descriptions more specific about what you did.")
    if score < 35:
        out.append("This role is a stretch for your current profile. Consider "
                   "similar roles at a more junior level, or build the missing "
                   "skills first.")
    out.append("Only add skills and experience you genuinely have — interviews "
               "will test them.")
    return out
