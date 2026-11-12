"""Settings, read from environment variables (see README)."""

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    # Firebase project whose ID tokens we accept.
    firebase_project_id: str = os.getenv("VERIXA_FIREBASE_PROJECT", "verixa-app")

    # "firebase" (default) verifies the user's Firebase ID token.
    # "disabled" skips the check — ONLY for local tests, never in production.
    auth_mode: str = os.getenv("VERIXA_AUTH_MODE", "firebase")

    # ── Phone OTP login (our own, not Firebase SMS) ─────────────────────
    # "2factor" sends real SMS through 2Factor.in; "console" only logs the
    # code (local development and tests).
    sms_provider: str = os.getenv("VERIXA_SMS_PROVIDER", "console")
    twofactor_api_key: str = os.getenv("VERIXA_2FACTOR_API_KEY", "")
    # Optional 2Factor template name (their default OTP template is used if empty).
    twofactor_template: str = os.getenv("VERIXA_2FACTOR_TEMPLATE", "")
    # Secret used to sign OTP sessions. Set it in production so codes stay
    # valid across restarts; a random one is used otherwise.
    otp_secret: str = os.getenv("VERIXA_OTP_SECRET", "")
    # Stop sending SMS after this many per day (protects your SMS balance).
    sms_daily_cap: int = int(os.getenv("VERIXA_SMS_DAILY_CAP", "300"))
    # Numbers that never get an SMS and accept a fixed code, e.g.
    # "+919999999999:123456" (comma-separated). For demos and testing.
    test_phones: str = os.getenv("VERIXA_TEST_PHONES", "+919999999999:123456")
    # Firebase service-account JSON (the whole file's contents), needed to
    # create login tokens. Never commit it; set it as a secret on the host.
    firebase_service_account: str = os.getenv("VERIXA_FIREBASE_SERVICE_ACCOUNT", "")

    # Largest upload we accept.
    max_upload_bytes: int = int(os.getenv("VERIXA_MAX_UPLOAD_MB", "5")) * 1024 * 1024


settings = Settings()
