"""Runs every parsing step and assembles the API response."""

from __future__ import annotations

import re

from ..extraction import ExtractedDocument
from ..models import CareerGoal, Extras, Meta, ParsedResume
from .common import strip_bullet, tidy
from .contact import parse_contact
from .education import parse_education
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


def _items(lines: list[str]) -> list[str]:
    return [tidy(strip_bullet(l)) for l in lines if tidy(strip_bullet(l))]


def _comma_items(lines: list[str]) -> list[str]:
    out: list[str] = []
    for line in lines:
        out += [tidy(p) for p in re.split(r"[,;|•]", strip_bullet(line)) if tidy(p)]
    return out


def parse_resume(doc: ExtractedDocument) -> ParsedResume:
    sections = split_sections(doc.lines)
    result = ParsedResume()
    warnings: list[str] = []
    conf: dict[str, float] = {}

    result.contact, conf["contact"] = parse_contact(sections.header, doc.lines)
    if not result.contact.fullName:
        warnings.append("Couldn't find your name — please add it.")

    if sections.has("summary"):
        result.careerGoal = CareerGoal(objective=_objective(sections.get("summary")))
        conf["careerGoal"] = 0.8 if result.careerGoal.objective else 0.0

    if sections.has("education"):
        result.education, conf["education"] = parse_education(sections.get("education"))
    else:
        warnings.append("No education section found.")
        conf["education"] = 0.0

    if sections.has("experience"):
        result.experience = parse_experience(sections.get("experience"))
        conf["experience"] = 0.85 if result.experience else 0.2

    if sections.has("projects"):
        result.projects = parse_projects(sections.get("projects"))
        conf["projects"] = 0.85 if result.projects else 0.2

    result.skills, conf["skills"], inferred = parse_skills(
        sections.get("skills"), sections.get("languages"), doc.text
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
        lines=len(doc.lines),
        sectionsFound=sections.found,
    )
    return result
