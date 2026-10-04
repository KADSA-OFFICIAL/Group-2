#!/usr/bin/env python3
"""오의 LD 공격 애니메이션을 게임용 영상·정지 그림으로 변환한다 (#546).

입력: 캐릭터별 투명 PNG 시퀀스 zip (`<id>_transparent_frames.zip`, 1080x1920 RGBA 72장, 24fps).
출력:
  assets/video/ultimate/<id>.ogv
      **알파를 옆에 붙인 Theora 영상**(왼쪽 절반 = 색, 오른쪽 절반 = 알파 회색조).
      Theora 는 알파를 못 담고, 크로마키로 빼면 외곽에 배경색이 번진다. 알파를 따로 실어 두면
      게임의 셰이더(`UltimateCutin`)가 원본 그대로의 외곽을 되살린다.
  assets/sprites/characters/cutins/ult/char_<id>_ult.png
      마지막 프레임(결정 포즈)의 정지 그림. 짧게 모드와 영상이 없을 때 쓴다.

색 쪽 투명 영역은 근처 색으로 채운다 — 검게 두면 영상 압축(색차 4:2:0)이 외곽에 검은 테를 만든다.

사용:
  python tools/build_ultimate_videos.py <zip 폴더>
필요: numpy, Pillow, opencv-python, imageio-ffmpeg(ffmpeg + libtheora)
"""

import io
import os
import subprocess
import sys
import tempfile
import zipfile

import cv2
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VIDEO_DIR = os.path.join(ROOT, "assets", "video", "ultimate")
STILL_DIR = os.path.join(ROOT, "assets", "sprites", "characters", "cutins", "ult")
IDS = ["seola", "mina", "taehee", "harang", "arin", "gangji"]

# 영상 한쪽(색 또는 알파)의 크기. 원본 1080x1920 의 3/4 — 1080p 화면에서 컷인 인물이
# 화면 높이의 약 110% 로 서므로 이 정도면 원본(확대된 원화)과 구분되지 않는다.
HALF_W, HALF_H = 810, 1440
FPS = 24


def ffmpeg_exe() -> str:
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        return "ffmpeg"


def bleed_colors(rgba: np.ndarray) -> np.ndarray:
    """투명 영역의 RGB 를 가까운 불투명 색으로 번지게 채운다(정규화 블러를 넓혀 가며)."""
    rgb = rgba[:, :, :3].astype(np.float32)
    known = (rgba[:, :, 3] > 127).astype(np.float32)   # 색을 믿을 수 있는 픽셀
    out = rgb.copy()
    for k in (5, 11, 23, 47, 95):
        acc = cv2.blur(out * known[:, :, None], (k, k))
        w = cv2.blur(known, (k, k))
        filled = acc / np.maximum(w, 1e-4)[:, :, None]
        hole = (known < 0.5) & (w > 1e-3)
        out[hole] = filled[hole]
        known = np.maximum(known, hole.astype(np.float32))
    return np.clip(out, 0, 255).astype(np.uint8)


def packed_frame(rgba: np.ndarray) -> np.ndarray:
    small = cv2.resize(rgba, (HALF_W, HALF_H), interpolation=cv2.INTER_AREA)
    color = bleed_colors(small)
    alpha = np.repeat(small[:, :, 3:4], 3, axis=2)
    return np.concatenate([color, alpha], axis=1)


def still(rgba: np.ndarray) -> Image.Image:
    """결정 포즈 정지 그림: 원본 크기 그대로, 투명 여백만 고르게 남기고 자른다."""
    ys, xs = np.nonzero(rgba[:, :, 3] > 8)
    pad = 40
    x0, x1 = max(0, xs.min() - pad), min(rgba.shape[1], xs.max() + pad)
    y0, y1 = max(0, ys.min() - pad), min(rgba.shape[0], ys.max() + pad)
    return Image.fromarray(rgba[y0:y1, x0:x1])


def build(char_id: str, zip_path: str) -> None:
    with zipfile.ZipFile(zip_path) as z:
        names = sorted(n for n in z.namelist() if n.lower().endswith(".png"))
        frames = [np.array(Image.open(io.BytesIO(z.read(n))).convert("RGBA")) for n in names]
    with tempfile.TemporaryDirectory() as tmp:
        for i, f in enumerate(frames):
            cv2.imwrite(os.path.join(tmp, "%03d.png" % i), cv2.cvtColor(packed_frame(f), cv2.COLOR_RGB2BGR))
        out = os.path.join(VIDEO_DIR, char_id + ".ogv")
        subprocess.run([ffmpeg_exe(), "-y", "-hide_banner", "-loglevel", "error", "-framerate", str(FPS),
                        "-i", os.path.join(tmp, "%03d.png"), "-c:v", "libtheora", "-q:v", "8",
                        "-pix_fmt", "yuv420p", "-an", out], check=True)
    still(frames[-1]).save(os.path.join(STILL_DIR, "char_%s_ult.png" % char_id), optimize=True)
    print("%s: %d frames -> %s (%.1f MB)" % (char_id, len(frames), os.path.relpath(out, ROOT),
                                             os.path.getsize(out) / 1e6))


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 1
    src = argv[0]
    os.makedirs(VIDEO_DIR, exist_ok=True)
    os.makedirs(STILL_DIR, exist_ok=True)
    for char_id in argv[1:] or IDS:
        build(char_id, os.path.join(src, "%s_transparent_frames.zip" % char_id))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
