"""Checks that what users upload or paste is what the screen asks for.

* is_resume: an uploaded document must be a resume / CV (not an invoice,
  certificate, question paper, job description, essay …).
* is_job_description: pasted text must be a job description (not a resume,
  random text or a few words).
* review_problem: a company review must be about working or interviewing
  there, and not abusive or spam.

Each check combines NLP signals: resume / job-posting section structure,
named things found in the text (contact details, degrees, dates, skills
from our skill lexicon), cue phrases for other document types, and, when the
MiniLM model is available, similarity by meaning to prototype descriptions
of each document type.
"""

from .classify import (Verdict, is_job_description, is_requirements, is_resume,
                       review_problem)

__all__ = ["Verdict", "is_job_description", "is_requirements", "is_resume", "review_problem"]
