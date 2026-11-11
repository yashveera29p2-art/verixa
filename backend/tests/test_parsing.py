"""End-to-end parsing of the sample resumes, via real PDF/DOCX files."""

import pytest

from app.extraction import UnsupportedFileError, detect_file_type, extract
from app.parsing import parse_resume
from app.parsing.contact import find_links, find_phone
from app.parsing.sections import heading_of, split_sections

from .samples import FRESHER, PROFESSIONAL, STUDENT, make_docx, make_pdf


@pytest.fixture(scope="module")
def student():
    return parse_resume(extract(make_pdf(STUDENT)))


@pytest.fixture(scope="module")
def fresher():
    return parse_resume(extract(make_docx(FRESHER)))


@pytest.fixture(scope="module")
def professional():
    return parse_resume(extract(make_pdf(PROFESSIONAL)))


# ── Extraction ─────────────────────────────────────────────────────────────

def test_detects_file_type_by_content():
    assert detect_file_type(make_pdf("hi")) == "pdf"
    assert detect_file_type(make_docx("hi")) == "docx"
    with pytest.raises(UnsupportedFileError):
        detect_file_type(b"just some text")


def test_pdf_keeps_word_styles_for_the_security_scanner():
    doc = extract(make_pdf(STUDENT))
    assert doc.words and doc.words[0].size == pytest.approx(10)
    assert doc.lines[0] == "PRIYA SHARMA"


def test_empty_pdf_is_rejected():
    with pytest.raises(UnsupportedFileError):
        extract(make_pdf(""))


# ── Building blocks ────────────────────────────────────────────────────────

@pytest.mark.parametrize("text, expected", [
    ("+91 98765 43210", "+919876543210"),
    ("+91-99887-76655", "+919988776655"),
    ("9123456789", "+919123456789"),
    ("Call 09876543210", "+919876543210"),
    ("Roll no 12345678901234", ""),
])
def test_indian_phone_numbers(text, expected):
    assert find_phone(text) == expected


def test_headings_including_inline_form():
    assert heading_of("TECHNICAL SKILLS") == ("skills", "")
    assert heading_of("Career Objective:") == ("summary", "")
    assert heading_of("Skills: Java, Python") == ("skills", "Java, Python")
    assert heading_of("Built a Flutter app") is None


def test_skill_sub_labels_do_not_start_new_sections():
    s = split_sections(["SKILLS", "Languages: Java, Python", "LANGUAGES", "English"])
    assert s.get("skills") == ["Languages: Java, Python"]
    assert s.get("languages") == ["English"]


# ── Student resume (PDF) ───────────────────────────────────────────────────

def test_student_contact(student):
    c = student.contact
    assert c.fullName == "Priya Sharma"
    assert c.email == "priya.sharma@example.com"
    assert c.phone == "+919876543210"
    assert c.city == "Hyderabad"
    assert c.linkedin == "linkedin.com/in/priya-sharma"
    assert c.github == "github.com/priyasharma"
    # Regression: "B.Tech" in the education section was taken as a link.
    assert c.portfolio == ""


@pytest.mark.parametrize("text, expected", [
    ("B.Tech in CSE, M.Tech, B.E. Mechanical", ("", "", "")),
    ("Portfolio: priya.dev | github.com/priya", ("", "github.com/priya", "priya.dev")),
    ("https://www.example.in/me", ("", "", "https://www.example.in/me")),
    ("Built with Node.js and Vue.js", ("", "", "")),
])
def test_link_detection(text, expected):
    assert find_links(text) == expected


def test_student_education(student):
    e = student.education
    assert e.degree.degree == "B.Tech"
    assert e.degree.branch == "CSE"
    assert e.degree.college == "JNTU Hyderabad College of Engineering"
    assert e.degree.cgpa == "8.4"
    assert e.degree.graduationYear == "2026"
    assert e.class12.score == "94.5%" and e.class12.year == "2022"
    assert e.class12.school == "Narayana Junior College"
    assert e.class10.board == "CBSE" and e.class10.score == "92%"
    assert e.class10.school == "Kendriya Vidyalaya"


def test_student_projects(student):
    titles = [p.title for p in student.projects]
    assert titles == ["Verixa – Resume Intelligence App", "Smart Attendance System"]
    verixa, attendance = student.projects
    assert verixa.techStack == ["Flutter", "Firebase", "Python", "spaCy"]
    assert verixa.duration == "Jan 2025 – Apr 2025"
    assert "spaCy" in verixa.description
    assert attendance.techStack == ["Python", "OpenCV"]
    assert attendance.link == "github.com/priyasharma/attendance"


def test_student_internship(student):
    [job] = student.experience
    assert job.type == "internship"
    assert job.role == "Software Development Intern"
    assert job.company == "Acme Technologies Pvt Ltd"
    assert (job.start, job.end) == ("May 2024", "Jul 2024")


def test_student_skills_are_classified(student):
    s = student.skills
    assert {"Java", "Python", "Dart", "SQL", "Flutter", "Spring Boot"} <= set(s.technical)
    assert s.tools == ["Git", "VS Code", "Postman"]
    assert s.soft == ["Communication", "Teamwork"]
    assert s.languages == ["English", "Telugu", "Hindi"]


def test_student_extras_and_goal(student):
    assert student.extras.certifications == [
        "AWS Cloud Practitioner (2025)", "NPTEL Data Structures (Elite)"]
    assert student.extras.achievements == ["Smart India Hackathon 2024 finalist"]
    assert student.extras.hobbies == ["Chess", "Photography"]
    assert student.careerGoal.objective.startswith("Computer science student")
    assert student.warnings == []


# ── Fresher resume (DOCX) ──────────────────────────────────────────────────

def test_fresher(fresher):
    assert fresher.contact.fullName == "Rahul Verma"
    assert fresher.contact.phone == "+919123456789"
    assert fresher.contact.city == "Pune"
    d = fresher.education.degree
    assert (d.degree, d.branch, d.cgpa, d.graduationYear) == ("B.E.", "Mechanical", "7.9", "2025")
    assert d.college == "Pune Institute of Technology"
    [diploma] = fresher.education.additional
    assert diploma.qualification.startswith("Diploma")
    assert diploma.score == "85%"
    assert fresher.education.class10.score == "88%"
    assert {"AutoCAD", "SolidWorks", "CATIA"} <= set(fresher.skills.technical)
    assert fresher.skills.soft == ["Communication", "Teamwork"]
    [project] = fresher.projects
    assert project.title == "Design of a Low-Cost Solar Dryer"
    assert project.techStack == ["SolidWorks", "ANSYS"]
    assert fresher.meta.fileType == "docx"


# ── Working professional (PDF) ─────────────────────────────────────────────

def test_professional(professional):
    p = professional
    assert p.contact.fullName == "Anil Kumar Reddy"
    assert p.contact.phone == "+919988776655"
    assert p.contact.city == "Bengaluru"
    first, second = p.experience
    assert (first.role, first.company, first.end, first.type) == (
        "Senior Software Engineer", "Razorpay", "Present", "job")
    assert (second.role, second.company) == ("Software Engineer", "Infosys Limited")
    d = p.education.degree
    assert (d.degree, d.branch, d.college, d.cgpa) == ("B.Tech", "ECE", "NIT Warangal", "8.1")
    assert "Kafka" in p.skills.technical
    assert p.confidence["experience"] > 0.5


def test_resume_without_headings_warns():
    result = parse_resume(extract(make_docx("Just a name\nSome text about Python and Docker")))
    assert any("section" in w.lower() for w in result.warnings)
    assert {"Python", "Docker"} <= set(result.skills.technical)
