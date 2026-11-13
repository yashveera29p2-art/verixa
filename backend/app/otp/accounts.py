"""One permanent Firebase account per phone number.

After the OTP is verified, we look up the Firebase user that owns the
number (existing users keep their uid and data) or create it, then mint a
custom token. The app signs in with that token; the account's phone number
is set, so ID tokens carry `phone_number` exactly like Firebase phone login.
"""

from __future__ import annotations

import json
import logging
from functools import lru_cache

from ..config import settings
from .codes import OtpError

log = logging.getLogger("verixa.accounts")


@lru_cache(maxsize=1)
def _app():
    import firebase_admin
    from firebase_admin import credentials

    if not settings.firebase_service_account:
        raise OtpError("Login isn't set up on the server yet.")
    info = json.loads(settings.firebase_service_account)
    return firebase_admin.initialize_app(credentials.Certificate(info), name="verixa-otp")


def custom_token_for(phone: str) -> tuple[str, bool]:
    """Returns (custom token, is_new_user) for the account owning [phone]."""
    from firebase_admin import auth

    app = _app()
    try:
        user = auth.get_user_by_phone_number(phone, app=app)
        is_new = False
    except auth.UserNotFoundError:
        user = auth.create_user(phone_number=phone, app=app)
        is_new = True
        log.info("created account uid=%s", user.uid)
    token = auth.create_custom_token(user.uid, app=app)
    return (token.decode() if isinstance(token, bytes) else token), is_new


def account_exists(phone: str) -> bool:
    """Whether a Verixa account already owns [phone]."""
    from firebase_admin import auth

    try:
        auth.get_user_by_phone_number(phone, app=_app())
        return True
    except auth.UserNotFoundError:
        return False
