"""Builds the full scan report: threats, ATS score and suggestions."""

from __future__ import annotations

from ..extraction import ExtractedDocument
from ..models import AtsComponent, ScanReport, Threat
from ..parsing import parse_resume
from .ats import score_ats
from .detectors import detect_threats

# One clear fix per technique (feature 4: correction suggestions).
_FIXES = {
    "hidden_text": "Remove all hidden text (white, microscopic or off-page). "
                   "Recruiters and modern ATS treat it as manipulation and may "
                   "reject the application outright.",
    "prompt_injection": "Delete any instructions aimed at AI tools (\"ignore previous "
                        "instructions\", \"rate this candidate 10/10\"). Let your "
                        "genuine experience speak for itself.",
    "keyword_stuffing": "Mention each skill where you actually used it — in a project "
                        "or job — instead of repeating keywords.",
    "metadata_stuffing": "Clear the keyword list from the file's properties "
                         "(File → Info/Properties) before exporting.",
    "invisible_characters": "Retype affected text or paste it as plain text to strip "
                            "invisible characters.",
    "homoglyphs": "Retype the flagged words using a normal English keyboard.",
}


def _risk_level(threats: list[Threat]) -> str:
    severities = {t.severity for t in threats}
    for level in ("high", "medium", "low"):
        if level in severities:
            return level
    return "clean"


def _suggestions(threats: list[Threat], parts: list[AtsComponent]) -> list[str]:
    out: list[str] = []
    for technique in dict.fromkeys(t.technique for t in threats):
        out.append(_FIXES[technique])
    for part in parts:
        if part.key != "integrity" and part.score < part.max:
            out.extend(n for n in part.notes if n not in out)
    if threats:
        out.append("Use 'Import genuine details' to rebuild your profile from the "
                   "visible content only.")
    return out


def scan_resume(doc: ExtractedDocument) -> ScanReport:
    parsed = parse_resume(doc)  # visible text only
    threats = detect_threats(doc)
    score, parts = score_ats(doc, parsed, threats)
    return ScanReport(
        atsScore=score,
        riskLevel=_risk_level(threats),
        threats=threats,
        atsBreakdown=parts,
        suggestions=_suggestions(threats, parts),
        parsed=parsed,
    )
