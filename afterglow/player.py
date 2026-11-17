"""Audio playback through an mpv process controlled over its JSON IPC socket."""
import json
import os
import shutil

from PySide6.QtCore import QObject, QProcess, QTimer, Signal
from PySide6.QtNetwork import QLocalSocket

from .config import RUNTIME_DIR

_OBS = {1: "time-pos", 2: "duration", 3: "pause", 4: "idle-active"}


class MpvPlayer(QObject):
    positionChanged = Signal(float)
    durationChanged = Signal(float)
    pausedChanged = Signal(bool)
    loaded = Signal()
    ended = Signal()
    failed = Signal(str)
    ready = Signal()

    def __init__(self):
        super().__init__()
        self.proc = None
        self.sock = QLocalSocket(self)
        self.sock.readyRead.connect(self._read)
        self.sock.connected.connect(self._on_connected)
        self._buf = b""
        self._path = str(RUNTIME_DIR / f"mpv-{os.getpid()}.sock")
        self._retry = QTimer(self, interval=100)
        self._retry.timeout.connect(self._try_connect)
        self._tries = 0
        self._last_error = ""
        self._pending = []
        self._expect_stop = False
        self.available = shutil.which("mpv") is not None

    # -- process -------------------------------------------------------
    def start(self, cookies_browser="", volume=70):
        if not self.available:
            return
        self.stop_process()
        RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
        if os.path.exists(self._path):
            os.remove(self._path)
        args = [
            "--idle=yes", "--no-video", "--no-input-terminal", "--audio-display=no",
            "--input-ipc-server=" + self._path,
            "--ytdl-format=bestaudio/best",
            "--msg-level=all=error,ytdl_hook=error",
            "--cache=yes", "--demuxer-max-bytes=64MiB",
            f"--volume={int(volume)}",
        ]
        if cookies_browser:
            args.append(f"--ytdl-raw-options-append=cookies-from-browser={cookies_browser}")
        self.proc = QProcess(self)
        self.proc.setProcessChannelMode(QProcess.MergedChannels)
        self.proc.readyReadStandardOutput.connect(self._read_log)
        self.proc.start("mpv", args)
        self._tries = 0
        self._retry.start()

    def stop_process(self):
        self._retry.stop()
        if self.sock.state() != QLocalSocket.UnconnectedState:
            self.sock.abort()
        if self.proc:
            self.proc.readyReadStandardOutput.disconnect()
            self.proc.terminate()
            if not self.proc.waitForFinished(1500):
                self.proc.kill()
            self.proc = None

    def _read_log(self):
        text = bytes(self.proc.readAllStandardOutput()).decode(errors="replace")
        for line in text.splitlines():
            line = line.strip()
            if line:
                # keep the first real error (e.g. the yt-dlp one); later lines are only consequences
                if "ERROR" in line or not self._last_error:
                    if not ("ERROR" in self._last_error and "ERROR" not in line):
                        self._last_error = line
                print("[mpv]", line)

    def _try_connect(self):
        self._tries += 1
        if self._tries > 80:
            self._retry.stop()
            self.failed.emit("mpv did not start")
            return
        if os.path.exists(self._path) and self.sock.state() == QLocalSocket.UnconnectedState:
            self.sock.connectToServer(self._path)

    def _on_connected(self):
        self._retry.stop()
        for oid, name in _OBS.items():
            self._send(["observe_property", oid, name])
        for cmd in self._pending:
            self._send(cmd)
        self._pending.clear()
        self.ready.emit()

    # -- ipc -----------------------------------------------------------
    def _send(self, command):
        if self.sock.state() != QLocalSocket.ConnectedState:
            self._pending.append(command)
            return
        self.sock.write((json.dumps({"command": command}) + "\n").encode())
        self.sock.flush()

    def _read(self):
        self._buf += bytes(self.sock.readAll())
        *lines, self._buf = self._buf.split(b"\n")
        for raw in lines:
            if not raw.strip():
                continue
            try:
                msg = json.loads(raw)
            except ValueError:
                continue
            ev = msg.get("event")
            if ev == "property-change":
                self._prop(msg.get("id"), msg.get("data"))
            elif ev == "file-loaded":
                self._last_error = ""
                self.loaded.emit()
            elif ev == "end-file":
                reason = msg.get("reason")
                if reason == "eof":
                    self.ended.emit()
                elif reason == "error":
                    self.failed.emit(self._last_error or msg.get("file_error") or "error")

    def _prop(self, oid, data):
        name = _OBS.get(oid)
        if name == "time-pos" and data is not None:
            self.positionChanged.emit(float(data))
        elif name == "duration" and data is not None:
            self.durationChanged.emit(float(data))
        elif name == "pause":
            self.pausedChanged.emit(bool(data))

    # -- controls ------------------------------------------------------
    def load(self, url):
        self._last_error = ""
        self._send(["loadfile", url, "replace"])
        self._send(["set_property", "pause", False])

    def set_paused(self, paused):
        self._send(["set_property", "pause", bool(paused)])

    def seek(self, seconds):
        self._send(["seek", float(seconds), "absolute"])

    def set_volume(self, vol):
        self._send(["set_property", "volume", int(vol)])

    def stop(self):
        self._send(["stop"])
