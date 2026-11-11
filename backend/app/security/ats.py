"""Estimated ATS compatibility score (feature 3).

A transparent, rule-based estimate: six components add up to 100, and each
explains what earned or cost points. Real ATS products differ — the app
labels this an estimate.
"""

from __future__ import annotations

import re

from ..extraction import ExtractedDocument
from ..models import AtsComponent, ParsedResume, Threat
from ..parsing.common import is_bullet, strip_bullet

ACTION_VERBS = {
    "led", "built", "developed", "designed", "implemented", "created", "improved",
    "reduced", "increased", "managed", "launched", "optimised", "optimized",
    "automated", "analysed", "analyzed", "delivered", "achieved", "collaborated",
    "organised", "organized", "coordinated", "wrote", "tested", "deployed",
    "migrated", "researched", "trained", "mentored", "presented", "won",
    "secured", "streamlined", "engineered", "integrated", "maintained",
    "resolved", "established", "initiated", "spearheaded", "conducted",
    "prepared", "handled", "supported", "architected", "refactored", "scaled",
}
QUANTIFIED = re.compile(r"\d+(?:\.\d+)?\s*(?:%|x\b|\+|k\b|lakh|crore|users|ms\b|hours|days)|\b\d{2,}\b",
                        re.IGNORECASE)

# If any high-severity manipulation is found, the score is capped here.
HIGH_RISK_CAP = 45


def _component(key, label, score, maximum, notes) -> AtsComponent:
    return AtsComponent(key=key, label=label, score=max(0, min(score, maximum)),
                        max=maximum, notes=notes)


def score_ats(doc: ExtractedDocument, parsed: ParsedResume,
              threats: list[Threat]) -> tuple[int, list[AtsComponent]]:
    parts: list[AtsComponent] = []
    visible = [l for l in doc.visible_lines if l.strip()]

    # 1. Parsability — can software read the text at all?
    notes = []
    if len(visible) >= 15:
        p = 20
    elif len(visible) >= 8:
        p, notes = 12, ["Very little text was found."]
    else:
        p, notes = 4, ["Almost no readable text — image-based resumes fail most ATS."]
    hidden_ratio = 1 - len(" ".join(visible)) / max(1, len(doc.text))
    if hidden_ratio > 0.1:
        p -= 6
        notes.append("A noticeable part of the text is invisible to readers.")
    parts.append(_component("parsability", "Readable by ATS", p, 20,
                            notes or ["Text extracts cleanly."]))

    # 2. Standard sections.
    found = set(parsed.meta.sectionsFound if parsed.meta else [])
    s, notes = 0, []
    if "education" in found:
        s += 8
    else:
        notes.append("Add an 'Education' section heading.")
    if found & {"experience", "projects"}:
        s += 9
    else:
        notes.append("Add 'Experience' or 'Projects' — ATS look for these.")
    if "skills" in found:
        s += 8
    else:
        notes.append("Add a 'Skills' section with a clear heading.")
    parts.append(_component("sections", "Standard sections", s, 25,
                            notes or ["Education, experience/projects and skills found."]))

    # 3. Contact details.
    c = parsed.contact
    contact_score = 5 * sum(bool(x) for x in (c.fullName, c.email, c.phone))
    missing = [label for label, value in
               (("name", c.fullName), ("email", c.email), ("phone", c.phone)) if not value]
    parts.append(_component("contact", "Contact details", contact_score, 15,
                            [f"Missing: {', '.join(missing)}."] if missing
                            else ["Name, email and phone found."]))

    # 4. Content quality — bullets, numbers, action verbs.
    bullets = [strip_bullet(l) for l in visible if is_bullet(l)]
    descriptions = bullets + [e.description for e in parsed.experience] + \
        [p.description for p in parsed.projects]
    q, notes = 0, []
    if len(bullets) >= 3:
        q += 5
    else:
        notes.append("Use bullet points to describe your work.")
    quantified = sum(bool(QUANTIFIED.search(d)) for d in descriptions if d)
    if quantified >= 2:
        q += 8
    elif quantified == 1:
        q += 4
        notes.append("Add numbers to more achievements (%, users, time saved).")
    else:
        notes.append("Quantify achievements — numbers stand out to ATS and recruiters.")
    starts = [b.split()[0].lower().strip(",.") for b in bullets if b.split()]
    verb_share = sum(w in ACTION_VERBS for w in starts) / len(starts) if starts else 0
    if verb_share >= 0.5:
        q += 7
    elif verb_share >= 0.25:
        q += 4
        notes.append("Start more bullet points with action verbs (Built, Led, Improved).")
    else:
        notes.append("Start bullet points with action verbs (Built, Led, Improved).")
    parts.append(_component("content", "Content quality", q, 20,
                            notes or ["Clear bullets with numbers and action verbs."]))

    # 5. Length and format.
    f, notes = 2, []  # PDF/DOCX are both ATS-friendly formats
    if doc.file_type == "docx" or 1 <= doc.pages <= 2:
        f += 6
    else:
        notes.append(f"{doc.pages} pages — keep it to 1 page (freshers) or 2 at most.")
    long_lines = sum(len(l.split()) > 45 for l in visible)
    if long_lines <= 2:
        f += 2
    else:
        notes.append("Some lines are very long; break them into bullets.")
    parts.append(_component("format", "Length & format", f, 10,
                            notes or ["Good length and layout."]))

    # 6. Integrity — manipulation costs everything here.
    severities = {t.severity for t in threats}
    if "high" in severities:
        i, notes = 0, ["Serious manipulation found — see the threat report."]
    elif "medium" in severities:
        i, notes = 3, ["Suspicious content found — see the threat report."]
    elif "low" in severities:
        i, notes = 7, ["Minor issues found — see the threat report."]
    else:
        i, notes = 10, ["No manipulation detected."]
    parts.append(_component("integrity", "Integrity", i, 10, notes))

    total = sum(part.score for part in parts)
    if "high" in severities:
        total = min(total, HIGH_RISK_CAP)
    return total, parts
