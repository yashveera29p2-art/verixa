"""Resume writing checker (NLP).

Reads resume text the way a careful reviewer would and points out what
makes bullets weaker, with a suggested fix for each:

* weak phrases ("responsible for", "worked on", "helped with")
* passive voice ("was developed", "were handled"), found with spaCy
  part-of-speech tags: a form of "be" followed by a past participle (VBN)
* bullets with no number / impact (no %, count, time, money)
* buzzwords and clichés ("hardworking", "team player", "go-getter")
* first-person pronouns ("I", "my") — resumes are written without them
* over-long sentences and several bullets starting with the same verb
* overall readability (Flesch reading ease, from a syllable estimate)
"""

from __future__ import annotations

import re
from collections import Counter

from ..models import WritingIssue, WritingReport
from ..parsing.common import nlp
from ..parsing.sections import heading_of

WEAK = {
    "responsible for": "Led / Owned / Managed",
    "worked on": "Built / Developed / Implemented",
    "helped with": "Contributed to / Supported (say exactly what you did)",
    "helped in": "Contributed to (say exactly what you did)",
    "involved in": "Built / Designed / Delivered",
    "was part of": "Collaborated on / Delivered",
    "participated in": "Contributed to / Presented at",
    "duties included": "Start with what you achieved",
    "tasked with": "Delivered / Completed",
    "handled": "Managed / Resolved / Processed",
    "did": "Completed / Delivered",
    "made": "Built / Created / Designed",
    "used": "Applied / Implemented with",
    "learned": "Applied / Mastered (show the result)",
}
BUZZWORDS = ("hardworking", "hard-working", "team player", "go-getter", "self-starter",
             "detail-oriented", "detail oriented", "results-driven", "dynamic",
             "synergy", "think outside the box", "passionate", "motivated",
             "dedicated", "quick learner", "fast learner", "excellent communication",
             "best of breed", "go to person", "proactive")
STRONG_START = ("Built, Designed, Developed, Implemented, Led, Optimised, Reduced, "
                "Increased, Automated, Launched")
NUMBER = re.compile(r"\d|%|₹|\$|\b(one|two|three|four|five|six|seven|eight|nine|ten|"
                    r"hundred|thousand|lakh|crore|million|double|triple|half)\b", re.I)
BULLET = re.compile(r"^\s*([•●▪◦‣\-–—*·o>]|\d+[.)])\s+")
IMPACT_SECTIONS = {"experience", "projects", "internships", "achievements",
                   "responsibilities", "work"}


def _syllables(word: str) -> int:
    w = word.lower()
    groups = re.findall(r"[aeiouy]+", w)
    n = len(groups) - (1 if w.endswith("e") and len(groups) > 1 else 0)
    return max(1, n)


def _readability(sentences: list[str]) -> int:
    words = [w for s in sentences for w in re.findall(r"[A-Za-z]+", s)]
    if not words or not sentences:
        return 0
    syll = sum(_syllables(w) for w in words)
    score = 206.835 - 1.015 * (len(words) / len(sentences)) - 84.6 * (syll / len(words))
    return max(0, min(100, round(score)))


def _label(r: int) -> str:
    return ("very easy" if r >= 80 else "easy" if r >= 65 else "plain" if r >= 50
            else "fairly hard" if r >= 30 else "hard")


def _short(text: str, n: int = 90) -> str:
    text = " ".join(text.split())
    return text if len(text) <= n else text[: n - 1].rstrip() + "…"


def check_writing(text: str) -> WritingReport:
    lines = [l.rstrip() for l in text.splitlines() if l.strip()]
    section = ""
    bullets: list[tuple[str, str]] = []  # (section, text)
    for line in lines:
        h = heading_of(line.strip())
        if h:
            section = h[0]
            continue
        body = BULLET.sub("", line).strip()
        # A bullet: a bulleted line, or a sentence-like line under an impact
        # section, that describes doing something (has a verb). Skips titles
        # and lists like "Tech: Flutter, Firebase".
        if (BULLET.match(line) or section in IMPACT_SECTIONS) and len(body.split()) >= 5 \
                and not re.match(r"^[A-Za-z ]{2,20}:\s", body) \
                and any(t.tag_.startswith("VB") for t in nlp()(body)):
            bullets.append((section, body))

    issues: list[WritingIssue] = []
    weak = passive = buzz = 0

    # Sentences for readability and length checks: resume lines are their own
    # units (they rarely end with full stops), split further at full stops.
    sentences = [part.strip() for line in lines if not heading_of(line.strip())
                 for part in re.split(r"(?<=[.!?])\s+", BULLET.sub("", line))
                 if len(part.split()) >= 3]

    # Passive voice: a "be" auxiliary directly followed by a past participle.
    for b_section, b in bullets:
        tokens = nlp()(b)
        for i in range(len(tokens) - 1):
            t, nxt = tokens[i], tokens[i + 1]
            if t.lower_ in ("was", "were", "is", "are", "been", "be", "being") and nxt.tag_ == "VBN":
                passive += 1
                issues.append(WritingIssue(
                    kind="passive", excerpt=_short(b),
                    message=f"Passive voice (“{t.text} {nxt.text}”) hides who did the work.",
                    suggestion="Start with what you did, e.g. “Developed …”, “Reduced …”."))
                break

    for _, b in bullets:
        low = b.lower()
        for phrase, better in WEAK.items():
            if re.search(rf"\b{re.escape(phrase)}\b", low):
                weak += 1
                issues.append(WritingIssue(
                    kind="weak_phrase", excerpt=_short(b),
                    message=f"“{phrase}” is vague and weak.",
                    suggestion=f"Use a strong verb: {better}."))
                break

    quantified = sum(1 for s, b in bullets if NUMBER.search(b))
    for s, b in bullets:
        if s in IMPACT_SECTIONS and not NUMBER.search(b):
            issues.append(WritingIssue(
                kind="no_impact", excerpt=_short(b),
                message="No number or result: readers can’t see the impact.",
                suggestion="Add a measurable result, e.g. users, % faster, time saved, "
                           "accuracy, team size."))

    low_text = text.lower()
    for word in BUZZWORDS:
        if word in low_text:
            buzz += 1
            issues.append(WritingIssue(
                kind="buzzword", excerpt=word,
                message=f"“{word}” is a cliché recruiters skip.",
                suggestion="Show it with an example instead of claiming it."))

    first = re.findall(r"\b(I|my|me|myself)\b", text)
    if len(first) >= 2:
        issues.append(WritingIssue(
            kind="first_person", excerpt=", ".join(sorted(set(first))),
            message=f"Uses first person {len(first)} times.",
            suggestion="Drop “I/my”: write “Built a …” instead of “I built a …”."))

    for s in sentences:
        n = len(s.split())
        if n > 32:
            issues.append(WritingIssue(
                kind="long", excerpt=_short(s),
                message=f"{n} words in one sentence is hard to scan.",
                suggestion="Split into two bullets of 12–20 words each."))

    starts = Counter(b.split()[0].lower().strip(",.") for _, b in bullets if b.split())
    for verb, n in starts.items():
        if n >= 3 and verb.isalpha():
            issues.append(WritingIssue(
                kind="repeated_start", excerpt=verb.capitalize(),
                message=f"{n} bullets start with “{verb.capitalize()}”.",
                suggestion=f"Vary the opening verbs, e.g. {STRONG_START}."))

    readability = _readability(sentences)
    qpct = round(100 * quantified / len(bullets)) if bullets else 0

    # Score: start at 100, take points off for each kind of problem.
    score = 100
    score -= min(25, weak * 5)
    score -= min(15, passive * 4)
    score -= min(10, buzz * 3)
    score -= 0 if not bullets else max(0, (60 - qpct) // 3)  # want ≥60 % quantified
    score -= 6 if len(first) >= 2 else 0
    score -= min(10, sum(1 for i in issues if i.kind == "long") * 3)
    score -= min(8, sum(1 for i in issues if i.kind == "repeated_start") * 4)
    score -= 6 if readability and readability < 30 else 0
    score = max(0, min(100, score))

    summary = ("Strong, clear writing." if score >= 85 else
               "Good, with a few things to tighten." if score >= 70 else
               "Several bullets could be stronger." if score >= 50 else
               "The writing needs work: start bullets with action verbs and add results.")
    if not bullets:
        summary = "Couldn’t find bullet points to review; list projects and experience as bullets."

    # Most useful first, and not too many.
    order = {"weak_phrase": 0, "no_impact": 1, "passive": 2, "first_person": 3,
             "buzzword": 4, "repeated_start": 5, "long": 6}
    issues.sort(key=lambda i: order.get(i.kind, 9))
    return WritingReport(
        score=score, readability=readability, readabilityLabel=_label(readability),
        bullets=len(bullets), quantifiedPercent=qpct, passiveCount=passive,
        weakCount=weak, buzzwordCount=buzz, issues=issues[:20], summary=summary)
