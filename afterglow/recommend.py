"""Afterglow's own track picker.

YouTube's personal mixes only know the watch history, which for many people is games and vlogs,
not music. This picker starts from artists the listener chose, learns from what they finish,
skip, like or ban, and builds radio-style queues from YouTube's per-track radios.
"""
import json
import os
import random
import re
import threading
from pathlib import Path

from .sources import youtube
from .sources.common import norm

DATA_DIR = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share") / "afterglow"
_CYRILLIC = re.compile("[Ѐ-ӿ]")  # the whole Cyrillic block
_NOT_MUSIC = ("reaction", "реакция", "interview", "интервью", "podcast", "подкаст", "trailer", "трейлер",
              "tutorial", "how to", "review", "обзор", "full album", "mix 20", "playlist", "compilation",
              "сборник", "1 hour", "10 hours", "live stream", "karaoke", "караоке", "cover by", "instrumental",
              "#shorts", "slowed", "sped up", "8d audio", "nightcore", "bass boosted")


class Taste:
    def __init__(self):
        self.path = DATA_DIR / "taste.json"
        self.lock = threading.Lock()
        self.data = {"seeds": [], "artists": {}, "banned": [], "tracks": {}, "recent": []}
        try:
            self.data.update(json.loads(self.path.read_text()))
        except (OSError, ValueError):
            pass

    def save(self):
        with self.lock:
            DATA_DIR.mkdir(parents=True, exist_ok=True)
            tmp = self.path.with_suffix(".tmp")
            tmp.write_text(json.dumps(self.data, ensure_ascii=False, indent=1))
            tmp.replace(self.path)

    @property
    def seeds(self):
        return list(self.data["seeds"])

    def set_seeds(self, names):
        self.data["seeds"] = [n for n in dict.fromkeys(n.strip() for n in names) if n]
        seeds = {norm(n) for n in self.data["seeds"]}
        self.data["banned"] = [b for b in self.data["banned"] if norm(b) not in seeds]
        self.save()

    def bump(self, artist, delta):
        key = norm(artist)
        if not key:
            return
        a = self.data["artists"].setdefault(key, {"name": artist, "score": 0.0})
        a["score"] = max(-10.0, min(20.0, a["score"] + delta))
        self.save()

    def ban(self, artist):
        if artist and norm(artist) not in {norm(b) for b in self.data["banned"]}:
            self.data["banned"].append(artist)
        self.data["seeds"] = [s for s in self.data["seeds"] if norm(s) != norm(artist)]
        self.save()

    def track_event(self, track, event):
        """event: 'played' | 'finished' | 'skipped' | 'liked' | 'banned'"""
        vid = track.get("videoId") or track.get("id")
        artist = track.get("artist", "")
        t = self.data["tracks"].setdefault(vid, {"title": track.get("title", ""), "artist": artist,
                                                 "plays": 0, "skips": 0, "liked": False})
        if event == "played":
            t["plays"] += 1
            self.data["recent"] = ([vid] + [r for r in self.data["recent"] if r != vid])[:200]
            self.save()
        elif event == "finished":
            self.bump(artist, 1.0)
        elif event == "skipped":
            t["skips"] += 1
            self.bump(artist, -0.7)
        elif event == "liked":
            t["liked"] = True
            self.bump(artist, 3.0)
        elif event == "unliked":
            t["liked"] = False
            self.bump(artist, -3.0)
        elif event == "banned":
            self.ban(artist)

    def is_liked(self, vid):
        return bool(self.data["tracks"].get(vid, {}).get("liked"))

    def liked_tracks(self):
        return [(vid, t) for vid, t in self.data["tracks"].items() if t.get("liked")]

    def score(self, artist):
        return self.data["artists"].get(norm(artist), {}).get("score", 0.0)

    def is_banned(self, artist):
        a = norm(artist)
        return bool(a) and any(norm(b) == a for b in self.data["banned"])

    def skipped(self, vid):
        t = self.data["tracks"].get(vid)
        return bool(t and t["skips"] >= 1 and t["skips"] >= t["plays"])

    def recent(self, n=60):
        return set(self.data["recent"][:n])


def allowed(track, taste, no_russian=True):
    raw = " ".join((track.get("rawTitle") or track.get("title") or "", track.get("channel", ""), track.get("artist", "")))
    low = raw.lower()
    dur = track.get("duration") or 0
    if dur and (dur < 75 or dur > 8 * 60):
        return False
    if any(w in low for w in _NOT_MUSIC):
        return False
    if no_russian and _CYRILLIC.search(raw):
        return False
    if taste.is_banned(track.get("artist", "")) or taste.is_banned(track.get("channel", "")):
        return False
    return True


def seed_track(artist):
    """A well-known track (ideally the official video) of an artist to start a radio from."""
    res = youtube.search(f"{artist} official music video", limit=10)
    want = norm(artist)
    best, best_score = None, -1e9
    for i, t in enumerate(res["tracks"]):
        if not (60 < (t["duration"] or 0) < 9 * 60):
            continue
        s = 0.0
        if want and (want in norm(t["channel"]) or want in norm(t["artist"])):
            s += 3
        if "official" in t["rawTitle"].lower():
            s += 1
        s -= i * 0.2
        if s > best_score:
            best, best_score = t, s
    return best


def pick_seeds(taste, n=4):
    pool = {norm(s): [s, 6.0] for s in taste.seeds}
    for key, a in taste.data["artists"].items():
        if a["score"] > 0.5 and not taste.is_banned(a["name"]):
            entry = pool.setdefault(key, [a["name"], 0.0])
            entry[1] += a["score"]
    names = list(pool.values())
    chosen = []
    while names and len(chosen) < n:
        total = sum(max(w, 0.1) for _, w in names)
        r = random.uniform(0, total)
        for i, (name, w) in enumerate(names):
            r -= max(w, 0.1)
            if r <= 0:
                chosen.append(name)
                names.pop(i)
                break
    return chosen


def build(taste, no_russian=True, exclude_ids=(), size=40, from_tracks=None):
    """A fresh queue. from_tracks: continue from these tracks' radios instead of the seed artists."""
    starts = []
    if from_tracks:
        starts = [t for t in from_tracks if t.get("videoId")][:3]
    else:
        for name in pick_seeds(taste):
            try:
                t = seed_track(name)
            except Exception:  # noqa: BLE001
                t = None
            if t:
                starts.append(t)
        liked = taste.liked_tracks()
        if liked:
            vid, info = random.choice(liked)
            starts.append({"videoId": vid, "artist": info["artist"], "title": info["title"]})
    radios = []
    for st in starts:
        try:
            radios.append(youtube.mix(st["videoId"], limit=40))
        except Exception:  # noqa: BLE001
            pass
    skip_ids = set(exclude_ids) | taste.recent(80)
    seen_titles, out = set(), []
    for row in range(40):  # interleave the radios so one seed does not take over
        for radio in radios:
            if row >= len(radio):
                continue
            t = radio[row]
            vid = t.get("videoId")
            key = norm(t["artist"]) + "|" + norm(t["title"])
            if vid in skip_ids or key in seen_titles or taste.skipped(vid):
                continue
            if not allowed(t, taste, no_russian):
                continue
            seen_titles.add(key)
            out.append(t)
    order = {id(t): i for i, t in enumerate(out)}
    out.sort(key=lambda t: order[id(t)] * 0.25 - min(taste.score(t["artist"]), 4) * 0.8)
    result, pending = [], list(out)
    while pending and len(result) < size:  # never the same artist twice in a row
        for i, t in enumerate(pending):
            if not result or norm(t["artist"]) != norm(result[-1]["artist"]):
                result.append(pending.pop(i))
                break
        else:
            result.append(pending.pop(0))
    return result


def artist_suggestions(query):
    """Artists matching what the listener types in the taste picker."""
    res = youtube.search(query)
    out, seen = [], set()
    for a in res["artists"]:
        name = a["name"].replace(" - Topic", "")
        if norm(name) not in seen:
            seen.add(norm(name))
            out.append({"name": name, "thumb": a["thumb"]})
    for t in res["tracks"]:
        n = norm(t["artist"])
        if n and n not in seen and norm(query) in n:
            seen.add(n)
            out.append({"name": t["artist"], "thumb": t["thumb"]})
    return out[:8]
