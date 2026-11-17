"""MPRIS2 server so KDE's media widget, lock screen and media keys can control Afterglow."""
import asyncio
import threading

from PySide6.QtCore import QObject, Signal

try:
    from dbus_fast import BusType, Variant
    from dbus_fast.aio import MessageBus
    from dbus_fast.service import PropertyAccess, ServiceInterface, dbus_property, method, signal
except ImportError:  # optional dependency
    MessageBus = None

PATH = "/org/mpris/MediaPlayer2"


class Mpris(QObject):
    request = Signal(str, object)  # delivered on the GUI thread

    def __init__(self, position_fn):
        super().__init__()
        self.position_fn = position_fn
        self.state = {"status": "Stopped", "title": "", "artist": "", "album": "", "art": "",
                      "length": 0, "volume": 0.7, "trackNo": 0, "canNext": False, "canPrev": False}
        self.loop = None
        self.player = None
        if MessageBus is None:
            return
        threading.Thread(target=self._run, daemon=True, name="mpris").start()

    def _run(self):
        self.loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self.loop)
        try:
            self.loop.run_until_complete(self._setup())
        except Exception as exc:  # noqa: BLE001 - no session bus is not fatal
            print("[mpris] disabled:", exc)
            return
        self.loop.run_forever()

    async def _setup(self):
        bus = await MessageBus(bus_type=BusType.SESSION).connect()
        self.player = _Player(self)
        bus.export(PATH, _Root(self))
        bus.export(PATH, self.player)
        await bus.request_name("org.mpris.MediaPlayer2.afterglow")

    def update(self, state):
        if not self.loop:
            self.state.update(state)
            return
        self.loop.call_soon_threadsafe(self._apply, dict(state))

    def _apply(self, state):
        old = self.state
        self.state = {**old, **state}
        if not self.player:
            return
        changed = {}
        if old.get("status") != self.state["status"]:
            changed["PlaybackStatus"] = self.state["status"]
        if any(old.get(k) != self.state[k] for k in ("title", "artist", "album", "art", "length", "trackNo")):
            changed["Metadata"] = self.player.metadata()
        if old.get("volume") != self.state["volume"]:
            changed["Volume"] = self.state["volume"]
        if old.get("canNext") != self.state["canNext"]:
            changed["CanGoNext"] = self.state["canNext"]
        if changed:
            self.player.emit_properties_changed(changed)

    def ask(self, what, arg=None):
        self.request.emit(what, arg)


if MessageBus is not None:

    class _Root(ServiceInterface):
        def __init__(self, ctl):
            super().__init__("org.mpris.MediaPlayer2")
            self.ctl = ctl

        @method()
        def Raise(self):
            self.ctl.ask("raise")

        @method()
        def Quit(self):
            self.ctl.ask("quit")

        @dbus_property(access=PropertyAccess.READ)
        def CanQuit(self) -> "b":
            return True

        @dbus_property(access=PropertyAccess.READ)
        def CanRaise(self) -> "b":
            return True

        @dbus_property(access=PropertyAccess.READ)
        def HasTrackList(self) -> "b":
            return False

        @dbus_property(access=PropertyAccess.READ)
        def Identity(self) -> "s":
            return "Afterglow"

        @dbus_property(access=PropertyAccess.READ)
        def DesktopEntry(self) -> "s":
            return "afterglow"

        @dbus_property(access=PropertyAccess.READ)
        def SupportedUriSchemes(self) -> "as":
            return []

        @dbus_property(access=PropertyAccess.READ)
        def SupportedMimeTypes(self) -> "as":
            return []

    class _Player(ServiceInterface):
        def __init__(self, ctl):
            super().__init__("org.mpris.MediaPlayer2.Player")
            self.ctl = ctl

        def metadata(self):
            s = self.ctl.state
            md = {"mpris:trackid": Variant("o", f"/org/afterglow/track/{int(s['trackNo'])}")}
            if s["title"]:
                md["xesam:title"] = Variant("s", s["title"])
            if s["artist"]:
                md["xesam:artist"] = Variant("as", [s["artist"]])
            if s["album"]:
                md["xesam:album"] = Variant("s", s["album"])
            if s["art"]:
                md["mpris:artUrl"] = Variant("s", s["art"])
            if s["length"]:
                md["mpris:length"] = Variant("x", int(s["length"] * 1_000_000))
            return md

        @method()
        def Next(self):
            self.ctl.ask("next")

        @method()
        def Previous(self):
            self.ctl.ask("prev")

        @method()
        def Pause(self):
            self.ctl.ask("pause")

        @method()
        def PlayPause(self):
            self.ctl.ask("toggle")

        @method()
        def Stop(self):
            self.ctl.ask("pause")

        @method()
        def Play(self):
            self.ctl.ask("play")

        @method()
        def Seek(self, offset: "x"):
            self.ctl.ask("seek", self.ctl.position_fn() + offset / 1_000_000)

        @method()
        def SetPosition(self, track_id: "o", position: "x"):
            self.ctl.ask("seek", position / 1_000_000)

        @method()
        def OpenUri(self, uri: "s"):
            pass

        @signal()
        def Seeked(self) -> "x":
            return int(self.ctl.position_fn() * 1_000_000)

        @dbus_property(access=PropertyAccess.READ)
        def PlaybackStatus(self) -> "s":
            return self.ctl.state["status"]

        @dbus_property()
        def LoopStatus(self) -> "s":
            return "None"

        @LoopStatus.setter
        def LoopStatus(self, value: "s"):
            pass

        @dbus_property()
        def Rate(self) -> "d":
            return 1.0

        @Rate.setter
        def Rate(self, value: "d"):
            pass

        @dbus_property()
        def Shuffle(self) -> "b":
            return False

        @Shuffle.setter
        def Shuffle(self, value: "b"):
            pass

        @dbus_property(access=PropertyAccess.READ)
        def Metadata(self) -> "a{sv}":
            return self.metadata()

        @dbus_property()
        def Volume(self) -> "d":
            return float(self.ctl.state["volume"])

        @Volume.setter
        def Volume(self, value: "d"):
            self.ctl.ask("volume", int(max(0.0, min(1.0, value)) * 100))

        @dbus_property(access=PropertyAccess.READ)
        def Position(self) -> "x":
            return int(self.ctl.position_fn() * 1_000_000)

        @dbus_property(access=PropertyAccess.READ)
        def MinimumRate(self) -> "d":
            return 1.0

        @dbus_property(access=PropertyAccess.READ)
        def MaximumRate(self) -> "d":
            return 1.0

        @dbus_property(access=PropertyAccess.READ)
        def CanGoNext(self) -> "b":
            return bool(self.ctl.state["canNext"])

        @dbus_property(access=PropertyAccess.READ)
        def CanGoPrevious(self) -> "b":
            return bool(self.ctl.state["canPrev"])

        @dbus_property(access=PropertyAccess.READ)
        def CanPlay(self) -> "b":
            return True

        @dbus_property(access=PropertyAccess.READ)
        def CanPause(self) -> "b":
            return True

        @dbus_property(access=PropertyAccess.READ)
        def CanSeek(self) -> "b":
            return True

        @dbus_property(access=PropertyAccess.READ)
        def CanControl(self) -> "b":
            return True
