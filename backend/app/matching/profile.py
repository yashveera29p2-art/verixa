"""The user's profile as sent by the app, and its matchable 'evidence'."""

from __future__ import annotations

import re

from pydantic import BaseModel, Field


class ProjectIn(BaseModel):
    title: str = ""
    description: str = ""
    techStack: list[str] = []


class ExperienceIn(BaseModel):
    type: str = ""
    company: str = ""
    role: str = ""
    description: str = ""


class ProfileIn(BaseModel):
    """The parts of the app's profile used for matching. Field names follow
    lib/features/profile/domain/profile_data.dart."""

    status: str = ""  # student | fresher | working_professional
    targetRole: str = ""
    degree: str = ""
    branch: str = ""
    cgpa: str = ""
    graduationYear: str = ""
    totalExperienceYears: float | None = None
    skills: list[str] = Field(default_factory=list, max_length=200)
    tools: list[str] = Field(default_factory=list, max_length=200)
    softSkills: list[str] = Field(default_factory=list, max_length=100)
    projects: list[ProjectIn] = Field(default_factory=list, max_length=30)
    experience: list[ExperienceIn] = Field(default_factory=list, max_length=30)
    certifications: list[str] = Field(default_factory=list, max_length=50)


def evidence(profile: ProfileIn) -> list[tuple[str, str]]:
    """(sentence, label) pairs describing the user. The label is what the
    app shows as 'matched by', e.g. 'Project: Verixa'."""
    out: list[tuple[str, str]] = []
    for skill in profile.skills + profile.tools:
        out.append((skill, f"Skill: {skill}"))
    for skill in profile.softSkills:
        out.append((skill, f"Soft skill: {skill}"))
    # Each sentence of a project or job is its own piece of evidence:
    # comparing one requirement with one sentence is far more precise than
    # with a whole paragraph.
    for p in profile.projects:
        label = f"Project: {p.title}"
        tech = f" using {', '.join(p.techStack)}" if p.techStack else ""
        out.append((f"{p.title}{tech}", label))
        out += [(s, label) for s in _sentences(p.description)]
    for e in profile.experience:
        label = (f"{'Internship' if e.type == 'internship' else 'Job'}: "
                 f"{e.role} at {e.company}")
        out.append((f"{e.role} at {e.company}", label))
        out += [(s, label) for s in _sentences(e.description)]
    for c in profile.certifications:
        out.append((c, f"Certification: {c}"))
    if profile.degree:
        out.append((f"{profile.degree} {profile.branch}".strip(),
                    f"Education: {profile.degree} {profile.branch}".strip()))
    # The career goal is deliberately NOT evidence: wanting a role isn't
    # proof of having the skills for it.
    return [(text, label) for text, label in out if text.strip()]


def _sentences(text: str) -> list[str]:
    parts = re.split(r"(?<=[.!?])\s+|\n+|\s*[•;]\s*", text or "")
    return [p.strip(" -") for p in parts if len(p.split()) >= 3]


def known_skills(profile: ProfileIn) -> set[str]:
    """Every skill named anywhere in the profile, lower-cased."""
    names = profile.skills + profile.tools + profile.certifications
    for p in profile.projects:
        names += p.techStack
    return {n.strip().lower() for n in names if n.strip()}
