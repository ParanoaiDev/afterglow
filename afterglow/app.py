"""Entry point: a full-screen QML scene living on the desktop layer (wlr-layer-shell, below windows)."""
import argparse
import os
import signal
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SOCKET_NAME = "afterglow-control"


def _parse():
    p = argparse.ArgumentParser(prog="afterglow", description="Aesthetic music desktop for Linux")
    p.add_argument("--windowed", action="store_true", help="run as a normal window (for development)")
    p.add_argument("--search", action="store_true", help="open the search box of the running instance")
    p.add_argument("--toggle", action="store_true", help="play/pause the running instance")
    p.add_argument("--next", action="store_true", help="next track in the running instance")
    p.add_argument("--prev", action="store_true", help="previous track in the running instance")
    p.add_argument("--quit", action="store_true", help="quit the running instance")
    p.add_argument("--play", metavar="QUERY", help="search and play the first result")
    p.add_argument("--shot", metavar="PNG", help=argparse.SUPPRESS)
    p.add_argument("--shot-delay", type=float, default=8, help=argparse.SUPPRESS)
    p.add_argument("--size", default="", help=argparse.SUPPRESS)
    p.add_argument("--panel", default="", help=argparse.SUPPRESS)
    p.add_argument("--query", default="", help=argparse.SUPPRESS)
    return p.parse_args()


def _command(args):
    for name in ("search", "toggle", "next", "prev", "quit"):
        if getattr(args, name):
            return name
    if args.play:
        return "play:" + args.play
    return "raise"


def main():
    args = _parse()
    if not args.windowed and os.environ.get("XDG_SESSION_TYPE") == "wayland":
        os.environ["QT_WAYLAND_SHELL_INTEGRATION"] = "layer-shell"
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

    from PySide6.QtCore import QMetaObject, QTimer, QUrl
    from PySide6.QtGui import QAction, QFont, QFontDatabase, QIcon
    from PySide6.QtNetwork import QLocalServer, QLocalSocket
    from PySide6.QtQml import QQmlApplicationEngine
    from PySide6.QtWidgets import QApplication, QMenu, QSystemTrayIcon

    from . import tasks
    from .backend import Backend
    from .config import Settings
    from .mpris import Mpris

    app = QApplication(sys.argv)
    app.setApplicationName("afterglow")
    app.setApplicationDisplayName("Afterglow")
    app.setDesktopFileName("afterglow")
    app.setQuitOnLastWindowClosed(False)
    if "Inter" in QFontDatabase.families():
        f = QFont("Inter")
        f.setPointSizeF(app.font().pointSizeF())
        app.setFont(f)
    QFontDatabase.addApplicationFont(str(HERE / "assets" / "fonts" / "Oswald.ttf"))
    icon = QIcon(str(HERE / "assets" / "afterglow.svg"))
    app.setWindowIcon(icon)

    # one instance only; later launches forward their command to it
    cmd = _command(args)
    probe = QLocalSocket()
    probe.connectToServer(SOCKET_NAME)
    if probe.waitForConnected(300):
        probe.write(cmd.encode())
        probe.flush()
        probe.waitForBytesWritten(500)
        return 0
    if cmd in ("quit", "toggle", "next", "prev"):
        return 0  # nothing running: these commands must never start Afterglow
    QLocalServer.removeServer(SOCKET_NAME)
    server = QLocalServer()
    server.listen(SOCKET_NAME)

    tasks.init()
    settings = Settings()
    backend = Backend(settings)

    engine = QQmlApplicationEngine()
    ctx = engine.rootContext()
    ctx.setContextProperty("B", backend)
    ctx.setContextProperty("S", settings)
    ctx.setContextProperty("LayerMode", not args.windowed and os.environ.get("QT_WAYLAND_SHELL_INTEGRATION") == "layer-shell")
    ctx.setContextProperty("ForcedSize", args.size)
    engine.load(QUrl.fromLocalFile(str(HERE / "qml" / ("LayerMain.qml" if not args.windowed and os.environ.get("QT_WAYLAND_SHELL_INTEGRATION") == "layer-shell" else "Main.qml"))))
    if not engine.rootObjects():
        print("QML failed to load", file=sys.stderr)
        return 1
    import shiboken6
    from PySide6.QtQuick import QQuickWindow

    window = shiboken6.wrapInstance(shiboken6.getCppPointer(engine.rootObjects()[0])[0], QQuickWindow)

    def handle(command):
        if command == "search":
            window.show()
            backend.openSearchRequested.emit()
        elif command == "toggle":
            backend.toggle()
        elif command == "next":
            backend.next()
        elif command == "prev":
            backend.prev()
        elif command == "quit":
            app.quit()
        elif command.startswith("play:"):
            q = command[5:]
            from .sources import youtube

            tasks.run(youtube.search, q, on_done=lambda r: r["tracks"] and backend.playResult(r["tracks"][0]))
        else:
            window.show()

    def on_conn():
        conn = server.nextPendingConnection()

        def read():
            handle(bytes(conn.readAll()).decode(errors="replace").strip())
            conn.disconnectFromServer()

        conn.readyRead.connect(read)

    server.newConnection.connect(on_conn)

    # MPRIS: media keys, the Plasma media widget and the lock screen
    mpris = Mpris(backend.mpris_position)
    backend.mpris = mpris

    def on_mpris(what, arg):
        if what in ("next", "prev", "toggle", "play", "pause"):
            getattr(backend, what)()
        elif what == "seek":
            backend.seek(arg)
        elif what == "volume":
            backend.setVolume(arg)
        elif what == "raise":
            window.show()
        elif what == "quit":
            app.quit()

    mpris.request.connect(on_mpris)

    # tray icon: the desktop layer has no taskbar entry, so this is how to reach settings or quit
    tray = QSystemTrayIcon(icon)
    tray.setToolTip("Afterglow")
    menu = QMenu()
    s = backend.strings
    act_show = QAction(s["showHide"], menu)
    act_show.triggered.connect(lambda: window.setVisible(not window.isVisible()))
    act_toggle = QAction(s["playPause"], menu)
    act_toggle.triggered.connect(backend.toggle)
    act_settings = QAction(s["settings"], menu)
    act_settings.triggered.connect(lambda: (window.show(), QMetaObject.invokeMethod(window, "openSettings")))
    act_quit = QAction(s["quit"], menu)
    act_quit.triggered.connect(app.quit)
    for a in (act_show, act_toggle, act_settings):
        menu.addAction(a)
    menu.addSeparator()
    menu.addAction(act_quit)
    tray.setContextMenu(menu)
    tray.activated.connect(lambda reason: reason == QSystemTrayIcon.Trigger and window.setVisible(not window.isVisible()))
    tray.show()

    backend.start()
    if cmd.startswith("play:"):
        QTimer.singleShot(800, lambda: handle(cmd))

    if args.panel == "search":
        QTimer.singleShot(1500, lambda: (backend.openSearchRequested.emit(), backend.doSearch(args.query)))
    elif args.panel == "settings":
        QTimer.singleShot(1500, lambda: QMetaObject.invokeMethod(window, "openSettings"))

    if args.shot:
        def shot():
            try:
                img = window.grabWindow()
                img.save(args.shot)
                print("saved", args.shot, img.width(), img.height())
            finally:
                app.quit()

        QTimer.singleShot(int(args.shot_delay * 1000), shot)

    signal.signal(signal.SIGINT, lambda *_: app.quit())
    signal.signal(signal.SIGTERM, lambda *_: app.quit())
    tick = QTimer()
    tick.start(500)
    tick.timeout.connect(lambda: None)  # let Python see Ctrl+C

    code = app.exec()
    backend.shutdown()
    tasks.shutdown()
    server.close()
    return code
