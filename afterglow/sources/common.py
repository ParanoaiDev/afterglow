import re
import unicodedata

import requests

UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36"

session = requests.Session()
session.headers["User-Agent"] = UA

_JUNK_WORDS = (
    "official", "video", "audio", "lyric", "lyrics", "visualizer", "visualiser", "hd", "hq", "4k",
    "explicit", "clean", "mv", "m/v", "remaster", "remastered", "music", "live", "prod", "dir",
)
_BRACKETS = re.compile(r"\s*[\(\[\{]([^\)\]\}]*)[\)\]\}]")


def _strip_junk(text):
    def repl(m):
        inner = m.group(1).lower()
        if any(w in inner for w in _JUNK_WORDS):
            return ""
        return m.group(0)

    text = _BRACKETS.sub(repl, text)
    text = re.sub(r"\s*\|.*$", "", text)
    text = re.sub(r"\s+(official\s+)?(music\s+)?(video|audio|visualizer)\s*$", "", text, flags=re.I)
    return text.strip(" -–—_\"'“”«»").strip()


def split_title(title, channel=""):
    """'Kodak Black - Transportin’ [Official Music Video]' -> ('Kodak Black', 'Transportin’')."""
    channel = re.sub(r"\s*-\s*Topic$", "", channel or "").strip()
    channel = re.sub(r"VEVO$", "", channel).strip()
    t = title.strip()
    m = re.match(r"^(.+?)\s+[-–—]\s+(.+)$", t)
    if m:
        artist, name = m.group(1), m.group(2)
    else:
        m = re.match(r"^(.+?)\s+[\"“«](.+?)[\"”»](.*)$", t)  # Artist "Title" (extra)
        if m:
            artist, name = m.group(1), m.group(2) + m.group(3)
        else:
            artist, name = channel, t
    name = _strip_junk(name) or name
    artist = _strip_junk(artist) or artist
    return artist.strip(), name.strip()


def norm(text):
    text = unicodedata.normalize("NFKD", text or "").lower()
    text = text.replace("’", "'")
    text = re.sub(r"\(.*?\)|\[.*?\]", " ", text)
    text = re.sub(r"feat\.?.*$|ft\.?.*$", " ", text)
    return re.sub(r"[^a-z0-9а-яё]+", " ", text).strip()


def parse_duration(text):
    if not text:
        return 0
    try:
        parts = [int(p) for p in text.strip().split(":")]
    except ValueError:
        return 0
    secs = 0
    for p in parts:
        secs = secs * 60 + p
    return secs
