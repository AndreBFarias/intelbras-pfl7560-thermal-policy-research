#!/usr/bin/env python3
"""Prova offline dos padrões do kit (bloco 7, etapa C2). Não toca no aparelho.

Uso:  python3 -I tests/simula-padroes-kit.py [pasta-dos-png]
      (padrão: pendrive-autorun/kit)

Simula sobre os PNG reais as duas rotações de 2 bits que separam VESA de JEIDA
(esquerda e direita, iguais em R, G e B) e, depois delas, o pipeline de imagem do
aparelho como uma curva MONÓTONA aleatória (gamma 0,6 a 1,6, offset de -10 a +10),
e confere sobre a escada (calibracao, escada-1, escada-2):
  1. geometria: 16 faixas, níveis 10 + 15k, 34 px de altura, passo 50 px a partir
     de y = 140, separadas por preto; texto só em bandas de preto e branco PUROS
     (0 e 255) acima de y = 140 e a partir de y = 940;
  2. formato certo (sem rotação): 0 inversões, com qualquer curva monótona;
  3. formato errado (rotl2 ou rotr2): no mínimo 3 inversões, em todas as curvas;
  4. calibracao: faixas em 255 sobre 0 nas mesmas posições, e a rotação não a muda
     (é por ela que a câmera acha as faixas sem depender do formato);
  5. as bandas de texto e as telas só de texto (0 e 255 puros) não mudam com a
     rotação: a instrução fica legível nos dois formatos.
A inversão é a do nl_camcheck: diferença entre faixas vizinhas maior que 3 % da
amplitude; vale o MENOR entre quedas e subidas (a câmera entrega o quadro girado).
Sai com código != 0 se qualquer afirmação falhar.
"""
import os
import random
import sys

import numpy as np
from PIL import Image

LARGURA, ALTURA = 1920, 1080
# Mesma geometria de tests/gerar-padroes-kit.py (a conferência abaixo pega divergência).
NFAIXAS = 16
NIVEIS = [10 + 15 * k for k in range(NFAIXAS)]
FAIXA_ALTURA = 34
FAIXA_PASSO = 50
FAIXA_Y0 = 140
BANDA_TOPO = (0, FAIXA_Y0)
BANDA_BASE = (940, ALTURA)

ESCADAS = ("escada-1.png", "escada-2.png")
CALIBRACAO = "calibracao.png"
SO_TEXTO = ("aguarde.png", "reiniciando.png", "pronto.png", "erro.png", "corrigida.png")

MIN_INVERSOES_ERRADO = 3
MARGEM = 0.03
CURVAS = 400          # curvas aleatórias por formato
SEMENTE = 7560


def rotl2(a):
    """Rotação de 2 bits à esquerda em 8 bits (um sentido da troca VESA/JEIDA)."""
    a = np.asarray(a).astype(np.uint16)
    return (((a << 2) | (a >> 6)) & 0xFF).astype(np.uint8)


def rotr2(a):
    """Rotação de 2 bits à direita em 8 bits (o sentido contrário)."""
    a = np.asarray(a).astype(np.uint16)
    return (((a >> 2) | (a << 6)) & 0xFF).astype(np.uint8)


FORMATOS = (
    ("certo (sem rotacao)", lambda a: np.asarray(a).astype(np.uint8)),
    ("errado, rotl2", rotl2),
    ("errado, rotr2", rotr2),
)


def curva_aleatoria(rng):
    """Curva monótona crescente 0..255 -> 0..255: gamma e offset (como o pipeline)."""
    g = rng.uniform(0.6, 1.6)
    off = rng.uniform(-10, 10)
    return lambda v: np.clip(255.0 * (np.asarray(v, dtype=float) / 255.0) ** g + off, 0, 255)


def inversoes(niveis):
    """(quedas, subidas) entre vizinhas, com margem de 3 % da amplitude (= nl_camcheck)."""
    n = [float(x) for x in niveis]
    margem = MARGEM * (max(n) - min(n))
    quedas = sum(1 for a, b in zip(n, n[1:]) if a - b > margem)
    subidas = sum(1 for a, b in zip(n, n[1:]) if b - a > margem)
    return quedas, subidas


def faixas_y():
    return [(FAIXA_Y0 + k * FAIXA_PASSO, FAIXA_Y0 + k * FAIXA_PASSO + FAIXA_ALTURA)
            for k in range(NFAIXAS)]


def carregar(pasta, nome):
    img = Image.open(os.path.join(pasta, nome))
    if img.size != (LARGURA, ALTURA):
        sys.exit("FALHA: %s tem %s, esperado %dx%d" % (nome, img.size, LARGURA, ALTURA))
    return np.asarray(img.convert("RGB"))


def confere_geometria(nome, img, niveis):
    """Faixas nos níveis certos, preto entre elas e texto só em 0/255 nas bandas."""
    ok = True
    pretos = np.ones(ALTURA, dtype=bool)
    for (y0, y1), nivel in zip(faixas_y(), niveis):
        if not np.all(img[y0:y1] == nivel):
            print("FALHA: %s: faixa %d..%d nao e %d uniforme" % (nome, y0, y1, nivel))
            ok = False
        pretos[y0:y1] = False
    entre = np.where(pretos)[0]
    entre = entre[(entre >= FAIXA_Y0) & (entre < BANDA_BASE[0])]
    if not np.all(img[entre] == 0):
        print("FALHA: %s: o espaco entre as faixas nao e preto puro" % nome)
        ok = False
    for banda in (BANDA_TOPO, BANDA_BASE):
        y0, y1 = banda
        if not np.isin(img[y0:y1], (0, 255)).all():
            print("FALHA: %s: banda de texto %s tem valor fora de {0,255}" % (nome, banda))
            ok = False
    return ok


def main():
    pasta = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "pendrive-autorun", "kit")
    falhas = 0

    # as bandas de texto nao mudam com a rotacao (so 0 e 255) -- escadas e calibracao
    print("%-14s %-22s %10s %10s" % ("padrao", "formato", "inv. min", "inv. max"))
    for nome in ESCADAS:
        img = carregar(pasta, nome)
        if not confere_geometria(nome, img, NIVEIS):
            falhas += 1
        # nivel de cada faixa lido do PNG (centro da faixa, coluna do meio)
        lidos = [int(img[(y0 + y1) // 2, LARGURA // 2, 0]) for y0, y1 in faixas_y()]
        if lidos != NIVEIS:
            print("FALHA: %s: niveis lidos %s diferem de 10+15k" % (nome, lidos))
            falhas += 1
        for rotulo, rot in FORMATOS[1:]:
            sim = rot(img)
            for banda in (BANDA_TOPO, BANDA_BASE):
                y0, y1 = banda
                if not np.array_equal(sim[y0:y1], img[y0:y1]):
                    print("FALHA: %s: banda de texto %s muda com %s" % (nome, banda, rotulo))
                    falhas += 1
        # curvas aleatorias monotonas, nos tres formatos
        rng = random.Random(SEMENTE)
        for rotulo, rot in FORMATOS:
            certo = rot is FORMATOS[0][1]
            menores = []
            for _ in range(CURVAS):
                f = curva_aleatoria(rng)
                niv = f(rot(np.array(lidos)))
                q, s = inversoes(niv)
                menores.append(min(q, s))
            if certo:
                ok = max(menores) == 0
            else:
                ok = min(menores) >= MIN_INVERSOES_ERRADO
            print("%-14s %-22s %10d %10d  %s" % (nome, rotulo, min(menores), max(menores),
                                                 "ok" if ok else "FALHA"))
            falhas += 0 if ok else 1

    # calibracao: branco 255 nas faixas, preto 0 no resto, igual nos dois formatos
    cal = carregar(pasta, CALIBRACAO)
    if not confere_geometria(CALIBRACAO, cal, [255] * NFAIXAS):
        falhas += 1
    if not np.isin(cal, (0, 255)).all():
        print("FALHA: %s tem valor fora de {0,255}" % CALIBRACAO)
        falhas += 1
    for rotulo, rot in FORMATOS[1:]:
        if not np.array_equal(rot(cal), cal):
            print("FALHA: %s muda com %s" % (CALIBRACAO, rotulo))
            falhas += 1
    mascara = cal[:, :, 0] == 255
    esc = carregar(pasta, ESCADAS[0])
    if not np.array_equal(mascara[FAIXA_Y0:BANDA_BASE[0]], (esc[:, :, 0] > 0)[FAIXA_Y0:BANDA_BASE[0]]):
        print("FALHA: as faixas da calibracao nao coincidem com as da escada")
        falhas += 1
    print("%-14s so 0/255, faixas brancas nas posicoes da escada, igual nos dois formatos  ok" % CALIBRACAO)

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

    # o criterio e o mesmo do nl_camcheck: confere com os valores medidos no aparelho
    jeida = [235, 235, 235, 235, 235, 232, 222, 210, 197, 181, 164, 141, 114, 91, 72, 63]
    vesa = [235, 235, 235, 231, 192, 148, 105, 86, 220, 212, 156, 90, 185, 116, 195, 128]
    if inversoes(jeida) != (10, 0) or inversoes(vesa) != (9, 3):
        print("FALHA: inversoes() nao reproduz o nl_camcheck nas medidas reais: %s %s"
              % (inversoes(jeida), inversoes(vesa)))
        falhas += 1

    if falhas:
        print("RESULTADO: %d falha(s)" % falhas)
        sys.exit(1)
    print("RESULTADO: padroes ok (certo = 0 inversoes, errado >= %d, %d curvas por formato)"
          % (MIN_INVERSOES_ERRADO, CURVAS))


if __name__ == "__main__":
    main()
