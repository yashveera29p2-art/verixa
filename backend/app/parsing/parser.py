"""Runs every parsing step and assembles the API response."""

from __future__ import annotations

import re

from ..extraction import ExtractedDocument
from ..models import CareerGoal, Extras, Meta, ParsedResume
from .common import strip_bullet, tidy
from .contact import parse_contact
from .education import current_year, parse_education
from .entries import parse_experience, parse_projects
from .sections import split_sections
from .skills import parse_skills

OBJECTIVE_LIMIT = 300


def _objective(lines: list[str]) -> str:
    text = " ".join(strip_bullet(l) for l in lines).strip()
    if len(text) <= OBJECTIVE_LIMIT:
        return text
    # Cut at the last full sentence that fits.
    cut = text[:OBJECTIVE_LIMIT]
    end = cut.rfind(". ")
    return cut[: end + 1] if end > 80 else cut.rstrip() + "…"


_TARGET_ROLE = [
    # "Target role: Software Developer" / "Desired position - Data Analyst"
    re.compile(r"(?:target|desired|preferred)\s+(?:role|position|job)s?\s*[:\-–]\s*([^.;\n]{3,60})", re.I),
    # "seeking a Software Developer role" / "looking for an SDE internship"
    re.compile(r"(?:seeking|looking for|aspiring|aiming for)\s+(?:an?\s+)?([A-Z][\w+#/ .-]{2,50}?)\s+"
               r"(?:role|position|internship|opportunit)", re.I),
]


def _target_role(lines: list[str]) -> str:
    # "Target role: …" is a line of its own; "seeking a … role" may wrap.
    for line in lines:
        m = _TARGET_ROLE[0].search(strip_bullet(line))
        if m:
            return tidy(m.group(1)).rstrip(" ,")
    m = _TARGET_ROLE[1].search(" ".join(strip_bullet(l) for l in lines))
    return tidy(m.group(1)).rstrip(" ,") if m else ""


def _strip_target_line(lines: list[str]) -> list[str]:
    """The "Target role: …" line feeds targetRole, not the objective."""
    return [l for l in lines if not _TARGET_ROLE[0].search(l)]


def _items(lines: list[str]) -> list[str]:
    return [tidy(strip_bullet(l)) for l in lines if tidy(strip_bullet(l))]


def _comma_items(lines: list[str]) -> list[str]:
    out: list[str] = []
    for line in lines:
        out += [tidy(p) for p in re.split(r"[,;|•]", strip_bullet(line)) if tidy(p)]
    return out


def parse_resume(doc: ExtractedDocument) -> ParsedResume:
    """Parses the VISIBLE text only, so hidden keywords or instructions
    never reach the user's profile."""
    lines = doc.visible_lines
    sections = split_sections(lines)
    result = ParsedResume()
    warnings: list[str] = []
    conf: dict[str, float] = {}

    result.contact, conf["contact"] = parse_contact(sections.header, lines)
    if not result.contact.fullName:
        warnings.append("Couldn't find your name — please add it.")

    if sections.has("summary"):
        summary = sections.get("summary")
        result.careerGoal = CareerGoal(
            targetRole=_target_role(summary),
            objective=_objective(_strip_target_line(summary)),
        )
        conf["careerGoal"] = 0.8 if result.careerGoal.objective else 0.0

    if sections.has("education"):
        result.education, conf["education"] = parse_education(sections.get("education"))
    else:
        warnings.append("No education section found.")
        conf["education"] = 0.0
    # "3rd Year" is often in the headline under the name, not in Education.
    if not result.education.degree.currentYear:
        result.education.degree.currentYear = current_year(" ".join(sections.header))

    if sections.has("experience"):
        result.experience = parse_experience(sections.get("experience"))
        conf["experience"] = 0.85 if result.experience else 0.2

    if sections.has("projects"):
        result.projects = parse_projects(sections.get("projects"))
        conf["projects"] = 0.85 if result.projects else 0.2

    result.skills, conf["skills"], inferred = parse_skills(
        sections.get("skills"), sections.get("languages"), doc.visible_text
    )
    if inferred:
        warnings.append("No skills section found; skills were picked up from the "
                        "rest of the resume — please review them.")

    result.extras = Extras(
        certifications=_items(sections.get("certifications")),
        achievements=_items(sections.get("achievements")),
        positions=_items(sections.get("activities")),
        hobbies=_comma_items(sections.get("hobbies")),
    )

    if doc.file_type == "pdf" and doc.pages > 2:
        warnings.append(f"Your resume is {doc.pages} pages; most recruiters "
                        "expect 1–2 pages.")
    if len(sections.found) <= 1:
        warnings.append("Few section headings were recognised. Unusual layouts "
                        "(columns, tables, images) may not parse well.")

    result.confidence = conf
    result.warnings = warnings
    result.meta = Meta(
        fileType=doc.file_type,
        pages=doc.pages,
        lines=len(lines),
        sectionsFound=sections.found,
    )
    return result
