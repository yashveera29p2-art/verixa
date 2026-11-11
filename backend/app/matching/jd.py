"""Reads a job description: requirements, skills, years, education, level."""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from ..parsing.common import is_bullet, strip_bullet
from ..parsing.skills import skill_counts

# Section headings in job descriptions → what their bullets mean.
_REQUIRED_HEADINGS = re.compile(
    r"^(requirements?|qualifications?|minimum qualifications|basic qualifications|"
    r"must[- ]haves?|what we(?:'re| are) looking for|what you(?:'ll)? need|"
    r"who you are|skills( required)?|required skills|key skills|eligibility|"
    r"you (?:should|will) have|technical skills)\b", re.I)
_PREFERRED_HEADINGS = re.compile(
    r"^(nice[- ]to[- ]haves?|preferred( qualifications| skills)?|good[- ]to[- ]haves?|"
    r"bonus( points)?|pluses|additional skills|desired skills|it'?s a plus)\b", re.I)
_RESPONSIBILITY_HEADINGS = re.compile(
    r"^(responsibilities|key responsibilities|what you(?:'ll)? do|the role|"
    r"role (?:and|&) responsibilities|your role|job description|about the role|"
    r"day[- ]to[- ]day|duties)\b", re.I)
_IGNORED_HEADINGS = re.compile(
    r"^(about (?:us|the company)|benefits|perks|why join us|what we offer|"
    r"compensation|salary|how to apply|equal opportunity)\b", re.I)

_PREFERRED_HINT = re.compile(r"\b(preferred|nice to have|good to have|a plus|bonus|"
                             r"desirable|advantage|optional)\b", re.I)
YEARS = re.compile(r"(\d{1,2})\s*(?:\+|plus)?\s*(?:(?:-|–|to)\s*(\d{1,2})\s*)?"
                   r"(?:years?|yrs?)\b", re.I)
EDUCATION = re.compile(
    r"\b(b\.?\s?tech|b\.?\s?e\b|bachelor'?s?|be/b\.?tech|m\.?\s?tech|master'?s?|mca|bca|"
    r"b\.?\s?sc|m\.?\s?sc|mba|ph\.?\s?d|degree|graduate|graduation|diploma)\b", re.I)
_LEVELS = [
    (re.compile(r"\b(intern(ship)?)\b", re.I), "Internship"),
    (re.compile(r"\b(fresher|fresh graduate|entry[- ]level|graduate trainee|trainee)\b", re.I),
     "Entry level"),
    (re.compile(r"\b(junior|associate)\b", re.I), "Junior"),
    (re.compile(r"\b(senior|sr\.?)\b", re.I), "Senior"),
    (re.compile(r"\b(lead|principal|staff|architect|manager|head of)\b", re.I), "Lead"),
]
_ROLE_WORDS = re.compile(r"\b(engineer|developer|analyst|intern|designer|scientist|"
                         r"manager|consultant|architect|specialist|associate|"
                         r"administrator|tester|lead|executive)\b", re.I)


@dataclass
class Requirement:
    text: str
    importance: str  # "required" | "preferred"
    kind: str  # "skill" | "experience" | "education" | "responsibility"
    skills: list[str] = field(default_factory=list)
    years: int | None = None


@dataclass
class JobAnalysis:
    title: str = ""
    seniority: str = ""
    years_required: int | None = None
    education: str = ""
    requirements: list[Requirement] = field(default_factory=list)

    def skills(self, importance: str) -> list[str]:
        out: list[str] = []
        for r in self.requirements:
            if r.importance == importance:
                out += [s for s in r.skills if s not in out]
        return out


def _heading(line: str) -> str | None:
    text = re.sub(r"^[^a-zA-Z]+", "", line).strip().rstrip(":").strip()
    if len(text.split()) > 7:
        return None
    for pattern, kind in ((_PREFERRED_HEADINGS, "preferred"),
                          (_REQUIRED_HEADINGS, "required"),
                          (_RESPONSIBILITY_HEADINGS, "responsibility"),
                          (_IGNORED_HEADINGS, "ignore")):
        if pattern.match(text):
            return kind
    return None


# "Requirements: Java…" / "Nice to have: Docker…" written inline.
_INLINE_LABEL = re.compile(
    r"^(requirements?|qualifications?|must[- ]haves?|skills|responsibilities|"
    r"nice[- ]to[- ]haves?|good[- ]to[- ]haves?|preferred|bonus)\s*:\s*", re.I)


def _items(lines: list[str]) -> list[str]:
    """Bullets stay as-is; paragraphs are split into sentences. Inline
    labels are removed from the text (their meaning is kept by the
    preferred-hint check before removal)."""
    items: list[str] = []
    for line in lines:
        if is_bullet(line):
            items.append(strip_bullet(line))
        else:
            items += [s.strip() for s in re.split(r"(?<=[.!?;])\s+", line) if s.strip()]
    return [i for i in items if len(i.split()) >= 2]


def _strip_label(item: str) -> str:
    return _INLINE_LABEL.sub("", item, count=1).strip() or item


def _classify(text: str, importance: str) -> Requirement:
    years = YEARS.search(text)
    skills = list(skill_counts(text))
    if years and re.search(r"experience|exp\b|working", text, re.I):
        return Requirement(text, importance, "experience", skills, int(years.group(1)))
    if EDUCATION.search(text) and not skills:
        return Requirement(text, importance, "education")
    if skills:
        return Requirement(text, importance, "skill", skills)
    return Requirement(text, importance, "responsibility")


def _title(lines: list[str]) -> str:
    for line in lines[:4]:
        if len(line.split()) <= 8 and _ROLE_WORDS.search(line) and not _heading(line):
            return re.sub(r"^(job title|role|position)\s*[:\-]\s*", "", line, flags=re.I).strip()
    m = re.search(r"(?:hiring|looking for|seeking)\s+(?:an?\s+)?([A-Z][\w/+ .-]{2,40}?"
                  r"(?:engineer|developer|analyst|intern|designer|scientist))", " ".join(lines))
    return m.group(1).strip() if m else ""


def analyze_jd(text: str) -> JobAnalysis:
    lines = [" ".join(l.split()) for l in text.splitlines() if l.strip()]
    job = JobAnalysis(title=_title(lines))

    # Group lines by the section they're under.
    groups: list[tuple[str, list[str]]] = [("unknown", [])]
    for line in lines:
        kind = _heading(line)
        if kind:
            groups.append((kind, []))
        else:
            groups[-1][1].append(line)

    has_sections = any(kind in ("required", "preferred") for kind, _ in groups)
    for kind, body in groups:
        if kind == "ignore" or not body:
            continue
        for item in _items(body):
            if item == job.title:
                continue
            importance = "preferred" if kind == "preferred" or _PREFERRED_HINT.search(item) \
                else "required"
            req = _classify(_strip_label(item), importance)
            # Responsibilities only count when they name skills; generic
            # duties ("collaborate with the team") aren't matchable needs.
            if kind in ("responsibility", "unknown") and req.kind == "responsibility":
                if has_sections or len(item.split()) < 6:
                    continue
            job.requirements.append(req)

    # Years, education and level, from anywhere in the text.
    all_years = [int(m.group(1)) for m in YEARS.finditer(text)
                 if re.search(r"experience", text[m.end():m.end() + 40], re.I)
                 or re.search(r"experience", text[max(0, m.start() - 40):m.start()], re.I)]
    job.years_required = min(all_years) if all_years else None
    edu = next((r.text for r in job.requirements if r.kind == "education"), "")
    if not edu:
        m = EDUCATION.search(text)
        edu = m.group(0) if m else ""
    job.education = edu[:120]
    for pattern, level in _LEVELS:
        if pattern.search(job.title or "") or (not job.title and pattern.search(text[:300])):
            job.seniority = level
            break
    if not job.seniority and job.years_required is not None:
        y = job.years_required
        job.seniority = "Entry level" if y == 0 else "Junior" if y <= 2 else \
            "Mid level" if y <= 5 else "Senior"
    # De-duplicate identical requirement texts.
    seen: set[str] = set()
    job.requirements = [r for r in job.requirements
                        if not (r.text.lower() in seen or seen.add(r.text.lower()))]
    return job
