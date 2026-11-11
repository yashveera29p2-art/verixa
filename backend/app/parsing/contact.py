"""Name, email, phone, city and profile links."""

from __future__ import annotations

import re

from ..models import Contact
from .common import EMAIL, URL, load_list, nlp
from .sections import heading_of

# Indian mobile numbers: optional +91 / 0 prefix, 10 digits starting 6–9.
PHONE = re.compile(r"(?<!\d)(?:\+?91[\s-]*|0)?([6-9]\d{4})[\s-]?(\d{5})(?!\d)")


def find_phone(text: str) -> str:
    m = PHONE.search(text)
    return f"+91{m.group(1)}{m.group(2)}" if m else ""


def find_links(text: str) -> tuple[str, str, str]:
    """Returns (linkedin, github, portfolio)."""
    linkedin = github = portfolio = ""
    emails = set(EMAIL.findall(text))
    for match in URL.finditer(text):
        url = match.group(0).rstrip(".")
        # Skip the domain part of an email address.
        if any(url in e for e in emails):
            continue
        low = url.lower()
        if "linkedin.com" in low:
            linkedin = linkedin or url
        elif "github.com" in low:
            github = github or url
        elif not portfolio:
            portfolio = url
    return linkedin, github, portfolio


def _looks_like_name(line: str) -> bool:
    if any(ch.isdigit() for ch in line) or "@" in line or URL.search(line):
        return False
    if heading_of(line):
        return False
    words = line.replace(".", " ").split()
    return 2 <= len(words) <= 4 and all(re.fullmatch(r"[A-Za-z'’-]+", w) for w in words)


def find_name(header: list[str]) -> tuple[str, float]:
    """The first plausible name line near the top. spaCy NER raises
    confidence when it agrees the line is a PERSON."""
    for line in header[:6]:
        candidate = line.split("|")[0].strip()
        if _looks_like_name(candidate):
            name = candidate.title() if candidate.isupper() else candidate
            doc = nlp()(name)
            is_person = any(ent.label_ == "PERSON" for ent in doc.ents)
            return name, 0.95 if is_person else 0.7
    return "", 0.0


def find_city(lines: list[str]) -> str:
    text = " ".join(lines)
    for city in load_list("indian_cities"):
        if re.search(rf"\b{re.escape(city)}\b", text, re.IGNORECASE):
            return city
    return ""


def parse_contact(header: list[str], all_lines: list[str]) -> tuple[Contact, float]:
    text = "\n".join(all_lines)
    top = header if header else all_lines[:8]
    name, name_conf = find_name(top)
    email_match = EMAIL.search(text)
    linkedin, github, portfolio = find_links(text)
    contact = Contact(
        fullName=name,
        email=email_match.group(0) if email_match else "",
        phone=find_phone(text),
        city=find_city(top[:10]),
        linkedin=linkedin,
        github=github,
        portfolio=portfolio,
    )
    # Confidence: name, email and phone matter most.
    found = [name_conf, 1.0 if contact.email else 0.0, 1.0 if contact.phone else 0.0]
    return contact, round(sum(found) / 3, 2)
