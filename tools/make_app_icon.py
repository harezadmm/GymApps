"""Menggambar ikon GymApps: pelat besi di atas squircle hitam mengilap.

Digambar dari nol, bukan diambil dari mana-mana — tidak ada merek orang lain
di dalamnya. Skripnya disimpan supaya ikonnya bisa dibuat ulang: ukuran baru
tinggal ditambah di `main()`, bukan digambar ulang dengan tangan.

    python3 tools/make_app_icon.py

Semua ukuran ditulis langsung ke tempatnya masing-masing (iOS, Android, web,
favicon, dan aset dalam aplikasi).
"""

import math
import os
from PIL import Image, ImageDraw, ImageFilter

# Digambar besar lalu dikecilkan. Lingkaran dan lengkung superellipse tidak
# punya anti-alias sendiri di PIL; mengecilkan gambar 4x yang memberikannya.
SS = 4
BASE = 512
N = BASE * SS
C = N / 2

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(HERE, "app")


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def vgrad(stops, size=N):
    """Gradien tegak dari daftar (posisi 0..1, warna)."""
    strip = Image.new("RGB", (1, 1024))
    px = strip.load()
    stops = sorted(stops)
    for y in range(1024):
        t = y / 1023
        lo = stops[0]
        hi = stops[-1]
        for i in range(len(stops) - 1):
            if stops[i][0] <= t <= stops[i + 1][0]:
                lo, hi = stops[i], stops[i + 1]
                break
        span = hi[0] - lo[0]
        k = 0 if span == 0 else (t - lo[0]) / span
        a, b = rgb(lo[1]), rgb(hi[1])
        px[0, y] = tuple(round(a[j] + (b[j] - a[j]) * k) for j in range(3))
    return strip.resize((size, size), Image.BICUBIC)


def dgrad(stops, angle=45, size=N):
    """Gradien miring — dipakai supaya cahaya jatuh dari kiri atas."""
    big = int(size * 1.5)
    g = vgrad(stops, big).rotate(angle, resample=Image.BICUBIC)
    o = (big - size) // 2
    return g.crop((o, o, o + size, o + size))


def disc(r, cx=C, cy=C, fill=255):
    m = Image.new("L", (N, N), 0)
    ImageDraw.Draw(m).ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill)
    return m


def ring(r_in, r_out):
    m = disc(r_out)
    ImageDraw.Draw(m).ellipse([C - r_in, C - r_in, C + r_in, C + r_in], fill=0)
    return m


def squircle(inset, n=5.0, steps=1440):
    """Superellipse — bentuk yang dipakai iOS, bukan persegi bersudut bulat.
    Bedanya kecil tapi terlihat kalau ditaruh bersebelahan di layar Home."""
    r = C - inset
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        ct, st = math.cos(t), math.sin(t)
        pts.append((
            C + r * math.copysign(abs(ct) ** (2.0 / n), ct),
            C + r * math.copysign(abs(st) ** (2.0 / n), st),
        ))
    return pts


def squircle_mask(inset, n=5.0):
    m = Image.new("L", (N, N), 0)
    ImageDraw.Draw(m).polygon(squircle(inset, n), fill=255)
    return m


def solid(colour):
    return Image.new("RGB", (N, N), rgb(colour))


def plate():
    """Pelat besi dilihat dari atas, dengan collar krom di tengahnya."""
    # Jari-jari sebagai pecahan sisi kanvas.
    R = 0.356 * N
    r_a = 0.309 * N      # alur pertama
    r_b = 0.238 * N      # alur kedua
    r_hub = 0.156 * N    # naikan tengah
    r_lobe = 0.104 * N   # collar bergerigi
    r_chrome = 0.086 * N
    r_mid = 0.070 * N
    r_hole = 0.050 * N

    body = dgrad([(0.0, "#8b8c92"), (0.35, "#6b6c72"), (0.7, "#56575c"), (1.0, "#434449")])
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    img.paste(body, (0, 0), disc(R))

    def shade(mask, colour, alpha):
        layer = solid(colour)
        m = mask.point(lambda v: int(v * alpha))
        img.paste(layer, (0, 0), m)

    def groove(r, w, depth=0.62, lip=0.50):
        """Alur melingkar: garis gelap, lalu bibir terang di bawahnya —
        itu yang membuat permukaannya terbaca bertingkat, bukan datar."""
        shade(ring(r - w, r + w), "#2b2c30", depth)
        shade(ring(r + w, r + w * 2.1), "#9a9ba1", lip)

    # Tepi luar: bevel terang lalu jatuh gelap ke arah sisi.
    shade(ring(R * 0.992, R), "#1b1c1f", 0.85)
    shade(ring(R * 0.955, R * 0.992), "#a9aab0", 0.30)

    groove(r_a, 0.004 * N)
    shade(ring(r_b, r_a), "#000000", 0.05)
    groove(r_b, 0.004 * N)
    shade(ring(r_hub, r_b), "#000000", 0.11)

    # Naikan tengah: lebih terang supaya terbaca lebih dekat ke mata.
    hub = dgrad([(0.0, "#9c9da4"), (0.4, "#7a7b82"), (1.0, "#54555a")])
    img.paste(hub, (0, 0), disc(r_hub))
    shade(ring(r_hub - 0.004 * N, r_hub), "#26272a", 0.65)
    shade(ring(r_hub - 0.013 * N, r_hub - 0.004 * N), "#a6a7ad", 0.35)

    # Collar krom bergerigi. Sembilan gigi, sama seperti klip pengunci pelat.
    lobes = Image.new("L", (N, N), 0)
    pts = []
    for i in range(1440):
        t = 2 * math.pi * i / 1440
        rr = r_lobe + 0.009 * N * math.cos(9 * t)
        pts.append((C + rr * math.cos(t), C + rr * math.sin(t)))
    ImageDraw.Draw(lobes).polygon(pts, fill=255)

    chrome = vgrad([
        (0.00, "#f2f3f5"), (0.13, "#b6b9be"), (0.30, "#7b7e84"),
        (0.44, "#dfe1e6"), (0.56, "#eef0f3"), (0.72, "#878a90"),
        (0.86, "#c4c7cc"), (1.00, "#6d7075"),
    ])
    # Bayangan jatuh lebih dulu, baru collar-nya — tanpa ini gigi-giginya
    # tampak dicetak di permukaan, bukan diletakkan di atasnya.
    drop = lobes.filter(ImageFilter.GaussianBlur(0.008 * N))
    img.paste(solid("#121316"),
              (0, int(0.006 * N)), drop.point(lambda v: int(v * 0.55)))
    img.paste(chrome, (0, 0), lobes)

    img.paste(solid("#5f6267"), (0, 0), ring(r_chrome, r_chrome + 0.004 * N))
    img.paste(chrome, (0, 0), disc(r_chrome))
    shade(ring(r_mid, r_chrome), "#000000", 0.18)
    img.paste(chrome.rotate(180), (0, 0), disc(r_mid))

    # Lubang tengah, dengan bayangan dalam di bibir atasnya.
    img.paste(solid("#050506"), (0, 0), disc(r_hole))
    img.paste(solid("#c9ccd0"),
              (0, 0), ring(r_hole, r_hole + 0.005 * N).point(lambda v: int(v * 0.5)))
    return img, R


def render(inset_pct, plate_scale=1.0, rounded=True, bg_bleed=False):
    """Satu gambar ikon.

    `rounded` mematikan sudut transparan — iOS memotong sendiri bentuknya, dan
    ikon maskable PWA harus memenuhi seluruh persegi.
    """
    inset = inset_pct * N
    mask = squircle_mask(inset) if rounded else Image.new("L", (N, N), 255)

    bg = vgrad([
        (0.00, "#2e2e31"), (0.12, "#202023"), (0.32, "#121215"),
        (0.44, "#0c0c0e"), (0.46, "#060607"), (1.00, "#000000"),
    ])
    canvas = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    canvas.paste(bg, (0, 0), mask)

    # Kilap iOS lama: lengkung lebar yang berhenti sedikit di atas tengah.
    gloss = Image.new("L", (N, N), 0)
    ImageDraw.Draw(gloss).ellipse([-N * 0.55, -N * 0.62, N * 1.55, N * 0.47], fill=255)
    gloss = Image.composite(gloss, Image.new("L", (N, N), 0), mask)
    gloss = Image.composite(
        gloss.point(lambda v: int(v * 0.11)),
        Image.new("L", (N, N), 0),
        vgrad([(0.0, "#ffffff"), (0.45, "#3a3a3a"), (0.5, "#000000")]).convert("L"),
    )
    canvas.paste(solid("#ffffff"), (0, 0), gloss.filter(ImageFilter.GaussianBlur(2 * SS)))

    p, R = plate()
    if plate_scale != 1.0:
        s = int(N * plate_scale)
        p = p.resize((s, s), Image.LANCZOS)
        off = (N - s) // 2
        shifted = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        shifted.paste(p, (off, off))
        p = shifted
        R = R * plate_scale

    # Bayangan pelat ke latar: turun sedikit, lembut.
    sh = Image.new("L", (N, N), 0)
    ImageDraw.Draw(sh).ellipse(
        [C - R, C - R + 0.018 * N, C + R, C + R + 0.018 * N], fill=190)
    sh = sh.filter(ImageFilter.GaussianBlur(0.022 * N))
    sh = Image.composite(sh, Image.new("L", (N, N), 0), mask)
    canvas.paste(solid("#000000"), (0, 0), sh)
    canvas = Image.alpha_composite(canvas, p)

    if rounded:
        # Garis tepi tipis: terang di atas, hampir hilang di bawah.
        edge = Image.new("L", (N, N), 0)
        ImageDraw.Draw(edge).line(squircle(inset) + [squircle(inset)[0]],
                                  fill=255, width=max(2, int(0.0035 * N)), joint="curve")
        edge = Image.composite(
            edge, Image.new("L", (N, N), 0),
            vgrad([(0.0, "#ffffff"), (0.55, "#6a6a6a"), (1.0, "#2a2a2a")]).convert("L"))
        canvas.paste(solid("#b9bcc0"), (0, 0), edge.point(lambda v: int(v * 0.85)))
        canvas.putalpha(Image.composite(canvas.getchannel("A"), Image.new("L", (N, N), 0), mask))

    if bg_bleed:
        flat = Image.new("RGB", (N, N), rgb("#000000"))
        flat.paste(canvas.convert("RGB"), (0, 0), canvas.getchannel("A"))
        return flat
    return canvas


def save(img, path, size, flatten=False):
    path = os.path.join(APP, path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out = img.resize((size, size), Image.LANCZOS)
    if flatten:
        bg = Image.new("RGB", out.size, rgb("#000000"))
        if out.mode == "RGBA":
            bg.paste(out, (0, 0), out)
        else:
            bg.paste(out, (0, 0))
        out = bg
    out.save(path, "PNG", optimize=True)
    return path, size


def main():
    # Tiga varian: sudut bulat untuk tempat yang tidak memotong sendiri,
    # penuh-persegi untuk iOS dan ikon maskable.
    round_icon = render(0.055)
    ios_icon = render(0.012, bg_bleed=True)
    # Maskable PWA: lambangnya harus muat di lingkaran aman 80% tengah.
    maskable = render(0.0, plate_scale=0.74, rounded=False, bg_bleed=True)

    written = []
    ios = "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-{}.png"
    for name, size in [
        ("20x20@1x", 20), ("20x20@2x", 40), ("20x20@3x", 60),
        ("29x29@1x", 29), ("29x29@2x", 58), ("29x29@3x", 87),
        ("40x40@1x", 40), ("40x40@2x", 80), ("40x40@3x", 120),
        ("60x60@2x", 120), ("60x60@3x", 180),
        ("76x76@1x", 76), ("76x76@2x", 152),
        ("83.5x83.5@2x", 167), ("1024x1024@1x", 1024),
    ]:
        written.append(save(ios_icon, ios.format(name), size, flatten=True))

    for folder, size in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
                         ("xxhdpi", 144), ("xxxhdpi", 192)]:
        written.append(save(round_icon,
                            f"android/app/src/main/res/mipmap-{folder}/ic_launcher.png", size))

    written.append(save(round_icon, "web/icons/Icon-192.png", 192))
    written.append(save(round_icon, "web/icons/Icon-512.png", 512))
    written.append(save(maskable, "web/icons/Icon-maskable-192.png", 192))
    written.append(save(maskable, "web/icons/Icon-maskable-512.png", 512))
    written.append(save(round_icon, "web/favicon.png", 32))

    # Dipakai layar masuk dan daftar, supaya lambang di dalam aplikasi dan
    # ikon di layar Home benar-benar barang yang sama.
    # 256 px: layar 3x butuh 168 px untuk lambang 56 pt, sisanya cuma berat.
    written.append(save(round_icon, "assets/brand/app_icon.png", 256))

    for path, size in written:
        print(f"{size:>5}  {os.path.relpath(path, HERE)}")


if __name__ == "__main__":
    main()
