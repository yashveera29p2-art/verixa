"""Phone-number login verified by Truecaller (free, India).

The app verifies the number with Truecaller's SDK in one of two ways:

* Truecaller app users approve a consent sheet; the app sends us the OAuth
  authorization code and its PKCE code verifier. We swap them for an access
  token and read the verified phone number from Truecaller's userinfo.
* Everyone else gets a missed call (or a Truecaller OTP); the SDK then gives
  the app an access token, which we check with Truecaller's server to get
  the verified number.

Either way the number comes from Truecaller's server, never from the app,
so it can't be faked. The caller then signs in to that number's account.
"""

from __future__ import annotations

import logging
import re

import requests

from ..config import settings
from .codes import OtpError, normalise_phone

log = logging.getLogger("verixa.truecaller")

TOKEN_URL = "https://oauth-account-noneu.truecaller.com/v1/token"
USERINFO_URL = "https://oauth-account-noneu.truecaller.com/v1/userinfo"
PHONE_DETAIL_URL = ("https://sdk-otp-verification-noneu.truecaller.com"
                    "/v1/otp/client/installation/phoneNumberDetail/{token}")

_FAILED = "We couldn’t confirm your number with Truecaller. Please try again."


def _client_id() -> str:
    if not settings.truecaller_client_id:
        raise OtpError("Phone login isn't set up on the server yet.")
    return settings.truecaller_client_id


def _to_phone(raw: object) -> str:
    digits = re.sub(r"\D", "", str(raw or ""))
    return normalise_phone(digits[-10:] if len(digits) >= 10 else digits)


def phone_from_oauth(authorization_code: str, code_verifier: str) -> str:
    """Truecaller app users: authorization code + PKCE verifier → number."""
    try:
        r = requests.post(TOKEN_URL, timeout=15, data={
            "grant_type": "authorization_code",
            "client_id": _client_id(),
            "code": authorization_code,
            "code_verifier": code_verifier,
        })
        token = (r.json() or {}).get("access_token")
    except OtpError:
        raise
    except Exception as exc:
        log.error("token request failed: %s", exc)
        raise OtpError(_FAILED) from exc
    if r.status_code != 200 or not token:
        log.error("token refused: HTTP %s %s", r.status_code, (r.json() or {}).get("error"))
        raise OtpError(_FAILED)
    try:
        info = requests.get(USERINFO_URL, timeout=15,
                            headers={"Authorization": f"Bearer {token}"}).json() or {}
    except Exception as exc:
        log.error("userinfo failed: %s", exc)
        raise OtpError(_FAILED) from exc
    if not info.get("phone_number") or info.get("phone_number_verified") is False:
        log.error("userinfo has no verified phone")
        raise OtpError(_FAILED)
    return _to_phone(info["phone_number"])


def phone_from_access_token(access_token: str) -> str:
    """Missed-call / Truecaller-OTP users: SDK access token → number."""
    if not re.fullmatch(r"[A-Za-z0-9._\-]{8,200}", access_token or ""):
        raise OtpError(_FAILED)
    try:
        r = requests.get(PHONE_DETAIL_URL.format(token=access_token), timeout=15,
                         headers={"clientId": _client_id()})
        body = r.json() or {}
    except OtpError:
        raise
    except Exception as exc:
        log.error("phone detail failed: %s", exc)
        raise OtpError(_FAILED) from exc
    if r.status_code != 200 or not body.get("phoneNumber"):
        log.error("phone detail refused: HTTP %s %s", r.status_code, body.get("message"))
        raise OtpError(_FAILED)
    if str(body.get("countryCode", "IN")).upper() != "IN":
        raise OtpError("Verixa works with Indian mobile numbers only.")
    return _to_phone(body["phoneNumber"])
