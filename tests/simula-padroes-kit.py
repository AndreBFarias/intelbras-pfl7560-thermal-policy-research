#!/usr/bin/env python3
"""Prova offline dos padrões do kit (bloco 5, etapa E2). Não toca no aparelho.

Uso:  python3 -I tests/simula-padroes-kit.py [pasta-dos-png]
      (padrão: pendrive-autorun/kit)

Simula sobre os PNG reais as duas rotações de 2 bits que separam VESA de JEIDA
(esquerda e direita, iguais em R, G e B) e confere:
  1. no formato certo, as metades 63|64 e 127|128 saem iguais:
     |L-R|/(L+R) < 0,01;
  2. nos dois formatos errados, a mesma razão fica > 0,6 (em ambas as faixas);
  3. as bandas de texto e as telas só de texto (0 e 255 puros) não mudam com a
     rotação: a instrução fica legível nos dois formatos.
Sai com código != 0 se qualquer afirmação falhar.
"""
import os
import sys

import numpy as np
from PIL import Image

LARGURA, ALTURA = 1920, 1080
# Mesma geometria de tests/gerar-padroes-kit.py (a conferência abaixo pega divergência).
BANDA_TOPO = (0, 230)
FAIXA_A = (230, 580)
FAIXA_B = (580, 830)
BANDA_BASE = (830, 1080)
CINZAS_A = (63, 64)
CINZAS_B = (127, 128)
META = LARGURA // 2

PADROES = ("metades-1.png", "metades-2.png")
SO_TEXTO = ("aguarde.png", "reiniciando.png", "pronto.png", "erro.png")

LIMITE_IGUAIS = 0.01
LIMITE_DIFERENTES = 0.6


def rotl2(a):
    """Rotação de 2 bits à esquerda em 8 bits (um sentido da troca VESA/JEIDA)."""
    a = a.astype(np.uint16)
    return (((a << 2) | (a >> 6)) & 0xFF).astype(np.uint8)


def rotr2(a):
    """Rotação de 2 bits à direita em 8 bits (o sentido contrário)."""
    a = a.astype(np.uint16)
    return (((a >> 2) | (a << 6)) & 0xFF).astype(np.uint8)


FORMATOS = (
    ("certo (sem rotacao)", lambda a: a),
    ("errado, rotl2 (63|64 -> 252|1)", rotl2),
    ("errado, rotr2 (63|64 -> 207|16)", rotr2),
)


def razao(img, faixa):
    y0, y1 = faixa
    esq = float(img[y0:y1, :META, :].mean())
    dir_ = float(img[y0:y1, META:, :].mean())
    return abs(esq - dir_) / (esq + dir_)


def carregar(pasta, nome):
    img = Image.open(os.path.join(pasta, nome))
    if img.size != (LARGURA, ALTURA):
        sys.exit("FALHA: %s tem %s, esperado %dx%d" % (nome, img.size, LARGURA, ALTURA))
    return np.asarray(img.convert("RGB"))


def confere_geometria(nome, img):
    for faixa, cinzas in ((FAIXA_A, CINZAS_A), (FAIXA_B, CINZAS_B)):
        y0, y1 = faixa
        if not (np.all(img[y0:y1, :META] == cinzas[0]) and np.all(img[y0:y1, META:] == cinzas[1])):
            sys.exit("FALHA: %s: faixa %s nao e %d|%d (geometria divergente do gerador)"
                     % (nome, faixa, cinzas[0], cinzas[1]))
    for banda in (BANDA_TOPO, BANDA_BASE):
        y0, y1 = banda
        if not np.isin(img[y0:y1], (0, 255)).all():
            sys.exit("FALHA: %s: banda %s tem valor fora de {0,255}" % (nome, banda))


def main():
    pasta = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "pendrive-autorun", "kit")
    falhas = 0

    print("%-14s %-34s %10s %10s" % ("padrao", "formato", "63|64", "127|128"))
    for nome in PADROES:
        img = carregar(pasta, nome)
        confere_geometria(nome, img)
        for rotulo, rot in FORMATOS:
            sim = rot(img)
            ra, rb = razao(sim, FAIXA_A), razao(sim, FAIXA_B)
            certo = rot is FORMATOS[0][1]
            if certo:
                ok = ra < LIMITE_IGUAIS and rb < LIMITE_IGUAIS
            else:
                ok = ra > LIMITE_DIFERENTES and rb > LIMITE_DIFERENTES
            print("%-14s %-34s %10.4f %10.4f  %s" % (nome, rotulo, ra, rb, "ok" if ok else "FALHA"))
            falhas += 0 if ok else 1
        # a rotação não pode mexer nas bandas de texto
        for rotulo, rot in FORMATOS[1:]:
            sim = rot(img)
            for banda in (BANDA_TOPO, BANDA_BASE):
                y0, y1 = banda
                if not np.array_equal(sim[y0:y1], img[y0:y1]):
                    print("FALHA: %s: banda de texto %s muda com %s" % (nome, banda, rotulo))
                    falhas += 1
    for nome in SO_TEXTO:
        img = carregar(pasta, nome)
        if not np.isin(img, (0, 255)).all():
            print("FALHA: %s tem valor fora de {0,255}" % nome)
            falhas += 1
            continue
        for rotulo, rot in FORMATOS[1:]:
            if not np.array_equal(rot(img), img):
                print("FALHA: %s muda com %s" % (nome, rotulo))
                falhas += 1
        print("%-14s so 0/255, identico nos dois formatos errados  ok" % nome)

    # as duas rotações são inversas: o teste pega o erro nos dois sentidos
    v = np.arange(256, dtype=np.uint8)
    if not (np.array_equal(rotr2(rotl2(v)), v) and np.array_equal(rotl2(rotr2(v)), v)):
        print("FALHA: rotl2 e rotr2 nao sao inversas")
        falhas += 1

    if falhas:
        print("RESULTADO: %d falha(s)" % falhas)
        sys.exit(1)
    print("RESULTADO: padroes ok (certo < %.2f, errado > %.1f nos dois sentidos)"
          % (LIMITE_IGUAIS, LIMITE_DIFERENTES))


if __name__ == "__main__":
    main()
