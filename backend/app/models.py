"""API response shapes. Field names match the app's profile sections
(lib/features/profile/domain/profile_data.dart) so results can be imported
directly after the user reviews them."""

from __future__ import annotations

from pydantic import BaseModel, Field


class Contact(BaseModel):
    fullName: str = ""
    email: str = ""
    phone: str = ""
    city: str = ""
    linkedin: str = ""
    github: str = ""
    portfolio: str = ""


class SchoolRecord(BaseModel):
    board: str = ""
    school: str = ""
    score: str = ""
    year: str = ""


class Degree(BaseModel):
    college: str = ""
    degree: str = ""
    branch: str = ""
    cgpa: str = ""
    graduationYear: str = ""


class HigherQualification(BaseModel):
    qualification: str = ""
    institution: str = ""
    score: str = ""
    year: str = ""


class Education(BaseModel):
    class10: SchoolRecord = Field(default_factory=SchoolRecord)
    class12: SchoolRecord = Field(default_factory=SchoolRecord)
    degree: Degree = Field(default_factory=Degree)
    additional: list[HigherQualification] = []


class ExperienceEntry(BaseModel):
    type: str = "internship"  # "internship" or "job"
    company: str = ""
    role: str = ""
    start: str = ""
    end: str = ""
    description: str = ""


class ProjectEntry(BaseModel):
    title: str = ""
    description: str = ""
    techStack: list[str] = []
    link: str = ""
    duration: str = ""


class Skills(BaseModel):
    technical: list[str] = []
    tools: list[str] = []
    soft: list[str] = []
    languages: list[str] = []


class CareerGoal(BaseModel):
    objective: str = ""


class Extras(BaseModel):
    certifications: list[str] = []
    achievements: list[str] = []
    positions: list[str] = []
    hobbies: list[str] = []


class Meta(BaseModel):
    fileType: str
    pages: int
    lines: int
    sectionsFound: list[str]


class ParsedResume(BaseModel):
    contact: Contact = Field(default_factory=Contact)
    careerGoal: CareerGoal = Field(default_factory=CareerGoal)
    education: Education = Field(default_factory=Education)
    experience: list[ExperienceEntry] = []
    projects: list[ProjectEntry] = []
    skills: Skills = Field(default_factory=Skills)
    extras: Extras = Field(default_factory=Extras)
    # 0.0–1.0 per section: how sure the parser is (heading found + fields filled).
    confidence: dict[str, float] = {}
    # Things the user should double-check.
    warnings: list[str] = []
    meta: Meta | None = None
