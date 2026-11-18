"""YouTube search and mixes through the public InnerTube endpoints used by youtube.com."""
from .. import auth
from .common import norm, parse_duration, session, split_title

API = "https://www.youtube.com/youtubei/v1/"
CONTEXT = {"client": {"clientName": "WEB", "clientVersion": "2.20261117.00.00", "hl": "en"}}


def _post(endpoint, payload):
    r = session.post(API + endpoint + "?prettyPrint=false", json={"context": CONTEXT, **payload},
                     headers=auth.headers(), timeout=20)
    r.raise_for_status()
    return r.json()


def _text(node):
    if not node:
        return ""
    if "simpleText" in node:
        return node["simpleText"]
    return "".join(r.get("text", "") for r in node.get("runs", []))


def thumb(video_id):
    return f"https://i.ytimg.com/vi/{video_id}/hq720.jpg"


def track_from_video(video_id, title, channel, duration):
    artist, name = split_title(title, channel)
    low = title.lower()
    # "video": the upload is a real clip, so it can be the background in sync with the sound
    static = ("audio", "lyric", "текст", "visualizer", "visualiser", "slowed", "sped up", "speed up", "8d", "nightcore")
    if channel.endswith(" - Topic") or any(w in low for w in static):
        kind = "song"
    else:
        kind = "video"
    return {
        "id": "yt:" + video_id,
        "videoId": video_id,
        "source": "youtube",
        "url": "https://www.youtube.com/watch?v=" + video_id,
        "title": name,
        "artist": artist,
        "album": "",
        "duration": duration,
        "thumb": thumb(video_id),
        "kind": kind,
        "rawTitle": title,
        "channel": channel,
    }


def _walk_items(contents):
    for sec in contents:
        items = sec.get("itemSectionRenderer", {}).get("contents", [])
        for it in items:
            if "shelfRenderer" in it:
                sub = it["shelfRenderer"].get("content", {}).get("verticalListRenderer", {}).get("items", [])
                yield from sub
            else:
                yield it


def search(query, limit=24):
    data = _post("search", {"query": query})
    contents = data["contents"]["twoColumnSearchResultsRenderer"]["primaryContents"]["sectionListRenderer"]["contents"]
    tracks, artists, seen = [], [], set()
    for it in _walk_items(contents):
        if "videoRenderer" in it:
            v = it["videoRenderer"]
            vid = v.get("videoId")
            dur = parse_duration(_text(v.get("lengthText")))
            if not vid or vid in seen or not dur or dur > 15 * 60:
                continue  # skip live streams, mixes and long compilations
            seen.add(vid)
            channel = _text(v.get("ownerText") or v.get("longBylineText"))
            tracks.append(track_from_video(vid, _text(v.get("title")), channel, dur))
        elif "channelRenderer" in it:
            c = it["channelRenderer"]
            thumbs = c.get("thumbnail", {}).get("thumbnails", [])
            url = thumbs[-1]["url"] if thumbs else ""
            if url.startswith("//"):
                url = "https:" + url
            artists.append({"id": "ytc:" + c["channelId"], "channelId": c["channelId"], "source": "youtube",
                            "name": _text(c.get("title")), "thumb": url})
        if len(tracks) >= limit:
            break
    return {"tracks": tracks, "artists": artists}


def mix(video_id, limit=25):
    """YouTube's auto-generated radio for a video: the 'Up next' list."""
    return _panel(_post("next", {"videoId": video_id, "playlistId": "RD" + video_id}), limit)


def my_mix(after_video_id=None, limit=50):
    """The signed-in user's personal 'My Mix' (RDMM). Pass the last video id to get the continuation."""
    payload = {"playlistId": "RDMM"}
    if after_video_id:
        payload["videoId"] = after_video_id
    return _panel(_post("next", payload), limit)


def _panel(data, limit):
    panel = (data.get("contents", {}).get("twoColumnWatchNextResults", {})
             .get("playlist", {}).get("playlist", {}).get("contents", []))
    out = []
    for it in panel:
        v = it.get("playlistPanelVideoRenderer")
        if not v or not v.get("videoId"):
            continue
        dur = parse_duration(_text(v.get("lengthText")))
        if not dur or dur > 15 * 60:
            continue
        out.append(track_from_video(v["videoId"], _text(v.get("title")), _text(v.get("longBylineText") or v.get("shortBylineText")), dur))
        if len(out) >= limit:
            break
    return out


def artist_tracks(name):
    res = search(name + " songs")
    first = [t for t in res["tracks"] if norm(t["artist"]) == norm(name) or norm(t["channel"]).startswith(norm(name))]
    rest = [t for t in res["tracks"] if t not in first]
    return first + rest


def find_clip(artist, title, duration=0):
    """Video id of the official music video for a track, or None."""
    want_t, want_a = norm(title), norm(artist)
    if not want_t:
        return None
    res = search(f"{artist} {title} official music video", limit=12)
    best, best_score = None, 0
    for t in res["tracks"]:
        raw = t["rawTitle"].lower()
        if want_t not in norm(t["rawTitle"]):
            continue
        score = 1
        if "official" in raw and ("video" in raw or "visual" in raw):
            score += 3
        elif "video" in raw:
            score += 1
        if want_a and (want_a in norm(t["channel"]) or want_a in norm(t["rawTitle"])):
            score += 2
        if any(w in raw for w in ("lyric", "reaction", "cover", "instrumental", "karaoke", "slowed", "sped up", "8d", "remix", "live")):
            score -= 3
        if t["channel"].endswith(" - Topic"):
            score -= 1  # a static album-art video, not a clip
        if duration and abs(t["duration"] - duration) > 120:
            score -= 1
        if score > best_score:
            best, best_score = t, score
    return best["videoId"] if best and best_score >= 2 else None
