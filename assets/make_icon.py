#!/usr/bin/env python3
"""Installer uygulama simgesini (AppIcon.icns) üretir. Gerekli: pip install pillow"""
import struct, io, os
from PIL import Image, ImageDraw

S = 4096


def gradient(size, top, bottom):
    g = Image.new("RGBA", (size, size))
    px = g.load()
    for y in range(size):
        t = y / (size - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,)
        for x in range(size):
            px[x, y] = c
    return g


def draw():
    m = int(S * 0.098); r = int(S * 0.225)
    bg = gradient(S, (64, 156, 255), (20, 70, 220))
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([m, m, S - m, S - m], r, fill=255)
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    img.paste(bg, (0, 0), mask)
    d = ImageDraw.Draw(img)
    W = (255, 255, 255, 255)
    cx = S // 2
    bx0, bx1 = int(S * 0.27), int(S * 0.73)
    by0, by1 = int(S * 0.58), int(S * 0.76)
    d.rounded_rectangle([bx0, by0, bx1, by1], int(S * 0.04), fill=W)
    t = int(S * 0.045)
    d.rounded_rectangle([bx0, int(S * 0.50), bx0 + t, by1], t // 2, fill=W)
    d.rounded_rectangle([bx1 - t, int(S * 0.50), bx1, by1], t // 2, fill=W)
    sw = int(S * 0.075)
    d.rounded_rectangle([cx - sw, int(S * 0.20), cx + sw, int(S * 0.45)], sw // 2, fill=W)
    hw = int(S * 0.17)
    d.polygon([(cx - hw, int(S * 0.42)), (cx + hw, int(S * 0.42)), (cx, int(S * 0.58))], fill=W)
    return img


def icns(img):
    types = {"ic07": 128, "ic08": 256, "ic09": 512, "ic10": 1024}
    chunks = b""
    for t, sz in types.items():
        b = io.BytesIO()
        img.resize((sz, sz), Image.LANCZOS).save(b, "PNG")
        data = b.getvalue()
        chunks += t.encode() + struct.pack(">I", len(data) + 8) + data
    return b"icns" + struct.pack(">I", len(chunks) + 8) + chunks


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    img = draw()
    open(os.path.join(here, "AppIcon.icns"), "wb").write(icns(img))
    if os.environ.get("PREVIEW"):
        img.resize((512, 512), Image.LANCZOS).save(os.environ["PREVIEW"])
    print("AppIcon.icns hazır")
