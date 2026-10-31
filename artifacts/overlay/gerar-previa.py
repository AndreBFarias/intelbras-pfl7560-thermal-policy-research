#!/usr/bin/env python3
"""Folha de previa do bloco 13A: artifacts/overlay/previa/antes-depois.png.

  python3 -I artifacts/overlay/gerar-previa.py <ZYSetting desmontado pelo apktool>

Desenha, lado a lado, cada tela do fabricante antes (cores e imagens de fabrica, lidas do app
desmontado) e depois (as cores das sobreposicoes e as imagens recoloridas de
artifacts/overlay/zysetting/res). Desenho com os valores, nao captura: posicoes e tamanhos
seguem os layouts do fabricante em dp (densidade 1,5, a dos recursos hdpi), escalados para
caber na folha. A fonte e a IBM Plex do kit; no aparelho o texto sai na fonte do sistema.
So para olhar: nao vai para o kit. Precisa do Pillow.
"""
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.join(AQUI, "..", "..")
FONTES = os.path.join(RAIZ, "pendrive-autorun", "fontes")
SAIDA = os.path.join(AQUI, "previa", "antes-depois.png")


def paleta():
    p = {}
    with open(os.path.join(RAIZ, "artifacts", "tema", "dracula.txt"), encoding="utf-8") as f:
        for ln in f:
            if "=" in ln:
                k, v = ln.strip().split("=")
                p[k] = v
    return p


def rgba(h):
    h = h.lstrip("#")
    if len(h) == 6:
        h = "ff" + h
    return (int(h[2:4], 16), int(h[4:6], 16), int(h[6:8], 16), int(h[0:2], 16))


def cores_overlay(arq):
    with open(arq, encoding="utf-8") as f:
        return {n: v for n, v in re.findall(r'<color name="([^"]+)">(#[0-9A-Fa-f]+)<', f.read())}


P = paleta()
ZY_NOVO = cores_overlay(os.path.join(AQUI, "zysetting", "res", "values", "colors.xml"))
FW_NOVO = cores_overlay(os.path.join(AQUI, "android", "res", "values", "colors.xml"))

# Valores de fabrica (aapt2 dump resources dos APKs do firmware; doc 48).
ANTES = {
    "pt_green": "#FF00B26B", "pt_green_black": "#FF163134",
    "btn_txt_foco": "#FF000000", "btn_txt": "#FFFFFFFF",
    "lb_fundo": "#FFEEEEEE", "lb_texto": "#CC222222", "lb_sec": "#99222222",
    "realce": "#1F000000",
}
DEPOIS = {
    "pt_green": ZY_NOVO["pt_green"], "pt_green_black": ZY_NOVO["pt_green_black"],
    "btn_txt_foco": P["fundo"], "btn_txt": P["texto"],
    "lb_fundo": FW_NOVO["background_leanback_light"],
    "lb_texto": FW_NOVO["primary_text_leanback_light"],
    "lb_sec": FW_NOVO["secondary_text_leanback_light"],
    "realce": "#1F000000",       # ripple_material_light: a sobreposicao NAO muda
}
ACENTO_MATERIAL = "#FF009688"   # colorAccent do Material claro: a sobreposicao NAO muda

W, H = 768, 432            # cada tela: 1920x1080 em 0,4
K = W / 1920.0             # px da tela -> px da folha
DP = 1.5 * K               # dp -> px da folha (densidade 1,5)
MARG, GAP, ROT, CAB = 40, 24, 40, 70


def fonte(nome, tam):
    return ImageFont.truetype(os.path.join(FONTES, nome), max(8, int(round(tam))))


def sp(n):
    return fonte("IBMPlexSansCondensed-Regular.ttf", n * DP)


def nove(img, w, h):
    """Desenha um .9.png (com a borda de marcacao) esticado para w x h."""
    im = img.convert("RGBA")
    iw, ih = im.size
    top = [x for x in range(1, iw - 1) if im.getpixel((x, 0))[3] > 0]
    lef = [y for y in range(1, ih - 1) if im.getpixel((0, y))[3] > 0]
    c = im.crop((1, 1, iw - 1, ih - 1))
    cw, ch = c.size
    x0, x1 = (top[0] - 1, top[-1]) if top else (cw // 2, cw // 2 + 1)
    y0, y1 = (lef[0] - 1, lef[-1]) if lef else (ch // 2, ch // 2 + 1)
    w, h = max(w, cw - (x1 - x0) + 1), max(h, ch - (y1 - y0) + 1)
    xs = [(0, x0, 0, x0), (x0, x1, x0, w - (cw - x1)), (x1, cw, w - (cw - x1), w)]
    ys = [(0, y0, 0, y0), (y0, y1, y0, h - (ch - y1)), (y1, ch, h - (ch - y1), h)]
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for sx0, sx1, dx0, dx1 in xs:
        for sy0, sy1, dy0, dy1 in ys:
            if sx1 > sx0 and sy1 > sy0 and dx1 > dx0 and dy1 > dy0:
                out.alpha_composite(c.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0)), (dx0, dy0))
    return out


def colar(tela, img, x, y, w=None, h=None, nove_patch=False):
    if nove_patch:
        # o 9-patch e hdpi: desenha no tamanho em px de tela e escala junto
        im = nove(img, int(round(w / K)), int(round(h / K)))
        im = im.resize((max(1, int(round(im.width * K))), max(1, int(round(im.height * K)))))
    else:
        im = img.convert("RGBA")
        if w is None:
            w, h = im.width * K, im.height * K
        im = im.resize((max(1, int(round(w))), max(1, int(round(h)))))
    tela.alpha_composite(im, (int(round(x)), int(round(y))))


def texto(d, xy, s, f, cor, ancora="la"):
    d.text(xy, s, font=f, fill=rgba(cor), anchor=ancora)


class Imgs:
    def __init__(self, base):
        self.base = base

    def __call__(self, nome):
        for pasta in ("drawable-hdpi", "drawable"):
            for ext in (".9.png", ".png"):
                p = os.path.join(self.base, pasta, nome + ext)
                if os.path.isfile(p):
                    return Image.open(p)
        raise SystemExit("falta a imagem %s em %s" % (nome, self.base))


def tela_principal(img, c):
    t = Image.new("RGBA", (W, H), rgba(c["pt_green"]))
    d = ImageDraw.Draw(t)
    lado, gap = 240 * DP, 10 * DP
    x0, y0 = (W - 2 * lado - gap) / 2, (H - 2 * lado - gap) / 2
    nomes = [("pt_bt", "Bluetooth"), ("pt_dlp", "Projeção"), ("pt_update", "Sistema"), ("pt_other", "Configurações")]
    for i, (n, rot) in enumerate(nomes):
        x, y = x0 + (i % 2) * (lado + gap), y0 + (i // 2) * (lado + gap)
        colar(t, img(n), x, y, lado, lado)
        texto(d, (x + lado / 2, y + lado - 8 * DP), rot, sp(22), "#FFFFFFFF", "ms")
    m = 12 * DP
    colar(t, img("item_focus_white"), x0 - m, y0 - m, lado + 2 * m, lado + 2 * m, nove_patch=True)
    return t


def tela_wifi(img, c):
    t = Image.new("RGBA", (W, H), rgba(c["pt_green"]))
    d = ImageDraw.Draw(t)
    colar(t, img("left"), 60 * DP, 40 * DP)
    texto(d, (80 * DP, 32 * DP), "Wi-Fi", sp(28), "#FFFFFFFF")
    lx, lw = (W - 825 * DP) / 2, 825 * DP
    y = 100 * DP
    texto(d, (lx + 20 * DP, y + 30 * DP), "Ativar / Desativar", sp(22), "#FFFFFFFF", "lm")
    ch = img("open_check_pt")
    colar(t, ch, lx + lw - 20 * DP - ch.width * K, y + 30 * DP - ch.height * K / 2)
    d.line([(lx, y + 62 * DP), (lx + lw, y + 62 * DP)], fill=(0, 0, 0, 255), width=1)
    redes = [("Casa 5G", "wifi_lock_signal_3"), ("Escritório", "wifi_lock_signal_2"), ("Visitantes", "wifi_signal_1")]
    for i, (nome, ic) in enumerate(redes):
        ry = y + 72 * DP + i * 66 * DP
        texto(d, (lx + 20 * DP, ry + 30 * DP), nome, sp(22), "#FFFFFFFF", "lm")
        im = img(ic)
        colar(t, im, lx + lw - 30 * DP - im.width * K, ry + 30 * DP - im.height * K / 2)
        if i == 0:
            m = 6 * DP
            colar(t, img("item_focus_white"), lx - m, ry - m, lw + 2 * m, 60 * DP + 2 * m, nove_patch=True)
    return t


def tela_senha(img, c):
    t = tela_wifi(img, c)
    t.alpha_composite(Image.new("RGBA", (W, H), (0, 0, 0, 150)))
    d = ImageDraw.Draw(t)
    pw, ph = 620 * DP, 330 * DP
    px, py = (W - pw) / 2, (H - ph) / 2
    colar(t, img("confirm_dialog_bg"), px, py, pw, ph, nove_patch=True)
    texto(d, (W / 2, py + 30 * DP), "Casa 5G", sp(26), "#FFFFFFFF", "mm")
    ew, eh = 300 * DP, 48 * DP
    linhas = [("Senha:", "edit_large_focus", "••••••••"), ("Exibir", "edit_large_normal", "Ativado")]
    for i, (rot, bg, val) in enumerate(linhas):
        ly = py + 70 * DP + i * 70 * DP
        texto(d, (px + 60 * DP, ly + eh / 2), rot, sp(20), "#FFFFFFFF", "lm")
        ex = px + 60 * DP + 140 * DP
        colar(t, img(bg), ex, ly, ew, eh, nove_patch=True)
        texto(d, (ex + ew / 2, ly + eh / 2), val, sp(20), "#FFFFFFFF", "mm")
    bw, bh = 180 * DP, 50 * DP
    by = py + ph - 80 * DP
    for i, (rot, foco) in enumerate([("Não", False), ("Conectar", True)]):
        bx = W / 2 - bw - 20 * DP + i * (bw + 40 * DP)
        colar(t, img("button_bg_press" if foco else "button_bg_normal"), bx, by, bw, bh)
        texto(d, (bx + bw / 2, by + bh / 2), rot, sp(20), c["btn_txt_foco"] if foco else c["btn_txt"], "mm")
    return t


def tela_hdmi(img, c):
    t = Image.new("RGBA", (W, H), rgba(P["fundo"]))
    t.alpha_composite(Image.new("RGBA", (W, H), (0, 0, 0, 120)))
    d = ImageDraw.Draw(t)
    pw = 381 * DP
    ph = 15 * DP + 30 * DP + 2 * 20 * DP * 1.3 + 30 * DP + 51 * DP + 15 * DP + 20 * DP
    px, py = (W - pw) / 2, (H - ph) / 2
    d.rectangle([px, py, px + pw, py + ph], fill=rgba(c["pt_green_black"]))
    f = sp(20)
    for i, ln in enumerate(["Dispositivo conectado.", "Deseja abrir HDMI1?"]):
        texto(d, (W / 2, py + 45 * DP + i * 26 * DP), ln, f, "#FFFFFFFF", "mt")
    bw, bh = 158 * DP, 51 * DP
    by = py + ph - 15 * DP - bh
    for i, (rot, foco) in enumerate([("Sim", True), ("Não", False)]):
        cx = px + pw / 4 + i * pw / 2
        if foco:
            d.rectangle([cx - bw / 2, by, cx + bw / 2, by + bh], fill=rgba(c["pt_green"]))
        texto(d, (cx, by + bh / 2), rot, sp(21), "#FFFFFFFF", "mm")
    return t


def tela_temperatura(img, c):
    t = Image.new("RGBA", (W, H), rgba(P["fundo"]))
    t.alpha_composite(Image.new("RGBA", (W, H), (0, 0, 0, 120)))
    d = ImageDraw.Draw(t)
    pw, ph = 560 * DP, 230 * DP
    px, py = (W - pw) / 2, (H - ph) / 2
    d.rounded_rectangle([px, py, px + pw, py + ph], radius=2 * DP, fill=rgba(c["lb_fundo"]))
    texto(d, (px + 24 * DP, py + 24 * DP), "Temperatura anormal", fonte("IBMPlexSansCondensed-SemiBold.ttf", 22 * DP), c["lb_texto"])
    msg = ["A temperatura atual é muito alta, o sistema será desligado",
           "automaticamente. Verifique se o ventilador está conectado",
           "normalmente."]
    for i, ln in enumerate(msg):
        texto(d, (px + 24 * DP, py + 70 * DP + i * 22 * DP), ln, sp(16), c["lb_sec"])
    bw, bh = 90 * DP, 40 * DP
    bx, by = px + pw - 24 * DP - bw, py + ph - 16 * DP - bh
    camada = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(camada).rounded_rectangle([bx, by, bx + bw, by + bh], radius=2 * DP, fill=rgba(c["realce"]))
    t.alpha_composite(camada)
    texto(d, (bx + bw / 2, by + bh / 2), "OK", fonte("IBMPlexSansCondensed-SemiBold.ttf", 16 * DP), ACENTO_MATERIAL, "mm")
    return t


TELAS = [
    ("Configurações (MainPTActivity), foco no 1º cartão", tela_principal),
    ("Wi-Fi (WifiSettingActivity), foco na 1ª rede", tela_wifi),
    ("Senha do Wi-Fi (WiFiConnectDialog), foco em Conectar", tela_senha),
    ("Aviso de HDMI (MyDialog, SYSTEM_ALERT), foco em Sim", tela_hdmi),
    ("Temperatura anormal (AlertDialog, tema Leanback claro)", tela_temperatura),
]


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    antes = Imgs(os.path.join(sys.argv[1], "res"))
    depois_zy = Imgs(os.path.join(AQUI, "zysetting", "res"))

    def depois(nome):
        try:
            return depois_zy(nome)
        except SystemExit:
            return antes(nome)     # imagem que a sobreposicao nao troca (setas, sinal de Wi-Fi)

    largura = 2 * MARG + 2 * W + GAP
    altura = 2 * MARG + CAB + len(TELAS) * (H + ROT) + (len(TELAS) - 1) * GAP
    folha = Image.new("RGBA", (largura, altura), rgba(P["fundo"]))
    d = ImageDraw.Draw(folha)
    tit = fonte("IBMPlexSansCondensed-SemiBold.ttf", 30)
    rot = fonte("IBMPlexSansCondensed-Regular.ttf", 20)
    texto(d, (MARG, MARG), "Antes (fábrica)", tit, P["texto"])
    texto(d, (MARG + W + GAP, MARG), "Depois (sobreposições Drácula)", tit, P["roxo"])
    y = MARG + CAB
    for nome, fn in TELAS:
        folha.alpha_composite(fn(antes, ANTES), (MARG, y))
        folha.alpha_composite(fn(depois, DEPOIS), (MARG + W + GAP, y))
        d.rectangle([MARG - 1, y - 1, MARG + W, y + H], outline=rgba(P["comentario"]))
        d.rectangle([MARG + W + GAP - 1, y - 1, MARG + 2 * W + GAP, y + H], outline=rgba(P["comentario"]))
        texto(d, (MARG, y + H + 10), nome, rot, "#FFB4BCCF")
        y += H + ROT + GAP
    os.makedirs(os.path.dirname(SAIDA), exist_ok=True)
    folha.convert("RGB").save(SAIDA, optimize=True)
    print(SAIDA)


if __name__ == "__main__":
    main()
