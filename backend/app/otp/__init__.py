"""Phone-number login with our own SMS OTP (no Firebase SMS / billing)."""

from __future__ import annotations

import logging
import secrets

from ..config import settings
from . import codes
from .accounts import custom_token_for
from .codes import OtpError
from .limits import OtpLimits
from .sms import send_otp

log = logging.getLogger("verixa.otp")

_secret = (settings.otp_secret or secrets.token_hex(32)).encode()
limits = OtpLimits(settings.sms_daily_cap)


def _test_codes() -> dict[str, str]:
    out = {}
    for pair in settings.test_phones.split(","):
        if ":" in pair:
            phone, code = pair.split(":", 1)
            out[codes.normalise_phone(phone)] = code.strip()
    return out


class RateLimited(OtpError):
    def __init__(self, message: str, retry_after: int):
        super().__init__(message)
        self.retry_after = retry_after


def start(raw_phone: str, client: str) -> tuple[str, str]:
    """Sends a code. Returns (normalised phone, session token)."""
    phone = codes.normalise_phone(raw_phone)
    test = _test_codes().get(phone)
    if test:
        return phone, codes.issue(_secret, phone, test)

    if not limits.resend.hit(phone):
        wait = limits.resend.retry_after(phone)
        raise RateLimited(f"Please wait {wait} seconds before asking for a new code.", wait)
    if not limits.per_phone.hit(phone) or not limits.per_ip.hit(client):
        raise RateLimited("Too many codes requested. Please try again in an hour.", 3600)
    if not limits.daily.take():
        log.error("daily SMS cap (%d) reached", settings.sms_daily_cap)
        raise RateLimited("We can’t send more codes today. Please try again tomorrow.", 3600)

    code = codes.new_code()
    send_otp(phone, code)
    log.info("otp sent to %s****%s", phone[:5], phone[-2:])
    return phone, codes.issue(_secret, phone, code)


def finish(token: str, code: str) -> tuple[str, str, bool]:
    """Checks the code. Returns (phone, Firebase custom token, is_new_user)."""
    session, _ = codes.read(token)
    if not limits.attempts.hit(session.sid) or not limits.failed_phone.hit(session.phone):
        raise RateLimited("Too many wrong codes. Request a new code in a few minutes.", 600)
    session = codes.check(_secret, token, code)
    firebase_token, is_new = custom_token_for(session.phone)
    return session.phone, firebase_token, is_new
