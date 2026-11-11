"""Turns an uploaded PDF or DOCX into plain text lines.

The PDF path also keeps word-level style info (font size, colour), which
the Phase 7 security scanner will use to spot hidden or tiny text.
"""

from __future__ import annotations

import io
from dataclasses import dataclass, field

import pdfplumber
from docx import Document


class UnsupportedFileError(ValueError):
    """The file isn't a readable PDF or DOCX."""


@dataclass
class StyledWord:
    text: str
    page: int
    size: float
    font: str
    color: tuple | None


@dataclass
class ExtractedDocument:
    file_type: str  # "pdf" or "docx"
    lines: list[str]
    pages: int = 1
    words: list[StyledWord] = field(default_factory=list)

    @property
    def text(self) -> str:
        return "\n".join(self.lines)


def detect_file_type(data: bytes) -> str:
    """Checks the file's magic bytes rather than trusting its name."""
    if data.startswith(b"%PDF"):
        return "pdf"
    if data.startswith(b"PK\x03\x04"):  # DOCX is a ZIP archive
        return "docx"
    raise UnsupportedFileError("Only PDF and DOCX files are supported.")


def _clean(lines: list[str]) -> list[str]:
    out = []
    for line in lines:
        line = " ".join(line.replace(" ", " ").split())
        if line:
            out.append(line)
    return out


def extract_pdf(data: bytes) -> ExtractedDocument:
    try:
        with pdfplumber.open(io.BytesIO(data)) as pdf:
            lines: list[str] = []
            words: list[StyledWord] = []
            for page_no, page in enumerate(pdf.pages, start=1):
                lines.extend((page.extract_text() or "").splitlines())
                for w in page.extract_words(
                    extra_attrs=["size", "fontname", "non_stroking_color"]
                ):
                    color = w.get("non_stroking_color")
                    words.append(
                        StyledWord(
                            text=w["text"],
                            page=page_no,
                            size=float(w.get("size") or 0),
                            font=str(w.get("fontname") or ""),
                            color=tuple(color) if isinstance(color, (list, tuple)) else None,
                        )
                    )
            return ExtractedDocument("pdf", _clean(lines), len(pdf.pages), words)
    except Exception as exc:  # pdfminer raises many different errors
        raise UnsupportedFileError("This PDF couldn't be read.") from exc


def extract_docx(data: bytes) -> ExtractedDocument:
    try:
        doc = Document(io.BytesIO(data))
    except Exception as exc:
        raise UnsupportedFileError("This DOCX couldn't be read.") from exc
    lines = [p.text for p in doc.paragraphs]
    # Many resume templates put content in tables.
    for table in doc.tables:
        for row in table.rows:
            for cell in row.cells:
                lines.extend(p.text for p in cell.paragraphs)
    return ExtractedDocument("docx", _clean(lines))


def extract(data: bytes) -> ExtractedDocument:
    kind = detect_file_type(data)
    doc = extract_pdf(data) if kind == "pdf" else extract_docx(data)
    if not doc.lines:
        raise UnsupportedFileError(
            "No text found. Scanned (image-only) resumes aren't supported yet."
        )
    return doc
