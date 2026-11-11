"""Experience and projects: both are lists of entries made of a header
(title / company / role / dates) followed by bullet points."""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from ..models import ExperienceEntry, ProjectEntry
from .common import DATE_RANGE, URL, is_bullet, load_list, nlp, strip_bullet, tidy
from .skills import mentioned_skills

ROLE_WORDS = re.compile(
    r"\b(intern|internship|engineer|developer|analyst|associate|trainee|manager|"
    r"consultant|designer|lead|scientist|executive|specialist|assistant|officer|"
    r"architect|tester|administrator|programmer|researcher|fellow|member|coordinator)\b",
    re.IGNORECASE,
)
COMPANY_WORDS = re.compile(
    r"\b(pvt|private|ltd|limited|inc|llp|llc|technologies|technology|solutions|labs|"
    r"systems|software|services|corp|corporation|company|consultancy|infotech|"
    r"tech|global|india|digital|bank|university|institute)\b",
    re.IGNORECASE,
)
TECH_LINE = re.compile(
    r"^(?:tech(?:nologies|nology)?(?:\s*stack)?|tools(?:\s*used)?|built with|stack|"
    r"skills used)\s*[:\-]\s*(.+)$",
    re.IGNORECASE,
)
DURATION = re.compile(r"\b\d+\s*(?:months?|weeks?|days?)\b", re.IGNORECASE)


@dataclass
class Entry:
    header: list[str] = field(default_factory=list)
    body: list[str] = field(default_factory=list)

    @property
    def text(self) -> str:
        return "\n".join(self.header + self.body)


def split_entries(lines: list[str]) -> list[Entry]:
    """A new entry starts at a non-bullet line that follows bullets.
    Long sentence-like lines without bullets count as description."""
    entries: list[Entry] = []
    for line in lines:
        bullet = is_bullet(line)
        sentence_like = len(line.split()) > 12 or line.rstrip().endswith(".")
        # "Tech: Flutter, Firebase" or a bare link belong to the current entry.
        detail = bool(TECH_LINE.match(line)) or (
            URL.fullmatch(line.strip()) is not None)
        if bullet or ((sentence_like or detail) and entries):
            if not entries:
                entries.append(Entry())
            entries[-1].body.append(strip_bullet(line))
        elif not entries or entries[-1].body or len(entries[-1].header) >= 2:
            entries.append(Entry(header=[line]))
        else:
            entries[-1].header.append(line)
    return [e for e in entries if e.header or e.body]


def _dates(text: str) -> tuple[str, str]:
    m = DATE_RANGE.search(text)
    if not m:
        return "", ""
    end = m.group("end")
    return m.group("start").title(), "Present" if end.lower() in (
        "present", "current", "now", "till date", "ongoing") else end.title()


def _parts(header: str) -> list[str]:
    cleaned = DATE_RANGE.sub(" ", header)
    pieces = re.split(r"\s*\|\s*|\s*,\s*|\s+at\s+|\s+@\s+|\s+[–—-]\s+", cleaned)
    cities = {c.lower() for c in load_list("indian_cities")}
    return [tidy(p) for p in pieces
            if tidy(p) and tidy(p).lower() not in cities and tidy(p).lower() != "remote"]


def _is_org(text: str) -> bool:
    if COMPANY_WORDS.search(text):
        return True
    return any(ent.label_ == "ORG" for ent in nlp()(text).ents)


def parse_experience(lines: list[str]) -> list[ExperienceEntry]:
    results: list[ExperienceEntry] = []
    for entry in split_entries(lines):
        header = " | ".join(entry.header)
        start, end = _dates(entry.text)
        parts = _parts(header)
        role = next((p for p in parts if ROLE_WORDS.search(p)), "")
        others = [p for p in parts if p != role]
        company = next((p for p in others if _is_org(p)), others[0] if others else "")
        if not (role or company):
            continue
        results.append(ExperienceEntry(
            type="internship" if re.search(r"\bintern", header, re.I) else "job",
            company=company,
            role=role,
            start=start,
            end=end,
            description="\n".join(entry.body)[:600],
        ))
    return results


def _tech_stack(entry: Entry, header: str) -> list[str]:
    for line in entry.header + entry.body:
        m = TECH_LINE.match(strip_bullet(line))
        if m:
            return [tidy(t) for t in re.split(r"[,;|/]", m.group(1)) if tidy(t)]
    paren = re.search(r"\(([^)]+)\)", header)
    if paren and "," in paren.group(1):
        return [tidy(t) for t in paren.group(1).split(",") if tidy(t)]
    return mentioned_skills(entry.text)[:8]


def parse_projects(lines: list[str]) -> list[ProjectEntry]:
    results: list[ProjectEntry] = []
    for entry in split_entries(lines):
        header = " ".join(entry.header)
        link_match = URL.search(entry.text)
        start, end = _dates(entry.text)
        length = DURATION.search(entry.text)
        duration = f"{start} – {end}" if start else (length.group(0) if length else "")
        title = header
        title = DATE_RANGE.sub(" ", title)
        title = URL.sub(" ", title)
        title = re.sub(r"\([^)]*\)", " ", title)
        title = tidy(title.split("|")[0])
        if not title:
            continue
        body = [b for b in entry.body
                if not TECH_LINE.match(b) and not URL.fullmatch(b.strip())]
        results.append(ProjectEntry(
            title=title,
            description="\n".join(body)[:600],
            techStack=_tech_stack(entry, header),
            link=link_match.group(0) if link_match else "",
            duration=duration,
        ))
    return results
