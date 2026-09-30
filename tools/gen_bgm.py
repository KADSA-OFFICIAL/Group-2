#!/usr/bin/env python3
"""배경음악 2곡을 합성해 OGG Vorbis 로 만든다 (#535).

외부 샘플·음원을 쓰지 않는다 — 모든 소리는 이 파일의 가산·FM 합성으로 만든다. 멜로디와 곡 구조는
이 파일에 직접 적은 **자작곡**이다. 분위기(템포·편성·코드 색)만 참고했다:
  - 전투 "Stone Rush": 소닉 매니아 Studiopolis·Flying Battery 풍의 경쾌한 펑크 — 일렉트릭 피아노
    comping, 브라스 스탭, 16분 베이스, 백비트 드럼. D 장조 140BPM.
  - 로비 "Pebble Plaza": 트릭컬 풍의 가볍고 통통 튀는 스윙 — 마림바·피치카토·글로켄·플루트,
    움파 튜바 베이스. F 장조 108BPM.

같은 시드면 같은 파일이 나온다. 반복 이음새는 곡 끝에서 넘친 잔향을 곡 처음에 더해 없앤다.

사용:
  python tools/gen_bgm.py                 # 두 곡 모두
  python tools/gen_bgm.py battle          # 한 곡만
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


# ------------------------------------------------------------------ oscillators

def additive(freq, n, wave="saw", cutoff=4000.0, detune_cents=0.0, vib=None, max_h=48):
    """대역 제한 파형. cutoff(Hz, 상수 또는 길이 n 배열)가 배음을 부드럽게 깎는다(가산 영역의 저역 통과)."""
    t = np.arange(n) / SR
    f = freq * 2.0 ** (detune_cents / 1200.0)
    inst = np.full(n, f)
    if vib is not None:
        rate, depth, delay = vib
        onset = np.clip((t - delay) / 0.25, 0.0, 1.0)
        inst = f * (1.0 + depth * onset * np.sin(2 * np.pi * rate * t))
    phase = 2 * np.pi * np.cumsum(inst) / SR
    cut = np.asarray(cutoff, dtype=np.float64)
    top = float(np.max(cut)) * 3.0
    out = np.zeros(n)
    for k in range(1, max_h + 1):
        if k * f > min(top, SR * 0.45):
            break
        if wave == "square" and k % 2 == 0:
            continue
        if wave == "tri":
            if k % 2 == 0:
                continue
            base = (1.0 / k ** 2) * (1 if (k // 2) % 2 == 0 else -1)
        else:
            base = 1.0 / k
        out += base * np.exp(-(k * f) / cut) * np.sin(k * phase)
    return out


def adsr(n, a, d, s, r, sr=SR, note_len=None):
    """길이 n 의 엔벨로프. note_len(샘플) 뒤에 r 초 동안 놓아준다."""
    note_len = n if note_len is None else note_len
    t = np.arange(n) / sr
    env = np.where(t < a, t / max(a, 1e-4), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-4)))
    rel = np.clip(1.0 - (np.arange(n) - note_len) / (r * sr + 1), 0.0, 1.0)
    return env * np.where(np.arange(n) < note_len, 1.0, rel)


# ------------------------------------------------------------------ instruments
# 모두 (freq, dur_seconds, vel) -> mono 배열. 꼬리(release)를 포함한다.

def inst_ep(f, dur, vel):
    """FM 일렉트릭 피아노: 변조 지수가 빨리 줄어 "틱" 하는 어택 뒤 둥근 소리."""
    n = int((dur + 0.6) * SR)
    t = np.arange(n) / SR
    index = 1.6 * np.exp(-t / 0.25) + 0.25
    body = np.sin(2 * np.pi * f * t + index * np.sin(2 * np.pi * f * t))
    tine = 0.18 * np.sin(2 * np.pi * f * 7.0 * t) * np.exp(-t / 0.04)
    env = adsr(n, 0.003, 0.9, 0.35, 0.25, note_len=int(dur * SR))
    return vel * (body + tine) * env


def inst_brass(f, dur, vel):
    n = int((dur + 0.25) * SR)
    t = np.arange(n) / SR
    cutoff = 700 + 2600 * np.clip(t / 0.05, 0, 1) * (0.55 + 0.45 * np.exp(-t / 0.18))
    x = sum(additive(f, n, "saw", cutoff, dc) for dc in (-9.0, 0.0, 8.0)) / 3.0
    return vel * x * adsr(n, 0.02, 0.2, 0.75, 0.12, note_len=int(dur * SR))


def inst_lead(f, dur, vel):
    """전투 리드: 톱니+사각을 섞은 부드러운 신스 브라스. 뒤에 깔리도록 밝기를 낮춘다."""
    n = int((dur + 0.3) * SR)
    t = np.arange(n) / SR
    cutoff = 900 + 1500 * np.exp(-t / 0.3)
    x = 0.6 * additive(f, n, "saw", cutoff, -5, vib=(5.2, 0.004, 0.18)) + \
        0.4 * additive(f, n, "square", cutoff, 5, vib=(5.2, 0.004, 0.18))
    return vel * x * adsr(n, 0.012, 0.4, 0.7, 0.15, note_len=int(dur * SR))


def inst_bass_funk(f, dur, vel):
    n = int((dur + 0.08) * SR)
    t = np.arange(n) / SR
    cutoff = 350 + 2200 * np.exp(-t / 0.05)
    x = 0.8 * additive(f, n, "square", cutoff) + 0.25 * np.sin(2 * np.pi * f * t)
    return vel * x * adsr(n, 0.002, 0.15, 0.55, 0.04, note_len=int(dur * SR))


def inst_pad(f, dur, vel):
    n = int((dur + 0.8) * SR)
    x = sum(additive(f, n, "saw", 1100.0, dc) for dc in (-12.0, -4.0, 5.0, 11.0)) / 4.0
    return vel * x * adsr(n, 0.35, 1.0, 0.85, 0.6, note_len=int(dur * SR))


def inst_marimba(f, dur, vel):
    n = int((min(dur, 0.6) + 0.5) * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.32) + \
        0.35 * np.sin(2 * np.pi * f * 4.0 * t) * np.exp(-t / 0.05) + \
        0.08 * np.sin(2 * np.pi * f * 9.9 * t) * np.exp(-t / 0.015)
    return vel * x * np.clip(t / 0.002, 0, 1)


def inst_glock(f, dur, vel):
    n = int(1.4 * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.7) + \
        0.35 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t / 0.25) + \
        0.15 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t / 0.08)
    return vel * x * np.clip(t / 0.001, 0, 1)


def inst_pizz(f, dur, vel):
    n = int(0.55 * SR)
    t = np.arange(n) / SR
    cutoff = 500 + 3200 * np.exp(-t / 0.04)
    return vel * additive(f, n, "saw", cutoff) * np.exp(-t / 0.18) * np.clip(t / 0.002, 0, 1)


def inst_flute(f, dur, vel, rng=np.random.default_rng(7)):
    n = int((dur + 0.25) * SR)
    t = np.arange(n) / SR
    x = additive(f, n, "tri", 2200.0, vib=(5.0, 0.005, 0.25)) + 0.25 * np.sin(2 * np.pi * 2 * f * t)
    breath = fft_band(rng.standard_normal(n), 1500, 6000) * 0.12 * np.exp(-t / 0.08)
    return vel * (x + breath) * adsr(n, 0.05, 0.5, 0.8, 0.18, note_len=int(dur * SR))


def inst_tuba(f, dur, vel):
    n = int((dur + 0.1) * SR)
    t = np.arange(n) / SR
    x = 0.6 * np.sin(2 * np.pi * f * t) + 0.55 * np.sin(4 * np.pi * f * t) + 0.25 * np.sin(6 * np.pi * f * t)
    return vel * x * adsr(n, 0.015, 0.2, 0.6, 0.06, note_len=int(dur * SR))


INSTRUMENTS = {
    "ep": inst_ep, "brass": inst_brass, "lead": inst_lead, "bass_funk": inst_bass_funk,
    "pad": inst_pad, "marimba": inst_marimba, "glock": inst_glock, "pizz": inst_pizz,
    "flute": inst_flute, "tuba": inst_tuba,
}


# ------------------------------------------------------------------ drums (한 번 합성해 재사용)

def fft_band(x, lo, hi):
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / SR)
    mask = 1.0 / (1 + (lo / np.maximum(freqs, 1)) ** 4) / (1 + (freqs / hi) ** 4)
    return np.fft.irfft(spec * mask, len(x))


def make_drums(rng, soft):
    d = {}
    t = np.arange(int(0.5 * SR)) / SR
    fk = 46 + (150 if not soft else 110) * np.exp(-t / (0.03 if not soft else 0.04))
    kick = np.sin(2 * np.pi * np.cumsum(fk) / SR) * np.exp(-t / (0.26 if not soft else 0.2))
    kick += fft_band(rng.standard_normal(len(t)), 2000, 9000) * np.exp(-t / 0.004) * (0.25 if not soft else 0.1)
    d["kick"] = kick
    t = np.arange(int(0.35 * SR)) / SR
    tone = (np.sin(2 * np.pi * 185 * t) + 0.5 * np.sin(2 * np.pi * 330 * t)) * np.exp(-t / 0.07)
    noise = fft_band(rng.standard_normal(len(t)), 1500, 9000) * np.exp(-t / 0.13)
    d["snare"] = 0.55 * tone + 0.9 * noise
    clap = np.zeros(len(t))
    for k, off in enumerate((0.0, 0.011, 0.022)):
        s = int(off * SR)
        clap[s:] += fft_band(rng.standard_normal(len(t) - s), 900, 6000) * np.exp(-t[:len(t) - s] / (0.012 if k < 2 else 0.11))
    d["clap"] = clap
    t = np.arange(int(0.12 * SR)) / SR
    d["hat"] = fft_band(rng.standard_normal(len(t)), 7000, 16000) * np.exp(-t / 0.025)
    t = np.arange(int(0.45 * SR)) / SR
    d["ohat"] = fft_band(rng.standard_normal(len(t)), 6500, 16000) * np.exp(-t / 0.18)
    t = np.arange(int(0.15 * SR)) / SR
    d["shaker"] = fft_band(rng.standard_normal(len(t)), 4500, 12000) * np.clip(t / 0.012, 0, 1) * np.exp(-t / 0.045)
    t = np.arange(int(2.2 * SR)) / SR
    d["crash"] = fft_band(rng.standard_normal(len(t)), 3500, 15000) * np.exp(-t / 0.9)
    t = np.arange(int(0.12 * SR)) / SR
    d["rim"] = (np.sin(2 * np.pi * 1700 * t) * 0.5 + fft_band(rng.standard_normal(len(t)), 2000, 8000)) * np.exp(-t / 0.018)
    return {k: v / (np.max(np.abs(v)) + 1e-9) for k, v in d.items()}


# ------------------------------------------------------------------ mixing helpers

class Bus:
    def __init__(self, n):
        self.l = np.zeros(n)
        self.r = np.zeros(n)

    def add(self, x, start, pan=0.0, gain=1.0):
        """pan -1(왼쪽)..1(오른쪽), 동력 보존 팬."""
        if start >= len(self.l):
            return
        x = x[:len(self.l) - start]
        a = (pan + 1) * np.pi / 4
        self.l[start:start + len(x)] += gain * np.cos(a) * x
        self.r[start:start + len(x)] += gain * np.sin(a) * x

    def stereo(self):
        return np.stack([self.l, self.r])


def reverb_ir(seconds, rng, bright=6000.0):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    decay = np.exp(-6.9 * t / seconds)
    irs = []
    for ch in range(2):
        noise = fft_band(rng.standard_normal(n), 200, bright) * decay
        noise[: int(0.018 * SR)] = 0.0   # 사전 지연
        irs.append(noise / np.sqrt(np.sum(noise ** 2)))
    return np.stack(irs)


def convolve(x, ir):
    n = x.shape[1] + ir.shape[1]
    size = 1 << (n - 1).bit_length()
    out = np.zeros((2, x.shape[1]))
    for ch in range(2):
        y = np.fft.irfft(np.fft.rfft(x[ch], size) * np.fft.rfft(ir[ch], size), size)
        out[ch] = y[: x.shape[1]]
    return out


def echo(x, delay_s, feedback=0.35, taps=4):
    """핑퐁 딜레이."""
    out = x.copy()
    d = int(delay_s * SR)
    for k in range(1, taps + 1):
        g = feedback ** k
        src = x[::-1] if k % 2 else x   # 좌우를 번갈아
        out[:, k * d:] += g * src[:, : x.shape[1] - k * d]
    return out


# ------------------------------------------------------------------ song rendering

class Song:
    def __init__(self, name, bpm, bars, seed, swing=0.0, tail=4.0):
        self.name = name
        self.bpm = bpm
        self.bars = bars
        self.beat = 60.0 / bpm
        self.loop_len = int(round(bars * 4 * self.beat * SR))
        self.n = self.loop_len + int(tail * SR)
        self.rng = np.random.default_rng(seed)
        self.swing = swing
        self.buses = {}

    def bus(self, name):
        if name not in self.buses:
            self.buses[name] = Bus(self.n)
        return self.buses[name]

    def when(self, bar, beat):
        """마디·박 → 샘플. 스윙은 8분 뒷박(.5)을 늦춘다."""
        frac = beat - np.floor(beat)
        if self.swing and abs(frac - 0.5) < 1e-6:
            beat = np.floor(beat) + 0.5 + self.swing
        jitter = self.rng.normal(0, 0.003) if self.swing else self.rng.normal(0, 0.0015)
        return max(0, int(round(((bar * 4 + beat) * self.beat + jitter) * SR)))

    def note(self, bus, inst, bar, beat, beats, midi, vel=0.8, pan=0.0):
        v = vel * (1.0 + self.rng.normal(0, 0.06))
        x = INSTRUMENTS[inst](mtof(midi), beats * self.beat, v)
        self.bus(bus).add(x, self.when(bar, beat), pan)

    def hit(self, drums, name, bar, beat, vel=0.8, pan=0.0):
        self.bus("drums").add(drums[name] * vel * (1.0 + self.rng.normal(0, 0.05)), self.when(bar, beat), pan)


def chord_hits(song, bus, inst, bar, pattern, voicing, vel, spread=0.35):
    for beat, beats in pattern:
        for i, m in enumerate(voicing):
            pan = -spread + 2 * spread * i / max(1, len(voicing) - 1)
            song.note(bus, inst, bar, beat, beats, m, vel, pan)


def play_line(song, bus, inst, bar0, line, vel, pan=0.0, transpose=0):
    """line: [(bar_offset, beat, beats, midi), ...]"""
    for bo, beat, beats, m in line:
        song.note(bus, inst, bar0 + bo, beat, beats, m + transpose, vel, pan)


# ------------------------------------------------------------------ track 1: battle

def compose_battle():
    s = Song("battle_land", bpm=140, bars=32, seed=535)
    drums = make_drums(s.rng, soft=False)
    # (EP 보이싱, 베이스 근음, 3박째에 바뀌는 두 번째 코드)
    A = [([66, 69, 73, 76], 38, None),                 # Dmaj9
         ([62, 66, 69, 73], 35, None),                 # Bm9
         ([59, 62, 66, 69], 43, None),                 # Gmaj9
         ([62, 64, 67, 69], 45, ([61, 64, 67, 69], 45))]  # A7sus4 → A7
    B = [([62, 66, 67, 71], 40, None),                 # Em9
         ([61, 64, 69, 73], 42, None),                 # F#m7
         ([59, 62, 66, 69], 43, None),                 # Gmaj9
         ([61, 66, 67, 71], 45, None),                 # A13
         ([62, 66, 69, 73], 35, None),                 # Bm9
         ([62, 66, 68, 71], 40, None),                 # E9
         ([59, 62, 66, 69], 43, None),                 # Gmaj9
         ([61, 64, 67, 69], 45, None)]                 # A7
    prog = A * 4 + B * 2
    comp = [(0, 0.5), (0.75, 0.25), (1.5, 0.5), (2.5, 0.25), (3.25, 0.5)]
    for bar, (voice, root, change) in enumerate(prog):
        section_b = bar >= 16
        # EP comping (밝기 낮게, 가운데 넓게)
        first = [p for p in comp if p[0] < 2] if change else comp
        chord_hits(s, "keys", "ep", bar, first, voice, 0.16, 0.45)
        if change:
            chord_hits(s, "keys", "ep", bar, [(2, 0.5), (3.25, 0.5)], change[0], 0.16, 0.45)
        # 패드 (B 구간만, 얇게)
        if section_b:
            for m in voice[:3]:
                s.note("pad", "pad", bar, 0, 4, m, 0.05)
        # 16분 펑크 베이스
        nxt = prog[(bar + 1) % len(prog)][1]
        r = root
        line = [(0, r, 0.5), (0.75, r, 0.25), (1.0, r + 12, 0.25), (1.5, r, 0.5), (2.25, r + 7, 0.25),
                (2.5, r, 0.25), (3.0, r + 12, 0.25), (3.5, nxt - 1 if nxt != r else r + 10, 0.5)]
        if change:
            line[4] = (2.25, change[1] + 7, 0.25)
        for beat, m, beats in line:
            s.note("bass", "bass_funk", bar, beat, beats, m, 0.55)
        # 브라스 스탭 (B 구간: 밀어 치는 엇박)
        if section_b:
            top = [m + 12 for m in voice[1:]]
            chord_hits(s, "brass", "brass", bar, [(1.5, 0.25), (3.5, 0.5)] if bar % 2 else [(0, 0.5), (2.5, 0.25)], top, 0.10, 0.5)
        # 드럼
        fill = bar % 8 == 7
        for beat in (0, 2.5):
            s.hit(drums, "kick", bar, beat, 0.5)
        if bar % 2 == 1:
            s.hit(drums, "kick", bar, 1.75, 0.35)
        for beat in (1, 3):
            s.hit(drums, "snare", bar, beat, 0.62, 0.05)
        for k in range(8):
            if fill and k >= 6:
                continue
            s.hit(drums, "hat", bar, k * 0.5, 0.36 if k % 2 == 0 else 0.26, 0.3)
            s.hit(drums, "hat", bar, k * 0.5 + 0.25, 0.14, 0.3)
        s.hit(drums, "ohat", bar, 3.5, 0.2, 0.35)
        if fill:
            for k, beat in enumerate((3.0, 3.25, 3.5, 3.75)):
                s.hit(drums, "snare", bar, beat, 0.3 + 0.1 * k, -0.1 + 0.07 * k)
        if bar % 8 == 0:
            s.hit(drums, "crash", bar, 0, 0.35, -0.4)

    # 리드 멜로디 (A 8마디, 자작) — 두 번째 A 는 3도 아래 화음을 얇게 더한다.
    melody = [
        (0, 0, .5, 69), (0, .5, .5, 74), (0, 1.5, .5, 73), (0, 2, .5, 74), (0, 2.5, 1, 78), (0, 3.5, .5, 76),
        (1, 0, .75, 74), (1, .75, .75, 71), (1, 1.5, .5, 69), (1, 2, 1.5, 66), (1, 3.5, .5, 69),
        (2, 0, .5, 71), (2, .5, .5, 74), (2, 1, .5, 78), (2, 1.5, .5, 76), (2, 2, .5, 74), (2, 2.5, 1, 71), (2, 3.5, .5, 74),
        (3, 0, .75, 73), (3, .75, .75, 76), (3, 1.5, .5, 79), (3, 2, .5, 78), (3, 2.5, 1.5, 76),
        (4, 0, .5, 69), (4, .5, .5, 74), (4, 1.5, .5, 73), (4, 2, .5, 74), (4, 2.5, 1, 81), (4, 3.5, .5, 78),
        (5, 0, .5, 76), (5, .5, .5, 78), (5, 1, .5, 74), (5, 1.5, .5, 71), (5, 2, .5, 73), (5, 2.5, .5, 74), (5, 3, 1, 76),
        (6, 0, .75, 78), (6, .75, .75, 74), (6, 1.5, .5, 71), (6, 2, .5, 67), (6, 2.5, .5, 71), (6, 3, .5, 74), (6, 3.5, .5, 73),
        (7, 0, 1, 76), (7, 1, .5, 73), (7, 1.5, 1.5, 69),
    ]
    play_line(s, "lead", "lead", 0, melody, 0.2, 0.08)
    play_line(s, "lead", "lead", 8, melody, 0.2, 0.08)
    harmony = [(bo, b, d, m - 4 if m % 12 in (2, 6, 9) else m - 3) for bo, b, d, m in melody]
    play_line(s, "lead", "lead", 8, harmony, 0.09, -0.25)
    # B 후반(25~32마디): 브라스와 주고받는 대선율
    counter = [
        (0, 0, 1.5, 71), (0, 2, 1, 74), (1, 0, 2, 73), (1, 2.5, 1, 69), (2, 0, 1.5, 71), (2, 2, 1, 74),
        (3, 0, 2, 76), (3, 2.5, .5, 73), (3, 3, 1, 76),
        (4, 0, 1.5, 78), (4, 2, 1, 74), (5, 0, 2, 76), (5, 2.5, 1, 80), (6, 0, 1.5, 78), (6, 2, 1, 74),
        (7, 0, 1, 73), (7, 1, 1, 76), (7, 2, 2, 69),
    ]
    play_line(s, "lead", "lead", 24, counter, 0.17, 0.08)
    master = mix(s, sidechain_kicks=[(bar, b) for bar in range(32) for b in (0, 2.5)],
                 levels={"drums": 0.8, "bass": 0.36, "keys": 1.5, "pad": 0.8, "brass": 1.3, "lead": 1.25},
                 reverb={"keys": 0.22, "pad": 0.4, "brass": 0.2, "lead": 0.28, "drums": 0.06},
                 room=1.3, lead_echo=0.75 * s.beat)
    return s, master


# ------------------------------------------------------------------ track 2: lobby

def compose_lobby():
    s = Song("lobby_theme", bpm=108, bars=32, seed=308, swing=0.12)
    drums = make_drums(s.rng, soft=True)
    # (반주 보이싱, 베이스 근음, 3박째 두 번째 코드(보이싱, 근음))
    A = [([57, 60, 64], 41, None),                          # Fmaj7 (A C E)
         ([55, 60, 64], 45, ([54, 57, 60], 50)),            # Am7 → D7
         ([58, 62, 65], 43, None),                          # Gm7
         ([58, 60, 65], 48, ([58, 60, 64], 48)),            # C7sus → C7
         ([57, 60, 64], 41, None),                          # Fmaj7
         ([55, 61, 64], 45, ([57, 60, 65], 50)),            # A7 → Dm7
         ([58, 62, 65], 43, ([58, 60, 64], 48)),            # Gm7 → C7
         ([57, 62, 65], 41, None)]                          # F6
    B = [([57, 62, 65], 46, None),                          # Bbmaj7
         ([55, 60, 64], 45, None),                          # Am7
         ([58, 62, 65], 43, None),                          # Gm7
         ([57, 60, 64], 41, None),                          # Fmaj7
         ([57, 62, 65], 46, None),                          # Bbmaj7
         ([58, 62, 64], 40, ([55, 61, 64], 45)),            # Em7b5 → A7
         ([57, 60, 65], 50, ([53, 59, 62], 43)),            # Dm7 → G7
         ([58, 62, 65], 43, ([58, 60, 64], 48))]            # Gm7 → C7 (되돌이)
    prog = A + B + A + B
    for bar, (voice, root, change) in enumerate(prog):
        second = bar >= 16
        # 움파: 튜바 1·3박, 피치카토 화음 2·4박(스윙 엇박 하나 더)
        r2 = change[1] if change else root
        s.note("bass", "tuba", bar, 0, 0.8, root - 12 if root > 44 else root, 0.5)
        s.note("bass", "tuba", bar, 2, 0.8, (r2 - 12 if r2 > 44 else r2) + (7 if not change else 0), 0.42)
        v2 = change[0] if change else voice
        for beat, vv in ((1, voice), (3, v2)):
            for i, m in enumerate(vv):
                s.note("keys", "pizz", bar, beat, 0.4, m + 12, 0.11, -0.3 + 0.3 * i)
        s.note("keys", "pizz", bar, 3.5, 0.3, v2[-1] + 12, 0.07, 0.35)
        # 두 번째 바퀴: 마림바 8분 분산화음
        if second:
            arp = voice + [voice[1] + 12]
            for k in range(4):
                s.note("keys", "marimba", bar, k * 0.5, 0.5, arp[k] + 12, 0.1, 0.4)
            for k in range(4):
                s.note("keys", "marimba", bar, 2 + k * 0.5, 0.5, (v2 + [v2[1] + 12])[k] + 12, 0.1, 0.4)
        # 얇은 현악 패드
        for m in voice:
            s.note("pad", "pad", bar, 0, 4, m, 0.035)
        # 드럼: 부드러운 킥 1·3, 박수 2·4, 셰이커 8분
        s.hit(drums, "kick", bar, 0, 0.4)
        s.hit(drums, "kick", bar, 2, 0.3)
        s.hit(drums, "clap", bar, 1, 0.3, 0.1)
        s.hit(drums, "clap", bar, 3, 0.3, 0.1)
        for k in range(8):
            s.hit(drums, "shaker", bar, k * 0.5, 0.28 if k % 2 == 0 else 0.18, 0.35)
        if bar % 4 == 3:
            s.hit(drums, "rim", bar, 3.5, 0.25, -0.3)
            s.hit(drums, "rim", bar, 3.75, 0.2, -0.3)
        if bar % 16 == 0:
            s.hit(drums, "crash", bar, 0, 0.18, 0.4)

    # A 멜로디(마림바, 자작) — 두 번째 바퀴는 글로켄이 한 옥타브 위를 얇게 겹친다.
    melody_a = [
        (0, 0, .5, 72), (0, .5, .5, 69), (0, 1, .5, 72), (0, 1.5, 1, 77), (0, 3, .5, 76), (0, 3.5, .5, 74),
        (1, 0, 1, 72), (1, 1, .5, 69), (1, 1.5, .5, 67), (1, 2, .5, 66), (1, 2.5, .5, 69), (1, 3, 1, 72),
        (2, 0, .5, 70), (2, .5, .5, 74), (2, 1, .5, 77), (2, 1.5, .5, 74), (2, 2, 1, 70), (2, 3, .5, 69), (2, 3.5, .5, 70),
        (3, 0, 1.5, 72), (3, 1.5, .5, 70), (3, 2, .5, 67), (3, 2.5, .5, 64), (3, 3, 1, 67),
        (4, 0, .5, 72), (4, .5, .5, 69), (4, 1, .5, 72), (4, 1.5, 1, 81), (4, 2.5, .5, 79), (4, 3, .5, 77), (4, 3.5, .5, 76),
        (5, 0, 1, 76), (5, 1, .5, 73), (5, 1.5, .5, 69), (5, 2, 1, 74), (5, 3, 1, 77),
        (6, 0, .5, 74), (6, .5, .5, 70), (6, 1, .5, 67), (6, 1.5, .5, 70), (6, 2, .5, 76), (6, 2.5, .5, 72), (6, 3, .5, 70), (6, 3.5, .5, 67),
        (7, 0, 1.5, 69), (7, 2, 1, 65),
    ]
    melody_b = [
        (0, 0, 2, 74), (0, 2, 1.5, 77), (0, 3.5, .5, 74),
        (1, 0, 2, 76), (1, 2, 1, 72), (1, 3, 1, 69),
        (2, 0, 1.5, 74), (2, 1.5, .5, 70), (2, 2, 1, 67), (2, 3, 1, 70),
        (3, 0, 3, 69), (3, 3, 1, 72),
        (4, 0, 1, 74), (4, 1, 1, 77), (4, 2, 2, 81),
        (5, 0, 1, 79), (5, 1, 1, 76), (5, 2, 1, 73), (5, 3, 1, 76),
        (6, 0, 1, 77), (6, 1, 1, 74), (6, 2, 1, 71), (6, 3, 1, 74),
        (7, 0, 1, 70), (7, 1, .5, 69), (7, 1.5, .5, 67), (7, 2, 1, 64), (7, 3, 1, 67),
    ]
    play_line(s, "lead", "marimba", 0, melody_a, 0.3, 0.1)
    play_line(s, "lead", "flute", 8, melody_b, 0.13, 0.1)
    play_line(s, "lead", "marimba", 16, melody_a, 0.28, 0.1)
    play_line(s, "lead", "glock", 16, melody_a, 0.07, -0.3, transpose=12)
    play_line(s, "lead", "flute", 24, melody_b, 0.12, 0.1)
    play_line(s, "lead", "marimba", 24, melody_b, 0.12, -0.2, transpose=-12)
    master = mix(s, sidechain_kicks=None,
                 levels={"drums": 0.8, "bass": 0.4, "keys": 1.3, "pad": 0.7, "lead": 1.25},
                 reverb={"keys": 0.3, "pad": 0.45, "lead": 0.35, "drums": 0.1, "bass": 0.05},
                 room=1.7, lead_echo=0.75 * s.beat)
    return s, master


# ------------------------------------------------------------------ master

def mix(s, sidechain_kicks, levels, reverb, room, lead_echo):
    out = np.zeros((2, s.n))
    send = np.zeros((2, s.n))
    duck = np.ones(s.n)
    if sidechain_kicks:
        t = np.arange(int(0.25 * SR)) / SR
        shape = 1.0 - 0.3 * np.exp(-t / 0.08)
        for bar, beat in sidechain_kicks:
            a = s.when(bar, beat)
            b = min(s.n, a + len(shape))
            duck[a:b] = np.minimum(duck[a:b], shape[: b - a])
    for name, bus in s.buses.items():
        x = bus.stereo() * levels.get(name, 0.8)
        if name == "lead" and lead_echo:
            x = echo(x, lead_echo, 0.28, 3)
        if name in ("keys", "pad", "brass"):
            x = x * duck
        out += x
        send += x * reverb.get(name, 0.0)
    out += convolve(send, reverb_ir(room, np.random.default_rng(11)))
    # 이음새: 곡 끝을 넘친 꼬리(잔향·release)를 처음에 더해 반복을 매끄럽게 한다.
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
    x = stereo / (np.max(np.abs(stereo)) + 1e-9) * 0.5
    probe = os.path.join(tmpdir, "probe.wav")
    for _ in range(3):
        write_wav(probe, x)
        gain = 10 ** ((target_lufs - loudness(probe)) / 20)
        x = x * gain
        # 부드러운 제한: −1 dBFS 를 넘는 부분만 tanh 로 눌러 준다.
        ceiling = 10 ** (-1.2 / 20)
        over = np.abs(x) > ceiling * 0.8
        knee = ceiling * 0.8
        x = np.where(over, np.sign(x) * (knee + (ceiling - knee) * np.tanh((np.abs(x) - knee) / (ceiling - knee))), x)
    return x


def encode(stereo, name, tmpdir):
    wav = os.path.join(tmpdir, name + ".wav")
    write_wav(wav, stereo)
    out = os.path.join(OUT_DIR, name + ".ogg")
    subprocess.run([ffmpeg_exe(), "-y", "-hide_banner", "-loglevel", "error", "-i", wav, "-map_metadata", "-1",
                    "-c:a", "libvorbis", "-q:a", "5", "-ar", str(SR), "-ac", "2", out], check=True)
    return out


TRACKS = {"battle": (compose_battle, -17.0), "lobby": (compose_lobby, -20.0)}


def main(argv):
    names = argv or list(TRACKS)
    with tempfile.TemporaryDirectory() as tmp:
        for key in names:
            compose, target = TRACKS[key]
            song, stereo = compose()
            stereo = master_to(stereo, target, tmp)
            out = encode(stereo, song.name, tmp)
            print(json.dumps({"track": key, "file": os.path.relpath(out, ROOT), "bpm": song.bpm,
                              "bars": song.bars, "seconds": round(song.loop_len / SR, 3),
                              "peak_db": round(20 * np.log10(np.max(np.abs(stereo))), 2)}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
