#!/usr/bin/env python3
"""Folha de previa do bloco 18: artifacts/overlay/previa/antes-depois-18.png.

  python3 -I artifacts/overlay/gerar-previa-18.py <pasta com os apps desmontados pelo apktool>

A pasta precisa ter as subpastas HiPinyinIME, NLHotkeyService, ZYCustomUI, HiTvSetting,
PackageInstaller, NewLinkService e framework-res (apktool d dos APKs do firmware; doc 48, secao
Metodo). Mesmo metodo da gerar-previa-17a.py (de onde vem a classe App, a escala e as fontes): as
cores e as formas de fabrica sao lidas do app desmontado; as novas, de cada sobreposicao em
artifacts/overlay. Desenho com os valores, nao captura; posicoes e tamanhos dos layouts do
fabricante em dp (densidade 1,5), escalados para caber na folha. So para olhar: nao vai para o kit.
Precisa do Pillow.
"""
import importlib.util
import os
import sys

from PIL import Image, ImageDraw

AQUI = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("previa17a", os.path.join(AQUI, "gerar-previa-17a.py"))
C = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(C)          # so as funcoes: o main() dela so roda como script

A, B = C.A, C.B
P, rgba, colar, texto, fonte = B.P, B.rgba, B.colar, B.texto, B.fonte
W, H, K, DP = B.W, B.H, B.K, B.DP
ret, sp, pintar, escurecer = A.ret, A.sp, C.pintar, C.escurecer
SAIDA = os.path.join(AQUI, "previa", "antes-depois-18.png")
BRANCO = "#FFFFFFFF"
PRETO = "#FF000000"
NEGRITO = C.NEGRITO


class App(C.App):
    def __init__(self, dec, sob=None):
        super().__init__(dec, sob)
        # cores so da configuracao television (PackageInstaller): a de fabrica e, por cima, a nova
        for base in [self.dec] + ([self.sob] if self.sob else []):
            self.cores.update(A.cores_xml(os.path.join(base, "values-television", "colors.xml")))

    def forma(self, nome):
        """Como a da 17A, mas resolvendo @color/x da forma de fabrica pelas cores do app."""
        import re
        for base in ([self.sob] if self.sob else []) + [self.dec]:
            p = os.path.join(base, "drawable", nome + ".xml")
            if os.path.isfile(p):
                with open(p, encoding="utf-8") as f:
                    s = re.sub(r"@color/(\w+)", lambda m: self.cores[m.group(1)], f.read())
                    s = s.replace("@android:color/white", "#FFFFFFFF")
                cheio = re.search(r'<solid[^>]*android:color="(#[0-9A-Fa-f]+)"', s)
                deg = re.search(r'android:startColor="(#[0-9A-Fa-f]+)"[^>]*android:endColor="(#[0-9A-Fa-f]+)"', s)
                fio = re.search(r'<stroke[^>]*android:width="([\d.]+)(?:dip|dp)"[^>]*android:color="(#[0-9A-Fa-f]+)"', s)
                return (cheio.group(1) if cheio else None, deg.groups() if deg else None,
                        fio.group(2) if fio else None, float(fio.group(1)) if fio else 0)
        raise SystemExit("falta a forma %s" % nome)

    def gif(self, nome):
        """Primeiro quadro do GIF (o da sobreposicao, se ela tiver)."""
        for base in ([self.sob] if self.sob else []) + [self.dec]:
            p = os.path.join(base, "drawable", nome + ".gif")
            if os.path.isfile(p):
                im = Image.open(p)
                im.seek(0)
                return im.convert("RGBA")
        raise SystemExit("falta o gif %s" % nome)


def fundo_qualquer():
    """Uma tela escura qualquer por tras dos avisos."""
    return Image.new("RGBA", (W, H), rgba("#FF3A3F4B"))


def tela_teclado(a):
    # campo de senha do Wi-Fi por tras; o teclado ocupa a parte de baixo
    t = fundo_qualquer()
    d = ImageDraw.Draw(t)
    texto(d, (W / 2, 60 * DP), "Senha do Wi-Fi", sp(26), BRANCO, "mm")
    kh = 250 * DP
    ky = H - kh
    colar(t, a.img("skb_container_bg"), 0, ky - 50 * DP, W, kh + 50 * DP, nove_patch=True)
    colar(t, a.img("skb_bg"), 0, ky, W, kh)
    # barra de candidatos (modo pinyin) em cima do teclado
    colar(t, a.img("candidates_area_bg"), 0, ky - 50 * DP, W, 50 * DP, nove_patch=True)
    d = ImageDraw.Draw(t)
    cands = ["ni", "nihao", "nin", "nian", "niu"]   # a fonte da folha nao tem CJK: so a cor importa
    cx = 60 * DP
    for i, c in enumerate(cands):
        cw = 90 * DP
        if i == 1:
            colar(t, a.img("candidate_hl_bg"), cx, ky - 46 * DP, cw, 42 * DP, nove_patch=True)
            d = ImageDraw.Draw(t)
            cor = a.cor("active_candidate_color")
        else:
            cor = a.cor("recommended_candidate_color" if i == 0 else "candidate_color")
        texto(d, (cx + cw / 2, ky - 25 * DP), c, sp(24), cor, "mm")
        texto(d, (cx + 8 * DP, ky - 42 * DP), str(i + 1), sp(12), a.cor("footnote_color"))
        cx += cw + 10 * DP
    colar(t, a.img("arrow_right"), W - 30 * DP, ky - 32 * DP, 15 * DP, 21 * DP)
    # quatro linhas de teclas
    linhas = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
    tw, th = W / 10, kh / 4
    for r, ln in enumerate(linhas):
        x0 = (W - len(ln) * tw) / 2
        for i, ch in enumerate(ln):
            foco = (r == 1 and i == 4)
            nome = "normal_key_hl_bg" if foco else "normal_key_bg"
            x, y = x0 + i * tw, ky + r * th
            colar(t, a.img(nome), x, y, tw, th, nove_patch=True)
            texto(ImageDraw.Draw(t), (x + tw / 2, y + th / 2), ch, sp(26), a.cor("label_color"), "mm")
    # ultima linha: shift aceso, ?123, espaco e enter
    y = ky + 3 * th
    for x, w, nome, rot in ((0, 2 * tw, "light_key_up_bg", "Shift"), (2 * tw, 1.5 * tw, "light_key_bg", "?123"),
                            (3.5 * tw, 4.5 * tw, "normal_key_bg", "espaço"), (8 * tw, 2 * tw, "normal_key_bg", "OK")):
        colar(t, a.img(nome), x, y, w, th, nove_patch=True)
        texto(ImageDraw.Draw(t), (x + w / 2, y + th / 2), rot, sp(22), a.cor("label_color"), "mm")
    return t


def tela_atalho(a):
    t = fundo_qualquer()
    escurecer(t)
    pw, ph = 572 * K, 260 * DP          # o layout my_dialog usa px de tela (572 px)
    px, py = (W - pw) / 2, (H - ph) / 2
    pintar(t, a, "bg_white_90", [px, py, px + pw, py + ph], 20 * K)
    d = ImageDraw.Draw(t)
    texto(d, (W / 2, py + 70 * DP), "Restaurar os padrões de fábrica?", sp(22), "#FF333333", "mm")
    for i, rot in enumerate(["OK", "Cancelar"]):
        bw, bh = 238 * K, 77 * K
        bx, by = px + pw / 4 + i * pw / 2 - bw / 2, py + ph - bh - 30 * DP
        foco = i == 0
        pintar(t, a, "button_bg_itemcolor" if foco else "button_bg_item_white", [bx, by, bx + bw, by + bh], 40 * DP)
        texto(ImageDraw.Draw(t), (bx + bw / 2, by + bh / 2), rot, sp(20), BRANCO if foco else PRETO, "mm")
    return t


def tela_entradas(a):
    t = fundo_qualquer()
    d = ImageDraw.Draw(t)
    gw = 400 * DP
    itens = ["Início", "HDMI 1", "HDMI 2", "USB"]
    ih, gap = 52 * DP, 8 * DP
    gh = 70 * DP + len(itens) * (ih + gap)
    gx, gy = (W - gw) / 2, (H - gh) / 2
    ret(d, [gx, gy, gx + gw, gy + gh], a.cor("pt_grey_white"), 0)
    texto(d, (W / 2, gy + 35 * DP), "Entrada", sp(26), a.titulo, "mm")
    for i, rot in enumerate(itens):
        y = gy + 70 * DP + i * (ih + gap)
        ret(d, [gx + 60 * DP, y, gx + gw - 60 * DP, y + ih], a.cor("pt_green" if i == 1 else "pt_green_black"), 0)
        texto(d, (W / 2, y + ih / 2), rot, sp(24), BRANCO, "mm")
    return t


def tela_pareamento(a):
    t = Image.new("RGBA", (W, H))
    colar(t, a.gif("match_ir_yuyin1280x800"), 0, 0, W, H)
    return t


def tela_menu_imagem(a):
    # a entrada HDMI por tras (um degrade qualquer) e o menu a direita
    t = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(t)
    for y in range(H):
        f = y / H
        d.line([(0, y), (W, y)], fill=(int(60 + 50 * f), int(80 + 30 * f), int(50 + 20 * f), 255))
    mw = 420 * DP
    mx = W - mw
    ret(d, [mx, 0, W, H], a.cor("back_color"), 0)
    ret(d, [mx, 0, W, 90 * DP], "#55000000", 0)
    texto(d, (mx + 20 * DP, 55 * DP), "Imagem", sp(22), BRANCO, "lm")
    linhas = [("Modo de imagem", "Padrão"), ("Brilho", 50), ("Contraste", 50), ("Nitidez", None), ("Temperatura de cor", "Normal")]
    y = 92 * DP
    for i, (rot, val) in enumerate(linhas):
        lh = 60 * DP
        if i == 1:
            ret(d, [mx, y, W, y + lh], a.cor("selct_back_color"), 0)
        texto(d, (mx + 20 * DP, y + lh / 2), rot, sp(20), BRANCO if val is not None else "#FF6B6B6B", "lm")
        if isinstance(val, int):
            bx0, bx1, by = mx + 210 * DP, W - 60 * DP, y + lh / 2
            ret(d, [bx0, by - 4 * DP, bx1, by + 4 * DP], a.cor("seekbar_bg_color"), 4 * DP)
            cheio = a.cor("seekbar_progress_fill_enable_color")
            ret(d, [bx0, by - 4 * DP, bx0 + (bx1 - bx0) * val / 100, by + 4 * DP], cheio, 4 * DP)
            texto(d, (W - 20 * DP, by), str(val), sp(18), BRANCO, "rm")
        elif val:
            texto(d, (W - 20 * DP, y + lh / 2), "‹  %s  ›" % val, sp(18), BRANCO, "rm")
        y += lh
    return t


def tela_permissao(a):
    t = fundo_qualquer()
    escurecer(t, 160)
    d = ImageDraw.Draw(t)
    pw, ph = 560 * DP, 220 * DP
    px, py = (W - pw) / 2, H - ph - 40 * DP
    ret(d, [px, py, px + pw, py + ph], a.cor("grant_permissions_background_color"), 0)
    texto(d, (px + 30 * DP, py + 40 * DP), "Permitir que o VLC acesse fotos, mídia e arquivos?", sp(18), "#FFEEEEEE")
    for i, rot in enumerate(["NEGAR", "PERMITIR"]):
        bx, by = px + 30 * DP, py + 100 * DP + i * 50 * DP
        if i == 1:
            ret(d, [bx - 8 * DP, by - 6 * DP, bx + 200 * DP, by + 34 * DP], a.cor("grant_permissions_focus_highlight"), 2 * DP)
        texto(d, (bx, by + 14 * DP), rot, sp(16), "#FFEEEEEE", "lm")
    return t


def tela_desligar(a):
    """A contagem de desligar do 17A com o titulo da sobreposicao do android (holo_red_dark)."""
    t = Image.new("RGBA", (W, H), rgba("#FF101418"))
    d = ImageDraw.Draw(t)
    pw, ph = 600 * DP, 220 * DP
    px, py = (W - pw) / 2, (H - ph) / 2
    ret(d, [px, py, px + pw, py + ph], a.nl.cor("black"), 0)
    texto(d, (W / 2, py + 45 * DP), "O projetor vai desligar em 30 s", sp(26), a.cor("holo_red_dark"), "mm")
    texto(d, (W / 2, py + 90 * DP), "Aperte qualquer botão para continuar ligado", sp(20), BRANCO, "mm")
    for i, rot in enumerate(["Desligar agora", "Cancelar"]):
        bx, by = px + 70 * DP + i * 250 * DP, py + ph - 75 * DP
        ret(d, [bx, by, bx + 210 * DP, by + 50 * DP], a.nl.cor("red" if i == 0 else "black"), 0)
        texto(d, (bx + 105 * DP, by + 25 * DP), rot, sp(22), BRANCO, "mm")
    return t


def tela_toast(a):
    """ToastActivity do NewLinkService: tela cheia @android:color/background_light, texto preto."""
    t = Image.new("RGBA", (W, H), rgba(a.cor("background_light")))
    texto(ImageDraw.Draw(t), (W / 2, H / 2), "Atualização concluída", sp(48), PRETO, "mm")
    return t


def app_entradas(dec, sob):
    a = App(os.path.join(dec, "ZYCustomUI"), sob)
    # o titulo nao tem cor no codigo: a de texto do tema escuro (primary_text_dark ->
    # bright_foreground_dark -> background_light do framework, que a do android troca)
    fw = App(os.path.join(dec, "framework-res"), "android" if sob else None)
    a.titulo = fw.cor("background_light")
    return a


def app_android(dec, sob):
    a = App(os.path.join(dec, "framework-res"), sob)
    a.nl = App(os.path.join(dec, "NewLinkService"), "newlinkservice" if sob else None)
    return a


TELAS = [
    ("Teclado na tela (HiPinyinIME), foco no G e candidato 2", "HiPinyinIME", "hipinyinime", tela_teclado, App),
    ("Aviso de tecla de atalho (NLHotkeyService, MyDialog), foco em OK", "NLHotkeyService", "nlhotkeyservice",
     tela_atalho, App),
    ("Lista de entradas (ZYCustomUI, SourceUIActivity), foco em HDMI 1", None, "zycustomui", tela_entradas, app_entradas),
    ("Pareamento do controle (ZYCustomUI, GIF animado, 1o quadro)", "ZYCustomUI", "zycustomui", tela_pareamento, App),
    ("Menu de imagem das entradas (HiTvSetting), foco em Brilho", "HiTvSetting", "hitvsetting", tela_menu_imagem, App),
    ("Pedido de permissão no modo TV (PackageInstaller), foco em Permitir", "PackageInstaller", "packageinstaller",
     tela_permissao, App),
    ("Contagem de desligar: título vermelho pela sobreposição do android", None, "android", tela_desligar, app_android),
    ("ToastActivity do NewLinkService (background_light pela do android)", "framework-res", "android", tela_toast, App),
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
    texto(d, (margem + W + gap, margem), "Depois (sobreposições Drácula, bloco 18)", tit, P["roxo"])
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
