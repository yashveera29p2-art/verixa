"""Document / text type classification (see package docstring)."""

from __future__ import annotations

import re
from dataclasses import dataclass
from functools import lru_cache

from ..parsing.sections import heading_of
from ..parsing.skills import mentioned_skills as extract_skills

WORD = re.compile(r"[A-Za-z][A-Za-z+#.]*")
EMAIL = re.compile(r"[\w.+-]+@[\w-]+\.[\w.]+")
PHONE = re.compile(r"(?:\+?91[\s-]?)?[6-9]\d{4}[\s-]?\d{5}\b")
PROFILE_LINK = re.compile(r"linkedin\.com|github\.com", re.I)
DATE_RANGE = re.compile(
    r"\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s*'?\d{2,4}"
    r"|\b(?:19|20)\d{2}\s*[-–—to]+\s*(?:(?:19|20)\d{2}|present|current|now)\b", re.I)
EDUCATION = re.compile(
    r"\b(b\.?\s?tech|b\.?\s?e\b|m\.?\s?tech|bachelor|master|mca|bca|b\.?\s?sc|m\.?\s?sc|"
    r"mba|diploma|cgpa|gpa|sgpa|percentage|university|college|institute|"
    r"intermediate|ssc|hsc|cbse|icse|class\s?(x|xii|10|12)|10th|12th)\b", re.I)

# Cue phrases of other kinds of documents, with the name shown to the user.
OTHER_KINDS: dict[str, tuple[str, ...]] = {
    "an invoice or bill": ("invoice", "tax invoice", "gstin", "bill to", "amount due",
                           "subtotal", "grand total", "hsn", "payment terms", "qty"),
    "a certificate": ("this is to certify", "certificate of", "is hereby awarded",
                      "certify that", "in recognition of"),
    "a question paper": ("answer all questions", "answer any", "max marks", "maximum marks",
                         "time allowed", "section a", "question paper", "marks)"),
    "a bank or account statement": ("account statement", "opening balance", "closing balance",
                                    "ifsc", "debit", "credit", "transaction date"),
    "a research paper": ("abstract", "references", "et al", "keywords:", "introduction",
                         "conclusion", "methodology", "doi"),
    "a letter": ("dear sir", "dear madam", "yours sincerely", "yours faithfully",
                 "to whomsoever", "subject:"),
    "a job description": ("we are looking for", "job description", "responsibilities",
                          "what you'll do", "what you will do", "requirements",
                          "qualifications", "about the role", "apply now", "who you are",
                          "you will be", "job type", "ctc"),
}

JD_CUES = ("responsibilit", "requirement", "qualification", "we are looking", "looking for",
           "you will", "you'll", "the role", "about the role", "job description", "job title",
           "must have", "nice to have", "preferred", "experience in", "experience with",
           "years of experience", "knowledge of", "proficien", "candidate", "apply",
           "skills", "eligib", "ctc", "salary", "stipend", "internship", "full-time",
           "full time", "hiring", "join our", "join us", "team", "role", "position", "duties",
           "required", "we offer", "benefits", "location", "work from")
JOB_TITLES = re.compile(
    r"\b(engineer|developer|analyst|intern|internship|designer|manager|associate|"
    r"consultant|scientist|architect|specialist|executive|trainee|lead|tester|"
    r"administrator|officer|programmer|technician)\b", re.I)

ABUSE = {"fuck", "shit", "bitch", "bastard", "asshole", "idiot", "stupid", "chutiya",
         "madarchod", "bhenchod", "behenchod", "gandu", "harami", "saala", "kamina",
         "randi", "porn", "nude", "sex"}
WORK_WORDS = ("work", "team", "manager", "culture", "learn", "salary", "pay", "hike",
              "interview", "round", "hr", "intern", "project", "client", "office", "hours",
              "shift", "leave", "growth", "promotion", "training", "colleague", "boss",
              "management", "layoff", "job", "role", "company", "environment", "balance",
              "experience", "onboard", "stipend", "mentor", "senior", "policy", "benefit")


@dataclass
class Verdict:
    ok: bool
    message: str = ""
    kind: str = ""  # what it looks like, when it was rejected


def _words(text: str) -> list[str]:
    return WORD.findall(text)


def _cues(text: str, cues: tuple[str, ...]) -> int:
    low = text.lower()
    return sum(1 for c in cues if c in low)


# ── Meaning-based check (MiniLM, when available) ───────────────────────────

_PROTOTYPES = {
    "resume": "A candidate's resume or CV listing education, skills, projects, internships, "
              "work experience, certifications, contact details and achievements.",
    "job description": "A job posting describing the role, responsibilities, required skills, "
                       "qualifications, experience, location and how to apply.",
    "an invoice or bill": "An invoice or bill with items, quantities, prices, taxes and a total "
                          "amount to pay.",
    "a certificate": "A certificate stating that a person has completed a course or won an award.",
    "a question paper": "An exam question paper with questions, marks and instructions.",
    "a research paper": "An academic research paper with an abstract, methodology, results and "
                        "references.",
    "an essay or article": "An essay, article or story written in paragraphs about a topic, with an opinion or conclusion.",
    "a letter": "A formal letter addressed to someone with a subject and signature.",
}


@lru_cache(maxsize=1)
def _prototype_vectors():
    from ..matching.matcher import _embed, _model
    model = _model()
    if model is None:
        return None
    names = list(_PROTOTYPES)
    return names, _embed(model, [_PROTOTYPES[n] for n in names])


def _closest_kind(text: str) -> tuple[str, float, float] | None:
    """(closest kind, its similarity, the resume similarity) by meaning."""
    protos = _prototype_vectors()
    if protos is None:
        return None
    from ..matching.matcher import _embed, _model
    names, vectors = protos
    # A representative slice keeps it fast and avoids the 512-token limit.
    sample = " ".join(text.split()[:220])
    v = _embed(_model(), [sample])[0]
    sims = vectors @ v
    best = int(sims.argmax())
    return names[best], float(sims[best]), float(sims[names.index("resume")])


# ── Resume ─────────────────────────────────────────────────────────────────

def is_resume(text: str) -> Verdict:
    """Is an uploaded document a resume / CV?"""
    reject = Verdict(False, "This doesn’t look like a resume. Please upload your resume "
                            "(CV) as a PDF or Word file.")
    words = _words(text)
    if len(words) < 40:
        return Verdict(False, "This file has too little text to be a resume. Please upload "
                              "your full resume (CV) as a PDF or Word file. Scanned images "
                              "of a resume can’t be read; export it as a text PDF.")
    lines = [l.strip() for l in text.splitlines() if l.strip()]
    headings = {h[0] for l in lines if (h := heading_of(l))}
    contact = bool(EMAIL.search(text) or PHONE.search(text) or PROFILE_LINK.search(text))
    education = len(EDUCATION.findall(text))
    dates = len(DATE_RANGE.findall(text))
    skills = len(extract_skills(text)) if len(text) < 60_000 else 10

    # Resume evidence (0–10 points).
    score = (min(len(headings), 4) * 1.5 + (1.5 if contact else 0)
             + min(education, 3) * 0.5 + min(dates, 3) * 0.3 + min(skills, 6) * 0.25)

    # Evidence it's something else.
    other_kind, other_hits = max(((k, _cues(text, c)) for k, c in OTHER_KINDS.items()),
                                 key=lambda kv: kv[1])
    # Job descriptions share words with resumes; "requirements"+"responsibilities"
    # with no contact details is a strong sign.
    if other_kind == "a job description" and contact and len(headings) >= 3:
        other_hits = 0

    meaning = _closest_kind(text)
    if meaning:
        kind, sim, resume_sim = meaning
        if kind != "resume" and sim - resume_sim > 0.08 and score < 6:
            named = _cues(text, OTHER_KINDS.get(kind, ())) >= 2 or kind == "job description"
            return Verdict(False, _wrong_kind(kind) if named else reject.message, kind)
        if kind == "resume":
            score += 1.5

    if other_hits >= 3 and score < 6:
        return Verdict(False, _wrong_kind(other_kind), other_kind)
    if len(words) > 6000 and len(headings) < 3:
        reject.kind = "a long document"
        reject.message = ("This document is too long to be a resume. Please upload your "
                          "resume (CV), usually 1–2 pages.")
        return reject
    if score >= 4.5 and (headings or contact):
        return Verdict(True)
    return reject


def _wrong_kind(kind: str) -> str:
    if kind == "job description" or kind == "a job description":
        return ("This looks like a job description, not a resume. Please upload your own "
                "resume (CV). To compare with a job, use “Match a job”.")
    return (f"This looks like {kind}, not a resume. Please upload your resume (CV) as a "
            "PDF or Word file.")


# ── Job description ────────────────────────────────────────────────────────

STRONG_JD_CUES = ("responsibilit", "requirement", "required", "qualification",
                  "we are looking", "looking for", "you will", "you'll", "about the role",
                  "job description", "must have", "nice to have", "preferred",
                  "years of experience", "apply", "we offer", "join our", "join us",
                  "eligib", "duties", "hiring", "ctc", "stipend", "what you'll do",
                  "who you are", "the ideal candidate", "candidates")


def is_job_description(text: str) -> Verdict:
    """Is pasted text a job description?"""
    words = _words(text)
    if len(words) < 15:
        return Verdict(False, "That’s too short for a job description. Paste the full "
                              "posting: job title, responsibilities, required skills and "
                              "experience.")
    low = text.lower()
    strong = _cues(low, STRONG_JD_CUES)
    cues = _cues(low, JD_CUES)
    titles = len(JOB_TITLES.findall(text))
    skills = len(extract_skills(text)) if len(text) < 40_000 else 10

    # A resume pasted by mistake: resume sections plus contact details or
    # first-person writing, and few real job-posting phrases.
    contact = bool(EMAIL.search(text) or PHONE.search(text))
    resume_headings = {h[0] for l in text.splitlines() if (h := heading_of(l.strip()))}
    first_person = len(re.findall(r"\b(i|my|me)\b", low))
    if ((contact and len(resume_headings) >= 2) or first_person >= 6) and strong < 3:
        return Verdict(False, "This looks like a resume, not a job description. Paste the "
                              "job posting you want to compare your profile with.", "resume")

    # Clear job-posting structure: a role or skills plus posting phrases.
    if strong >= 2 and (titles or skills >= 2):
        return Verdict(True)
    if strong >= 1 and (titles or skills >= 3):
        return Verdict(True)

    meaning = _closest_kind(text)
    if meaning:
        kind, _, _ = meaning
        if kind == "job description" and (titles or skills >= 2):
            return Verdict(True)
        if kind not in ("job description", "resume") and _cues(low, OTHER_KINDS.get(kind, ())) >= 2:
            return Verdict(False, f"This looks like {kind}, not a job description. Paste "
                                  "the job posting: title, responsibilities and requirements.",
                           kind)
    elif cues >= 3 and (titles or skills >= 2):
        return Verdict(True)
    return Verdict(False, "This doesn’t look like a job description. Paste the full job "
                          "posting: job title, responsibilities, required skills, "
                          "experience and education.")


def is_requirements(text: str) -> Verdict:
    """Looser check for a recruiter's typed requirements in Find talent."""
    if len(_words(text)) < 4:
        return Verdict(False, "Describe the role or skills you need, e.g. “Backend intern: "
                              "Python, REST APIs, SQL”.")
    if extract_skills(text) or JOB_TITLES.search(text) or _cues(text, JD_CUES) >= 2:
        return Verdict(True)
    return Verdict(False, "Please describe a role or the skills you need, e.g. “Backend "
                          "intern: Python, REST APIs, SQL”.")


# ── Reviews ────────────────────────────────────────────────────────────────

def review_problem(text: str) -> Verdict:
    """A review must be about working / interviewing there and not abusive."""
    t = text.strip()
    if not t:
        return Verdict(True)  # ratings only are fine
    low = t.lower()
    tokens = set(re.findall(r"[a-z]+", low))
    if tokens & ABUSE:
        return Verdict(False, "Please keep reviews respectful: remove abusive or offensive "
                              "words.", "abusive")
    if re.search(r"https?://|www\.|\b\d{10}\b|@\w+\.\w+", low):
        return Verdict(False, "Reviews can’t contain links, phone numbers or email addresses.",
                       "spam")
    words = _words(t)
    if len(words) >= 3 and len(set(w.lower() for w in words)) <= max(2, len(words) // 5):
        return Verdict(False, "This review repeats the same words. Please describe your "
                              "experience at the company.", "spam")
    if len(words) >= 6 and not any(w in low for w in WORK_WORDS):
        return Verdict(False, "Please write about working, interning or interviewing at "
                              "this company (culture, learning, pay, hours, interview…).",
                       "irrelevant")
    return Verdict(True)
