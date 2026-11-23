"""Sends OTP SMS. Choose providers with VERIXA_SMS_PROVIDER.

The setting may list several providers separated by commas, e.g.
"textbee,fast2sms": the first is tried, and if it fails the next one sends
the same code. A user who gets the code twice can use either message.
"""

from __future__ import annotations

import logging
import time

import requests

from ..config import settings
from .codes import OtpError
from .limits import DailyCap

log = logging.getLogger("verixa.sms")

_GENERIC = "Couldn’t send the code. Please try again in a minute."

# Fast2SMS charges per SMS, so it has its own daily cap on top of the global one.
_fast2sms_cap = DailyCap(settings.fast2sms_daily_cap)


def otp_text(code: str) -> str:
    # Plain GSM-7 characters only, so the SMS stays one segment.
    return (f"{code} is your Verixa login code. It expires in 5 minutes. "
            "Do not share it with anyone.")


def providers() -> list[str]:
    return [p.strip().lower() for p in settings.sms_provider.split(",") if p.strip()]


def send_otp(phone: str, code: str) -> None:
    """Delivers [code] to [phone] (+91XXXXXXXXXX), trying each configured
    provider in order. Raises OtpError when none of them could send it."""
    names = providers()
    if not names:
        raise OtpError("SMS isn't set up on the server yet.")
    last: OtpError | None = None
    for name in names:
        sender = _SENDERS.get(name)
        if sender is None:
            log.error("unknown SMS provider %r", name)
            continue
        try:
            sender(phone, code)
            if name != names[0]:
                log.warning("otp sent via backup provider %s", name)
            return
        except OtpError as exc:
            log.error("%s could not send: %s", name, exc)
            last = exc
    if last is None:
        raise OtpError("SMS isn't set up on the server yet.")
    # Provider details stay in the log; the user sees a plain message.
    raise OtpError(_GENERIC)


def _send_console(phone: str, code: str) -> None:
    # Development only: the code appears in the server log.
    log.warning("DEV OTP for %s: %s", phone, code)


# ── textbee: sends from an Android phone's own SIM (free plan) ─────────────

TEXTBEE = "https://api.textbee.dev/api/v1"


def _send_textbee(phone: str, code: str) -> None:
    """Queues the SMS on the textbee phone, then waits until the phone
    reports it as sent. A phone that is off or offline leaves the message
    pending; after the wait we give up so the backup provider can send."""
    key = settings.textbee_api_key
    if not key:
        raise OtpError("textbee is not configured")
    headers = {"x-api-key": key}
    body: dict = {"recipients": [phone], "message": otp_text(code)}
    if settings.textbee_device_id:
        body["deviceId"] = settings.textbee_device_id
    try:
        r = requests.post(f"{TEXTBEE}/gateway/send-sms", json=body, headers=headers, timeout=15)
        data = (r.json() or {}).get("data") or {}
    except Exception as exc:
        raise OtpError(f"request failed: {exc}") from exc
    if r.status_code != 200:
        # 400: no enabled device / permission; 401: bad key; 429: plan limit.
        raise OtpError(f"HTTP {r.status_code}")
    if data.get("warning"):
        log.warning("textbee warning: %s", (data["warning"] or {}).get("code"))
    batch = data.get("smsBatchId")
    if not batch:
        if data.get("successCount"):
            return  # pushed to the phone straight away
        raise OtpError("no batch id in response")
    _wait_until_sent(batch, headers)


def _wait_until_sent(batch: str, headers: dict) -> None:
    deadline = time.monotonic() + settings.textbee_wait_seconds
    status = "pending"
    while time.monotonic() < deadline:
        time.sleep(1.5)
        try:
            r = requests.get(f"{TEXTBEE}/gateway/messages", headers=headers, timeout=10,
                             params={"smsBatchId": batch, "limit": 1})
            items = (r.json() or {}).get("data") or []
        except Exception:
            continue
        status = (items[0].get("status") if items else None) or "pending"
        if status in ("sent", "delivered"):
            return
        if status == "failed":
            raise OtpError("the phone could not send the SMS")
    raise OtpError(f"phone did not send in time (status {status})")


# ── Fast2SMS Quick SMS: paid backup, no DLT needed ─────────────────────────

def _send_fast2sms(phone: str, code: str) -> None:
    key = settings.fast2sms_api_key
    if not key:
        raise OtpError("Fast2SMS is not configured")
    if not _fast2sms_cap.take():
        raise OtpError(f"Fast2SMS daily cap ({settings.fast2sms_daily_cap}) reached")
    try:
        r = requests.post("https://www.fast2sms.com/dev/bulkV2", timeout=20,
                          headers={"authorization": key},
                          data={"route": "q", "message": otp_text(code),
                                "numbers": phone[-10:], "flash": "0"})
        body = r.json()
    except Exception as exc:
        raise OtpError(f"request failed: {exc}") from exc
    if r.status_code != 200 or body.get("return") is not True:
        # Never log the key; the message says e.g. "insufficient balance".
        raise OtpError(f"HTTP {r.status_code}: {body.get('message')}")


# ── 2Factor.in (kept from earlier) ─────────────────────────────────────────

def _send_2factor(phone: str, code: str) -> None:
    """2Factor.in "send this OTP" API."""
    key = settings.twofactor_api_key
    if not key:
        raise OtpError("2Factor is not configured")
    url = f"https://2factor.in/API/V1/{key}/SMS/{phone.lstrip('+')}/{code}"
    if settings.twofactor_template:
        url += f"/{settings.twofactor_template}"
    try:
        r = requests.get(url, timeout=15)
        body = r.json()
    except Exception as exc:
        raise OtpError("request failed") from exc
    if r.status_code != 200 or body.get("Status") != "Success":
        # Never log the URL: it contains the API key.
        raise OtpError(f"HTTP {r.status_code}: {body.get('Details')}")


_SENDERS = {
    "console": _send_console,
    "textbee": _send_textbee,
    "fast2sms": _send_fast2sms,
    "2factor": _send_2factor,
}
