#!/usr/bin/env python3
import hashlib, os, re, subprocess, sys, xml.etree.ElementTree as ET

SDK = os.environ.get('ANDROID_SDK', os.path.expanduser('~/Android/sdk'))
AAPT2 = os.path.join(SDK, 'build-tools', os.environ.get('BUILD_TOOLS', '35.0.0'), 'aapt2')
NS_ANDROID = 'http://schemas.android.com/apk/res/android'
NS_AUTO = 'http://schemas.android.com/apk/res-auto'

def alvo_do_manifesto(pasta):
    with open(os.path.join(pasta, 'AndroidManifest.xml'), encoding='utf-8') as f:
        return re.search(r'targetPackage="([^"]+)"', f.read()).group(1)

def proprios(pasta):
    out = set()
    res = os.path.join(pasta, 'res')
    for d in sorted(os.listdir(res)):
        tipo = d.split('-')[0]
        for f in sorted(os.listdir(os.path.join(res, d))):
            if tipo == 'values':
                for e in ET.parse(os.path.join(res, d, f)).getroot():
                    t = e.get('type') if e.tag == 'item' else e.tag
                    out.add(f'{t}/{e.get("name")}')
            else:
                out.add(f'{tipo}/{f.split(".")[0]}')
    return out

def citados(pasta):
    out = set()
    res = os.path.join(pasta, 'res')
    for d in sorted(os.listdir(res)):
        if not d.startswith('layout'):
            continue
        for f in sorted(os.listdir(os.path.join(res, d))):
            p = os.path.join(res, d, f)
            for e in ET.parse(p).iter():
                for k, v in e.attrib.items():
                    if k.startswith('{') and k[1:].split('}')[0] != NS_ANDROID:
                        out.add('attr/' + k.split('}')[1])
                    m = re.fullmatch(r'@\+?([a-z]+)/([\w.]+)', v)
                    if m:
                        out.add(f'{m.group(1)}/{m.group(2)}')
                    m = re.fullmatch(r'\?(?:attr/)?([\w.]+)', v)
                    if m:
                        out.add('attr/' + m.group(1))
    return out

def extrair(apk, pasta):
    dump = subprocess.run([AAPT2, 'dump', 'resources', apk], check=True, capture_output=True,
                          text=True).stdout.splitlines()
    ids, attrs, cur = {}, {}, None
    for ln in dump:
        m = re.match(r'\s+resource (0x[0-9a-f]+) (\S+/\S+)', ln)
        if m:
            cur = m.group(2)
            ids[cur] = m.group(1)
            continue
        m = re.match(r'\s+\(\) \(attr\) type=(\S+)', ln)
        if m and cur and cur.startswith('attr/'):
            attrs[cur] = [m.group(1)]
            continue
        m = re.match(r'\s+(\w+)\((0x[0-9a-f]+)\)=(0x[0-9a-f]+)$', ln)
        if m and cur in attrs:
            attrs[cur].append(f'{m.group(1)}={m.group(2)}:{m.group(3)}')
    linhas, falta = [], []
    for r in sorted(citados(pasta) | proprios(pasta)):
        if r not in ids:
            falta.append(r)
            continue
        linhas.append(' '.join([ids[r], r] + attrs.get(r, [])))
    if falta:
        raise SystemExit('nao existe no alvo: ' + ', '.join(falta))
    md5 = hashlib.md5(open(apk, 'rb').read()).hexdigest()[:8]
    linhas.sort()
    with open(os.path.join(pasta, 'alvo-ids.txt'), 'w', encoding='ascii') as f:
        f.write(f'# gerado por molde-alvo.py de {os.path.basename(apk)} (md5 {md5}); nao editar a mao\n')
        f.write('\n'.join(linhas) + '\n')
    print(f'{len(linhas)} recursos -> {os.path.join(pasta, "alvo-ids.txt")}')

VALOR = {'dimen': '<dimen name="{n}">0dp</dimen>', 'string': '<string name="{n}">x</string>',
         'color': '<color name="{n}">#0000</color>', 'id': '<item type="id" name="{n}"/>',
         'drawable': '<item type="drawable" name="{n}">#0000</item>',
         'mipmap': '<item type="mipmap" name="{n}">#0000</item>',
         'integer': '<integer name="{n}">0</integer>', 'bool': '<bool name="{n}">false</bool>',
         'style': '<style name="{n}" parent=""/>'}

def gerar(pasta, saida):
    pacote = alvo_do_manifesto(pasta)
    meus = proprios(pasta)
    valores, ids = [], []
    with open(os.path.join(pasta, 'alvo-ids.txt'), encoding='ascii') as f:
        for ln in f:
            if ln.startswith('#') or not ln.strip():
                continue
            campos = ln.split()
            rid, r, resto = campos[0], campos[1], campos[2:]
            tipo, nome = r.split('/')
            ids.append(f'{pacote}:{r} = {rid}')
            if r in meus:
                continue
            if tipo == 'attr':
                fmt = '|'.join(t for t in resto[0].split('|') if t not in ('enum', 'flags', 'any'))
                filho = 'flag' if 'flags' in resto[0] else 'enum'
                simb = []
                for s in resto[1:]:
                    sn, sv = s.split('=')
                    sid, val = sv.split(':')
                    ids.append(f'{pacote}:id/{sn} = {sid}')
                    simb.append(f'<{filho} name="{sn}" value="{val}"/>')
                fa = f' format="{fmt}"' if fmt else ''
                valores.append(f'<attr name="{nome}"{fa}>' + ''.join(simb) + '</attr>')
            elif tipo in VALOR:
                valores.append(VALOR[tipo].format(n=nome))
            elif tipo == 'layout':
                os.makedirs(os.path.join(saida, 'res', 'layout'), exist_ok=True)
                with open(os.path.join(saida, 'res', 'layout', nome + '.xml'), 'w', encoding='utf-8') as f:
                    f.write(f'<View xmlns:android="{NS_ANDROID}"/>\n')
            else:
                raise SystemExit(f'tipo sem molde: {r}')
    os.makedirs(os.path.join(saida, 'res', 'values'), exist_ok=True)
    with open(os.path.join(saida, 'res', 'values', 'molde.xml'), 'w', encoding='utf-8') as f:
        f.write('<resources>\n' + '\n'.join(valores) + '\n</resources>\n')
    with open(os.path.join(saida, 'AndroidManifest.xml'), 'w', encoding='utf-8') as f:
        f.write(f'<manifest xmlns:android="{NS_ANDROID}" package="{pacote}"/>\n')
    with open(os.path.join(saida, 'ids.txt'), 'w', encoding='ascii') as f:
        f.write('\n'.join(sorted(set(ids))) + '\n')
    print(pacote)

if sys.argv[1] == '--gerar':
    gerar(sys.argv[2], sys.argv[3])
else:
    extrair(sys.argv[1], sys.argv[2])
