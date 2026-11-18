"""Settings stored as JSON in ~/.config/afterglow/settings.json."""
import json
import os
from pathlib import Path

from PySide6.QtCore import QObject, Property, Signal, Slot

CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "afterglow"
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "afterglow"
RUNTIME_DIR = Path(os.environ.get("XDG_RUNTIME_DIR") or "/tmp") / "afterglow"

DEFAULTS = {
    # background: clip | cover | image | video | color
    "background": "clip",
    "backgroundPath": "",
    "backgroundColor": "#0d0d12",
    "dim": 0.25,
    # accent: auto (from cover art) | fixed
    "accentMode": "auto",
    "accentColor": "#ff4f8b",
    "showClock": True,
    "showLyrics": True,
    "showQueue": True,
    "showCard": True,
    "showGlow": True,
    "glowStrength": 0.8,
    "clock24": True,
    # source: auto | youtube | soundcloud
    "source": "auto",
    # where to borrow the YouTube sign-in from: auto | off | firefox | chrome | chromium | brave | vivaldi | opera
    "signIn": "auto",
    # start the personal "My Mix" when Afterglow starts
    "autoplay": True,
    "clipQuality": 1080,
    "clipCacheMB": 1500,
    "volume": 70,
    "repeat": "off",
    "language": "auto",
    "autostart": False,
}


class Settings(QObject):
    changed = Signal()
    keyChanged = Signal(str)

    def __init__(self):
        super().__init__()
        self._path = CONFIG_DIR / "settings.json"
        self._data = dict(DEFAULTS)
        try:
            self._data.update(json.loads(self._path.read_text()))
        except (OSError, ValueError):
            pass

    def get(self, key):
        return self._data.get(key, DEFAULTS.get(key))

    @Slot(str, "QVariant")
    def set(self, key, value):
        if self._data.get(key) == value:
            return
        self._data[key] = value
        self._save()
        self.keyChanged.emit(key)
        self.changed.emit()

    @Slot()
    def reset(self):
        keep = {k: self._data[k] for k in ("volume",) if k in self._data}
        self._data = dict(DEFAULTS, **keep)
        self._save()
        self.changed.emit()

    def _save(self):
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        tmp = self._path.with_suffix(".tmp")
        tmp.write_text(json.dumps(self._data, indent=2, ensure_ascii=False))
        tmp.replace(self._path)

    def _get_data(self):
        return self._data

    data = Property("QVariant", _get_data, notify=changed)
