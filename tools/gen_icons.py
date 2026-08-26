#!/usr/bin/env python3
"""Generate the protein and hudamantium UI icons with Pillow."""

from pathlib import Path

from PIL import Image, ImageDraw


OUTPUT_SIZE = 512
SCALE = 4
WORK_SIZE = OUTPUT_SIZE * SCALE
ART_SCALE = 1.0

OUTLINE = "#6E6558"
HIGHLIGHT = "#F7F3EA"
GOLD = "#D9B26A"
SAND = "#C9B894"
GREY = "#9A9691"
DARK_GREY = "#6E6A64"
SAND_DARK = "#B2A385"  # SAND blended 25% toward OUTLINE.

# Documented extension of the icon palette, not a stray colour.
HUDA = "#8B72B0"  # Vein base — UITheme.LILAC darkened.
HUDA_LIGHT = "#A78BC8"  # Vein highlight — UITheme.LILAC, the existing accent.

OUTLINE_WIDTH = 14 * SCALE
FACET_WIDTH = 7 * SCALE


def _box(coords):
    return tuple(_coord(value) for value in coords)


def _points(points):
    return [(_coord(x), _coord(y)) for x, y in points]


def _coord(value):
    return round((OUTPUT_SIZE * 0.5 + (value - OUTPUT_SIZE * 0.5) * ART_SCALE) * SCALE)


def polygon(draw, points, fill, *, outline=OUTLINE, width=OUTLINE_WIDTH):
    points = _points(points)
    draw.polygon(points, fill=fill)
    if outline and width:
        draw.line(points + [points[0]], fill=outline, width=width, joint="curve")


def facet(draw, points, fill, *, line=True):
    points = _points(points)
    draw.polygon(points, fill=fill)
    if line:
        draw.line(points, fill=OUTLINE, width=FACET_WIDTH, joint="curve")


def ellipse(draw, box, fill, *, outline=OUTLINE, width=OUTLINE_WIDTH):
    draw.ellipse(_box(box), fill=fill, outline=outline, width=width)


def line(draw, points, fill=OUTLINE, width=FACET_WIDTH):
    draw.line(_points(points), fill=fill, width=width, joint="curve")


def new_canvas(art_scale):
    global ART_SCALE
    ART_SCALE = art_scale
    return Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))


def render_protein():
    image = new_canvas(1.063)
    draw = ImageDraw.Draw(image)

    # Powder spill sits behind the tub and scoop but remains visible at the base.
    polygon(
        draw,
        [(111, 389), (163, 370), (226, 379), (272, 367), (326, 382),
         (370, 371), (428, 392), (454, 419), (424, 440), (345, 447),
         (284, 438), (217, 446), (150, 432)],
        HIGHLIGHT,
    )
    line(draw, [(153, 413), (209, 405), (257, 416)], fill=SAND_DARK)

    # Wooden scoop, angled against the right wall of the canister.
    polygon(draw, [(387, 186), (427, 201), (382, 365), (344, 354)], GOLD)
    facet(draw, [(408, 203), (427, 201), (382, 365), (363, 359)], SAND_DARK)
    polygon(
        draw,
        [(342, 343), (386, 337), (432, 355), (460, 386),
         (443, 414), (393, 420), (351, 399), (330, 370)],
        GOLD,
    )
    facet(draw, [(342, 370), (386, 365), (424, 379), (443, 397), (426, 409),
                 (388, 409), (353, 392)], SAND_DARK, line=False)
    line(draw, [(350, 368), (388, 365), (424, 379)])
    line(draw, [(355, 381), (385, 383), (411, 393)], fill=HIGHLIGHT, width=6 * SCALE)

    # Squat stone/clay canister body.
    polygon(
        draw,
        [(82, 175), (359, 175), (375, 337), (354, 391),
         (319, 418), (126, 418), (91, 394), (68, 343)],
        SAND,
    )
    facet(
        draw,
        [(301, 183), (359, 175), (375, 337), (354, 391),
         (319, 418), (282, 418), (303, 339)],
        SAND_DARK,
    )
    line(draw, [(105, 365), (133, 389), (239, 395)], fill=HIGHLIGHT, width=9 * SCALE)

    # Slightly domed grey lid and its heavy rolled rim.
    ellipse(draw, (91, 68, 354, 184), GREY)
    facet(draw, [(225, 74), (314, 87), (346, 116), (321, 148), (256, 166)], DARK_GREY)
    line(draw, [(126, 121), (151, 101), (189, 90)], fill=HIGHLIGHT, width=9 * SCALE)
    ellipse(draw, (66, 143, 377, 232), DARK_GREY)
    ellipse(draw, (80, 139, 363, 211), GREY, width=FACET_WIDTH)
    line(draw, [(112, 174), (139, 160), (179, 153)], fill=HIGHLIGHT, width=8 * SCALE)

    return image


def render_hudamantium():
    image = new_canvas(1.03)
    draw = ImageDraw.Draw(image)

    # Four crystalline veins rise from the top face of the host rock.
    polygon(draw, [(130, 235), (153, 114), (211, 230)], HUDA)
    facet(draw, [(153, 114), (176, 217), (211, 230)], HUDA_LIGHT)

    polygon(draw, [(190, 224), (228, 59), (276, 226)], HUDA)
    facet(draw, [(228, 59), (254, 213), (276, 226)], HUDA_LIGHT)

    polygon(draw, [(250, 221), (300, 42), (344, 228)], HUDA)
    facet(draw, [(300, 42), (321, 209), (344, 228)], HUDA_LIGHT)

    polygon(draw, [(317, 236), (386, 104), (411, 263)], HUDA)
    facet(draw, [(386, 104), (389, 239), (411, 263)], HUDA_LIGHT)

    # Angular host rock, kept entirely in the locked neutral palette.
    polygon(
        draw,
        [(58, 278), (91, 213), (151, 186), (217, 196), (271, 176),
         (335, 194), (376, 227), (425, 249), (456, 322), (445, 388),
         (392, 430), (315, 446), (250, 428), (181, 442), (111, 409),
         (70, 354)],
        GREY,
    )
    facet(draw, [(58, 278), (151, 248), (213, 279), (181, 355),
                 (111, 409), (70, 354)], DARK_GREY)
    facet(draw, [(151, 248), (217, 196), (271, 176), (300, 241),
                 (253, 298), (213, 279)], GREY)
    facet(draw, [(271, 176), (335, 194), (376, 227), (351, 294),
                 (300, 241)], DARK_GREY)
    facet(draw, [(253, 298), (300, 241), (351, 294), (425, 249),
                 (456, 322), (391, 350), (315, 339)], GREY)
    facet(draw, [(181, 355), (253, 298), (315, 339), (283, 419),
                 (250, 428), (181, 442)], DARK_GREY)
    facet(draw, [(315, 339), (391, 350), (445, 388), (392, 430),
                 (315, 446), (283, 419)], GREY)

    # Short, hard-edged mineral glints: no glow or soft lighting.
    polygon(draw, [(106, 279), (148, 259), (181, 274), (142, 291)], HIGHLIGHT,
            outline=None, width=0)
    polygon(draw, [(326, 306), (374, 283), (397, 294), (349, 319)], HIGHLIGHT,
            outline=None, width=0)
    line(draw, [(119, 382), (148, 397), (171, 394)], fill=HIGHLIGHT, width=7 * SCALE)

    return image


def save_icon(image, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    image = image.resize((OUTPUT_SIZE, OUTPUT_SIZE), Image.Resampling.LANCZOS)
    image.save(path, format="PNG", optimize=True)
    print(f"{path.as_posix()} - {image.width}x{image.height}")


def main():
    root = Path(__file__).resolve().parents[1]
    output_dir = root / "assets" / "sprites" / "ui" / "icons"
    save_icon(render_protein(), output_dir / "icon_protein.png")
    save_icon(render_hudamantium(), output_dir / "icon_hudamantium.png")


if __name__ == "__main__":
    main()
