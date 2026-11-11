"""Verixa API.

Run locally:  uvicorn app.main:app --host 0.0.0.0 --port 8001 --reload
The Android emulator reaches this at http://10.0.2.2:8001.
"""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, File, HTTPException, Response, UploadFile, status

from .auth import CurrentUser, current_user
from .config import settings
from .export import ResumeIn, cover_letter_docx, resume_docx
from .export.docx_export import CoverLetterIn
from .extraction import ExtractedDocument, UnsupportedFileError, extract
from pydantic import BaseModel, Field

from .matching import match_profile
from .matching.matcher import semantic_available
from .matching.profile import ProfileIn
from .models import MatchReport, ParsedResume, ScanReport
from .parsing import parse_resume
from .parsing.common import nlp
from .security import scan_resume

log = logging.getLogger("verixa")

@asynccontextmanager
async def _lifespan(_: FastAPI):
    nlp()  # load spaCy once at startup, not on the first request
    semantic_available()  # load the sentence-transformers model (Phase 8)
    yield


app = FastAPI(
    title="Verixa API",
    version="0.9.0",
    description="Resume parsing, security scanning, job matching and DOCX export for the Verixa app.",
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


class MatchRequest(BaseModel):
    jobDescription: str = Field(min_length=50, max_length=20_000)
    profile: ProfileIn


@app.post("/v1/jobs/match", response_model=MatchReport)
def match_job(
    body: MatchRequest,
    user: CurrentUser = Depends(current_user),
) -> MatchReport:
    """Analyses a job description and matches it against the user's profile
    by meaning (feature 8). Runs in a worker thread: embedding is CPU work."""
    report = match_profile(body.jobDescription, body.profile)
    log.info("matched job uid=%s requirements=%d score=%d semantic=%s",
             user.uid, len(report.requirements), report.matchScore, report.semantic)
    return report


DOCX = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"


@app.post("/v1/export/resume.docx")
def export_resume(
    body: ResumeIn,
    user: CurrentUser = Depends(current_user),
) -> Response:
    """Lays out a resume the app built from the user's profile as DOCX."""
    log.info("export resume docx uid=%s blocks=%d", user.uid, len(body.blocks))
    return Response(resume_docx(body), media_type=DOCX)


@app.post("/v1/export/cover-letter.docx")
def export_cover_letter(
    body: CoverLetterIn,
    user: CurrentUser = Depends(current_user),
) -> Response:
    log.info("export cover letter docx uid=%s", user.uid)
    return Response(cover_letter_docx(body), media_type=DOCX)
