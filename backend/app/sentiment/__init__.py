"""Company review sentiment and aspects (NLP).

Each review is split into sentences; each sentence gets a polarity from a
sentiment lexicon with negation ("not good" → negative) and intensifiers
("very", "extremely") handled, and is linked to the aspects it talks about
(learning, work-life balance, pay, management, culture, growth, job
security, interview). The result summarises what reviewers feel overall and
about each aspect, with a short example quote for each.
"""

from __future__ import annotations

import re

from pydantic import BaseModel

POSITIVE = {
    "good": 1, "great": 2, "excellent": 2, "amazing": 2, "awesome": 2, "best": 2, "nice": 1,
    "supportive": 2, "helpful": 1.5, "friendly": 1.5, "flexible": 1.5, "learn": 1,
    "learning": 1, "learned": 1, "growth": 1, "grow": 1, "decent": 0.5, "fair": 0.5,
    "fun": 1, "happy": 1.5, "love": 2, "loved": 2, "enjoy": 1.5, "enjoyed": 1.5,
    "stable": 1, "secure": 1, "smooth": 1, "transparent": 1.5, "respect": 1,
    "respectful": 1.5, "competitive": 1, "generous": 1.5, "balanced": 1.5, "relaxed": 1,
    "positive": 1.5, "recommend": 1.5, "recommended": 1.5, "well": 0.5, "easy": 0.5,
    "exciting": 1.5, "mentor": 1, "mentorship": 1, "mentoring": 1, "appreciated": 1.5,
    "caring": 1.5, "fast": 0.5, "on time": 1, "hike": 0.5, "bonus": 1, "perks": 1,
    "benefits": 0.5, "clear": 0.5, "organized": 1, "organised": 1, "innovative": 1.5,
}
NEGATIVE = {
    "bad": -1.5, "poor": -1.5, "worst": -2, "terrible": -2, "awful": -2, "toxic": -2,
    "stressful": -1.5, "stress": -1, "pressure": -1, "long": -0.5, "overtime": -1,
    "late": -0.5, "low": -1, "underpaid": -2, "unpaid": -1, "delay": -1, "delayed": -1.5,
    "micromanage": -2, "micromanagement": -2, "politics": -1.5, "rude": -2, "unfair": -1.5,
    "layoff": -1.5, "layoffs": -1.5, "fired": -1.5, "insecure": -1.5, "unstable": -1.5,
    "boring": -1, "monotonous": -1, "slow": -0.5, "difficult": -0.5, "tough": -0.5,
    "hard": -0.3, "exhausting": -1.5, "burnout": -2, "hectic": -1, "chaotic": -1.5,
    "disorganized": -1.5, "disorganised": -1.5, "no growth": -1.5, "bench": -1,
    "not recommend": -2, "avoid": -1.5, "worse": -1.5, "less": -0.5, "lack": -1,
    "lacks": -1, "lacking": -1, "problem": -1, "problems": -1, "issue": -0.5,
    "issues": -0.5, "weekend": -0.5, "weekends": -0.5, "night": -0.3, "unclear": -1,
}
NEGATORS = {"not", "no", "never", "n't", "dont", "don't", "isnt", "isn't", "wasnt",
            "wasn't", "hardly", "without", "nothing"}
INTENSIFIERS = {"very": 1.5, "really": 1.4, "extremely": 1.8, "too": 1.3, "so": 1.3,
                "highly": 1.5, "super": 1.5, "quite": 1.2, "bit": 0.7, "slightly": 0.6}

ASPECTS: dict[str, tuple[str, ...]] = {
    "Learning": ("learn", "training", "mentor", "skill", "knowledge", "teach", "course"),
    "Work-life balance": ("work-life", "work life", "hours", "overtime", "weekend", "late",
                          "shift", "leave", "balance", "flexible", "wfh", "remote", "night"),
    "Pay": ("pay", "salary", "stipend", "hike", "bonus", "ctc", "package", "paid", "money",
            "compensation", "appraisal"),
    "Management": ("manager", "management", "lead", "boss", "senior", "hr", "leadership",
                   "micromanag"),
    "Culture": ("culture", "team", "colleague", "people", "environment", "friendly",
                "politics", "toxic", "atmosphere"),
    "Growth": ("growth", "promotion", "career", "opportunit", "grow", "bench", "project"),
    "Job security": ("layoff", "fired", "secure", "security", "stable", "job cut",
                     "termination", "bench"),
    "Interview": ("interview", "round", "hiring", "recruit", "test", "offer", "onboard"),
}


class AspectSentiment(BaseModel):
    aspect: str
    mentions: int
    score: float  # −1 … +1
    label: str  # positive | mixed | negative
    example: str = ""


class ReviewAnalysis(BaseModel):
    reviews: int
    positivePercent: int
    neutralPercent: int
    negativePercent: int
    overall: str  # e.g. "Mostly positive"
    aspects: list[AspectSentiment] = []
    summary: str = ""


def _sentences(text: str) -> list[str]:
    parts = re.split(r"(?<=[.!?])\s+|\n+|;\s*|\bbut\b", text, flags=re.I)
    return [p.strip(" ,.-") for p in parts if p and len(p.split()) >= 2]


def sentence_polarity(sentence: str) -> float:
    """Lexicon polarity with negation and intensifiers, squashed to −1…+1."""
    low = sentence.lower().replace("n't", " n't")
    tokens = re.findall(r"[a-z']+|n't", low)
    total = 0.0
    # Two-word phrases first ("no growth", "not recommend", "on time").
    for phrase, v in list(POSITIVE.items()) + list(NEGATIVE.items()):
        if " " in phrase and phrase in low:
            total += v
    for i, tok in enumerate(tokens):
        v = POSITIVE.get(tok, NEGATIVE.get(tok))
        if v is None:
            continue
        window = tokens[max(0, i - 3):i]
        if any(w in INTENSIFIERS for w in window[-1:]):
            v *= INTENSIFIERS[window[-1]]
        if any(w in NEGATORS for w in window):
            v *= -0.8
        total += v
    return max(-1.0, min(1.0, total / 2.5))


def _label(score: float) -> str:
    return "positive" if score > 0.15 else "negative" if score < -0.15 else "mixed"


def analyze_reviews(texts: list[str], ratings: list[int] | None = None) -> ReviewAnalysis:
    ratings = ratings or []
    review_scores: list[float] = []
    aspect_scores: dict[str, list[tuple[float, str]]] = {a: [] for a in ASPECTS}
    for i, text in enumerate(texts):
        sents = _sentences(text or "")
        pols = [sentence_polarity(s) for s in sents]
        text_score = sum(pols) / len(pols) if pols else 0.0
        # Blend with the star rating when there is one (1★ → −1, 5★ → +1).
        if i < len(ratings) and ratings[i]:
            stars = (ratings[i] - 3) / 2
            text_score = 0.6 * text_score + 0.4 * stars if sents else stars
        review_scores.append(text_score)
        for s, p in zip(sents, pols):
            low = s.lower()
            for aspect, keys in ASPECTS.items():
                if any(k in low for k in keys):
                    aspect_scores[aspect].append((p, s))

    n = len(review_scores)
    pos = sum(1 for s in review_scores if s > 0.15)
    neg = sum(1 for s in review_scores if s < -0.15)
    neu = n - pos - neg
    pct = (lambda k: round(100 * k / n)) if n else (lambda k: 0)
    overall = ("No reviews yet" if not n else
               "Mostly positive" if pos >= 0.6 * n else
               "Mostly negative" if neg >= 0.6 * n else "Mixed")

    aspects = []
    for aspect, items in aspect_scores.items():
        if not items:
            continue
        avg = sum(p for p, _ in items) / len(items)
        # The most telling sentence: strongest in the same direction as the average.
        example = max(items, key=lambda it: it[0] * (1 if avg >= 0 else -1))[1]
        aspects.append(AspectSentiment(
            aspect=aspect, mentions=len(items), score=round(avg, 2), label=_label(avg),
            example=example[:120]))
    aspects.sort(key=lambda a: a.mentions, reverse=True)

    good = [a.aspect.lower() for a in aspects if a.label == "positive"][:2]
    bad = [a.aspect.lower() for a in aspects if a.label == "negative"][:2]
    parts = []
    if good:
        parts.append("praised for " + " and ".join(good))
    if bad:
        parts.append("concerns about " + " and ".join(bad))
    summary = (overall + (": " + "; ".join(parts) if parts else "") + ".") if n else ""
    return ReviewAnalysis(reviews=n, positivePercent=pct(pos), neutralPercent=pct(neu),
                          negativePercent=pct(neg), overall=overall, aspects=aspects[:6],
                          summary=summary)
