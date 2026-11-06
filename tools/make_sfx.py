"""Synthesises Chaos Car's sound effects (no recordings needed). Run from the project root:
    python3 tools/make_sfx.py
Writes 22 kHz mono WAVs into assets/sfx/. Loops are built from whole periods (and periodic noise made
by inverse FFT), so they repeat with no click."""
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfiltfilt

SR = 22050
rng = np.random.default_rng(7)
OUT = "assets/sfx/"


def periodic_noise(seconds, lo, hi):
    """Noise that loops seamlessly: random phases on a band of whole-period frequencies."""
    n = int(SR * seconds)
    spec = np.zeros(n // 2 + 1, complex)
    f = np.fft.rfftfreq(n, 1 / SR)
    band = (f >= lo) & (f <= hi)
    spec[band] = np.exp(2j * np.pi * rng.random(band.sum())) / np.sqrt(np.maximum(f[band], 1.0) / lo)
    x = np.fft.irfft(spec, n)
    return x / np.max(np.abs(x))


def save(name, x, peak=0.8):
    x = x / np.max(np.abs(x)) * peak
    wavfile.write(OUT + name, SR, (x * 32767).astype(np.int16))


def engine(f0, seconds, rough=0.35, noise=0.12):
    t = np.arange(int(SR * seconds)) / SR
    x = np.zeros_like(t)
    for k, a in enumerate([1.0, 0.75, 0.55, 0.42, 0.3, 0.22, 0.15, 0.1, 0.07], start=1):
        x += a * np.sin(2 * np.pi * k * f0 * t + rng.random() * 6.28)
    x *= 1.0 + rough * np.sin(2 * np.pi * f0 / 2 * t)        # lumpy V8 firing
    x = np.tanh(1.6 * x)                                    # a little grit
    return x + noise * periodic_noise(seconds, 200, 4000)


# your engine: 1 s loop, 110 Hz (pitched up and down in game with speed)
save("engine.wav", engine(110.0, 1.0))
# the pack around you: a chorus of slightly different engines, 2 s loop (all whole periods in 2 s)
pack = sum(engine(f, 2.0, rough=0.25, noise=0.0) for f in [101.5, 106.0, 112.5, 117.0, 123.5])
save("pack.wav", pack + 0.8 * periodic_noise(2.0, 150, 3000), 0.7)
# wind/air rush: 2 s loop
save("wind.wav", periodic_noise(2.0, 250, 5000), 0.6)
# crowd: 4 s loop of murmur that swells (whole-period swells)
t = np.arange(SR * 4) / SR
crowd = periodic_noise(4.0, 300, 3500) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.5 * t) + 0.15 * np.sin(2 * np.pi * 1.25 * t))
save("crowd.wav", crowd, 0.5)
# whoosh: a car going past, 0.6 s
n = int(SR * 0.6)
t = np.arange(n) / SR
x = rng.standard_normal(n)
lo = butter(2, 2500, "lowpass", fs=SR, output="sos")
hi = butter(2, 500, "highpass", fs=SR, output="sos")
whoosh = sosfiltfilt(hi, sosfiltfilt(lo, x)) * np.sin(np.pi * t / t[-1]) ** 2
save("whoosh.wav", whoosh, 0.7)
# radio click: squelch burst + short beep, 0.16 s
n = int(SR * 0.16)
t = np.arange(n) / SR
click = rng.standard_normal(n) * np.exp(-t * 60) * 0.6
click[int(SR * 0.03):int(SR * 0.09)] += 0.5 * np.sin(2 * np.pi * 1250 * t[:int(SR * 0.06)])
save("radio.wav", click, 0.6)
print("wrote", OUT)
