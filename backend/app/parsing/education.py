"""Education: 10th, 12th, the main degree, and any diploma / PG."""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from ..models import Degree, Education, HigherQualification, SchoolRecord
from .common import DATE_RANGE, YEAR, strip_bullet, tidy

CLASS12 = re.compile(
    r"\b(12th|xii(?:th)?|class\s*(?:xii|12)|hsc|intermediate|higher secondary|"
    r"senior secondary|puc|pre-university)\b",
    re.IGNORECASE,
)
CLASS10 = re.compile(
    r"\b(10th|x(?:th)?\s+(?:class|standard|std)|class\s*(?:x|10)|ssc|sslc|"
    r"matriculation|secondary school certificate)\b",
    re.IGNORECASE,
)

# (pattern, display name, is_bachelor)
DEGREES: list[tuple[re.Pattern, str, bool]] = [
    (re.compile(r"\bb\.?\s?tech\b", re.I), "B.Tech", True),
    (re.compile(r"\bb\.\s?e\.?(?=\s|$|,)|\bbachelor of engineering\b", re.I), "B.E.", True),
    (re.compile(r"\bm\.?\s?tech\b", re.I), "M.Tech", False),
    (re.compile(r"\bm\.\s?e\.?(?=\s|$|,)|\bmaster of engineering\b", re.I), "M.E.", False),
    (re.compile(r"\bbca\b", re.I), "BCA", True),
    (re.compile(r"\bmca\b", re.I), "MCA", False),
    (re.compile(r"\bb\.?\s?sc\b", re.I), "B.Sc", True),
    (re.compile(r"\bm\.?\s?sc\b", re.I), "M.Sc", False),
    (re.compile(r"\bb\.?\s?com\b", re.I), "B.Com", True),
    (re.compile(r"\bm\.?\s?com\b", re.I), "M.Com", False),
    (re.compile(r"\bbba\b", re.I), "BBA", True),
    (re.compile(r"\bmba\b|\bpgdm\b", re.I), "MBA", False),
    (re.compile(r"\bb\.?\s?arch\b", re.I), "B.Arch", True),
    (re.compile(r"\bb\.?\s?pharm\b", re.I), "B.Pharm", True),
    (re.compile(r"\bph\.?\s?d\b", re.I), "PhD", False),
    (re.compile(r"\bdiploma\b|\bpolytechnic\b", re.I), "Diploma", False),
    (re.compile(r"\bbachelor(?:'s)? of [a-z]+(?: [a-z]+)?", re.I), "", True),
    (re.compile(r"\bmaster(?:'s)? of [a-z]+(?: [a-z]+)?", re.I), "", False),
]

BRANCHES: list[tuple[re.Pattern, str]] = [
    (re.compile(r"artificial intelligence (?:and|&) machine learning|\bai\s*&?\s*ml\b|\baiml\b", re.I), "AI & ML"),
    (re.compile(r"\bdata science\b", re.I), "Data Science"),
    (re.compile(r"computer science(?: (?:and|&) engineering)?|\bcse\b", re.I), "CSE"),
    (re.compile(r"information technology|\bi\.?t\.?\b(?=\s*[),|]|$)", re.I), "IT"),
    (re.compile(r"electronics (?:and|&) communication|\bece\b", re.I), "ECE"),
    (re.compile(r"electrical (?:and|&) electronics|\beee\b", re.I), "EEE"),
    (re.compile(r"mechanical|\bmech\b", re.I), "Mechanical"),
    (re.compile(r"\bcivil\b", re.I), "Civil"),
    (re.compile(r"\bchemical\b", re.I), "Chemical"),
    (re.compile(r"biotechnology", re.I), "Biotechnology"),
]

INSTITUTION = re.compile(
    r"\b(college|university|institute|school|vidyalaya|vidyalayam|academy|"
    r"polytechnic|iit|nit|iiit|bits|jntu\w*|vit|srm|kendriya|campus)\b",
    re.IGNORECASE,
)
BOARD = re.compile(
    r"\b(cbse|icse|isc|igcse|nios|bseap|bieap|tsbie|bie|bse|"
    r"state board|board of (?:secondary|intermediate|school)[a-z ]*)\b",
    re.IGNORECASE,
)
CGPA = [
    re.compile(r"(?:cgpa|gpa|cpi|sgpa)\s*[:\-]?\s*(\d{1,2}(?:\.\d{1,2})?)(?:\s*/\s*10)?", re.I),
    re.compile(r"(\d{1,2}\.\d{1,2})\s*(?:/\s*10(?:\.0)?)?\s*(?:cgpa|gpa|cpi)", re.I),
]
PERCENT = re.compile(
    r"(?:percentage|marks|score)?\s*[:\-]?\s*(\d{2,3}(?:\.\d{1,2})?)\s*(?:%|percent)", re.I
)


@dataclass
class _Entry:
    kind: str  # "class10", "class12", "degree", "unknown"
    lines: list[str] = field(default_factory=list)
    degree_name: str = ""
    is_bachelor: bool = False

    @property
    def text(self) -> str:
        return " | ".join(self.lines)


def _classify(line: str) -> tuple[str, str, bool] | None:
    if CLASS12.search(line):
        return "class12", "", False
    if CLASS10.search(line):
        return "class10", "", False
    for pattern, name, bachelor in DEGREES:
        m = pattern.search(line)
        if m:
            return "degree", name or m.group(0).title(), bachelor
    return None


def _group(lines: list[str]) -> list[_Entry]:
    entries: list[_Entry] = []
    for raw in lines:
        line = strip_bullet(raw)
        hit = _classify(line)
        if hit:
            kind, name, bachelor = hit
            entries.append(_Entry(kind, [line], name, bachelor))
        elif entries:
            entries[-1].lines.append(line)
        else:
            entries.append(_Entry("unknown", [line]))
    return entries


def _score(text: str) -> str:
    for pattern in CGPA:
        m = pattern.search(text)
        if m and 0 < float(m.group(1)) <= 10:
            return m.group(1)
    m = PERCENT.search(text)
    if m and 30 <= float(m.group(1)) <= 100:
        return f"{m.group(1)}%"
    return ""


def _year(text: str) -> str:
    years = YEAR.findall(text)
    return years[-1] if years else ""


def _board(text: str) -> str:
    m = BOARD.search(text)
    if not m:
        return ""
    board = m.group(1)
    return board.upper() if len(board) <= 6 else board.title()


def _institution(entry: _Entry) -> str:
    """The part of the entry that names the school/college."""
    parts = [p for line in entry.lines for p in re.split(r"\s*[|,–—]\s*|\s+-\s+", line)]
    for part in parts:
        if INSTITUTION.search(part):
            cleaned = DATE_RANGE.sub("", part)
            cleaned = YEAR.sub("", cleaned)
            cleaned = re.sub(r"\(?\s*\d{1,3}(?:\.\d+)?\s*%\s*\)?", "", cleaned)
            return tidy(cleaned)
    return ""


def _branch(text: str) -> str:
    for pattern, name in BRANCHES:
        if pattern.search(text):
            return name
    return ""


def parse_education(lines: list[str]) -> tuple[Education, float]:
    entries = _group(lines)
    edu = Education()
    degrees = [e for e in entries if e.kind == "degree"]
    main = next((e for e in degrees if e.is_bachelor), degrees[0] if degrees else None)

    for entry in entries:
        if entry.kind in ("class10", "class12"):
            record = SchoolRecord(
                board=_board(entry.text),
                school=_institution(entry),
                score=_score(entry.text),
                year=_year(entry.text),
            )
            setattr(edu, entry.kind, record)
        elif entry is main:
            edu.degree = Degree(
                college=_institution(entry),
                degree=entry.degree_name,
                branch=_branch(entry.text),
                cgpa=_score(entry.text).rstrip("%") if "%" not in _score(entry.text) else "",
                graduationYear=_year(entry.text),
            )
        elif entry.kind == "degree":
            edu.additional.append(HigherQualification(
                qualification=tidy(f"{entry.degree_name} {_branch(entry.text)}"),
                institution=_institution(entry),
                score=_score(entry.text),
                year=_year(entry.text),
            ))

    filled = sum(bool(x) for x in (
        edu.degree.degree, edu.degree.college, edu.class10.year, edu.class12.year,
    ))
    return edu, round(filled / 4, 2) if entries else 0.0
