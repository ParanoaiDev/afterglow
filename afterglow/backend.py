"""The object QML talks to: playback state, queue, search, lyrics, colors and the background clip."""
import bisect
import os
import shutil
import subprocess
import sys
from pathlib import Path

from PySide6.QtCore import QObject, Property, QTimer, QUrl, Signal, Slot

from . import clips, colors, i18n, lyrics, meta, tasks
from .player import MpvPlayer
from .sources import soundcloud, youtube

SOURCE_NAMES = {"youtube": "YouTube", "soundcloud": "SoundCloud", "auto": "YouTube"}


class Backend(QObject):
    positionChanged = Signal()
    trackChanged = Signal()
    queueChanged = Signal()
    searchChanged = Signal()
    lyricsChanged = Signal()
    lineChanged = Signal()
    lookChanged = Signal()
    stateChanged = Signal()
    stringsChanged = Signal()
    toastRequested = Signal(str)
    openSearchRequested = Signal()
    visibilityToggleRequested = Signal()

    def __init__(self, settings):
        super().__init__()
        self.settings = settings
        self._lang = i18n.pick_language(settings.get("language"))
        self._strings = i18n.strings(self._lang)
        self._track = None
        self._queue = []
        self._qindex = -1
        self._position = 0.0
        self._duration = 0.0
        self._paused = True
        self._loading = False
        self._search = {"query": "", "loading": False, "tracks": [], "artists": [], "error": ""}
        self._lyric_versions = []
        self._lyric_choice = 0
        self._lyrics = {"status": "none", "synced": False, "lines": [], "label": "", "versions": 0}
        self._line_times = []
        self._line = -1
        self._accent_auto = colors.FALLBACK
        self._cover = ""
        self._clip = {"path": "", "synced": False, "loading": False}
        self._gen = 0
        self._search_gen = 0
        self._fallback_tried = set()

        self.player = MpvPlayer()
        self.player.positionChanged.connect(self._on_position)
        self.player.durationChanged.connect(self._on_duration)
        self.player.pausedChanged.connect(self._on_paused)
        self.player.loaded.connect(self._on_loaded)
        self.player.ended.connect(self._on_ended)
        self.player.failed.connect(self._on_failed)
        settings.keyChanged.connect(self._on_setting)
        self.mpris = None

    def start(self):
        if not self.player.available:
            QTimer.singleShot(1500, lambda: self.toastRequested.emit(self._strings["errMpv"]))
            return
        self.player.start(self.settings.get("cookiesBrowser"), self.settings.get("volume"))
        QTimer.singleShot(3000, lambda: tasks.run(clips.trim_cache, self.settings.get("clipCacheMB")))

    def shutdown(self):
        self.player.stop_process()

    # ---------------------------------------------------------------- properties
    def _p(name, signal):  # noqa: N805 - tiny helper for read-only properties
        return Property("QVariant", lambda self: getattr(self, "_" + name), notify=signal)

    position = Property(float, lambda self: self._position, notify=positionChanged)
    duration = Property(float, lambda self: self._duration, notify=trackChanged)
    track = _p("track", trackChanged)
    queue = _p("queue", queueChanged)
    queueIndex = Property(int, lambda self: self._qindex, notify=queueChanged)
    search = _p("search", searchChanged)
    lyrics = _p("lyrics", lyricsChanged)
    line = Property(int, lambda self: self._line, notify=lineChanged)
    clip = _p("clip", lookChanged)
    cover = Property(str, lambda self: self._cover, notify=lookChanged)
    paused = Property(bool, lambda self: self._paused, notify=stateChanged)
    loading = Property(bool, lambda self: self._loading, notify=stateChanged)
    strings = _p("strings", stringsChanged)
    language = Property(str, lambda self: self._lang, notify=stringsChanged)

    def _get_accent(self):
        if self.settings.get("accentMode") == "fixed":
            return self.settings.get("accentColor")
        return self._accent_auto

    accent = Property(str, _get_accent, notify=lookChanged)

    def _get_source(self):
        return self.settings.get("source")

    source = Property(str, _get_source, notify=stateChanged)

    def _get_source_label(self):
        if self._track:
            return SOURCE_NAMES.get(self._track.get("source"), "")
        return SOURCE_NAMES.get(self.settings.get("source"), "YouTube")

    sourceLabel = Property(str, _get_source_label, notify=trackChanged)

    # ---------------------------------------------------------------- search
    @Slot(str)
    def doSearch(self, query):
        query = (query or "").strip()
        self._search_gen += 1
        gen = self._search_gen
        if not query:
            self._search = {"query": "", "loading": False, "tracks": [], "artists": [], "error": ""}
            self.searchChanged.emit()
            return
        self._search = {"query": query, "loading": True, "tracks": [], "artists": [], "error": ""}
        self.searchChanged.emit()
        src = self.settings.get("source")
        pending = {"n": 0}

        def merge(res, name):
            if gen != self._search_gen:
                return
            s = dict(self._search)
            if name == "youtube":
                s["tracks"] = res["tracks"] + s["tracks"]
                s["artists"] = res["artists"] + s["artists"]
            else:
                s["tracks"] = s["tracks"] + res["tracks"]
                s["artists"] = s["artists"] + res["artists"]
            done(s)

        def fail(exc):
            if gen != self._search_gen:
                return
            s = dict(self._search)
            if not s["tracks"]:
                s["error"] = self._strings["errSearch"].format(str(exc)[:120])
            done(s)

        def done(s):
            pending["n"] -= 1
            s["loading"] = pending["n"] > 0
            self._search = s
            self.searchChanged.emit()

        if src in ("auto", "youtube"):
            pending["n"] += 1
            tasks.run(youtube.search, query, on_done=lambda r: merge(r, "youtube"), on_error=fail)
        if src in ("auto", "soundcloud"):
            pending["n"] += 1
            tasks.run(soundcloud.search, query, 8 if src == "auto" else 16,
                      on_done=lambda r: merge(r, "soundcloud"), on_error=fail)

    @Slot("QVariant")
    def openArtist(self, artist):
        name = artist.get("name", "")
        self._search_gen += 1
        gen = self._search_gen
        self._search = {"query": name, "loading": True, "tracks": [], "artists": [artist], "error": ""}
        self.searchChanged.emit()

        def ok(tracks):
            if gen == self._search_gen:
                self._search = {"query": name, "loading": False, "tracks": tracks, "artists": [artist], "error": ""}
                self.searchChanged.emit()

        tasks.run(youtube.artist_tracks, name, on_done=ok,
                  on_error=lambda e: ok([]))

    # ---------------------------------------------------------------- playback
    @Slot("QVariant")
    def playResult(self, track):
        tracks = self._search.get("tracks") or []
        rest = [t for t in tracks if t.get("id") != track.get("id") and t.get("source") == track.get("source")]
        if track.get("source") == "soundcloud":
            self._set_queue([track] + rest[:20], 0)
        else:
            self._set_queue([track], 0)
            self._extend_with_mix(track)
        self._play_current()

    @Slot(int)
    def playQueue(self, index):
        if 0 <= index < len(self._queue):
            self._qindex = index
            self.queueChanged.emit()
            self._play_current()

    def _set_queue(self, items, index):
        self._queue = list(items)
        self._qindex = index
        self.queueChanged.emit()

    def _extend_with_mix(self, track):
        if track.get("source") != "youtube":
            return
        gen = self._gen

        def ok(items):
            known = {t["id"] for t in self._queue}
            add = [t for t in items if t["id"] not in known]
            if add:
                self._queue = self._queue + add
                self.queueChanged.emit()

        tasks.run(youtube.mix, track["videoId"], on_done=ok)

    def _play_current(self):
        if not (0 <= self._qindex < len(self._queue)):
            return
        track = dict(self._queue[self._qindex])
        self._gen += 1
        gen = self._gen
        self._track = track
        self._duration = float(track.get("duration") or 0)
        self._position = 0.0
        self._loading = True
        self._cover = track.get("thumb") or ""
        self._clip = {"path": "", "synced": False, "loading": False}
        self._set_lyrics_loading()
        self.trackChanged.emit()
        self.positionChanged.emit()
        self.stateChanged.emit()
        self.lookChanged.emit()
        self.player.load(track["url"])
        self._update_mpris()

        if self._cover:
            tasks.run(colors.accent_from_url, self._cover, on_done=lambda c: self._set_accent(gen, c))

        def got_meta(m):
            if gen != self._gen or not m:
                return
            t = dict(self._track)
            t["album"] = m["album"]
            t["cover"] = m["cover"]
            self._track = t
            self._cover = m["cover"] or self._cover
            self.trackChanged.emit()
            self.lookChanged.emit()
            self._update_mpris()
            if m["cover"]:
                tasks.run(colors.accent_from_url, m["cover"], on_done=lambda c: self._set_accent(gen, c))

        tasks.run(meta.lookup, track.get("artist", ""), track.get("title", ""), on_done=got_meta)
        tasks.run(lyrics.candidates, track.get("artist", ""), track.get("title", ""), "", track.get("duration") or 0,
                  on_done=lambda v: self._set_lyrics(gen, v), on_error=lambda e: self._set_lyrics(gen, []))
        self._load_clip()

    def _set_accent(self, gen, color):
        if gen == self._gen:
            self._accent_auto = color
            self.lookChanged.emit()

    def _load_clip(self):
        track = self._track
        if not track or self.settings.get("background") != "clip":
            return
        gen = self._gen
        self._clip = {"path": "", "synced": False, "loading": True}
        self.lookChanged.emit()

        def ok(res):
            if gen != self._gen:
                return
            path, synced = res
            self._clip = {"path": QUrl.fromLocalFile(path).toString() if path else "", "synced": synced, "loading": False}
            self.lookChanged.emit()

        def err(exc):
            if gen != self._gen:
                return
            self._clip = {"path": "", "synced": False, "loading": False}
            self.lookChanged.emit()
            if isinstance(exc, clips.SignInRequired):
                self.toastRequested.emit(self._strings["errBot"])

        tasks.run(clips.resolve, track, self.settings.get("clipQuality"), self.settings.get("cookiesBrowser"),
                  on_done=ok, on_error=err)

    @Slot()
    def toggle(self):
        if not self._track:
            return
        self.player.set_paused(not self._paused)

    @Slot()
    def play(self):
        if self._track:
            self.player.set_paused(False)

    @Slot()
    def pause(self):
        self.player.set_paused(True)

    @Slot()
    def next(self):
        if self._qindex + 1 < len(self._queue):
            self._qindex += 1
        elif self.settings.get("repeat") == "all" and self._queue:
            self._qindex = 0
        else:
            return
        self.queueChanged.emit()
        self._play_current()

    @Slot()
    def prev(self):
        if self._position > 3 or self._qindex <= 0:
            self.seek(0)
            return
        self._qindex -= 1
        self.queueChanged.emit()
        self._play_current()

    @Slot(float)
    def seek(self, seconds):
        self.player.seek(max(0.0, seconds))

    @Slot(int)
    def setVolume(self, vol):
        vol = max(0, min(100, int(vol)))
        self.player.set_volume(vol)
        self.settings.set("volume", vol)
        self._update_mpris()

    @Slot()
    def cycleRepeat(self):
        order = ["off", "all", "one"]
        cur = self.settings.get("repeat")
        self.settings.set("repeat", order[(order.index(cur) + 1) % 3] if cur in order else "all")

    @Slot(str)
    def setSource(self, src):
        self.settings.set("source", src)
        self.stateChanged.emit()
        if self._search.get("query"):
            self.doSearch(self._search["query"])

    # ---------------------------------------------------------------- player events
    def _on_position(self, pos):
        self._position = pos
        self.positionChanged.emit()
        self._update_line()

    def _on_duration(self, dur):
        if dur > 0 and abs(dur - self._duration) > 0.5:
            self._duration = dur
            self.trackChanged.emit()

    def _on_paused(self, paused):
        self._paused = paused
        self.stateChanged.emit()
        self._update_mpris()

    def _on_loaded(self):
        self._loading = False
        self._paused = False
        self.stateChanged.emit()
        self._update_mpris()

    def _on_ended(self):
        if self.settings.get("repeat") == "one":
            self.seek(0)
            self.player.load(self._track["url"])
            return
        if self._qindex + 1 >= len(self._queue) and self._track and self._track.get("source") == "youtube":
            self._extend_with_mix(self._track)
            QTimer.singleShot(2500, self.next)
            return
        self.next()

    def _on_failed(self, err):
        self._loading = False
        self.stateChanged.emit()
        track = self._track or {}
        low = (err or "").lower()
        if "sign in" in low or "not a bot" in low:
            self.toastRequested.emit(self._strings["errBot"])
            return
        if track.get("source") == "soundcloud" and track.get("id") not in self._fallback_tried:
            # Major-label tracks on SoundCloud are DRM-locked; play the same song from YouTube instead.
            self._fallback_tried.add(track.get("id"))
            self.toastRequested.emit(self._strings["errDrm"])
            gen = self._gen

            def ok(res):
                if gen != self._gen or not res["tracks"]:
                    self.toastRequested.emit(self._strings["errPlay"])
                    return
                q = list(self._queue)
                q[self._qindex] = res["tracks"][0]
                self._queue = q
                self.queueChanged.emit()
                self._play_current()

            tasks.run(youtube.search, f"{track.get('artist', '')} {track.get('title', '')}", on_done=ok)
            return
        self.toastRequested.emit(self._strings["errPlay"] + (": " + err[:140] if err else ""))

    # ---------------------------------------------------------------- lyrics
    def _set_lyrics_loading(self):
        self._lyric_versions = []
        self._lyric_choice = 0
        self._lyrics = {"status": "loading", "synced": False, "lines": [], "label": "", "versions": 0}
        self._line_times = []
        self._line = -1
        self.lyricsChanged.emit()
        self.lineChanged.emit()

    def _set_lyrics(self, gen, versions):
        if gen != self._gen:
            return
        self._lyric_versions = versions or []
        self._lyric_choice = 0
        self._apply_lyrics()

    def _apply_lyrics(self):
        if not self._lyric_versions:
            self._lyrics = {"status": "none", "synced": False, "lines": [], "label": "", "versions": 0}
            self._line_times = []
        else:
            v = self._lyric_versions[self._lyric_choice % len(self._lyric_versions)]
            self._lyrics = {"status": "ok", "synced": v["synced"], "lines": v["lines"], "label": v["label"],
                            "versions": len(self._lyric_versions), "choice": self._lyric_choice}
            self._line_times = [l["t"] for l in v["lines"]] if v["synced"] else []
        self._line = -1
        self.lyricsChanged.emit()
        self._update_line()

    @Slot()
    def otherLyrics(self):
        if len(self._lyric_versions) > 1:
            self._lyric_choice = (self._lyric_choice + 1) % len(self._lyric_versions)
            self._apply_lyrics()

    def _update_line(self):
        if not self._line_times:
            return
        idx = bisect.bisect_right(self._line_times, self._position + 0.15) - 1
        if idx != self._line:
            self._line = idx
            self.lineChanged.emit()

    # ---------------------------------------------------------------- settings
    def _on_setting(self, key):
        if key == "cookiesBrowser":
            pos, track, paused = self._position, self._track, self._paused
            self.player.start(self.settings.get("cookiesBrowser"), self.settings.get("volume"))
            if track:
                self._play_current()
        elif key == "background":
            if self.settings.get("background") == "clip" and not self._clip.get("path"):
                self._load_clip()
        elif key in ("accentMode", "accentColor"):
            self.lookChanged.emit()
        elif key == "language":
            self._lang = i18n.pick_language(self.settings.get("language"))
            self._strings = i18n.strings(self._lang)
            self.stringsChanged.emit()
        elif key == "autostart":
            self._write_autostart(self.settings.get("autostart"))
        elif key == "source":
            self.stateChanged.emit()

    @Slot(str, result=str)
    def pickFile(self, kind):
        """Out-of-process file picker, so it is a normal window even though we are a desktop layer."""
        filt = "Images (*.png *.jpg *.jpeg *.webp *.gif)" if kind == "image" else "Video (*.mp4 *.mkv *.webm *.mov)"
        start = str(Path.home())
        for cmd in (["kdialog", "--getopenfilename", start, filt],
                    ["zenity", "--file-selection"]):
            if shutil.which(cmd[0]):
                try:
                    out = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
                except subprocess.TimeoutExpired:
                    return ""
                return out.stdout.strip()
        return ""

    @Slot(str, result=str)
    def fileUrl(self, path):
        return QUrl.fromLocalFile(path).toString() if path else ""

    def _write_autostart(self, enabled):
        path = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "autostart" / "afterglow.desktop"
        if not enabled:
            path.unlink(missing_ok=True)
            return
        exe = shutil.which("afterglow")
        if exe:
            cmd = exe
        else:
            root = Path(__file__).resolve().parent.parent
            cmd = f"env PYTHONPATH={root} {sys.executable} -m afterglow"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("[Desktop Entry]\nType=Application\nName=Afterglow\n"
                        f"Exec={cmd}\nIcon=afterglow\nX-KDE-autostart-phase=2\n")

    # ---------------------------------------------------------------- mpris
    def _update_mpris(self):
        if not self.mpris:
            return
        t = self._track or {}
        self.mpris.update({
            "status": "Stopped" if not t else ("Paused" if self._paused else "Playing"),
            "title": t.get("title", ""),
            "artist": t.get("artist", ""),
            "album": t.get("album", ""),
            "art": self._cover,
            "length": self._duration,
            "volume": self.settings.get("volume") / 100.0,
            "trackNo": self._gen,
            "canNext": self._qindex + 1 < len(self._queue),
            "canPrev": bool(t),
        })

    def mpris_position(self):
        return self._position
