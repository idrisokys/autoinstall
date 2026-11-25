#!/usr/bin/env python3
"""Pac-Man uygulama simgesini (AppIcon.icns) üretir. Gerekli: pip install pillow"""
import struct, io
from PIL import Image, ImageDraw

S = 4096  # süper-örnekleme boyutu


def draw():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # macOS tarzı yuvarlatılmış kare zemin (kenarlarda boşluk bırakır)
    m = int(S * 0.098)
    r = int(S * 0.225)
    d.rounded_rectangle([m, m, S - m, S - m], r, fill=(14, 18, 52, 255))
    # Pac-Man: ağzı açık (yaklaşık 70° açıklık), sağa bakıyor
    cx, cy, R = int(S * 0.42), int(S * 0.5), int(S * 0.255)
    half = 36
    d.pieslice([cx - R, cy - R, cx + R, cy + R], half, 360 - half, fill=(255, 214, 10, 255))
    # göz
    ex, ey, er = cx + int(R * 0.05), cy - int(R * 0.52), int(R * 0.115)
    d.ellipse([ex - er, ey - er, ex + er, ey + er], fill=(14, 18, 52, 255))
    # yenecek noktalar (kurulacak uygulamalar)
    for x in (0.665, 0.745, 0.825):
        pr = int(S * 0.03)
        px = int(S * x)
        d.ellipse([px - pr, cy - pr, px + pr, cy + pr], fill=(255, 245, 200, 255))
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
    import os
    here = os.path.dirname(os.path.abspath(__file__))
    img = draw()
    open(os.path.join(here, "AppIcon.icns"), "wb").write(icns(img))
    if os.environ.get("PREVIEW"):
        img.resize((512, 512), Image.LANCZOS).save(os.environ["PREVIEW"])
    print("AppIcon.icns hazır")
