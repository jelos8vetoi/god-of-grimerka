"""Петли музыки DOG CASINO 67 из референса + синтезированные слои.
python tools/g67_casino_loops.py <папка_с_ref.wav и ffmpeg> — ref.wav: 44,1 кГц стерео из dog_casino_67_reference.mp3.
Границы петель — КОНСТАНТЫ НИЖЕ, «на утверждение владельцу». Шов — настоящий кроссфейд хвоста в начало (XFADE_MS).
Выход: ev_g67_casino_a/b.ogg (петли), ev_g67_casino_perc.ogg (перкуссия, синтез), ev_g67_casino_accent.ogg (акцент 66-го спина).
Печатает метрики шва до/после: скачок на стыке относительно обычного шага сигнала и отношение RMS 5 мс до/после стыка."""
import sys, os, wave, subprocess
import numpy as np

SR = 44100
LOOP_A = (125.98, 13.61)     # на утверждение владельцу
LOOP_B = (180.45, 13.61)     # на утверждение владельцу
XFADE_MS = 30.0
BAR = 3.404                  # такт референса, с
FF = os.environ.get("FFMPEG", "ffmpeg")


def read(path):
    with wave.open(path, "rb") as w:
        n = w.getnframes()
        d = np.frombuffer(w.readframes(n), dtype=np.int16).reshape(-1, w.getnchannels()).astype(np.float64) / 32768.0
    return d


def write(path, x):
    x = np.clip(x, -1.0, 1.0)
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767.0).astype(np.int16).tobytes())


def seam_metrics(x):
    jump = np.abs(x[0] - x[-1]).mean()
    step = np.abs(np.diff(x[:2000], axis=0)).mean()
    win = int(0.005 * SR)
    r_end = np.sqrt((x[-win:] ** 2).mean())
    r_start = np.sqrt((x[:win] ** 2).mean())
    n = int(0.01 * SR)
    a = np.abs(np.fft.rfft(x[-n:, 0] * np.hanning(n)))
    b = np.abs(np.fft.rfft(x[:n, 0] * np.hanning(n)))
    cos = float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-12))
    return {"скачок/шаг": round(float(jump / (step + 1e-12)), 2), "RMS 5мс до/после": round(float(r_end / (r_start + 1e-12)), 2), "косинус спектров 10мс": round(cos, 3)}


def make_loop(ref, start, length):
    d = int(XFADE_MS / 1000.0 * SR)
    i0 = int(start * SR)
    n = int(length * SR)
    seg = ref[i0:i0 + n + d].copy()
    loop = seg[:n].copy()
    fi = np.linspace(0.0, 1.0, d)[:, None]
    loop[:d] = seg[:d] * np.sqrt(fi) + seg[n:n + d] * np.sqrt(1.0 - fi)
    return loop


def kick(t):
    f = 45.0 + 90.0 * np.exp(-t * 28.0)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 11.0)


def make_perc(n):
    rng = np.random.default_rng(67)
    out = np.zeros((n, 2))
    beat = BAR / 4.0
    t_hit = np.arange(0, n / SR, beat / 2.0)
    for k, th in enumerate(t_hit):
        i = int(th * SR)
        if k % 4 in (0, 3) or k % 8 == 5:
            m = min(int(0.3 * SR), n - i)
            t = np.arange(m) / SR
            out[i:i + m, :] += (kick(t) * 0.9)[:, None]
        if k % 4 == 2:
            m = min(int(0.18 * SR), n - i)
            t = np.arange(m) / SR
            nz = rng.standard_normal(m) * np.exp(-t * 22.0) * 0.5 + np.sin(2 * np.pi * 190.0 * t) * np.exp(-t * 18.0) * 0.4
            out[i:i + m, :] += nz[:, None]
        m = min(int(0.05 * SR), n - i)
        t = np.arange(m) / SR
        hat = np.diff(rng.standard_normal(m + 1)) * np.exp(-t * 70.0) * (0.22 if k % 2 == 0 else 0.14)
        out[i:i + m, :] += hat[:, None]
    fade = int(0.004 * SR)
    out[:fade] *= np.linspace(0, 1, fade)[:, None]
    out[-fade:] *= np.linspace(1, 0, fade)[:, None]
    return out * 0.8


def make_accent():
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(66)
    x = kick(t) * 1.2 + np.sin(2 * np.pi * 55.0 * t) * np.exp(-t * 5.0) * 0.6 + rng.standard_normal(n) * np.exp(-t * 30.0) * 0.35
    x[-int(0.02 * SR):] *= np.linspace(1, 0, int(0.02 * SR))
    return np.stack([x, x], axis=1) * 0.8


def enc(wav, ogg):
    subprocess.run([FF, "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", ogg], check=True)


if __name__ == "__main__":
    work = sys.argv[1]
    out_dir = sys.argv[2]
    ref = read(os.path.join(work, "ref.wav"))
    for name, (st, ln) in (("a", LOOP_A), ("b", LOOP_B)):
        old = read(os.path.join(work, "old_%s.wav" % name))[:int(ln * SR)]
        new = make_loop(ref, st, ln)
        print("петля", name, "ДО (fade в тишину):", seam_metrics(old))
        print("петля", name, "ПОСЛЕ (кроссфейд %.0f мс):" % XFADE_MS, seam_metrics(new))
        write(os.path.join(work, "new_%s.wav" % name), new)
        enc(os.path.join(work, "new_%s.wav" % name), os.path.join(out_dir, "ev_g67_casino_%s.ogg" % name))
    perc = make_perc(int(LOOP_A[1] * SR))
    write(os.path.join(work, "perc.wav"), perc)
    enc(os.path.join(work, "perc.wav"), os.path.join(out_dir, "ev_g67_casino_perc.ogg"))
    write(os.path.join(work, "accent.wav"), make_accent())
    enc(os.path.join(work, "accent.wav"), os.path.join(out_dir, "ev_g67_casino_accent.ogg"))
    print("готово")
