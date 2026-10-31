#!/usr/bin/env python3
# artifacts/overlay/conferir.py - confere cada sobreposicao (RRO) contra o APK do alvo (blocos 13A, 16A, 17A, 18 e 19B).
#
#   python3 -I artifacts/overlay/conferir.py <pasta com os APKs alvo extraidos do firmware>
#
# A pasta precisa ter (em qualquer subpasta) o APK de cada alvo, extraido do firmware (doc 48,
# secao Metodo): ZYSetting, NLProvision, framework-res, ZYBluetooth, ZYFileManager, TvSettings,
# HiGalleryL, NLSourcePlayer, PowerService, desde o 17A AutoFocus3, ZYSpeakerModel e
# NewLinkService (e os players) e, desde o 18, HiPinyinIME, NLHotkeyService, ZYCustomUI,
# HiTvSetting e PackageInstaller. O alvo de cada sobreposicao e achado pelo nome do
# pacote, nao pelo nome do arquivo.
#
# Para cada APK de artifacts/overlay/apk/ confere, com `aapt2 dump`:
#  1. o <overlay android:targetPackage> e o pacote de um APK alvo da pasta, e nao ha classes.dex;
#  2. todo recurso da sobreposicao existe no alvo com o MESMO tipo e o mesmo nome;
#  3. toda configuracao que o alvo tem para o recurso (ex.: hdpi-v4) a sobreposicao tambem tem
#     (senao, na configuracao que falta, o recurso do alvo ganha e a troca nao aparece);
#  4. nenhum valor da sobreposicao referencia recurso (@0x...): no Android 9 o id de um recurso
#     so da sobreposicao cairia no espaco do alvo;
#  5. nada de dimen, style, integer, bool ou string (so cor, forma e imagem: color,
#     drawable e, desde o 16A, mipmap, que e imagem como drawable; o gerenciador de arquivos
#     guarda os icones da lista em mipmap; e, desde o 19B, layout, na regra do item 6);
#  6. (19B) cada layout, em cada configuracao, e o do alvo com so cores trocadas: o `aapt2 dump
#     xmltree` dos dois e igual linha a linha (mesmos elementos, mesma ordem, mesmos atributos,
#     mesmos ids e referencias com o MESMO numero do alvo), tirando o numero da linha do fonte e o
#     texto cru '(Raw: "@...")' que o aapt antigo guarda ao lado de uma referencia (o numero fica
#     comparado); a unica diferenca aceita e um atributo cujo valor e cor literal (#aarrggbb) nos dois. Por
#     isso o item 4 nao vale para layout: as referencias dele sao as do alvo, numero a numero.
# Sai com 1 se qualquer item falhar. Imprime a tabela recurso / tipo / configs / valor alvo -> novo.
import os, re, subprocess, sys, zipfile

AQUI = os.path.dirname(os.path.abspath(__file__))
SDK = os.environ.get('ANDROID_SDK', os.path.expanduser('~/Android/sdk'))
AAPT2 = os.path.join(SDK, 'build-tools', os.environ.get('BUILD_TOOLS', '35.0.0'), 'aapt2')
TIPOS_OK = {'color', 'drawable', 'mipmap', 'layout'}
COR = re.compile(r'#[0-9a-f]{8}')

def aapt2(*args):
    return subprocess.run([AAPT2, *args], check=True, capture_output=True, text=True).stdout

def pacote(apk):
    m = re.search(r"package: name='([^']+)'", aapt2('dump', 'badging', apk))
    return m.group(1) if m else None

def recursos(apk):
    """{tipo/nome: {config: valor}} a partir do aapt2 dump resources."""
    out, cur = {}, None
    for ln in aapt2('dump', 'resources', apk).splitlines():
        m = re.match(r'\s+resource 0x[0-9a-f]+ (\S+/\S+)', ln)
        if m:
            cur = m.group(1)
            out[cur] = {}
            continue
        m = re.match(r'\s+\(([^)]*)\) (.*)', ln)
        if m and cur:
            out[cur][m.group(1)] = m.group(2)
    return out

def alvo_da_sobreposicao(apk):
    x = aapt2('dump', 'xmltree', '--file', 'AndroidManifest.xml', apk)
    m = re.search(r'targetPackage\(0x01010021\)="([^"]+)"', x)
    return m.group(1) if m else None

def arvore(apk, arquivo):
    """Linhas do xmltree sem o numero da linha do fonte e sem o texto cru de uma referencia (o
    aapt antigo do fabricante guarda '(Raw: "@style/x")' ao lado do numero, o aapt2 nao; quem
    vale em tempo de execucao e o numero, que continua comparado)."""
    x = aapt2('dump', 'xmltree', '--file', arquivo, apk)
    out = []
    for ln in x.splitlines():
        ln = re.sub(r' \(line=\d+\)$', '', ln)
        out.append(re.sub(r'(=@0x[0-9a-f]{8}) \(Raw: "@[^"]*"\)$', r'\1', ln))
    return out

def comparar_layout(sob_apk, sob_arq, alv_apk, alv_arq):
    """(erros, cores trocadas): item 6 do cabecalho."""
    a, b = arvore(alv_apk, alv_arq), arvore(sob_apk, sob_arq)
    if len(a) != len(b):
        return [f'{sob_arq}: {len(b)} linhas na arvore, o alvo tem {len(a)}'], 0
    erros, trocas = [], 0
    for la, lb in zip(a, b):
        if la == lb:
            continue
        ma = re.match(r'(\s+A: \S+\(0x[0-9a-f]{8}\))=(\S+)$', la)
        mb = re.match(r'(\s+A: \S+\(0x[0-9a-f]{8}\))=(\S+)$', lb)
        if ma and mb and ma.group(1) == mb.group(1) and COR.fullmatch(ma.group(2)) and COR.fullmatch(mb.group(2)):
            trocas += 1
            continue
        erros.append(f'{sob_arq}: difere do alvo: {la.strip()} -> {lb.strip()}')
    return erros, trocas

def curto(v):
    v = re.sub(r'\(file\) res/\S*/', '', v)
    return v.replace(' type=PNG', '').replace(' type=XML', '')

def main():
    pasta = sys.argv[1]
    alvos = {}
    for r, _, fs in os.walk(pasta):
        for f in fs:
            if f.endswith('.apk'):
                p = os.path.join(r, f)
                try:
                    alvos.setdefault(pacote(p), p)
                except subprocess.CalledProcessError:
                    pass
    falhas = 0
    apks = sorted(os.path.join(AQUI, 'apk', f) for f in os.listdir(os.path.join(AQUI, 'apk')) if f.endswith('.apk'))
    if not apks:
        raise SystemExit('nenhum APK em artifacts/overlay/apk/ (rode o build.sh)')
    for apk in apks:
        nome = os.path.basename(apk)
        tp = alvo_da_sobreposicao(apk)
        print(f'== {nome}: targetPackage={tp}')
        if tp not in alvos:
            print(f'   FALHA: alvo {tp} nao esta na pasta'); falhas += 1; continue
        print(f'   alvo: {os.path.relpath(alvos[tp], pasta)}')
        if 'classes.dex' in zipfile.ZipFile(apk).namelist():
            print('   FALHA: tem classes.dex'); falhas += 1
        sob, alv = recursos(apk), recursos(alvos[tp])
        for rr in sorted(sob):
            tipo = rr.split('/')[0]
            erros = []
            if tipo not in TIPOS_OK:
                erros.append(f'tipo {tipo} nao permitido')
            if rr not in alv:
                outros = [k for k in alv if k.split('/')[1] == rr.split('/')[1]]
                erros.append('nao existe no alvo' + (f' (so como {", ".join(outros)})' if outros else ''))
            else:
                falta = set(alv[rr]) - set(sob[rr])
                if falta:
                    erros.append('configs do alvo sem cobertura: ' + ', '.join(sorted(c or 'padrao' for c in falta)))
            for c, v in sob[rr].items():
                if re.match(r'[@?]', v) or re.search(r'@0x[0-9a-f]{8}|\?0x[0-9a-f]{8}', v):
                    erros.append(f'valor com referencia em ({c})')
            trocas = None
            if tipo == 'layout' and rr in alv:
                # item 6: a arvore do alvo, so com cores trocadas (o item 4 nao vale aqui)
                trocas = 0
                for c, v in sorted(sob[rr].items()):
                    ms = re.match(r'\(file\) (\S+\.xml)', v)
                    ma = re.match(r'\(file\) (\S+\.xml)', alv[rr].get(c, ''))
                    if not ms or not ma:
                        erros.append(f'layout sem arquivo XML em ({c or "padrao"})'); continue
                    e, t = comparar_layout(apk, ms.group(1), alvos[tp], ma.group(1))
                    erros += e
                    trocas += t
            else:
                # referencias dentro dos XML compilados (shape/selector)
                for c, v in sob[rr].items():
                    m = re.match(r'\(file\) (\S+\.xml)', v)
                    if m:
                        x = aapt2('dump', 'xmltree', '--file', m.group(1), apk)
                        if re.search(r'=@0x[0-9a-f]{8}|=\?0x[0-9a-f]{8}', x):
                            erros.append(f'{m.group(1)} referencia recurso')
            confs = ' '.join(c or 'padrao' for c in sorted(sob[rr]))
            antes = curto(next(iter(alv.get(rr, {'': '-'}).values())))
            depois = curto(next(iter(sob[rr].values())))
            if trocas is not None:
                antes, depois = 'arvore do alvo', f'{trocas} cor(es) trocada(s), resto igual'
            print(f'   {"OK   " if not erros else "FALHA"} {rr:42s} [{confs}] {antes} -> {depois}')
            for e in erros:
                print(f'         {e}')
            falhas += bool(erros)
    print(f'{"TUDO OK" if not falhas else f"{falhas} FALHA(S)"}')
    sys.exit(1 if falhas else 0)

main()
