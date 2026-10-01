"""Generate the WAV probes and shazamio-core signatures the Dart port is checked against.

Run from the repository root with the project's virtualenv:
    .venv/Scripts/python tool/gen_signature_fixtures.py
Requires numpy and shazamio-core (see legacy/README.md).
"""

import asyncio
import pathlib
import wave

import numpy as np
import shazamio_core

OUT = pathlib.Path(__file__).resolve().parent.parent / "test" / "fixtures" / "shazam"
RATE = 16000
SECONDS = 8


def chord(t):
    return (
        0.25 * np.sin(2 * np.pi * 440 * t)
        + 0.2 * np.sin(2 * np.pi * 1320 * t)
        + 0.15 * np.sin(2 * np.pi * 2750 * t)
        + 0.1 * np.sin(2 * np.pi * 4400 * t)
    ) * (0.6 + 0.4 * np.sin(2 * np.pi * 1.5 * t))


def noisy(t):
    rng = np.random.default_rng(7)
    tone = 0.3 * np.sin(2 * np.pi * 660 * t) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.5 * t))
    return tone + 0.15 * rng.standard_normal(len(t))


def sweep(t):
    freq = 300 + (5000 - 300) * t / SECONDS
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    return 0.4 * np.sin(phase)


PROBES = {"chord": chord, "noisy": noisy, "sweep": sweep}


async def main():
    OUT.mkdir(parents=True, exist_ok=True)
    recognizer = shazamio_core.Recognizer(segment_duration_seconds=10)
    t = np.arange(RATE * SECONDS) / RATE
    for name, fn in PROBES.items():
        pcm = (np.clip(fn(t), -1, 1) * 32767).astype("<i2")
        wav_path = OUT / f"{name}.wav"
        with wave.open(str(wav_path), "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(RATE)
            wf.writeframes(pcm.tobytes())
        signature = await recognizer.recognize_path(str(wav_path))
        (OUT / f"{name}.uri").write_text(signature.signature.uri + "\n", encoding="ascii")
        print(name, signature.signature.samples, "ms")


asyncio.run(main())
