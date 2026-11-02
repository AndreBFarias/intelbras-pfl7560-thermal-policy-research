#!/usr/bin/env python3
# Previas PNG da marca para o dono aprovar (bloco 28): decodifica o que o aparelho mostra, os JPEG de
# artifacts/tema/marca e cada quadro do bootanimation.zip, e grava em artifacts/tema/previa/
import io
import os
import zipfile

from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MARCA = os.path.join(RAIZ, "artifacts", "tema", "marca")
SAIDA = os.environ.get("PFL_PREVIA_SAIDA") or os.path.join(RAIZ, "artifacts", "tema", "previa")

def png(im, nome):
    caminho = os.path.join(SAIDA, nome)
    im.convert("RGB").save(caminho, "PNG", optimize=True)
    print("%-36s %dx%d" % (nome, im.size[0], im.size[1]))

def main():
    os.makedirs(SAIDA, exist_ok=True)
    png(Image.open(os.path.join(MARCA, "logo.jpg")), "marca-logo.png")
    png(Image.open(os.path.join(MARCA, "logo-boot.jpg")), "marca-logo-boot.png")
    with zipfile.ZipFile(os.path.join(MARCA, "bootanimation.zip")) as z:
        quadros = sorted(n for n in z.namelist() if n.lower().endswith((".jpg", ".png")))
        for n in quadros:
            im = Image.open(io.BytesIO(z.read(n)))
            png(im, "marca-animacao-" + n.replace("/", "-").rsplit(".", 1)[0] + ".png")
    print("animacao: %d quadro(s) (desc.txt: %s)" % (len(quadros), " | ".join(
        zipfile.ZipFile(os.path.join(MARCA, "bootanimation.zip")).read("desc.txt").decode().split("\n")).strip(" |")))

if __name__ == "__main__":
    main()
