#!/usr/bin/env python3
import os
import sys

from PIL import Image, ImageDraw, ImageFont

LARGURA, ALTURA = 1920, 1080
NFAIXAS = 16
NIVEIS = tuple(10 + 15 * k for k in range(NFAIXAS))
FAIXA_ALTURA = 34
FAIXA_PASSO = 50
FAIXA_Y0 = 140
BANDA_TOPO = (0, FAIXA_Y0)
BANDA_BASE = (940, ALTURA)

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
    d.fontmode = "1"
    return img, d

def texto_centrado(d, caixa, linhas, tamanho):
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

def faixas_y():
    return [(FAIXA_Y0 + k * FAIXA_PASSO, FAIXA_Y0 + k * FAIXA_PASSO + FAIXA_ALTURA)
            for k in range(NFAIXAS)]

def tela_calibracao():
    img, d = novo_quadro()
    for y0, y1 in faixas_y():
        d.rectangle([0, y0, LARGURA - 1, y1 - 1], fill=BRANCO)
    return img

def tela_escada(topo, base):
    img, d = novo_quadro()
    for (y0, y1), nivel in zip(faixas_y(), NIVEIS):
        d.rectangle([0, y0, LARGURA - 1, y1 - 1], fill=(nivel,) * 3)
    texto_centrado(d, BANDA_TOPO, topo, 36)
    texto_centrado(d, BANDA_BASE, base, 34)
    return img

def tela_texto(linhas, tamanho=74):
    img, d = novo_quadro()
    texto_centrado(d, (0, ALTURA), linhas, tamanho)
    return img

TELAS = {
    "calibracao.png": tela_calibracao,
    "escada-1.png": lambda: tela_escada(
        ["TESTE DE COR (1 de 2)",
         "A escada vai do escuro ao claro em ordem, sem faixa fora do lugar e sem cor?"],
        ["SIM: não faça nada. Em 30 segundos o teste segue sozinho.",
         "NÃO: aperte qualquer tecla do controle."]),
    "escada-2.png": lambda: tela_escada(
        ["TESTE DE COR (2 de 2)",
         "Agora a escada está em ordem, sem faixa fora do lugar e sem cor?"],
        ["SIM, agora em ordem: aperte qualquer tecla do controle para MANTER.",
         "Sem tecla em 30 segundos volta ao anterior."]),
    "corrigida.png": lambda: tela_texto(
        ["COR CORRIGIDA AUTOMATICAMENTE",
         "Se a imagem piorou, aperte qualquer tecla",
         "do controle em 30 segundos para desfazer."], 60),
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
