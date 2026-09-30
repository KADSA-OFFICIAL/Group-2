#!/usr/bin/env python3
"""배경음악 10곡을 합성해 OGG Vorbis 로 만든다 (#539).

외부 샘플·음원을 쓰지 않는다 — 모든 소리는 이 파일의 가산·FM·카플러스-스트롱 합성으로 만든다.
멜로디·코드 진행·곡 구조는 이 파일에 직접 적은 **자작곡**이다. 분위기만 참고했다:
  블루 아카이브 사운드트랙 풍 — 로즈 피아노와 7·9화음, 핑거 베이스, 클린 기타 커팅,
  사이드체인으로 숨 쉬는 패드, 청량한 시티팝·퓨처 펑크 그루브.

**배경음이 목표다.** 그래서
  - 칩튠 사각파·FM 브라스 같은 "옛날 게임" 소리를 쓰지 않는다.
  - 멜로디는 여백을 두고, 한 구간(8마디)은 반주·그루브만으로 흐른다.
  - 목표 음량을 일상 −23, 전투 −21, 보스 −20.5 LUFS 부근으로 낮게 잡는다.
  - 마스터에 고역을 살짝 깎아(테이프처럼) 귀를 찌르지 않게 한다.

같은 시드면 같은 파일이 나온다. 반복 이음새는 곡 끝에서 넘친 잔향을 곡 처음에 더해 없앤다.

악보 표기:
  seq("F#5:.75 D5:.5 r:1 | ...")  — 음이름+옥타브(C4=60):박 수, r 은 쉼표. "|" 는 마디줄이며
  위치가 4박의 배수가 아니면 에러를 낸다(박 계산 실수를 잡는다).
  prog("Gmaj9:4 | A7sus4:2 A7:2 | ...") — 코드 진행. 같은 마디줄 검사를 한다.

사용:
  python tools/gen_bgm.py                 # 모든 곡
  python tools/gen_bgm.py lobby story     # 몇 곡만
필요: numpy, imageio-ffmpeg(ffmpeg + libvorbis)
"""

import json
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "audio", "bgm")


def ffmpeg_exe():
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        return "ffmpeg"


def mtof(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


# ------------------------------------------------------------------ notation

NOTE_PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def _pc_len(s):
    """음이름 앞부분(예: "F#", "Bb")의 음 번호와 글자 수."""
    pc, i = NOTE_PC[s[0]], 1
    while i < len(s) and s[i] in "#b":
        pc += 1 if s[i] == "#" else -1
        i += 1
    return pc % 12, i


def nn(s):
    _, i = _pc_len(s)
    raw = NOTE_PC[s[0]] + sum(1 if c == "#" else -1 for c in s[1:i])   # B#/Cb 도 옥타브가 맞게
    return 12 * (int(s[i:]) + 1) + raw


def seq(text):
    """[(bar, beat, beats, midi)] — 선율 한 줄."""
    out, pos = [], 0.0
    for tok in text.split():
        if tok == "|":
            if abs(pos / 4 - round(pos / 4)) > 1e-6:
                raise ValueError(f"마디줄 위치가 어긋났다: {pos}박 ({text[:40]}...)")
            continue
        name, dur = tok.split(":")
        dur = float(dur)
        if name != "r":
            out.append((int(pos // 4), pos % 4, dur, nn(name)))
        pos += dur
    return out


QUAL = {
    "": (0, 4, 7), "m": (0, 3, 7), "maj7": (0, 4, 7, 11), "maj9": (0, 4, 7, 11, 14), "6": (0, 4, 7, 9),
    "69": (0, 4, 7, 9, 14), "m7": (0, 3, 7, 10), "m9": (0, 3, 7, 10, 14), "m11": (0, 3, 7, 10, 14, 17),
    "7": (0, 4, 7, 10), "9": (0, 4, 7, 10, 14), "13": (0, 4, 10, 14, 21), "7sus4": (0, 5, 7, 10),
    "9sus4": (0, 5, 7, 10, 14), "m7b5": (0, 3, 6, 10), "7b9": (0, 4, 7, 10, 13), "add9": (0, 4, 7, 14),
    "7b13": (0, 4, 10, 20), "sus4": (0, 5, 7), "madd9": (0, 3, 7, 14),
}


class Chord:
    def __init__(self, bar, beat, beats, name):
        self.bar, self.beat, self.beats, self.name = bar, beat, beats, name
        self.root, i = _pc_len(name)
        self.q = name[i:]
        self.ints = QUAL[self.q]

    def pcs(self, rootless=True):
        ints = list(self.ints)
        if rootless and len(ints) >= 4:
            ints.remove(0)
            if len(ints) >= 4 and 7 in ints:
                ints.remove(7)   # 5음 이상이면 5도를 뺀다 — 색을 내는 음(3·7·9·13)만 남긴다
        return sorted({(self.root + k) % 12 for k in ints})

    def bass(self):
        """베이스 근음 (C#2..C3). 너무 낮으면 작은 스피커에서 웅웅거리기만 한다."""
        r = self.root + 36
        return r + 12 if r < 37 else r

    def tone(self, k):
        """화음의 k 번째 구성음(근음 기준 반음 수)."""
        return self.ints[k % len(self.ints)]


def prog(text):
    out, pos = [], 0.0
    for tok in text.split():
        if tok == "|":
            if abs(pos / 4 - round(pos / 4)) > 1e-6:
                raise ValueError(f"코드 마디줄 위치가 어긋났다: {pos}박")
            continue
        name, dur = tok.split(":")
        out.append(Chord(int(pos // 4), pos % 4, float(dur), name))
        pos += float(dur)
    return out


def shift(chords, bars):
    return [Chord(c.bar + bars, c.beat, c.beats, c.name) for c in chords]


def voice(chord, prev, center=63, lo_range=range(52, 62), rootless=True, count=None):
    """가까운 자리바꿈을 고른다: 앞 화음과의 거리 + 중심 음역에서 벗어난 정도가 가장 작은 것."""
    pcs = chord.pcs(rootless)
    best, cost = None, 1e9
    for lo in lo_range:
        v = sorted(lo + (p - lo) % 12 for p in pcs)
        if count and len(v) > count:
            v = v[-count:]
        c = abs(np.mean(v) - center)
        if prev:
            c += sum(min(abs(a - b) for b in prev) for a in v) * 0.6
        if c < cost:
            best, cost = v, c
    return best


# ------------------------------------------------------------------ dsp basics

def fft_band(x, lo, hi):
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / SR)
    mask = 1.0 / (1 + (lo / np.maximum(freqs, 1)) ** 4) / (1 + (freqs / hi) ** 4)
    return np.fft.irfft(spec * mask, len(x))


def additive(freq, n, wave="saw", cutoff=4000.0, detune_cents=0.0, vib=None, max_h=40):
    """대역 제한 파형. cutoff(Hz, 상수 또는 길이 n 배열)가 배음을 부드럽게 깎는다."""
    t = np.arange(n) / SR
    f = freq * 2.0 ** (detune_cents / 1200.0)
    inst = np.full(n, f)
    if vib is not None:
        rate, depth, delay = vib
        onset = np.clip((t - delay) / 0.3, 0.0, 1.0)
        inst = f * (1.0 + depth * onset * np.sin(2 * np.pi * rate * t))
    phase = 2 * np.pi * np.cumsum(inst) / SR
    cut = np.asarray(cutoff, dtype=np.float64)
    top = float(np.max(cut)) * 3.0
    out = np.zeros(n)
    for k in range(1, max_h + 1):
        if k * f > min(top, SR * 0.45):
            break
        if wave == "tri":
            if k % 2 == 0:
                continue
            base = (1.0 / k ** 2) * (1 if (k // 2) % 2 == 0 else -1)
        else:
            base = 1.0 / k
        out += base * np.exp(-(k * f) / cut) * np.sin(k * phase)
    return out


def adsr(n, a, d, s, r, note_len=None):
    note_len = n if note_len is None else note_len
    t = np.arange(n) / SR
    env = np.where(t < a, t / max(a, 1e-4), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-4)))
    rel = np.clip(1.0 - (np.arange(n) - note_len) / (r * SR + 1), 0.0, 1.0)
    return env * np.where(np.arange(n) < note_len, 1.0, rel)


def karplus(f, n, damp=0.996, bright=5000.0, seed=0):
    """카플러스-스트롱 현. 정수 지연으로 만든 뒤 보간해 정확한 음높이로 늘인다."""
    period = SR / f
    N = max(2, int(period))
    m = int(n * N / period) + N + 2
    rng = np.random.default_rng(seed)
    exc = fft_band(rng.standard_normal(N * 8), 80, bright)[:N]
    y = np.zeros(m)
    y[:N] = exc / (np.max(np.abs(exc)) + 1e-9)
    prev = np.concatenate([[0.0], y[:N - 1]])
    for i in range(N, m, N):
        j = min(i + N, m)
        cur = y[i - N:j - N]
        lag = y[i - N - 1:j - N - 1] if i - N - 1 >= 0 else prev[: j - i]
        y[i:j] = damp * 0.5 * (cur + lag)
    pos = np.arange(n) * N / period
    return np.interp(pos, np.arange(m), y)


# ------------------------------------------------------------------ instruments
# 모두 (freq, dur_seconds) -> mono 배열(세기 1). 꼬리를 포함한다. 세기는 Song.note 가 곱한다.

def inst_rhodes(f, dur):
    """로즈: 1:1 FM 몸통(변조가 빨리 줄어 둥글어진다) + 짧은 "팅" 소리. 낮은 음일수록 오래 울린다."""
    n = int((dur + 0.45) * SR)
    t = np.arange(n) / SR
    idx = 1.3 * np.exp(-t / 0.22) + 0.35
    body = np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * t))
    tine = 0.22 * np.sin(2 * np.pi * f * t + 2.2 * np.exp(-t / 0.03) * np.sin(2 * np.pi * 14.0 * f * t)) * np.exp(-t / 0.35)
    decay = np.exp(-t / (1.8 * (262.0 / max(f, 80.0)) ** 0.5))
    damp = np.where(t < dur, 1.0, np.exp(-(t - dur) / 0.08))
    return (body * decay + tine) * damp * np.clip(t / 0.002, 0, 1) * 0.8


def inst_piano(f, dur):
    """피아노: 약간 어긋난 배음, 배음마다 다른 감쇠, 두 줄의 맥놀이, 부드러운 해머."""
    n = int((dur + 0.5) * SR)
    t = np.arange(n) / SR
    base = 2.6 * (261.6 / max(f, 60.0)) ** 0.4
    x = np.zeros(n)
    for k in range(1, 11):
        fk = k * f * np.sqrt(1 + 0.0003 * k * k)
        if fk > 9000:
            break
        amp = (1.0 / k ** 1.3) * np.exp(-t / (base / k ** 0.7))
        x += amp * (np.sin(2 * np.pi * fk * t) + 0.5 * np.sin(2 * np.pi * fk * 1.0009 * t))
    hammer = fft_band(np.random.default_rng(int(f * 10)).standard_normal(n), 200, 2500) * np.exp(-t / 0.005) * 0.25
    damp = np.where(t < dur, 1.0, np.exp(-(t - dur) / 0.12))
    return (x / 1.5 + hammer) * damp * np.clip(t / 0.002, 0, 1)


def inst_bass(f, dur):
    """핑거 베이스: 사인 몸통 + 금방 사라지는 2·3배음 + 손끝 소리, 살짝 포화."""
    n = int((dur + 0.08) * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * f * t) + 0.45 * np.sin(4 * np.pi * f * t) * np.exp(-t / 0.18) + \
        0.22 * np.sin(6 * np.pi * f * t) * np.exp(-t / 0.08) + 0.1 * np.sin(8 * np.pi * f * t) * np.exp(-t / 0.04)
    pluck = fft_band(np.random.default_rng(int(f * 3)).standard_normal(n), 400, 2500) * np.exp(-t / 0.006) * 0.25
    env = adsr(n, 0.004, 0.35, 0.65, 0.05, note_len=int(dur * SR))
    return np.tanh(1.3 * (x + pluck) * env) / np.tanh(1.3)


def inst_synth_bass(f, dur):
    """전투용 신스 베이스: 톱니 + 서브 사인, 필터가 짧게 열린다."""
    n = int((dur + 0.06) * SR)
    t = np.arange(n) / SR
    x = 0.55 * additive(f, n, "saw", 260 + 1100 * np.exp(-t / 0.06)) + 0.8 * np.sin(2 * np.pi * f * t)
    return np.tanh(1.4 * x * adsr(n, 0.003, 0.2, 0.7, 0.04, note_len=int(dur * SR))) / np.tanh(1.4)


def inst_guitar(f, dur):
    """클린 일렉 기타(카플러스-스트롱). 짧은 음은 손바닥으로 뮤트한 커팅이 된다."""
    n = int((dur + 0.12) * SR)
    muted = dur < 0.2
    x = karplus(f, n, 0.985 if muted else 0.997, 3200 if muted else 4500, seed=int(f))
    t = np.arange(n) / SR
    damp = np.where(t < dur, 1.0, np.exp(-(t - dur) / 0.03))
    return x * damp * 0.8


def inst_pad(f, dur):
    """따뜻한 패드: 톱니 네 겹, 낮은 밝기, 천천히 부풀고 천천히 사라진다."""
    n = int((dur + 1.0) * SR)
    x = sum(additive(f, n, "saw", 1200.0, dc, max_h=24) for dc in (-11.0, -4.0, 4.0, 11.0)) / 4.0
    x += 0.35 * np.sin(2 * np.pi * f * np.arange(n) / SR)
    return x * adsr(n, 0.4, 1.2, 0.85, 0.8, note_len=int(dur * SR))


def inst_strings(f, dur):
    """현악 합주: 연주자마다 음정·떨림이 조금씩 어긋난다."""
    n = int((dur + 0.6) * SR)
    x = np.zeros(n)
    for i in range(3):
        x += additive(f, n, "saw", 2200.0, (i - 1) * 7.0, vib=(5.0 + 0.3 * i, 0.004, 0.2 + 0.05 * i), max_h=24)
    return x / 3 * adsr(n, 0.3, 1.0, 0.9, 0.5, note_len=int(dur * SR))


def inst_lead(f, dur):
    """부드러운 신스 리드: 톱니와 사인을 섞고 밝기를 낮춘다. 늦게 들어오는 비브라토."""
    n = int((dur + 0.3) * SR)
    t = np.arange(n) / SR
    cut = 1500 + 900 * np.exp(-t / 0.25)
    x = 0.45 * (additive(f, n, "saw", cut, -6, vib=(5.3, 0.0045, 0.25)) + additive(f, n, "saw", cut, 6, vib=(5.3, 0.0045, 0.25))) + \
        0.6 * np.sin(2 * np.pi * f * t)
    return x * adsr(n, 0.018, 0.5, 0.75, 0.16, note_len=int(dur * SR))


def inst_bell(f, dur):
    """첼레스타 같은 종: 비정수 배음이 금방 사라진다."""
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * f * t + 0.8 * np.exp(-t / 0.15) * np.sin(2 * np.pi * 3.5 * f * t)) * np.exp(-t / 0.7) + \
        0.18 * np.sin(2 * np.pi * f * 4.0 * t) * np.exp(-t / 0.12)
    return x * np.clip(t / 0.0015, 0, 1)


def inst_pluck(f, dur):
    """16분 분산화음용 플럭: 톱니 두 겹, 필터가 빨리 닫힌다."""
    n = int(0.4 * SR)
    t = np.arange(n) / SR
    cut = 500 + 2200 * np.exp(-t / 0.045)
    x = 0.5 * (additive(f, n, "saw", cut, -5) + additive(f, n, "saw", cut, 5))
    return x * np.exp(-t / 0.13) * np.clip(t / 0.002, 0, 1)


def inst_mallet(f, dur):
    """칼림바·마림바 사이의 나무 건반."""
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.35) + 0.3 * np.sin(2 * np.pi * f * 4.0 * t) * np.exp(-t / 0.05) + \
        0.06 * np.sin(2 * np.pi * f * 9.2 * t) * np.exp(-t / 0.015)
    return x * np.clip(t / 0.0015, 0, 1)


def inst_choir(f, dur):
    """"아" 합창 패드: 떨리는 톱니를 모음 대역(700·1200Hz 부근)으로 거른다."""
    n = int((dur + 1.0) * SR)
    x = sum(additive(f, n, "saw", 1500.0, dc, vib=(4.6 + 0.3 * i, 0.005, 0.2), max_h=24)
            for i, dc in enumerate((-9.0, -2.0, 5.0))) / 3.0
    x = 0.6 * fft_band(x, 450, 1100) + 0.4 * fft_band(x, 1000, 1500)
    return x * adsr(n, 0.5, 1.0, 0.9, 0.8, note_len=int(dur * SR)) * 1.6


def inst_sub_hit(f, dur):
    """보스곡 구간 머리의 낮은 붐(팀파니 대신)."""
    n = int(1.4 * SR)
    t = np.arange(n) / SR
    fr = f * (1 + 0.6 * np.exp(-t / 0.04))
    return np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-t / 0.5)


def inst_swell(f, dur):
    """구간 전환 직전의 흰소음 상승(아주 작게)."""
    n = int(dur * SR)
    x = fft_band(np.random.default_rng(9).standard_normal(n), 1500, 9000)
    ramp = np.linspace(0, 1, n) ** 3
    return x * ramp * 0.5


INSTRUMENTS = {
    "rhodes": inst_rhodes, "piano": inst_piano, "bass": inst_bass, "synth_bass": inst_synth_bass,
    "guitar": inst_guitar, "pad": inst_pad, "strings": inst_strings, "lead": inst_lead, "bell": inst_bell,
    "pluck": inst_pluck, "mallet": inst_mallet, "choir": inst_choir, "sub_hit": inst_sub_hit, "swell": inst_swell,
}


# ------------------------------------------------------------------ drums

def make_kit(seed, tight=1.0):
    """드럼 한 벌. 킥은 둥글게, 스네어는 몸통 + 짧은 잡음, 하이햇은 얇고 작게."""
    rng = np.random.default_rng(seed)
    d = {}
    t = np.arange(int(0.45 * SR)) / SR
    fk = 54 + 95 * np.exp(-t / 0.035)
    d["kick"] = np.sin(2 * np.pi * np.cumsum(fk) / SR) * np.exp(-t / (0.24 * tight)) + \
        fft_band(rng.standard_normal(len(t)), 1500, 6000) * np.exp(-t / 0.003) * 0.12
    t = np.arange(int(0.35 * SR)) / SR
    tone = (np.sin(2 * np.pi * 190 * t) + 0.4 * np.sin(2 * np.pi * 320 * t)) * np.exp(-t / 0.06)
    d["snare"] = 0.7 * tone + 0.75 * fft_band(rng.standard_normal(len(t)), 1800, 8000) * np.exp(-t / (0.11 * tight))
    d["ghost"] = 0.4 * tone + 0.6 * fft_band(rng.standard_normal(len(t)), 2000, 7000) * np.exp(-t / 0.04)
    t = np.arange(int(0.3 * SR)) / SR
    clap = np.zeros(len(t))
    for k, off in enumerate((0.0, 0.01, 0.02)):
        s = int(off * SR)
        clap[s:] += fft_band(rng.standard_normal(len(t) - s), 1000, 5500) * np.exp(-t[:len(t) - s] / (0.01 if k < 2 else 0.09))
    d["clap"] = clap
    t = np.arange(int(0.1 * SR)) / SR
    d["hat"] = fft_band(rng.standard_normal(len(t)), 7500, 14000) * np.exp(-t / 0.02)
    t = np.arange(int(0.4 * SR)) / SR
    d["ohat"] = fft_band(rng.standard_normal(len(t)), 7000, 14000) * np.exp(-t / 0.15)
    t = np.arange(int(0.14 * SR)) / SR
    d["shaker"] = fft_band(rng.standard_normal(len(t)), 5000, 11000) * np.clip(t / 0.015, 0, 1) * np.exp(-t / 0.04)
    t = np.arange(int(0.1 * SR)) / SR
    d["rim"] = (0.5 * np.sin(2 * np.pi * 1650 * t) + fft_band(rng.standard_normal(len(t)), 2000, 7000)) * np.exp(-t / 0.015)
    t = np.arange(int(2.4 * SR)) / SR
    d["crash"] = fft_band(rng.standard_normal(len(t)), 4000, 13000) * np.exp(-t / 0.9) * np.clip(t / 0.004, 0, 1)
    d["ride"] = (fft_band(rng.standard_normal(len(t)), 5000, 12000) * 0.6 + 0.2 * np.sin(2 * np.pi * 3100 * t)) * np.exp(-t / 0.35)
    for name, f0, dec in (("tom_hi", 170, 0.25), ("tom_lo", 105, 0.35)):
        t = np.arange(int(0.6 * SR)) / SR
        fr = f0 * (1 + 0.4 * np.exp(-t / 0.02))
        d[name] = np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-t / dec)
    return {k: v / (np.max(np.abs(v)) + 1e-9) for k, v in d.items()}


# ------------------------------------------------------------------ mixing helpers

class Bus:
    def __init__(self, n):
        self.l = np.zeros(n)
        self.r = np.zeros(n)

    def add(self, x, start, pan=0.0, gain=1.0):
        if start >= len(self.l):
            return
        x = x[:len(self.l) - start]
        a = (pan + 1) * np.pi / 4
        self.l[start:start + len(x)] += gain * np.cos(a) * x
        self.r[start:start + len(x)] += gain * np.sin(a) * x

    def stereo(self):
        return np.stack([self.l, self.r])


def reverb_ir(seconds, rng, bright=5500.0, predelay=0.02):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    decay = np.exp(-6.9 * t / seconds)
    irs = []
    for _ in range(2):
        noise = fft_band(rng.standard_normal(n), 250, bright) * decay
        noise[: int(predelay * SR)] = 0.0
        irs.append(noise / np.sqrt(np.sum(noise ** 2)))
    return np.stack(irs)


def convolve(x, ir):
    n = x.shape[1] + ir.shape[1]
    size = 1 << (n - 1).bit_length()
    out = np.zeros((2, x.shape[1]))
    for ch in range(2):
        out[ch] = np.fft.irfft(np.fft.rfft(x[ch], size) * np.fft.rfft(ir[ch], size), size)[: x.shape[1]]
    return out


def echo(x, delay_s, feedback=0.3, taps=4):
    """핑퐁 딜레이(되돌아오는 소리는 어둡게)."""
    out = x.copy()
    d = int(delay_s * SR)
    dark = np.stack([fft_band(x[0], 200, 4500), fft_band(x[1], 200, 4500)])
    for k in range(1, taps + 1):
        src = dark[::-1] if k % 2 else dark
        out[:, k * d:] += feedback ** k * src[:, : x.shape[1] - k * d]
    return out


# ------------------------------------------------------------------ song

class Song:
    def __init__(self, name, bpm, bars, seed, shuffle=0.0, tail=4.0):
        self.name, self.bpm, self.bars, self.seed = name, bpm, bars, seed
        self.beat = 60.0 / bpm
        self.loop_len = int(round(bars * 4 * self.beat * SR))
        self.n = self.loop_len + int(tail * SR)
        self.rng = np.random.default_rng(seed)
        self.shuffle = shuffle   # 16분 뒷박을 늦추는 정도(16분의 비율)
        self.buses = {}
        self.cache = {}
        self.kicks = []          # 사이드체인 기준

    def bus(self, name):
        if name not in self.buses:
            self.buses[name] = Bus(self.n)
        return self.buses[name]

    def when(self, bar, beat, human=0.004):
        q = beat * 4
        if self.shuffle and abs(q - round(q)) < 1e-6 and int(round(q)) % 2 == 1:
            beat += self.shuffle * 0.25
        jitter = self.rng.normal(0, human)
        return max(0, int(round(((bar * 4 + beat) * self.beat + jitter) * SR)))

    def note(self, bus, inst, bar, beat, beats, midi, vel=0.8, pan=0.0, delay=0.0):
        v = vel * (1.0 + self.rng.normal(0, 0.07))
        # 악기는 세기에 선형이다: 같은 (악기, 음, 길이)는 한 번만 합성하고 세기만 곱한다.
        key = (inst, midi, round(beats * self.beat, 4))
        if key not in self.cache:
            self.cache[key] = INSTRUMENTS[inst](mtof(midi), beats * self.beat)
        self.bus(bus).add(self.cache[key] * v, self.when(bar, beat) + int(delay * SR), pan)

    def hit(self, kit, name, bar, beat, vel=0.8, pan=0.0):
        if name == "kick":
            self.kicks.append((bar, beat))
        self.bus("drums").add(kit[name] * vel * (1.0 + self.rng.normal(0, 0.06)), self.when(bar, beat, 0.002), pan)


def melody(s, bus, inst, bar0, line, vel, pan=0.0, transpose=0, delay=0.0):
    for bo, beat, beats, m in line:
        s.note(bus, inst, bar0 + bo, beat, beats, m + transpose, vel, pan, delay)


def comp(s, bus, inst, chords, pattern, vel, center=63, strum=0.008, spread=0.5, rootless=True, count=None,
         accent=None):
    """화음 반주. pattern = [(박 오프셋, 길이)] (4박 화음 기준; 짧은 화음은 그 안에 드는 것만)."""
    prev = None
    for c in chords:
        v = voice(c, prev, center, rootless=rootless, count=count)
        prev = v
        for k, (off, dur) in enumerate(pattern):
            if off >= c.beats - 1e-6:
                continue
            dur = min(dur, c.beats - off)
            acc = accent[k % len(accent)] if accent else 1.0
            for i, m in enumerate(v):
                pan = -spread + 2 * spread * i / max(1, len(v) - 1)
                s.note(bus, inst, c.bar, c.beat + off, dur, m, vel * acc, pan, delay=i * strum)


def bass_line(s, bus, inst, chords, pattern, vel, pan=0.0):
    """pattern = [(박 오프셋, 음, 길이, 세기)] — 음: "R" 근음, "5", "8", "b7", "A" 다음 근음으로 가는 경과음."""
    for idx, c in enumerate(chords):
        r = c.bass()
        nxt = chords[(idx + 1) % len(chords)].bass()
        for off, deg, dur, acc in pattern:
            if off >= c.beats - 1e-6:
                continue
            if deg == "A":
                if c.beats - off > 0.75:
                    deg = "8"   # 화음이 한참 남았으면 경과음 대신 옥타브
                else:
                    m = nxt - 1 if nxt > r else nxt + 1
                    if m == r:
                        m = r + 7
            if deg != "A":
                m = r + {"R": 0, "5": 7 if 7 in c.ints or len(c.ints) < 4 else 6 if 6 in c.ints else 7,
                         "8": 12, "b7": 10, "3": c.ints[1]}[deg]
            s.note(bus, inst, c.bar, c.beat + off, min(dur, c.beats - off), m, vel * acc, pan)


def arpeggio(s, bus, inst, chords, order, step, vel, center=70, pan_swing=0.4, length=None):
    """분산화음: 화음 구성음(루트 포함, 두 옥타브)을 order 순서로 step 박마다."""
    for c in chords:
        base = voice(c, None, center, rootless=False, count=4)
        notes = base + [m + 12 for m in base]
        k = 0
        pos = 0.0
        while pos < c.beats - 1e-6:
            m = notes[order[k % len(order)] % len(notes)]
            s.note(bus, inst, c.bar, c.beat + pos, length or step, m, vel * (1.0 if k % 4 == 0 else 0.8),
                   pan_swing if k % 2 else -pan_swing)
            k += 1
            pos += step


def pads(s, bus, inst, chords, vel, center=60, count=4):
    prev = None
    for c in chords:
        v = voice(c, prev, center, rootless=False, count=count)
        prev = v
        for i, m in enumerate(v):
            s.note(bus, inst, c.bar, c.beat, c.beats, m, vel, -0.6 + 1.2 * i / max(1, len(v) - 1))


# ------------------------------------------------------------------ drum grooves

def groove_pop(s, kit, bar, v=1.0, kick=(0, 2.5), snare=(1, 3), hat16=True, shaker=False, open_hat=3.5, fill=False):
    for b in kick:
        s.hit(kit, "kick", bar, b, 0.62 * v)
    for b in snare:
        s.hit(kit, "snare", bar, b, 0.5 * v, 0.05)
    if hat16:
        for k in range(16):
            if fill and k >= 12:
                continue
            acc = (0.26, 0.1, 0.17, 0.1)[k % 4]
            s.hit(kit, "hat", bar, k * 0.25, acc * v, 0.3)
    else:
        for k in range(8):
            s.hit(kit, "hat", bar, k * 0.5, (0.22 if k % 2 == 0 else 0.14) * v, 0.3)
    if shaker:
        for k in range(8):
            s.hit(kit, "shaker", bar, k * 0.5 + 0.25, 0.12 * v, -0.35)
    if open_hat is not None and not fill:
        s.hit(kit, "ohat", bar, open_hat, 0.12 * v, 0.3)
    if fill:
        for k, b in enumerate((3.0, 3.25, 3.5, 3.75)):
            s.hit(kit, "snare" if k % 2 == 0 else "ghost", bar, b, (0.2 + 0.06 * k) * v, -0.1 + 0.07 * k)


def groove_four(s, kit, bar, v=1.0, clap=True, fill=False):
    """네 박 킥 + 뒷박 오픈햇(퓨처 펑크·하우스)."""
    for b in range(4):
        s.hit(kit, "kick", bar, b, 0.62 * v)
        s.hit(kit, "ohat" if b % 2 else "hat", bar, b + 0.5, (0.1 if b % 2 else 0.2) * v, 0.3)
        s.hit(kit, "hat", bar, b + 0.25, 0.07 * v, 0.3)
        s.hit(kit, "hat", bar, b + 0.75, 0.08 * v, 0.3)
    for b in (1, 3):
        s.hit(kit, "clap" if clap else "snare", bar, b, 0.42 * v, 0.08)
        s.hit(kit, "snare", bar, b, 0.22 * v, -0.05)
    if fill:
        for k, b in enumerate((2.5, 2.75, 3.25, 3.5, 3.75)):
            s.hit(kit, "snare", bar, b, (0.15 + 0.05 * k) * v, -0.1 + 0.05 * k)


def groove_break(s, kit, bar, v=1.0, fill=False, ride=False):
    """빠른 곡용 브레이크비트: 킥 1·2.5(·3.75), 스네어 2·4, 고스트 노트."""
    s.hit(kit, "kick", bar, 0, 0.62 * v)
    s.hit(kit, "kick", bar, 2.5, 0.52 * v)
    if bar % 2 == 1:
        s.hit(kit, "kick", bar, 1.75, 0.4 * v)
    s.hit(kit, "snare", bar, 1, 0.52 * v, 0.05)
    s.hit(kit, "snare", bar, 3, 0.52 * v, 0.05)
    for b in (0.75, 2.25, 3.75):
        if not (fill and b > 3):
            s.hit(kit, "ghost", bar, b, 0.12 * v, -0.08)
    for k in range(8):
        if fill and k >= 6:
            continue
        if ride:
            s.hit(kit, "ride", bar, k * 0.5, (0.16 if k % 2 == 0 else 0.1) * v, 0.35)
        else:
            s.hit(kit, "hat", bar, k * 0.5, (0.22 if k % 2 == 0 else 0.13) * v, 0.3)
            s.hit(kit, "hat", bar, k * 0.5 + 0.25, 0.07 * v, 0.3)
    if fill:
        for k, (b, d) in enumerate(((3.0, "tom_hi"), (3.25, "tom_hi"), (3.5, "tom_lo"), (3.75, "snare"))):
            s.hit(kit, d, bar, b, (0.3 + 0.06 * k) * v, 0.25 - 0.15 * k)


# ================================================================== songs

def compose_lobby():
    """"Afterschool Plaza" — 로비. D장조 98BPM, 32마디. 느긋한 시티팝.
    A(1~8) 로즈·베이스·드럼만 / A'(9~16) 부드러운 리드가 주제 / B(17~24) 기타 커팅이 들어오고 종이 두 번째 선율 /
    A''(25~32) 주제를 종과 리드가 옥타브로 나눠 부른다."""
    s = Song("lobby_theme", bpm=98, bars=32, seed=5391, shuffle=0.1)
    kit = make_kit(s.seed + 1)
    A = prog("Gmaj9:4 | A13:4 | F#m7:4 | Bm9:4 | Em9:4 | A7sus4:2 A7:2 | Dmaj9:4 | D9:4 |")
    B = prog("Gmaj9:4 | F#7b13:4 | Bm9:4 | Am7:2 D7:2 | Gmaj9:4 | F#m7:2 B7:2 | Em9:4 | A13:4 |")
    chords = A + shift(A, 8) + shift(B, 16) + shift(A, 24)
    theme = seq("r:1 F#5:.5 A5:.5 B5:1 A5:.5 F#5:.5 | E5:1.5 D5:.5 E5:1 r:1 | "
                "r:.5 C#5:.5 E5:.5 F#5:.5 A5:1 E5:1 | F#5:2 r:1 D5:.5 E5:.5 | "
                "F#5:1 G5:.5 F#5:.5 E5:1 D5:.5 B4:.5 | D5:1.5 E5:.5 C#5:2 | "
                "r:.5 A4:.5 D5:.5 E5:.5 F#5:1 E5:.5 C#5:.5 | D5:3 r:1 |")
    theme_b = seq("B5:1 A5:.5 B5:.5 D6:1 B5:.5 A5:.5 | A#5:1.5 F#5:.5 E5:1 r:1 | "
                  "r:.5 F#5:.5 B5:.5 C#6:.5 D6:1.5 C#6:.5 | C6:1 B5:.5 A5:.5 F#5:1 A5:1 | "
                  "G5:2 r:.5 F#5:.5 G5:.5 A5:.5 | A5:1 F#5:1 D#5:1.5 r:.5 | "
                  "E5:.5 F#5:.5 G5:.5 B5:.5 D6:1 B5:1 | C#6:1.5 B5:.5 A5:1 r:1 |")

    comp(s, "keys", "rhodes", chords, [(0, 0.75), (0.75, 0.5), (1.75, 0.75), (2.5, 0.5), (3.25, 0.75)], 0.13,
         center=62, accent=(1.0, 0.7, 0.85, 0.75, 0.8))
    bass_line(s, "bass", "bass", chords, [(0, "R", .7, 1.0), (.75, "R", .2, .5), (1.5, "8", .4, .7), (2, "R", .45, .85),
                                          (2.75, "5", .25, .6), (3, "8", .4, .7), (3.5, "A", .45, .75)], 0.5)
    pads(s, "pad", "pad", chords[len(A):], 0.035, center=60)
    # B: 기타 커팅(뒷박 16분)
    comp(s, "gtr", "guitar", [c for c in chords if 16 <= c.bar < 24],
         [(0.5, 0.12), (1.25, 0.12), (1.5, 0.12), (2.5, 0.12), (3.25, 0.12), (3.5, 0.12)], 0.07,
         center=66, strum=0.006, spread=0.3, count=4)
    melody(s, "lead", "lead", 8, theme, 0.13, 0.05)
    melody(s, "bells", "bell", 16, theme_b, 0.11, 0.2)
    melody(s, "bells", "bell", 24, theme, 0.1, 0.25, transpose=12)
    melody(s, "lead", "lead", 24, theme, 0.07, -0.1)
    for bar in range(32):
        sec = bar // 8
        groove_pop(s, kit, bar, v=0.8 if sec == 0 else 0.95, shaker=sec >= 1, fill=bar % 8 == 7,
                   kick=(0, 2.5) if bar % 2 == 0 else (0, 1.75, 2.5))
        if bar % 8 == 0:
            s.hit(kit, "crash", bar, 0, 0.12, -0.4)
    return s, mix(s, levels={"drums": 0, "bass": -2, "keys": -3, "pad": -13, "gtr": -12, "lead": -6, "bells": -8},
                  sends={"drums": 0.08, "keys": 0.22, "pad": 0.35, "gtr": 0.18, "lead": 0.3, "bells": 0.35},
                  duck=("keys", "pad", "gtr"), depth=0.22, room=1.8,
                  echoes={"lead": (0.75 * s.beat, 0.25, 3), "bells": (0.5 * s.beat, 0.3, 3)},
                  autopan={"keys": (1 / (2 * s.beat), 0.18)})


def compose_story():
    """"Letters in Blue" — 스토리. F장조 72BPM, 24마디. 피아노가 말을 걸고 로즈·현이 뒤에서 받쳐 준다.
    1(1~8) 피아노 독주 + 옅은 패드 / 2(9~16) 로즈 분산화음·베이스·브러시 같은 셰이커 / 3(17~24) 현이 차오르고 종이 선율을 겹친다."""
    s = Song("story_theme", bpm=72, bars=24, seed=5392, tail=5.0)
    kit = make_kit(s.seed + 1, tight=0.8)
    P = prog("Bbmaj9:4 | Am7:4 | Gm9:4 | C7sus4:2 C7:2 | Fmaj9:4 | Dm9:4 | Gm9:4 | C9sus4:4 |")
    chords = P + shift(P, 8) + shift(P, 16)
    theme = seq("r:1 A4:.5 C5:.5 D5:1.5 C5:.5 | C5:2 r:.5 G4:.5 A4:.5 C5:.5 | D5:1 F5:1 A5:1.5 G5:.5 | "
                "F5:2 E5:1 r:1 | r:.5 C5:.5 F5:.5 G5:.5 A5:2 | G5:1 F5:.5 E5:.5 F5:1 r:1 | "
                "D5:1 F5:.5 G5:.5 Bb5:1.5 A5:.5 | G5:3 r:1 |")
    # 왼손: 근음 + 열린 10도 화음을 2박마다
    for c in chords:
        r = c.bass() + 12
        top = voice(c, None, 58, rootless=True, count=3)
        for off in (0, 2):
            if off < c.beats:
                s.note("keys", "piano", c.bar, c.beat + off, 1.9, r, 0.16, -0.2)
                for i, m in enumerate(top):
                    s.note("keys", "piano", c.bar, c.beat + off + 0.5, 1.4, m, 0.08, -0.1 + 0.1 * i, delay=0.012 * i)
    pads(s, "pad", "pad", chords[:8], 0.025, center=58)
    arpeggio(s, "rhodes", "rhodes", [c for c in chords if c.bar >= 8], [0, 1, 2, 3, 4, 3, 2, 1], 0.5, 0.07, center=64,
             pan_swing=0.45, length=0.9)
    bass_line(s, "bass", "bass", [c for c in chords if c.bar >= 8], [(0, "R", 1.8, 1.0), (2, "5", .9, .6), (3, "R", .9, .7)], 0.38)
    pads(s, "strings", "strings", [c for c in chords if c.bar >= 16], 0.06, center=62)
    melody(s, "lead", "piano", 0, theme, 0.24, 0.1)
    melody(s, "lead", "piano", 8, theme, 0.2, 0.1)
    melody(s, "lead", "piano", 16, theme, 0.2, 0.1, transpose=12)
    melody(s, "bells", "bell", 16, theme, 0.07, 0.3, transpose=12)
    for bar in range(8, 24):
        for k in range(8):
            s.hit(kit, "shaker", bar, k * 0.5 + 0.25, 0.07 if k % 2 else 0.1, -0.3)
        s.hit(kit, "kick", bar, 0, 0.3)
        s.hit(kit, "rim", bar, 3, 0.1, 0.2)
        if bar >= 16:
            s.hit(kit, "kick", bar, 2.5, 0.2)
    s.note("fx", "swell", 15, 2, 2, 60, 0.04)
    return s, mix(s, levels={"keys": -4, "pad": -14, "rhodes": -9, "bass": -6, "strings": -10, "lead": -2, "bells": -12, "drums": -10, "fx": -24},
                  sends={"keys": 0.35, "pad": 0.4, "rhodes": 0.35, "strings": 0.45, "lead": 0.4, "bells": 0.45,
                         "drums": 0.15, "fx": 0.4},
                  duck=(), depth=0.0, room=2.6, echoes={"bells": (0.75 * s.beat, 0.3, 3)},
                  autopan={"rhodes": (0.5 / s.beat, 0.25)})


def compose_sortie():
    """"Blue Sortie" — 스테이지 선택·편성. A장조 124BPM, 32마디. 설레는 퓨처 펑크.
    A(1~8) 플럭 분산화음 + 네 박 킥 / A'(9~16) 리드가 훅 / B(17~24) 두 번째 선율, 기타 커팅 / A''(25~32) 훅 + 종 옥타브."""
    s = Song("sortie_theme", bpm=124, bars=32, seed=5393, shuffle=0.04)
    kit = make_kit(s.seed + 1, tight=0.9)
    A = prog("Dmaj7:4 | E6:4 | C#m7:4 | F#m7:4 | Dmaj7:4 | E6:4 | C#m7:4 | F#m7:4 |")
    B = prog("Bm7:4 | C#m7:4 | Dmaj7:4 | E7sus4:2 E7:2 | Bm7:4 | C#7:4 | F#m7:4 | E7sus4:2 E7:2 |")
    chords = A + shift(A, 8) + shift(B, 16) + shift(A, 24)
    hook = seq("r:.5 E5:.5 F#5:.5 A5:.5 C#6:1 B5:.5 A5:.5 | B5:1.5 G#5:.5 E5:.5 F#5:.5 G#5:1 | "
               "G#5:1.5 B5:.5 G#5:.5 E5:.5 C#5:1 | C#5:.5 E5:.5 F#5:1 r:1 E5:.5 F#5:.5 | "
               "r:.5 E5:.5 F#5:.5 A5:.5 C#6:1 B5:.5 A5:.5 | B5:1.5 G#5:.5 E5:.5 F#5:.5 G#5:1 | "
               "G#5:1.5 B5:.5 G#5:.5 E5:.5 C#5:1 | A5:1.5 G#5:.5 F#5:2 |")
    theme_b = seq("F#5:1 A5:1 B5:1.5 A5:.5 | G#5:2 E5:1 r:1 | F#5:1 A5:1 C#6:1.5 B5:.5 | A5:2 G#5:1.5 r:.5 | "
                  "B5:1 A5:.5 B5:.5 D6:1 C#6:.5 B5:.5 | G#5:1.5 F5:.5 G#5:1 B5:1 | A5:2 F#5:1 E5:1 | E5:2 D5:1 r:1 |")
    comp(s, "keys", "rhodes", chords, [(0, 0.4), (0.75, 0.25), (1.5, 0.4), (2.5, 0.25), (3.0, 0.4)], 0.1, center=64,
         accent=(1.0, 0.7, 0.85, 0.7, 0.8))
    arpeggio(s, "pluck", "pluck", chords, [0, 2, 4, 2, 1, 3, 5, 3], 0.25, 0.06, center=69, pan_swing=0.5)
    bass_line(s, "bass", "bass", chords, [(0, "R", .4, 1.0), (.5, "8", .2, .6), (.75, "R", .2, .7), (1.5, "R", .4, .8),
                                          (2, "8", .2, .6), (2.5, "R", .4, .85), (3, "5", .4, .7), (3.5, "A", .4, .75)], 0.5)
    pads(s, "pad", "pad", chords[8:], 0.03, center=62)
    comp(s, "gtr", "guitar", [c for c in chords if 16 <= c.bar < 24],
         [(0.25, 0.1), (0.5, 0.1), (1.25, 0.1), (1.5, 0.1), (2.25, 0.1), (2.5, 0.1), (3.25, 0.1), (3.5, 0.1)], 0.06,
         center=67, strum=0.005, spread=0.3, count=4)
    melody(s, "lead", "lead", 8, hook, 0.13, 0.05)
    melody(s, "lead", "lead", 16, theme_b, 0.12, 0.05)
    melody(s, "lead", "lead", 24, hook, 0.11, 0.05)
    melody(s, "bells", "bell", 24, hook, 0.08, -0.25, transpose=12)
    for bar in range(32):
        sec = bar // 8
        if sec == 2:
            groove_pop(s, kit, bar, v=0.9, kick=(0, 1.5, 2.5), fill=bar % 8 == 7, shaker=True)
        else:
            groove_four(s, kit, bar, v=0.8 if sec == 0 else 0.92, fill=bar % 8 == 7)
        if bar % 8 == 0:
            s.hit(kit, "crash", bar, 0, 0.13, 0.4)
    s.note("fx", "swell", 15, 2, 2, 60, 0.05)
    s.note("fx", "swell", 23, 2, 2, 60, 0.05)
    return s, mix(s, levels={"drums": 0, "bass": -2, "keys": -5, "pluck": -10, "pad": -13, "gtr": -12, "lead": -6, "bells": -10, "fx": -22},
                  sends={"drums": 0.06, "keys": 0.2, "pluck": 0.25, "pad": 0.35, "gtr": 0.15, "lead": 0.28, "bells": 0.35, "fx": 0.3},
                  duck=("keys", "pad", "pluck", "gtr"), depth=0.35, room=1.7,
                  echoes={"lead": (0.75 * s.beat, 0.25, 3), "pluck": (0.75 * s.beat, 0.2, 2)},
                  autopan={"keys": (1 / (2 * s.beat), 0.15)})


def compose_land():
    """"Schale Skirmish" — 1챕터(땅) 전투. B단조/D장조 148BPM, 32마디. 피아노 스탭과 브레이크비트.
    A(1~8) 피아노·베이스·드럼 / A'(9~16) 리드 주제 / B(17~24) 두 번째 선율, 라이드로 바꿔 넓게 / A''(25~32) 주제 + 종."""
    s = Song("battle_land", bpm=148, bars=32, seed=5394)
    kit = make_kit(s.seed + 1, tight=0.85)
    A = prog("Bm9:4 | Gmaj9:4 | A6:4 | F#m7:4 | Bm9:4 | Gmaj9:4 | A6:4 | F#m7:4 |")
    B = prog("Em9:4 | F#m7:4 | Gmaj9:4 | A7sus4:2 A7:2 | Em9:4 | F#m7:4 | Gmaj9:4 | A7:4 |")
    chords = A + shift(A, 8) + shift(B, 16) + shift(A, 24)
    theme = seq("F#5:.75 D5:.75 F#5:.5 B5:1 A5:.5 F#5:.5 | G5:.75 F#5:.75 D5:.5 B4:1 D5:1 | "
                "E5:.75 C#5:.75 E5:.5 A5:1 F#5:.5 E5:.5 | F#5:2 E5:.5 C#5:.5 r:1 | "
                "F#5:.75 D5:.75 F#5:.5 B5:1 A5:.5 F#5:.5 | G5:.75 A5:.75 B5:.5 D6:1 B5:1 | "
                "C#6:.75 B5:.75 A5:.5 E5:1 F#5:.5 A5:.5 | F#5:3 r:1 |")
    theme_b = seq("B5:1 A5:.5 B5:.5 D6:1 B5:1 | C#6:1.5 A5:.5 F#5:2 | B5:1 A5:.5 B5:.5 F#5:1 A5:1 | D6:2 C#6:1.5 r:.5 | "
                  "G5:1 F#5:.5 G5:.5 B5:1 E6:1 | C#6:1 A5:1 E6:1.5 C#6:.5 | D6:1.5 B5:.5 A5:1 F#5:1 | G5:1 E5:1 C#5:1 r:1 |")
    comp(s, "keys", "piano", chords, [(0, 0.35), (0.75, 0.25), (1.5, 0.35), (2.5, 0.25), (3.0, 0.35), (3.5, 0.25)], 0.11,
         center=65, strum=0.004, accent=(1.0, 0.7, 0.85, 0.75, 0.8, 0.6))
    bass_line(s, "bass", "synth_bass", chords, [(0, "R", .4, 1.0), (.5, "R", .2, .6), (.75, "8", .2, .7), (1.5, "R", .4, .8),
                                                (2, "5", .3, .7), (2.5, "R", .4, .85), (3, "8", .3, .7), (3.5, "A", .4, .75)], 0.42)
    pads(s, "pad", "pad", chords[8:], 0.03, center=62)
    arpeggio(s, "pluck", "pluck", [c for c in chords if c.bar >= 16], [0, 1, 2, 3, 4, 3, 2, 1], 0.25, 0.045, center=72)
    melody(s, "lead", "lead", 8, theme, 0.13, 0.05)
    melody(s, "lead", "lead", 16, theme_b, 0.12, 0.05)
    melody(s, "lead", "lead", 24, theme, 0.11, 0.05)
    melody(s, "bells", "bell", 24, theme, 0.07, -0.25, transpose=12)
    for bar in range(32):
        sec = bar // 8
        groove_break(s, kit, bar, v=0.85 if sec == 0 else 0.95, fill=bar % 8 == 7, ride=sec == 2)
        if bar % 8 == 0:
            s.hit(kit, "crash", bar, 0, 0.14, -0.4)
    s.note("fx", "swell", 7, 2, 2, 60, 0.04)
    s.note("fx", "swell", 23, 2, 2, 60, 0.05)
    return s, mix(s, levels={"drums": 0, "bass": -3, "keys": -4, "pad": -13, "pluck": -11, "lead": -6, "bells": -10, "fx": -22},
                  sends={"drums": 0.06, "keys": 0.2, "pad": 0.35, "pluck": 0.25, "lead": 0.26, "bells": 0.35, "fx": 0.3},
                  duck=("keys", "pad", "pluck"), depth=0.3, room=1.6,
                  echoes={"lead": (0.75 * s.beat, 0.22, 3)}, autopan={})


def compose_sea():
    """"Coral Parade" — 2챕터(바다) 전투. E장조 122BPM, 32마디. 트로피컬 퓨처 펑크: 나무 건반 뒷박, 통통 튀는 베이스.
    A(1~8) 건반·베이스·드럼 / A'(9~16) 리드 주제 / B(17~24) 나무 건반이 두 번째 선율 / A''(25~32) 주제 + 종."""
    s = Song("battle_sea", bpm=122, bars=32, seed=5395, shuffle=0.08)
    kit = make_kit(s.seed + 1, tight=0.9)
    A = prog("Amaj7:4 | B6:4 | G#m7:4 | C#m7:4 | Amaj7:4 | B6:4 | G#m7:4 | C#m7:4 |")
    B = prog("F#m7:4 | G#m7:4 | Amaj7:4 | B7sus4:2 B7:2 | F#m7:4 | G#m7:4 | Amaj7:4 | B7:4 |")
    chords = A + shift(A, 8) + shift(B, 16) + shift(A, 24)
    theme = seq("r:.5 E5:.5 G#5:.5 B5:.5 C#6:1 B5:.5 G#5:.5 | F#5:1 D#5:.5 F#5:.5 G#5:1.5 r:.5 | "
                "B5:1 G#5:.5 F#5:.5 D#5:1 F#5:1 | E5:2 r:1 B4:.5 C#5:.5 | "
                "r:.5 E5:.5 G#5:.5 B5:.5 E6:1 C#6:.5 B5:.5 | D#6:1 C#6:.5 B5:.5 G#5:1.5 F#5:.5 | "
                "G#5:1 B5:1 D#6:1 C#6:1 | B5:.5 G#5:.5 E5:2 r:1 |")
    theme_b = seq("A5:1.5 G#5:.5 F#5:1 E5:1 | F#5:1.5 G#5:.5 B5:2 | C#6:1 B5:.5 A5:.5 G#5:1 E5:1 | E5:2 D#5:1.5 r:.5 | "
                  "A5:.5 C#6:.5 E6:1 C#6:1 A5:1 | B5:.5 D#6:.5 F#6:1 D#6:1 B5:1 | C#6:2 B5:.5 A5:.5 G#5:1 | A5:1 F#5:1 D#5:1 r:1 |")
    comp(s, "keys", "rhodes", chords, [(0.5, 0.3), (1.5, 0.3), (2.5, 0.3), (3.25, 0.2), (3.5, 0.3)], 0.1, center=64,
         accent=(1.0, 0.9, 1.0, 0.6, 0.85))
    comp(s, "mallet", "mallet", chords, [(0, 0.25), (0.75, 0.25), (1.5, 0.25), (2.25, 0.25), (3.0, 0.25)], 0.05,
         center=72, strum=0.0, spread=0.6, count=3)
    bass_line(s, "bass", "bass", chords, [(0, "R", .5, 1.0), (.75, "8", .2, .6), (1.5, "5", .4, .75), (2, "R", .5, .9),
                                          (2.75, "8", .2, .6), (3, "5", .3, .7), (3.5, "A", .4, .75)], 0.5)
    pads(s, "pad", "pad", chords[8:], 0.028, center=62)
    melody(s, "lead", "lead", 8, theme, 0.12, 0.05)
    melody(s, "mallet", "mallet", 16, theme_b, 0.16, 0.15)
    melody(s, "lead", "lead", 16, theme_b, 0.06, -0.1)
    melody(s, "lead", "lead", 24, theme, 0.11, 0.05)
    melody(s, "bells", "bell", 24, theme, 0.07, -0.25, transpose=12)
    for bar in range(32):
        sec = bar // 8
        groove_four(s, kit, bar, v=0.75 if sec == 0 else 0.88, clap=True, fill=bar % 8 == 7)
        for k in range(8):
            s.hit(kit, "shaker", bar, k * 0.5 + 0.25, 0.1, -0.35)
        s.hit(kit, "rim", bar, 1.75, 0.1, -0.3)
        s.hit(kit, "rim", bar, 3.25, 0.08, -0.3)
        if bar % 8 == 0:
            s.hit(kit, "crash", bar, 0, 0.12, 0.4)
    return s, mix(s, levels={"drums": 0, "bass": -2, "keys": -5, "mallet": -6, "pad": -13, "lead": -6, "bells": -10},
                  sends={"drums": 0.07, "keys": 0.22, "mallet": 0.25, "pad": 0.35, "lead": 0.28, "bells": 0.35},
                  duck=("keys", "pad", "mallet"), depth=0.3, room=1.8,
                  echoes={"lead": (0.75 * s.beat, 0.25, 3), "mallet": (0.75 * s.beat, 0.18, 2)},
                  autopan={"keys": (1 / (2 * s.beat), 0.15)})


def compose_sky():
    """"Skyline Rush" — 3챕터(하늘) 전투. G장조 156BPM, 32마디. 쉬지 않는 16분 종 분산화음 위로 긴 음의 선율이 난다.
    A(1~8) 분산화음·베이스·드럼 / A'(9~16) 리드 주제 / B(17~24) 두 번째 선율, 현 패드 / A''(25~32) 주제 옥타브 위."""
    s = Song("battle_sky", bpm=156, bars=32, seed=5396)
    kit = make_kit(s.seed + 1, tight=0.8)
    A = prog("Cmaj9:4 | D6:4 | Bm7:4 | Em9:4 | Cmaj9:4 | D6:4 | Bm7:4 | Em9:4 |")
    B = prog("Am9:4 | Bm7:4 | Cmaj9:4 | D7sus4:2 D7:2 | Am9:4 | Bm7:4 | Cmaj9:4 | D7:4 |")
    chords = A + shift(A, 8) + shift(B, 16) + shift(A, 24)
    theme = seq("E5:1 G5:1 B5:2 | A5:1.5 B5:.5 A5:1 F#5:1 | F#5:2 D5:1 F#5:1 | G5:1 F#5:1 E5:2 | "
                "E5:1 G5:1 D6:2 | B5:1.5 A5:.5 F#5:1 A5:1 | D6:2 B5:1 A5:1 | B5:3 r:1 |")
    theme_b = seq("C6:1.5 B5:.5 A5:1 E5:1 | F#5:1.5 A5:.5 B5:2 | G5:1 B5:1 E6:2 | D6:2 C6:1.5 r:.5 | "
                  "E6:1.5 D6:.5 C6:1 B5:1 | A5:1.5 B5:.5 D6:2 | E6:1 D6:1 B5:1 G5:1 | A5:2 F#5:1 r:1 |")
    arpeggio(s, "arp", "bell", chords, [0, 1, 2, 3, 4, 3, 2, 1], 0.25, 0.045, center=72, pan_swing=0.5)
    comp(s, "keys", "rhodes", chords, [(0, 1.5), (1.5, 1.0), (2.5, 1.5)], 0.08, center=62, accent=(1.0, 0.7, 0.8))
    bass_line(s, "bass", "synth_bass", chords, [(0, "R", .45, 1.0), (.5, "R", .2, .5), (1, "8", .4, .7), (1.5, "R", .4, .7),
                                                (2, "R", .45, .9), (2.5, "5", .4, .6), (3, "8", .4, .7), (3.5, "A", .4, .7)], 0.4)
    pads(s, "pad", "strings", chords[16:24], 0.06, center=64)
    pads(s, "pad", "pad", chords[8:], 0.025, center=60)
    melody(s, "lead", "lead", 8, theme, 0.13, 0.05)
    melody(s, "lead", "lead", 16, theme_b, 0.12, 0.05)
    melody(s, "lead", "lead", 24, theme, 0.1, 0.05, transpose=12)
    melody(s, "lead", "lead", 24, theme, 0.06, -0.2)
    for bar in range(32):
        sec = bar // 8
        groove_break(s, kit, bar, v=0.8 if sec == 0 else 0.92, fill=bar % 8 == 7, ride=sec == 2)
        if bar % 8 == 0:
            s.hit(kit, "crash", bar, 0, 0.13, 0.4)
    s.note("fx", "swell", 15, 2, 2, 60, 0.04)
    return s, mix(s, levels={"drums": 0, "bass": -3, "arp": -8, "keys": -7, "pad": -12, "lead": -5, "fx": -22},
                  sends={"drums": 0.06, "arp": 0.3, "keys": 0.25, "pad": 0.4, "lead": 0.3, "fx": 0.3},
                  duck=("keys", "pad", "arp"), depth=0.3, room=2.0,
                  echoes={"lead": (0.75 * s.beat, 0.25, 3), "arp": (0.75 * s.beat, 0.2, 2)}, autopan={})


def compose_boss():
    """"Crimson Protocol" — 보스 웨이브. D단조 138BPM, 32마디. 긴장감은 피아노 오스티나토와 8분 베이스가 만들고,
    선율은 현·리드가 길게 끈다. A(1~8) 오스티나토 / A'(9~16) 주제 / B(17~24) 관계장조 쪽으로 열린다 / A''(25~32) 주제 + 합창."""
    s = Song("battle_boss", bpm=138, bars=32, seed=5397)
    kit = make_kit(s.seed + 1, tight=0.85)
    A = prog("Dm9:4 | Bbmaj7:4 | Gm7:4 | A7:4 | Dm9:4 | Bbmaj7:4 | Gm7:4 | A7:4 |")
    B = prog("Bbmaj7:4 | C:4 | Am7:4 | Dm9:4 | Bbmaj7:4 | C:4 | Gm7:4 | A7sus4:2 A7:2 |")
    chords = A + shift(A, 8) + shift(B, 16) + shift(A, 24)
    theme = seq("A5:1.5 F5:.5 D5:1 E5:1 | F5:1.5 D5:.5 F5:1 A5:1 | Bb5:2 A5:.5 G5:.5 F5:1 | E5:1.5 C#5:.5 A4:2 | "
                "D5:1 F5:1 A5:1 C6:1 | D6:1.5 C6:.5 Bb5:1 A5:1 | G5:1 Bb5:1 D6:1.5 C6:.5 | C#6:2 A5:1 r:1 |")
    theme_b = seq("D6:2 C6:1 A5:1 | G5:2 E5:1 C5:1 | A5:1.5 G5:.5 E5:2 | F5:2 E5:1 D5:1 | "
                  "D6:1.5 C6:.5 D6:1 F6:1 | E6:2 D6:1 C6:1 | Bb5:2 D6:1 Bb5:1 | D6:2 C#6:2 |")
    # 피아노 오스티나토: 16분으로 근음-5도-옥타브-화음음
    for c in chords:
        v = voice(c, None, 64, rootless=False, count=4)
        v = v + [v[0] + 12] if len(v) < 4 else v
        pat = [v[0], v[2], v[1], v[3], v[2], v[1]]
        pos = 0.0
        k = 0
        while pos < c.beats - 1e-6:
            s.note("keys", "piano", c.bar, c.beat + pos, 0.25, pat[k % len(pat)], 0.08 if k % 4 else 0.11, 0.25 if k % 2 else -0.15)
            pos += 0.25
            k += 1
    bass_line(s, "bass", "synth_bass", chords, [(b * 0.5, "R" if b % 4 != 3 else "8", 0.4, 1.0 if b % 2 == 0 else 0.7)
                                                for b in range(8)], 0.42)
    pads(s, "pad", "pad", chords, 0.03, center=58)
    pads(s, "strings", "strings", chords[8:], 0.05, center=62)
    pads(s, "choir", "choir", chords[24:], 0.05, center=64, count=3)
    melody(s, "lead", "strings", 8, theme, 0.14, 0.1)
    melody(s, "lead", "lead", 8, theme, 0.07, -0.1)
    melody(s, "lead", "lead", 16, theme_b, 0.12, 0.05)
    melody(s, "lead", "strings", 24, theme, 0.12, 0.1, transpose=12)
    melody(s, "lead", "lead", 24, theme, 0.08, -0.1)
    for bar in range(32):
        sec = bar // 8
        groove_break(s, kit, bar, v=0.8 if sec == 0 else 0.92, fill=bar % 8 == 7)
        if bar % 4 == 0:
            s.note("fx", "sub_hit", bar, 0, 1, 38, 0.18)
        if bar % 8 == 0:
            s.hit(kit, "crash", bar, 0, 0.14, -0.4)
    s.note("fx", "swell", 23, 2, 2, 60, 0.05)
    return s, mix(s, levels={"drums": 0, "bass": -2, "keys": -5, "pad": -12, "strings": -9, "choir": -11, "lead": -5, "fx": -8},
                  sends={"drums": 0.07, "keys": 0.2, "pad": 0.35, "strings": 0.4, "choir": 0.45, "lead": 0.3, "fx": 0.2},
                  duck=("keys", "pad", "strings"), depth=0.25, room=2.0,
                  echoes={"lead": (0.75 * s.beat, 0.2, 3)}, autopan={})


def compose_final():
    """"Last Sanctuary" — 최종 보스. C단조 146BPM, 32마디. 보스곡보다 넓다: 합창·현 오스티나토·낮은 붐.
    A(1~8) 현 스타카토 + 피아노 / A'(9~16) 주제 / B(17~24) 장조 쪽으로 밀어 올리는 선율 / A''(25~32) 주제 옥타브 + 합창."""
    s = Song("battle_final", bpm=146, bars=32, seed=5398)
    kit = make_kit(s.seed + 1, tight=0.85)
    A = prog("Cm9:4 | Abmaj7:4 | Ebmaj7:4 | G7sus4:2 G7:2 | Cm9:4 | Abmaj7:4 | Ebmaj7:4 | G7:4 |")
    B = prog("Abmaj7:4 | Bb:4 | Gm7:4 | Cm9:4 | Fm9:4 | Bb7:4 | Ebmaj7:2 Abmaj7:2 | Dm7b5:2 G7:2 |")
    chords = A + shift(A, 8) + shift(B, 16) + shift(A, 24)
    theme = seq("G5:1.5 Eb5:.5 G5:1 C6:1 | C6:1.5 Bb5:.5 G5:1 Eb5:1 | G5:1 Bb5:1 D6:1.5 C6:.5 | C6:2 B5:1.5 r:.5 | "
                "Eb6:1.5 D6:.5 C6:1 G5:1 | Ab5:1.5 G5:.5 Eb5:1 C5:1 | D5:1 Eb5:1 G5:1 Bb5:1 | B5:2 G5:1 r:1 |")
    theme_b = seq("Eb6:2 C6:1 Ab5:1 | D6:2 Bb5:1 F5:1 | G5:1.5 Bb5:.5 D6:2 | Eb6:3 D6:1 | "
                  "C6:1.5 Ab5:.5 G5:1 Ab5:1 | F5:1.5 Ab5:.5 D6:2 | G5:1 Bb5:1 C6:1 Eb6:1 | D6:1 C6:1 B5:2 |")
    # 오스티나토: 피아노 8분 옥타브 + 플럭 16분
    for c in chords:
        r = c.bass() + 12
        pos = 0.0
        while pos < c.beats - 1e-6:
            s.note("keys", "piano", c.bar, c.beat + pos, 0.45, r, 0.1, -0.2)
            s.note("keys", "piano", c.bar, c.beat + pos + 0.25, 0.2, r + 12, 0.05, 0.2)
            pos += 0.5
    arpeggio(s, "pluck", "pluck", chords, [0, 2, 1, 3, 2, 4, 3, 1], 0.25, 0.04, center=67)
    bass_line(s, "bass", "synth_bass", chords, [(b * 0.5, "R" if b % 4 != 3 else "8", 0.4, 1.0 if b % 2 == 0 else 0.7)
                                                for b in range(8)], 0.42)
    pads(s, "pad", "pad", chords, 0.03, center=58)
    pads(s, "strings", "strings", chords[8:], 0.05, center=62)
    pads(s, "choir", "choir", [c for c in chords if c.bar >= 16], 0.045, center=64, count=3)
    melody(s, "lead", "strings", 8, theme, 0.14, 0.1)
    melody(s, "lead", "lead", 8, theme, 0.07, -0.1)
    melody(s, "lead", "lead", 16, theme_b, 0.12, 0.05)
    melody(s, "lead", "strings", 16, theme_b, 0.08, 0.2)
    melody(s, "lead", "strings", 24, theme, 0.12, 0.1, transpose=12)
    melody(s, "lead", "lead", 24, theme, 0.08, -0.1)
    for bar in range(32):
        sec = bar // 8
        groove_break(s, kit, bar, v=0.82 if sec == 0 else 0.95, fill=bar % 8 == 7, ride=sec == 2)
        if bar % 2 == 0:
            s.note("fx", "sub_hit", bar, 0, 1, 36, 0.16 if bar % 8 else 0.22)
        if bar % 8 == 0:
            s.hit(kit, "crash", bar, 0, 0.15, -0.4)
    s.note("fx", "swell", 15, 2, 2, 60, 0.05)
    s.note("fx", "swell", 23, 2, 2, 60, 0.06)
    return s, mix(s, levels={"drums": 0, "bass": -2, "keys": -5, "pluck": -11, "pad": -12, "strings": -9, "choir": -10, "lead": -5, "fx": -8},
                  sends={"drums": 0.07, "keys": 0.2, "pluck": 0.25, "pad": 0.35, "strings": 0.4, "choir": 0.5,
                         "lead": 0.3, "fx": 0.2},
                  duck=("keys", "pad", "strings", "pluck"), depth=0.25, room=2.2,
                  echoes={"lead": (0.75 * s.beat, 0.2, 3)}, autopan={})


def compose_victory():
    """승리: 로즈 화음 위로 종이 올라가 D장조 으뜸화음에서 멈춘다(3마디 + 잔향)."""
    s = Song("jingle_victory", bpm=120, bars=3, seed=5399, tail=3.0)
    kit = make_kit(s.seed + 1)
    chords = prog("Gmaj9:4 | A6:4 | Dmaj9:4 |")
    comp(s, "keys", "rhodes", chords[:2], [(0, 0.9), (1.5, 0.4), (2.5, 1.4)], 0.14, center=64)
    comp(s, "keys", "rhodes", chords[2:], [(0, 4.0)], 0.16, center=64, strum=0.02)
    bass_line(s, "bass", "bass", chords[:2], [(0, "R", 1.4, 1.0), (1.5, "8", .4, .7), (2.5, "R", 1.4, .9)], 0.5)
    s.note("bass", "bass", 2, 0, 3.5, chords[2].bass(), 0.5)
    pads(s, "pad", "pad", chords, 0.035, center=62)
    line = seq("D5:.5 G5:.5 B5:.5 D6:.5 F#6:1 E6:1 | C#6:.5 E6:.5 A5:.5 C#6:.5 E6:1.5 r:.5 | F#6:4 |")
    melody(s, "bells", "bell", 0, line, 0.13, 0.2)
    melody(s, "lead", "lead", 0, line, 0.07, -0.15, transpose=-12)
    for b in (0, 1.5, 2.5):
        s.hit(kit, "kick", 0, b, 0.5)
        s.hit(kit, "kick", 1, b, 0.5)
    for b in (1, 3):
        s.hit(kit, "snare", 0, b, 0.4)
    for k, b in enumerate((2.0, 2.5, 3.0, 3.25, 3.5, 3.75)):
        s.hit(kit, "snare" if k % 2 == 0 else "ghost", 1, b, 0.2 + 0.05 * k)
    s.hit(kit, "kick", 2, 0, 0.6)
    s.hit(kit, "crash", 2, 0, 0.22, 0.3)
    for k in range(16):
        s.hit(kit, "hat", k // 8, (k % 8) * 0.5, 0.14, 0.3)
    return s, mix(s, levels={"keys": -2, "bass": -2, "pad": -12, "bells": -3, "lead": -9, "drums": -3},
                  sends={"keys": 0.3, "pad": 0.4, "bells": 0.4, "lead": 0.3, "drums": 0.1},
                  duck=(), depth=0.0, room=2.2, echoes={"bells": (0.5 * s.beat, 0.25, 3)}, autopan={}, loop_wrap=False)


def compose_defeat():
    """패배: 로즈가 조용히 내려와 해결하지 않은 sus 화음에 머문다 — 벌이 아니라 "한 번 더"의 여지."""
    s = Song("jingle_defeat", bpm=76, bars=2, seed=5400, tail=3.5)
    chords = prog("Gmaj9:4 | Em9:2 A7sus4:2 |")
    comp(s, "keys", "rhodes", chords, [(0, 4.0)], 0.12, center=62, strum=0.03)
    for c in chords:
        s.note("bass", "bass", c.bar, c.beat, c.beats, c.bass(), 0.4)
    pads(s, "pad", "pad", chords, 0.03, center=60)
    melody(s, "lead", "piano", 0, seq("B5:1 A5:1 F#5:1 D5:1 | E5:2 D5:2 |"), 0.16, 0.15)
    return s, mix(s, levels={"keys": -2, "bass": -5, "pad": -12, "lead": -1}, sends={"keys": 0.35, "pad": 0.45, "lead": 0.4},
                  duck=(), depth=0.0, room=2.6, echoes={}, autopan={}, loop_wrap=False)


# ------------------------------------------------------------------ mix & master

def active_rms(x):
    """소리가 나는 구간만의 RMS. 선율처럼 곡의 일부에서만 나오는 버스도 공정하게 잰다."""
    m = (x[0] ** 2 + x[1] ** 2) / 2
    hop = 2048
    e = m[: len(m) // hop * hop].reshape(-1, hop).mean(axis=1)
    if not np.any(e > 0):
        return 1e-9
    e = e[e > e.max() * 1e-4]
    return float(np.sqrt(e.mean()))


def mix(s, levels, sends, duck, depth, room, echoes, autopan, loop_wrap=True):
    """levels 는 dB 다: 각 버스의 (소리 나는 구간) RMS 를 이 값에 맞춘다. 드럼 0 을 기준으로 적는다.
    악기·세기를 고쳐도 균형이 흔들리지 않는다 — 믹스의 의도가 숫자 한 줄에 남는다."""
    s.levels = levels
    out = np.zeros((2, s.n))
    send = np.zeros((2, s.n))
    ducker = np.ones(s.n)
    if duck and depth > 0:
        t = np.arange(int(0.3 * SR)) / SR
        shape = 1.0 - depth * np.exp(-t / 0.09) * np.clip(t / 0.004, 0, 1)
        for bar, beat in s.kicks:
            a = s.when(bar, beat, 0.0)
            b = min(s.n, a + len(shape))
            ducker[a:b] = np.minimum(ducker[a:b], shape[: b - a])
    t = np.arange(s.n) / SR
    for name, bus in s.buses.items():
        x = bus.stereo()
        x = x * (10 ** (levels.get(name, -12.0) / 20) / active_rms(x))
        if name in echoes:
            d, fb, taps = echoes[name]
            x = echo(x, d, fb, taps)
        if name in autopan:
            rate, dep = autopan[name]
            lfo = dep * np.sin(2 * np.pi * rate * t)
            x = np.stack([x[0] * (1 + lfo), x[1] * (1 - lfo)])
        if name in duck:
            x = x * ducker
        out += x
        send += x * sends.get(name, 0.0)
    out += convolve(send, reverb_ir(room, np.random.default_rng(11)))
    # 테이프처럼 고역을 살짝 깎고 초저역을 정리한다 — 오래 틀어 둬도 귀가 피곤하지 않게.
    out = np.stack([fft_band(out[0], 38, 15000), fft_band(out[1], 38, 15000)])
    if not loop_wrap:
        fade = np.clip((s.n - np.arange(s.n)) / (1.0 * SR), 0, 1)
        return out * fade
    loop = out[:, : s.loop_len].copy()
    tail = out[:, s.loop_len:]
    loop[:, : tail.shape[1]] += tail
    return loop


def write_wav(path, stereo):
    data = (np.clip(stereo.T, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def loudness(path):
    r = subprocess.run([ffmpeg_exe(), "-hide_banner", "-i", path, "-af", "ebur128=framelog=quiet", "-f", "null", "-"],
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    for line in r.stderr.splitlines()[::-1]:
        if line.strip().startswith("I:"):
            return float(line.split()[1])
    raise RuntimeError("loudness measurement failed")


def master_to(stereo, target_lufs, tmpdir):
    # 가벼운 글루: 큰 소리만 부드럽게 눌러 드럼이 튀지 않게 한다.
    x = stereo / (np.max(np.abs(stereo)) + 1e-9)
    x = np.tanh(1.5 * x) / np.tanh(1.5) * 0.5
    probe = os.path.join(tmpdir, "probe.wav")
    ceiling = 10 ** (-1.5 / 20)
    for _ in range(3):
        write_wav(probe, x)
        x = x * 10 ** ((target_lufs - loudness(probe)) / 20)
        knee = ceiling * 0.8
        over = np.abs(x) > knee
        x = np.where(over, np.sign(x) * (knee + (ceiling - knee) * np.tanh((np.abs(x) - knee) / (ceiling - knee))), x)
    return x


def encode(stereo, name, tmpdir):
    wav = os.path.join(tmpdir, name + ".wav")
    write_wav(wav, stereo)
    out = os.path.join(OUT_DIR, name + ".ogg")
    subprocess.run([ffmpeg_exe(), "-y", "-hide_banner", "-loglevel", "error", "-i", wav, "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact",
                    "-c:a", "libvorbis", "-q:a", "5", "-ar", str(SR), "-ac", "2", out], check=True)
    return out, loudness(out)


# (합성 함수, 목표 음량 LUFS). 반복 여부는 곡마다 .import 의 loop 가 정한다.
# 배경음이므로 예전(−16.5 ~ −20)보다 3~4dB 낮다. 효과음·대사 위에 얹히지 않고 밑에 깔린다.
TRACKS = {
    "lobby": (compose_lobby, -23.0),
    "story": (compose_story, -23.5),
    "sortie": (compose_sortie, -22.0),
    "land": (compose_land, -21.0),
    "sea": (compose_sea, -21.0),
    "sky": (compose_sky, -21.0),
    "boss": (compose_boss, -20.5),
    "final": (compose_final, -20.5),
    "victory": (compose_victory, -21.0),
    "defeat": (compose_defeat, -23.0),
}


def main(argv):
    names = argv or list(TRACKS)
    with tempfile.TemporaryDirectory() as tmp:
        for key in names:
            compose, target = TRACKS[key]
            song, stereo = compose()
            rms = {k: round(20 * np.log10(active_rms(b.stereo()) + 1e-12), 1) for k, b in song.buses.items()}
            stereo = master_to(stereo, target, tmp)
            out, lufs = encode(stereo, song.name, tmp)
            print(json.dumps({"track": key, "file": os.path.relpath(out, ROOT), "bpm": song.bpm, "bars": song.bars,
                              "seconds": round(song.loop_len / SR, 2), "lufs": lufs,
                              "peak_db": round(20 * np.log10(np.max(np.abs(stereo))), 2), "bus_rms_db": rms},
                             ensure_ascii=False), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
