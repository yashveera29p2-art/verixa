"""In-memory rate limits that protect the SMS balance from abuse.

Kept in memory on purpose (one small server): a restart resets them, which
is acceptable because every limit is short-lived and the daily cap also
bounds total spend.
"""

from __future__ import annotations

import threading
import time
from collections import defaultdict, deque


class SlidingWindow:
    """At most `limit` events per `seconds` for each key."""

    def __init__(self, limit: int, seconds: int):
        self.limit, self.seconds = limit, seconds
        self._events: dict[str, deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()

    def hit(self, key: str, now: float | None = None) -> bool:
        """Records an event; False if the key is over its limit."""
        now = time.time() if now is None else now
        with self._lock:
            q = self._events[key]
            while q and now - q[0] > self.seconds:
                q.popleft()
            if len(q) >= self.limit:
                return False
            q.append(now)
            return True

    def retry_after(self, key: str, now: float | None = None) -> int:
        now = time.time() if now is None else now
        q = self._events.get(key)
        return max(1, int(self.seconds - (now - q[0]))) if q else 0


class DailyCap:
    """Counts SMS per UTC day and refuses beyond `cap`."""

    def __init__(self, cap: int):
        self.cap = cap
        self._day = ""
        self._count = 0
        self._lock = threading.Lock()

    def take(self, now: float | None = None) -> bool:
        day = time.strftime("%Y-%m-%d", time.gmtime(time.time() if now is None else now))
        with self._lock:
            if day != self._day:
                self._day, self._count = day, 0
            if self._count >= self.cap:
                return False
            self._count += 1
            return True


class OtpLimits:
    def __init__(self, daily_cap: int):
        self.resend = SlidingWindow(1, 30)            # one SMS per number per 30 s
        self.per_phone = SlidingWindow(5, 3600)       # 5 SMS per number per hour
        self.per_ip = SlidingWindow(15, 3600)         # 15 SMS per device/IP per hour
        self.attempts = SlidingWindow(5, 600)         # 5 tries per code
        self.failed_phone = SlidingWindow(15, 3600)   # 15 wrong codes per number per hour
        self.daily = DailyCap(daily_cap)
