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
# Bloco 12: o manifesto (--conteudo, artifacts/bin-build/conteudo.txt) grava arquivos e pastas
# novos com os metadados carimbados; conferido aqui por fora, com debugfs, entrada por entrada,
# e as recusas (sem espaco no ext4, sem folga no slot, modo com escrita para grupo, pasta-mae
# ausente, destino fora do /vendor ou derivado, metadado diferente do stock, origem ausente).
# Com PFL_STOCK_ANTIGO roda tambem o conteudo.txt de verdade no stock e confere so o record
# 14 mudado, cabecalho intacto, checksum1, CRC e cada entrada; o .bin de teste e apagado.
#
# Precisa de: python3, mke2fs, debugfs, e2fsck. NUNCA fala com o aparelho.
#   python3 tests/test-builder-bin.py
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
    h = hashlib.md5()
    with open(path, 'rb') as f:
        for b in iter(lambda: f.read(1 << 24), b''):
            h.update(b)
    return h.hexdigest()


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


def roda_builder(stock, ini, out, *extra):
    r = subprocess.run([sys.executable, os.path.join(BB, 'build_fix_bin.py'), stock, ini, out, *extra],
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

# ---- bloco 12: manifesto (--conteudo) ----------------------------------------------------
ROTULO_CFG = 'u:object_r:vendor_configs_file:s0'
ROTULO_APP = 'u:object_r:vendor_app_file:s0'
CONTEUDO = os.path.join(BB, 'conteudo.txt')


def meta_de(raw, path):
    """(tipo, modo, uid, gid, rotulo com o NUL do stock) lidos por fora, pelo debugfs stat."""
    st = subprocess.run(['debugfs', '-R', f'stat {path}', raw], capture_output=True, text=True).stdout
    m = re.search(r'Type:\s+(\S+)\s+Mode:\s+(\d+)', st)
    u = re.search(r'User:\s+(\d+)\s+Group:\s+(\d+)', st)
    r = re.search(r'security\.selinux \(\d+\) = "([^"]*)"', st)
    if not (m and u and r):
        return None
    return (m.group(1), m.group(2).zfill(4)[-4:], u.group(1), u.group(2), r.group(1))


def ler_manifesto(path):
    """Leitura propria (independente do builder): [(origem|None, destino na imagem, meta esperada)]."""
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


def stock_com_app(d, pfx, folga):
    """Stock sintetico com /app (como o vendor: 0755 root:shell, vendor_app_file) e um arquivo
    /etc/existente.txt (0644, vendor_configs_file) para o caso de troca de conteudo."""
    raw = ext4_com_os_3_arquivos(d, ANTIGO_INI, os.path.join(ART, 'build.prop.STOCK'),
                                 os.path.join(ART, 'init.bigfish.rc.STOCK'))
    ex = os.path.join(d, 'existente.txt')
    open(ex, 'w').write('versao de fabrica\n')
    cmds = (f'mkdir /app\nsif /app mode 040755\nsif /app gid 2000\nea_set /app security.selinux {ROTULO_APP}\\000\n'
            f'write {ex} /etc/existente.txt\n' + B.meta_cmds('/etc/existente.txt', {
                'mode': '0644', 'uid': '0', 'gid': '0', 'selinux': ROTULO_CFG}))
    open(os.path.join(d, 'cmds2'), 'w').write(cmds)
    B.dfs(raw, os.path.join(d, 'cmds2'))
    return monta_stock(d, raw, pfx, folga=folga)


def apk_falso(d, tamanho):
    p = os.path.join(d, 'app falso.apk')   # com espaco: o builder copia antes de dar ao debugfs
    open(p, 'wb').write(hashlib.sha256(b'pfl').digest() * (tamanho // 32))
    return p


def caso_conteudo(rotulo):
    global CASO
    CASO = rotulo
    d = tempfile.mkdtemp(prefix='testbin_')
    try:
        stock, size = stock_com_app(d, 0x2c0, folga=256 * 1024)
        novo = os.path.join(d, 'existente.novo')
        open(novo, 'w').write('versao nova, mais comprida que a de fabrica\n')
        man = os.path.join(d, 'conteudo.txt')
        open(man, 'w').write(
            '# comentario\n\n'
            f'pendrive-autorun/pfl7560-suite.rc /vendor/etc/init/pfl7560-suite.rc 0644 0 0 {ROTULO_CFG}\n'
            f'{apk_falso(d, 20000).replace(" ", "?")} /vendor/app/PFL7560/PFL7560.apk 0644 0 0 {ROTULO_APP}\n'
            f'- /vendor/app/PFL7560 0755 0 0 {ROTULO_APP}   # a pasta pode vir depois do arquivo\n'
            f'{novo} /vendor/etc/existente.txt 0644 0 0 {ROTULO_CFG}\n'
            f'- /vendor/etc/pfl7560 0755 0 2000 {ROTULO_CFG}\n'
            f'- /vendor/etc/pfl7560/sub 0700 0 0 {ROTULO_CFG}\n')
        out = os.path.join(d, 'saida.bin')
        rc, log = roda_builder(stock, FIX_ANTIGO, out, '--conteudo', man)
        afirma(rc != 0 and 'nao e um arquivo' in log, "origem com '?' devia ser recusada (nome literal)")
        # agora com o nome de verdade (com espaco: o manifesto separa por espaco, entao o teste
        # usa um link sem espaco para a origem)
        link = os.path.join(d, 'app_falso.apk')
        os.symlink(apk_falso(d, 20000), link)
        texto = open(man).read().replace(apk_falso(d, 20000).replace(' ', '?'), link)
        open(man, 'w').write(texto)
        rc, log = roda_builder(stock, FIX_ANTIGO, out, '--conteudo', man)
        afirma(rc == 0 and 'VALIDO' in log and '6 entradas do manifesto' in log,
               f"builder com manifesto falhou (rc={rc}): {log.strip().splitlines()[-2:]}")
        if rc != 0:
            return
        confere_saida(stock, out, 0x2c0, size, FIX_ANTIGO)
        o = ler(out)
        pl = os.path.join(d, 'conteudo.vendor')
        open(pl, 'wb').write(o[0x2c0 + 8:0x2c0 + 8 + size])
        raw = pl + '.raw'
        sparse.expand(pl, raw)
        confere_manifesto(raw, man)
        afirma(meta_de(raw, '/app') == ('directory', '0755', '0', '2000', ROTULO_APP + '\\000'),
               "a pasta /app do stock mudou de metadados")
        for p, m in B.META_FALLBACK.items():
            afirma(meta_de(raw, p) == ('regular', m['mode'], m['uid'], m['gid'], m['selinux'] + '\\000'),
                   f"{p}: metadados do stock mudaram")
        afirma(subprocess.run(['e2fsck', '-fn', raw], capture_output=True).returncode == 0,
               "e2fsck -fn da imagem de saida nao esta limpo")
        rc2, _ = roda_builder(stock, FIX_ANTIGO, out + '.2', '--conteudo', man)
        afirma(rc2 == 0 and md5(out) == md5(out + '.2'), "saida com manifesto nao e deterministica")
    finally:
        shutil.rmtree(d, ignore_errors=True)


def caso_recusa_conteudo(rotulo, linhas, trecho, folga=256 * 1024, tamanho_apk=20000):
    """Manifesto invalido ou sem espaco: rc != 0, a mensagem, e nenhum .bin de saida."""
    global CASO
    CASO = rotulo
    d = tempfile.mkdtemp(prefix='testbin_')
    try:
        stock, _size = stock_com_app(d, 0x2c0, folga=folga)
        apk = os.path.join(d, 'apk.bin')
        os.rename(apk_falso(d, tamanho_apk), apk)
        man = os.path.join(d, 'conteudo.txt')
        open(man, 'w').write(linhas.format(apk=apk, cfg=ROTULO_CFG, app=ROTULO_APP))
        out = os.path.join(d, 'saida.bin')
        rc, log = roda_builder(stock, FIX_ANTIGO, out, '--conteudo', man)
        afirma(rc != 0 and trecho in log, f"nao recusou com '{trecho}' (rc={rc}): {log.strip().splitlines()[-1:]}")
        afirma(not os.path.exists(out), "gerou o .bin apesar da recusa")
    finally:
        shutil.rmtree(d, ignore_errors=True)


print("== builder: manifesto --conteudo (containers sinteticos) ==")
caso_conteudo("manifesto com .rc, pasta e app novos, troca de conteudo e pastas aninhadas")
APK_LINHAS = '- /vendor/app/PFL7560 0755 0 0 {app}\n{apk} /vendor/app/PFL7560/PFL7560.apk 0644 0 0 {app}\n'
caso_recusa_conteudo("app maior que a folga do slot", APK_LINHAS, "maior que o slot stock",
                     folga=65536, tamanho_apk=96000)
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


def iguais_fora(a, b, ini, fim):
    """Os dois arquivos sao iguais fora de [ini, fim) (lido em pedacos: 1,3 GB cada)."""
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


def caso_real_conteudo(rotulo, stock, ini, manifesto):
    """Stock de verdade + manifesto: so o record 14 (prefixo de CRC e payload) muda, cabecalho
    intacto, checksum1 e CRC conferidos, cada entrada do manifesto com modo, dono, rotulo e
    conteudo, os 3 fixes no lugar, e saida deterministica. Imprime o md5; o .bin e apagado."""
    global CASO
    CASO = rotulo
    d = tempfile.mkdtemp(prefix='testbin_')
    try:
        out = os.path.join(d, 'saida.bin')
        rc, log = roda_builder(stock, ini, out, '--conteudo', manifesto)
        print('\n'.join('    ' + x for x in log.strip().splitlines()))
        afirma(rc == 0 and 'VALIDO' in log, f"builder falhou: {log.strip().splitlines()[-2:]}")
        if rc != 0:
            return
        with open(stock, 'rb') as f:
            f.seek(TABLE_OFF + VENDOR_REC * TABLE_ENTRY + 0x14)
            size, pfx = struct.unpack('>II', f.read(8))
            f.seek(0)
            hdr_stock = f.read(0x2b4)
        afirma(os.path.getsize(out) == os.path.getsize(stock), "tamanho do .bin mudou")
        afirma(iguais_fora(stock, out, pfx + 4, pfx + 8 + size), "mudou algo fora do record 14 (CRC + payload)")
        with open(out, 'rb') as o:
            hdr = bytearray(o.read(0x2b4))
            o.seek(pfx)
            psize, crc_gravado = struct.unpack('>II', o.read(8))
            pl = os.path.join(d, 'v.bin')
            open(pl, 'wb').write(o.read(size))
        afirma(bytes(hdr) == hdr_stock, "cabecalho/tabela LOAD mudou")
        afirma(psize == size, "tamanho do prefixo do vendor mudou")
        c1 = struct.unpack('>I', hdr[4:8])[0]
        hdr[4:8] = b'\x00\x00\x00\x00'
        afirma(B.crc_header(bytes(hdr)) == c1, "checksum1 nao confere")
        afirma(crc_gravado == B.crc32_mpeg2(pl), "CRC do vendor nao confere")
        raw = pl + '.raw'
        sparse.expand(pl, raw)
        os.remove(pl)
        confere_manifesto(raw, manifesto)
        for origem, img, esperado in ler_manifesto(manifesto):
            print(f"    debugfs {img}: {meta_de(raw, img)} md5 {hashlib.md5(cat(raw, img)).hexdigest() if origem else '-'}")
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
        m1 = md5(out)
        print(f"    md5 do .bin de teste: {m1}  CRC do vendor 0x{crc_gravado:08x}")
        os.remove(out)
        rc2, _ = roda_builder(stock, ini, out, '--conteudo', manifesto)
        afirma(rc2 == 0 and md5(out) == m1, "saida com manifesto nao e deterministica")
    finally:
        shutil.rmtree(d, ignore_errors=True)


def caso_real_recusa_app(rotulo, stock, ini):
    """Stock de verdade + o app no manifesto: o slot do vendor nao comporta; recusa sem saida."""
    global CASO
    CASO = rotulo
    d = tempfile.mkdtemp(prefix='testbin_')
    try:
        man = os.path.join(d, 'conteudo-com-app.txt')
        open(man, 'w').write(open(CONTEUDO).read() + APK_LINHAS.format(
            apk='pendrive-autorun/pfl7560.apk', app=ROTULO_APP))
        out = os.path.join(d, 'saida.bin')
        rc, log = roda_builder(stock, ini, out, '--conteudo', man)
        print('    ' + (log.strip().splitlines() or [''])[-1])
        afirma(rc != 0 and 'maior que o slot stock' in log, f"nao recusou o app por falta de slot: {log.strip().splitlines()[-1:]}")
        afirma(not os.path.exists(out), "gerou o .bin apesar da recusa")
    finally:
        shutil.rmtree(d, ignore_errors=True)


ANT = os.environ.get('PFL_STOCK_ANTIGO')
NOV = os.environ.get('PFL_STOCK_NOVO')
if ANT and os.path.isfile(ANT):
    print("== builder: stock V1.0.0.9 de verdade ==")
    caso_real("stock antigo + ini antigo: md5 eae3a83d de sempre", ANT, FIX_ANTIGO,
              'eae3a83db44f790b64b9a5838a27a977')
    print("== builder: stock V1.0.0.9 + conteudo.txt (bloco 12) ==")
    caso_real_conteudo("stock antigo + conteudo.txt", ANT, FIX_ANTIGO, CONTEUDO)
    caso_real_recusa_app("stock antigo + app no manifesto: nao cabe no slot", ANT, FIX_ANTIGO)
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
