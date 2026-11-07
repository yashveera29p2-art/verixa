# Verixa — AI-Powered Resume Intelligence & Builder

Verixa is a mobile app (Android first, iOS later) that helps students, freshers and working
professionals in India build genuine, ATS-friendly resumes, check resumes for manipulation
(prompt injection, hidden text, keyword stuffing), and tailor resumes to company types and job
descriptions. It is an academic NLP project that should also be good enough to ship.

Read this file fully before every task. It is the single source of truth for design and behaviour.
If something here conflicts with a request, ask before deviating.

---

## 1. Tech stack

| Layer | Choice |
|---|---|
| App | Flutter (latest stable), Dart 3 |
| State management | Riverpod |
| Routing | go_router |
| Auth | Firebase Authentication — phone number OTP (required); Google/Gmail sign-in optional, linkable later |
| Database | Cloud Firestore |
| File storage | Firebase Storage (uploaded resumes, generated PDFs) |
| NLP backend (later phases) | Python + FastAPI, spaCy, sentence-transformers |
| Fonts | `google_fonts` package: DM Serif Display (headings), DM Sans (body, buttons, labels) |

Rules:
- Ask before adding any package not listed here.
- Keep business logic out of widgets (layered: UI → providers/controllers → repositories → services).
- During development use Firebase **test phone numbers** for OTP, not real SMS.

### Folder structure

```
lib/
  main.dart
  app/            # app widget, router, theme
  core/
    theme/        # colour tokens, typography, spacing — the ONLY place colours are defined
    widgets/      # shared widgets (buttons, glass nav bar, cards, inputs)
    utils/
  features/
    splash/
    auth/
    home/
    companies/    # MNC / SME / Startup lists and company detail
    profile/
    resume/       # builder, scanner, ATS (later phases)
assets/
  images/verixa_logo.png
  data/companies.json
```

---

## 2. Design system (global — applies to EVERY screen)

### Colour tokens

Define these once in `lib/core/theme/` and reuse everywhere. Never hard-code hex values in widgets.
Never invent new primary colours for individual pages.

| Token | Hex | Target share | Use |
|---|---|---:|---|
| `ivory` | `#F5F1E8` | 40% | Main backgrounds, page surfaces, large sections |
| `botanicalGreen` | `#365C47` | 40% | Brand, primary buttons, active/selected states, prominent filled sections |
| `charcoal` | `#292D2B` | 20% | Headings, important text, icons, dark contrast sections |
| `white` | `#FFFFFF` | max 4% | Small cards/highlights only — never the dominant background |
| `stone` | `#D9D4C9` | — | Borders, dividers, separators |
| `softSage` | `#A8B8AA` | — | Secondary backgrounds, subtle highlights, inactive states |
| `mutedText` | `#626A63` | — | Secondary/supporting text |

Splash-only brand tokens (sampled from the logo; used ONLY on the splash screen):

| Token | Hex | Use |
|---|---|---|
| `splashBgTop` | `#002C28` | Splash background (radial/top) |
| `splashBgBottom` | `#001F1E` | Splash background (edges/bottom) |
| `logoGreen` | `#11D258` | The N and the V |
| `logoGreenDeep` | `#029932` | Shading on the V |
| `logoCream` | `#FCEFDF` | Cream parts of Λ and the letters E R I X |
| `logoCharcoal` | `#3D3A3A` | Dark upper part of Λ |

Botanical green must be clearly visible (filled sections, cards, selected tabs), not limited to
tiny icons.

### Typography
- Headings: DM Serif Display (Lora as fallback).
- Body: DM Sans (Inter as fallback).
- Buttons and labels: DM Sans, medium weight.
- Clear hierarchy, comfortable line height and spacing.

### Style
Premium, minimal but not empty, professional, editorial. It should look like a premium writing and
career platform, not a generic AI dashboard.

Avoid: neon colours, glow effects, unnecessary gradients (the splash background is the only
exception), heavy shadows, overly rounded "bubbly" cards, random colour variations, colourful
illustrations.

Resume templates that users pick can have their own themes; the app UI itself always uses this palette.

---

## 3. App flow

```
App launch → Splash animation (every launch, all users)
  ├─ Not logged in → Welcome: [Create account] [Log in]
  │                    → Phone number → OTP → (new user) basic onboarding → Home
  └─ Logged in     → Home
```

### 3.1 Splash animation (plays on EVERY launch, new and existing users)

Total target: about 2–2.5 s. While it plays, check the auth session in the background so the next
screen opens instantly.

1. **0.0 s** — Full-screen background in the logo's dark green (`splashBgTop` → `splashBgBottom`).
   A single letter **N** in `logoGreen`, centred.
2. **0.5 s** — The N **flips** (3D rotation on the Y axis, ~400 ms). The N is drawn with slanted
   strokes in the same ribbon style as the monogram, so its mirror image is the **VΛ** monogram.
   After the flip, the VΛ monogram from the logo is shown (V green, Λ charcoal/cream).
3. **Then** — V slides left and Λ slides right (~400 ms, ease-out), opening a gap.
4. **Then** — The letters **E R I X** appear in the gap one at a time with a keyboard-typing
   effect (~100 ms per letter), so the word reads **VERIXA** (V and Λ act as the first and last letters).
5. Short hold (~300 ms), then fade to the next screen.

Defaults (easy to change): no blinking cursor during typing; fade transition to the next screen.

Build the animation with Flutter's animation APIs (AnimationController / Transform with Matrix4
for the flip) or a Rive file. Draw the N and VΛ as vector paths (CustomPainter or SVG) so the flip
looks seamless.

### 3.2 Authentication
- Account identity = **phone number** (required, OTP-verified). Paid plans are planned later and
  will be tied to this account.
- Gmail is **optional**; it can be linked later from Profile.
- After the first sign-up, run a short onboarding: full name, status (Student / Fresher /
  Working professional), college or company. Everything else is collected step by step from
  Profile (see section 5).

### 3.3 Bottom navigation bar (on main screens)
- Frosted glass style: translucent ivory with background blur, thin `stone` border, no glow,
  no heavy shadow.
- Three items: **Home** | a **slightly larger circle in the centre with a document-outline icon** |
  **Profile**.
- Active item uses `botanicalGreen`; inactive items use `softSage`/`mutedText`.
- The centre button opens the resume actions (bottom sheet): Create resume, Upload & scan resume,
  Match with a job description. Until those features exist, show the sheet with "Coming soon" states.

---

## 4. Home screen

- **Greeting** at the top using the phone's local time and the user's first name, in DM Serif Display, charcoal on ivory:
  - 04:00–11:59 → "Good morning, {name}"
  - 12:00–16:59 → "Good afternoon, {name}"
  - 17:00–03:59 → "Good evening, {name}"
- **Three category sections:** **MNC**, **SME**, **Startup**. Each is a prominent card with a
  botanical green fill, ivory title, a one-line description and a simple line icon
  (building / briefcase / rocket).
- Bottom navigation bar as in 3.3.

### 4.1 Company category screens (MNC / SME / Startup)

Tapping a category opens a list of companies in that category.

**Company list:** name, logo placeholder (initials; no scraped logos), sector, one-line summary of
what they look for.

**Company detail screen:**
- What the company typically expects from candidates (skills, academics, experience, traits).
- The resume pattern that suits them: recommended section order, length (1 page / 2 pages),
  what to emphasise (e.g. CGPA and certifications for MNC mass hiring; projects, shipped work and
  ownership for startups), ATS considerations.
- A "Build a resume for this company type" button (wired up in a later phase).

**Data:**
- Phase 1: local seed file `assets/data/companies.json`, India-focused, roughly 8–10 companies per
  category. Move to Firestore later.
- Content is **general guidance based on public hiring patterns**, not official statements from the
  companies. Show a small note on the detail screen saying so, and keep a `sources` field (careers
  page URL) and `lastReviewed` date per company.
- Later: derive expectations automatically from real job descriptions using NLP (feature 8).

Suggested schema:
```json
{
  "id": "string",
  "name": "string",
  "category": "MNC | SME | Startup",
  "sector": "string",
  "summary": "string",
  "expectations": { "skills": [], "academics": "string", "experience": "string", "traits": [] },
  "resumePattern": { "length": "string", "sectionOrder": [], "emphasise": [], "avoid": [], "atsNotes": "string" },
  "sources": [],
  "lastReviewed": "YYYY-MM-DD"
}
```

---

## 5. Profile data to collect (step by step, not all at signup)

Show a profile-completion indicator. Branch the questions by status.

1. **Account & contact:** phone (verified), Gmail (optional), full name, city/state, LinkedIn,
   GitHub, portfolio (optional), photo (optional), date of birth (optional).
2. **Status:**
   - Student → college, degree, branch, current year/semester, expected graduation year, CGPA.
   - Fresher → same education fields + graduation year + target role.
   - Working professional → company, designation, start date, total years of experience.
3. **Education history:** 10th and 12th (board, school, percentage/CGPA, year); diploma/PG if any.
4. **Career goal:** target role/domain, short objective.
5. **Experience:** internships and jobs (company, role, duration, description).
6. **Projects:** title, description, tech stack, link, duration.
7. **Skills:** technical, tools, soft skills, spoken languages.
8. **Extras (optional):** certifications, hackathons and coding ranks, publications, positions of
   responsibility, clubs, NSS/NCC, volunteering, hobbies.

Later, users can also fill this by uploading an old resume (NLP parsing, feature 6) or typing free
text that gets parsed into fields.

---

## 6. Feature roadmap (the 10 core features)

1. **Resume Security Scanner** — detect prompt injections, hidden white text, keyword stuffing,
   invisible content and ATS manipulation techniques.
2. **In-app security warnings** — detailed alerts naming the suspicious content and the technique.
3. **ATS score & threat report** — estimated ATS compatibility score plus detected issues and
   where they are in the resume.
4. **Correction suggestions** — remove manipulative content; convert into a genuine, well-structured resume.
5. **Scan history** — uploaded resumes, threats found, reports, ATS scores, corrections.
6. **Intelligent resume parsing** — extract personal, academic, professional, technical and project
   info from uploaded resumes using NLP.
7. **Centralised professional profile** — structured store of qualifications, skills,
   certifications, experience, achievements and projects.
8. **Job description analysis & matching** — extract requirements from a JD and compare them with
   the profile using semantic similarity.
9. **AI resume generation** — customised, ATS-friendly resumes using only genuine profile data.
10. **Resume optimisation & management** — job-alignment scores, multiple resume versions,
    cover letters, PDF/DOCX export.

---

## 7. Build phases

Work one phase at a time. At the end of each phase: run `flutter analyze`, make sure the app runs
on the emulator, summarise what was built, and list anything I need to do manually (e.g. Firebase
console steps). Then stop and wait.

1. Project setup, theme tokens, typography, shared widgets, splash animation.
2. Firebase setup, phone OTP sign-up/login, optional Google link, auth routing.
3. Home screen (greeting, three category cards), glass bottom nav bar, centre-button bottom sheet.
4. Company category lists and company detail screens with seed data.
5. Profile screen and step-by-step profile onboarding (section 5), saved to Firestore.
6. Python FastAPI backend: resume upload and parsing (feature 6).
7. Security scanner, warnings, ATS score and threat report, scan history (features 1–5).
8. JD analysis and matching (feature 8).
9. Resume generation, versions, cover letters, PDF/DOCX export (features 9–10).

## 8. Working rules for Claude
- Explain briefly what you are about to change before large edits.
- Do not rewrite working features when adding new ones.
- Keep all colours, text styles and spacing in `core/theme`.
- Keep the code readable for a student team: clear names, short widgets, comments only where the
  logic is non-obvious.
- Remind me to commit to Git after each phase.
