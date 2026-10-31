#!/usr/bin/env python3
"""Gera os icones e os banners do app (PNG) nas pastas res/. Sem emoji: so formas simples,
no estilo das telas da suite (fundo #0E1116, traco claro #F2F3F5, acento verde #6FD6A6).

  python3 -I artifacts/app/gerar-icones.py

Precisa do Pillow. O texto dos banners usa a fonte IBM Plex (OFL) do kit, em
pendrive-autorun/fontes/. Saida deterministica: rodar de novo nao muda os bytes.
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

AQUI = os.path.dirname(os.path.abspath(__file__))
FONTE = os.path.join(AQUI, "..", "..", "pendrive-autorun", "fontes", "IBMPlexSansCondensed-SemiBold.ttf")
FUNDO = (0x0E, 0x11, 0x16)
CARTAO = (0x17, 0x1B, 0x21)
FIO = (0x2A, 0x30, 0x38)
TRACO = (0xF2, 0xF3, 0xF5)
OK = (0x6F, 0xD6, 0xA6)
SS = 4  # supersampling


def tela(lado):
    im = Image.new("RGB", (lado * SS, lado * SS), FUNDO)
    return im, ImageDraw.Draw(im)


def moldura(d, lado):
    s = lado * SS
    d.rounded_rectangle([s * 0.04, s * 0.04, s * 0.96, s * 0.96], radius=s * 0.18, fill=CARTAO, outline=FIO, width=max(2, SS))


def linha(d, pts, w, cor):
    d.line(pts, fill=cor, width=w, joint="curve")
    r = w / 2
    for x, y in (pts[0], pts[-1]):
        d.ellipse([x - r, y - r, x + r, y + r], fill=cor)


def icone_verificar(lado):
    im, d = tela(lado)
    s = lado * SS
    moldura(d, lado)
    c = s / 2
    r = s * 0.27
    w = int(s * 0.07)
    d.ellipse([c - r, c - r, c + r, c + r], outline=TRACO, width=w)
    linha(d, [(c - r * 0.45, c + r * 0.02), (c - r * 0.1, c + r * 0.38), (c + r * 0.52, c - r * 0.34)], w, OK)
    return im.resize((lado, lado), Image.LANCZOS)


def icone_wifi(lado):
    im, d = tela(lado)
    s = lado * SS
    moldura(d, lado)
    cx, cy = s / 2, s * 0.68
    w = int(s * 0.06)
    for raio in (0.18, 0.31, 0.44):
        r = s * raio
        d.arc([cx - r, cy - r, cx + r, cy + r], 225, 315, fill=TRACO, width=w)
    r = s * 0.045
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=TRACO)
    return im.resize((lado, lado), Image.LANCZOS)


def banner(fn, texto):
    lw, lh = 320, 180
    im = Image.new("RGB", (lw, lh), FUNDO)
    ic = fn(96)
    im.paste(ic, (28, (lh - 96) // 2))
    d = ImageDraw.Draw(im)
    fonte = ImageFont.truetype(FONTE, 23)
    d.text((136, lh // 2), texto, font=fonte, fill=TRACO, anchor="lm")
    return im


def salva(im, caminho):
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    im.save(caminho, "PNG", optimize=True)
    print("gerado", os.path.relpath(caminho, AQUI))


def main():
    if not os.path.isfile(FONTE):
        sys.exit("sem a fonte " + FONTE)
    for dens, lado in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
        salva(icone_verificar(lado), os.path.join(AQUI, "res", "mipmap-" + dens, "ic_verificar.png"))
        salva(icone_wifi(lado), os.path.join(AQUI, "res", "mipmap-" + dens, "ic_wifi.png"))
    salva(banner(icone_verificar, "Verificar projetor"), os.path.join(AQUI, "res", "drawable-xhdpi", "banner_verificar.png"))
    salva(banner(icone_wifi, "Wi-Fi"), os.path.join(AQUI, "res", "drawable-xhdpi", "banner_wifi.png"))


main()
