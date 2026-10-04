#!/usr/bin/env python3
"""오의 LD 공격 애니메이션 → 게임용 24장 프레임 시퀀스 (#549).

#546 의 "알파를 옆에 붙인 Theora 영상"을 대신한다. 오의 한 번은 **독립 원화 24장**이고,
게임은 그것을 `SpriteFrames`(장마다 길이가 다른 리미티드 애니메이션)로 재생한다.

입력 (캐릭터 하나):
  - 24장 PNG 폴더 또는 zip — 이미지 생성 원화. 투명 배경, 또는 자홍(#FF00FF)·초록(#00FF00) 단색 배경.
    파일 이름 순서가 재생 순서다(00.png ~ 23.png 권장).
  - 24fps 클립 — 72장 PNG 폴더·zip, 단색 배경 .mp4/.webm(영상 생성), #546 의 알파 붙인 .ogv.
    타이밍표의 각 장 시작 시점을 뽑는다.

출력:
  assets/sprites/characters/cutins/ult/<id>/<id>_ult_00.webp ... _23.webp
      모든 장을 **같은 잘라내기 상자**(24장 합집합)로 자르고 같은 비율로 줄인다 — 장마다 따로 자르면
      인물이 장마다 다른 크기로 보인다.
  assets/sprites/characters/cutins/ult/<id>/<id>_ult.tres
      SpriteFrames. 애니메이션 "ult", 24fps, 장마다 길이(duration = 1/24초 단위).
      metadata/strike_frame — 공격이 정점에 닿는 장(기술명 타이포가 이 장에서 박힌다)
      metadata/final_rect   — 마지막 장(결정 포즈)의 인물 상자(px). 짧게 모드가 이만큼만 잘라 쓴다.

타이밍표(선택): art/ultimate-ld/timing/<id>.json  {"durations": [24개, 1/24초 단위], "strike_frame": n}
없으면 DEFAULT_DURATIONS / DEFAULT_STRIKE 를 쓴다.

규칙:
  - 발 기준선: 장마다 가장 낮은 점을 24장 중 가장 낮은 기준선에 맞춘다(생성 원화는 장마다 몇십 px 씩
    떠 있다). 점프처럼 일부러 뜬 동작이면 --no-ground 로 끈다.
  - 크기는 장마다 맞추지 않는다. 몸을 낮추거나 무기를 뻗는 것이 동작이라, 높이로 맞추면 동작이 망가진다.
    원화에 크기 편차가 있으면 원화를 다시 뽑는다(프롬프트: docs/ultimate-ld-animation-prompts.md).

사용:
  python tools/build_ultimate_frames.py <id> <원화 폴더|zip|ogv> [--no-ground]
  godot --headless --path . --editor --import --quit
필요: numpy, Pillow (ogv 입력이면 opencv-python)
"""

import io
import json
import os
import sys
import zipfile

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "sprites", "characters", "cutins", "ult")
TIMING_DIR = os.path.join(ROOT, "art", "ultimate-ld", "timing")

FRAME_COUNT = 24
FPS = 24
# 장마다 길이(1/24초). 합 72 = 1배속 3초.
#   0~7   준비·예비 동작      3씩(8fps) — 1.00초
#   8~15  최대 젖힘·공격·임팩트 2씩(12fps) — 0.67초. 공격 장은 빠르게 넘겨야 힘이 실린다. 11 = 정점
#   16~21 여운                 3씩 — 0.75초
#   22    결정 포즈 들어가기    4
#   23    결정 포즈 홀드       10 — 0.42초
DEFAULT_DURATIONS = [3] * 8 + [2] * 8 + [3] * 6 + [4, 10]
DEFAULT_STRIKE = 11

# 잘라낸 시퀀스의 최대 높이(px). 1080p 에서 인물이 화면 높이의 약 1.2배로 서므로 이 정도면 충분하고,
# 24장 × 캐릭터 6명이 VRAM(압축, 1B/px) 에 무리가 없다.
MAX_H = 1152
PAD = 24
WEBP_QUALITY = 92
ALPHA_CUT = 8          # 이 아래 알파는 인물로 보지 않는다(0..255)

# 단색 배경 제거 — tools/prepare_animation_frames.py 와 같은 규칙(배경색 정도 = 배경 채널 - 나머지)
FG_EXCESS = 0.24
BG_EXCESS = 0.72
BG_SEED = 0.55
EDGE_REACH = 9


# ===== 읽기 =====

def _sorted_pngs(names):
    return sorted(n for n in names if n.lower().endswith(".png"))


def read_frames(src):
    """RGBA uint8 배열 목록."""
    if src.lower().endswith(".ogv"):
        return read_packed_ogv(src)
    if src.lower().endswith((".mp4", ".webm", ".mov")):
        return read_keyed_video(src)
    if src.lower().endswith(".zip"):
        with zipfile.ZipFile(src) as z:
            return [to_rgba(Image.open(io.BytesIO(z.read(n)))) for n in _sorted_pngs(z.namelist())]
    return [to_rgba(Image.open(os.path.join(src, n))) for n in _sorted_pngs(os.listdir(src))]


def read_packed_ogv(path):
    """#546 형식: 왼쪽 절반 = 색, 오른쪽 절반 = 알파."""
    import cv2
    cap = cv2.VideoCapture(path)
    out = []
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        half = rgb.shape[1] // 2
        out.append(np.dstack([rgb[:, :half], rgb[:, half:half * 2, 0]]))
    return out


def read_keyed_video(path):
    """영상 생성 도구의 단색 배경 클립(초록·자홍). 장마다 배경을 뺀다."""
    import cv2
    cap = cv2.VideoCapture(path)
    out = []
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        out.append(to_rgba(Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))))
    return out


def to_rgba(im):
    if im.mode == "RGBA":
        rgba = np.asarray(im)
        corners = rgba[[0, 0, -1, -1], [0, -1, 0, -1], 3]
        if corners.max() < 16:
            return rgba.copy()          # 진짜 투명 배경
        im = im.convert("RGB")
    rgb = np.asarray(im.convert("RGB")).astype(np.float64) / 255.0
    corner = rgb[[0, 0, -1, -1], [0, -1, 0, -1]].mean(axis=0)
    if corner[1] > 0.6 and corner[0] < 0.4 and corner[2] < 0.4:
        key = "green"
    elif corner[1] < 0.4 and corner[0] > 0.6 and corner[2] > 0.6:
        key = "magenta"
    else:
        raise SystemExit("배경을 알 수 없다(투명·자홍·초록만 된다): 모서리 색 %s" % (corner * 255).round())
    return (key_out(rgb, key) * 255 + 0.5).astype(np.uint8)


def key_out(rgb, key):
    if key == "magenta":
        ex = np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1]
        key_rgb = np.array([1.0, 0.0, 1.0])
    else:
        ex = rgb[..., 1] - np.maximum(rgb[..., 0], rgb[..., 2])
        key_rgb = np.array([0.0, 1.0, 0.0])
    alpha = np.clip((BG_EXCESS - ex) / (BG_EXCESS - FG_EXCESS), 0.0, 1.0)
    # 섞임은 배경 바로 옆에서만 생긴다 — 안쪽의 배경색 비슷한 장식은 불투명으로 지킨다.
    bg = Image.fromarray(((ex >= BG_SEED) * 255).astype(np.uint8))
    near_bg = np.asarray(bg.filter(ImageFilter.MaxFilter(EDGE_REACH))) > 0
    alpha = np.where(near_bg, alpha, 1.0)
    safe = np.maximum(alpha, 1e-3)[..., None]
    color = np.clip((rgb - (1.0 - alpha)[..., None] * key_rgb) / safe, 0.0, 1.0)
    color = np.where((alpha >= 1.0)[..., None], rgb, color)
    return np.dstack([color, alpha])


# ===== 타이밍 =====

def load_timing(char_id):
    path = os.path.join(TIMING_DIR, char_id + ".json")
    durations, strike = list(DEFAULT_DURATIONS), DEFAULT_STRIKE
    if os.path.exists(path):
        data = json.load(open(path, encoding="utf-8"))
        durations = [int(d) for d in data.get("durations", durations)]
        strike = int(data.get("strike_frame", strike))
    if len(durations) != FRAME_COUNT or min(durations) < 1:
        raise SystemExit("타이밍표는 1 이상 정수 %d개여야 한다: %s" % (FRAME_COUNT, path))
    if not 0 <= strike < FRAME_COUNT:
        raise SystemExit("strike_frame 은 0..%d: %s" % (FRAME_COUNT - 1, path))
    return durations, strike


def pick_drawings(frames, durations):
    """24장이면 그대로, 24fps 클립이면 각 장이 시작하는 시점의 프레임을 뽑는다."""
    if len(frames) == FRAME_COUNT:
        return frames
    if len(frames) < FRAME_COUNT:
        raise SystemExit("원화가 %d장이다(%d장 필요)" % (len(frames), FRAME_COUNT))
    picked, t = [], 0
    for d in durations:
        picked.append(frames[min(t, len(frames) - 1)])
        t += d
    return picked


# ===== 맞추기·자르기 =====

def bbox(alpha):
    ys, xs = np.nonzero(alpha >= ALPHA_CUT)
    if ys.size == 0:
        return None
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def ground(frames):
    """장마다 가장 낮은 점을 공통 기준선(가장 낮은 장)에 맞춘다."""
    bottoms = [bbox(f[..., 3])[3] for f in frames]
    base = max(bottoms)
    out = []
    for f, b in zip(frames, bottoms):
        shift = base - b
        g = np.zeros_like(f)
        g[shift:] = f[:f.shape[0] - shift] if shift > 0 else f
        out.append(g)
    return out


def union_box(frames):
    boxes = [bbox(f[..., 3]) for f in frames]
    h, w = frames[0].shape[:2]
    x0 = max(0, min(b[0] for b in boxes) - PAD)
    y0 = max(0, min(b[1] for b in boxes) - PAD)
    x1 = min(w, max(b[2] for b in boxes) + PAD)
    y1 = min(h, max(b[3] for b in boxes) + PAD)
    return x0, y0, x1, y1


def resize_rgba(rgba, size):
    """알파를 곱한 채로 줄여 외곽이 어두워지지 않게 한다."""
    f = rgba.astype(np.float32) / 255.0
    f[..., :3] *= f[..., 3:4]
    chans = [np.asarray(Image.fromarray(f[..., c], mode="F").resize(size, Image.LANCZOS)) for c in range(4)]
    out = np.clip(np.dstack(chans), 0.0, 1.0)
    a = out[..., 3:4]
    out[..., :3] = np.where(a > 1e-4, np.clip(out[..., :3] / np.maximum(a, 1e-4), 0.0, 1.0), 0.0)
    return (out * 255 + 0.5).astype(np.uint8)


# ===== 쓰기 =====

def write_import(path):
    """VRAM 압축으로 가져온다 — 무압축이면 24장이 캐릭터당 수십 MB 다.
    이미 있으면 그대로 둔다(uid 가 바뀌지 않게)."""
    if os.path.exists(path + ".import"):
        return
    with open(path + ".import", "w", encoding="utf-8", newline="\n") as f:
        f.write('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[deps]\n\n')
        f.write('source_file="%s"\n\n' % res_path(path))
        f.write("[params]\n\ncompress/mode=2\nmipmaps/generate=false\n")


def res_path(path):
    return "res://" + os.path.relpath(path, ROOT).replace("\\", "/")


def write_tres(path, tex_paths, durations, strike, final_rect):
    lines = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (len(tex_paths) + 1), ""]
    for i, p in enumerate(tex_paths):
        lines.append('[ext_resource type="Texture2D" path="%s" id="f%02d"]' % (res_path(p), i))
    lines += ["", "[resource]", "animations = [{", '"frames": [']
    frames = ['{\n"duration": %.1f,\n"texture": ExtResource("f%02d")\n}' % (d, i) for i, d in enumerate(durations)]
    lines.append(", ".join(frames) + "],")
    lines += ['"loop": false,', '"name": &"ult",', '"speed": %.1f' % FPS, "}]"]
    lines.append("metadata/strike_frame = %d" % strike)
    lines.append("metadata/final_rect = Rect2(%d, %d, %d, %d)" % final_rect)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


def build(char_id, src, grounded=True):
    durations, strike = load_timing(char_id)
    frames = pick_drawings(read_frames(src), durations)
    if grounded:
        frames = ground(frames)
    x0, y0, x1, y1 = union_box(frames)
    scale = min(1.0, MAX_H / float(y1 - y0))
    size = (round((x1 - x0) * scale), round((y1 - y0) * scale))

    out_dir = os.path.join(OUT_DIR, char_id)
    os.makedirs(out_dir, exist_ok=True)
    keep = {"%s_ult_%02d.webp" % (char_id, i) for i in range(FRAME_COUNT)}
    for name in os.listdir(out_dir):
        if name.startswith(char_id + "_ult_") and name.split(".import")[0] not in keep:
            os.remove(os.path.join(out_dir, name))
    tex_paths, final = [], None
    for i, f in enumerate(frames):
        small = resize_rgba(f[y0:y1, x0:x1], size)
        small[small[..., 3] < 4] = 0
        p = os.path.join(out_dir, "%s_ult_%02d.webp" % (char_id, i))
        Image.fromarray(small, "RGBA").save(p, "WEBP", quality=WEBP_QUALITY, method=6)
        write_import(p)
        tex_paths.append(p)
        final = small
    fb = bbox(final[..., 3])
    final_rect = (fb[0], fb[1], fb[2] - fb[0], fb[3] - fb[1])
    write_tres(os.path.join(out_dir, char_id + "_ult.tres"), tex_paths, durations, strike, final_rect)
    total = sum(os.path.getsize(p) for p in tex_paths) / 1e6
    print("%s: %d장 %dx%d, %.2f초, 정점 %d장, %.1f MB" % (char_id, len(frames), size[0], size[1],
                                                       sum(durations) / FPS, strike, total))


def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    if len(args) != 2:
        print(__doc__)
        return 1
    build(args[0], args[1], grounded="--no-ground" not in argv)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
