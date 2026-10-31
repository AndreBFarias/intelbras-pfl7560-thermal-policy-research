#!/usr/bin/env python3
import io
import os
import sys
import zipfile

from PIL import Image, ImageDraw, ImageFont

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAIDA = os.environ.get("PFL_MARCA_SAIDA") or os.path.join(RAIZ, "artifacts", "tema", "marca")
FONTE = os.path.join(RAIZ, "pendrive-autorun", "fontes", "IBMPlexSansCondensed-Bold.ttf")
L, A = 1920, 1080

FUNDO = (0x12, 0x0B, 0x1A)
NOME = (0x9D, 0x7A, 0xD0)
SUPER = 2
TEXTO = "MeowCast"

CANTOS_DONO = ("95,915", "1715,1030", "40,25", "1775,35")

def plana():
    im = Image.new("RGB", (L * SUPER, A * SUPER), FUNDO)
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(FONTE, 160 * SUPER)
    x0, y0, x1, y1 = d.textbbox((0, 0), TEXTO, font=f)
    d.text(((L * SUPER - (x1 - x0)) // 2 - x0, (A * SUPER - (y1 - y0)) // 2 - y0), TEXTO, font=f, fill=NOME)
    return im.resize((L, A), Image.LANCZOS)

def resolve(m, v):
    n = len(v)
    a = [list(m[i]) + [v[i]] for i in range(n)]
    for c in range(n):
        p = max(range(c, n), key=lambda r: abs(a[r][c]))
        a[c], a[p] = a[p], a[c]
        for r in range(n):
            if r != c:
                k = a[r][c] / a[c][c]
                a[r] = [x - k * y for x, y in zip(a[r], a[c])]
    return [a[i][n] / a[i][i] for i in range(n)]

def distorcida(im, cantos):
    pts = []
    for c in cantos:
        x, y = (int(t) for t in c.split(","))
        pts.append((x, A - y))
    lt, rt, lb, rb = pts
    destino = [lt, rt, rb, lb]
    origem = [(0, 0), (L, 0), (L, A), (0, A)]
    m, v = [], []
    for (xd, yd), (xo, yo) in zip(destino, origem):
        m.append([xd, yd, 1, 0, 0, 0, -xo * xd, -xo * yd]); v.append(xo)
        m.append([0, 0, 0, xd, yd, 1, -yo * xd, -yo * yd]); v.append(yo)
    coef = resolve(m, v)
    return im.transform((L, A), Image.PERSPECTIVE, coef, Image.BICUBIC, fillcolor=(0, 0, 0))

def jpeg(im):
    b = io.BytesIO()
    im.save(b, "JPEG", quality=95, optimize=False, subsampling=0)
    return b.getvalue()

def main():
    cantos = sys.argv[1:5] if len(sys.argv) >= 5 else CANTOS_DONO
    os.makedirs(SAIDA, exist_ok=True)
    im = plana()
    j_plana = jpeg(im)
    j_boot = jpeg(distorcida(im, cantos))
    open(os.path.join(SAIDA, "logo.jpg"), "wb").write(j_plana)
    open(os.path.join(SAIDA, "logo-boot.jpg"), "wb").write(j_boot)
    zi = lambda nome: zipfile.ZipInfo(nome, date_time=(2026, 10, 31, 0, 0, 0))
    with zipfile.ZipFile(os.path.join(SAIDA, "bootanimation.zip"), "w", zipfile.ZIP_STORED) as z:
        z.writestr(zi("desc.txt"), "%d %d 1\np 0 0 part0\n" % (L, A))
        z.writestr(zi("part0/0.jpg"), j_plana)
    print("cantos:", " ".join(cantos))
    for n in ("logo.jpg", "logo-boot.jpg", "bootanimation.zip"):
        print("%-18s %d bytes" % (n, os.path.getsize(os.path.join(SAIDA, n))))

if __name__ == "__main__":
    main()
