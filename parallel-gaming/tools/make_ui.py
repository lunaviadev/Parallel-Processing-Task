import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ui", "art")
SS = 4


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def vgrad(w, h, stops):
    ys = np.linspace(0, 1, h)[:, None]
    out = np.zeros((h, w, 4), dtype=np.float64)
    for c in range(4):
        pos = [s[0] for s in stops]
        val = [s[1][c] for s in stops]
        out[:, :, c] = np.interp(ys, pos, val)
    return Image.fromarray(out.clip(0, 255).astype(np.uint8), "RGBA")


def rmask(w, h, r, inset=0):
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle((inset, inset, w - 1 - inset, h - 1 - inset), r, fill=255)
    return m


def masked(img, mask):
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    a = np.array(img)[:, :, 3].astype(np.float64) * (np.array(mask) / 255.0)
    arr = np.array(img)
    arr[:, :, 3] = a.astype(np.uint8)
    return Image.fromarray(arr, "RGBA")


def over(base, top):
    return Image.alpha_composite(base, top)


def down(img, w, h):
    return img.resize((w, h), Image.LANCZOS)


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, name))
    print("wrote", name, img.size)


def glossy(w, h, r, body, border, gloss_alpha=170, glow=None, inner=(255, 255, 255, 150)):
    W, H, R = w * SS, h * SS, r * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    if glow:
        g = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(g).rounded_rectangle((2 * SS, 2 * SS, W - 1 - 2 * SS, H - 1 - 2 * SS), R, fill=glow)
        img = over(img, g.filter(ImageFilter.GaussianBlur(3 * SS)))
    pad = 2 * SS if glow else 0
    bw, bh = W - 2 * pad, H - 2 * pad
    b = masked(vgrad(bw, bh, body), rmask(bw, bh, R))
    gl = vgrad(bw, bh, [(0, (255, 255, 255, gloss_alpha)), (0.48, (255, 255, 255, int(gloss_alpha * 0.35))), (0.5, (255, 255, 255, 0)), (1, (255, 255, 255, 0))])
    b = over(b, masked(gl, rmask(bw, bh, max(R - SS, 1), inset=SS + 1)))
    d = ImageDraw.Draw(b)
    d.rounded_rectangle((SS, SS, bw - 1 - SS, bh - 1 - SS), max(R - SS, 1), outline=inner, width=SS)
    d.rounded_rectangle((0, 0, bw - 1, bh - 1), R, outline=border, width=SS)
    img.alpha_composite(b, (pad, pad))
    return down(img, w, h)


def buttons():
    sets = {
        "btn": {
            "normal": ([(0, hexc("f7fcff")), (0.5, hexc("e2f3fd")), (0.51, hexc("c8e7fb")), (1, hexc("e6f6ff"))], hexc("6f9fc4"), None),
            "hover": ([(0, hexc("eefaff")), (0.5, hexc("bfe9fd")), (0.51, hexc("8fd5f7")), (1, hexc("c9f1ff"))], hexc("3c8dc7"), (120, 210, 255, 160)),
            "pressed": ([(0, hexc("a9d6f3")), (0.5, hexc("8cc4ea")), (0.51, hexc("6fb4e4")), (1, hexc("a5dcf6"))], hexc("2e6f9e"), None),
        },
        "btn_green": {
            "normal": ([(0, hexc("d9fbb8")), (0.5, hexc("98e06a")), (0.51, hexc("5fc23d")), (1, hexc("9ae66c"))], hexc("3d8a2a"), None),
            "hover": ([(0, hexc("e8ffcc")), (0.5, hexc("adf080")), (0.51, hexc("6ed64a")), (1, hexc("b5f58a"))], hexc("2f7a1f"), (150, 255, 120, 150)),
            "pressed": ([(0, hexc("8fd062")), (0.5, hexc("6cbf45")), (0.51, hexc("4aa630")), (1, hexc("7fd153"))], hexc("2a6a1a"), None),
        },
        "btn_red": {
            "normal": ([(0, hexc("ffd5d0")), (0.5, hexc("f58a7d")), (0.51, hexc("e2483a")), (1, hexc("f7806f"))], hexc("9e2a20"), None),
            "hover": ([(0, hexc("ffe2dc")), (0.5, hexc("ff9d8f")), (0.51, hexc("f2584a")), (1, hexc("ff9a88"))], hexc("8a1f17"), (255, 120, 100, 160)),
            "pressed": ([(0, hexc("e88a7f")), (0.5, hexc("d8665a")), (0.51, hexc("c03a2e")), (1, hexc("e06a5c"))], hexc("7a1a12"), None),
        },
    }
    for name, states in sets.items():
        for st, (body, border, glow) in states.items():
            save(glossy(104, 52, 11, body, border, glow=glow), "%s_%s.png" % (name, st))
    save(glossy(104, 52, 11, [(0, hexc("ffffff", 150)), (1, hexc("e6f2fa", 120))], hexc("9fbfd6", 200), gloss_alpha=60), "btn_disabled.png")
    for st, body in {
        "close": [(0, hexc("ffb9ad")), (0.5, hexc("ee6d5c")), (0.51, hexc("d63a28")), (1, hexc("f08a70"))],
        "close_hover": [(0, hexc("ffd0c6")), (0.5, hexc("ff8473")), (0.51, hexc("ee4a35")), (1, hexc("ffa08a"))],
        "min": [(0, hexc("eaf7ff")), (0.5, hexc("bfe4fa")), (0.51, hexc("98d2f4")), (1, hexc("c9ecff"))],
        "min_hover": [(0, hexc("f5fcff")), (0.5, hexc("d4f0ff")), (0.51, hexc("aee0fb")), (1, hexc("dcf5ff"))],
    }.items():
        save(glossy(46, 22, 5, body, hexc("2b4f6b", 220)), "win_%s.png" % st)


def panels():
    W, H, R = 64 * SS, 64 * SS, 14 * SS
    body = masked(vgrad(W, H, [(0, (255, 255, 255, 215)), (0.5, (246, 252, 255, 190)), (1, (232, 246, 255, 200))]), rmask(W, H, R))
    d = ImageDraw.Draw(body)
    d.rounded_rectangle((SS, SS, W - 1 - SS, H - 1 - SS), R - SS, outline=(255, 255, 255, 235), width=SS)
    d.rounded_rectangle((0, 0, W - 1, H - 1), R, outline=(120, 170, 205, 170), width=SS)
    save(down(body, 64, 64), "panel_glass.png")

    body = masked(vgrad(W, H, [(0, (20, 60, 100, 190)), (1, (8, 30, 60, 210))]), rmask(W, H, R))
    d = ImageDraw.Draw(body)
    d.rounded_rectangle((SS, SS, W - 1 - SS, H - 1 - SS), R - SS, outline=(160, 220, 255, 110), width=SS)
    d.rounded_rectangle((0, 0, W - 1, H - 1), R, outline=(0, 20, 40, 200), width=SS)
    save(down(body, 64, 64), "panel_dark.png")

    w, h, r, tb = 128, 128, 10, 34
    W, H, R, TB = w * SS, h * SS, r * SS, tb * SS
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    frame = masked(vgrad(W, H, [(0, (150, 215, 250, 225)), (TB / H * 0.5, (95, 180, 235, 215)), (TB / H, (70, 155, 220, 220)), (1, (120, 195, 240, 220))]), rmask(W, H, R))
    gl = masked(vgrad(W, TB, [(0, (255, 255, 255, 200)), (0.55, (255, 255, 255, 60)), (0.56, (255, 255, 255, 0)), (1, (255, 255, 255, 0))]), rmask(W, TB, R - SS, inset=SS))
    frame.alpha_composite(gl, (0, 0))
    inner = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(inner).rounded_rectangle((6 * SS, TB, W - 1 - 6 * SS, H - 1 - 6 * SS), 4 * SS, fill=(250, 253, 255, 248), outline=(80, 130, 170, 200), width=SS)
    frame = over(frame, inner)
    d = ImageDraw.Draw(frame)
    d.rounded_rectangle((SS, SS, W - 1 - SS, H - 1 - SS), R - SS, outline=(255, 255, 255, 170), width=SS)
    d.rounded_rectangle((0, 0, W - 1, H - 1), R, outline=(20, 50, 80, 210), width=SS)
    save(down(over(shadow, frame), w, h), "window.png")

    W, H = 32 * SS, 48 * SS
    tbimg = vgrad(W, H, [(0, (40, 120, 180, 215)), (0.04, (210, 240, 255, 150)), (0.08, (30, 100, 160, 210)), (0.5, (14, 60, 110, 225)), (1, (6, 30, 60, 235))])
    save(down(tbimg, 32, 48), "taskbar.png")

    for name, stops, border in [
        ("bar_fill", [(0, hexc("e6ffcf")), (0.5, hexc("8fe063")), (0.51, hexc("4fbf32")), (1, hexc("8ae35c"))], hexc("2f7a1f")),
        ("bar_fill_red", [(0, hexc("ffe0da")), (0.5, hexc("ff8a78")), (0.51, hexc("e64532")), (1, hexc("ff8b70"))], hexc("8e231a")),
        ("bar_fill_blue", [(0, hexc("e9f8ff")), (0.5, hexc("8fd6fb")), (0.51, hexc("3fa8ea")), (1, hexc("88d4fa"))], hexc("1f5f8e")),
        ("bar_bg", [(0, hexc("cfdbe4", 230)), (1, hexc("f4f9fc", 230))], hexc("7d9db5")),
    ]:
        save(glossy(40, 18, 8, stops, border, gloss_alpha=150 if name != "bar_bg" else 0), name + ".png")


def sphere(size, c0, c1, glyph=None, rim=(255, 255, 255, 120)):
    S = size * SS
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float64)
    cx = cy = (S - 1) / 2.0
    r = S / 2.0 - SS
    dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / r
    lx, ly = (xx - cx * 0.8) / r, (yy - cy * 1.25) / r
    t = np.clip(np.sqrt(lx ** 2 + ly ** 2) / 1.6, 0, 1)
    rgb = np.zeros((S, S, 4))
    for c in range(3):
        rgb[:, :, c] = c0[c] * (1 - t) + c1[c] * t
    rgb[:, :, 3] = np.clip((1 - dist) * r / (1.2 * SS), 0, 1) * 255
    img = Image.fromarray(rgb.clip(0, 255).astype(np.uint8), "RGBA")
    hl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    hd.ellipse((S * 0.18, S * 0.06, S * 0.82, S * 0.5), fill=(255, 255, 255, 150))
    hl = hl.filter(ImageFilter.GaussianBlur(S * 0.03))
    hl = Image.composite(hl, Image.new("RGBA", (S, S), (0, 0, 0, 0)), Image.fromarray((np.clip(1 - dist, 0, 1) > 0).astype(np.uint8) * 255))
    grad = vgrad(S, S, [(0, (255, 255, 255, 255)), (0.5, (255, 255, 255, 40)), (1, (255, 255, 255, 0))])
    hl = Image.fromarray((np.array(hl).astype(np.float64) * np.stack([np.ones((S, S))] * 3 + [np.array(grad)[:, :, 3] / 255.0], axis=2)).astype(np.uint8), "RGBA")
    img = over(img, hl)
    ImageDraw.Draw(img).ellipse((SS, SS, S - 1 - SS, S - 1 - SS), outline=rim, width=SS)
    if glyph:
        g = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        glyph(ImageDraw.Draw(g), S)
        sh = g.copy().filter(ImageFilter.GaussianBlur(SS * 1.5))
        sh = Image.fromarray((np.array(sh) * np.array([0, 0, 0, 0.5])).astype(np.uint8), "RGBA")
        img = over(img, sh)
        img = over(img, g)
    return down(img, size, size)


def g_drop(d, S):
    cx, cy, r = S / 2, S * 0.6, S * 0.17
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, 255, 255, 245))
    d.polygon([(cx - r * 0.93, cy - r * 0.38), (cx, S * 0.2), (cx + r * 0.93, cy - r * 0.38)], fill=(255, 255, 255, 245))
    d.ellipse((cx - r * 0.55, cy - r * 0.2, cx - r * 0.15, cy + r * 0.25), fill=(230, 40, 70, 230))


def g_question(d, S):
    w = S * 0.09
    d.arc((S * 0.32, S * 0.2, S * 0.68, S * 0.52), 190, 400, fill=(255, 255, 255, 250), width=int(w))
    d.line((S * 0.5, S * 0.5, S * 0.5, S * 0.62), fill=(255, 255, 255, 250), width=int(w))
    d.ellipse((S * 0.45, S * 0.69, S * 0.55, S * 0.79), fill=(255, 255, 255, 250))


def g_power(d, S):
    w = int(S * 0.08)
    d.arc((S * 0.27, S * 0.27, S * 0.73, S * 0.73), 300, 600, fill=(255, 255, 255, 250), width=w)
    d.line((S * 0.5, S * 0.2, S * 0.5, S * 0.5), fill=(255, 255, 255, 250), width=w)


def g_star(d, S):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = S * (0.3 if i % 2 == 0 else 0.13)
        pts.append((S / 2 + math.cos(a) * r, S * 0.52 + math.sin(a) * r))
    d.polygon(pts, fill=(255, 255, 255, 250))


def g_leaf(d, S):
    d.ellipse((S * 0.3, S * 0.28, S * 0.72, S * 0.7), fill=(255, 255, 255, 240))
    d.ellipse((S * 0.38, S * 0.2, S * 0.8, S * 0.62), fill=(0, 0, 0, 0))
    d.chord((S * 0.28, S * 0.24, S * 0.74, S * 0.74), 100, 350, fill=(255, 255, 255, 245))
    d.line((S * 0.33, S * 0.7, S * 0.66, S * 0.34), fill=(70, 160, 80, 255), width=int(S * 0.035))


def g_speaker(d, S):
    d.polygon([(S * 0.24, S * 0.42), (S * 0.36, S * 0.42), (S * 0.5, S * 0.28), (S * 0.5, S * 0.72), (S * 0.36, S * 0.58), (S * 0.24, S * 0.58)], fill=(255, 255, 255, 250))
    for k, rr in enumerate([0.12, 0.2]):
        d.arc((S * (0.5 - rr), S * (0.5 - rr), S * (0.5 + rr) + S * 0.1, S * (0.5 + rr)), 300, 420, fill=(255, 255, 255, 230), width=int(S * 0.05))


def g_chart(d, S):
    for i, hh in enumerate([0.18, 0.3, 0.42]):
        x = S * (0.28 + i * 0.16)
        d.rounded_rectangle((x, S * (0.7 - hh), x + S * 0.11, S * 0.7), int(S * 0.02), fill=(255, 255, 255, 250))
    d.line((S * 0.25, S * 0.72, S * 0.77, S * 0.72), fill=(255, 255, 255, 220), width=int(S * 0.03))


def g_brush(d, S):
    cols = [(255, 40, 70, 255), (200, 40, 160, 255), (255, 210, 60, 255), (60, 200, 120, 255), (40, 150, 255, 255)]
    d.ellipse((S * 0.2, S * 0.26, S * 0.8, S * 0.74), fill=(255, 255, 255, 245))
    d.ellipse((S * 0.52, S * 0.52, S * 0.66, S * 0.66), fill=(0, 0, 0, 0))
    for i, c in enumerate(cols):
        a = math.pi * (1.05 + i * 0.28)
        x, y = S / 2 + math.cos(a) * S * 0.18, S / 2 + math.sin(a) * S * 0.14
        d.ellipse((x - S * 0.055, y - S * 0.055, x + S * 0.055, y + S * 0.055), fill=c)


def g_snow(d, S):
    w = int(S * 0.05)
    for k in range(3):
        a = k * math.pi / 3
        dx, dy = math.cos(a) * S * 0.25, math.sin(a) * S * 0.25
        d.line((S / 2 - dx, S / 2 - dy, S / 2 + dx, S / 2 + dy), fill=(255, 255, 255, 250), width=w)


def g_bucket(d, S):
    d.polygon([(S * 0.3, S * 0.38), (S * 0.7, S * 0.38), (S * 0.64, S * 0.72), (S * 0.36, S * 0.72)], fill=(255, 255, 255, 250))
    d.arc((S * 0.32, S * 0.2, S * 0.68, S * 0.56), 180, 360, fill=(255, 255, 255, 250), width=int(S * 0.04))
    d.ellipse((S * 0.42, S * 0.42, S * 0.58, S * 0.5), fill=(255, 60, 80, 255))


def g_mega(d, S):
    d.ellipse((S * 0.24, S * 0.24, S * 0.76, S * 0.76), outline=(255, 255, 255, 250), width=int(S * 0.06))
    d.ellipse((S * 0.4, S * 0.4, S * 0.6, S * 0.6), fill=(255, 255, 255, 250))


def g_rinse(d, S):
    for k, (x, y, r) in enumerate([(0.38, 0.42, 0.12), (0.6, 0.36, 0.08), (0.58, 0.62, 0.14)]):
        d.ellipse((S * (x - r), S * (y - r), S * (x + r), S * (y + r)), outline=(255, 255, 255, 250), width=int(S * 0.035))


def g_clock(d, S):
    d.ellipse((S * 0.25, S * 0.25, S * 0.75, S * 0.75), outline=(255, 255, 255, 250), width=int(S * 0.06))
    d.line((S * 0.5, S * 0.5, S * 0.5, S * 0.32), fill=(255, 255, 255, 250), width=int(S * 0.05))
    d.line((S * 0.5, S * 0.5, S * 0.63, S * 0.56), fill=(255, 255, 255, 250), width=int(S * 0.05))


def icons():
    spec = [
        ("orb", (120, 230, 160), (10, 120, 170), g_drop, 64),
        ("icon_play", (255, 150, 150), (200, 20, 50), g_brush, 72),
        ("icon_zen", (170, 255, 200), (20, 150, 110), g_leaf, 72),
        ("icon_bench", (170, 220, 255), (20, 90, 190), g_chart, 72),
        ("icon_mixer", (255, 220, 150), (220, 120, 20), g_speaker, 72),
        ("icon_help", (170, 230, 255), (30, 110, 210), g_question, 72),
        ("icon_scores", (255, 240, 160), (210, 140, 10), g_star, 72),
        ("icon_power", (255, 170, 160), (190, 40, 30), g_power, 72),
    ]
    for name, c0, c1, glyph, size in spec:
        save(sphere(size, c0, c1, glyph), name + ".png")
    for name, c0, c1, glyph in [
        ("pw_freeze", (220, 245, 255), (90, 170, 255), g_snow),
        ("pw_bucket", (255, 225, 200), (255, 120, 60), g_bucket),
        ("pw_mega", (255, 220, 255), (200, 80, 220), g_mega),
        ("pw_rinse", (210, 255, 250), (40, 190, 190), g_rinse),
        ("pw_time", (230, 255, 200), (90, 190, 60), g_clock),
    ]:
        save(sphere(56, c0, c1, glyph, rim=(255, 255, 255, 200)), name + ".png")


def bubble():
    S = 128 * SS
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float64)
    c = (S - 1) / 2
    r = S / 2 - 2 * SS
    dx, dy = xx - c, yy - c
    dist = np.sqrt(dx ** 2 + dy ** 2) / r
    ang = np.arctan2(dy, dx)
    rim = np.clip((dist - 0.55) / 0.45, 0, 1) ** 2.2
    edge = np.clip((1 - dist) * r / (1.5 * SS), 0, 1)
    hue = (ang / (2 * np.pi) + 0.5 + dist * 0.3) % 1.0
    rgb = np.stack([0.5 + 0.5 * np.cos(2 * np.pi * (hue + k / 3.0)) for k in range(3)], axis=2)
    rgb = 0.55 + 0.45 * rgb
    a = (0.08 + 0.75 * rim) * edge
    img = np.dstack([rgb * 255, a * 255]).clip(0, 255).astype(np.uint8)
    img = Image.fromarray(img, "RGBA")
    hl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    hd.arc((S * 0.16, S * 0.16, S * 0.84, S * 0.84), 200, 250, fill=(255, 255, 255, 230), width=int(S * 0.05))
    hd.ellipse((S * 0.25, S * 0.22, S * 0.33, S * 0.3), fill=(255, 255, 255, 240))
    img = over(img, hl.filter(ImageFilter.GaussianBlur(SS * 2)))
    save(down(img, 128, 128), "bubble.png")


def glow():
    S = 64
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float64)
    d = np.sqrt((xx - S / 2 + 0.5) ** 2 + (yy - S / 2 + 0.5) ** 2) / (S / 2)
    a = np.clip(1 - d, 0, 1) ** 2
    img = np.dstack([np.full((S, S), 255), np.full((S, S), 255), np.full((S, S), 255), a * 255]).astype(np.uint8)
    save(Image.fromarray(img, "RGBA"), "glow.png")


if __name__ == "__main__":
    buttons()
    panels()
    icons()
    bubble()
    glow()
