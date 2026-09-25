"""Regenerate Android launcher PNGs (requires Pillow)."""

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "android" / "app" / "src" / "main" / "res"
NAVY = "#0D1117"
AMBER = "#F59E0B"
PANEL = ("#0F766E", "#16A6A0", "#10B981", "#168E9C")
OUTLINE = "#E5F5F3"
SCALE = 8
CANVAS = 108 * SCALE


def point(x, y):
    return round(x * SCALE), round(y * SCALE)


def between(a, b, fraction):
    return a + (b - a) * fraction


def draw_logo(image):
    draw = ImageDraw.Draw(image)

    # A utility pylon and cable show where the panel's power goes.
    tower = (
        ((78, 28), (68, 80)),
        ((78, 28), (88, 80)),
        ((71, 42), (85, 42)),
        ((68, 54), (88, 54)),
        ((66, 66), (90, 66)),
        ((66, 80), (90, 80)),
        ((60, 59), (69, 59)),
    )
    for start, end in tower:
        draw.line([point(*start), point(*end)], fill=AMBER, width=round(2.8 * SCALE))

    # Four large cells remain recognizable at launcher size.
    top_left, top_right = (20, 49), (62, 49)
    bottom_left, bottom_right = (24, 79), (58, 79)
    for row in range(2):
        for col in range(2):
            t0, t1 = row / 2, (row + 1) / 2
            c0, c1 = col / 2, (col + 1) / 2
            y0 = between(top_left[1], bottom_left[1], t0)
            y1 = between(top_left[1], bottom_left[1], t1)
            left0 = between(top_left[0], bottom_left[0], t0)
            right0 = between(top_right[0], bottom_right[0], t0)
            left1 = between(top_left[0], bottom_left[0], t1)
            right1 = between(top_right[0], bottom_right[0], t1)
            gap = 1.1
            corners = [
                point(between(left0, right0, c0) + gap, y0 + gap),
                point(between(left0, right0, c1) - gap, y0 + gap),
                point(between(left1, right1, c1) - gap, y1 - gap),
                point(between(left1, right1, c0) + gap, y1 - gap),
            ]
            draw.polygon(corners, fill=PANEL[row * 2 + col])
    draw.line(
        [point(*top_left), point(*top_right), point(*bottom_right), point(*bottom_left), point(*top_left)],
        fill=OUTLINE,
        width=round(2.5 * SCALE),
        joint="curve",
    )


def save_icon(path, size, *, transparent):
    image = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0) if transparent else NAVY)
    draw_logo(image)
    path.parent.mkdir(parents=True, exist_ok=True)
    image.resize((size, size), Image.Resampling.LANCZOS).save(path)


for density, size in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
    save_icon(RES / f"mipmap-{density}" / "ic_launcher.png", size, transparent=False)

save_icon(RES / "drawable-nodpi" / "ic_launcher_foreground.png", 432, transparent=True)
