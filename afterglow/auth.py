"""YouTube sign-in borrowed from a local browser.

Reads the browser's YouTube cookies on this computer (through yt-dlp's cookie reader) and signs
InnerTube requests with them, so 'My Mix' and other personal lists work. Nothing is stored and the
cookies are only ever sent to youtube.com.
"""
import hashlib
import threading
import time

BROWSERS = ("firefox", "chrome", "chromium", "brave", "vivaldi", "opera", "edge")
ORIGIN = "https://www.youtube.com"

_lock = threading.Lock()
_state = {"browser": "", "cookies": {}, "loaded": 0.0}


def _read(browser):
    from yt_dlp.cookies import extract_cookies_from_browser

    class _Quiet:
        def debug(self, *a, **k): pass
        def info(self, *a, **k): pass
        def warning(self, *a, **k): pass
        def error(self, *a, **k): pass

    jar = extract_cookies_from_browser(browser, logger=_Quiet())
    return {c.name: c.value for c in jar if c.domain.endswith("youtube.com")}


def _signed_in(cookies):
    return bool(cookies.get("SAPISID") or cookies.get("__Secure-3PAPISID")) and "LOGIN_INFO" in cookies


def load(preference="auto"):
    """Find a browser signed in to YouTube. Returns its name, or '' if none. Blocking."""
    if preference == "":
        with _lock:
            _state.update(browser="", cookies={}, loaded=time.time())
        return ""
    order = BROWSERS if preference in ("auto", None) else (preference,)
    for b in order:
        try:
            cookies = _read(b)
        except Exception:  # noqa: BLE001 - browser not installed, locked keyring, etc.
            continue
        if _signed_in(cookies):
            with _lock:
                _state.update(browser=b, cookies=cookies, loaded=time.time())
            return b
    with _lock:
        _state.update(browser="", cookies={}, loaded=time.time())
    return ""


def browser():
    return _state["browser"]


def headers():
    """Extra request headers for a signed-in InnerTube call, or {} when signed out."""
    with _lock:
        cookies = dict(_state["cookies"])
        stale = time.time() - _state["loaded"] > 1800 and _state["browser"]
    if stale:
        threading.Thread(target=load, args=(_state["browser"],), daemon=True).start()
    sapisid = cookies.get("SAPISID") or cookies.get("__Secure-3PAPISID")
    if not sapisid:
        return {}
    ts = str(int(time.time()))
    digest = hashlib.sha1(f"{ts} {sapisid} {ORIGIN}".encode()).hexdigest()
    return {
        "Cookie": "; ".join(f"{k}={v}" for k, v in cookies.items()),
        "Authorization": f"SAPISIDHASH {ts}_{digest}",
        "Origin": ORIGIN,
        "X-Origin": ORIGIN,
        "X-Goog-AuthUser": "0",
    }
