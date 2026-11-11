"""Builds ATS-friendly DOCX files from the resume the app generated.

The app sends the finished resume content (built from the user's own
profile); this module only lays it out. One column, real headings and
paragraphs, standard fonts — no tables, text boxes or images, which ATS
parsers often skip.
"""

from __future__ import annotations

import io

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_TAB_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Pt, RGBColor, Cm
from pydantic import BaseModel, Field

GREEN = RGBColor(0x36, 0x5C, 0x47)
CHARCOAL = RGBColor(0x29, 0x2D, 0x2B)
MUTED = RGBColor(0x62, 0x6A, 0x63)


class ItemIn(BaseModel):
    heading: str = Field("", max_length=300)
    subheading: str = Field("", max_length=300)
    meta: str = Field("", max_length=120)
    bullets: list[str] = Field(default_factory=list, max_length=30)
    line: str = Field("", max_length=3000)
    bullet: bool = False


class BlockIn(BaseModel):
    title: str = Field(max_length=60)
    items: list[ItemIn] = Field(default_factory=list, max_length=60)


class ResumeIn(BaseModel):
    name: str = Field(max_length=120)
    headline: str = Field("", max_length=200)
    contact: list[str] = Field(default_factory=list, max_length=10)
    blocks: list[BlockIn] = Field(default_factory=list, max_length=12)
    template: str = "classic"


FONTS = {"classic": "Cambria", "modern": "Calibri", "compact": "Arial"}


def _setup(doc: Document, compact: bool, font: str = "Calibri") -> None:
    section = doc.sections[0]
    margin = Cm(1.2 if compact else 1.6)
    section.left_margin = section.right_margin = margin
    section.top_margin = section.bottom_margin = margin
    style = doc.styles["Normal"]
    style.font.name = font
    style.font.size = Pt(9.5 if compact else 10.5)
    style.font.color.rgb = CHARCOAL
    style.paragraph_format.space_after = Pt(0)


def _bottom_border(paragraph, color: str) -> None:
    """A thin rule under a section heading (real paragraph border, ATS-safe)."""
    p_pr = paragraph._p.get_or_add_pPr()
    borders = OxmlElement("w:pBdr")
    bottom = OxmlElement("w:bottom")
    for key, value in (("w:val", "single"), ("w:sz", "6"), ("w:space", "1"),
                       ("w:color", color)):
        bottom.set(qn(key), value)
    borders.append(bottom)
    p_pr.append(borders)


def _para(doc: Document, text: str = "", *, bold=False, italic=False, size=None,
          color=None, after=0.0, style=None):
    p = doc.add_paragraph(style=style)
    p.paragraph_format.space_after = Pt(after)
    if text:
        run = p.add_run(text)
        run.bold, run.italic = bold, italic
        if size:
            run.font.size = Pt(size)
        if color is not None:
            run.font.color.rgb = color
    return p


def resume_docx(r: ResumeIn) -> bytes:
    compact = r.template == "compact"
    classic = r.template == "classic"
    accent = CHARCOAL if classic else GREEN
    doc = Document()
    _setup(doc, compact, FONTS.get(r.template, "Calibri"))
    width = doc.sections[0].page_width - doc.sections[0].left_margin \
        - doc.sections[0].right_margin

    header = [
        _para(doc, r.name.upper() if classic else r.name, bold=True,
              size=18 if compact else 22, color=GREEN if r.template == "modern" else CHARCOAL),
    ]
    if r.headline:
        header.append(_para(doc, r.headline, italic=classic, size=11, color=accent))
    header.append(_para(doc, "  ·  ".join(r.contact), size=9, color=MUTED, after=4))
    if classic:
        for p in header:
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER

    for block in r.blocks:
        heading = _para(doc, block.title.upper() if not r.template == "modern" else block.title,
                        bold=True, size=10 if compact else 11.5, color=accent)
        _bottom_border(heading, "000000" if classic else "365C47")
        heading.paragraph_format.space_before = Pt(6 if compact else 10)
        heading.paragraph_format.space_after = Pt(3)
        for item in block.items:
            skill_row = item.heading and item.line and not item.subheading \
                and not item.bullets
            if item.heading or item.meta:
                p = doc.add_paragraph()
                p.paragraph_format.tab_stops.add_tab_stop(width, WD_TAB_ALIGNMENT.RIGHT)
                run = p.add_run(item.heading)
                run.bold = True
                if skill_row:
                    p.add_run(f": {item.line}")
                if item.meta:
                    meta = p.add_run(f"\t{item.meta}")
                    meta.font.color.rgb = MUTED
            if item.subheading:
                _para(doc, item.subheading, italic=True, color=MUTED)
            for b in item.bullets:
                _para(doc, b, style="List Bullet")
            if item.line and not skill_row:
                _para(doc, item.line, style="List Bullet" if item.bullet else None)
            doc.paragraphs[-1].paragraph_format.space_after = Pt(3 if compact else 5)

    out = io.BytesIO()
    doc.save(out)
    return out.getvalue()


class CoverLetterIn(BaseModel):
    name: str = Field(max_length=120)
    contact: list[str] = Field(default_factory=list, max_length=10)
    text: str = Field(min_length=20, max_length=8000)


def cover_letter_docx(c: CoverLetterIn) -> bytes:
    doc = Document()
    _setup(doc, compact=False)
    _para(doc, c.name, bold=True, size=18)
    _para(doc, "  |  ".join(c.contact), size=9, color=MUTED, after=16)
    for para in [p.strip() for p in c.text.split("\n\n") if p.strip()]:
        p = _para(doc, after=8)
        lines = para.split("\n")
        for i, line in enumerate(lines):
            run = p.add_run(line)
            if i < len(lines) - 1:
                run.add_break()
    out = io.BytesIO()
    doc.save(out)
    return out.getvalue()
