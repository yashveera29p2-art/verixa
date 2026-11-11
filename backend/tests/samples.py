"""Sample resumes (fictional people) and helpers that turn them into real
PDF and DOCX files, so tests exercise the same extraction path as uploads."""

from __future__ import annotations

import io

from docx import Document

STUDENT = """\
PRIYA SHARMA
Hyderabad, Telangana | +91 98765 43210 | priya.sharma@example.com
linkedin.com/in/priya-sharma | github.com/priyasharma
CAREER OBJECTIVE
Computer science student seeking a software engineering internship to apply my skills in Flutter and backend development.
EDUCATION
B.Tech in Computer Science and Engineering
JNTU Hyderabad College of Engineering | 2022 – 2026 | CGPA: 8.4/10
Intermediate (MPC), Narayana Junior College | Board of Intermediate Education | 2022 | 94.5%
SSC, Kendriya Vidyalaya | CBSE | 2020 | 92%
PROJECTS
Verixa – Resume Intelligence App | Jan 2025 – Apr 2025
• Built a Flutter app with Firebase phone authentication.
• Designed a resume parser using spaCy.
Tech: Flutter, Firebase, Python, spaCy
Smart Attendance System (Python, OpenCV)
• Face-recognition based attendance for 120 students.
github.com/priyasharma/attendance
INTERNSHIP
Software Development Intern, Acme Technologies Pvt Ltd | May 2024 – Jul 2024
• Developed REST APIs using Spring Boot.
• Reduced report generation time by 30%.
TECHNICAL SKILLS
Languages: Java, Python, Dart, SQL
Frameworks: Flutter, Spring Boot
Tools: Git, VS Code, Postman
Soft Skills: Communication, Teamwork
CERTIFICATIONS
• AWS Cloud Practitioner (2025)
• NPTEL Data Structures (Elite)
ACHIEVEMENTS
• Smart India Hackathon 2024 finalist
LANGUAGES
English, Telugu, Hindi
HOBBIES
Chess, Photography
"""

FRESHER = """\
RAHUL VERMA
rahul.verma@example.com • 9123456789 • Pune
Profile
B.E. graduate in Mechanical engineering looking for a design engineer role.
Academic Qualifications
Bachelor of Engineering (Mechanical), Pune Institute of Technology, 2025, CGPA 7.9
Diploma in Mechanical Engineering, Government Polytechnic Pune, 2021, 85%
SSC – Maharashtra State Board, 2018, 88%
Skills
AutoCAD, SolidWorks, CATIA, Communication, Teamwork
Projects
Design of a Low-Cost Solar Dryer
Designed and fabricated a solar dryer prototype for farmers.
Tools used: SolidWorks, ANSYS
"""

PROFESSIONAL = """\
Anil Kumar Reddy
Senior Software Engineer | Bengaluru | anil.reddy@example.com | +91-99887-76655
SUMMARY
Backend engineer with 4 years of experience building payment systems at scale.
WORK EXPERIENCE
Senior Software Engineer at Razorpay | Mar 2023 – Present
• Led migration of settlement service to Kafka, cutting latency by 40%.
Software Engineer, Infosys Limited | Jul 2021 – Feb 2023
• Built Java microservices for a banking client.
EDUCATION
B.Tech, Electronics and Communication Engineering, NIT Warangal, 2021, 8.1 CGPA
SKILLS
Java, Spring Boot, Kafka, PostgreSQL, Docker, Kubernetes, AWS
"""


def make_docx(text: str) -> bytes:
    doc = Document()
    for line in text.splitlines():
        doc.add_paragraph(line)
    buf = io.BytesIO()
    doc.save(buf)
    return buf.getvalue()


def _pdf_escape(line: str) -> bytes:
    raw = line.encode("cp1252", errors="replace")
    return raw.replace(b"\\", b"\\\\").replace(b"(", b"\\(").replace(b")", b"\\)")


def make_pdf(text: str, lines_per_page: int = 52) -> bytes:
    """A minimal valid PDF (Helvetica, WinAnsi) — enough for pdfplumber."""
    all_lines = text.splitlines()
    pages = [all_lines[i:i + lines_per_page]
             for i in range(0, len(all_lines), lines_per_page)] or [[]]

    objects: list[bytes] = []

    def add(obj: bytes) -> int:
        objects.append(obj)
        return len(objects)

    catalog = add(b"")  # filled in below
    pages_obj = add(b"")
    font = add(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica "
               b"/Encoding /WinAnsiEncoding >>")
    page_ids = []
    for page_lines in pages:
        stream = b"BT /F1 10 Tf 14 TL 50 800 Td " + b" ".join(
            b"(" + _pdf_escape(l) + b") '" for l in page_lines) + b" ET"
        content = add(b"<< /Length %d >>\nstream\n" % len(stream) + stream +
                      b"\nendstream")
        page_ids.append(add(
            b"<< /Type /Page /Parent %d 0 R /MediaBox [0 0 595 842] "
            b"/Resources << /Font << /F1 %d 0 R >> >> /Contents %d 0 R >>"
            % (pages_obj, font, content)))
    objects[catalog - 1] = b"<< /Type /Catalog /Pages %d 0 R >>" % pages_obj
    kids = b" ".join(b"%d 0 R" % p for p in page_ids)
    objects[pages_obj - 1] = b"<< /Type /Pages /Kids [%s] /Count %d >>" % (
        kids, len(page_ids))

    out = io.BytesIO()
    out.write(b"%PDF-1.4\n")
    offsets = []
    for i, obj in enumerate(objects, start=1):
        offsets.append(out.tell())
        out.write(b"%d 0 obj\n" % i + obj + b"\nendobj\n")
    xref = out.tell()
    out.write(b"xref\n0 %d\n0000000000 65535 f \n" % (len(objects) + 1))
    for off in offsets:
        out.write(b"%010d 00000 n \n" % off)
    out.write(b"trailer\n<< /Size %d /Root %d 0 R >>\nstartxref\n%d\n%%%%EOF\n"
              % (len(objects) + 1, catalog, xref))
    return out.getvalue()
