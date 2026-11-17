"""Time-synced lyrics from LRCLIB (https://lrclib.net), a free open lyrics database."""
import re

from .sources.common import norm, session

API = "https://lrclib.net/api/"
HEADERS = {"User-Agent": "Afterglow/0.1 (desktop music player)"}
_STAMP = re.compile(r"\[(\d+):(\d+(?:\.\d+)?)\]")


def parse_lrc(text):
    lines = []
    for raw in (text or "").splitlines():
        stamps = _STAMP.findall(raw)
        if not stamps:
            continue
        words = _STAMP.sub("", raw).strip()
        for mm, ss in stamps:
            lines.append({"t": int(mm) * 60 + float(ss), "text": words})
    lines.sort(key=lambda l: l["t"])
    return lines


def _get(path, params):
    r = session.get(API + path, params=params, headers=HEADERS, timeout=12)
    if r.status_code == 404:
        return None
    r.raise_for_status()
    return r.json()


def candidates(artist, title, album="", duration=0):
    """All usable lyric versions for a track, best first."""
    found, seen = [], set()

    def add(item):
        if not item or item.get("id") in seen or item.get("instrumental"):
            return
        if not (item.get("syncedLyrics") or item.get("plainLyrics")):
            return
        seen.add(item.get("id"))
        found.append(item)

    params = {"artist_name": artist, "track_name": title}
    if album:
        params["album_name"] = album
    if duration:
        params["duration"] = int(duration)
    try:
        add(_get("get", params))
    except Exception:  # noqa: BLE001 - try the search below anyway
        pass
    for p in ({"track_name": title, "artist_name": artist}, {"q": f"{artist} {title}"}):
        try:
            for item in _get("search", p) or []:
                add(item)
        except Exception:  # noqa: BLE001
            pass
        if len(found) >= 6:
            break

    want_t, want_a = norm(title), norm(artist)

    def score(item):
        s = 0.0
        if item.get("syncedLyrics"):
            s += 10
        if norm(item.get("trackName")) == want_t:
            s += 4
        elif want_t and want_t in norm(item.get("trackName")):
            s += 2
        if want_a and want_a in norm(item.get("artistName")):
            s += 3
        if duration and item.get("duration"):
            s -= min(abs(item["duration"] - duration), 60) / 6
        return s

    found.sort(key=score, reverse=True)
    out = []
    for item in found:
        synced = parse_lrc(item.get("syncedLyrics"))
        if synced:
            out.append({"id": item.get("id"), "synced": True, "lines": synced,
                        "label": f"{item.get('artistName', '')} — {item.get('trackName', '')}"})
        else:
            plain = [l.strip() for l in (item.get("plainLyrics") or "").splitlines() if l.strip()]
            out.append({"id": item.get("id"), "synced": False, "lines": [{"t": -1, "text": l} for l in plain],
                        "label": f"{item.get('artistName', '')} — {item.get('trackName', '')}"})
    return out
