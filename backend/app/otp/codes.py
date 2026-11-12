"""OTP codes and signed, stateless OTP sessions.

`issue()` makes a 6-digit code and a session token. The token holds the
phone, an expiry, a random id and an HMAC of (phone, expiry, id, code), so
the server needs no database: `check()` recomputes the HMAC with the code
the user typed. The code itself is never stored or sent back to the app.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import re
import secrets
import time
from dataclasses import dataclass

CODE_LENGTH = 6
TTL_SECONDS = 5 * 60
INDIAN_MOBILE = re.compile(r"^\+91[6-9]\d{9}$")


class OtpError(Exception):
    """A problem the user can fix; the message is shown in the app."""


def normalise_phone(raw: str) -> str:
    """'+91 98765-43210', '9876543210' → '+919876543210'. India only."""
    digits = re.sub(r"\D", "", raw or "")
    if len(digits) == 10:
        digits = "91" + digits
    phone = "+" + digits
    if not INDIAN_MOBILE.match(phone):
        raise OtpError("Enter a valid 10-digit Indian mobile number.")
    return phone


def new_code() -> str:
    return f"{secrets.randbelow(10 ** CODE_LENGTH):0{CODE_LENGTH}d}"


@dataclass
class Session:
    phone: str
    expires: int
    sid: str


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode().rstrip("=")


def _unb64(text: str) -> bytes:
    return base64.urlsafe_b64decode(text + "=" * (-len(text) % 4))


def _mac(secret: bytes, phone: str, expires: int, sid: str, code: str) -> str:
    msg = f"{phone}|{expires}|{sid}|{code}".encode()
    return _b64(hmac.new(secret, msg, hashlib.sha256).digest())


def issue(secret: bytes, phone: str, code: str, now: float | None = None) -> str:
    expires = int((time.time() if now is None else now) + TTL_SECONDS)
    sid = secrets.token_urlsafe(9)
    body = {"p": phone, "e": expires, "s": sid, "m": _mac(secret, phone, expires, sid, code)}
    return _b64(json.dumps(body, separators=(",", ":")).encode())


def read(token: str) -> tuple[Session, str]:
    """Parses a session token (without checking the code)."""
    try:
        body = json.loads(_unb64(token))
        return Session(phone=body["p"], expires=int(body["e"]), sid=body["s"]), body["m"]
    except Exception as exc:  # malformed / tampered
        raise OtpError("This code has expired. Tap “Resend code” to get a new one.") from exc


def check(secret: bytes, token: str, code: str, now: float | None = None) -> Session:
    """Returns the session if [code] is right and not expired; raises OtpError."""
    session, mac = read(token)
    if (time.time() if now is None else now) > session.expires:
        raise OtpError("This code has expired. Tap “Resend code” to get a new one.")
    code = re.sub(r"\D", "", code or "")
    expected = _mac(secret, session.phone, session.expires, session.sid, code)
    if len(code) != CODE_LENGTH or not hmac.compare_digest(expected, mac):
        raise OtpError("That code is incorrect. Check and try again.")
    return session
