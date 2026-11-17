"""SoundCloud search through yt-dlp (it knows how to talk to SoundCloud)."""
import json
import subprocess

from .common import split_title


def _ytdlp(*args, timeout=40):
    out = subprocess.run(["yt-dlp", "--no-warnings", "--ignore-errors", *args],
                         capture_output=True, text=True, timeout=timeout)
    if not out.stdout.strip():
        raise RuntimeError((out.stderr or "yt-dlp failed").strip().splitlines()[-1])
    return json.loads(out.stdout)


def _entry_to_track(e):
    url = e.get("webpage_url") or e.get("url") or ""
    if not url:
        return None
    thumb = e.get("thumbnail") or ""
    if not thumb and e.get("thumbnails"):
        thumb = e["thumbnails"][-1].get("url", "")
    thumb = thumb.replace("-large.", "-t500x500.").replace("-original.", "-t500x500.")
    uploader = e.get("uploader") or e.get("artist") or ""
    artist, title = split_title(e.get("title") or "", uploader)
    if artist == uploader and " - " not in (e.get("title") or ""):
        title = e.get("title") or title
    return {
        "id": "sc:" + str(e.get("id") or url),
        "source": "soundcloud",
        "url": url,
        "title": title,
        "artist": artist or uploader,
        "album": "",
        "duration": int(e.get("duration") or 0),
        "thumb": thumb,
        "kind": "song",
    }


def search(query, limit=10):
    data = _ytdlp("--flat-playlist", "-J", f"scsearch{limit}:{query}")
    tracks = []
    for e in data.get("entries") or []:
        t = _entry_to_track(e)
        if t:
            tracks.append(t)
    return {"tracks": tracks, "artists": []}


def details(url):
    """Full info for one track: thumbnail, and whether it can be streamed at all."""
    data = _ytdlp("-J", "--skip-download", url)
    t = _entry_to_track(data)
    return t
