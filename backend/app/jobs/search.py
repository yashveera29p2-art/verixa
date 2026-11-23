"""Job search through the Adzuna API (https://developer.adzuna.com).

Set VERIXA_ADZUNA_APP_ID and VERIXA_ADZUNA_APP_KEY on the server. Without
them (or if Adzuna fails) we return the bundled sample listings, marked
source="sample". Results are cached for 30 minutes to stay well inside the
free plan's limits.
"""

from __future__ import annotations

import json
import logging
import re
import time
from functools import lru_cache
from pathlib import Path

import requests
from pydantic import BaseModel

from ..config import settings

log = logging.getLogger("verixa.jobs")

_API = "https://api.adzuna.com/v1/api/jobs/in/search/{page}"
_CACHE: dict[tuple, tuple[float, list["JobListing"]]] = {}
_TTL = 30 * 60


class JobListing(BaseModel):
    id: str
    title: str
    company: str
    location: str = ""
    description: str = ""
    url: str = ""
    salaryMin: float | None = None  # yearly, INR; 0 = unpaid
    salaryMax: float | None = None
    contract: str = ""  # "full_time" | "part_time" | "internship" | ""
    postedAt: str = ""
    source: str = "adzuna"  # "adzuna" | "sample"


def _clean(text: str) -> str:
    # Adzuna wraps matched words in <strong>; dropping the tags can leave
    # double spaces ("Java  SQL"), so whitespace is collapsed too.
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", text or "")).strip()


def _contract(title: str, contract_time: str | None, contract_type: str | None) -> str:
    if re.search(r"\bintern(ship)?\b|\btrainee\b", title, re.I):
        return "internship"
    if contract_time in ("full_time", "part_time"):
        return contract_time
    return "full_time" if contract_type == "permanent" else ""


def _adzuna(query: str, location: str, page: int, internship: bool) -> list[JobListing]:
    what = query or "software developer"
    if internship and "intern" not in what.lower():
        what += " intern"
    params = {
        "app_id": settings.adzuna_app_id,
        "app_key": settings.adzuna_app_key,
        "results_per_page": 20,
        "what": what,
        "content-type": "application/json",
    }
    if location:
        params["where"] = location
    r = requests.get(_API.format(page=max(1, page)), params=params, timeout=12)
    r.raise_for_status()
    out = []
    for j in r.json().get("results", []):
        title = _clean(j.get("title", ""))
        out.append(JobListing(
            id=f"az-{j.get('id')}",
            title=title,
            company=(j.get("company") or {}).get("display_name", "") or "Company not listed",
            location=(j.get("location") or {}).get("display_name", ""),
            description=_clean(j.get("description", "")),
            url=j.get("redirect_url", ""),
            salaryMin=j.get("salary_min"),
            salaryMax=j.get("salary_max"),
            contract=_contract(title, j.get("contract_time"), j.get("contract_type")),
            postedAt=j.get("created", ""),
            source="adzuna",
        ))
    return out


@lru_cache(maxsize=1)
def _samples() -> tuple[JobListing, ...]:
    data = json.loads((Path(__file__).parent / "samples.json").read_text(encoding="utf-8"))
    return tuple(JobListing(**j, source="sample") for j in data)


def _matches(job: JobListing, query: str, location: str, internship: bool) -> bool:
    if internship and job.contract != "internship":
        return False
    if location and location.lower() not in job.location.lower():
        return False
    words = [w for w in re.findall(r"[a-z0-9+#]+", query.lower()) if len(w) > 1]
    text = f"{job.title} {job.description} {job.company}".lower()
    return not words or any(w in text for w in words)


def adzuna_enabled() -> bool:
    return bool(settings.adzuna_app_id and settings.adzuna_app_key)


def search_jobs(query: str = "", location: str = "", page: int = 1,
                internship: bool = False) -> tuple[str, list[JobListing]]:
    """Returns (source, listings): source is "adzuna" or "sample"."""
    if adzuna_enabled():
        key = (query.lower().strip(), location.lower().strip(), page, internship)
        hit = _CACHE.get(key)
        if hit and time.time() - hit[0] < _TTL:
            return "adzuna", hit[1]
        try:
            jobs = _adzuna(query, location, page, internship)
            _CACHE[key] = (time.time(), jobs)
            if len(_CACHE) > 300:
                _CACHE.pop(next(iter(_CACHE)))
            return "adzuna", jobs
        except Exception as exc:  # network, quota, bad key …
            log.warning("Adzuna search failed, using samples: %s", exc)
    samples = list(_samples())
    picked = [j for j in samples if _matches(j, query, location, internship)]
    # Sample mode should never look empty: fall back to every sample.
    if not picked and not location and not internship:
        picked = samples
    return "sample", picked[(page - 1) * 20: page * 20]
