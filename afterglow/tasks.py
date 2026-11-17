"""Run blocking work (network, subprocesses) off the GUI thread and hand results back."""
from concurrent.futures import ThreadPoolExecutor
import traceback

from PySide6.QtCore import QObject, Signal, Slot

_pool = ThreadPoolExecutor(max_workers=6, thread_name_prefix="afterglow")


class _Relay(QObject):
    done = Signal(object)

    def __init__(self):
        super().__init__()
        self.done.connect(self._run)

    @Slot(object)
    def _run(self, fn):
        fn()


_relay = None


def init():
    global _relay
    _relay = _Relay()


def run(fn, *args, on_done=None, on_error=None):
    """Run fn(*args) in a worker; call on_done(result) / on_error(exc) on the GUI thread."""

    def job():
        try:
            res = fn(*args)
        except Exception as exc:  # noqa: BLE001
            traceback.print_exc()
            if on_error:
                _relay.done.emit(lambda e=exc: on_error(e))
            return
        if on_done:
            _relay.done.emit(lambda r=res: on_done(r))

    return _pool.submit(job)


def shutdown():
    _pool.shutdown(wait=False, cancel_futures=True)
