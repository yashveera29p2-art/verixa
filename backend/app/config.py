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

    # Largest upload we accept.
    max_upload_bytes: int = int(os.getenv("VERIXA_MAX_UPLOAD_MB", "5")) * 1024 * 1024


settings = Settings()
