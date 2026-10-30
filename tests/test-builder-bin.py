#!/usr/bin/env python3
# tests/test-builder-bin.py - bloco 6 (T6.2): o build_fix_bin.py le o offset e o
# tamanho do vendor (record 14) da tabela do container, nao de uma constante.
#
# Monta containers LOAD SINTETICOS e pequenos (um ext4 de 4 MiB com os 3 arquivos que o
# builder edita, empacotado em sparse, dentro de um LOAD com o record 14 em offsets
# diferentes) e roda o builder REAL contra eles. Nao depende dos .bin de 1,3 GB.
# Opcional, com os stocks de verdade (so leitura): PFL_STOCK_ANTIGO (V1.0.0.9) e
# PFL_STOCK_NOVO (V1.0.0.1, sem USB-C) rodam o builder com cada um: o antigo tem de sair
# com md5 eae3a83d e o novo (com ZYCustom_390.NOTYPEC.ini) com 0d294cb3, CRC do vendor 0xe2cad2f5.
#
# Precisa de: python3, mke2fs, debugfs, e2fsck. NUNCA fala com o aparelho.
#   python3 tests/test-builder-bin.py
import hashlib
import os
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

# layout do container LOAD (doc 42 s2): escrito aqui, de proposito, e nao importado do builder
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
    return hashlib.md5(open(path, 'rb').read()).hexdigest()


def ler(path):
    return open(path, 'rb').read()


def ext4_com_os_3_arquivos(d, ini, bp, rc):
    """ext4 de 4 MiB com /etc/ZYCustom.ini, /build.prop e /etc/init/hw/init.bigfish.rc,
    com os metadados do stock (mode, uid/gid e security.selinux), como o vendor real."""
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


def monta_stock(d, raw, pfx, folga=65536, depois=4096):
    """LOAD sintetico: cabecalho 0x2b4 com checksum1 em 0x04, tabela em 0x40 (19 x 32 B) com o
    record 14 apontando para `pfx`, prefixo [size BE][crc BE] + payload sparse + folga de
    zeros (o slot do stock) + bytes de outro record depois. Devolve (caminho, size)."""
    payload = os.path.join(d, 'vendor.sparse')
    psz, _n, _total = sparse.pack(raw, payload)
    size = psz + folga
    with open(payload, 'ab') as f:
        f.write(b'\x00' * folga)
    crc = B.crc32_mpeg2(payload)
    hdr = bytearray(0x2b4)
    hdr[0:4] = b'LOAD'
    hdr[0x10:0x14] = struct.pack('>I', pfx + 8 + size + depois)
    for i in range(N_RECORDS):
        ent = bytearray(32)
        if i == VENDOR_REC:
            struct.pack_into('>II', ent, 0x14, size, pfx)
        else:
            struct.pack_into('>II', ent, 0x14, 4096, 0x2c0 + 0x1000 * i)   # records de enfeite
        hdr[0x40 + 32 * i:0x40 + 32 * (i + 1)] = ent
    struct.pack_into('>I', hdr, 4, B.crc_header(bytes(hdr[:4] + b'\x00\x00\x00\x00' + hdr[8:])))
    out = os.path.join(d, 'stock.bin')
    with open(out, 'wb') as f:
        f.write(bytes(hdr))
        f.write(b'\xee' * (pfx - len(hdr)))
        f.write(struct.pack('>II', size, crc))
        f.write(ler(payload))
        f.write(b'\xdd' * depois)
    return out, size


def roda_builder(stock, ini, out):
    r = subprocess.run([sys.executable, os.path.join(BB, 'build_fix_bin.py'), stock, ini, out],
                       capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


def cat(raw, path):
    return subprocess.run(['debugfs', '-R', f'cat {path}', raw], capture_output=True).stdout


def confere_saida(stock, out, pfx, size, ini):
    """Confere o .bin de saida de forma independente do builder."""
    s, o = ler(stock), ler(out)
    afirma(len(s) == len(o), "tamanho do .bin mudou")
    afirma(s[:0x2b4] == o[:0x2b4], "cabecalho/tabela LOAD (checksum1 inclusive) mudou")
    afirma(s[:pfx] == o[:pfx], "bytes antes do record 14 mudaram")
    afirma(s[pfx + 8 + size:] == o[pfx + 8 + size:], "bytes depois do record 14 mudaram")
    afirma(s[pfx:pfx + 4] == o[pfx:pfx + 4], "o tamanho do prefixo mudou")
    payload = o[pfx + 8:pfx + 8 + size]
    pl = os.path.join(os.path.dirname(out), 'saida.vendor')
    open(pl, 'wb').write(payload)
    afirma(struct.unpack('>I', o[pfx + 4:pfx + 8])[0] == B.crc32_mpeg2(pl), "CRC do vendor gravado nao confere com o payload")
    afirma(o[pfx + 8:pfx + 8 + size] != s[pfx + 8:pfx + 8 + size], "o vendor nao mudou")
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
        if rc == 0:
            confere_saida(stock, out, pfx, size, ini_dado)
            rc2, _ = roda_builder(stock, ini_dado, out + '.2')
            afirma(rc2 == 0 and md5(out) == md5(out + '.2'), "saida nao e deterministica")
    finally:
        shutil.rmtree(d, ignore_errors=True)


def caso_recusa(rotulo, mexe, stock_ini, ini_dado, pfx, trecho):
    """O builder tem de recusar (rc != 0, mensagem) e NAO gerar o .bin de saida."""
    global CASO
    CASO = rotulo
    d = tempfile.mkdtemp(prefix='testbin_')
    try:
        raw = ext4_com_os_3_arquivos(d, stock_ini, os.path.join(ART, 'build.prop.STOCK'),
                                     os.path.join(ART, 'init.bigfish.rc.STOCK'))
        stock, size = monta_stock(d, raw, pfx)
        mexe(stock, pfx, size)
        out = os.path.join(d, 'saida.bin')
        rc, log = roda_builder(stock, ini_dado, out)
        afirma(rc != 0 and trecho in log, f"nao recusou com '{trecho}' (rc={rc}): {log.strip().splitlines()[-1:]}")
        afirma(not os.path.exists(out), "gerou o .bin apesar da recusa")
    finally:
        shutil.rmtree(d, ignore_errors=True)


def poe(stock, pos, dados):
    with open(stock, 'r+b') as f:
        f.seek(pos)
        f.write(dados)


def caso_real(rotulo, stock, ini, md5_saida=None):
    """Com o stock de verdade (1,3 GB): o builder gera um .bin com checksum1 e CRC do vendor
    conferidos; com o md5 de saida esperado, quando ele e conhecido."""
    global CASO
    CASO = rotulo
    d = tempfile.mkdtemp(prefix='testbin_')
    try:
        out = os.path.join(d, 'saida.bin')
        rc, log = roda_builder(stock, ini, out)
        afirma(rc == 0 and 'VALIDO' in log, f"builder falhou: {log.strip().splitlines()[-2:]}")
        if rc != 0:
            return
        with open(stock, 'rb') as f:
            f.seek(TABLE_OFF + VENDOR_REC * TABLE_ENTRY + 0x14)
            size, pfx = struct.unpack('>II', f.read(8))
        o = open(out, 'rb')
        hdr = bytearray(o.read(0x2b4))
        c1 = struct.unpack('>I', hdr[4:8])[0]
        hdr[4:8] = b'\x00\x00\x00\x00'
        afirma(B.crc_header(bytes(hdr)) == c1, "checksum1 nao confere")
        o.seek(pfx + 4)
        crc_gravado = struct.unpack('>I', o.read(4))[0]
        pl = os.path.join(d, 'v.bin')
        o.seek(pfx + 8)
        open(pl, 'wb').write(o.read(size))
        o.close()
        afirma(crc_gravado == B.crc32_mpeg2(pl), "CRC do vendor nao confere")
        if md5_saida:
            afirma(md5(out) == md5_saida, f"md5 da saida {md5(out)} != {md5_saida}")
    finally:
        shutil.rmtree(d, ignore_errors=True)


CASO = ''
ANTIGO_INI = os.path.join(ART, 'ZYCustom.ini.ORIGINAL')
NOVO_INI = os.path.join(ART, 'ZYCustom.ini.NOTYPEC.STOCK')
FIX_ANTIGO = os.path.join(ART, 'ZYCustom_390.ini')
FIX_NOVO = os.path.join(ART, 'ZYCustom_390.NOTYPEC.ini')

print("== builder: offset e tamanho do vendor lidos da tabela (containers sinteticos) ==")
# dois offsets diferentes entre si e do antigo fixo (o do V1.0.0.1 e 0xac00 depois do V1.0.0.9)
caso_layout("modelo com USB-C, vendor em 0x2c0", ANTIGO_INI, FIX_ANTIGO, 0x2c0)
caso_layout("modelo com USB-C, vendor em 0x2c0+0xac00", ANTIGO_INI, FIX_ANTIGO, 0x2c0 + 0xac00)
caso_layout("modelo sem USB-C, vendor em 0x2c0+0xac00", NOVO_INI, FIX_NOVO, 0x2c0 + 0xac00)
caso_layout("modelo sem USB-C, vendor em 0x400", NOVO_INI, FIX_NOVO, 0x400)

print("== builder: recusas (nada e gravado) ==")
caso_recusa("magic LOAD ausente", lambda s, p, z: poe(s, 0, b'XXXX'), ANTIGO_INI, FIX_ANTIGO, 0x2c0,
            "nao e um container LOAD")
caso_recusa("tamanho do prefixo difere da tabela",
            lambda s, p, z: poe(s, p, struct.pack('>I', z - 4096)), ANTIGO_INI, FIX_ANTIGO, 0x2c0,
            "difere do da tabela")
caso_recusa("record 14 fora do arquivo",
            lambda s, p, z: poe(s, 0x40 + 32 * VENDOR_REC + 0x18, struct.pack('>I', 0x7fffff00)),
            ANTIGO_INI, FIX_ANTIGO, 0x2c0, "fora do arquivo")
caso_recusa("ini do modelo sem USB-C no stock com USB-C", lambda s, p, z: None, ANTIGO_INI, FIX_NOVO,
            0x2c0, "CONFIG_MODEL")
caso_recusa("ini do modelo com USB-C no stock sem USB-C", lambda s, p, z: None, NOVO_INI, FIX_ANTIGO,
            0x2c0, "CONFIG_MODEL")

ANT = os.environ.get('PFL_STOCK_ANTIGO')
NOV = os.environ.get('PFL_STOCK_NOVO')
if ANT and os.path.isfile(ANT):
    print("== builder: stock V1.0.0.9 de verdade ==")
    caso_real("stock antigo + ini antigo: md5 eae3a83d de sempre", ANT, FIX_ANTIGO,
              'eae3a83db44f790b64b9a5838a27a977')
else:
    print("  (PFL_STOCK_ANTIGO nao definido: stock real V1.0.0.9 pulado)")
if NOV and os.path.isfile(NOV):
    print("== builder: stock V1.0.0.1 (sem USB-C) de verdade ==")
    caso_real("stock novo + ini NOTYPEC", NOV, FIX_NOVO, os.environ.get('PFL_MD5_SAIDA_NOVO', '0d294cb3800808e4c825cc9190e7ca34'))
else:
    print("  (PFL_STOCK_NOVO nao definido: stock real V1.0.0.1 pulado)")

print("----")
print(f"{TESTES} verificacoes, {FALHAS} falha(s)")
sys.exit(1 if FALHAS else 0)
