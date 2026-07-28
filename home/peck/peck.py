"""peck - push-to-toggle dictation for macOS.

One global hotkey toggles recording. Audio is fed to NVIDIA Parakeet
(via parakeet-mlx) in ~1s chunks while you're still talking, so the
transcript is already caught up when you toggle off; the final text is
then typed into the focused app as synthetic keystrokes.

Menu bar states:  ... loading   [mic] idle   [red] recording   [pen] typing

Configuration comes from the environment (set by the nix module):
  PECK_KEY_CODE   virtual keycode of the toggle key (default 115, Home)
  PECK_MOD_FLAGS  required modifier bitmask (default 0, bare key)
  PECK_KEY_LABEL  human name for the key, shown in the menu
  PECK_MODEL      huggingface repo of the parakeet model
  PECK_SOUND      "0" to disable the start/stop sounds
"""

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

# Only these bits participate in hotkey matching; arrow/nav keys always
# carry the fn/secondary-fn flag, so it must not be part of the comparison.
MOD_MASK = (
    Quartz.kCGEventFlagMaskCommand
    | Quartz.kCGEventFlagMaskShift
    | Quartz.kCGEventFlagMaskControl
    | Quartz.kCGEventFlagMaskAlternate
)


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
        self.menu = [self.status_item]
        self.state = "loading"
        self.lock = threading.Lock()
        self.model = None
        self.sample_rate = None
        self.recording = False
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
            type_text(text)
        self.set_state("idle", "🎙", f"Idle — press {KEY_LABEL} to dictate")

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
            if keycode == KEY_CODE and flags == MOD_FLAGS:
                if not Quartz.CGEventGetIntegerValueField(
                    event, Quartz.kCGKeyboardEventAutorepeat
                ):
                    threading.Thread(target=self.toggle, daemon=True).start()
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
            elif self.state == "recording":
                self.stop_recording()
            # loading/transcribing: ignore the press

    def start_recording(self):
        self.audio_q = queue.Queue()

        def on_audio(indata, _frames, _time, _status):
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
