"""전투 프레임 원본 플레이트 → 게임용 투명 PNG (#533).

`tools/prepare_animation_frames.gd` 와 **같은 규칙**을 numpy 로 빠르게 한다. 새 원본 플레이트는
1024x1536 에 자홍색 배경이 고르지 않아(R/B 233~252, G 3~37) GDScript 의 픽셀 단위 처리가
168장에 수 시간 걸린다.

규칙 (art/battle-animation/README.md):
  1. 자홍색 배경 제거. 경계의 반투명 픽셀은 자홍색을 걷어 낸 색으로 되돌린다(분홍 테두리 방지).
     반투명은 배경 바로 옆에서만 — 안쪽의 보라·자주 장식은 불투명으로 지킨다.
  2. 캔버스 비율 유지 — 원본 전체를 칸 크기로 한 번에 줄인다. 컷마다 키우지 않는다
     (쓰러진 몸을 전체 높이로 확대하지 않는다).
  3. 가장 낮은 점을 캔버스 밑변에 붙인다(발 기준선). 생성 원본은 쓰러짐 컷이 최대 170px 떠 있다.
  4. 대기 1~3 컷은 idle_0 의 실루엣 높이 +2/+4/+2px 과 발 중심에 맞춘다.
  5. 공격 궤적(분홍·보라 곡선)은 자홍색과 섞여 배경 제거 뒤 보라로 남으므로 옅은 흰색으로 바꾼다.
     캐릭터 둘레의 얇은 경계는 건드리지 않는다 — 굵은 획만 궤적으로 본다.

사용:
  python tools/prepare_animation_frames.py art/battle-animation/manifest.json [--unit=harang]

manifest 항목: {unit, animation, frame, source, output, width, height, [offset_x]}
(source/output 은 res:// 경로)
"""

import json
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 자홍색 정도 = min(R, B) - G (0..1). 배경은 0.77 이상, 캐릭터 색은 0.2 미만이다.
FG_EXCESS = 0.24     # 이하: 완전 불투명
BG_EXCESS = 0.72     # 이상: 완전 투명 (노이즈 낀 배경의 최솟값 0.77 보다 아래)
ARC_EXCESS = 0.20    # 궤적 후보: 이보다 자홍색 쪽인 픽셀
ARC_THICK = 7        # 궤적 판정 침식 크기(px, 원본 해상도). 경계 테두리는 이보다 얇다.
ARC_ANIMS = ("attack",)
BG_SEED = 0.55      # 배경 시작점으로 볼 자홍색 정도. 머리카락 틈의 작은 배경(노이즈로 0.72 아래)도 잡되,
                     # 아린 번개 문양(0.44)보다는 높게.
EDGE_REACH = 9       # 배경과 섞인 반투명 경계로 볼 수 있는 폭(px, 원본 해상도, 필터 크기). 그 안쪽은 불투명.
ALPHA_CUT = 0.04     # 이 아래 알파는 투명으로 정리한다 (gd 도구와 같다)


def res_path(p):
    return os.path.join(ROOT, p[len("res://"):]) if p.startswith("res://") else p


def excess_of(rgb):
    return np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1]


def key_out(rgb, whiten_arcs):
    """RGB(0..1) → RGBA(0..1). 알파는 자홍색 정도로, 색은 자홍색을 걷어 낸 값으로."""
    ex = excess_of(rgb)
    alpha = np.clip((BG_EXCESS - ex) / (BG_EXCESS - FG_EXCESS), 0.0, 1.0)
    # 색만으로는 "자홍색과 섞인 경계"와 "원래 보라·자주로 그린 장식"(아린 석궁의 번개 문양
    # 216,104,240)을 구분할 수 없다. 섞임은 배경 바로 옆에서만 생기므로, 배경에서 떨어진 픽셀은
    # 불투명으로 둔다.
    bg = Image.fromarray(((ex >= BG_SEED) * 255).astype(np.uint8))
    near_bg = np.asarray(bg.filter(ImageFilter.MaxFilter(EDGE_REACH))) > 0
    alpha = np.where(near_bg, alpha, 1.0)
    magenta = np.array([1.0, 0.0, 1.0])
    safe = np.maximum(alpha, 1e-3)[..., None]
    color = np.clip((rgb - (1.0 - alpha)[..., None] * magenta) / safe, 0.0, 1.0)
    color = np.where((alpha >= 1.0)[..., None], rgb, color)
    if whiten_arcs:
        arc = arc_mask(ex)
        if arc.any():
            # 궤적은 흰 빛: 원래의 자홍색 섞임 정도를 투명도로 남긴다(중심은 진하고 가장자리는 옅게).
            strength = np.clip((BG_EXCESS - ex) / (BG_EXCESS - ARC_EXCESS), 0.0, 1.0)
            alpha = np.where(arc, np.maximum(strength * 0.85, 0.0), alpha)
            color = np.where(arc[..., None], np.array([1.0, 1.0, 1.0]), color)
    return np.dstack([color, alpha])


def arc_mask(ex):
    """굵은 분홍·보라 획. 얇은 경계 테두리는 침식에서 사라지고, 굵은 획만 남아 다시 불어난다."""
    cand = (ex > ARC_EXCESS) & (ex < BG_EXCESS + 0.05)
    img = Image.fromarray((cand * 255).astype(np.uint8))
    core = img.filter(ImageFilter.MinFilter(ARC_THICK))
    grown = core.filter(ImageFilter.MaxFilter(ARC_THICK + 4))
    return (np.asarray(grown) > 0) & cand


def resize_rgba(rgba, size):
    """알파를 곱한 채로 줄여 테두리가 어두워지지 않게 한다."""
    pre = rgba.copy()
    pre[..., :3] *= pre[..., 3:4]
    chans = []
    for c in range(4):
        im = Image.fromarray(pre[..., c].astype(np.float32), mode="F")
        chans.append(np.asarray(im.resize(size, Image.LANCZOS)))
    out = np.clip(np.dstack(chans), 0.0, 1.0)
    a = out[..., 3:4]
    out[..., :3] = np.where(a > 1e-4, out[..., :3] / np.maximum(a, 1e-4), 0.0)
    out[..., :3] = np.clip(out[..., :3], 0.0, 1.0)
    return out


def used_rect(rgba):
    ys, xs = np.where(rgba[..., 3] >= ALPHA_CUT)
    if ys.size == 0:
        return None
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def foot_center(rgba):
    """아래 20줄의 알파 가중 가로 중심 (gd 도구의 _foot_center 와 같다)."""
    h = rgba.shape[0]
    band = rgba[max(0, h - 20):, :, 3]
    w = band.sum()
    if w <= 0:
        return rgba.shape[1] * 0.5
    return float((band * np.arange(rgba.shape[1])[None, :]).sum() / w)


def place(canvas_w, canvas_h, img, x):
    out = np.zeros((canvas_h, canvas_w, 4), dtype=np.float64)
    r = used_rect(img)
    if r is None:
        return out
    fig = img[r[1]:r[3], :, :]            # 세로만 잘라 밑변에 붙인다(가로 위치는 유지)
    top = canvas_h - fig.shape[0]
    src_y0 = max(0, -top)
    top = max(0, top)
    x0 = max(0, x)
    sx0 = x0 - x
    w = min(fig.shape[1] - sx0, canvas_w - x0)
    out[top:top + fig.shape[0] - src_y0, x0:x0 + w] = fig[src_y0:, sx0:sx0 + w]
    return out


def prepare(job, idle_base):
    canvas_w, canvas_h = int(job["width"]), int(job["height"])
    src = np.asarray(Image.open(res_path(job["source"])).convert("RGB")).astype(np.float64) / 255.0
    rgba = key_out(src, job["animation"] in ARC_ANIMS)
    factor = min(canvas_w / src.shape[1], canvas_h / src.shape[0])
    size = (round(src.shape[1] * factor), round(src.shape[0] * factor))
    small = resize_rgba(rgba, size)
    small[small[..., 3] < ALPHA_CUT] = 0.0
    out = place(canvas_w, canvas_h, small, (canvas_w - size[0]) // 2 + int(job.get("offset_x", 0)))
    if job["animation"] == "idle" and int(job["frame"]) > 0 and idle_base is not None:
        # 대기는 서 있는 실루엣이 고정이다: idle_0 높이 +2/+4/+2 와 발 중심에 맞춘다.
        base_r = used_rect(idle_base)
        target_h = (base_r[3] - base_r[1]) + (4 if int(job["frame"]) == 2 else 2)
        r = used_rect(out)
        fig = out[r[1]:r[3], r[0]:r[2]]
        scale = min(target_h / fig.shape[0], (canvas_w - 2) / fig.shape[1])
        fig = resize_rgba(fig, (round(fig.shape[1] * scale), round(fig.shape[0] * scale)))
        fx = round(foot_center(idle_base) - foot_center(fig))
        fx = min(max(fx, 0), canvas_w - fig.shape[1])
        padded = np.zeros((fig.shape[0], canvas_w, 4))
        padded[:, fx:fx + fig.shape[1]] = fig
        out = place(canvas_w, canvas_h, padded, 0)
    return out


def save(rgba, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray((np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(path, optimize=True)


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    jobs = json.load(open(res_path(argv[0]), encoding="utf-8"))
    only = next((a.split("=", 1)[1] for a in argv[1:] if a.startswith("--unit=")), "")
    # idle_0 을 먼저 만든다: 나머지 대기 컷이 그것에 맞춘다.
    jobs.sort(key=lambda j: (j["unit"], 0 if (j["animation"] == "idle" and int(j["frame"]) == 0) else 1))
    base = {}
    for job in jobs:
        if only and job["unit"] != only:
            continue
        img = prepare(job, base.get(job["unit"]))
        if job["animation"] == "idle" and int(job["frame"]) == 0:
            base[job["unit"]] = img
        save(img, res_path(job["output"]))
        r = used_rect(img)
        print(job["unit"], job["animation"], job["frame"], r)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
