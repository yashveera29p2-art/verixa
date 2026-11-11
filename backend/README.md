# Verixa backend

Python + FastAPI service for the Verixa app. Phase 6: resume upload and
parsing (feature 6). Uploaded files are processed in memory and never stored.

## Setup (Windows, once)

```powershell
cd backend
python -m venv .venv
.venv\Scripts\python -m pip install torch --index-url https://download.pytorch.org/whl/cpu
.venv\Scripts\python -m pip install -r requirements-dev.txt
```

## Run

```powershell
cd backend
.venv\Scripts\python -m uvicorn app.main:app --host 0.0.0.0 --port 8001 --reload
```

- API docs: http://localhost:8001/docs
- The Android emulator reaches the API at `http://10.0.2.2:8001`.
- A real phone on the same Wi-Fi uses your PC's LAN IP instead
  (run the app with `--dart-define=VERIXA_API_URL=http://<pc-ip>:8001`).

## Test

```powershell
.venv\Scripts\python -m pytest
```

## Endpoints

| Method | Path | Notes |
|---|---|---|
| GET | `/health` | Liveness check |
| POST | `/v1/resumes/scan` | Multipart `file`. Security scan + estimated ATS score + visible-text parse. |
| POST | `/v1/jobs/match` | JSON `{jobDescription, profile}`. JD analysis and semantic match. |
| POST | `/v1/resumes/parse` | Multipart `file` (PDF or DOCX, ≤ 5 MB). Requires `Authorization: Bearer <Firebase ID token>`. |

## Settings (environment variables)

| Variable | Default | Meaning |
|---|---|---|
| `VERIXA_FIREBASE_PROJECT` | `verixa-app` | Firebase project whose ID tokens are accepted |
| `VERIXA_AUTH_MODE` | `firebase` | `disabled` skips the token check — **tests only** |
| `VERIXA_MAX_UPLOAD_MB` | `5` | Upload size limit |

## How parsing works

1. **Extraction** (`app/extraction.py`): PDF via pdfplumber (text plus
   word-level font size/colour, used by the Phase 7 scanner), DOCX via
   python-docx (paragraphs and tables).
2. **Sections** (`parsing/sections.py`): heading detection with common
   synonyms ("Academic Qualifications" → education).
3. **Contact** (`parsing/contact.py`): regex for email, Indian phone formats
   and links; spaCy NER confirms the name.
4. **Education** (`parsing/education.py`): 10th / 12th / degree / diploma,
   board, institution, CGPA or percentage, year, branch.
5. **Experience & projects** (`parsing/entries.py`): entries split by
   header lines and bullets; roles and companies via keywords + spaCy ORG.
6. **Skills** (`parsing/skills.py`): dictionary classification and spaCy
   `PhraseMatcher` over `parsing/data/*.txt` (easy to extend).

Known limits: scanned image-only PDFs have no text; two-column layouts can
mix up section order.

## Export (Phase 9)

- `POST /v1/export/resume.docx` — body: the resume the app built from the
  user's profile (`name`, `headline`, `contact`, `blocks`, `template`).
  Returns a single-column, ATS-friendly DOCX.
- `POST /v1/export/cover-letter.docx` — body: `name`, `contact`, `text`.

PDFs are generated on the phone (Flutter `pdf` package); DOCX here with
python-docx. Nothing is stored on the server.
