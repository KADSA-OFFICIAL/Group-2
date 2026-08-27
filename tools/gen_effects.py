#!/usr/bin/env python3
"""Generate shared combat-effect sprite sheets with Pillow."""

from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw


SCALE = 4

OUTLINE = "#6E6558"
CREAM = "#F7F3EA"
STONE_GRAY = "#9A9691"
STONE_DARK = "#6E6A64"
AMBER = "#D9B26A"
LILAC = "#A78BC8"
HOSTILE = "#C8402F"
POSITIVE = "#6F8A46"
SKY = "#6B8FA8"
LEAF = "#7B9455"
INK = "#2E2A24"

# HOSTILE blended 40% toward INK.
HOSTILE_DARK = "#8A372B"
# POSITIVE blended 40% toward CREAM.
POSITIVE_LIGHT = "#A5B488"
# SKY blended 35% toward OUTLINE.
SKY_DARK = "#6C808C"


def _scaled_box(box: Iterable[float]) -> tuple[int, ...]:
    return tuple(round(value * SCALE) for value in box)


def _scaled_points(points: Iterable[tuple[float, float]]) -> list[tuple[int, int]]:
    return [(round(x * SCALE), round(y * SCALE)) for x, y in points]


def new_frame(width: int, height: int) -> Image.Image:
    return Image.new("RGBA", (width * SCALE, height * SCALE), (0, 0, 0, 0))


def ellipse(
    draw: ImageDraw.ImageDraw,
    box: tuple[float, float, float, float],
    *,
    fill: str | None = None,
    outline: str | None = None,
    width: int = 1,
) -> None:
    draw.ellipse(
        _scaled_box(box),
        fill=fill,
        outline=outline,
        width=width * SCALE if outline else 1,
    )


def line(
    draw: ImageDraw.ImageDraw,
    points: Iterable[tuple[float, float]],
    fill: str,
    width: int,
    *,
    joint: str = "curve",
) -> None:
    draw.line(_scaled_points(points), fill=fill, width=width * SCALE, joint=joint)


def polygon(
    draw: ImageDraw.ImageDraw,
    points: Iterable[tuple[float, float]],
    *,
    fill: str | None = None,
    outline: str | None = None,
    width: int = 1,
) -> None:
    scaled = _scaled_points(points)
    draw.polygon(scaled, fill=fill)
    if outline:
        draw.line(scaled + [scaled[0]], fill=outline, width=width * SCALE, joint="curve")


def _radial_triangle(
    draw: ImageDraw.ImageDraw,
    angle_degrees: float,
    inner_radius: float,
    length: float,
    half_width: float,
    color: str,
    edge_color: str | None = None,
) -> None:
    import math

    angle = math.radians(angle_degrees)
    ux, uy = math.cos(angle), math.sin(angle)
    px, py = -uy, ux
    cx = cy = 64
    base_x = cx + inner_radius * ux
    base_y = cy + inner_radius * uy
    tip_x = cx + (inner_radius + length) * ux
    tip_y = cy + (inner_radius + length) * uy
    polygon(
        draw,
        [
            (base_x + half_width * px, base_y + half_width * py),
            (tip_x, tip_y),
            (base_x - half_width * px, base_y - half_width * py),
        ],
        fill=color,
        outline=edge_color,
        width=1,
    )


# A stationary radial detonation shared by all instant area-damage events.
def render_burst() -> list[Image.Image]:
    frames = [new_frame(128, 128) for _ in range(4)]

    draw = ImageDraw.Draw(frames[0])
    ellipse(draw, (48, 48, 80, 80), fill=CREAM)
    ellipse(draw, (28, 28, 100, 100), outline=HOSTILE, width=4)

    draw = ImageDraw.Draw(frames[1])
    ellipse(draw, (56, 56, 72, 72), fill=CREAM)
    ellipse(draw, (12, 12, 116, 116), outline=HOSTILE, width=6)
    for angle in range(0, 360, 45):
        _radial_triangle(draw, angle, 52, 10, 4, HOSTILE, HOSTILE_DARK)

    draw = ImageDraw.Draw(frames[2])
    ellipse(draw, (2, 2, 126, 126), outline=HOSTILE_DARK, width=2)
    for angle in range(0, 360, 45):
        _radial_triangle(draw, angle, 58, 5, 3, HOSTILE_DARK)

    draw = ImageDraw.Draw(frames[3])
    for index, angle in enumerate(range(0, 360, 45)):
        color = STONE_GRAY if index in (1, 2, 3) else HOSTILE_DARK
        _radial_triangle(draw, angle, 53.5, 5, 2, color)

    return frames


# A continuous upward fill that marks healing received at a character's feet.
def render_heal() -> list[Image.Image]:
    frames = [new_frame(64, 96) for _ in range(4)]
    stem_specs = [(13, 10), (21, 18), (29, 12), (39, 20), (50, 15)]

    draw = ImageDraw.Draw(frames[0])
    ellipse(draw, (10, 73, 54, 87), outline=POSITIVE, width=2)

    draw = ImageDraw.Draw(frames[1])
    ellipse(draw, (10, 73, 54, 87), outline=POSITIVE, width=2)
    for x, length in stem_specs:
        line(draw, [(x, 78), (x, 78 - length)], POSITIVE_LIGHT, 2)
        # A compact cap sharpens the rising direction without adding a sparkle motif.
        draw.rectangle(_scaled_box((x - 1, 77 - length, x + 1, 79 - length)), fill=CREAM)

    draw = ImageDraw.Draw(frames[2])
    ellipse(draw, (10, 73, 54, 87), outline=POSITIVE_LIGHT, width=1)
    for x, length in stem_specs:
        top = 58 - length
        for y in range(top, 59, 6):
            line(draw, [(x, y), (x, min(y + 2, 58))], POSITIVE_LIGHT, 2)

    draw = ImageDraw.Draw(frames[3])
    for x, y in [(15, 22), (27, 13), (40, 26), (51, 17)]:
        draw.rectangle(_scaled_box((x, y, x + 2, y + 2)), fill=POSITIVE_LIGHT)

    return frames


def _taunt_hook(draw: ImageDraw.ImageDraw, angle_degrees: float) -> None:
    import math

    angle = math.radians(angle_degrees)
    ux, uy = math.cos(angle), math.sin(angle)
    tx, ty = -uy, ux
    cx = cy = 128
    outer = (cx + 120 * ux, cy + 120 * uy)
    bend = (cx + 110 * ux + 5 * tx, cy + 110 * uy + 5 * ty)
    inner = (cx + 106 * ux, cy + 106 * uy)
    line(draw, [outer, bend, inner], LEAF, 3, joint="curve")
    # Reinforce the elbow so the inward hook remains readable after world scaling.
    bx, by = bend
    draw.rectangle(_scaled_box((bx - 1, by - 1, bx + 1, by + 1)), fill=LEAF)


# A fixed-diameter flash that exposes the exact one-shot taunt radius.
def render_taunt_ring() -> list[Image.Image]:
    frames = [new_frame(256, 256) for _ in range(3)]

    draw = ImageDraw.Draw(frames[0])
    ellipse(draw, (4, 4, 252, 252), outline=LEAF, width=8)

    draw = ImageDraw.Draw(frames[1])
    ellipse(draw, (4, 4, 252, 252), outline=CREAM, width=3)
    for angle in range(0, 360, 45):
        _taunt_hook(draw, angle)

    draw = ImageDraw.Draw(frames[2])
    import math

    box = _scaled_box((4, 4, 252, 252))
    for segment in range(0, 24, 2):
        start = segment * 15
        draw.arc(box, start=start, end=start + 15, fill=OUTLINE, width=2 * SCALE)

    return frames


RAGE_CRACKS = [
    [(7, 43), (17, 43), (17, 35), (22, 30)],
    [(74, 35), (82, 35), (82, 25), (87, 20)],
    [(13, 98), (22, 89), (22, 79), (28, 73)],
    [(71, 91), (82, 91), (82, 103), (88, 109)],
    [(8, 65), (19, 65), (25, 59), (30, 59)],
    [(69, 65), (81, 65), (87, 59), (92, 59)],
    [(48, 0), (48, 24), (41, 31), (41, 36)],
]


def _draw_cracks(
    draw: ImageDraw.ImageDraw,
    count: int,
    outer_color: str,
    *,
    core: bool,
) -> None:
    for points in RAGE_CRACKS[:count]:
        line(draw, points, outer_color, 2, joint="curve")
        if core:
            line(draw, points, CREAM, 1, joint="curve")


# Angular fractures show the low-health rage state without covering the character.
def render_rage_crack() -> list[Image.Image]:
    frames = [new_frame(96, 128) for _ in range(4)]
    _draw_cracks(ImageDraw.Draw(frames[0]), 3, HOSTILE, core=False)
    _draw_cracks(ImageDraw.Draw(frames[1]), 5, HOSTILE, core=True)
    _draw_cracks(ImageDraw.Draw(frames[2]), 7, HOSTILE_DARK, core=True)
    _draw_cracks(ImageDraw.Draw(frames[3]), 7, HOSTILE_DARK, core=False)
    return frames


def _hexagon(cx: float, cy: float, radius: float = 8) -> list[tuple[float, float]]:
    import math

    return [
        (
            cx + radius * math.cos(math.radians(60 * index)),
            cy + radius * math.sin(math.radians(60 * index)),
        )
        for index in range(6)
    ]


SHELL_SCATTERED = [(13, 26), (48, 13), (83, 28), (12, 101), (48, 115), (84, 99)]
SHELL_MIDWAY = [(24, 38), (48, 25), (72, 38), (24, 90), (48, 103), (72, 90)]
SHELL_LOCKED = [(48, 10), (86, 32), (86, 96), (48, 118), (10, 96), (10, 32)]
SHELL_INNER = [(48, 36), (66, 44), (66, 84), (48, 92), (30, 84), (30, 44)]


def _draw_shell_plates(
    draw: ImageDraw.ImageDraw,
    centers: Iterable[tuple[float, float]],
    *,
    width: int,
    locked: bool,
    seams: bool,
    dark_lower: bool = False,
) -> None:
    if locked:
        outer = list(centers)
        for index in range(6):
            next_index = (index + 1) % 6
            color = SKY_DARK if dark_lower and index in (2, 3, 4) else SKY
            polygon(
                draw,
                [outer[index], outer[next_index], SHELL_INNER[next_index], SHELL_INNER[index]],
                outline=color,
                width=width,
            )
            # One restrained inner bevel adds plate depth while keeping every face hollow.
            if index in (4, 5, 0):
                a = SHELL_INNER[index]
                b = SHELL_INNER[next_index]
                line(draw, [a, b], CREAM, 1)
        if seams:
            for x, y in SHELL_INNER:
                draw.rectangle(_scaled_box((x - 1, y - 1, x + 2, y + 2)), fill=CREAM)
        return

    for index, (cx, cy) in enumerate(centers):
        polygon(draw, _hexagon(cx, cy), outline=SKY, width=width)


# Interlocking thick plates harden into an unmistakable invulnerability shell.
def render_immunity_shell() -> list[Image.Image]:
    frames = [new_frame(96, 128) for _ in range(5)]
    _draw_shell_plates(ImageDraw.Draw(frames[0]), SHELL_SCATTERED, width=2, locked=False, seams=False)
    _draw_shell_plates(ImageDraw.Draw(frames[1]), SHELL_MIDWAY, width=2, locked=False, seams=False)
    _draw_shell_plates(ImageDraw.Draw(frames[2]), SHELL_LOCKED, width=4, locked=True, seams=True)
    _draw_shell_plates(
        ImageDraw.Draw(frames[3]), SHELL_LOCKED, width=4, locked=True, seams=False, dark_lower=True
    )
    _draw_shell_plates(
        ImageDraw.Draw(frames[4]), SHELL_LOCKED, width=4, locked=True, seams=True, dark_lower=True
    )
    return frames


def save_sheet(frames: list[Image.Image], frame_size: tuple[int, int], path: Path) -> None:
    frame_width, frame_height = frame_size
    resized = [
        frame.resize((frame_width, frame_height), Image.Resampling.LANCZOS)
        for frame in frames
    ]
    sheet = Image.new("RGBA", (frame_width * len(frames), frame_height), (0, 0, 0, 0))
    for index, frame in enumerate(resized):
        sheet.paste(frame, (index * frame_width, 0), frame)
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path, format="PNG", optimize=True)
    print(f"{path.as_posix()} - {sheet.width}x{sheet.height}")


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    output_dir = root / "assets" / "sprites" / "effects"
    save_sheet(render_burst(), (128, 128), output_dir / "burst.png")
    save_sheet(render_heal(), (64, 96), output_dir / "heal.png")
    save_sheet(render_taunt_ring(), (256, 256), output_dir / "taunt_ring.png")
    save_sheet(render_rage_crack(), (96, 128), output_dir / "rage_crack.png")
    save_sheet(render_immunity_shell(), (96, 128), output_dir / "immunity_shell.png")


if __name__ == "__main__":
    main()
