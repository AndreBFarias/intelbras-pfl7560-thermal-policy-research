#!/usr/bin/env python3
# artifacts/overlay/recolorir.py - troca as cores das imagens do fabricante pela paleta Dracula,
# sem mudar o desenho (bloco 13A).
#
#   python3 -I artifacts/overlay/recolorir.py <ZYSetting desmontado pelo apktool> artifacts/overlay/zysetting/res
#
# Roda UMA vez por firmware, sobre o app desmontado (apktool d, que devolve os 9-patch com a
# borda de marcacao). A saida vai para o res/ da sobreposicao e entra no git: o build.sh nao
# precisa do firmware. Para cada recurso da tabela, recolore TODAS as variantes que o alvo tem
# (drawable/, drawable-hdpi/...), com o mesmo nome e a mesma pasta: a sobreposicao so ganha do
# alvo na configuracao que ela mesma oferece.
#
# Como recolore: cada pixel e escrito como mistura de duas cores-ancora do desenho original
# (ex.: o fundo teal e o branco do icone, com o antisserrilhado entre elas) e reescrito com a
# mesma mistura das cores Dracula correspondentes. O alfa e mantido (ou multiplicado, quando a
# tabela pede). Num .9.png a borda de 1 px (marcacao de estica e de margem) fica intacta.
import os, sys, glob
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
PAL = {}
with open(os.path.join(AQUI, '..', 'tema', 'dracula.txt'), encoding='utf-8') as f:
    for ln in f:
        if '=' in ln:
            k, v = ln.strip().split('=')
            PAL[k] = tuple(int(v[i:i + 2], 16) for i in (1, 3, 5))

def hexrgb(s):
    return tuple(int(s[i:i + 2], 16) for i in (1, 3, 5))

# recurso -> (ancoras {cor de fabrica: token Dracula}, multiplicador de alfa)
TABELA = {
    # moldura de foco das listas (estilo rgtp_ui=1) e a do outro estilo: branco -> rosa
    'item_focus_white': ({'#FFFFFF': 'rosa'}, 1),
    'item_focus': ({'#FFFFFF': 'rosa', '#0FC4C2': 'rosa'}, 1),
    # os 4 cartoes da tela principal das Configuracoes: teal -> linha, icone branco -> texto
    'pt_bt': ({'#1D3034': 'linha', '#FFFFFF': 'texto'}, 1),
    'pt_dlp': ({'#1D3034': 'linha', '#FFFFFF': 'texto'}, 1),
    'pt_other': ({'#1D3034': 'linha', '#FFFFFF': 'texto'}, 1),
    'pt_update': ({'#1D3034': 'linha', '#FFFFFF': 'texto'}, 1),
    # chave Ligado/Desligado (texto pintado na imagem): verde -> verde, teal -> linha
    'open_check_pt': ({'#00B26B': 'verde', '#FFFFFF': 'texto', '#000000': 'fundo'}, 1),
    'open_check_en': ({'#00B26B': 'verde', '#FFFFFF': 'texto', '#000000': 'fundo'}, 1),
    'open_check_es': ({'#00B26B': 'verde', '#FFFFFF': 'texto', '#000000': 'fundo'}, 1),
    'close_check_pt': ({'#153134': 'linha', '#FFFFFF': 'texto', '#000000': 'fundo'}, 1),
    'close_check_en': ({'#153134': 'linha', '#FFFFFF': 'texto', '#000000': 'fundo'}, 1),
    'close_check_es': ({'#153134': 'linha', '#FFFFFF': 'texto', '#000000': 'fundo'}, 1),
    # janela de senha do Wi-Fi: painel preto -> linha; campo em foco verde -> comentario
    # (o texto do campo e branco fixo no layout); campo parado branco 20% -> fundo cheio
    'confirm_dialog_bg': ({'#000000': 'linha'}, 1),
    'edit_large_focus': ({'#82AA81': 'comentario'}, 1),
    'edit_large_normal': ({'#FFFFFF': 'fundo'}, 5),
    # botoes da janela de senha: parado preto com fio branco -> fundo com fio comentario;
    # em foco branco -> rosa (o texto em foco vem do color/button_text, que vira fundo)
    'button_bg_normal': ({'#000000': 'fundo', '#FFFFFF': 'comentario'}, 1),
    'button_bg_press': ({'#FFFFFF': 'rosa'}, 1),
}

def melhor(px, ancoras):
    """(i, j, t): px ~ ancora i misturada com j na fracao t (j=None: so i)."""
    best = None
    for i, a in enumerate(ancoras):
        d = sum((px[k] - a[k]) ** 2 for k in range(3))
        if best is None or d < best[0]:
            best = (d, i, None, 0.0)
        for j in range(i + 1, len(ancoras)):
            b = ancoras[j]
            v = [b[k] - a[k] for k in range(3)]
            vv = sum(c * c for c in v)
            t = max(0.0, min(1.0, sum((px[k] - a[k]) * v[k] for k in range(3)) / vv))
            q = [a[k] + t * v[k] for k in range(3)]
            d = sum((px[k] - q[k]) ** 2 for k in range(3))
            if d < best[0]:
                best = (d, i, j, t)
    return best[1:]

def recolorir(src, dst, mapa, malfa):
    orig = [hexrgb(k) for k in mapa]
    novo = [PAL[v] for v in mapa.values()]
    im = Image.open(src).convert('RGBA')
    w, h = im.size
    nove = src.endswith('.9.png')
    px = im.load()
    cache = {}
    for y in range(h):
        for x in range(w):
            if nove and (x in (0, w - 1) or y in (0, h - 1)):
                continue
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            k = (r, g, b)
            if k not in cache:
                i, j, t = melhor(k, orig)
                if j is None:
                    cache[k] = novo[i]
                else:
                    cache[k] = tuple(round(novo[i][c] + t * (novo[j][c] - novo[i][c])) for c in range(3))
            nr, ng, nb = cache[k]
            px[x, y] = (nr, ng, nb, min(255, a * malfa))
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    im.save(dst, optimize=True)

def main():
    alvo, saida = sys.argv[1], sys.argv[2]
    n = 0
    for nome, (mapa, malfa) in sorted(TABELA.items()):
        fontes = sorted(glob.glob(os.path.join(alvo, 'res', 'drawable*', nome + '.png')) +
                        glob.glob(os.path.join(alvo, 'res', 'drawable*', nome + '.9.png')))
        if not fontes:
            raise SystemExit(f'FALTA no alvo: {nome}')
        for f in fontes:
            pasta = os.path.basename(os.path.dirname(f))
            dst = os.path.join(saida, pasta, os.path.basename(f))
            recolorir(f, dst, mapa, malfa)
            print(f'{pasta}/{os.path.basename(f)}')
            n += 1
    print(f'{n} imagens')

main()
