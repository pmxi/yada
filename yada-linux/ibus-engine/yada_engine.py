#!/usr/bin/env python3

import signal
import subprocess
import sys
import threading
import time

import gi  # type: ignore

gi.require_version("IBus", "1.0")
from gi.repository import GLib, IBus  # type: ignore


ENGINE_NAME = "yada"
DBUS_NAME = "dev.yada.Linux"
DBUS_PATH = "/dev/yada/Linux"
DBUS_IFACE = "dev.yada.Linux"


def _is_trigger(keyval, state):
    # Default trigger: Ctrl+Alt+Space
    # IBus modifier state uses Gdk-like masks.
    # Important: ignore key release events; otherwise one physical keystroke
    # can trigger twice (press + release) and immediately Start then Stop.
    if state & IBus.ModifierType.RELEASE_MASK:
        return False

    ctrl = bool(state & IBus.ModifierType.CONTROL_MASK)
    alt = bool(state & IBus.ModifierType.MOD1_MASK)
    return keyval == IBus.space and ctrl and alt


class YadaEngine(IBus.Engine):
    def __init__(self):
        super().__init__()
        # States: idle -> recording -> processing -> idle
        # We keep D-Bus calls off the key event path so the engine UI
        # stays responsive while the daemon does network work.
        self._state = "idle"
        self._lock = threading.Lock()
        self._last_trigger_ts = 0.0

    def do_process_key_event(self, keyval, keycode, state):
        # Debug: log trigger key info.
        if keyval == IBus.space:
            _debug("space key: keycode=%s state=0x%08x" % (str(keycode), int(state)))

        # Debounce: some setups can deliver repeated events for a single
        # chord press. Prevent immediate double-toggle.
        now = time.monotonic()
        if (
            keyval == IBus.space
            and (state & IBus.ModifierType.CONTROL_MASK)
            and (state & IBus.ModifierType.MOD1_MASK)
        ):
            if (now - self._last_trigger_ts) < 0.20:
                return True
            self._last_trigger_ts = now

        # Pass through everything unless it's our trigger.
        if not _is_trigger(keyval, state):
            return False

        # Consume trigger and toggle state.
        with self._lock:
            if self._state == "idle":
                self._state = "recording"
                self.update_auxiliary_text(
                    IBus.Text.new_from_string("Yada: Listening..."), True
                )
                threading.Thread(target=self._start_async, daemon=True).start()
                return True

            if self._state == "recording":
                self._state = "processing"
                self.update_auxiliary_text(
                    IBus.Text.new_from_string("Yada: Processing..."), True
                )
                threading.Thread(target=self._stop_async, daemon=True).start()
                return True

            # processing: swallow triggers so we don't stack requests.
            return True

    def _start_async(self):
        ok, err_or_text = _dbus_call("Start")
        if ok:
            return

        def _fail():
            with self._lock:
                self._state = "idle"
            self.update_auxiliary_text(
                IBus.Text.new_from_string("Yada: Start failed"), True
            )
            return False

        _schedule(_fail)

    def _stop_async(self):
        ok, text_or_err = _dbus_call("Stop")

        def _finish():
            with self._lock:
                self._state = "idle"

            self.update_auxiliary_text(IBus.Text.new_from_string(""), False)
            if ok and text_or_err:
                self.commit_text(IBus.Text.new_from_string(text_or_err))
            return False

        _schedule(_finish)


def _dbus_call(method):
    # Minimal dependency approach: use gdbus CLI.
    # This keeps the engine tiny; Rust daemon owns the API.
    cmd = [
        "gdbus",
        "call",
        "--session",
        "--dest",
        DBUS_NAME,
        "--object-path",
        DBUS_PATH,
        "--method",
        f"{DBUS_IFACE}.{method}",
    ]
    try:
        out = subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True).strip()
    except subprocess.CalledProcessError as e:
        sys.stderr.write(e.output)
        return (False, e.output.strip())

    # Methods that return no value.
    if out == "()":
        return (True, "")

    # gdbus prints something like: "('text',)"
    if out.startswith("(") and out.endswith(")"):
        inner = out[1:-1].strip()
        if inner.startswith("'") and inner.endswith("',"):
            return (True, inner[1:-2])
        if inner.startswith("'") and inner.endswith("'"):
            return (True, inner[1:-1])
    return (True, "")


def _schedule(fn):
    # Run on the GLib main loop.
    GLib.idle_add(fn)


def _debug(msg):
    # Write to a stable per-user log file so we can see what keys are arriving.
    try:
        p = "%s/.cache/yada-linux" % (GLib.get_home_dir(),)
        subprocess.call(["/usr/bin/env", "mkdir", "-p", p])
        with open(p + "/ibus-engine.log", "a", encoding="utf-8") as f:
            f.write("%s %s\n" % (time.strftime("%Y-%m-%d %H:%M:%S"), msg))
    except Exception:
        pass


def main():
    IBus.init()

    bus = IBus.Bus()
    factory = IBus.Factory.new(bus.get_connection())
    factory.add_engine(ENGINE_NAME, YadaEngine)

    bus.request_name("org.freedesktop.IBus.YadaLinux", 0)
    loop = GLib.MainLoop()

    def _sigterm(_sig, _frame):
        loop.quit()

    signal.signal(signal.SIGINT, _sigterm)
    signal.signal(signal.SIGTERM, _sigterm)

    loop.run()


if __name__ == "__main__":
    main()
