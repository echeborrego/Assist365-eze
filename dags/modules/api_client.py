import logging
import random
import time

import requests

log = logging.getLogger(__name__)

RETRYABLE_STATUS = {429, 500, 502, 503, 504}


class ApiError(Exception):
    pass


class ApiClient:
    """GET-only client: retries 429/5xx, timeouts and broken bodies with exponential backoff + jitter."""

    def __init__(self, base_url: str, token: str, max_attempts: int = 8, base_delay: float = 1.0,
                 max_delay: float = 60.0, timeout: float = 60.0):
        self.base_url = base_url
        self.max_attempts = max_attempts
        self.base_delay = base_delay
        self.max_delay = max_delay
        self.timeout = timeout
        self.session = requests.Session()
        self.session.headers.update({"Authorization": f"Bearer {token}", "Accept-Encoding": "gzip"})
        self.calls = 0
        self.retries = 0

    def get(self, path: str, params: dict | None = None) -> dict:
        url = f"{self.base_url}{path}"
        for attempt in range(1, self.max_attempts + 1):
            self.calls += 1
            retry_after = None
            try:
                r = self.session.get(url, params=params, timeout=self.timeout)
                if r.status_code == 200:
                    return r.json()
                if r.status_code not in RETRYABLE_STATUS:
                    raise ApiError(f"HTTP {r.status_code} on {path} {params}: {r.text[:300]}")
                reason = f"HTTP {r.status_code}"
                retry_after = r.headers.get("Retry-After")
            except (requests.ConnectionError, requests.Timeout, requests.JSONDecodeError) as e:
                reason = type(e).__name__

            if attempt == self.max_attempts:
                raise ApiError(f"Gave up on {path} {params} after {attempt} attempts: {reason}")
            delay = min(self.max_delay, self.base_delay * 2 ** (attempt - 1)) * random.uniform(0.5, 1.5)
            if retry_after and retry_after.isdigit():
                delay = max(delay, float(retry_after))
            self.retries += 1
            log.warning("%s on %s %s, retry %d in %.1fs", reason, path, params, attempt, delay)
            time.sleep(delay)
