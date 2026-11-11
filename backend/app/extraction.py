"""Turns an uploaded PDF or DOCX into text — twice.

* ``lines``: everything a machine (an ATS) reads, including hidden text.
* ``visible_lines``: only what a human reader would actually see.

The difference between the two is exactly what the security scanner
(Phase 7) looks for; resume parsing uses the visible text only, so hidden
keywords never end up in the user's profile.
"""

from __future__ import annotations

import io
from dataclasses import dataclass, field

import pdfplumber
from docx import Document
from docx.enum.dml import MSO_COLOR_TYPE

# Text this small can't be read on a printed or on-screen page.
TINY_FONT_PT = 4.0
# Colour channels at or above this (0–1) count as "white-ish".
LIGHT_THRESHOLD = 0.92


class UnsupportedFileError(ValueError):
    """The file isn't a readable PDF or DOCX."""


@dataclass
class HiddenSpan:
    """A run of text a reader can't see but an ATS can."""

    text: str
    reason: str  # "white", "tiny", "offpage", "hidden-format"
    page: int | None = None  # PDF page (1-based)
    paragraph: int | None = None  # DOCX paragraph (1-based)


@dataclass
class ExtractedDocument:
    file_type: str  # "pdf" or "docx"
    lines: list[str]  # all text, including hidden
    visible_lines: list[str] = field(default_factory=list)
    pages: int = 1
    hidden_spans: list[HiddenSpan] = field(default_factory=list)
    metadata: dict[str, str] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.visible_lines:
            self.visible_lines = list(self.lines)

    @property
    def text(self) -> str:
        return "\n".join(self.lines)

    @property
    def visible_text(self) -> str:
        return "\n".join(self.visible_lines)


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
        # Collapse normal whitespace but keep zero-width characters, which
        # the scanner needs to see.
        line = " ".join(line.replace(" ", " ").split())
        if line:
            out.append(line)
    return out


# ── PDF ─────────────────────────────────────────────────────────────────────

def _to_rgb(color) -> tuple[float, float, float] | None:
    """pdfplumber colours come as grey (1 value), RGB (3) or CMYK (4)."""
    if color is None:
        return (0.0, 0.0, 0.0)  # PDF default fill is black
    if not isinstance(color, (list, tuple)) or not color:
        return None  # patterns etc. — unknown
    try:
        values = [float(v) for v in color]
    except (TypeError, ValueError):
        return None
    if len(values) == 1:
        return (values[0],) * 3
    if len(values) == 3:
        return tuple(values)  # type: ignore[return-value]
    if len(values) == 4:
        c, m, y, k = values
        return ((1 - c) * (1 - k), (1 - m) * (1 - k), (1 - y) * (1 - k))
    return None


def _is_light(rgb) -> bool:
    return rgb is not None and min(rgb) >= LIGHT_THRESHOLD


def _dark_boxes(page) -> list[tuple[float, float, float, float]]:
    """Filled dark rectangles — white text on these is legitimate
    (e.g. a coloured header band)."""
    boxes = []
    for rect in page.rects:
        if not rect.get("fill"):
            continue
        rgb = _to_rgb(rect.get("non_stroking_color"))
        if rgb is not None and max(rgb) < 0.6:
            boxes.append((rect["x0"], rect["top"], rect["x1"], rect["bottom"]))
    return boxes


def _hidden_reason(char, page, dark_boxes) -> str | None:
    if char.get("text", "").isspace():
        return None
    x0, x1, top, bottom = char["x0"], char["x1"], char["top"], char["bottom"]
    if x1 <= 0 or x0 >= page.width or bottom <= 0 or top >= page.height:
        return "offpage"
    if float(char.get("size") or 0) < TINY_FONT_PT:
        return "tiny"
    if _is_light(_to_rgb(char.get("non_stroking_color"))):
        on_dark = any(bx0 <= x0 and x1 <= bx1 and by0 <= top and bottom <= by1
                      for bx0, by0, bx1, by1 in dark_boxes)
        if not on_dark:
            return "white"
    return None


def _pdf_hidden_spans(page, page_no: int, dark_boxes) -> list[HiddenSpan]:
    spans: list[HiddenSpan] = []
    current: list[str] = []
    reason: str | None = None
    last_top: float | None = None

    def flush() -> None:
        text = " ".join("".join(current).split())
        if text:
            spans.append(HiddenSpan(text=text, reason=reason or "", page=page_no))

    for char in page.chars:
        r = _hidden_reason(char, page, dark_boxes)
        new_line = last_top is not None and abs(char["top"] - last_top) > 2
        if char.get("text", "").isspace() and reason:
            current.append(" ")  # keep word gaps inside a hidden run
            continue
        if r != reason or (new_line and r):
            if reason:
                flush()
            current, reason = [], r
        if r:
            if new_line and current:
                current.append(" ")
            current.append(char.get("text", ""))
        last_top = char["top"]
    if reason:
        flush()
    return spans


def extract_pdf(data: bytes) -> ExtractedDocument:
    try:
        with pdfplumber.open(io.BytesIO(data)) as pdf:
            lines: list[str] = []
            visible: list[str] = []
            spans: list[HiddenSpan] = []
            for page_no, page in enumerate(pdf.pages, start=1):
                dark = _dark_boxes(page)
                lines.extend((page.extract_text() or "").splitlines())
                shown = page.filter(
                    lambda obj: obj.get("object_type") != "char"
                    or _hidden_reason(obj, page, dark) is None
                )
                visible.extend((shown.extract_text() or "").splitlines())
                spans.extend(_pdf_hidden_spans(page, page_no, dark))
            meta = {str(k): str(v) for k, v in (pdf.metadata or {}).items()
                    if isinstance(v, (str, bytes))}
            return ExtractedDocument(
                "pdf", _clean(lines), _clean(visible) or [""], len(pdf.pages),
                spans, meta,
            )
    except Exception as exc:  # pdfminer raises many different errors
        raise UnsupportedFileError("This PDF couldn't be read.") from exc


# ── DOCX ────────────────────────────────────────────────────────────────────

def _run_hidden_reason(run) -> str | None:
    font = run.font
    if font.hidden:
        return "hidden-format"
    if font.size is not None and font.size.pt < TINY_FONT_PT:
        return "tiny"
    color = font.color
    if color is not None and color.type == MSO_COLOR_TYPE.RGB and color.rgb is not None:
        rgb = tuple(int(str(color.rgb)[i:i + 2], 16) / 255 for i in (0, 2, 4))
        if _is_light(rgb):
            return "white"
    return None


def _docx_paragraphs(doc):
    yield from doc.paragraphs
    # Many resume templates put content in tables.
    for table in doc.tables:
        for row in table.rows:
            for cell in row.cells:
                yield from cell.paragraphs


def extract_docx(data: bytes) -> ExtractedDocument:
    try:
        doc = Document(io.BytesIO(data))
    except Exception as exc:
        raise UnsupportedFileError("This DOCX couldn't be read.") from exc

    lines: list[str] = []
    visible: list[str] = []
    spans: list[HiddenSpan] = []
    for number, paragraph in enumerate(_docx_paragraphs(doc), start=1):
        lines.append(paragraph.text)
        shown: list[str] = []
        for run in paragraph.runs:
            reason = _run_hidden_reason(run)
            if reason is None:
                shown.append(run.text)
            elif run.text.strip():
                last = spans[-1] if spans else None
                if last and last.paragraph == number and last.reason == reason:
                    last.text = f"{last.text}{run.text}"
                else:
                    spans.append(HiddenSpan(run.text, reason, paragraph=number))
        visible.append("".join(shown))

    props = doc.core_properties
    meta = {k: v for k, v in {
        "Title": props.title, "Subject": props.subject,
        "Keywords": props.keywords, "Comments": props.comments,
    }.items() if v}
    for span in spans:
        span.text = " ".join(span.text.split())
    return ExtractedDocument("docx", _clean(lines), _clean(visible) or [""], 1,
                             spans, meta)


def extract(data: bytes) -> ExtractedDocument:
    kind = detect_file_type(data)
    doc = extract_pdf(data) if kind == "pdf" else extract_docx(data)
    if not doc.lines:
        raise UnsupportedFileError(
            "No text found. Scanned (image-only) resumes aren't supported yet."
        )
    return doc
