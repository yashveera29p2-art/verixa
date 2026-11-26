"""Verixa API.

Run locally:  uvicorn app.main:app --host 0.0.0.0 --port 8001 --reload
The Android emulator reaches this at http://10.0.2.2:8001.
"""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi.middleware.cors import CORSMiddleware
from fastapi import Depends, FastAPI, File, HTTPException, Request, Response, UploadFile, status

from .auth import CurrentUser, current_user
from .config import settings
from .export import ResumeIn, cover_letter_docx, resume_docx
from .export.docx_export import CoverLetterIn
from . import otp
from .extraction import ExtractedDocument, UnsupportedFileError, extract
from pydantic import BaseModel, Field

from .matching import match_profile
from .matching.matcher import semantic_available
from .matching.profile import ProfileIn
from .matching.ranking import (RankCandidatesRequest, RankItem, RankJobsRequest,
                               rank_candidates, rank_jobs)
from .jobs import JobListing, search_jobs
from .sentiment import ReviewAnalysis, analyze_reviews
from .validation import is_job_description, is_requirements, is_resume, review_problem
from .writing import check_writing
from .models import MatchReport, ParsedResume, ScanReport, WritingReport
from .parsing import parse_resume
from .parsing.common import nlp
from .security import scan_resume

log = logging.getLogger("verixa")

@asynccontextmanager
async def _lifespan(_: FastAPI):
    nlp()  # load spaCy once at startup, not on the first request
    semantic_available()  # load the MiniLM matching model (Phase 8)
    yield


app = FastAPI(
    title="Verixa API",
    version="0.9.0",
    description="Resume parsing, security scanning, job matching and DOCX export for the Verixa app.",
    lifespan=_lifespan,
)

# The iPhone web app (GitHub Pages) and local web testing call the API from a
# browser, which needs CORS. Native apps don't send an Origin, so they're
# unaffected.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://yashveera29p2-art.github.io"],
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_methods=["GET", "POST"],
    allow_headers=["Authorization", "Content-Type"],
    expose_headers=["Retry-After", "Content-Disposition"],
    max_age=86400,
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
        document = extract(data)
    except UnsupportedFileError as exc:
        raise HTTPException(status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, str(exc)) from exc
    # Only resumes: invoices, certificates, question papers, job
    # descriptions etc. are turned away with a message saying what it looks like.
    verdict = is_resume(document.visible_text)
    if not verdict.ok:
        log.info("rejected upload: not a resume (%s)", verdict.kind or "unclear")
        raise HTTPException(status.HTTP_400_BAD_REQUEST, verdict.message)
    return document


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
    report.writing = check_writing(document.visible_text)
    log.info("scanned resume uid=%s type=%s risk=%s threats=%d score=%d",
             user.uid, document.file_type, report.riskLevel, len(report.threats),
             report.atsScore)
    return report


class MatchRequest(BaseModel):
    jobDescription: str = Field(min_length=1, max_length=20_000)
    profile: ProfileIn


@app.post("/v1/jobs/match", response_model=MatchReport)
def match_job(
    body: MatchRequest,
    user: CurrentUser = Depends(current_user),
) -> MatchReport:
    """Analyses a job description and matches it against the user's profile
    by meaning (feature 8). Runs in a worker thread: embedding is CPU work."""
    verdict = is_job_description(body.jobDescription)
    if not verdict.ok:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, verdict.message)
    report = match_profile(body.jobDescription, body.profile)
    log.info("matched job uid=%s requirements=%d score=%d semantic=%s",
             user.uid, len(report.requirements), report.matchScore, report.semantic)
    return report


class JobSearchRequest(BaseModel):
    query: str = Field(default="", max_length=120)
    location: str = Field(default="", max_length=80)
    page: int = Field(default=1, ge=1, le=10)
    internship: bool = False


class JobSearchResponse(BaseModel):
    source: str  # "adzuna" | "sample"
    jobs: list[JobListing]


@app.post("/v1/jobs/search", response_model=JobSearchResponse)
def jobs_search(body: JobSearchRequest,
                user: CurrentUser = Depends(current_user)) -> JobSearchResponse:
    """Job listings for the Jobs tab (Adzuna India, or sample listings)."""
    source, jobs = search_jobs(body.query, body.location, body.page, body.internship)
    return JobSearchResponse(source=source, jobs=jobs)


class RankResponse(BaseModel):
    results: list[RankItem]


@app.post("/v1/jobs/rank", response_model=RankResponse)
def jobs_rank(body: RankJobsRequest,
              user: CurrentUser = Depends(current_user)) -> RankResponse:
    """Ranks job listings for the signed-in student, with reasons and gaps."""
    results = rank_jobs(body)
    log.info("ranked jobs uid=%s n=%d", user.uid, len(results))
    return RankResponse(results=results)


@app.post("/v1/candidates/rank", response_model=RankResponse)
def candidates_rank(body: RankCandidatesRequest,
                    user: CurrentUser = Depends(current_user)) -> RankResponse:
    """Ranks opted-in students for a recruiter's job (skills, evidence and
    optional work-style fit)."""
    verdict = is_requirements(body.job.title + " " + body.job.description)
    if not verdict.ok:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, verdict.message)
    results = rank_candidates(body)
    log.info("ranked candidates uid=%s n=%d", user.uid, len(results))
    return RankResponse(results=results)


class WritingRequest(BaseModel):
    text: str = Field(min_length=1, max_length=30_000)


@app.post("/v1/writing/check", response_model=WritingReport)
def writing_check(body: WritingRequest,
                  user: CurrentUser = Depends(current_user)) -> WritingReport:
    """NLP writing review of a resume's text: weak phrases, passive voice,
    missing impact, buzzwords, first person, long sentences, readability."""
    return check_writing(body.text)


class ReviewsRequest(BaseModel):
    texts: list[str] = Field(max_length=100)
    ratings: list[int] = Field(default_factory=list, max_length=100)


@app.post("/v1/reviews/analyze", response_model=ReviewAnalysis)
def reviews_analyze(body: ReviewsRequest,
                    user: CurrentUser = Depends(current_user)) -> ReviewAnalysis:
    """Sentiment and aspects (learning, pay, work-life …) of a company's reviews."""
    return analyze_reviews([t[:2000] for t in body.texts], body.ratings)


class TextCheckRequest(BaseModel):
    kind: str = Field(pattern="^(job|requirements|review)$")
    text: str = Field(max_length=20_000)


class TextCheckResponse(BaseModel):
    ok: bool
    message: str = ""


@app.post("/v1/text/check", response_model=TextCheckResponse)
def text_check(body: TextCheckRequest,
               user: CurrentUser = Depends(current_user)) -> TextCheckResponse:
    """Checks that typed text is what the screen asks for: a job
    description, a recruiter's requirements, or a company review."""
    check = {"job": is_job_description, "requirements": is_requirements,
             "review": review_problem}[body.kind]
    verdict = check(body.text)
    return TextCheckResponse(ok=verdict.ok, message=verdict.message)


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


# ── Phone OTP login (no Firebase SMS) ──────────────────────────────────────

class OtpStart(BaseModel):
    phone: str = Field(min_length=10, max_length=20)


class OtpVerify(BaseModel):
    session: str = Field(min_length=10, max_length=600)
    code: str = Field(min_length=4, max_length=10)


def _client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for", "")
    return forwarded.split(",")[0].strip() or (request.client.host if request.client else "?")


def _otp_error(exc: otp.OtpError) -> HTTPException:
    if isinstance(exc, otp.RateLimited):
        return HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, str(exc),
                             headers={"Retry-After": str(exc.retry_after)})
    return HTTPException(status.HTTP_400_BAD_REQUEST, str(exc))


@app.post("/v1/auth/otp/start")
def otp_start(body: OtpStart, request: Request) -> dict:
    """Sends a 6-digit code by SMS. Returns a session to send back with it."""
    try:
        phone, session = otp.start(body.phone, _client_ip(request))
    except otp.OtpError as exc:
        raise _otp_error(exc) from exc
    return {"phone": phone, "session": session, "expiresIn": 300}


@app.post("/v1/auth/account/exists")
def account_exists(body: OtpStart, request: Request) -> dict:
    """Whether this phone number already has a Verixa account (no SMS sent)."""
    try:
        phone, exists = otp.exists(body.phone, _client_ip(request))
    except otp.OtpError as exc:
        raise _otp_error(exc) from exc
    return {"phone": phone, "exists": exists}


class TruecallerLogin(BaseModel):
    authorizationCode: str = Field(default="", max_length=600)
    codeVerifier: str = Field(default="", max_length=200)
    accessToken: str = Field(default="", max_length=200)


@app.post("/v1/auth/method")
def auth_method(body: OtpStart) -> dict:
    """How to verify this number: "code" (team test numbers) or "truecaller"."""
    try:
        phone, method = otp.login_method(body.phone)
    except otp.OtpError as exc:
        raise _otp_error(exc) from exc
    return {"phone": phone, "method": method}


@app.post("/v1/auth/truecaller")
def auth_truecaller(body: TruecallerLogin, request: Request) -> dict:
    """Checks a Truecaller verification and returns a Firebase custom token
    for the account that owns the verified number."""
    try:
        phone, token, is_new = otp.finish_truecaller(
            _client_ip(request), authorization_code=body.authorizationCode,
            code_verifier=body.codeVerifier, access_token=body.accessToken)
    except otp.OtpError as exc:
        raise _otp_error(exc) from exc
    return {"phone": phone, "firebaseToken": token, "isNewUser": is_new}


@app.post("/v1/auth/otp/verify")
def otp_verify(body: OtpVerify) -> dict:
    """Checks the code and returns a Firebase custom token for the one
    account that belongs to this phone number."""
    try:
        phone, token, is_new = otp.finish(body.session, body.code)
    except otp.OtpError as exc:
        raise _otp_error(exc) from exc
    return {"phone": phone, "firebaseToken": token, "isNewUser": is_new}
