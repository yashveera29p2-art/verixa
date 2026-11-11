"""Verixa API.

Run locally:  uvicorn app.main:app --host 0.0.0.0 --port 8001 --reload
The Android emulator reaches this at http://10.0.2.2:8001.
"""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, File, HTTPException, UploadFile, status

from .auth import CurrentUser, current_user
from .config import settings
from .extraction import ExtractedDocument, UnsupportedFileError, extract
from .models import ParsedResume, ScanReport
from .parsing import parse_resume
from .parsing.common import nlp
from .security import scan_resume

log = logging.getLogger("verixa")

@asynccontextmanager
async def _lifespan(_: FastAPI):
    nlp()  # load spaCy once at startup, not on the first request
    yield


app = FastAPI(
    title="Verixa API",
    version="0.7.0",
    description="Resume parsing and security scanning for the Verixa app.",
    lifespan=_lifespan,
)


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "version": app.version}


async def _read_document(file: UploadFile) -> ExtractedDocument:
    """Size, emptiness and type checks shared by every upload endpoint.
    Files are processed in memory and never stored."""
    data = await file.read(settings.max_upload_bytes + 1)
    if len(data) > settings.max_upload_bytes:
        raise HTTPException(
            status.HTTP_413_CONTENT_TOO_LARGE,
            f"File is larger than {settings.max_upload_bytes // (1024 * 1024)} MB.",
        )
    if not data:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "The file is empty.")
    try:
        return extract(data)
    except UnsupportedFileError as exc:
        raise HTTPException(status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, str(exc)) from exc


@app.post("/v1/resumes/parse", response_model=ParsedResume)
async def parse(
    file: UploadFile = File(..., description="Resume as PDF or DOCX"),
    user: CurrentUser = Depends(current_user),
) -> ParsedResume:
    """Extracts profile information from the resume's visible text."""
    document = await _read_document(file)
    result = parse_resume(document)
    # Log sizes only — never resume content.
    log.info("parsed resume uid=%s type=%s lines=%d sections=%s",
             user.uid, document.file_type, len(document.lines), result.meta.sectionsFound)
    return result


@app.post("/v1/resumes/scan", response_model=ScanReport)
async def scan(
    file: UploadFile = File(..., description="Resume as PDF or DOCX"),
    user: CurrentUser = Depends(current_user),
) -> ScanReport:
    """Security scan (hidden text, prompt injection, keyword stuffing,
    invisible characters), estimated ATS score, suggestions, and the
    visible-text parse for importing genuine details."""
    document = await _read_document(file)
    report = scan_resume(document)
    log.info("scanned resume uid=%s type=%s risk=%s threats=%d score=%d",
             user.uid, document.file_type, report.riskLevel, len(report.threats),
             report.atsScore)
    return report
