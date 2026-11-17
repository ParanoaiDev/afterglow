"""Better cover art and album names from the iTunes Search API (no key needed)."""
from .sources.common import norm, session


def lookup(artist, title):
    if not title:
        return None
    r = session.get("https://itunes.apple.com/search",
                    params={"term": f"{artist} {title}", "entity": "song", "limit": 8}, timeout=25)
    r.raise_for_status()
    want_t, want_a = norm(title), norm(artist)
    best, best_score = None, 0
    for it in r.json().get("results", []):
        s = 0
        nt = norm(it.get("trackName"))
        if nt == want_t:
            s += 3
        elif want_t and (want_t in nt or nt in want_t):
            s += 1
        if want_a and want_a in norm(it.get("artistName")):
            s += 2
        if s > best_score:
            best, best_score = it, s
    if not best or best_score < 4:
        return None
    art = (best.get("artworkUrl100") or "").replace("100x100bb", "1000x1000bb")
    album = best.get("collectionName") or ""
    if album.endswith(" - Single"):
        album = album[:-9]
    return {"cover": art, "album": album, "artist": best.get("artistName") or artist}
