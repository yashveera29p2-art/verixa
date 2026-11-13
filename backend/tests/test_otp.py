"""Phone OTP login (our own SMS, Firebase custom tokens)."""

import pytest
from fastapi.testclient import TestClient

from app import otp
from app.main import app
from app.otp import codes
from app.otp.limits import DailyCap, OtpLimits, SlidingWindow

SECRET = b"test-secret"


@pytest.fixture(autouse=True)
def fresh_limits(monkeypatch):
    monkeypatch.setattr(otp, "limits", OtpLimits(daily_cap=100))
    sent = []
    monkeypatch.setattr(otp, "send_otp", lambda phone, code: sent.append((phone, code)))
    monkeypatch.setattr(otp, "custom_token_for", lambda phone: (f"token-for-{phone}", False))
    return sent


# ── Codes and sessions ─────────────────────────────────────────────────────

@pytest.mark.parametrize("raw", ["9876543210", "+91 98765 43210", "91-9876543210"])
def test_normalises_indian_numbers(raw):
    assert codes.normalise_phone(raw) == "+919876543210"


@pytest.mark.parametrize("raw", ["12345", "5876543210", "+1 650 555 1234"])
def test_rejects_non_indian_or_invalid(raw):
    with pytest.raises(codes.OtpError):
        codes.normalise_phone(raw)


def test_right_code_passes_wrong_code_fails():
    token = codes.issue(SECRET, "+919876543210", "123456")
    assert codes.check(SECRET, token, "123456").phone == "+919876543210"
    with pytest.raises(codes.OtpError, match="incorrect"):
        codes.check(SECRET, token, "654321")


def test_code_expires_after_five_minutes():
    token = codes.issue(SECRET, "+919876543210", "123456", now=1000)
    with pytest.raises(codes.OtpError, match="expired"):
        codes.check(SECRET, token, "123456", now=1000 + 301)


def test_tampered_session_is_rejected():
    token = codes.issue(SECRET, "+919876543210", "123456")
    other = codes.issue(SECRET, "+919000000000", "123456")
    with pytest.raises(codes.OtpError):
        codes.check(b"another-secret", token, "123456")
    with pytest.raises(codes.OtpError):
        codes.check(SECRET, token[:-4] + other[-4:], "123456")


def test_session_does_not_reveal_the_code():
    token = codes.issue(SECRET, "+919876543210", "424242")
    assert "424242" not in codes._unb64(token).decode()


# ── Limits ─────────────────────────────────────────────────────────────────

def test_sliding_window_and_daily_cap():
    w = SlidingWindow(2, 60)
    assert w.hit("a", 0) and w.hit("a", 1) and not w.hit("a", 2) and w.hit("a", 61)
    cap = DailyCap(1)
    assert cap.take(0) and not cap.take(10) and cap.take(86400 + 1)


def test_resend_needs_30_seconds(fresh_limits):
    otp.start("9876543210", "1.1.1.1")
    with pytest.raises(otp.RateLimited, match="wait"):
        otp.start("9876543210", "1.1.1.1")
    assert len(fresh_limits) == 1


def test_five_wrong_codes_lock_the_session(fresh_limits):
    _, session = otp.start("9876543210", "1.1.1.1")
    for _ in range(5):
        with pytest.raises(codes.OtpError, match="incorrect"):
            otp.finish(session, "000000")
    right = fresh_limits[0][1]
    with pytest.raises(otp.RateLimited):
        otp.finish(session, right)


def test_test_numbers_skip_sms(fresh_limits):
    _, session = otp.start("9999999999", "1.1.1.1")
    assert fresh_limits == []
    phone, token, _ = otp.finish(session, "123456")
    assert phone == "+919999999999" and token == "token-for-+919999999999"


# ── API ────────────────────────────────────────────────────────────────────

def test_full_flow_over_http(fresh_limits):
    client = TestClient(app)
    r = client.post("/v1/auth/otp/start", json={"phone": "98765 43210"})
    assert r.status_code == 200
    session = r.json()["session"]
    code = fresh_limits[0][1]

    r = client.post("/v1/auth/otp/verify", json={"session": session, "code": "111111"})
    assert r.status_code == 400 and "incorrect" in r.json()["detail"]

    r = client.post("/v1/auth/otp/verify", json={"session": session, "code": code})
    assert r.status_code == 200
    assert r.json() == {"phone": "+919876543210",
                        "firebaseToken": "token-for-+919876543210", "isNewUser": False}


def test_rate_limit_returns_429():
    client = TestClient(app)
    client.post("/v1/auth/otp/start", json={"phone": "9876500000"})
    r = client.post("/v1/auth/otp/start", json={"phone": "9876500000"})
    assert r.status_code == 429 and "Retry-After" in r.headers


# ── Message Central VerifyNow (provider-generated codes) ───────────────────

def test_verifynow_flow(monkeypatch, fresh_limits):
    from app.config import settings
    from app.otp import messagecentral
    object.__setattr__(settings, "sms_provider", "messagecentral")
    try:
        sent, checked = [], []
        monkeypatch.setattr(messagecentral, "send", lambda phone: sent.append(phone) or "4242")

        def fake_validate(vid, code):
            checked.append((vid, code))
            if code != "112233":
                raise codes.OtpError("That code is incorrect. Check and try again.")
        monkeypatch.setattr(messagecentral, "validate", fake_validate)

        phone, session = otp.start("9876543210", "1.1.1.1")
        assert sent == ["+919876543210"] and fresh_limits == []  # no local SMS
        with pytest.raises(codes.OtpError, match="incorrect"):
            otp.finish(session, "000000")
        assert otp.finish(session, "112 233")[1] == "token-for-+919876543210"
        assert checked == [("4242", "000000"), ("4242", "112233")]
    finally:
        object.__setattr__(settings, "sms_provider", "console")


def test_remote_session_cannot_be_forged():
    token = codes.issue_remote(SECRET, "+919876543210", "4242")
    assert codes.check_remote(SECRET, token).remote_id == "4242"
    with pytest.raises(codes.OtpError):
        codes.check_remote(b"other", token)
    with pytest.raises(codes.OtpError):  # a remote session can't pass the local check
        codes.check(SECRET, token, "123456")


def test_verifynow_response_mapping(monkeypatch):
    from app.otp import messagecentral as mc
    monkeypatch.setattr(mc, "_call", lambda *a: (200, {"responseCode": 200, "data": {
        "verificationId": 99}}))
    assert mc.send("+919876543210") == "99"
    for rc, msg in ((702, "incorrect"), (705, "expired")):
        monkeypatch.setattr(mc, "_call", lambda *a, rc=rc: (200, {"responseCode": rc, "data": {}}))
        with pytest.raises(codes.OtpError, match=msg):
            mc.validate("99", "123456")
    monkeypatch.setattr(mc, "_call", lambda *a: (200, {"responseCode": 200, "data": {
        "verificationStatus": "VERIFICATION_COMPLETED"}}))
    mc.validate("99", "123456")


def test_console_auth_token_is_used_directly(monkeypatch):
    from app.config import settings
    from app.otp import messagecentral as mc
    object.__setattr__(settings, "mc_auth_token", "console-token")
    try:
        seen = {}

        class R:
            status_code = 200
            def json(self):
                return {"responseCode": 200, "data": {"verificationId": 7}}

        def fake_request(method, url, params, timeout, headers):
            seen.update(headers)
            return R()
        monkeypatch.setattr(mc.requests, "request", fake_request)
        assert mc.send("+919876543210") == "7"
        assert seen["authToken"] == "console-token"
    finally:
        object.__setattr__(settings, "mc_auth_token", "")


def test_account_exists(monkeypatch, fresh_limits):
    monkeypatch.setattr(otp, "account_exists", lambda phone: phone == "+919876543210")
    assert otp.exists("98765 43210", "1.2.3.4") == ("+919876543210", True)
    assert otp.exists("+91 91234 56789", "1.2.3.4") == ("+919123456789", False)
