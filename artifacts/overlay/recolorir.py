#!/usr/bin/env python3
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

ZYSETTING = {
    'item_focus_white': ({'#FFFFFF': 'rosa'}, 1),
    'item_focus': ({'#FFFFFF': 'rosa', '#0FC4C2': 'rosa'}, 1),
    'pt_bt': ({'#1D3034': 'linha', '#FFFFFF': 'texto'}, 1),
    'pt_dlp': ({'#1D3034': 'linha', '#FFFFFF': 'texto'}, 1),
    'pt_other': ({'#1D3034': 'linha', '#FFFFFF': 'texto'}, 1),
    'pt_update': ({'#1D3034': 'linha', '#FFFFFF': 'texto'}, 1),
    'open_check_pt': ({'#00B26B': 'verde', '#FFFFFF': 'texto', '#000000': 'fundo'}, 1),
    'open_check_en': ({'#00B26B': 'verde', '#FFFFFF': 'texto', '#000000': 'fundo'}, 1),
    'open_check_es': ({'#00B26B': 'verde', '#FFFFFF': 'texto', '#000000': 'fundo'}, 1),
    'close_check_pt': ({'#153134': 'linha', '#FFFFFF': 'texto', '#000000': 'fundo'}, 1),
    'close_check_en': ({'#153134': 'linha', '#FFFFFF': 'texto', '#000000': 'fundo'}, 1),
    'close_check_es': ({'#153134': 'linha', '#FFFFFF': 'texto', '#000000': 'fundo'}, 1),
    'confirm_dialog_bg': ({'#000000': 'linha'}, 1),
    'edit_large_focus': ({'#82AA81': 'comentario'}, 1),
    'edit_large_normal': ({'#FFFFFF': 'fundo'}, 5),
    'button_bg_normal': ({'#000000': 'fundo', '#FFFFFF': 'comentario'}, 1),
    'button_bg_press': ({'#FFFFFF': 'rosa'}, 1),
    'selected_image': ({'#FFFFFF': 'texto', '#E97445': 'rosa'}, 1),
    'update': ({'#0A59F7': 'comentario'}, 1),
    'cancel': ({'#0A59F7': 'comentario'}, 1),
}

CHAVE = {
    'open_check_pt': ({'#00B26B': 'verde', '#FFFFFF': 'texto', '#000000': 'fundo'}, 1),
    'open_check_en': ({'#00B26B': 'verde', '#FFFFFF': 'texto', '#000000': 'fundo'}, 1),
    'open_check_es': ({'#00B26B': 'verde', '#FFFFFF': 'texto', '#000000': 'fundo'}, 1),
    'close_check_pt': ({'#153134': 'linha', '#FFFFFF': 'texto', '#000000': 'fundo'}, 1),
    'close_check_en': ({'#153134': 'linha', '#FFFFFF': 'texto', '#000000': 'fundo'}, 1),
    'close_check_es': ({'#153134': 'linha', '#FFFFFF': 'texto', '#000000': 'fundo'}, 1),
}
ZYBLUETOOTH = dict(CHAVE, item_focus=({'#FFFFFF': 'rosa'}, 1))

ZYFILEMANAGER = {
    'pt_list_folder_icon': ({'#163134': 'comentario'}, 1),
    'pt_list_audio_icon': ({'#163134': 'comentario'}, 1),
    'pt_list_music_icon': ({'#163134': 'comentario'}, 1),
    'pt_list_video_icon': ({'#163134': 'comentario'}, 1),
    'loading_pt': ({'#00B26B': 'rosa'}, 1),
}

HIGALLERY = {
    'gallery_selected': ({'#FFFFFF': 'rosa', '#2EA0FF': 'rosa', '#000000': 'fundo'}, 1),
}

ZYSPEAKERMODEL = {
    'pt_bg': ({'#163134': 'fundo', '#FFFFFF': 'texto', '#000000': '#000000'}, 1),
    'paly_paly_focus': ({'#159EFF': 'rosa', '#FFFFFF': 'fundo'}, 1),
    'paly_pause_focus': ({'#159EFF': 'rosa', '#FFFFFF': 'fundo'}, 1),
    'paly_back_focus': ({'#159EFF': 'rosa', '#FFFFFF': 'fundo'}, 1),
    'paly_forward_focus': ({'#159EFF': 'rosa', '#FFFFFF': 'fundo'}, 1),
    'lock_focus': ({'#159EFF': 'rosa', '#FFFFFF': 'fundo'}, 1),
}

FAIXA = {'video_bottom': ({'#001736': 'fundo', '#1A426D': 'linha', '#96A8BB': 'comentario',
                           '#000000': '#000000'}, 1)}
BOTAO = ({'#00184E': 'fundo', '#0099FD': 'rosa', '#FFFFFF': 'texto'}, 1)
IJKPLAYER = dict(FAIXA, pause_focus=BOTAO, play_focus=BOTAO, control_settings_focus=BOTAO)
HIVIDEOPLAYER = dict(FAIXA, pause_focus=BOTAO, play_focus=BOTAO, fastbackward_focus=BOTAO,
                     fastforward_focus=BOTAO, next_focus=BOTAO, previous_focus=BOTAO)

HIMUSIC = {
    'hisil_background_3': ({'#090934': 'fundo', '#A4D1E1': 'comentario', '#E8AA6F': 'comentario',
                            '#B43134': 'linha'}, 1),
    'hisil_lank_selected': ({'#11A9E1': 'rosa', '#000000': '#000000'}, 1),
    'hisil_yuandian': ({'#31AEDC': 'rosa', '#B0EAFF': 'texto'}, 1),
    'hisil_yuandian_selected': ({'#31AEDC': 'rosa', '#B0EAFF': 'texto'}, 1),
}

TECLA = {'#464646': 'linha', '#6B6B6B': 'linha', '#BABABA': 'linha', '#000000': '#000000'}
TECLA_FOCO = {'#787878': 'comentario', '#AFAFAF': 'comentario', '#DADADA': 'comentario', '#000000': 'rosa'}
SHIFT_ACESO = {'#B7E74B': 'verde', '#E4F9B2': 'texto'}
HIPINYINIME = {
    'skb_bg': ({'#272727': 'fundo'}, 1),
    'skb_container_bg': ({'#272727': 'fundo', '#848A90': 'comentario', '#000000': '#000000'}, 1),
    'normal_key_bg': (TECLA, 1),
    'light_key_bg': (TECLA, 1),
    'light_key_up_bg': (dict(TECLA, **SHIFT_ACESO), 1),
    'normal_key_hl_bg': (TECLA_FOCO, 1),
    'light_key_hl_bg': (TECLA_FOCO, 1),
    'light_key_up_hl_bg': (dict(TECLA_FOCO, **SHIFT_ACESO), 1),
    'cands_container_bg': ({'#FAFAFA': 'linha', '#636163': 'comentario'}, 1),
    'candidates_area_bg': ({'#FFFFFF': 'linha', '#F3F3F3': 'linha', '#777C81': 'comentario',
                            '#474C52': 'fundo'}, 1),
    'candidates_vertical_line': ({'#D8D8D8': 'comentario'}, 1),
    'arrow_left': ({'#333333': 'texto'}, 1),
    'arrow_right': ({'#333333': 'texto'}, 1),
    'candidate_hl_bg': ({'#FFA61A': 'rosa', '#FF8A1E': 'rosa', '#000000': '#000000'}, 1),
    'composing_area_bg': ({'#FFFFFF': 'linha', '#909398': 'comentario', '#000000': '#000000'}, 1),
    'composing_hl_bg': ({'#FFA335': 'rosa', '#FF9030': 'rosa', '#000000': '#000000'}, 1),
    'composing_area_cursor': ({'#FF7E00': 'rosa', '#E57100': 'rosa'}, 1),
}

PAREAMENTO = ({'#1F1F1F': '#1F1F1F', '#000000': '#000000', '#FFFFFF': '#FFFFFF',
               '#002060': 'fundo', '#0052BD': 'linha', '#006BEF': 'comentario',
               '#76C8FB': 'roxo', '#D82E2E': '#D82E2E'}, 1)
ZYCUSTOMUI = {'match_ir_yuyin1280x800': PAREAMENTO, 'match_ir_jinju': PAREAMENTO}

ANDROID = {
    'ic_media_play': ({'#FFFFFF': 'texto', '#7F7F7F': '#7F7F7F'}, 1),
    'ic_media_pause': ({'#FFFFFF': 'texto', '#7F7F7F': '#7F7F7F'}, 1),
    'panel_background': ({'#000000': 'fundo', '#505050': 'comentario'}, 1),
    'dialog_full_holo_dark': ({'#282828': 'fundo', '#343434': 'linha', '#000000': '#000000'}, 1),
}

TABELAS = {'zysetting': ZYSETTING, 'zybluetooth': ZYBLUETOOTH, 'zyfilemanager': ZYFILEMANAGER,
           'higallery': HIGALLERY, 'zyspeakermodel': ZYSPEAKERMODEL, 'ijkplayer': IJKPLAYER,
           'hivideoplayer': HIVIDEOPLAYER, 'himusic': HIMUSIC, 'hipinyinime': HIPINYINIME,
           'zycustomui': ZYCUSTOMUI, 'android': ANDROID}

def melhor(px, ancoras):
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

def ancoras(mapa):
    return [hexrgb(k) for k in mapa], [PAL[v] if v in PAL else hexrgb(v) for v in mapa.values()]

def nova_cor(k, orig, novo):
    i, j, t = melhor(k, orig)
    if j is None:
        return novo[i]
    return tuple(round(novo[i][c] + t * (novo[j][c] - novo[i][c])) for c in range(3))

def recolorir_gif(src, dst, mapa):
    orig, novo = ancoras(mapa)
    b = bytearray(open(src, 'rb').read())
    if b[:6] not in (b'GIF87a', b'GIF89a'):
        raise SystemExit(f'nao e GIF: {src}')
    def tabela(pos, flags):
        n = 3 * (2 << (flags & 7))
        for p in range(pos, pos + n, 3):
            b[p:p + 3] = bytes(nova_cor(tuple(b[p:p + 3]), orig, novo))
        return pos + n
    def blocos(pos):
        while b[pos]:
            pos += b[pos] + 1
        return pos + 1
    pos = 13
    if b[10] & 0x80:
        pos = tabela(pos, b[10])
    while b[pos] != 0x3B:
        if b[pos] == 0x21:
            pos = blocos(pos + 2)
        elif b[pos] == 0x2C:
            flags = b[pos + 9]
            pos += 10
            if flags & 0x80:
                pos = tabela(pos, flags)
            pos = blocos(pos + 1)
        else:
            raise SystemExit(f'GIF com bloco desconhecido 0x{b[pos]:02x} em {pos}: {src}')
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    open(dst, 'wb').write(b)

def recolorir(src, dst, mapa, malfa):
    if src.endswith('.gif'):
        return recolorir_gif(src, dst, mapa)
    orig, novo = ancoras(mapa)
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
                cache[k] = nova_cor(k, orig, novo)
            nr, ng, nb = cache[k]
            px[x, y] = (nr, ng, nb, min(255, a * malfa))
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    im.save(dst, optimize=True)

def main():
    alvo, saida = sys.argv[1], sys.argv[2]
    tabela = TABELAS[sys.argv[3] if len(sys.argv) > 3 else 'zysetting']
    n = 0
    for nome, (mapa, malfa) in sorted(tabela.items()):
        fontes = sorted(f for pasta in ('drawable*', 'mipmap*') for ext in ('.png', '.9.png', '.gif')
                        for f in glob.glob(os.path.join(alvo, 'res', pasta, nome + ext)))
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
