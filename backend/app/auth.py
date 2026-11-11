"""Checks that requests come from a signed-in Verixa user.

The app sends the user's Firebase ID token as `Authorization: Bearer <token>`.
We verify it with google-auth (installed with firebase-admin): the signature
is checked against Google's public keys, then audience, issuer, expiry and
subject — the checks Firebase documents for third-party verification.
No service-account key file is needed.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from functools import lru_cache

import cachecontrol
import requests
from fastapi import Header, HTTPException, status
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token

from .config import settings

log = logging.getLogger("verixa.auth")


@dataclass
class CurrentUser:
    uid: str
    phone: str | None = None


@lru_cache(maxsize=1)
def _request() -> google_requests.Request:
    # Caches Google's public signing keys between requests (HTTP cache headers).
    return google_requests.Request(session=cachecontrol.CacheControl(requests.Session()))


def verify_firebase_id_token(token: str) -> dict:
    """Returns the token's claims, or raises ValueError if it isn't valid
    for our Firebase project."""
    project = settings.firebase_project_id
    claims = id_token.verify_firebase_token(token, _request(), audience=project)
    if not claims:
        raise ValueError("Token could not be verified.")
    if claims.get("iss") != f"https://securetoken.google.com/{project}":
        raise ValueError("Token was issued for a different project.")
    if not claims.get("sub"):
        raise ValueError("Token has no user ID.")
    return claims


def current_user(authorization: str | None = Header(default=None)) -> CurrentUser:
    """FastAPI dependency: 401 unless a valid Firebase ID token is sent."""
    if settings.auth_mode == "disabled":
        return CurrentUser(uid="local-test-user")

    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Sign in to use this feature.")
    token = authorization.split(" ", 1)[1].strip()
    try:
        claims = verify_firebase_id_token(token)
    except Exception as exc:  # expired, wrong project, bad signature, malformed…
        # Log the reason (never the token) to make 401s easy to debug.
        log.warning("Rejected Firebase token: %s: %s", type(exc).__name__, exc)
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED, "Your session has expired. Sign in again."
        ) from exc
    return CurrentUser(uid=claims["sub"], phone=claims.get("phone_number"))
