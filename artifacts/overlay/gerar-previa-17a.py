#!/usr/bin/env python3
"""Folha de previa do bloco 17A: artifacts/overlay/previa/antes-depois-17a.png.

  python3 -I artifacts/overlay/gerar-previa-17a.py <pasta com os apps desmontados pelo apktool>

A pasta precisa ter as subpastas AutoFocus3, ZYSpeakerModel, NewLinkService, HiVideoPlayer e
HiMusic (apktool d dos APKs do firmware; doc 48, secao Metodo). Mesmo metodo da
gerar-previa-16a.py (de onde vem a classe App, a escala e as fontes): as cores e as formas de
fabrica sao lidas do app desmontado; as novas, de cada sobreposicao em artifacts/overlay.
Desenho com os valores, nao captura; posicoes e tamanhos dos layouts do fabricante em dp
(densidade 1,5), escalados para caber na folha. So para olhar: nao vai para o kit. Precisa do Pillow.
"""
import importlib.util
import os
import re
import sys

from PIL import Image, ImageDraw

AQUI = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("previa16a", os.path.join(AQUI, "gerar-previa-16a.py"))
A = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(A)

B = A.B
P, rgba, colar, texto, fonte = B.P, B.rgba, B.colar, B.texto, B.fonte
W, H, K, DP = B.W, B.H, B.K, B.DP
ret, sp = A.ret, A.sp
SAIDA = os.path.join(AQUI, "previa", "antes-depois-17a.png")
BRANCO = "#FFFFFFFF"
PRETO = "#FF000000"
NEGRITO = "IBMPlexSansCondensed-SemiBold.ttf"

class App(A.App):
    PASTAS = A.App.PASTAS + ("drawable-xhdpi", "drawable-nodpi-v4")

    def forma(self, nome):
        for base in ([self.sob] if self.sob else []) + [self.dec]:
            p = os.path.join(base, "drawable", nome + ".xml")
            if os.path.isfile(p):
                with open(p, encoding="utf-8") as f:
                    s = f.read()
                cheio = re.search(r'<solid[^>]*android:color="(#[0-9A-Fa-f]+)"', s)
                deg = re.search(r'android:startColor="(#[0-9A-Fa-f]+)"[^>]*android:endColor="(#[0-9A-Fa-f]+)"', s)
                fio = re.search(r'<stroke[^>]*android:width="([\d.]+)(?:dip|dp)"[^>]*android:color="(#[0-9A-Fa-f]+)"', s)
                return (cheio.group(1) if cheio else None, deg.groups() if deg else None,
                        fio.group(2) if fio else None, float(fio.group(1)) if fio else 0)
        raise SystemExit("falta a forma %s" % nome)

def pintar(t, a, nome, xy, raio):
    cheio, deg, fio, larg = a.forma(nome)
    d = ImageDraw.Draw(t)
    if deg:
        x0, y0, x1, y1 = (int(round(v)) for v in xy)
        g = Image.new("RGBA", (x1 - x0, y1 - y0))
        gd = ImageDraw.Draw(g)
        c0, c1 = rgba(deg[0]), rgba(deg[1])
        for x in range(g.width):
            f = x / max(1, g.width - 1)
            gd.line([(x, 0), (x, g.height)], fill=tuple(int(c0[k] + f * (c1[k] - c0[k])) for k in range(4)))
        m = Image.new("L", g.size, 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, g.width - 1, g.height - 1], radius=raio, fill=255)
        t.paste(g, (x0, y0), m)
        d = ImageDraw.Draw(t)
        cheio = None
    ret(d, xy, cheio, raio, fio, max(1, int(round(larg * DP))) if fio else 1)

def escurecer(t, alfa=110):
    t.alpha_composite(Image.new("RGBA", (W, H), (0, 0, 0, alfa)))

def tela_foco(a):
    t = Image.new("RGBA", (W, H), rgba("#FF3A3F4B"))
    tw, th = 330 * DP, 40 * DP
    tx, ty = (W - tw) / 2, (H - th) / 2
    pintar(t, a, "toast_bg", [tx, ty, tx + tw, ty + th], 5 * DP)
    texto(ImageDraw.Draw(t), (W / 2, ty + th / 2), "Ajustando o foco automaticamente...", sp(22),
          "#FF666666", "mm")
    return t

def tela_caixa(a):
    t = Image.new("RGBA", (W, H))
    colar(t, a.img("pt_bg"), 0, 0, W, H)
    d = ImageDraw.Draw(t)
    texto(d, (60 * DP, 60 * DP), "Modo caixa de som Bluetooth", sp(30), BRANCO)
    texto(d, (60 * DP, 105 * DP), "Conectado: celular", sp(22), BRANCO)
    texto(d, (60 * DP, 150 * DP), "Música tocando agora", sp(26), BRANCO)
    ic = 78 * DP
    x0 = 60 * DP
    for i, nome in enumerate(["paly_back", "paly_paly", "paly_forward", "lock"]):
        im = a.img(nome + ("_focus" if i == 1 else ""))
        colar(t, im, x0 + i * (ic + 20 * DP), 200 * DP, ic, ic)
    for i, rot in enumerate(["Tela desligada", "Sair do modo"]):
        bx, by = x0 + i * 200 * DP, 310 * DP
        foco = i == 0
        pintar(t, a, "selected_background" if foco else "unselected_background",
               [bx, by, bx + 180 * DP, by + 50 * DP], 8 * DP)
        if a.sob:
            cor = "#FF282A36" if foco else "#FFF8F8F2"
        else:
            cor = BRANCO if foco else PRETO
        texto(ImageDraw.Draw(t), (bx + 90 * DP, by + 25 * DP), rot, sp(20), cor, "mm")
    return t

def tela_caixa_aviso(a):
    t = tela_caixa(a)
    escurecer(t)
    d = ImageDraw.Draw(t)
    pw, ph = 520 * DP, 230 * DP
    px, py = (W - pw) / 2, (H - ph) / 2
    ret(d, [px, py, px + pw, py + ph], a.cor("pt_grey_white"), 13 * DP)
    texto(d, (W / 2, py + 40 * DP), "Sair do modo caixa de som?", sp(26), PRETO, "mm")
    texto(d, (W / 2, py + 90 * DP), "A tela volta a ligar em 10 s", sp(20), "#FF333333", "mm")
    for i, rot in enumerate(["Sair", "Cancelar"]):
        bx, by = px + 50 * DP + i * 225 * DP, py + ph - 80 * DP
        foco = i == 0
        ret(d, [bx, by, bx + 195 * DP, by + 52 * DP], a.cor("pt_green" if foco else "pt_grey_white"), 26 * DP)
        texto(d, (bx + 97 * DP, by + 26 * DP), rot, sp(22), BRANCO if foco else PRETO, "mm")
    return t

def tela_desligar(a):
    t = Image.new("RGBA", (W, H), rgba("#FF101418"))
    d = ImageDraw.Draw(t)
    pw, ph = 600 * DP, 220 * DP
    px, py = (W - pw) / 2, (H - ph) / 2
    ret(d, [px, py, px + pw, py + ph], a.cor("black"), 0)
    texto(d, (W / 2, py + 45 * DP), "O projetor vai desligar em 30 s", sp(26), "#FFCC0000", "mm")
    texto(d, (W / 2, py + 90 * DP), "Aperte qualquer botão para continuar ligado", sp(20), BRANCO, "mm")
    for i, rot in enumerate(["Desligar agora", "Cancelar"]):
        bx, by = px + 70 * DP + i * 250 * DP, py + ph - 75 * DP
        ret(d, [bx, by, bx + 210 * DP, by + 50 * DP], a.cor("red" if i == 0 else "black"), 0)
        texto(d, (bx + 105 * DP, by + 25 * DP), rot, sp(22), BRANCO, "mm")
    return t

def tela_apagada(a):
    t = Image.new("RGBA", (W, H), rgba("#FF3A3F4B"))
    escurecer(t)
    d = ImageDraw.Draw(t)
    pw, ph = 520 * DP, 230 * DP
    px, py = (W - pw) / 2, (H - ph) / 2
    pintar(t, a, "bg_white_90", [px, py, px + pw, py + ph], 13 * DP)
    d = ImageDraw.Draw(t)
    texto(d, (W / 2, py + 40 * DP), "Apagar a tela?", sp(26), a.cor("black"), "mm")
    texto(d, (W / 2, py + 90 * DP), "O som continua; qualquer botão acende", sp(20), "#FF333333", "mm")
    for i, rot in enumerate(["Apagar", "Cancelar"]):
        bx, by = px + 50 * DP + i * 225 * DP, py + ph - 80 * DP
        foco = i == 0
        pintar(t, a, "button_bg_itemcolor" if foco else "button_bg_item_white",
               [bx, by, bx + 195 * DP, by + 52 * DP], 26 * DP)
        texto(ImageDraw.Draw(t), (bx + 97 * DP, by + 26 * DP), rot, sp(22), BRANCO if foco else PRETO, "mm")
    return t

def tela_video(a):
    t = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(t)
    for y in range(H):
        f = y / H
        d.line([(0, y), (W, y)], fill=(int(40 + 60 * f), int(70 + 40 * f), int(60 + 20 * f), 255))
    bw, bh = 1061 * K * 1.5, 167 * K * 1.5
    bx, by = (W - bw) / 2, H - bh - 30 * DP
    colar(t, a.img("video_bottom"), bx, by, bw, bh)
    lado = 64 * K * 1.5
    nomes = ["previous", "fastbackward", "pause", "fastforward", "next"]
    x0 = W / 2 - (len(nomes) * lado + (len(nomes) - 1) * 14 * DP) / 2
    for i, n in enumerate(nomes):
        im = a.img(n + ("_focus" if n == "pause" else "_unfocus"))
        colar(t, im, x0 + i * (lado + 14 * DP), by + bh - lado - 12 * DP, lado, lado * 57 / 64)
    texto(ImageDraw.Draw(t), (bx + 30 * DP, by + 22 * DP), "00:12:31 / 01:45:02", sp(18), BRANCO)
    return t

def tela_musica(a):
    t = Image.new("RGBA", (W, H))
    colar(t, a.img("hisil_background_3"), 0, 0, W, H)
    d = ImageDraw.Draw(t)
    texto(d, (W / 2, 80 * DP), "musica.mp3", sp(30), BRANCO, "mm")
    texto(d, (W / 2, 120 * DP), "Artista desconhecido", sp(20), "#99FFFFFF", "mm")
    y = H - 150 * DP
    d.rounded_rectangle([120 * DP, y - 3 * DP, W - 120 * DP, y + 3 * DP], radius=3 * DP, fill=(0, 0, 0, 80))
    d.rounded_rectangle([120 * DP, y - 3 * DP, W * 0.45, y + 3 * DP], radius=3 * DP, fill=rgba("#FFFFFFFF"))
    th = a.img("hisil_yuandian")
    colar(t, th, W * 0.45 - th.width * K / 2, y - th.height * K / 2)
    lado = 66 * K * 1.6
    nomes = ["hisil_left", None, "hisil_right"]
    x0 = W / 2 - 1.5 * lado - 20 * DP
    for i, n in enumerate(nomes):
        x = x0 + i * (lado + 20 * DP)
        yb = H - 110 * DP
        if n:
            colar(t, a.img(n), x, yb, lado, lado * 62 / 66)
        else:
            d.rectangle([x + lado * 0.35, yb + lado * 0.25, x + lado * 0.45, yb + lado * 0.7], fill=rgba(BRANCO))
            d.rectangle([x + lado * 0.55, yb + lado * 0.25, x + lado * 0.65, yb + lado * 0.7], fill=rgba(BRANCO))
            colar(t, a.img("hisil_lank_selected"), x - 6 * DP, yb - 6 * DP, lado + 12 * DP, lado + 6 * DP, nove_patch=True)
            d = ImageDraw.Draw(t)
    return t

TELAS = [
    ("Aviso do foco automático (AutoFocus3, layout toast)", "AutoFocus3", "autofocus", tela_foco),
    ("Modo caixa de som (ZYSpeakerModel), foco em tocar e em Tela desligada", "ZYSpeakerModel", "zyspeakermodel", tela_caixa),
    ("Modo caixa de som, aviso de sair (MyDialog), foco em Sair", "ZYSpeakerModel", "zyspeakermodel", tela_caixa_aviso),
    ("Contagem de desligar do descanso (NewLinkService), foco em Desligar", "NewLinkService", "newlinkservice", tela_desligar),
    ("Aviso de tela apagada (NewLinkService), foco em Apagar", "NewLinkService", "newlinkservice", tela_apagada),
    ("Player de vídeo HiSilicon (o IjkPlayer usa as mesmas imagens), foco em pausar", "HiVideoPlayer", "hivideoplayer", tela_video),
    ("Player de música HiSilicon, foco em pausar", "HiMusic", "himusic", tela_musica),
]

def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    dec = sys.argv[1]
    margem, gap, rot_h, cab = B.MARG, B.GAP, B.ROT, B.CAB
    largura = 2 * margem + 2 * W + gap
    altura = 2 * margem + cab + len(TELAS) * (H + rot_h) + (len(TELAS) - 1) * gap
    folha = Image.new("RGBA", (largura, altura), rgba(P["fundo"]))
    d = ImageDraw.Draw(folha)
    tit = fonte(NEGRITO, 30)
    rot = fonte("IBMPlexSansCondensed-Regular.ttf", 20)
    texto(d, (margem, margem), "Antes (fábrica)", tit, P["texto"])
    texto(d, (margem + W + gap, margem), "Depois (sobreposições Drácula, bloco 17A)", tit, P["roxo"])
    y = margem + cab
    for nome, app, sob, fn in TELAS:
        antes, depois = App(os.path.join(dec, app)), App(os.path.join(dec, app), sob)
        folha.alpha_composite(fn(antes), (margem, y))
        folha.alpha_composite(fn(depois), (margem + W + gap, y))
        d.rectangle([margem - 1, y - 1, margem + W, y + H], outline=rgba(P["comentario"]))
        d.rectangle([margem + W + gap - 1, y - 1, margem + 2 * W + gap, y + H], outline=rgba(P["comentario"]))
        texto(d, (margem, y + H + 10), nome, rot, "#FFB4BCCF")
        y += H + rot_h + gap
    os.makedirs(os.path.dirname(SAIDA), exist_ok=True)
    folha.convert("RGB").save(SAIDA, optimize=True)
    print(SAIDA)

if __name__ == "__main__":
    main()
