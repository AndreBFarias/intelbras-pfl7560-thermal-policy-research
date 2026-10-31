#!/usr/bin/env python3
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
    x = aapt2('dump', 'xmltree', '--file', arquivo, apk)
    out = []
    for ln in x.splitlines():
        ln = re.sub(r' \(line=\d+\)$', '', ln)
        out.append(re.sub(r'(=@0x[0-9a-f]{8}) \(Raw: "@[^"]*"\)$', r'\1', ln))
    return out

def comparar_layout(sob_apk, sob_arq, alv_apk, alv_arq):
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
