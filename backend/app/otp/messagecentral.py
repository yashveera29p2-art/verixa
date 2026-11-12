"""Message Central VerifyNow: sends OTP SMS on its own DLT-approved
template (no DLT registration needed) and checks the code on its side.

Docs: https://www.messagecentral.com/product/verify-now/api-india
"""

from __future__ import annotations

import base64
import logging
import threading
import time

import requests

from ..config import settings
from .codes import CODE_LENGTH, OtpError

log = logging.getLogger("verixa.messagecentral")

BASE = "https://cpaas.messagecentral.com"
_TOKEN_TTL = 20 * 60  # refresh well before it can expire; also refreshed on 401

_lock = threading.Lock()
_token: tuple[str, float] | None = None

_GENERIC = "Couldn’t send the code. Please try again in a minute."
_EXPIRED = "This code has expired. Tap “Resend code” to get a new one."
_WRONG = "That code is incorrect. Check and try again."


def _auth_token(refresh: bool = False) -> str:
    global _token
    if settings.mc_auth_token:  # long-lived token from their console
        return settings.mc_auth_token
    with _lock:
        if not refresh and _token and _token[1] > time.time():
            return _token[0]
        if not settings.mc_customer_id or not settings.mc_key:
            raise OtpError("SMS isn't set up on the server yet.")
        key = base64.b64encode(settings.mc_key.encode()).decode()
        try:
            r = requests.get(f"{BASE}/auth/v1/authentication/token", timeout=15, params={
                "customerId": settings.mc_customer_id, "key": key,
                "scope": "NEW", "country": "91"})
            token = r.json().get("token")
        except Exception as exc:
            log.error("token request failed: %s", exc)
            raise OtpError(_GENERIC) from exc
        if not token:
            log.error("token request refused: HTTP %s", r.status_code)
            raise OtpError(_GENERIC)
        _token = (token, time.time() + _TOKEN_TTL)
        return token


def _call(method: str, path: str, params: dict) -> tuple[int, dict]:
    """One API call, retried once with a fresh token on 401."""
    for attempt in (0, 1):
        try:
            r = requests.request(method, f"{BASE}{path}", params=params, timeout=20,
                                 headers={"authToken": _auth_token(refresh=attempt == 1)})
        except OtpError:
            raise
        except Exception as exc:
            log.error("%s failed: %s", path, exc)
            raise OtpError(_GENERIC) from exc
        if r.status_code == 401 and attempt == 0 and not settings.mc_auth_token:
            continue
        if r.status_code == 401:
            log.error("%s: Message Central rejected the auth token (401)", path)
            raise OtpError(_GENERIC)
        try:
            body = r.json()
        except ValueError:
            body = {}
        return r.status_code, body
    return 401, {}


def _code(body: dict) -> int:
    """VerifyNow puts its result code in `responseCode` (sometimes as text)."""
    raw = body.get("responseCode") or (body.get("data") or {}).get("responseCode")
    try:
        return int(raw)
    except (TypeError, ValueError):
        return 0


def send(phone: str) -> str:
    """Sends an OTP SMS to +91XXXXXXXXXX. Returns VerifyNow's verificationId."""
    status, body = _call("POST", "/verification/v3/send", {
        "countryCode": "91", "flowType": "SMS",
        "mobileNumber": phone[-10:], "otpLength": str(CODE_LENGTH)})
    vid = (body.get("data") or {}).get("verificationId")
    if status == 200 and _code(body) == 200 and vid:
        return str(vid)
    code = _code(body)
    log.error("send refused: HTTP %s code %s %s", status, code, body.get("message"))
    if code in (506, 800):
        raise OtpError("A code was just sent. Please wait a minute before asking again.")
    raise OtpError(_GENERIC)


def validate(verification_id: str, code: str) -> None:
    """Raises OtpError unless [code] is right for [verification_id]."""
    status, body = _call("GET", "/verification/v3/validateOtp",
                         {"verificationId": verification_id, "code": code})
    data = body.get("data") or {}
    rc = _code(body)
    if status == 200 and rc == 200 and data.get("verificationStatus") == "VERIFICATION_COMPLETED":
        return
    if rc == 702:
        raise OtpError(_WRONG)
    if rc in (705, 505, 703):
        raise OtpError(_EXPIRED)
    if rc == 800:
        raise OtpError("Too many wrong codes. Request a new code in a few minutes.")
    log.error("validate refused: HTTP %s code %s %s", status, rc, body.get("message"))
    raise OtpError(_WRONG if rc == 700 else _GENERIC)
