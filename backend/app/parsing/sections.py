"""Splits resume lines into sections by detecting headings."""

from __future__ import annotations

import re
from dataclasses import dataclass, field

# Canonical section → headings people actually use.
HEADINGS: dict[str, tuple[str, ...]] = {
    "summary": ("summary", "professional summary", "objective", "career objective",
                "profile", "profile summary", "about me", "about"),
    "education": ("education", "academic details", "academics", "academic qualifications",
                  "educational qualifications", "educational qualification",
                  "qualifications", "academic background", "education details"),
    "experience": ("experience", "work experience", "professional experience",
                   "internships", "internship", "internship experience",
                   "employment history", "work history", "employment"),
    "projects": ("projects", "academic projects", "personal projects", "key projects",
                 "project work", "major projects", "project"),
    "skills": ("skills", "technical skills", "key skills", "core competencies",
               "technologies", "skill set", "skillset", "tech stack", "technical proficiency",
               "soft skills"),
    "certifications": ("certifications", "certification", "certificates",
                       "courses", "courses & certifications", "certifications & courses",
                       "licenses & certifications"),
    "achievements": ("achievements", "awards", "accomplishments", "honours", "honors",
                     "awards & achievements", "achievements & awards", "hackathons"),
    "activities": ("extracurricular activities", "extra-curricular activities",
                   "extracurriculars", "activities", "positions of responsibility",
                   "leadership", "volunteering", "volunteer experience",
                   "co-curricular activities"),
    "languages": ("languages", "languages known", "spoken languages"),
    "hobbies": ("hobbies", "interests", "hobbies & interests", "hobbies and interests"),
    "personal": ("personal details", "personal information", "personal profile",
                 "contact", "contact details", "declaration"),
}

_LOOKUP = {h: key for key, names in HEADINGS.items() for h in names}


def _normalise(line: str) -> str:
    line = re.sub(r"^[^a-zA-Z]+", "", line)  # leading bullets / numbers / icons
    line = line.lower().strip(" :-–|.")
    return re.sub(r"\s+", " ", line)


def heading_of(line: str) -> tuple[str, str] | None:
    """Returns (section, rest-of-line) if [line] is a heading.

    Handles "SKILLS", "Technical Skills:", and inline forms like
    "Skills: Java, Python" (rest = "Java, Python")."""
    if ":" in line:
        head, rest = line.split(":", 1)
        key = _LOOKUP.get(_normalise(head))
        if key and rest.strip():
            return key, rest.strip()
    norm = _normalise(line)
    if len(norm.split()) <= 5 and norm in _LOOKUP:
        return _LOOKUP[norm], ""
    return None


@dataclass
class Sections:
    header: list[str] = field(default_factory=list)  # lines before any heading
    bodies: dict[str, list[str]] = field(default_factory=dict)

    def get(self, key: str) -> list[str]:
        return self.bodies.get(key, [])

    def has(self, key: str) -> bool:
        return key in self.bodies

    @property
    def found(self) -> list[str]:
        return list(self.bodies)


def split_sections(lines: list[str]) -> Sections:
    result = Sections()
    current: list[str] = result.header
    current_key = ""
    for line in lines:
        hit = heading_of(line)
        # Inside Skills, "Languages: Java, Python" is a sub-label, not a new
        # section — only stand-alone headings switch sections there.
        if hit and current_key == "skills" and hit[1]:
            hit = None
        if hit:
            current_key = hit[0]
            key, rest = hit
            current = result.bodies.setdefault(key, [])
            if rest:
                current.append(rest)
        else:
            current.append(line)
    return result
