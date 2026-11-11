"""Detectors for resume manipulation techniques.

Each detector looks at the extracted document and returns Threats.
They are deliberately rule-based and explainable: every threat says which
technique was used, quotes the evidence, and says where it is.
"""

from __future__ import annotations

import re
import unicodedata
from collections import Counter

from ..extraction import ExtractedDocument, HiddenSpan
from ..models import Threat, ThreatLocation
from ..parsing.sections import heading_of
from ..parsing.skills import skill_counts

EVIDENCE_LIMIT = 160
MAX_PER_TECHNIQUE = 10


def _quote(text: str) -> str:
    text = " ".join(text.split())
    return text if len(text) <= EVIDENCE_LIMIT else text[: EVIDENCE_LIMIT - 1] + "…"


def section_map(lines: list[str]) -> list[str | None]:
    """The section each line belongs to (None before the first heading)."""
    current: str | None = None
    out: list[str | None] = []
    for line in lines:
        hit = heading_of(line)
        if hit:
            current = hit[0]
        out.append(current)
    return out


# ── 1. Hidden text ─────────────────────────────────────────────────────────

_HIDDEN_TITLES = {
    "white": ("White or invisible-coloured text",
              "Text coloured to match the page background, so readers can't "
              "see it but ATS software still reads it."),
    "tiny": ("Microscopic text",
             "Text in a font too small to read (under 4 pt) that ATS software "
             "still picks up."),
    "offpage": ("Text placed outside the page",
                "Text positioned beyond the visible page edges, where only "
                "software can read it."),
    "hidden-format": ("Text marked as hidden",
                      "Text using Word's 'hidden' formatting, invisible when "
                      "viewed or printed but present in the file."),
}


def _merge_spans(spans: list[HiddenSpan]) -> list[HiddenSpan]:
    """Joins neighbouring spans with the same reason and page."""
    merged: list[HiddenSpan] = []
    for span in spans:
        last = merged[-1] if merged else None
        if last and last.reason == span.reason and last.page == span.page and (
                span.paragraph is None or last.paragraph is None
                or span.paragraph - last.paragraph <= 1):
            last.text = f"{last.text} {span.text}"
            last.paragraph = span.paragraph or last.paragraph
        else:
            merged.append(HiddenSpan(span.text, span.reason, span.page, span.paragraph))
    return merged


def detect_hidden_text(doc: ExtractedDocument) -> list[Threat]:
    threats: list[Threat] = []
    for i, span in enumerate(_merge_spans(doc.hidden_spans)):
        text = span.text.strip()
        if len(text) < 3:
            continue
        keywords = sum(skill_counts(text).values())
        injected = bool(find_injections(text))
        severity = ("high" if keywords >= 3 or injected or len(text) > 80
                    else "medium" if len(text) > 20 else "low")
        title, description = _HIDDEN_TITLES.get(span.reason, _HIDDEN_TITLES["white"])
        if keywords >= 3:
            description += f" It contains {keywords} skill keywords — a classic "\
                           "way to game ATS keyword matching."
        threats.append(Threat(
            id=f"hidden-{i + 1}",
            technique="hidden_text",
            severity=severity,
            title=title,
            description=description,
            evidence=_quote(text),
            location=ThreatLocation(page=span.page, line=None,
                                    section=None),
            hidden=True,
        ))
    return threats[:MAX_PER_TECHNIQUE]


# ── 2. Prompt injection ────────────────────────────────────────────────────

# Phrases written to instruct an AI screener rather than inform a human.
_INJECTION_PATTERNS: list[tuple[re.Pattern, str]] = [
    (re.compile(r"\b(ignore|disregard|forget|override)\b.{0,40}\b(previous|prior|above|all|earlier|preceding|other)\b"
                r".{0,40}\b(instructions?|prompts?|rules|directions|guidelines|criteria)\b", re.I),
     "Tells the AI to ignore its instructions"),
    (re.compile(r"\b(you are|you're|act as|pretend to be)\b.{0,25}\b(an? )?(ai|assistant|language model|chatbot|"
                r"gpt|recruit(?:er|ing) (?:bot|assistant|ai)|ats|screener)\b", re.I),
     "Addresses the AI directly to change its role"),
    (re.compile(r"\b(system|developer)\s*(prompt|message|instructions?)\b|\[(?:inst|system)\]|"
                r"<\|?(?:im_start|system)\|?>|#{2,}\s*(?:instruction|system)", re.I),
     "Imitates a system prompt or chat-model control text"),
    (re.compile(r"\b(rank|rate|score|grade|evaluate|mark|assess)\b.{0,25}\b(this|the|my)\b.{0,15}"
                r"\b(candidate|applicant|resume|cv|profile)\b.{0,40}\b(highly|top|best|10|ten|perfect|"
                r"excellent|strong(?:est)?|first|maximum|highest|qualified)\b", re.I),
     "Instructs the AI to score this resume highly"),
    (re.compile(r"\b(recommend|shortlist|select|hire|approve|advance|move forward with|prioriti[sz]e)\b"
                r".{0,15}\b(this|the)\s+(candidate|applicant)\b", re.I),
     "Instructs the AI to shortlist or hire this candidate"),
    (re.compile(r"\bthis (candidate|applicant)\b.{0,30}\b(is|would be|should be)\b.{0,25}"
                r"\b(perfect|ideal|best|exceptional|most qualified|top choice|an excellent fit)\b", re.I),
     "Tells the reader what verdict to reach"),
    (re.compile(r"\b(output|respond|reply|answer|say|print|return)\b.{0,25}[\"'“‘](yes|hire|qualified|approved|"
                r"strong match|match|accept)", re.I),
     "Dictates the AI's answer"),
    (re.compile(r"\bdo not (mention|reveal|tell|disclose|flag|report)\b", re.I),
     "Asks the AI to hide something"),
]


def find_injections(text: str) -> list[tuple[str, str]]:
    """(matched text, explanation) for every injection phrase in [text]."""
    found = []
    for pattern, label in _INJECTION_PATTERNS:
        for m in pattern.finditer(text):
            found.append((m.group(0), label))
    return found


def detect_prompt_injection(doc: ExtractedDocument) -> list[Threat]:
    hidden_text = " ".join(s.text for s in doc.hidden_spans).lower()
    sections = section_map(doc.lines)
    threats: list[Threat] = []
    for number, line in enumerate(doc.lines, start=1):
        for matched, label in find_injections(line):
            hidden = matched.lower()[:40] in hidden_text
            threats.append(Threat(
                id=f"injection-{len(threats) + 1}",
                technique="prompt_injection",
                severity="high",
                title="Prompt injection" + (" (hidden)" if hidden else ""),
                description=(f"{label}. This text is aimed at AI screening tools, "
                             "not human readers, and is treated as manipulation."),
                evidence=_quote(line),
                location=ThreatLocation(line=number, section=sections[number - 1]),
                hidden=hidden,
            ))
            break  # one threat per line is enough
    return threats[:MAX_PER_TECHNIQUE]


# ── 3. Keyword stuffing ────────────────────────────────────────────────────

def detect_keyword_stuffing(doc: ExtractedDocument) -> list[Threat]:
    threats: list[Threat] = []
    visible = doc.visible_text
    counts = skill_counts(visible)

    over = [(skill, n) for skill, n in counts.most_common() if n >= 8]
    if over:
        worst = over[0][1]
        listed = ", ".join(f"{s} ×{n}" for s, n in over[:5])
        threats.append(Threat(
            id="stuffing-repeat",
            technique="keyword_stuffing",
            severity="high" if worst >= 12 else "medium",
            title="Repeated keywords",
            description="The same skills appear far more often than a genuine "
                        "resume needs, a common trick to inflate ATS match scores.",
            evidence=listed,
        ))

    sections = section_map(doc.visible_lines)
    for number, line in enumerate(doc.visible_lines, start=1):
        items = [i for i in re.split(r"[,|;•·]", line) if i.strip()]
        if len(items) >= 25 and all(len(i.split()) <= 3 for i in items):
            threats.append(Threat(
                id=f"stuffing-list-{number}",
                technique="keyword_stuffing",
                severity="medium",
                title="Keyword dump",
                description=f"A single line lists {len(items)} keywords. Long "
                            "unstructured keyword lists look like ATS gaming.",
                evidence=_quote(line),
                location=ThreatLocation(line=number, section=sections[number - 1]),
            ))

    normalised = [" ".join(l.lower().split()) for l in doc.visible_lines]
    repeated = [(l, n) for l, n in Counter(normalised).items()
                if n >= 3 and len(l.split()) >= 3]
    for line, n in repeated[:3]:
        threats.append(Threat(
            id=f"stuffing-dup-{len(threats) + 1}",
            technique="keyword_stuffing",
            severity="medium",
            title="Duplicated lines",
            description=f"The same line appears {n} times.",
            evidence=_quote(line),
        ))

    words = len(visible.split())
    mentions = sum(counts.values())
    if words >= 80 and mentions / words > 0.35:
        threats.append(Threat(
            id="stuffing-density",
            technique="keyword_stuffing",
            severity="medium",
            title="Very high keyword density",
            description=f"{round(100 * mentions / words)}% of all words are skill "
                        "keywords. Genuine resumes are usually well below 20%.",
        ))
    return threats[:MAX_PER_TECHNIQUE]


def detect_metadata_stuffing(doc: ExtractedDocument) -> list[Threat]:
    threats: list[Threat] = []
    for key, value in doc.metadata.items():
        value = str(value)
        items = [i for i in re.split(r"[,;|]", value) if i.strip()]
        keywords = sum(skill_counts(value).values())
        if len(value) > 300 or len(items) >= 15 or keywords >= 8:
            threats.append(Threat(
                id=f"metadata-{key.lower()}",
                technique="metadata_stuffing",
                severity="medium",
                title=f"Keywords hidden in file properties ({key})",
                description="The file's hidden properties are packed with "
                            "keywords that some ATS software indexes.",
                evidence=_quote(value),
                hidden=True,
            ))
    return threats


# ── 4. Invisible characters & look-alike letters ───────────────────────────

ZERO_WIDTH = "​‌‍⁠﻿᠎"
BIDI_CONTROLS = "‪‫‬‭‮⁦⁧⁨⁩"


def detect_invisible_characters(doc: ExtractedDocument) -> list[Threat]:
    threats: list[Threat] = []
    text = doc.text
    zero = sum(text.count(c) for c in ZERO_WIDTH)
    if zero >= 3:
        line = next((i for i, l in enumerate(doc.lines, 1)
                     if any(c in l for c in ZERO_WIDTH)), None)
        threats.append(Threat(
            id="invisible-zero-width",
            technique="invisible_characters",
            severity="medium",
            title="Zero-width characters",
            description=f"{zero} invisible zero-width characters were found. "
                        "They can split words to dodge filters or hide content.",
            location=ThreatLocation(line=line),
            hidden=True,
        ))
    bidi = sum(text.count(c) for c in BIDI_CONTROLS)
    if bidi:
        threats.append(Threat(
            id="invisible-bidi",
            technique="invisible_characters",
            severity="high",
            title="Text-direction control characters",
            description="Hidden characters that reorder how text is displayed, "
                        "so what you see differs from what software reads.",
            hidden=True,
        ))
    return threats


def _script(ch: str) -> str | None:
    if not ch.isalpha():
        return None
    name = unicodedata.name(ch, "")
    for script in ("LATIN", "CYRILLIC", "GREEK"):
        if name.startswith(script):
            return script
    return "OTHER"


def detect_homoglyphs(doc: ExtractedDocument) -> list[Threat]:
    mixed = []
    for word in re.findall(r"\w{3,}", doc.text):
        scripts = {_script(c) for c in word} - {None}
        if "LATIN" in scripts and scripts & {"CYRILLIC", "GREEK"}:
            mixed.append(word)
    if not mixed:
        return []
    return [Threat(
        id="homoglyphs",
        technique="homoglyphs",
        severity="medium",
        title="Look-alike letters",
        description="Words mix Latin letters with identical-looking Cyrillic or "
                    "Greek ones, which can fool keyword matching.",
        evidence=_quote(", ".join(dict.fromkeys(mixed))),
    )]


ALL_DETECTORS = (
    detect_hidden_text,
    detect_prompt_injection,
    detect_keyword_stuffing,
    detect_metadata_stuffing,
    detect_invisible_characters,
    detect_homoglyphs,
)


def detect_threats(doc: ExtractedDocument) -> list[Threat]:
    threats: list[Threat] = []
    for detector in ALL_DETECTORS:
        threats.extend(detector(doc))
    order = {"high": 0, "medium": 1, "low": 2}
    return sorted(threats, key=lambda t: order[t.severity])
