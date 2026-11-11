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
from .extraction import UnsupportedFileError, extract
from .models import ParsedResume
from .parsing import parse_resume
from .parsing.common import nlp

log = logging.getLogger("verixa")

@asynccontextmanager
async def _lifespan(_: FastAPI):
    nlp()  # load spaCy once at startup, not on the first request
    yield


app = FastAPI(
    title="Verixa API",
    version="0.6.0",
    description="Resume parsing for the Verixa app (feature 6).",
    lifespan=_lifespan,
)


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "version": app.version}


@app.post("/v1/resumes/parse", response_model=ParsedResume)
async def parse(
    file: UploadFile = File(..., description="Resume as PDF or DOCX"),
    user: CurrentUser = Depends(current_user),
) -> ParsedResume:
    """Extracts profile information from a resume.

    The file is processed in memory and never stored."""
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

    result = parse_resume(document)
    # Log sizes only — never resume content.
    log.info("parsed resume uid=%s type=%s lines=%d sections=%s",
             user.uid, document.file_type, len(document.lines), result.meta.sectionsFound)
    return result
