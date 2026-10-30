#!/usr/bin/env python3
"""Gera os PNG 1920x1080 do kit universal de pendrive (bloco 5, etapa E2).

Uso:  python3 -I tests/gerar-padroes-kit.py [pasta-de-saida]
      (padrão: pendrive-autorun/kit)

Desenho (doc 41 §4): as telas do teste de cor trazem DUAS METADES de cinza,
63|64 em cima e 127|128 embaixo. VESA e JEIDA diferem por uma rotação de 2 bits
igual em R, G e B; no formato certo as metades saem iguais (63|64), no errado
viram 252|1 ou 207|16. Os textos ficam só em bandas de preto e branco PUROS
(0 e 255), os únicos valores que a rotação não altera, então a instrução
continua legível nos dois formatos.

Os PNG gerados são versionados e o md5 de cada um vai na lista embutida no
newlink_update.sh (tests/atualizar-md5-kit.sh). Este gerador existe para
reproduzir/ajustar os padrões; o md5 depende da fonte instalada na máquina.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

LARGURA, ALTURA = 1920, 1080
# Geometria compartilhada com tests/simula-padroes-kit.py (que a confere).
BANDA_TOPO = (0, 230)
FAIXA_A = (230, 580)      # cinza 63 | 64
FAIXA_B = (580, 830)      # cinza 127 | 128
BANDA_BASE = (830, 1080)
CINZAS_A = (63, 64)
CINZAS_B = (127, 128)

FONTES = (
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
)

PRETO = (0, 0, 0)
BRANCO = (255, 255, 255)


def carregar_fonte(tamanho):
    for caminho in FONTES:
        if os.path.exists(caminho):
            return ImageFont.truetype(caminho, tamanho)
    sys.exit("fonte DejaVu Sans Bold nao encontrada; instale fonts-dejavu-core")


def novo_quadro():
    img = Image.new("RGB", (LARGURA, ALTURA), PRETO)
    d = ImageDraw.Draw(img)
    d.fontmode = "1"  # sem antialiasing: so 0 e 255 nos textos
    return img, d


def texto_centrado(d, caixa, linhas, tamanho):
    """Escreve linhas brancas centradas verticalmente na caixa (y0, y1)."""
    fonte = carregar_fonte(tamanho)
    altura_linha = int(tamanho * 1.35)
    y0, y1 = caixa
    total = altura_linha * len(linhas)
    y = y0 + (y1 - y0 - total) // 2
    for linha in linhas:
        largura = d.textlength(linha, font=fonte)
        if largura > LARGURA - 120:
            sys.exit("linha larga demais (%d px): %s" % (largura, linha))
        d.text(((LARGURA - largura) // 2, y), linha, font=fonte, fill=BRANCO)
        y += altura_linha


def faixa_dupla(d, faixa, cinzas):
    y0, y1 = faixa
    meio = LARGURA // 2
    d.rectangle([0, y0, meio - 1, y1 - 1], fill=(cinzas[0],) * 3)
    d.rectangle([meio, y0, LARGURA - 1, y1 - 1], fill=(cinzas[1],) * 3)


def tela_metades(topo, base):
    img, d = novo_quadro()
    texto_centrado(d, BANDA_TOPO, topo, 54)
    faixa_dupla(d, FAIXA_A, CINZAS_A)
    faixa_dupla(d, FAIXA_B, CINZAS_B)
    texto_centrado(d, BANDA_BASE, base, 42)
    return img


def tela_texto(linhas, tamanho=74):
    img, d = novo_quadro()
    texto_centrado(d, (0, ALTURA), linhas, tamanho)
    return img


TELAS = {
    "metades-1.png": lambda: tela_metades(
        ["TESTE DE COR (1 de 2)", "As duas metades cinzas abaixo parecem IGUAIS?"],
        ["SIM, iguais: não faça nada. Em 30 segundos o teste segue sozinho.",
         "NÃO, uma metade está bem mais clara: aperte qualquer tecla do controle."]),
    "metades-2.png": lambda: tela_metades(
        ["TESTE DE COR (2 de 2)", "Agora as duas metades parecem IGUAIS?"],
        ["SIM, iguais: aperte qualquer tecla do controle para MANTER.",
         "NÃO ou tela escura: não aperte nada. Em 30 segundos volta ao anterior."]),
    "aguarde.png": lambda: tela_texto(
        ["AGUARDE", "Preparando o teste de cor.", "Isso leva até 1 minuto."]),
    "reiniciando.png": lambda: tela_texto(
        ["AJUSTANDO", "O projetor vai reiniciar sozinho.", "Não desligue nem tire o pendrive."]),
    "pronto.png": lambda: tela_texto(
        ["PRONTO", "Pode retirar o pendrive."]),
    "erro.png": lambda: tela_texto(
        ["ALGO NÃO DEU CERTO", "Retire o pendrive e ligue o projetor de novo.",
         "Se repetir, veja o arquivo newlink_update.log", "que fica no pendrive."], 56),
}


def main():
    destino = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "pendrive-autorun", "kit")
    os.makedirs(destino, exist_ok=True)
    for nome, fabrica in TELAS.items():
        caminho = os.path.join(destino, nome)
        fabrica().save(caminho, format="PNG", optimize=True)
        print("gerado", caminho)


if __name__ == "__main__":
    main()
