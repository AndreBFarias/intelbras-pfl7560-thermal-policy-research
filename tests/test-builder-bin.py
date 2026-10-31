#!/usr/bin/env python3
import hashlib
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BB = os.path.join(ROOT, 'artifacts', 'bin-build')
ART = os.path.join(ROOT, 'artifacts')
sys.path.insert(0, BB)
import build_fix_bin as B   # noqa: E402  (importa o builder real: so funcoes)
import sparse               # noqa: E402

TABLE_OFF, TABLE_ENTRY, N_RECORDS, VENDOR_REC = 0x40, 32, 19, 14

FALHAS = 0
TESTES = 0

def afirma(cond, msg):
    global FALHAS, TESTES
    TESTES += 1
    if not cond:
        FALHAS += 1
        print(f"  FALHA {CASO}: {msg}")

def md5(path):
    h = hashlib.md5()
    with open(path, 'rb') as f:
        for b in iter(lambda: f.read(1 << 24), b''):
            h.update(b)
    return h.hexdigest()

def ler(path):
    return open(path, 'rb').read()

def ext4_com_os_3_arquivos(d, ini, bp, rc):
    raw = os.path.join(d, 'stock.raw')
    with open(raw, 'wb') as f:
        f.truncate(4 * 1024 * 1024)
    subprocess.run(['mke2fs', '-q', '-t', 'ext4', '-b', '4096', '-O', '^has_journal,^metadata_csum', '-F', raw],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    cmds = 'mkdir /etc\nmkdir /etc/init\nmkdir /etc/init/hw\n'
    alvos = (('/etc/ZYCustom.ini', ini), ('/build.prop', bp), ('/etc/init/hw/init.bigfish.rc', rc))
    for path, src in alvos:
        cmds += f'write {src} {path}\n' + B.meta_cmds(path, B.META_FALLBACK[path])
    open(os.path.join(d, 'cmds'), 'w').write(cmds)
    B.dfs(raw, os.path.join(d, 'cmds'))
    return raw

def monta_load(d, payload, pfx, nome='stock.bin', crc_errado=(5,)):
    outros = {i: bytes([0x30 + i]) * (16 + 4 * i) for i in range(N_RECORDS) if i != VENDOR_REC}
    blob_len = pfx - 0x2bc - sum(8 + len(outros[i]) for i in range(VENDOR_REC))
    assert blob_len >= 0, "pfx pequeno demais para os 14 records antes do vendor"
    blob = b'\x3e\x18\x00\xea' + b'\xee' * blob_len
    blob = blob[:blob_len]
    size = os.path.getsize(payload)
    dados = {i: outros[i] for i in outros}
    corpo, pos, tabela = bytearray(), 0x2bc + blob_len, []
    for i in range(N_RECORDS):
        x = ler(payload) if i == VENDOR_REC else dados[i]
        crc = B.crc_header(x) ^ (0xffffffff if i in crc_errado else 0)
        tabela.append((len(x), pos))
        corpo += struct.pack('>II', len(x), crc) + x
        pos += 8 + len(x)
    hdr = bytearray(0x2b4)
    hdr[0:4] = b'LOAD'
    struct.pack_into('>IQ', hdr, 8, 0x2b4, pos)
    for i, (ln, off) in enumerate(tabela):
        ini = 0x10000000 * i
        fim = ini + (76800 * 4096 if i == VENDOR_REC else 0x100000)
        struct.pack_into('>IIQQII', hdr, 0x54 + 32 * i, ln, off, ini, fim, 2, 0)
    struct.pack_into('>I', hdr, 4, B.crc_header(bytes(hdr[:4] + b'\x00' * 4 + hdr[8:])))
    out = os.path.join(d, nome)
    with open(out, 'wb') as f:
        f.write(bytes(hdr) + struct.pack('>II', blob_len, B.crc_header(blob)) + blob + bytes(corpo))
    assert tabela[VENDOR_REC][1] == pfx
    return out, size

def monta_stock(d, raw, pfx, folga=0, nome='stock.bin'):
    payload = os.path.join(d, 'vendor.sparse')
    sparse.pack(raw, payload)
    with open(payload, 'ab') as f:
        f.write(b'\x00' * folga)
    return monta_load(d, payload, pfx, nome)

def tabela(path):
    with open(path, 'rb') as f:
        h = f.read(0x2b4)
    return [struct.unpack('>II', h[0x54 + 32 * i:0x54 + 32 * i + 8]) for i in range(N_RECORDS)], \
        struct.unpack('>Q', h[0x0c:0x14])[0]

def layout(sp):
    return [c[:4] for c in sparse.parse(sp)[2]]

def meta_de(raw, path):
    st = subprocess.run(['debugfs', '-R', f'stat {path}', raw], capture_output=True, text=True).stdout
    m = re.search(r'Type:\s+(\S+)\s+Mode:\s+(\d+)', st)
    u = re.search(r'User:\s+(\d+)\s+Group:\s+(\d+)', st)
    r = re.search(r'security\.selinux \(\d+\) = "([^"]*)"', st)
    if not (m and u and r):
        return None
    return (m.group(1), m.group(2).zfill(4)[-4:], u.group(1), u.group(2), r.group(1))

def ler_manifesto(path):
    out = []
    for linha in open(path, encoding='utf-8'):
        c = linha.split('#', 1)[0].split()
        if len(c) != 6:
            continue
        origem = None if c[0] == '-' else (c[0] if os.path.isabs(c[0]) else os.path.join(ROOT, c[0]))
        tipo = 'directory' if origem is None else 'regular'
        out.append((origem, c[1][len('/vendor'):], (tipo, c[2], c[3], c[4], c[5] + '\\000')))
    return out

def confere_manifesto(raw, manifesto):
    for origem, img, esperado in ler_manifesto(manifesto):
        afirma(meta_de(raw, img) == esperado, f"{img}: metadados {meta_de(raw, img)} != {esperado}")
        if origem:
            afirma(cat(raw, img) == ler(origem), f"{img}: conteudo difere da origem")

def iguais_fora(a, b, ini, fim):
    with open(a, 'rb') as fa, open(b, 'rb') as fb:
        pos = 0
        while True:
            x, y = fa.read(1 << 24), fb.read(1 << 24)
            if not x and not y:
                return True
            n = len(x)
            if len(y) != n:
                return False
            lo, hi = max(ini - pos, 0), min(fim - pos, n)
            if lo < hi:
                if x[:lo] != y[:lo] or x[hi:] != y[hi:]:
                    return False
            elif x != y:
                return False
            pos += n

def roda_builder(stock, ini, out, *extra):
    r = subprocess.run([sys.executable, os.path.join(BB, 'build_fix_bin.py'), stock, ini, out, *extra],
                       capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr

def cat(raw, path):
    return subprocess.run(['debugfs', '-R', f'cat {path}', raw], capture_output=True).stdout

def verificar(out, stock, *extra):
    r = subprocess.run([sys.executable, os.path.join(BB, 'build_fix_bin.py'), '--verificar', out, stock, *extra],
                       capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr

def payload14(path, d, nome):
    recs, _ = tabela(path)
    size, pfx = recs[VENDOR_REC]
    pl = os.path.join(d, nome)
    with open(path, 'rb') as f:
        f.seek(pfx + 8)
        open(pl, 'wb').write(f.read(size))
    return pl

def confere_saida(stock, out, pfx, size, ini):
    s, o = ler(stock), ler(out)
    afirma(len(s) == len(o), "tamanho do .bin mudou")
    afirma(s[:0x2b4] == o[:0x2b4], "cabecalho/tabela LOAD (checksum1 inclusive) mudou")
    afirma(s[:pfx] == o[:pfx], "bytes antes do record 14 mudaram")
    afirma(s[pfx + 8 + size:] == o[pfx + 8 + size:], "bytes depois do record 14 mudaram")
    afirma(s[pfx:pfx + 4] == o[pfx:pfx + 4], "o tamanho do prefixo mudou")
    d = os.path.dirname(out)
    pl, pl_s = payload14(out, d, 'saida.vendor'), payload14(stock, d, 'stock.vendor')
    afirma(struct.unpack('>I', o[pfx + 4:pfx + 8])[0] == B.crc32_mpeg2(pl), "CRC do vendor gravado nao confere com o payload")
    afirma(ler(pl) != ler(pl_s), "o vendor nao mudou")
    afirma(layout(pl) == layout(pl_s), "o layout de chunks do sparse mudou (devia ser o do stock)")
    afirma({c[0] for c in sparse.parse(pl)[2]} <= {'raw', 'dontcare'}, "sparse com chunk fora de RAW/DONTCARE")
    hdr = bytearray(o[:0x2b4])
    c1 = struct.unpack('>I', hdr[4:8])[0]
    hdr[4:8] = b'\x00\x00\x00\x00'
    afirma(B.crc_header(bytes(hdr)) == c1, "checksum1 nao confere")
    raw = pl + '.raw'
    sparse.expand(pl, raw)
    afirma(cat(raw, '/etc/ZYCustom.ini') == ler(ini), "ZYCustom.ini da saida difere do ini dado")
    afirma(b'wifi_disconnect_on_boot=0' in cat(raw, '/build.prop')
           and b'wifi_disconnect_on_boot=1' not in cat(raw, '/build.prop'), "wi-fi nao foi trocado")
    afirma(b'disabled' in cat(raw, '/etc/init/hw/init.bigfish.rc').split(b'service xiriservice')[1][:60],
           "xiriservice nao foi desabilitado")
    afirma(subprocess.run(['e2fsck', '-fn', raw], capture_output=True).returncode == 0,
           "e2fsck -fn do vendor de saida nao esta limpo")
    for p, m in B.META_FALLBACK.items():
        afirma(meta_de(raw, p) == ('regular', m['mode'], m['uid'], m['gid'], m['selinux'] + '\\000'),
               f"{p}: metadados do stock mudaram")
    rc, log = verificar(out, stock)
    afirma(rc == 0 and 'APROVADO' in log, f"--verificar reprovou a saida: {log.strip().splitlines()[-3:]}")

def caso_layout(rotulo, stock_ini, ini_dado, pfx):
    global CASO
    CASO = rotulo
    d = tempfile.mkdtemp(prefix='testbin_')
    try:
        raw = ext4_com_os_3_arquivos(d, stock_ini, os.path.join(ART, 'build.prop.STOCK'),
                                     os.path.join(ART, 'init.bigfish.rc.STOCK'))
        stock, size = monta_stock(d, raw, pfx)
        afirma(pfx != 0x4b0b1d54, "o offset do teste nao devia ser o antigo fixo")
        out = os.path.join(d, 'saida.bin')
        rc, log = roda_builder(stock, ini_dado, out)
        afirma(rc == 0, f"builder falhou (rc={rc}): {log.strip().splitlines()[-1:] }")
        afirma(f'em 0x{pfx:x}' in log, "o log nao mostra o offset lido da tabela")
        afirma(not os.path.exists(out + '.tmp'), "sobrou o .tmp da saida")
        if rc == 0:
            confere_saida(stock, out, pfx, size, ini_dado)
            rc2, _ = roda_builder(stock, ini_dado, out + '.2')
            afirma(rc2 == 0 and md5(out) == md5(out + '.2'), "saida nao e deterministica")
    finally:
        shutil.rmtree(d, ignore_errors=True)

def caso_recusa(rotulo, mexe, stock_ini, ini_dado, pfx, trecho, folga=0):
    global CASO
    CASO = rotulo
    d = tempfile.mkdtemp(prefix='testbin_')
    try:
        raw = ext4_com_os_3_arquivos(d, stock_ini, os.path.join(ART, 'build.prop.STOCK'),
                                     os.path.join(ART, 'init.bigfish.rc.STOCK'))
        stock, size = monta_stock(d, raw, pfx, folga=folga)
        mexe(stock, pfx, size)
        out = os.path.join(d, 'saida.bin')
        rc, log = roda_builder(stock, ini_dado, out)
        afirma(rc != 0 and trecho in log, f"nao recusou com '{trecho}' (rc={rc}): {log.strip().splitlines()[-1:]}")
        afirma(not os.path.exists(out) and not os.path.exists(out + '.tmp'), "gerou o .bin apesar da recusa")
    finally:
        shutil.rmtree(d, ignore_errors=True)

def poe(stock, pos, dados):
    with open(stock, 'r+b') as f:
        f.seek(pos)
        f.write(dados)

def sparse_com_fill(sp, out):
    blk, total, chunks = sparse.parse(sp)
    raw = ler(sp)
    corpo, n = b'', 0
    feito = False
    for ct, _ob, cnt, off, _fill in chunks:
        if ct == 'raw':
            corpo += struct.pack('<HHII', sparse.RAW, 0, cnt, 12 + cnt * blk) + raw[off:off + cnt * blk]
            n += 1
        elif not feito and cnt >= 3:
            corpo += struct.pack('<HHII', sparse.DONTCARE, 0, 1, 12)
            corpo += struct.pack('<HHII', sparse.FILL, 0, 1, 16) + struct.pack('<I', 0xdeadbeef)
            corpo += struct.pack('<HHII', sparse.DONTCARE, 0, cnt - 2, 12)
            n += 3
            feito = True
        else:
            corpo += struct.pack('<HHII', sparse.DONTCARE, 0, cnt, 12)
            n += 1
    open(out, 'wb').write(struct.pack('<IHHHHIIII', sparse.SPARSE_MAGIC, 1, 0, 28, 12, blk, total, n, 0) + corpo)
    return feito

def caso_gate(rotulo, estraga, trecho):
    global CASO
    CASO = rotulo
    d = tempfile.mkdtemp(prefix='testbin_')
    try:
        raw = ext4_com_os_3_arquivos(d, ANTIGO_INI, os.path.join(ART, 'build.prop.STOCK'),
                                     os.path.join(ART, 'init.bigfish.rc.STOCK'))
        stock, _size = monta_stock(d, raw, 0x1000)
        out = os.path.join(d, 'saida.bin')
        rc, log = roda_builder(stock, FIX_ANTIGO, out)
        afirma(rc == 0, f"builder falhou (rc={rc}): {log.strip().splitlines()[-1:]}")
        if rc != 0:
            return
        ruim = estraga(d, stock, out)
        rc, log = verificar(ruim, stock)
        afirma(rc != 0 and trecho in log, f"--verificar nao pegou '{trecho}' (rc={rc}): {log.strip().splitlines()[-3:]}")
    finally:
        shutil.rmtree(d, ignore_errors=True)

def com_payload(d, out, mexe):
    pl = payload14(out, d, 'bom.vendor')
    novo = mexe(pl)
    return monta_load(d, novo, tabela(out)[0][VENDOR_REC][1], 'ruim.bin')[0]

def zeros_soltos(pl):
    open(pl, 'ab').write(b'\x00' * 4096)
    return pl

def com_fill(pl):
    afirma(sparse_com_fill(pl, pl + '.fill'), "o sparse do teste nao tinha DONTCARE de 3+ blocos")
    return pl + '.fill'

def outro_arquivo(pl):
    raw = pl + '.raw'
    sparse.expand(pl, raw)
    open(pl + '.x', 'wb').write(b'nao devia estar aqui\n')
    open(pl + '.cmds', 'w').write(f'write {pl}.x /etc/intruso.txt\nsif /etc mode 040700\n')
    B.dfs(raw, pl + '.cmds')
    sparse.pack(raw, pl + '.novo')
    return pl + '.novo'

def copia_mexida(out, pos, dados):
    ruim = out + '.ruim'
    shutil.copyfile(out, ruim)
    poe(ruim, pos, dados)
    return ruim

def caso_real(rotulo, stock, ini, md5_saida=None):
    global CASO
    CASO = rotulo
    d = tempfile.mkdtemp(prefix='testbin_')
    try:
        out = os.path.join(d, 'saida.bin')
        rc, log = roda_builder(stock, ini, out)
        afirma(rc == 0 and 'VALIDO' in log, f"builder falhou: {log.strip().splitlines()[-2:]}")
        if rc != 0:
            return
        recs, _ = tabela(stock)
        size, pfx = recs[VENDOR_REC]
        afirma(os.path.getsize(out) == os.path.getsize(stock), "tamanho do .bin mudou")
        afirma(iguais_fora(stock, out, pfx + 4, pfx + 8 + size), "mudou algo fora do record 14 (CRC + payload)")
        pl, pl_s = payload14(out, d, 'v.bin'), payload14(stock, d, 's.bin')
        afirma(layout(pl) == layout(pl_s), "layout de chunks diferente do stock")
        with open(out, 'rb') as o:
            o.seek(pfx + 4)
            crc_gravado = struct.unpack('>I', o.read(4))[0]
        afirma(crc_gravado == B.crc32_mpeg2(pl), "CRC do vendor nao confere")
        os.remove(pl)
        os.remove(pl_s)
        rc, vlog = verificar(out, stock)
        afirma(rc == 0 and 'APROVADO' in vlog, f"--verificar reprovou: {vlog.strip().splitlines()[-3:]}")
        print(f"    md5 {md5(out)}  CRC do vendor 0x{crc_gravado:08x}")
        if md5_saida:
            afirma(md5(out) == md5_saida, f"md5 da saida {md5(out)} != {md5_saida}")
    finally:
        shutil.rmtree(d, ignore_errors=True)

MD5_S4A_ANTIGO = 'a6e5da14cb3f53b42a457eb92bd91814'
MD5_S4A_NOVO = 'e3e3e87ce08a625c83c3824eafd26d9b'
CASO = ''
ANTIGO_INI = os.path.join(ART, 'ZYCustom.ini.ORIGINAL')
NOVO_INI = os.path.join(ART, 'ZYCustom.ini.NOTYPEC.STOCK')
FIX_ANTIGO = os.path.join(ART, 'ZYCustom_390.ini')
FIX_NOVO = os.path.join(ART, 'ZYCustom_390.NOTYPEC.ini')

print("== CRC-32/MPEG-2 rapido (zlib) = o bit a bit ==")
CASO = "crc"
for n in (0, 1, 7, 4096, 100003):
    t = tempfile.NamedTemporaryFile(delete=False)
    t.write(hashlib.sha256(str(n).encode()).digest() * (n // 32) + b'\xa5' * (n % 32))
    t.close()
    afirma(B.crc32_mpeg2(t.name) == B.crc_header(ler(t.name)), f"CRC de {n} bytes difere do bit a bit")
    os.remove(t.name)

print("== builder: offset e tamanho do vendor lidos da tabela (containers sinteticos) ==")
caso_layout("modelo com USB-C, vendor em 0x1000", ANTIGO_INI, FIX_ANTIGO, 0x1000)
caso_layout("modelo com USB-C, vendor em 0x1000+0xac00", ANTIGO_INI, FIX_ANTIGO, 0x1000 + 0xac00)
caso_layout("modelo sem USB-C, vendor em 0x1000+0xac00", NOVO_INI, FIX_NOVO, 0x1000 + 0xac00)
caso_layout("modelo sem USB-C, vendor em 0x2000", NOVO_INI, FIX_NOVO, 0x2000)

print("== builder: recusas (nada e gravado) ==")
caso_recusa("magic LOAD ausente", lambda s, p, z: poe(s, 0, b'XXXX'), ANTIGO_INI, FIX_ANTIGO, 0x1000,
            "nao e um container LOAD")
caso_recusa("tamanho do prefixo difere da tabela",
            lambda s, p, z: poe(s, p, struct.pack('>I', z - 4096)), ANTIGO_INI, FIX_ANTIGO, 0x1000,
            "difere do da tabela")
caso_recusa("record 14 fora do arquivo",
            lambda s, p, z: poe(s, 0x40 + 32 * VENDOR_REC + 0x18, struct.pack('>I', 0x7fffff00)),
            ANTIGO_INI, FIX_ANTIGO, 0x1000, "fora do arquivo")
caso_recusa("ini do modelo sem USB-C no stock com USB-C", lambda s, p, z: None, ANTIGO_INI, FIX_NOVO,
            0x1000, "CONFIG_MODEL")
caso_recusa("ini do modelo com USB-C no stock sem USB-C", lambda s, p, z: None, NOVO_INI, FIX_ANTIGO,
            0x1000, "CONFIG_MODEL")
INI_GRANDE = os.path.join(tempfile.mkdtemp(prefix='testbin_ini_'), 'ZYCustom grande.ini')
open(INI_GRANDE, 'wb').write(ler(FIX_ANTIGO) + b';' * 4096 + b'\n')
caso_recusa("ini que pede mais blocos que o do stock (caminho com espaco)", lambda s, p, z: None, ANTIGO_INI,
            INI_GRANDE, 0x1000, "nao cabe nos mesmos blocos")
shutil.rmtree(os.path.dirname(INI_GRANDE), ignore_errors=True)
caso_recusa("stock com zeros soltos no slot: o gate recusa a saida", lambda s, p, z: None, ANTIGO_INI,
            FIX_ANTIGO, 0x1000, "soltos depois do ultimo chunk", folga=65536)

def stock_com_fill(s, p, z):
    d = os.path.dirname(s)
    pl = payload14(s, d, 'stock-fill.vendor')
    sparse_com_fill(pl, pl + '.fill')
    novo, _ = monta_load(d, pl + '.fill', p, 'stock-fill.bin')
    os.replace(novo, s)

caso_recusa("stock com chunk FILL: o gate recusa a saida", stock_com_fill, ANTIGO_INI, FIX_ANTIGO, 0x1000,
            "chunk 0xcac2")

print("== --verificar: o gate pega cada estrago ==")
caso_gate("sobra de zeros depois do ultimo chunk", lambda d, s, o: com_payload(d, o, zeros_soltos),
          "soltos depois do ultimo chunk")
caso_gate("chunk FILL no sparse do 14", lambda d, s, o: com_payload(d, o, com_fill), "chunk 0xcac2")
caso_gate("arquivo novo e metadado mudado fora dos esperados", lambda d, s, o: com_payload(d, o, outro_arquivo),
          "/etc/intruso.txt: novo e fora do manifesto")
caso_gate("metadado de pasta mudado", lambda d, s, o: com_payload(d, o, outro_arquivo), "/etc: metadados mudaram")
caso_gate("CRC do record 14 errado",
          lambda d, s, o: copia_mexida(o, tabela(o)[0][VENDOR_REC][1] + 4, b'\x00\x00\x00\x00'), "CRC gravado")
caso_gate("byte mudado no record 16",
          lambda d, s, o: copia_mexida(o, tabela(o)[0][16][1] + 9, b'\x00'), "record 16: difere do stock")
caso_gate("checksum1 errado", lambda d, s, o: copia_mexida(o, 4, b'\x00\x00\x00\x00'), "checksum1 @0x04")
caso_gate("file_len errado", lambda d, s, o: copia_mexida(o, 0x13, b'\x01'), "file_len @0x0c")
caso_gate("blob do loader mudado", lambda d, s, o: copia_mexida(o, 0x2c0, b'\x00'), "blob do loader")

ROTULO_CFG = 'u:object_r:vendor_configs_file:s0'
ROTULO_APP = 'u:object_r:vendor_app_file:s0'
CONTEUDO = os.path.join(BB, 'conteudo.txt')

def stock_com_app(d, pfx):
    raw = ext4_com_os_3_arquivos(d, ANTIGO_INI, os.path.join(ART, 'build.prop.STOCK'),
                                 os.path.join(ART, 'init.bigfish.rc.STOCK'))
    ex = os.path.join(d, 'existente.txt')
    open(ex, 'w').write('versao de fabrica\n')
    cmds = (f'mkdir /app\nsif /app mode 040755\nsif /app gid 2000\nea_set /app security.selinux {ROTULO_APP}\\000\n'
            f'write {ex} /etc/existente.txt\n' + B.meta_cmds('/etc/existente.txt', {
                'mode': '0644', 'uid': '0', 'gid': '0', 'selinux': ROTULO_CFG}))
    open(os.path.join(d, 'cmds2'), 'w').write(cmds)
    B.dfs(raw, os.path.join(d, 'cmds2'))
    return monta_stock(d, raw, pfx)

def apk_falso(d, tamanho):
    p = os.path.join(d, 'app falso.apk')
    open(p, 'wb').write(hashlib.sha256(b'pfl').digest() * (tamanho // 32))
    return p

def confere_realocado(stock, out):
    rs, fs = tabela(stock)
    ro, fo = tabela(out)
    delta = ro[VENDOR_REC][0] - rs[VENDOR_REC][0]
    afirma(fo == os.path.getsize(out) and fo == fs + delta, f"file_len {fo} incoerente (stock {fs}, delta {delta})")
    afirma(all(ro[i][1] == rs[i][1] for i in range(VENDOR_REC + 1)), "offsets ate o 14 mudaram")
    afirma(all(ro[i][1] == rs[i][1] + delta for i in range(VENDOR_REC + 1, N_RECORDS)),
           "offsets dos records 15 a 18 nao andaram o delta")
    s, o = ler(stock), ler(out)
    for i in range(N_RECORDS):
        if i != VENDOR_REC:
            afirma(s[rs[i][1]:rs[i][1] + 8 + rs[i][0]] == o[ro[i][1]:ro[i][1] + 8 + ro[i][0]],
                   f"record {i} difere do stock")
    afirma(s[0x2b4:rs[0][1]] == o[0x2b4:ro[0][1]], "blob do loader mudou")
    hdr = bytearray(o[:0x2b4])
    c1 = struct.unpack('>I', hdr[4:8])[0]
    hdr[4:8] = b'\x00\x00\x00\x00'
    afirma(B.crc_header(bytes(hdr)) == c1, "checksum1 nao confere")
    hs, ho = bytearray(s[:0x2b4]), bytearray(o[:0x2b4])
    for h in (hs, ho):
        h[4:8] = b'\x00' * 4
        h[0x0c:0x14] = b'\x00' * 8
        h[0x54 + 32 * VENDOR_REC:0x54 + 32 * VENDOR_REC + 4] = b'\x00' * 4
        for i in range(VENDOR_REC + 1, N_RECORDS):
            h[0x58 + 32 * i:0x58 + 32 * i + 4] = b'\x00' * 4
    afirma(hs == ho, "cabecalho mudou fora de checksum1, file_len, tamanho do 14 e offsets dos seguintes")
    d = os.path.dirname(out)
    pl = payload14(out, d, 'realocado.vendor')
    afirma(struct.unpack('>I', o[ro[VENDOR_REC][1] + 4:ro[VENDOR_REC][1] + 8])[0] == B.crc32_mpeg2(pl),
           "CRC do vendor nao confere")
    _blk, _tot, ch = sparse.parse(pl)
    afirma({c[0] for c in ch} <= {'raw', 'dontcare'}, "sparse com chunk fora de RAW/DONTCARE")
    consumido = 28 + sum(12 + (c[2] * 4096 if c[0] == 'raw' else 0) for c in ch)
    afirma(consumido == os.path.getsize(pl), f"o sparse ocupa {consumido} B e o img_length e {os.path.getsize(pl)}")
    return pl

def caso_conteudo(rotulo):
    global CASO
    CASO = rotulo
    d = tempfile.mkdtemp(prefix='testbin_')
    try:
        stock, _size = stock_com_app(d, 0x1000)
        novo = os.path.join(d, 'existente.novo')
        open(novo, 'w').write('versao nova, mais comprida que a de fabrica\n')
        man = os.path.join(d, 'conteudo.txt')
        open(man, 'w').write(
            '# comentario\n\n'
            f'pendrive-autorun/pfl7560-suite.rc /vendor/etc/init/pfl7560-suite.rc 0644 0 0 {ROTULO_CFG}\n'
            f'{apk_falso(d, 96000).replace(" ", "?")} /vendor/app/PFL7560/PFL7560.apk 0644 0 0 {ROTULO_APP}\n'
            f'- /vendor/app/PFL7560 0755 0 0 {ROTULO_APP}   # a pasta pode vir depois do arquivo\n'
            f'{novo} /vendor/etc/existente.txt 0644 0 0 {ROTULO_CFG}\n'
            f'- /vendor/etc/pfl7560 0755 0 2000 {ROTULO_CFG}\n'
            f'- /vendor/etc/pfl7560/sub 0700 0 0 {ROTULO_CFG}\n')
        out = os.path.join(d, 'saida.bin')
        rc, log = roda_builder(stock, FIX_ANTIGO, out, '--realocar', '--conteudo', man)
        afirma(rc != 0 and 'nao e um arquivo' in log, "origem com '?' devia ser recusada (nome literal)")
        link = os.path.join(d, 'app_falso.apk')
        os.symlink(apk_falso(d, 96000), link)
        texto = open(man).read().replace(apk_falso(d, 96000).replace(' ', '?'), link)
        open(man, 'w').write(texto)
        rc, log = roda_builder(stock, FIX_ANTIGO, out, '--conteudo', man)
        afirma(rc != 0 and '--realocar' in log and not os.path.exists(out),
               f"manifesto sem --realocar devia ser recusado (rc={rc}): {log.strip().splitlines()[-1:]}")
        rc, log = roda_builder(stock, FIX_ANTIGO, out, '--realocar', '--conteudo', man)
        afirma(rc == 0 and 'VALIDO' in log and '6 entradas do manifesto' in log,
               f"builder com manifesto falhou (rc={rc}): {log.strip().splitlines()[-2:]}")
        if rc != 0:
            return
        afirma(os.path.getsize(out) > os.path.getsize(stock), "o app de 96 KB devia crescer o record 14")
        pl = confere_realocado(stock, out)
        raw = pl + '.raw'
        sparse.expand(pl, raw)
        confere_manifesto(raw, man)
        afirma(meta_de(raw, '/app') == ('directory', '0755', '0', '2000', ROTULO_APP + '\\000'),
               "a pasta /app do stock mudou de metadados")
        for p, m in B.META_FALLBACK.items():
            afirma(meta_de(raw, p) == ('regular', m['mode'], m['uid'], m['gid'], m['selinux'] + '\\000'),
                   f"{p}: metadados do stock mudaram")
        afirma(cat(raw, '/etc/ZYCustom.ini') == ler(FIX_ANTIGO), "ZYCustom.ini da saida difere do ini dado")
        afirma(subprocess.run(['e2fsck', '-fn', raw], capture_output=True).returncode == 0,
               "e2fsck -fn da imagem de saida nao esta limpo")
        rc, vlog = verificar(out, stock, '--conteudo', man)
        afirma(rc == 0 and 'APROVADO' in vlog, f"--verificar com o manifesto reprovou: {vlog.strip().splitlines()[-3:]}")
        rc, vlog = verificar(out, stock)
        afirma(rc != 0 and 'novo e fora do manifesto' in vlog, "--verificar sem o manifesto devia acusar os arquivos novos")
        rc2, _ = roda_builder(stock, FIX_ANTIGO, out + '.2', '--realocar', '--conteudo', man)
        afirma(rc2 == 0 and md5(out) == md5(out + '.2'), "saida com manifesto nao e deterministica")
        rc3, log3 = roda_builder(stock, FIX_ANTIGO, out + '.3', '--realocar')
        afirma(rc3 == 0 and 'VALIDO' in log3, f"--realocar sem manifesto falhou: {log3.strip().splitlines()[-1:]}")
        if rc3 == 0:
            confere_realocado(stock, out + '.3')
    finally:
        shutil.rmtree(d, ignore_errors=True)

def caso_recusa_conteudo(rotulo, linhas, trecho, tamanho_apk=20000):
    global CASO
    CASO = rotulo
    d = tempfile.mkdtemp(prefix='testbin_')
    try:
        stock, _size = stock_com_app(d, 0x1000)
        apk = os.path.join(d, 'apk.bin')
        os.rename(apk_falso(d, tamanho_apk), apk)
        man = os.path.join(d, 'conteudo.txt')
        open(man, 'w').write(linhas.format(apk=apk, cfg=ROTULO_CFG, app=ROTULO_APP))
        out = os.path.join(d, 'saida.bin')
        rc, log = roda_builder(stock, FIX_ANTIGO, out, '--realocar', '--conteudo', man)
        afirma(rc != 0 and trecho in log, f"nao recusou com '{trecho}' (rc={rc}): {log.strip().splitlines()[-1:]}")
        afirma(not os.path.exists(out) and not os.path.exists(out + '.tmp'), "gerou o .bin apesar da recusa")
    finally:
        shutil.rmtree(d, ignore_errors=True)

def kit_lista():
    sh = open(os.path.join(ROOT, 'pendrive-autorun', 'newlink_update.sh'), encoding='ascii').read()
    lista = dict((n, m) for m, n in re.findall(r'(?m)^([0-9a-f]{32})  (\S+)$', sh))
    pastas = {}
    for var, base in (('KIT_APPS', '/vendor/app'), ('KIT_OVERLAYS', '/vendor/overlay')):
        bloco = re.search(rf'(?ms)^{var}="([^"]*)"', sh).group(1)
        for par in bloco.split():
            n, pasta = par.split(':')
            pastas[n] = f'{base}/{pasta}/{pasta}.apk'
    return lista, pastas

def caso_manifesto_e_kit(rotulo):
    global CASO
    CASO = rotulo
    lista, pastas = kit_lista()
    vistos = set()
    for origem, img, esperado in ler_manifesto(CONTEUDO):
        if not origem:
            continue
        rel = os.path.relpath(origem, os.path.join(ROOT, 'pendrive-autorun'))
        afirma(not rel.startswith('..'), f"{origem}: origem fora do pendrive-autorun")
        afirma(lista.get(rel) == md5(origem), f"{rel}: md5 {md5(origem)} != KIT_LISTA {lista.get(rel)}")
        if rel in pastas:
            vistos.add(rel)
            afirma('/vendor' + img == pastas[rel], f"{rel}: vai para /vendor{img}, o kit instala em {pastas[rel]}")
            rotulo_kit = 'vendor_overlay_file' if '/overlay/' in pastas[rel] else 'vendor_app_file'
            afirma(esperado == ('regular', '0644', '0', '0', f'u:object_r:{rotulo_kit}:s0\\000'),
                   f"{rel}: metadados {esperado} diferentes dos do kit")
    afirma(vistos == set(pastas), f"conteudo.txt sem {sorted(set(pastas) - vistos)}")

print("== builder: manifesto --conteudo com --realocar (containers sinteticos) ==")
caso_conteudo("manifesto com .rc, pasta e app novos, troca de conteudo e pastas aninhadas")
APK_LINHAS = '- /vendor/app/PFL7560 0755 0 0 {app}\n{apk} /vendor/app/PFL7560/PFL7560.apk 0644 0 0 {app}\n'
caso_recusa_conteudo("arquivo maior que o ext4 livre", APK_LINHAS, "falta espaco no vendor",
                     tamanho_apk=6 * 1024 * 1024)
caso_recusa_conteudo(".rc 0664", 'pendrive-autorun/pfl7560-suite.rc /vendor/etc/init/x.rc 0664 0 0 {cfg}\n',
                     "escrita para grupo ou outros")
caso_recusa_conteudo("pasta-mae nao declarada", '{apk} /vendor/app/PFL7560/PFL7560.apk 0644 0 0 {app}\n',
                     "nao existe no stock nem esta no manifesto")
caso_recusa_conteudo("destino fora do /vendor", '{apk} /system/app/x.apk 0644 0 0 {app}\n',
                     "caminho limpo em /vendor/")
caso_recusa_conteudo("destino com ..", '{apk} /vendor/app/../x.apk 0644 0 0 {app}\n',
                     "caminho limpo em /vendor/")
caso_recusa_conteudo("destino derivado do stock", '{apk} /vendor/build.prop 0600 0 0 u:object_r:vendor_file:s0\n',
                     "derivado do stock")
caso_recusa_conteudo("metadado declarado difere do stock", '{apk} /vendor/etc/existente.txt 0600 0 0 {cfg}\n',
                     "divergem do esperado")
caso_recusa_conteudo("arquivo por cima de pasta do stock", '{apk} /vendor/app 0755 0 0 {app}\n',
                     "esperado regular")
caso_recusa_conteudo("origem ausente", '/nao/existe.apk /vendor/app/x.apk 0644 0 0 {app}\n', "nao e um arquivo")
caso_recusa_conteudo("rotulo fora do formato", '{apk} /vendor/app/x.apk 0644 0 0 vendor_app_file\n',
                     "fora do formato")
caso_recusa_conteudo("destino repetido", '{apk} /vendor/app/x.apk 0644 0 0 {app}\n{apk} /vendor/app/x.apk 0644 0 0 {app}\n',
                     "repetido")
caso_recusa_conteudo("linha sem 6 campos", '{apk} /vendor/app/x.apk 0644 0 0\n', "origem destino modo uid gid rotulo")
print("== conteudo.txt contra o kit (sem stock) ==")
caso_manifesto_e_kit("conteudo.txt: md5 da KIT_LISTA e pastas do kit")

def caso_real_conteudo(rotulo, stock, ini, manifesto):
    global CASO
    CASO = rotulo
    d = tempfile.mkdtemp(prefix='testbin_')
    try:
        out = os.path.join(d, 'saida.bin')
        rc, log = roda_builder(stock, ini, out, '--realocar', '--conteudo', manifesto)
        print('\n'.join('    ' + x for x in log.strip().splitlines()[-6:]))
        afirma(rc == 0 and 'VALIDO' in log, f"builder falhou: {log.strip().splitlines()[-2:]}")
        if rc != 0:
            return
        pl = confere_realocado(stock, out)
        raw = pl + '.raw'
        sparse.expand(pl, raw)
        os.remove(pl)
        confere_manifesto(raw, manifesto)
        afirma(cat(raw, '/etc/ZYCustom.ini') == ler(ini), "ZYCustom.ini da saida difere do ini dado")
        bp = cat(raw, '/build.prop')
        afirma(b'wifi_disconnect_on_boot=0' in bp and b'wifi_disconnect_on_boot=1' not in bp, "wi-fi nao foi trocado")
        afirma(b'disabled' in cat(raw, '/etc/init/hw/init.bigfish.rc').split(b'service xiriservice')[1][:60],
               "xiriservice nao foi desabilitado")
        for p, m in B.META_FALLBACK.items():
            afirma(meta_de(raw, p) == ('regular', m['mode'], m['uid'], m['gid'], m['selinux'] + '\\000'),
                   f"{p}: metadados do stock mudaram")
        afirma(subprocess.run(['e2fsck', '-fn', raw], capture_output=True).returncode == 0,
               "e2fsck -fn do vendor de saida nao esta limpo")
        os.remove(raw)
        rc, vlog = verificar(out, stock, '--conteudo', manifesto)
        afirma(rc == 0 and 'APROVADO' in vlog, f"--verificar reprovou: {vlog.strip().splitlines()[-3:]}")
        m1 = md5(out)
        print(f"    md5 do .bin de teste: {m1}  ({os.path.getsize(out) - os.path.getsize(stock):+d} B contra o stock)")
        os.remove(out)
        rc2, _ = roda_builder(stock, ini, out, '--realocar', '--conteudo', manifesto)
        afirma(rc2 == 0 and md5(out) == m1, "saida com manifesto nao e deterministica")
    finally:
        shutil.rmtree(d, ignore_errors=True)

ANT = os.environ.get('PFL_STOCK_ANTIGO')
NOV = os.environ.get('PFL_STOCK_NOVO')
if ANT and os.path.isfile(ANT):
    print("== builder: stock V1.0.0.9 de verdade, nos mesmos blocos (gate BIN-S4a) ==")
    caso_real("stock antigo + ini antigo", ANT, FIX_ANTIGO, os.environ.get('PFL_MD5_SAIDA_ANTIGO', MD5_S4A_ANTIGO))
    print("== builder: stock V1.0.0.9 + conteudo.txt, realocado (BIN-S4b) ==")
    caso_real_conteudo("stock antigo + conteudo.txt --realocar", ANT, FIX_ANTIGO, CONTEUDO)
else:
    print("  (PFL_STOCK_ANTIGO nao definido: stock real V1.0.0.9 pulado)")
if NOV and os.path.isfile(NOV):
    print("== builder: stock V1.0.0.1 (sem USB-C) de verdade, nos mesmos blocos ==")
    caso_real("stock novo + ini NOTYPEC", NOV, FIX_NOVO, os.environ.get('PFL_MD5_SAIDA_NOVO', MD5_S4A_NOVO))
else:
    print("  (PFL_STOCK_NOVO nao definido: stock real V1.0.0.1 pulado)")

print("----")
print(f"{TESTES} verificacoes, {FALHAS} falha(s)")
sys.exit(1 if FALHAS else 0)
