#!/usr/bin/env python3
"""Folha de previa do bloco 19B: artifacts/overlay/previa/antes-depois-19b.png.

  python3 -I artifacts/overlay/gerar-previa-19b.py <pasta com os apps desmontados pelo apktool>

A pasta precisa ter as subpastas ZYFileManager, ZYCustomUI, ZYSetting, HiVideoPlayer, HiMusic e
framework-res (apktool d dos APKs do firmware; doc 48, secao Metodo). Mesmo metodo da
gerar-previa-18.py (de onde vem a classe App, a escala e as fontes). As cores de cada layout saem
do proprio XML: o do app desmontado (antes) e a copia da sobreposicao (depois), na mesma ordem
dos elementos, que e a regra do bloco (so as cores mudam). Desenho com os valores, nao captura.
So para olhar: nao vai para o kit. Precisa do Pillow.
"""
import importlib.util
import os
import sys
import xml.etree.ElementTree as ET

from PIL import Image, ImageDraw

AQUI = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("previa18", os.path.join(AQUI, "gerar-previa-18.py"))
D = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(D)          # so as funcoes: o main() dela so roda como script

C, A, B = D.C, D.A, D.B
P, rgba, colar, texto, fonte = B.P, B.rgba, B.colar, B.texto, B.fonte
W, H, K, DP = B.W, B.H, B.K, B.DP
ret, sp = A.ret, A.sp
SAIDA = os.path.join(AQUI, "previa", "antes-depois-19b.png")
BRANCO = "#FFFFFFFF"
NA = "{http://schemas.android.com/apk/res/android}"
NAPP = "{http://schemas.android.com/apk/res-auto}"


class App(D.App):
    PASTAS = D.App.PASTAS + ("drawable-xhdpi",)

    def layout(self, nome, pasta="layout"):
        """Raiz do layout <nome>: a copia da sobreposicao, se ela tiver, senao a do app."""
        for base in ([self.sob] if self.sob else []) + [self.dec]:
            p = os.path.join(base, pasta, nome + ".xml")
            if os.path.isfile(p):
                return ET.parse(p).getroot()
        raise SystemExit("falta o layout %s" % nome)


def por_id(raiz, ident):
    for e in raiz.iter():
        if e.get(NA + "id") == "@id/" + ident:
            return e
    raise SystemExit("falta o id %s" % ident)


def tela_arquivos(a):
    """Pagina inicial do gerenciador (MainOtherActivity, activity_main_other): os cartoes visiveis."""
    t = Image.new("RGBA", (W, H), rgba(a.cor("pt_green")))
    d = ImageDraw.Draw(t)
    raiz = a.layout("activity_main_other")
    guia = {e.get(NA + "id"): float(e.get(NAPP + "layout_constraintGuide_percent"))
            for e in raiz if e.tag.endswith("Guideline")}
    rotulos = {"main_video": "Vídeo", "main_image": "Imagem", "main_audio": "Áudio", "main_word": "Documento",
               "main_externaldevice": "Dispositivo externo", "main_local_store": "Armazenamento local",
               "main_no_devices": "Nenhum dispositivo encontrado"}
    m = 8 * DP
    for fl in raiz:
        if fl.tag != "FrameLayout" or fl.get(NA + "visibility") == "gone":
            continue
        x0, x1, y0, y1 = (guia[fl.get(NAPP + k)] for k in ("layout_constraintStart_toStartOf", "layout_constraintEnd_toStartOf",
                                                           "layout_constraintTop_toTopOf", "layout_constraintBottom_toTopOf"))
        r = [x0 * W + m, y0 * H + m, x1 * W - m, y1 * H - m]
        cartao = fl[0]
        ret(d, r, cartao.get(NAPP + "cardBackgroundColor"), 10 * DP)
        img = [i.get(NAPP + "srcCompat") or i.get(NA + "background") for i in cartao.iter("ImageView")][0]
        txt = [(tv.get(NA + "text"), tv.get(NA + "textColor")) for tv in cartao.iter("TextView")
               if tv.get(NA + "visibility") != "gone"]
        cx, cy = (r[0] + r[2]) / 2, (r[1] + r[3]) / 2
        vertical = cartao[0].get(NA + "orientation") == "vertical"
        isz = 70 * DP
        ix, iy = (cx - isz / 2, cy - isz / 2 - 20 * DP) if vertical else (r[0] + 30 * DP, cy - isz / 2)
        colar(t, a.img(img.split("/")[1]), ix, iy, isz, isz)
        d = ImageDraw.Draw(t)
        for i, (s, cor) in enumerate(txt):
            s = rotulos.get(s.split("/")[-1], s)
            if vertical:
                texto(d, (cx, cy + 40 * DP), s, sp(20), cor, "mm")
            else:
                texto(d, (ix + isz + 20 * DP, cy - 12 * DP + i * 26 * DP), s, sp(20 if i == 0 else 14), cor, "lm")
        if fl.get(NA + "id") == "@id/frameLayout1":     # o foco (moldura background_white, 16A)
            fio = A.forma(a, "background_white", "stroke") if a.sob else BRANCO
            ret(d, r, None, 10 * DP, fio, max(1, int(round(3 * DP))))
    return t


def tela_entradas(a):
    """Lista de entradas (SourceUIActivity) ao abrir, antes do primeiro foco: o fundo do GridLayout
    e o do layout_main (no primeiro foco o codigo troca por pt_grey_white, ja no tema desde o 18)."""
    t = D.fundo_qualquer()
    d = ImageDraw.Draw(t)
    grade = por_id(a.layout("layout_main"), "layout_source_grid")
    itens = ["Início", "HDMI 1", "HDMI 2", "USB"]
    gw, ih, gap = 400 * DP, 52 * DP, 8 * DP
    gh = 70 * DP + len(itens) * (ih + gap)
    gx, gy = (W - gw) / 2, (H - gh) / 2
    ret(d, [gx, gy, gx + gw, gy + gh], grade.get(NA + "background"), 0)
    texto(d, (W / 2, gy + 35 * DP), "Entrada", sp(26), BRANCO, "mm")
    for i, rot in enumerate(itens):
        y = gy + 70 * DP + i * (ih + gap)
        ret(d, [gx + 60 * DP, y, gx + gw - 60 * DP, y + ih], a.cor("pt_green_black"), 0)
        texto(d, (W / 2, y + ih / 2), rot, sp(24), BRANCO, "mm")
    return t


def tela_wifi(a):
    """Wi-Fi (layout_wifi): o fio de 1 dp entre a linha Ativar/Desativar e a lista."""
    t = Image.new("RGBA", (W, H), rgba(a.cor("pt_green")))
    d = ImageDraw.Draw(t)
    fio = [e for e in a.layout("layout_wifi") if e.tag == "ImageView"][0].get(NA + "background")
    lw = 825 * DP * 0.8
    lx = (W - lw) / 2
    texto(d, (W / 2, 45 * DP), "Wi-Fi", sp(30), BRANCO, "mm")
    texto(d, (lx + 20 * DP, 110 * DP), "Ativar / Desativar", sp(22), BRANCO, "lm")
    colar(t, a.img("open_check_pt"), lx + lw - 130 * DP, 92 * DP, 110 * DP, 36 * DP)
    d = ImageDraw.Draw(t)
    ret(d, [lx, 145 * DP, lx + lw, 145 * DP + max(2, int(round(1 * DP * 2)))], fio, 0)
    for i, rede in enumerate(["Casa", "Casa_5G", "Vizinho"]):
        y = 175 * DP + i * 62 * DP
        texto(d, (lx + 20 * DP, y + 25 * DP), rede, sp(22), BRANCO, "lm")
    return t


def tela_video(a):
    """Player de video HiSilicon (VideoActivity, main_dpt_o): o painel de informacao (mediaInfo)."""
    t = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(t)
    for y in range(H):                               # o video por tras, um degrade qualquer
        f = y / H
        d.line([(0, y), (W, y)], fill=(int(40 + 60 * f), int(70 + 40 * f), int(90 + 20 * f), 255))
    raiz = a.layout("main_dpt_o")
    painel = por_id(raiz, "mediaInfo")
    fio = [e for e in painel if e.tag == "View"][0].get(NA + "background")
    pro = por_id(raiz, "pro_text").get(NA + "background")
    ph = 110 * DP
    ret(d, [0, 20 * DP, W, 20 * DP + ph], painel.get(NA + "background"), 0)
    texto(d, (30 * DP, 50 * DP), "aniversario.mp4", sp(25), BRANCO, "lm")
    texto(d, (W - 30 * DP, 50 * DP), "1,2 GB", sp(25), BRANCO, "rm")
    texto(d, (30 * DP, 95 * DP), "Legenda: nenhuma", sp(25), BRANCO, "lm")
    texto(d, (W - 30 * DP, 95 * DP), "Áudio: AAC 2.0", sp(25), BRANCO, "rm")
    t.alpha_composite(Image.new("RGBA", (W, max(1, int(round(DP)))), rgba(fio)), (0, int(20 * DP + ph)))
    d = ImageDraw.Draw(t)
    tw = 300 * DP
    ret(d, [(W - tw) / 2, 180 * DP, (W + tw) / 2, 230 * DP], pro, 0)
    texto(d, ((W) / 2, 205 * DP), "00:42 / 01:58", sp(26), BRANCO, "mm")
    return t


def tela_musica(a):
    """Player de musica HiSilicon: a lista de arquivos (FileListActivity, Theme.Dialog ->
    panel_background) por cima do player, e o botao tocar (MediaButton.Play -> ic_media_play)."""
    hm = a.himusic
    t = Image.new("RGBA", (W, H))
    colar(t, hm.img("hisil_background_3"), 0, 0, W, H)
    d = ImageDraw.Draw(t)
    # o botao tocar no rodape, com a moldura de foco do app (17A)
    bx, by, bw, bh = W / 2 - 50 * DP, H - 90 * DP, 100 * DP, 70 * DP
    colar(t, hm.img("hisil_lank_selected"), bx, by, bw, bh, nove_patch=True)
    colar(t, a.img("ic_media_play"), bx + (bw - 48 * DP) / 2, by + (bh - 48 * DP) / 2, 48 * DP, 48 * DP)
    # a janela da lista
    pw, ph = 520 * DP, 280 * DP
    px, py = (W - pw) / 2, 40 * DP
    colar(t, a.img("panel_background"), px, py, pw, ph, nove_patch=True)
    d = ImageDraw.Draw(t)
    claro = a.cor("background_light")              # primary_text_dark -> bright_foreground_dark
    for i, nome in enumerate(["musica.mp3", "show-ao-vivo.flac", "podcast.m4a", "trilha.ogg"]):
        y = py + 40 * DP + i * 55 * DP
        if i == 1:
            colar(t, hm.img("hisil_lank_selected"), px + 20 * DP, y - 22 * DP, pw - 40 * DP, 46 * DP, nove_patch=True)
            d = ImageDraw.Draw(t)
        texto(d, (px + 40 * DP, y), nome, sp(22), claro, "lm")
    return t


def tela_imagens(a):
    """... e a lista de capas (ImageListAcvitity, Theme.Holo.Dialog -> dialog_full_holo_dark)."""
    hm = a.himusic
    t = Image.new("RGBA", (W, H))
    colar(t, hm.img("hisil_background_3"), 0, 0, W, H)
    pw, ph = 560 * DP, 300 * DP
    px, py = (W - pw) / 2, (H - ph) / 2
    colar(t, a.img("dialog_full_holo_dark"), px, py, pw, ph, nove_patch=True)
    d = ImageDraw.Draw(t)
    claro = a.cor("background_light")
    texto(d, (px + 30 * DP, py + 40 * DP), "Imagens", sp(24), claro, "lm")
    for i, nome in enumerate(["capa.jpg", "encarte.png", "foto-do-show.jpg"]):
        texto(d, (px + 40 * DP, py + 100 * DP + i * 55 * DP), nome, sp(22), claro, "lm")
    return t


def app_musica(dec, sob):
    a = App(os.path.join(dec, "framework-res"), sob)
    a.himusic = App(os.path.join(dec, "HiMusic"), "himusic")    # o app ja no tema (17A) nos dois lados
    return a


TELAS = [
    ("Gerenciador de arquivos, página inicial (activity_main_other): os cartões", "ZYFileManager", "zyfilemanager",
     tela_arquivos, App),
    ("Lista de entradas (ZYCustomUI, layout_main) ao abrir, antes do primeiro foco", "ZYCustomUI", "zycustomui",
     tela_entradas, App),
    ("Wi-Fi (ZYSetting, layout_wifi): o fio sob Ativar / Desativar", "ZYSetting", "zysetting", tela_wifi, App),
    ("Player de vídeo (HiVideoPlayer, main_dpt_o): painel de informação e tempo", "HiVideoPlayer", "hivideoplayer",
     tela_video, App),
    ("Player de música: lista (panel_background) e botão tocar, pela do android", None, "android", tela_musica,
     app_musica),
    ("Player de música: lista de imagens (dialog_full_holo_dark), pela do android", None, "android", tela_imagens,
     app_musica),
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
    tit = fonte(D.NEGRITO, 30)
    rot = fonte("IBMPlexSansCondensed-Regular.ttf", 20)
    texto(d, (margem, margem), "Antes (fábrica)", tit, P["texto"])
    texto(d, (margem + W + gap, margem), "Depois (sobreposições Drácula, bloco 19B)", tit, P["roxo"])
    y = margem + cab
    for nome, app, sob, fn, fab in TELAS:
        if fab is App:
            antes, depois = App(os.path.join(dec, app)), App(os.path.join(dec, app), sob)
        else:
            antes, depois = fab(dec, None), fab(dec, sob)
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
