"""Turunkan glyph antarmuka yang tidak ada di paket Barudak Lier dari SVG yang
sudah ada di design/iconscout/icons.

Paket "Basic UI" tidak punya chevron, panah polos, minus, lingkaran kosong,
awan dicoret/awan centang, dan centang ganda. Menggambar ulang dari nol atau
mengambil paket lain membuat ketebalan garis dan ujungnya tidak cocok, jadi
glyph ini disusun dari potongan ikon Barudak Lier yang sudah dibeli: cincin dan
batang dari plus-sign, panah dari download, tanda seru dari info yang diputar.
Yang memang harus digambar (chevron, centang ganda, coretan awan) memakai
konstruksi garis paket itu sendiri: lebar 3 unit di kanvas 32, ujung dan
sambungan bulat — sama dengan centang approve-3461442. Sumber tiap glyph
tercatat di design/iconscout/SOURCES.md.

Font ikon hanya menggambar isian, jadi semua garis diubah jadi kontur tertutup
(skia-pathops) sebelum ditulis.

Cara pakai (fontTools + skia-pathops, lihat SOURCES.md):
  PYTHONPATH=D:/sdk/tmp/pyfonts python scripts/derive-gym-icons.py
Lalu bangun ulang fontnya.
"""
import math
import os
import re

import pathops
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.svgLib.path import parse_path

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
icons = os.path.join(root, 'design', 'iconscout', 'icons')

# Lebar garis paket Basic UI: busur ujungnya berjari-jari 1,5 di kanvas 32.
W = 3.0


def paths_of(name):
    """Semua atribut d dari satu berkas SVG, berurutan."""
    src = open(os.path.join(icons, name + '.svg'), encoding='utf-8').read()
    return re.findall(r'\sd="([^"]+)"', src)


def to_path(d):
    p = pathops.Path()
    parse_path(d, p.getPen())
    return p


def union(*ps):
    out = pathops.Path()
    for p in ps:
        out = pathops.op(out, p, pathops.PathOp.UNION)
    return out


def minus(a, b):
    return pathops.op(a, b, pathops.PathOp.DIFFERENCE)


def stroke(*pts, width=W):
    """Polyline berujung dan bersambungan bulat, sudah jadi kontur isian."""
    p = pathops.Path()
    p.moveTo(*pts[0])
    for pt in pts[1:]:
        p.lineTo(*pt)
    p.stroke(width, pathops.LineCap.ROUND_CAP, pathops.LineJoin.ROUND_JOIN, 4)
    # Skia menulis ujung bulat sebagai conic; font TrueType hanya kenal kurva
    # kuadrat, dan operasi boolean pathops juga menolak conic.
    p.convertConicsToQuads()
    return union(p)


def rotate(p, deg, cx=16.0, cy=16.0):
    # Sumbu y SVG mengarah ke bawah, jadi sudut positif = searah jarum jam.
    r = math.radians(deg)
    c, s = math.cos(r), math.sin(r)
    return p.transform(c, s, -s, c, cx - c * cx + s * cy, cy - s * cx - c * cy)


def move(p, dx, dy):
    return p.transform(1, 0, 0, 1, dx, dy)


def centred(p):
    x0, y0, x1, y1 = p.bounds
    return move(p, 16 - (x0 + x1) / 2, 16 - (y0 + y1) / 2)


def num(x):
    s = f'{x:.3f}'.rstrip('0').rstrip('.')
    return '0' if s in ('-0', '') else s


def write(name, p):
    pen = SVGPathPen(None, ntos=num)
    p.draw(pen)
    d = pen.getCommands()
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" id="{name}">'
           f'<path d="{d}" fill="#000000"></path></svg>')
    open(os.path.join(icons, f'ui_{name}.svg'), 'w', encoding='utf-8', newline='\n').write(svg)
    x0, y0, x1, y1 = p.bounds
    print(f'ui_{name}: {x0:.1f},{y0:.1f} - {x1:.1f},{y1:.1f}')


# plus-sign-3460760: kontur pertama cincin, kedua tanda tambah.
ring_d, cross_d = paths_of('ui_plus')
ring = to_path(ring_d)
# Batang mendatar tanda tambah yang sama, supaya minus dan plus sama panjang
# dan sama tebal saat berdampingan di stepper.
bar = to_path('M7.294 14.5a1.5 1.5 0 1 0 0 3h17.412a1.5 1.5 0 1 0 0-3H7.294z')
write('add', union(to_path(cross_d)))
write('minus', bar)
write('circle', union(ring))
write('minus-circle', union(ring, bar))

# info-sign-3460725 diputar 180°: titik pindah ke bawah, jadi tanda seru.
info_ring, info_mark = paths_of('ui_info')
write('alert', union(to_path(info_ring), rotate(to_path(info_mark), 180)))

# Panah dari download-3460695 (kontur pertama), dipusatkan lalu diputar.
arrow = centred(union(to_path(paths_of('ui_download')[0])))
for name, deg in [('arrow-down', 0), ('arrow-up', 180), ('arrow-left', 90),
                  ('arrow-right', -90), ('arrow-down-right', -45), ('arrow-up-right', -135)]:
    write(name, rotate(arrow, deg))

# Chevron: sudut 45° seperti "left" di paket Elements UI (Barudak Lier), tapi
# garisnya 3 unit supaya setebal Basic UI; ukurannya setara chevron Material
# agar baris daftar tidak berubah proporsi.
chevron = stroke((9, 12.5), (16, 19.5), (23, 12.5))
write('chevron-down', chevron)
write('chevron-up', rotate(chevron, 180))
write('chevron-right', rotate(chevron, -90))

# Dua kali ⇅ data-transfer-3460691 (tanpa cincin) diputar 90° menjadi ⇄.
write('swap', rotate(union(to_path(paths_of('ui_data-transfer')[1])), 90))

# Centang ganda: dua centang dengan konstruksi approve-3461442; centang kedua
# berhenti sebelum menyentuh lengan panjang centang pertama.
write('check-double', union(
    stroke((2.7, 16), (9.3, 22.7), (24, 8)),
    stroke((17.3, 21.3), (19.3, 23.3), (29.3, 13.3)),
))

# cloud-3460681 dengan coretan: awan dipotong selebar celah di sepanjang
# coretan, baru coretannya ditambahkan — seperti eye-off di paket yang sama.
cloud = union(to_path(paths_of('ui_cloud')[0]))
slash = ((4.5, 4.5), (27.5, 27.5))
write('cloud-off', union(minus(cloud, stroke(*slash, width=W + 3)), stroke(*slash)))
# Awan dengan centang kecil di dalamnya (sinkron selesai).
write('cloud-check', union(cloud, stroke((11.6, 18.1), (14.4, 20.9), (20.4, 14.9))))
