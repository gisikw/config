"""peck - push-to-toggle dictation for macOS.

One global hotkey toggles recording. Audio is fed to NVIDIA Parakeet
(via parakeet-mlx) in ~1s chunks while you're still talking, so the
transcript is already caught up when you toggle off; the final text is
then typed into the focused app as synthetic keystrokes. Shift+hotkey
pauses/resumes the take without ending it; Ctrl+hotkey cancels it and
discards everything.

Menu bar states:  ... loading   [mic] idle   [red] recording   [pause] paused
                  [pen] typing

The dropdown also offers a toggle that prefixes every transcription with
"[transcribed]" (persisted in ~/.local/state/peck/prefs.json) and a
"Copy last transcription" item that puts the most recent result on the
clipboard, in case it was typed into the wrong place.

Configuration comes from the environment (set by the nix module):
  PECK_KEY_CODE   virtual keycode of the toggle key (default 115, Home)
  PECK_MOD_FLAGS  required modifier bitmask (default 0, bare key)
  PECK_KEY_LABEL  human name for the key, shown in the menu
  PECK_MODEL      huggingface repo of the parakeet model
  PECK_SOUND      "0" to disable the start/stop sounds
"""

import json
import os
import queue
import threading
import time

import numpy as np
import rumps
import sounddevice as sd
import AppKit
import Foundation
import Quartz
from PyObjCTools import AppHelper

KEY_CODE = int(os.environ.get("PECK_KEY_CODE", "115"))  # kVK_Home
MOD_FLAGS = int(os.environ.get("PECK_MOD_FLAGS", "0"))
KEY_LABEL = os.environ.get("PECK_KEY_LABEL", "Home")
MODEL = os.environ.get("PECK_MODEL", "mlx-community/parakeet-tdt-0.6b-v3")
SOUND = os.environ.get("PECK_SOUND", "1") != "0"
CHUNK_SECONDS = 1.0
PREFIX = "[transcribed] "
PREFS_PATH = os.path.expanduser("~/.local/state/peck/prefs.json")

# Only these bits participate in hotkey matching; arrow/nav keys always
# carry the fn/secondary-fn flag, so it must not be part of the comparison.
MOD_MASK = (
    Quartz.kCGEventFlagMaskCommand
    | Quartz.kCGEventFlagMaskShift
    | Quartz.kCGEventFlagMaskControl
    | Quartz.kCGEventFlagMaskAlternate
)


def load_prefs():
    try:
        with open(PREFS_PATH) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def save_prefs(prefs):
    os.makedirs(os.path.dirname(PREFS_PATH), exist_ok=True)
    with open(PREFS_PATH, "w") as f:
        json.dump(prefs, f)


def copy_to_clipboard(text):
    pasteboard = AppKit.NSPasteboard.generalPasteboard()
    pasteboard.clearContents()
    pasteboard.setString_forType_(text, AppKit.NSPasteboardTypeString)


def play(name):
    if SOUND:
        sound = AppKit.NSSound.soundNamed_(name)
        if sound is not None:
            sound.play()


def type_text(text):
    """Type text into the focused app via CGEvents.

    CGEventKeyboardSetUnicodeString silently truncates past 20 UTF-16
    code units, so post in chunks, never splitting a surrogate pair.
    """
    chunk, units = [], 0
    chunks = []
    for ch in text:
        n = len(ch.encode("utf-16-le")) // 2
        if units + n > 20:
            chunks.append("".join(chunk))
            chunk, units = [], 0
        chunk.append(ch)
        units += n
    if chunk:
        chunks.append("".join(chunk))

    for piece in chunks:
        n = len(piece.encode("utf-16-le")) // 2
        for down in (True, False):
            event = Quartz.CGEventCreateKeyboardEvent(None, 0, down)
            Quartz.CGEventKeyboardSetUnicodeString(event, n, piece)
            Quartz.CGEventPost(Quartz.kCGHIDEventTap, event)
        time.sleep(0.003)


class Peck(rumps.App):
    def __init__(self):
        super().__init__("peck", title="…")
        self.status_item = rumps.MenuItem("Loading model…")
        self.prefix_enabled = bool(load_prefs().get("prefix", False))
        self.prefix_item = rumps.MenuItem(
            f"Prefix with “{PREFIX.strip()}”", callback=self.toggle_prefix
        )
        self.prefix_item.state = self.prefix_enabled
        # Disabled (no callback) until there is a transcription to copy.
        self.copy_item = rumps.MenuItem("Copy last transcription")
        self.last_text = ""
        self.menu = [self.status_item, None, self.prefix_item, self.copy_item]
        self.state = "loading"
        self.lock = threading.Lock()
        self.model = None
        self.sample_rate = None
        self.recording = False
        self.paused = False
        self.discard = False
        self.audio_q = None
        self.stream = None
        self.start_signal = threading.Event()

        # Opt out of App Nap so the hotkey stays responsive in the background.
        self.activity = Foundation.NSProcessInfo.processInfo().beginActivityWithOptions_reason_(
            Foundation.NSActivityUserInitiatedAllowingIdleSystemSleep,
            "peck listens for its dictation hotkey",
        )

        threading.Thread(target=self.engine, daemon=True).start()
        threading.Thread(target=self.run_event_tap, daemon=True).start()

    def set_state(self, state, title, note):
        self.state = state

        def apply():
            self.title = title
            self.status_item.title = note

        AppHelper.callAfter(apply)

    # -- engine --------------------------------------------------------------

    def engine(self):
        """Own ALL mlx work on one thread, for the model's whole life.

        MLX stream state is thread-local: touching the model from a
        different thread than the one that loaded it fails with
        "There is no Stream(cpu, N) in current thread".
        """
        import mlx.core as mx
        from parakeet_mlx import from_pretrained

        model = from_pretrained(MODEL)
        # Warm up: the first pass through the encoder compiles Metal kernels;
        # doing it on silence keeps the first real dictation snappy.
        with model.transcribe_stream() as transcriber:
            transcriber.add_audio(mx.zeros(model.preprocessor_config.sample_rate))
        self.sample_rate = model.preprocessor_config.sample_rate
        self.model = model
        self.set_state("idle", "🎙", f"Idle — press {KEY_LABEL} to dictate")

        while True:
            self.start_signal.wait()
            self.start_signal.clear()
            try:
                self.run_session(model, mx)
            except Exception:
                import traceback

                traceback.print_exc()
                self.set_state("idle", "🎙", "Transcription failed — see peck.log")

    def run_session(self, model, mx):
        sample_rate = self.sample_rate
        started = time.time()
        transcriber = model.transcribe_stream(context_size=(256, 256))
        transcriber.__enter__()
        try:
            pending = np.zeros(0, dtype=np.float32)
            duration = 0.0
            while True:
                try:
                    pending = np.concatenate([pending, self.audio_q.get(timeout=0.1)])
                except queue.Empty:
                    if not self.recording:
                        break
                if len(pending) >= sample_rate * CHUNK_SECONDS:
                    duration += len(pending) / sample_rate
                    transcriber.add_audio(mx.array(pending))
                    pending = np.zeros(0, dtype=np.float32)
            if self.discard:
                text = ""
            else:
                # Flush the remainder plus a little silence so trailing words
                # clear the model's right-context window.
                duration += len(pending) / sample_rate
                tail = np.concatenate(
                    [pending, np.zeros(sample_rate // 2, dtype=np.float32)]
                )
                transcriber.add_audio(mx.array(tail))
                text = transcriber.result.text.strip()
        finally:
            transcriber.__exit__(None, None, None)

        print(
            f"session: {duration:.1f}s audio, done {time.time()-started:.1f}s "
            f"after start, {len(text)} chars",
            flush=True,
        )
        if text:
            if self.prefix_enabled:
                text = PREFIX + text
            self.last_text = text
            AppHelper.callAfter(self.copy_item.set_callback, self.copy_last)
            type_text(text)
        self.set_state("idle", "🎙", f"Idle — press {KEY_LABEL} to dictate")

    # -- menu ----------------------------------------------------------------

    def toggle_prefix(self, item):
        self.prefix_enabled = not self.prefix_enabled
        item.state = self.prefix_enabled
        save_prefs({"prefix": self.prefix_enabled})

    def copy_last(self, _item):
        if self.last_text:
            copy_to_clipboard(self.last_text)

    # -- hotkey --------------------------------------------------------------

    def run_event_tap(self):
        # An *active* event tap (so the toggle key never reaches the focused
        # app) needs the Accessibility permission; posting keystrokes needs
        # it too, so ask for both up front.
        for request in ("CGRequestListenEventAccess", "CGRequestPostEventAccess"):
            fn = getattr(Quartz, request, None)
            if fn is not None:
                fn()

        def callback(_proxy, event_type, event, _refcon):
            if event_type in (
                Quartz.kCGEventTapDisabledByTimeout,
                Quartz.kCGEventTapDisabledByUserInput,
            ):
                Quartz.CGEventTapEnable(tap, True)
                return event
            keycode = Quartz.CGEventGetIntegerValueField(
                event, Quartz.kCGKeyboardEventKeycode
            )
            flags = Quartz.CGEventGetFlags(event) & MOD_MASK
            if keycode == KEY_CODE:
                if flags == MOD_FLAGS:
                    action = self.toggle
                elif flags == MOD_FLAGS | Quartz.kCGEventFlagMaskShift:
                    action = self.toggle_pause
                elif flags == MOD_FLAGS | Quartz.kCGEventFlagMaskControl:
                    action = self.cancel
                else:
                    action = None
                if action is not None:
                    if not Quartz.CGEventGetIntegerValueField(
                        event, Quartz.kCGKeyboardEventAutorepeat
                    ):
                        threading.Thread(target=action, daemon=True).start()
                    return None  # consume the keystroke
            return event

        tap = None
        while tap is None:
            tap = Quartz.CGEventTapCreate(
                Quartz.kCGSessionEventTap,
                Quartz.kCGHeadInsertEventTap,
                Quartz.kCGEventTapOptionDefault,
                Quartz.CGEventMaskBit(Quartz.kCGEventKeyDown),
                callback,
                None,
            )
            if tap is None:
                self.set_state(
                    "loading",
                    "…",
                    "Needs Accessibility permission (System Settings → Privacy)",
                )
                time.sleep(5)

        source = Quartz.CFMachPortCreateRunLoopSource(None, tap, 0)
        Quartz.CFRunLoopAddSource(
            Quartz.CFRunLoopGetCurrent(), source, Quartz.kCFRunLoopCommonModes
        )
        Quartz.CGEventTapEnable(tap, True)
        Quartz.CFRunLoopRun()

    # -- recording -----------------------------------------------------------

    def toggle(self):
        with self.lock:
            if self.state == "idle":
                self.start_recording()
            elif self.state in ("recording", "paused"):
                self.stop_recording()
            # loading/transcribing: ignore the press

    def toggle_pause(self):
        with self.lock:
            if self.state == "recording":
                self.paused = True
                play("Bottle")
                self.set_state(
                    "paused", "⏸", f"Paused — ⇧{KEY_LABEL} resumes, {KEY_LABEL} finishes"
                )
            elif self.state == "paused":
                self.paused = False
                play("Pop")
                self.set_state(
                    "recording", "🔴", f"Recording — press {KEY_LABEL} to finish"
                )

    def cancel(self):
        with self.lock:
            if self.state not in ("recording", "paused"):
                return
            self.discard = True
            self.stream.stop()
            self.stream.close()
            self.recording = False
            play("Basso")
            # Blocks further presses until the engine winds down and goes idle.
            self.set_state("transcribing", "🎙", "Discarding…")

    def start_recording(self):
        self.audio_q = queue.Queue()
        self.paused = False
        self.discard = False

        def on_audio(indata, _frames, _time, _status):
            if not self.paused:
                self.audio_q.put(indata[:, 0].copy())

        try:
            self.stream = sd.InputStream(
                samplerate=self.sample_rate,
                channels=1,
                dtype="float32",
                callback=on_audio,
            )
            self.stream.start()
        except Exception:
            import traceback

            traceback.print_exc()
            self.set_state("idle", "🎙", "Microphone unavailable — see peck.log")
            return
        self.recording = True
        play("Pop")
        self.set_state("recording", "🔴", f"Recording — press {KEY_LABEL} to finish")
        self.start_signal.set()

    def stop_recording(self):
        self.stream.stop()
        self.stream.close()
        self.recording = False
        play("Tink")
        self.set_state("transcribing", "✏️", "Transcribing…")


if __name__ == "__main__":
    Peck().run()
