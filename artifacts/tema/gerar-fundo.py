#!/usr/bin/env python3
"""Gera o plano de fundo Dracula 1920x1080 (bloco 10B): artifacts/tema/fundo-dracula.png.

  python3 -I artifacts/tema/gerar-fundo.py [saida.png]

Sobrio e sem texto: um gradiente sutil do token fundo (alto, a esquerda) para o token linha
(baixo, a direita), com um unico arco fino em roxo no canto de baixo a direita. As cores vem de
artifacts/tema/dracula.txt (a fonte unica da paleta). So a biblioteca padrao (zlib, struct):
o PNG e escrito a mao. Reprodutivel: sem aleatoriedade (o pontilhado que evita faixas no
gradiente e uma matriz de Bayer 8x8), a mesma entrada da os mesmos bytes.
"""
import math
import os
import struct
import sys
import zlib

AQUI = os.path.dirname(os.path.abspath(__file__))
LARG, ALT = 1920, 1080

# matriz de Bayer 8x8 (0..63): pontilhado ordenado, deterministico
BAYER = [[0, 32, 8, 40, 2, 34, 10, 42], [48, 16, 56, 24, 50, 18, 58, 26],
         [12, 44, 4, 36, 14, 46, 6, 38], [60, 28, 52, 20, 62, 30, 54, 22],
         [3, 35, 11, 43, 1, 33, 9, 41], [51, 19, 59, 27, 49, 17, 57, 25],
         [15, 47, 7, 39, 13, 45, 5, 37], [63, 31, 55, 23, 61, 29, 53, 21]]

# arco em roxo: centro fora da tela, embaixo a direita; so um traco fino e meio transparente
ARCO_CX, ARCO_CY, ARCO_R = 1700.0, 1420.0, 640.0
ARCO_LARG = 3.0          # px: no projetor, 2 px some
ARCO_OPAC = 0.6


def paleta():
    cores = {}
    with open(os.path.join(AQUI, "dracula.txt"), encoding="ascii") as f:
        for ln in f:
            ln = ln.strip()
            if ln and not ln.startswith("#"):
                k, v = ln.split("=")
                cores[k] = tuple(int(v[i:i + 2], 16) for i in (1, 3, 5))
    return cores


def lin(c):
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def srgb(l):
    c = l * 12.92 if l <= 0.0031308 else 1.055 * l ** (1 / 2.4) - 0.055
    return c * 255.0


def gerar():
    p = paleta()
    a, b, roxo = p["fundo"], p["linha"], p["roxo"]
    roxo_lin = [lin(c) for c in roxo]
    linhas = []
    for y in range(ALT):
        fy = y / (ALT - 1)
        brow = BAYER[y & 7]
        # faixa de x onde o arco pode cair nesta linha (economiza conta)
        dy = y + 0.5 - ARCO_CY
        xs = []
        for r in (ARCO_R - ARCO_LARG - 1, ARCO_R + ARCO_LARG + 1):
            if r > abs(dy):
                xs.append(math.sqrt(r * r - dy * dy))
        faixa = None
        if len(xs) == 2:
            faixa = (int(ARCO_CX - xs[1]) - 1, int(ARCO_CX - xs[0]) + 2,
                     int(ARCO_CX + xs[0]) - 1, int(ARCO_CX + xs[1]) + 2)
        elif len(xs) == 1:
            faixa = (int(ARCO_CX - xs[0]) - 1, int(ARCO_CX + xs[0]) + 2, 0, 0)
        out = bytearray(1 + 3 * LARG)  # filtro 0
        for x in range(LARG):
            fx = x / (LARG - 1)
            # diagonal suave, com curva: a maior parte da tela fica perto do fundo
            t = (0.38 * fx + 0.62 * fy) ** 1.7
            cor = [a[k] + (b[k] - a[k]) * t for k in range(3)]
            if faixa and (faixa[0] <= x < faixa[1] or faixa[2] <= x < faixa[3]):
                d = abs(math.hypot(x + 0.5 - ARCO_CX, dy) - ARCO_R)
                cob = min(1.0, max(0.0, ARCO_LARG / 2 + 0.5 - d)) * ARCO_OPAC
                if cob > 0:
                    cor = [srgb(lin(c) + (roxo_lin[k] - lin(c)) * cob) for k, c in enumerate(cor)]
            lim = (brow[x & 7] + 0.5) / 64.0
            o = 1 + 3 * x
            for k in range(3):
                v = cor[k]
                i = int(v)
                out[o + k] = min(255, i + (1 if v - i > lim else 0))
        linhas.append(bytes(out))
    return b"".join(linhas)


def png(dados):
    def bloco(tipo, c):
        return struct.pack(">I", len(c)) + tipo + c + struct.pack(">I", zlib.crc32(tipo + c) & 0xFFFFFFFF)
    ihdr = struct.pack(">IIBBBBB", LARG, ALT, 8, 2, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + bloco(b"IHDR", ihdr)
            + bloco(b"IDAT", zlib.compress(dados, 9)) + bloco(b"IEND", b""))


def main():
    saida = sys.argv[1] if len(sys.argv) > 1 else os.path.join(AQUI, "fundo-dracula.png")
    with open(saida, "wb") as f:
        f.write(png(gerar()))
    print("gerado", saida)


main()
