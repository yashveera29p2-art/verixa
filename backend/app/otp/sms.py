"""Sends OTP SMS. Swap providers with VERIXA_SMS_PROVIDER."""

from __future__ import annotations

import logging

import requests

from ..config import settings
from .codes import OtpError

log = logging.getLogger("verixa.sms")


def send_otp(phone: str, code: str) -> None:
    """Delivers [code] to [phone] (+91XXXXXXXXXX). Raises OtpError on failure."""
    provider = settings.sms_provider
    if provider == "console":
        # Development only: the code appears in the server log.
        log.warning("DEV OTP for %s: %s", phone, code)
        return
    if provider == "2factor":
        _send_2factor(phone, code)
        return
    raise OtpError("SMS isn't set up on the server yet.")


def _send_2factor(phone: str, code: str) -> None:
    """2Factor.in "send this OTP" API: they deliver it with their
    DLT-approved OTP template, so no sender registration is needed."""
    key = settings.twofactor_api_key
    if not key:
        raise OtpError("SMS isn't set up on the server yet.")
    url = f"https://2factor.in/API/V1/{key}/SMS/{phone.lstrip('+')}/{code}"
    if settings.twofactor_template:
        url += f"/{settings.twofactor_template}"
    try:
        r = requests.get(url, timeout=15)
        body = r.json()
    except Exception as exc:
        log.error("2Factor request failed: %s", exc)
        raise OtpError("Couldn’t send the code. Please try again.") from exc
    if r.status_code != 200 or body.get("Status") != "Success":
        # Never log the URL: it contains the API key.
        log.error("2Factor error %s: %s", r.status_code, body.get("Details"))
        raise OtpError("Couldn’t send the code. Please try again in a minute.")
