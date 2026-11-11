"""Shared regexes, word lists and the spaCy model."""

from __future__ import annotations

import re
from functools import lru_cache
from pathlib import Path

import spacy
from spacy.language import Language

DATA_DIR = Path(__file__).parent / "data"

MONTH = r"(?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?"
DATE = rf"(?:{MONTH}\s*'?\d{{2,4}}|\d{{1,2}}/\d{{4}}|(?:19|20)\d{{2}})"
DATE_END = rf"(?:{DATE}|present|current|now|till date|ongoing)"

# "Jun 2024 – Aug 2024", "2021 - Present", "06/2023 to 12/2023"
DATE_RANGE = re.compile(
    rf"(?P<start>{DATE})\s*(?:-|–|—|to|till)\s*(?P<end>{DATE_END})", re.IGNORECASE
)
YEAR = re.compile(r"\b(19[89]\d|20[0-4]\d)\b")
EMAIL = re.compile(r"[\w.+-]+@[\w-]+(?:\.[\w-]+)+")
# Common TLDs only, so "Node.js" isn't a link. The first label must be at
# least 2 characters and can't start mid-word, so degrees like "B.Tech" or
# "M.Tech" (single-letter label + .tech) aren't links either.
URL = re.compile(
    r"(?<![\w.@-])(?:https?://)?(?:www\.)?[a-z0-9][a-z0-9-]+(?:\.[a-z0-9-]+)*"
    r"\.(?:com|in|io|dev|org|net|me|app|co|ai|tech|site|page|xyz)\b(?:/[^\s,;|)]*)?",
    re.IGNORECASE,
)
BULLET = re.compile(r"^\s*(?:[•●▪◦‣∙·*➢►✓▸-]|–|\d{1,2}[.)])\s*")


def strip_bullet(line: str) -> str:
    return BULLET.sub("", line, count=1).strip()


def is_bullet(line: str) -> bool:
    return bool(BULLET.match(line)) and len(strip_bullet(line)) > 0


@lru_cache(maxsize=None)
def load_list(name: str) -> tuple[str, ...]:
    """Reads a word list from data/, skipping blanks and # comments."""
    lines = (DATA_DIR / f"{name}.txt").read_text(encoding="utf-8").splitlines()
    return tuple(l.strip() for l in lines if l.strip() and not l.startswith("#"))


@lru_cache(maxsize=1)
def nlp() -> Language:
    """The spaCy English model, loaded once per process."""
    return spacy.load("en_core_web_sm", disable=["parser", "lemmatizer"])


def tidy(text: str) -> str:
    """Collapses spaces and trims separators left over after removals.
    Brackets are trimmed only when unbalanced, so "AWS (2025)" survives."""
    text = re.sub(r"\s+", " ", text).strip(" ,;|-–—:")
    while text.endswith(")") and text.count(")") > text.count("("):
        text = text[:-1].rstrip(" ,;|-–—:")
    while text.startswith("(") and text.count("(") > text.count(")"):
        text = text[1:].lstrip(" ,;|-–—:")
    return text.strip()
