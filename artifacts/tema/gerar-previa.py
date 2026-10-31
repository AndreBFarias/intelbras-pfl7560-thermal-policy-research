#!/usr/bin/env python3
"""Folha de contato do tema Dracula (bloco 10B): artifacts/tema/previa/telas.png.

  bash tests/test-tela.sh                      # gera as telas em tests/saida/telas/
  python3 -I artifacts/tema/gerar-previa.py

Junta, em duas colunas, as 9 telas de exemplo da suite (tests/saida/telas/, os campos.txt do
dono em tests/fixtures/tela/) e o plano de fundo (artifacts/tema/fundo-dracula.png), cada uma
com o nome embaixo. So para olhar: nao vai para o kit. Precisa do Pillow.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.join(AQUI, "..", "..")
TELAS = os.path.join(RAIZ, "tests", "saida", "telas")
FONTE = os.path.join(RAIZ, "pendrive-autorun", "fontes", "IBMPlexMono-Regular.ttf")
NOMES = ["aviso-abertura-tomada", "aviso-abertura-pendrive", "aviso-etapa-temperatura",
         "aviso-alerta", "aviso-final-pendrive", "resumo-tudo-certo", "resumo-correcao",
         "resumo-atencao", "resumo-pendentes"]
FUNDO = (0x28, 0x2A, 0x36)
SEC = (0xB4, 0xBC, 0xCF)
FIO = (0x62, 0x72, 0xA4)
LW, LH, GAP, MARG, ROT = 960, 540, 32, 48, 44

def main():
    imgs = []
    for n in NOMES:
        p = os.path.join(TELAS, n + ".png")
        if not os.path.isfile(p):
            sys.exit("falta %s: rode antes  bash tests/test-tela.sh" % p)
        imgs.append((n, p))
    imgs.append(("fundo-dracula (plano de fundo)", os.path.join(AQUI, "fundo-dracula.png")))
    lin = (len(imgs) + 1) // 2
    w = 2 * MARG + 2 * LW + GAP
    h = 2 * MARG + lin * (LH + ROT) + (lin - 1) * GAP
    folha = Image.new("RGB", (w, h), FUNDO)
    d = ImageDraw.Draw(folha)
    fonte = ImageFont.truetype(FONTE, 22)
    for i, (nome, p) in enumerate(imgs):
        x = MARG + (i % 2) * (LW + GAP)
        y = MARG + (i // 2) * (LH + ROT + GAP)
        with Image.open(p) as im:
            folha.paste(im.convert("RGB").resize((LW, LH), Image.LANCZOS), (x, y))
        d.rectangle([x - 1, y - 1, x + LW, y + LH], outline=FIO, width=1)
        d.text((x, y + LH + 12), nome, font=fonte, fill=SEC)
    os.makedirs(os.path.join(AQUI, "previa"), exist_ok=True)
    saida = os.path.join(AQUI, "previa", "telas.png")
    folha.save(saida, "PNG", optimize=True)
    print("gerado", os.path.relpath(saida, RAIZ))

main()
