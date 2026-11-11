"""Skills: classify listed items into technical / tools / soft / languages,
and find dictionary skills mentioned anywhere (spaCy PhraseMatcher)."""

from __future__ import annotations

import re
from collections import Counter
from functools import lru_cache

from spacy.matcher import PhraseMatcher
from spacy.tokens import Span
from spacy.util import filter_spans

from ..models import Skills
from .common import load_list, nlp, strip_bullet, tidy

CATEGORIES = {
    "technical": "technical_skills",
    "tools": "tools",
    "soft": "soft_skills",
    "languages": "spoken_languages",
}

# Too ambiguous to detect in free text ("go to", "excel at", "C grade").
_AMBIGUOUS = {"c", "r", "go", "excel", "word", "spring", "swift", "rust", "ruby",
              "dart", "unity", "spark", "scrum", "agile", "presentation", "statistics"}


@lru_cache(maxsize=1)
def _canonical() -> dict[str, tuple[str, str]]:
    """lower-case name → (category, display spelling)."""
    table: dict[str, tuple[str, str]] = {}
    for category, file in CATEGORIES.items():
        for name in load_list(file):
            table.setdefault(name.lower(), (category, name))
    return table


@lru_cache(maxsize=1)
def _matcher() -> PhraseMatcher:
    matcher = PhraseMatcher(nlp().vocab, attr="LOWER")
    for name in load_list("technical_skills") + load_list("tools"):
        if name.lower() not in _AMBIGUOUS:
            matcher.add(name, [nlp().make_doc(name)])
    return matcher


def _split_items(line: str) -> tuple[str, list[str]]:
    """'Programming: Java, Python' → ('programming', ['Java', 'Python'])."""
    line = strip_bullet(line)
    prefix = ""
    if ":" in line:
        head, rest = line.split(":", 1)
        if len(head.split()) <= 4:
            prefix, line = head.lower(), rest
    # Don't split on "/" — it appears inside names like CI/CD.
    items = [tidy(i) for i in re.split(r"[,;|•·]|\s{2,}", line)]
    return prefix, [i for i in items if i and len(i.split()) <= 5]


def classify(items_lines: list[str]) -> Skills:
    skills = Skills()
    seen: set[str] = set()
    table = _canonical()
    for line in items_lines:
        prefix, items = _split_items(line)
        for item in items:
            key = item.lower().rstrip(".")
            if key in seen:
                continue
            seen.add(key)
            if key in table:
                category, display = table[key]
            elif "soft" in prefix or "interpersonal" in prefix:
                category, display = "soft", item
            elif "tool" in prefix or "software" in prefix:
                category, display = "tools", item
            elif "spoken" in prefix or prefix.startswith("languages known"):
                category, display = "languages", item
            else:
                category, display = "technical", item
            getattr(skills, category).append(display)
    return skills


def skill_counts(text: str) -> Counter:
    """How many times each dictionary skill/tool occurs in [text].
    Overlapping matches keep the longest ("Data Structures and Algorithms"
    is not also counted as "Data Structures")."""
    doc = nlp().make_doc(text)
    spans = [Span(doc, start, end, label=match_id)
             for match_id, start, end in _matcher()(doc)]
    return Counter(nlp().vocab.strings[s.label] for s in filter_spans(spans))


def mentioned_skills(text: str) -> list[str]:
    """Technical skills and tools named anywhere in [text]."""
    doc = nlp().make_doc(text)
    found: list[str] = []
    for match_id, _, _ in _matcher()(doc):
        name = nlp().vocab.strings[match_id]
        if name not in found:
            found.append(name)
    return found


def parse_skills(
    skill_lines: list[str], language_lines: list[str], full_text: str
) -> tuple[Skills, float, bool]:
    """Returns (skills, confidence, inferred). When there is no skills
    section, skills mentioned elsewhere are used and inferred=True."""
    skills = classify(skill_lines)
    for line in language_lines:
        for item in _split_items(line)[1]:
            word = item.split("(")[0].strip()
            if word and word not in skills.languages:
                skills.languages.append(word)
    if skill_lines:
        return skills, 0.9, False
    table = _canonical()
    for name in mentioned_skills(full_text):
        category = table.get(name.lower(), ("technical", name))[0]
        getattr(skills, category).append(name)
    has_any = bool(skills.technical or skills.tools)
    return skills, 0.4 if has_any else 0.0, has_any
