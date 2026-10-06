"""Generates the Rental Ledger web/PWA icons.

Design: the brand-teal tile used by the in-app logo, with a white house whose
body holds three "ledger" lines — a shared house + its account book.

    python tool/icons/make_icons.py

Writes web/favicon.png, web/icons/Icon-{192,512}.png and the maskable
variants (full-bleed background, artwork inside the 80% safe zone).
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
TEAL_TOP = (0, 160, 140)       # lighter teal
TEAL_BOTTOM = (0, 121, 107)    # #00796B
TEAL = (0, 137, 123)           # #00897B — brand primary
WHITE = (255, 255, 255)
SS = 4                          # supersampling for smooth edges


def gradient(size):
    img = Image.new('RGB', (size, size))
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        c = tuple(round(a + (b - a) * t) for a, b in zip(TEAL_TOP, TEAL_BOTTOM))
        for x in range(size):
            px[x, y] = c
    return img


def draw_house(draw, cx, cy, w):
    """White house centred on (cx, cy), w = overall width."""
    h_roof = w * 0.42
    body_w = w * 0.74
    body_h = w * 0.50
    top = cy - (h_roof + body_h) / 2
    roof_base = top + h_roof
    # Roof (with a little eave overhang) and body.
    draw.polygon(
        [(cx, top), (cx + w / 2, roof_base), (cx - w / 2, roof_base)],
        fill=WHITE,
    )
    r = w * 0.06
    draw.rounded_rectangle(
        [cx - body_w / 2, roof_base - 1, cx + body_w / 2, roof_base + body_h],
        radius=r,
        fill=WHITE,
    )
    # Ledger lines inside the body (teal), the last one shorter.
    lw = max(1, round(w * 0.065))
    x0 = cx - body_w * 0.30
    widths = [0.60, 0.60, 0.38]
    for i, frac in enumerate(widths):
        y = roof_base + body_h * (0.28 + i * 0.24)
        draw.rounded_rectangle(
            [x0, y - lw / 2, x0 + body_w * frac, y + lw / 2],
            radius=lw / 2,
            fill=TEAL,
        )


def icon(size, *, maskable):
    big = size * SS
    bg = gradient(big)
    mask = Image.new('L', (big, big), 0)
    if maskable:
        # Platform applies its own shape — fill the whole square.
        mask.paste(255, [0, 0, big, big])
        art = 0.50
    else:
        ImageDraw.Draw(mask).rounded_rectangle(
            [0, 0, big - 1, big - 1], radius=big * 0.22, fill=255)
        art = 0.62
    out = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    out.paste(bg, (0, 0), mask)
    draw_house(ImageDraw.Draw(out), big / 2, big * 0.51, big * art)
    return out.resize((size, size), Image.LANCZOS)


def main():
    web = ROOT / 'web'
    icon(192, maskable=False).save(web / 'icons' / 'Icon-192.png')
    icon(512, maskable=False).save(web / 'icons' / 'Icon-512.png')
    icon(192, maskable=True).save(web / 'icons' / 'Icon-maskable-192.png')
    icon(512, maskable=True).save(web / 'icons' / 'Icon-maskable-512.png')
    icon(64, maskable=False).save(web / 'favicon.png')
    # Larger preview for review (not shipped).
    icon(512, maskable=False).save(Path(__file__).with_name('preview.png'))


if __name__ == '__main__':
    main()
