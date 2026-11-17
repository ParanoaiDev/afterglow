"""Find the official music video for a track and cache a video-only copy for the background."""
import glob
import os
import subprocess

from .config import CACHE_DIR
from .sources import youtube

CLIP_DIR = CACHE_DIR / "clips"


class SignInRequired(RuntimeError):
    pass


def ytdlp_error(stderr):
    text = (stderr or "").strip()
    if "Sign in to confirm" in text or "not a bot" in text:
        return SignInRequired(text)
    lines = [l for l in text.splitlines() if "ERROR" in l] or text.splitlines() or ["yt-dlp failed"]
    return RuntimeError(lines[-1])


def cached(video_id):
    for p in glob.glob(str(CLIP_DIR / f"{video_id}.*")):
        if not p.endswith((".part", ".ytdl", ".tmp")):
            return p
    return None


def fetch(video_id, quality=1080, cookies_browser=""):
    """Download (or reuse) a video-only clip. Blocking - call from a worker thread."""
    hit = cached(video_id)
    if hit:
        os.utime(hit)
        return hit
    CLIP_DIR.mkdir(parents=True, exist_ok=True)
    q = int(quality)
    fmt = f"bv*[height<={q}][vcodec^=avc1]/bv*[height<={q}]/b[height<={q}]/bv*/b"
    cmd = ["yt-dlp", "--no-warnings", "-q", "--no-playlist", "-f", fmt,
           "-o", str(CLIP_DIR / f"{video_id}.%(ext)s"), "https://www.youtube.com/watch?v=" + video_id]
    if cookies_browser:
        cmd[1:1] = ["--cookies-from-browser", cookies_browser]
    out = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    hit = cached(video_id)
    if out.returncode != 0 or not hit:
        raise ytdlp_error(out.stderr)
    return hit


def resolve(track, quality=1080, cookies_browser=""):
    """Returns (path, synced). synced means the clip is the very video being played as audio."""
    if track.get("source") == "youtube" and track.get("kind") == "video":
        return fetch(track["videoId"], quality, cookies_browser), True
    vid = youtube.find_clip(track.get("artist", ""), track.get("title", ""), track.get("duration") or 0)
    if not vid:
        return None, False
    synced = track.get("source") == "youtube" and vid == track.get("videoId")
    return fetch(vid, quality, cookies_browser), synced


def trim_cache(limit_mb=1500):
    files = [p for p in glob.glob(str(CLIP_DIR / "*")) if os.path.isfile(p)]
    files.sort(key=os.path.getmtime, reverse=True)
    total = 0
    for p in files:
        total += os.path.getsize(p)
        if total > limit_mb * 1024 * 1024:
            try:
                os.remove(p)
            except OSError:
                pass
