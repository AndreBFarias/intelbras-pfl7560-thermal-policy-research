#!/usr/bin/env python3
"""Folha de previa do bloco 16A: artifacts/overlay/previa/antes-depois-16a.png.

  python3 -I artifacts/overlay/gerar-previa-16a.py <pasta com os apps desmontados pelo apktool>

A pasta precisa ter as subpastas ZYBluetooth, ZYFileManager, ZYSetting, PowerService e
NLSourcePlayer (apktool d dos APKs do firmware; doc 48, secao Metodo). As cores de fabrica sao
lidas de res/values/colors.xml de cada app; as novas, de cada sobreposicao em artifacts/overlay;
as imagens novas, de <sobreposicao>/res. Mesmo metodo da gerar-previa.py (bloco 13A), de onde
vem o desenho dos 9-patch, a escala e as fontes: desenho com os valores, nao captura; posicoes e
tamanhos dos layouts do fabricante em dp (densidade 1,5), escalados para caber na folha.
So para olhar: nao vai para o kit. Precisa do Pillow.
"""
import importlib.util
import os
import re
import sys

from PIL import Image, ImageDraw

AQUI = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("previa13a", os.path.join(AQUI, "gerar-previa.py"))
B = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(B)

P, rgba, colar, texto, fonte, nove = B.P, B.rgba, B.colar, B.texto, B.fonte, B.nove
W, H, K, DP = B.W, B.H, B.K, B.DP
SAIDA = os.path.join(AQUI, "previa", "antes-depois-16a.png")
BRANCO = "#FFFFFFFF"
PRETO = "#FF000000"

def sp(n):
    return B.sp(n)

def cores_xml(arq):
    if not os.path.isfile(arq):
        return {}
    with open(arq, encoding="utf-8") as f:
        return {n: v for n, v in re.findall(r'<color name="([^"]+)">(#[0-9A-Fa-f]+)<', f.read())}

class App:

    PASTAS = ("drawable-hdpi", "drawable-hdpi-v4", "drawable", "mipmap-pt-hdpi", "mipmap-hdpi", "mipmap-xhdpi")

    def __init__(self, dec, sob=None):
        self.dec = os.path.join(dec, "res")
        self.cores = cores_xml(os.path.join(self.dec, "values", "colors.xml"))
        self.sob = os.path.join(AQUI, sob, "res") if sob else None
        self.sobnome = sob
        if self.sob:
            self.cores.update(cores_xml(os.path.join(self.sob, "values", "colors.xml")))

    def cor(self, nome):
        return self.cores[nome]

    def img(self, nome):
        for base in ([self.sob] if self.sob else []) + [self.dec]:
            for pasta in self.PASTAS:
                for ext in (".9.png", ".png", ".jpg"):
                    p = os.path.join(base, pasta, nome + ext)
                    if os.path.isfile(p):
                        return Image.open(p)
        raise SystemExit("falta a imagem %s" % nome)

def forma(a, nome, elem):
    with open(os.path.join(AQUI, a.sobnome, "res", "drawable", nome + ".xml"), encoding="utf-8") as f:
        m = re.search(r'<%s[^>]*android:color="(#[0-9A-Fa-f]+)"' % elem, f.read())
    return m.group(1)

def ret(d, xy, cor, raio=0, fio=None, larg=1):
    d.rounded_rectangle(xy, radius=raio, fill=rgba(cor) if cor else None,
                        outline=rgba(fio) if fio else None, width=larg)

def tela_bluetooth(a):
    t = Image.new("RGBA", (W, H), rgba(a.cor("pt_green")))
    d = ImageDraw.Draw(t)
    colar(t, a.img("left"), 150 * DP, 100 * DP)
    texto(d, (170 * DP, 96 * DP), "Configurações de Bluetooth", sp(30), BRANCO)
    lx, lw = (W - 800 * DP) / 2, 800 * DP
    y = 150 * DP
    texto(d, (lx + 20 * DP, y + 30 * DP), "Bluetooth", sp(25), BRANCO, "lm")
    ch = a.img("open_check_pt")
    colar(t, ch, lx + lw - 20 * DP - ch.width * K, y + 30 * DP - ch.height * K / 2)
    fio = rgba(a.cor("black"))
    d.line([(lx, y + 60 * DP), (lx + lw, y + 60 * DP)], fill=fio, width=1)
    texto(d, (lx + 20 * DP, y + 90 * DP), "Procurar dispositivos", sp(25), BRANCO, "lm")
    seta = a.img("right")
    colar(t, seta, lx + lw - 20 * DP - seta.width * K, y + 90 * DP - seta.height * K / 2)
    d.line([(lx, y + 120 * DP), (lx + lw, y + 120 * DP)], fill=fio, width=1)
    y += 130 * DP
    for titulo, itens in (("Dispositivos pareados", [("Fone JBL", "ic_headset_black_24dp", "Conectado")]),
                          ("Dispositivos disponíveis", [("Caixa de som", "ic_headset_black_24dp", ""),
                                                        ("Controle", "ic_gamepad_black_24dp", "")])):
        texto(d, (lx + 20 * DP, y), titulo, sp(22), BRANCO)
        y += 34 * DP
        for i, (nome, ic, est) in enumerate(itens):
            im = a.img(ic)
            colar(t, im, lx + 20 * DP, y + 30 * DP - im.height * K / 2)
            texto(d, (lx + 70 * DP, y + 30 * DP), nome, sp(25), BRANCO, "lm")
            if est:
                texto(d, (lx + lw - 30 * DP, y + 30 * DP), est, sp(25), BRANCO, "rm")
            if titulo.startswith("Dispositivos pareados"):
                colar(t, a.img("item_focus"), lx, y, lw, 60 * DP, nove_patch=True)
            y += 60 * DP
        y += 10 * DP
    return t

def tela_arquivos(a):
    t = Image.new("RGBA", (W, H), rgba(a.cor("pt_green")))
    d = ImageDraw.Draw(t)
    texto(d, (60 * DP, 40 * DP), "USB  /  Fotos e vídeos", sp(26), BRANCO)
    nomes = [("pt_list_folder_icon", "Viagem"), ("pt_list_folder_icon", "Família"), ("pt_list_video_icon", "aniversario.mp4"),
             ("pt_list_audio_icon", "musica.mp3"), ("pt_list_folder_icon", "Trabalho"), ("pt_list_video_icon", "filme.mkv")]
    cw, chh = 150 * DP, 150 * DP
    x0, y0 = 60 * DP, 100 * DP
    for i, (ic, nome) in enumerate(nomes):
        x, y = x0 + (i % 6) * (cw + 20 * DP), y0 + (i // 6) * (chh + 20 * DP)
        colar(t, a.img(ic), x + (cw - 80 * DP) / 2, y + 10 * DP, 80 * DP, 80 * DP)
        texto(d, (x + cw / 2, y + 115 * DP), nome, sp(18), BRANCO, "mm")
        if i == 0:
            if a.sob:
                ret(d, [x, y, x + cw, y + chh], None, 0, forma(a, "background_white", "stroke"), max(1, int(round(3 * DP))))
            else:
                ret(d, [x, y, x + cw, y + chh], None, 0, BRANCO, max(1, int(round(3 * DP))))
    return t

def tela_operacao(a):
    t = tela_arquivos(a)
    t.alpha_composite(Image.new("RGBA", (W, H), (0, 0, 0, 120)))
    d = ImageDraw.Draw(t)
    pw, ph = 460 * DP, 380 * DP
    px, py = (W - pw) / 2, (H - ph) / 2
    ret(d, [px, py, px + pw, py + ph], a.cor("color11"), 10 * DP)
    texto(d, (W / 2, py + 40 * DP), "Viagem", sp(28), PRETO, "mm")
    for i, rot in enumerate(["Copiar", "Recortar", "Renomear", "Apagar"]):
        by = py + 80 * DP + i * 70 * DP
        foco = i == 0
        ret(d, [px + 40 * DP, by, px + pw - 40 * DP, by + 50 * DP], a.cor("color10") if foco else BRANCO, 25 * DP)
        texto(d, (W / 2, by + 25 * DP), rot, sp(25), BRANCO if foco else PRETO, "mm")
    return t

def tela_modo(a):
    t = Image.new("RGBA", (W, H), rgba(a.cor("pt_green")))
    d = ImageDraw.Draw(t)
    pw = 420 * DP
    px, py = W - pw - 60 * DP, 60 * DP
    modos = ["Padrão", "Vívido", "Cinema", "Esporte", "Personalizado"]
    ph = 30 * DP + len(modos) * 62 * DP
    ret(d, [px, py, px + pw, py + ph], a.cor("color_27293D"), 30 * DP)
    texto(d, (px + 26 * DP, py + 4 * DP), "Modo de imagem", sp(20), BRANCO)
    for i, m in enumerate(modos):
        iy = py + 30 * DP + i * 62 * DP
        if i == 1:
            if a.sob:
                ret(d, [px + 14 * DP, iy, px + pw - 14 * DP, iy + 57 * DP], forma(a, "bg_itemcolor", "solid"), 10 * DP)
            else:
                g = Image.new("RGBA", (int(pw - 28 * DP), int(57 * DP)))
                gd = ImageDraw.Draw(g)
                c0, c1 = rgba(a.cor("color_FB884C")), rgba(a.cor("color_DC6641"))
                for x in range(g.width):
                    f = x / max(1, g.width - 1)
                    gd.line([(x, 0), (x, g.height)], fill=tuple(int(c0[k] + f * (c1[k] - c0[k])) for k in range(4)))
                m_ = Image.new("L", g.size, 0)
                ImageDraw.Draw(m_).rounded_rectangle([0, 0, g.width - 1, g.height - 1], radius=10 * DP, fill=255)
                t.paste(g, (int(px + 14 * DP), int(iy)), m_)
                d = ImageDraw.Draw(t)
        texto(d, (px + 27 * DP, iy + 28 * DP), m, sp(18), BRANCO, "lm")
        im = a.img("selected_image" if i == 1 else "unselected_image")
        colar(t, im, px + pw - 27 * DP - im.width * K, iy + 28 * DP - im.height * K / 2)
    return t

def tela_energia(a):
    t = Image.new("RGBA", (W, H), rgba("#FF3A3F4B"))
    t.alpha_composite(Image.new("RGBA", (W, H), rgba(a.cor("app_background"))))
    d = ImageDraw.Draw(t)
    itens = [("power", "Desligar", "pt_red"), ("reboot", "Reiniciar", "pt_green"), ("seleep", "Dormir", "pt_green"),
             ("powertime", "Desligar em", "pt_green"), ("speak", "Só áudio", "pt_green")]
    lado, gap = 106 * DP, 50 * DP
    x0 = (W - len(itens) * lado - (len(itens) - 1) * gap) / 2
    y = H / 2 - lado / 2
    for i, (ic, rot, foco) in enumerate(itens):
        x = x0 + i * (lado + gap)
        cor = a.cor(foco) if i == 1 else a.cor("pt_green_black")
        d.ellipse([x, y, x + lado, y + lado], fill=rgba(cor))
        im = a.img(ic)
        colar(t, im, x + lado / 2 - im.width * K / 2, y + lado / 2 - im.height * K / 2)
        texto(d, (x + lado / 2, y + lado + 22 * DP), rot, sp(20), BRANCO, "mm")
    return t

def tela_sem_sinal(a):
    t = Image.new("RGBA", (W, H), rgba(a.cor("pt_green")))
    d = ImageDraw.Draw(t)
    im = a.img("hdmi_cable")
    colar(t, im, W / 2 - im.width * K / 2, H * 0.30)
    texto(d, (W / 2, H * 0.30 + im.height * K + 30 * DP), "Sem sinal. Verifique o cabo do HDMI 1.", sp(26), BRANCO, "mm")
    return t

def tela_pareamento(a):
    t = Image.new("RGBA", (W, H), rgba("#FF3A3F4B"))
    t.alpha_composite(Image.new("RGBA", (W, H), rgba(a.cor("bt_pair_dialog_window_background"))))
    d = ImageDraw.Draw(t)
    texto(d, (120 * DP, 120 * DP), "Pedido de pareamento Bluetooth", sp(28), BRANCO)
    texto(d, (120 * DP, 170 * DP), "Para parear com \"Fone JBL\", confirme a senha:", sp(18), "#B3EEEEEE")
    texto(d, (120 * DP, 210 * DP), "482 913", fonte("IBMPlexSansCondensed-SemiBold.ttf", 34 * DP), BRANCO)
    ax = W - 520 * DP
    for i, rot in enumerate(["Parear", "Cancelar"]):
        ay = 180 * DP + i * 56 * DP
        if i == 0:
            ret(d, [ax, ay, ax + 400 * DP, ay + 50 * DP], "#0DFFFFFF", 4 * DP)
        texto(d, (ax + 20 * DP, ay + 25 * DP), rot, sp(22), BRANCO, "lm")
    return t

def tela_dialogo_toast(a):
    t = Image.new("RGBA", (W, H), rgba("#FF3A3F4B"))
    t.alpha_composite(Image.new("RGBA", (W, H), (0, 0, 0, 110)))
    d = ImageDraw.Draw(t)
    pw, ph = 560 * DP, 200 * DP
    px, py = (W - pw) / 2, (H - ph) / 2 - 40 * DP
    ret(d, [px, py, px + pw, py + ph], a.cor("background_leanback_dark"), 2 * DP)
    texto(d, (px + 24 * DP, py + 24 * DP), "Remover dispositivo?", fonte("IBMPlexSansCondensed-SemiBold.ttf", 22 * DP),
          a.cor("primary_text_leanback_dark"))
    texto(d, (px + 24 * DP, py + 70 * DP), "O Fone JBL deixa de conectar sozinho.", sp(16), a.cor("secondary_text_leanback_dark"))
    for i, rot in enumerate(["CANCELAR", "OK"]):
        texto(d, (px + pw - 140 * DP + i * 80 * DP, py + ph - 36 * DP), rot,
              fonte("IBMPlexSansCondensed-SemiBold.ttf", 16 * DP), "#FF80CBC4", "mm")
    tw, th = 300 * DP, 48 * DP
    tx, ty = (W - tw) / 2, H - 64 * DP - th
    if a.sob:
        ret(d, [tx, ty, tx + tw, ty + th], forma(a, "toast_frame", "solid"), 22 * DP,
            forma(a, "toast_frame", "stroke"), max(1, int(round(2 * DP))))
    else:
        ret(d, [tx, ty, tx + tw, ty + th], "#E6EEEEEE", 22 * DP)
    texto(d, (W / 2, ty + th / 2), "Arquivo copiado", sp(14), "#DE000000", "mm")
    return t

TELAS = [
    ("Bluetooth (com.example.bluetoothsetting), foco no 1º pareado", "ZYBluetooth", "zybluetooth", tela_bluetooth),
    ("Gerenciador de arquivos, lista (file_show), foco na 1ª pasta", "ZYFileManager", "zyfilemanager", tela_arquivos),
    ("Gerenciador de arquivos, janela de operação, foco em Copiar", "ZYFileManager", "zyfilemanager", tela_operacao),
    ("Modo de imagem (Outras configurações), item escolhido", "ZYSetting", "zysetting", tela_modo),
    ("Menu de energia (PowerActivity), foco em Reiniciar", "PowerService", "powerservice", tela_energia),
    ("Entrada HDMI sem sinal (com.newlink.nlsource)", "NLSourcePlayer", "nlsource", tela_sem_sinal),
    ("Pedido de pareamento Bluetooth (TvSettings), foco em Parear", "TvSettings", "tvsettings", tela_pareamento),
    ("Diálogo escuro do Leanback e Toast do sistema (framework)", None, "android", tela_dialogo_toast),
]

FW_ANTES = {"background_leanback_dark": "#FF324248", "primary_text_leanback_dark": "#CCEEEEEE",
            "secondary_text_leanback_dark": "#99EEEEEE"}

class Fw:
    def __init__(self, sob):
        self.sob = sob
        self.sobnome = sob
        self.cores = dict(FW_ANTES)
        if sob:
            self.cores.update(cores_xml(os.path.join(AQUI, "android", "res", "values", "colors.xml")))

    def cor(self, nome):
        return self.cores[nome]

def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    dec = sys.argv[1]
    margem, gap, rot_h, cab = B.MARG, B.GAP, B.ROT, B.CAB
    largura = 2 * margem + 2 * W + gap
    altura = 2 * margem + cab + len(TELAS) * (H + rot_h) + (len(TELAS) - 1) * gap
    folha = Image.new("RGBA", (largura, altura), rgba(P["fundo"]))
    d = ImageDraw.Draw(folha)
    tit = fonte("IBMPlexSansCondensed-SemiBold.ttf", 30)
    rot = fonte("IBMPlexSansCondensed-Regular.ttf", 20)
    texto(d, (margem, margem), "Antes (fábrica)", tit, P["texto"])
    texto(d, (margem + W + gap, margem), "Depois (sobreposições Drácula, bloco 16A)", tit, P["roxo"])
    y = margem + cab
    for nome, app, sob, fn in TELAS:
        if app:
            antes, depois = App(os.path.join(dec, app)), App(os.path.join(dec, app), sob)
        else:
            antes, depois = Fw(None), Fw(sob)
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
