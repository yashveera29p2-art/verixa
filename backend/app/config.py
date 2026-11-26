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
    # Comma-separated, tried in order: e.g. "textbee,fast2sms" sends from
    # your textbee phone and falls back to Fast2SMS if the phone can't.
    # Others: "messagecentral" (VerifyNow, on its own), "2factor", and
    # "console" (only logs the code; local development and tests).
    sms_provider: str = os.getenv("VERIXA_SMS_PROVIDER", "console")
    twofactor_api_key: str = os.getenv("VERIXA_2FACTOR_API_KEY", "")
    # Message Central: customer id plus EITHER the auth token generated in
    # their console (Developer Guide → API Credentials) OR the account
    # password/key (we then fetch tokens ourselves).
    mc_customer_id: str = os.getenv("VERIXA_MC_CUSTOMER_ID", "")
    mc_auth_token: str = os.getenv("VERIXA_MC_AUTH_TOKEN", "")
    mc_key: str = os.getenv("VERIXA_MC_KEY", "")
    # Optional 2Factor template name (their default OTP template is used if empty).
    twofactor_template: str = os.getenv("VERIXA_2FACTOR_TEMPLATE", "")
    # Secret used to sign OTP sessions. Set it in production so codes stay
    # valid across restarts; a random one is used otherwise.
    otp_secret: str = os.getenv("VERIXA_OTP_SECRET", "")
    # Stop sending SMS after this many per day (protects your SMS balance).
    sms_daily_cap: int = int(os.getenv("VERIXA_SMS_DAILY_CAP", "300"))
    # textbee: free SMS from your own Android phone (app installed on it).
    # Truecaller SDK client ID (not secret; also in the Android manifest).
    truecaller_client_id: str = os.getenv(
        "VERIXA_TRUECALLER_CLIENT_ID", "5ulu0dqyonrhlqym-t6owpojelqghgqmmfkesuhn-sm")
    textbee_api_key: str = os.getenv("VERIXA_TEXTBEE_API_KEY", "")
    # Optional: which registered phone sends (default: textbee picks).
    textbee_device_id: str = os.getenv("VERIXA_TEXTBEE_DEVICE_ID", "")
    # How long to wait for the phone to report "sent" before using the backup.
    textbee_wait_seconds: float = float(os.getenv("VERIXA_TEXTBEE_WAIT", "30"))
    # Fast2SMS Quick SMS (paid backup, ~₹7/SMS); capped per day to protect balance.
    fast2sms_api_key: str = os.getenv("VERIXA_FAST2SMS_API_KEY", "")
    fast2sms_daily_cap: int = int(os.getenv("VERIXA_FAST2SMS_DAILY_CAP", "10"))
    # Numbers that never get an SMS and accept a fixed code, e.g.
    # "+919999999999:123456" (comma-separated). For demos and testing.
    test_phones: str = os.getenv("VERIXA_TEST_PHONES", "+919999999999:123456")
    # Firebase service-account JSON (the whole file's contents), needed to
    # create login tokens. Never commit it; set it as a secret on the host.
    firebase_service_account: str = os.getenv("VERIXA_FIREBASE_SERVICE_ACCOUNT", "")

    # Adzuna job search (https://developer.adzuna.com). Without these the
    # Jobs tab shows bundled sample listings.
    adzuna_app_id: str = os.getenv("VERIXA_ADZUNA_APP_ID", "")
    adzuna_app_key: str = os.getenv("VERIXA_ADZUNA_APP_KEY", "")

    # Largest upload we accept.
    max_upload_bytes: int = int(os.getenv("VERIXA_MAX_UPLOAD_MB", "5")) * 1024 * 1024


settings = Settings()
