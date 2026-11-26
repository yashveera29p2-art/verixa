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


# ── Providers: textbee first, Fast2SMS as backup ───────────────────────────

class _Resp:
    def __init__(self, status, body):
        self.status_code, self._body = status, body

    def json(self):
        return self._body


def _sms_settings(monkeypatch, provider):
    import dataclasses
    from app.otp import sms
    monkeypatch.setattr(sms, "settings", dataclasses.replace(
        sms.settings, sms_provider=provider, textbee_api_key="tb-key",
        fast2sms_api_key="f2-key", textbee_wait_seconds=0.01, textbee_device_id=""))
    monkeypatch.setattr(sms.time, "sleep", lambda s: None)
    monkeypatch.setattr(sms, "_fast2sms_cap", DailyCap(2))
    return sms


def test_textbee_sends_when_phone_reports_sent(monkeypatch):
    sms = _sms_settings(monkeypatch, "textbee,fast2sms")
    import dataclasses
    monkeypatch.setattr(sms, "settings", dataclasses.replace(sms.settings, textbee_wait_seconds=5))
    calls = []
    monkeypatch.setattr(sms.requests, "post", lambda url, **kw: calls.append(url) or
                        calls.append(kw["json"]["recipients"]) or
                        _Resp(200, {"data": {"smsBatchId": "b1"}}))
    monkeypatch.setattr(sms.requests, "get", lambda url, **kw:
                        _Resp(200, {"data": [{"status": "sent"}]}))
    sms.send_otp("+919876543210", "123456")
    assert calls == ["https://api.textbee.dev/api/v1/gateway/send-sms", ["9876543210"]]


def test_falls_back_to_fast2sms_when_phone_offline(monkeypatch):
    sms = _sms_settings(monkeypatch, "textbee,fast2sms")
    posts = []

    def post(url, **kw):
        posts.append((url, kw))
        if "textbee" in url:
            return _Resp(200, {"data": {"smsBatchId": "b1"}})
        return _Resp(200, {"return": True})

    monkeypatch.setattr(sms.requests, "post", post)
    monkeypatch.setattr(sms.requests, "get", lambda url, **kw:
                        _Resp(200, {"data": [{"status": "pending"}]}))
    sms.send_otp("+919876543210", "654321")
    url, kw = posts[-1]
    assert "fast2sms" in url
    assert kw["data"]["numbers"] == "9876543210"
    assert "654321" in kw["data"]["message"]


def test_fast2sms_daily_cap_and_clear_error(monkeypatch):
    sms = _sms_settings(monkeypatch, "fast2sms")
    monkeypatch.setattr(sms.requests, "post", lambda url, **kw: _Resp(200, {"return": True}))
    sms.send_otp("+919876543210", "111111")
    sms.send_otp("+919876543210", "222222")
    with pytest.raises(codes.OtpError, match="Couldn’t send"):
        sms.send_otp("+919876543210", "333333")


def test_otp_text_is_plain_gsm():
    from app.otp.sms import otp_text
    text = otp_text("123456")
    assert text.isascii() and len(text) <= 160


def test_code_works_only_once(fresh_limits, monkeypatch):
    client = TestClient(app)
    start = client.post("/v1/auth/otp/start", json={"phone": "9876543210"}).json()
    code = fresh_limits[-1][1]
    ok = client.post("/v1/auth/otp/verify", json={"session": start["session"], "code": code})
    assert ok.status_code == 200
    again = client.post("/v1/auth/otp/verify", json={"session": start["session"], "code": code})
    assert again.status_code == 400 and "already used" in again.json()["detail"]


def test_textbee_alone_accepts_a_slow_phone(monkeypatch):
    sms = _sms_settings(monkeypatch, "textbee")
    monkeypatch.setattr(sms.requests, "post", lambda url, **kw:
                        _Resp(200, {"data": {"smsBatchId": "b1"}}))
    monkeypatch.setattr(sms.requests, "get", lambda url, **kw:
                        _Resp(200, {"data": [{"status": "dispatched"}]}))
    sms.send_otp("+919876543210", "123456")  # no error: the code arrives late


def test_textbee_failure_still_reports_error(monkeypatch):
    sms = _sms_settings(monkeypatch, "textbee")
    monkeypatch.setattr(sms.requests, "post", lambda url, **kw:
                        _Resp(200, {"data": {"smsBatchId": "b1"}}))
    monkeypatch.setattr(sms.requests, "get", lambda url, **kw:
                        _Resp(200, {"data": [{"status": "failed"}]}))
    with pytest.raises(codes.OtpError, match="Couldn’t send"):
        sms.send_otp("+919876543210", "123456")


# ── Truecaller login ───────────────────────────────────────────────────────

def _tc(monkeypatch):
    import dataclasses
    from app.otp import truecaller
    monkeypatch.setattr(truecaller, "settings",
                        dataclasses.replace(truecaller.settings, truecaller_client_id="cid"))
    return truecaller


def test_login_method_test_numbers_use_code(monkeypatch):
    client = TestClient(app)
    monkeypatch.setattr(otp, "_test_codes", lambda: {"+919999999999": "123456"})
    assert client.post("/v1/auth/method", json={"phone": "9999999999"}).json()["method"] == "code"
    assert client.post("/v1/auth/method", json={"phone": "9876543210"}).json()["method"] == "truecaller"


def test_truecaller_access_token_signs_in_verified_number(monkeypatch):
    tc = _tc(monkeypatch)
    seen = {}
    monkeypatch.setattr(tc.requests, "get", lambda url, **kw: seen.update(url=url, kw=kw) or
                        _Resp(200, {"phoneNumber": 919876543210, "countryCode": "IN"}))
    r = TestClient(app).post("/v1/auth/truecaller", json={"accessToken": "71d8367e-39f7-4de5"})
    assert r.status_code == 200
    assert r.json() == {"phone": "+919876543210", "firebaseToken": "token-for-+919876543210",
                        "isNewUser": False}
    assert seen["kw"]["headers"] == {"clientId": "cid"}


def test_truecaller_oauth_code_flow(monkeypatch):
    tc = _tc(monkeypatch)
    monkeypatch.setattr(tc.requests, "post", lambda url, **kw: _Resp(200, {"access_token": "at"}))
    monkeypatch.setattr(tc.requests, "get", lambda url, **kw: _Resp(200, {
        "phone_number": "919876543211", "phone_number_verified": True}))
    r = TestClient(app).post("/v1/auth/truecaller",
                             json={"authorizationCode": "code", "codeVerifier": "verifier"})
    assert r.status_code == 200 and r.json()["phone"] == "+919876543211"


def test_truecaller_rejects_invalid_token(monkeypatch):
    tc = _tc(monkeypatch)
    monkeypatch.setattr(tc.requests, "get", lambda url, **kw:
                        _Resp(404, {"code": 1404, "message": "Invalid access token."}))
    r = TestClient(app).post("/v1/auth/truecaller", json={"accessToken": "bad-token-123"})
    assert r.status_code == 400 and "Truecaller" in r.json()["detail"]


def test_truecaller_needs_proof(monkeypatch):
    _tc(monkeypatch)
    r = TestClient(app).post("/v1/auth/truecaller", json={})
    assert r.status_code == 400
