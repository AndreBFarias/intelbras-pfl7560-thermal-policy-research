#!/usr/bin/env python3
# ============================================================================
#  build_fix_bin.py - reconstroi o PFL7560.bin com a correcao embutida.
#
#  Edita SO a particao vendor (record 14) e recalcula o CRC-32/MPEG-2 dela.
#  O sparse de saida so tem chunks RAW e DONTCARE e ocupa exatamente o
#  img_length do record, a forma do stock (doc 47 s10).
#
#  Padrao (sem --realocar): os 3 fixes nos MESMOS blocos e inodes do stock. Os
#  bytes vao direto nos chunks RAW do sparse original e so o i_size do inode
#  muda: layout de chunks, tamanho do slot, cabecalho e checksum1 iguais aos do
#  stock; modo, dono e rotulo de todos os inodes intactos por construcao.
#
#  --realocar: grava pelo debugfs (com os metadados do stock carimbados e
#  conferidos), re-empacota o vendor e muda o tamanho do record 14 no container
#  (img_length, offsets dos records seguintes, file_len e checksum1). E o unico
#  modo que aceita --conteudo <manifesto> (arquivos e pastas novos; conteudo.txt).
#
#  Toda saida passa por verificar_bin antes de ganhar o nome final: cabecalho,
#  os 19 records, a forma do sparse e a arvore inteira do vendor contra o stock.
#
#  Requisitos: python3, debugfs, e2fsck (e2fsprogs). Precisa de sparse.py ao lado.
#  Uso:
#    python3 build_fix_bin.py <stock_PFL7560.bin> <ZYCustom.ini_modificado> <saida.bin> [--realocar [--conteudo <manifesto>]]
#    python3 build_fix_bin.py --verificar <saida.bin> <stock_PFL7560.bin> [--conteudo <manifesto>]
# ============================================================================
import hashlib
import re
import sys
import os
import struct
import shutil
import subprocess
import tempfile
import zlib
import sparse

# Container LOAD, tudo big-endian (doc 15 s3): magic, checksum1 @0x04 (CRC do cabecalho com
# ele zerado), header_len @0x08 (0x2b4), file_len u64 @0x0c. As 19 imagens em 0x54 + 32*i
# (= TABLE_OFF + 32*i + 0x14): img_length, offset do prefixo [len][crc], flash_begin u64,
# flash_end u64, flash_type, flash_index. Em header_len fica o prefixo de um blob do loader e,
# logo depois dele, os records, contiguos (offset = anterior + 8 + len). O vendor e o record 14;
# o offset dele NAO e fixo (0x4b0b1d54 no V1.0.0.9, 0x4b0bc954 no V1.0.0.1, doc 42).
TABLE_OFF = 0x40
TABLE_ENTRY = 32
IMG_OFF = TABLE_OFF + 0x14
VENDOR_REC = 14
N_RECORDS = 19
CRC_POLY = 0x04C11DB7

# Fallback V1.0.0.9 (medido no stock oficial) — preferimos ler do stock em runtime.
META_FALLBACK = {
    '/etc/ZYCustom.ini': {
        'mode': '0644', 'uid': '0', 'gid': '0',
        'selinux': 'u:object_r:vendor_configs_file:s0',
    },
    '/build.prop': {
        'mode': '0600', 'uid': '0', 'gid': '0',
        'selinux': 'u:object_r:vendor_file:s0',
    },
    '/etc/init/hw/init.bigfish.rc': {
        'mode': '0644', 'uid': '0', 'gid': '0',
        'selinux': 'u:object_r:vendor_configs_file:s0',
    },
}

TARGET_PATHS = (
    '/etc/ZYCustom.ini',
    '/build.prop',
    '/etc/init/hw/init.bigfish.rc',
)

# Manifesto (bloco 12): origens relativas a raiz do repositorio (ou absolutas); destinos
# como o aparelho os ve (/vendor/...), gravados na imagem sem o prefixo /vendor.
RAIZ_REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PREFIXO_VENDOR = '/vendor'
ROTULO_RE = re.compile(r'^u:object_r:[a-z0-9_]+:s0$')
DESTINO_RE = re.compile(r'^(/[A-Za-z0-9._@+-]+)+$')


def ler_conteudo(manifesto):
    """Le o manifesto: 'origem destino modo uid gid rotulo' por linha ('#' comenta). Origem '-'
    = pasta. Devolve a lista de entradas; aborta (SystemExit, nada e gravado) em qualquer linha
    fora do formato, origem ausente, destino repetido ou derivado do stock, ou modo com escrita
    para grupo ou outros (a causa do brick de julho)."""
    entradas, vistos = [], set()
    for n, linha in enumerate(open(manifesto, encoding='utf-8'), 1):
        linha = linha.split('#', 1)[0].strip()
        if not linha:
            continue
        campos = linha.split()
        onde = f"{manifesto}:{n}"
        if len(campos) != 6:
            raise SystemExit(f"ERRO: {onde}: esperado 'origem destino modo uid gid rotulo' - abortado.")
        origem, destino, modo, uid, gid, rotulo = campos
        if not destino.startswith(PREFIXO_VENDOR + '/') or not DESTINO_RE.match(destino) \
                or '/../' in destino + '/' or '/./' in destino + '/':
            raise SystemExit(f"ERRO: {onde}: destino {destino!r} tem de ser um caminho limpo em /vendor/ - abortado.")
        img = destino[len(PREFIXO_VENDOR):]
        if img in TARGET_PATHS:
            raise SystemExit(f"ERRO: {onde}: {destino} e derivado do stock pelo proprio gerador - abortado.")
        if img in vistos:
            raise SystemExit(f"ERRO: {onde}: destino {destino} repetido - abortado.")
        if not re.match(r'^0[0-7]{3}$', modo) or not uid.isdigit() or not gid.isdigit():
            raise SystemExit(f"ERRO: {onde}: modo (0NNN octal), uid e gid numericos - abortado.")
        if int(modo, 8) & 0o022:
            raise SystemExit(f"ERRO: {onde}: modo {modo} com escrita para grupo ou outros - abortado.")
        if not ROTULO_RE.match(rotulo):
            raise SystemExit(f"ERRO: {onde}: rotulo {rotulo!r} fora do formato u:object_r:<tipo>:s0 - abortado.")
        tipo = 'directory' if origem == '-' else 'regular'
        if tipo == 'regular':
            if not os.path.isabs(origem):
                origem = os.path.join(RAIZ_REPO, origem)
            if not os.path.isfile(origem):
                raise SystemExit(f"ERRO: {onde}: origem {origem} nao e um arquivo - abortado.")
        vistos.add(img)
        entradas.append({'origem': origem, 'destino': destino, 'img': img, 'tipo': tipo,
                         'meta': {'mode': modo, 'uid': uid, 'gid': gid, 'selinux': rotulo}})
    return entradas


def existe(img, path):
    return 'Inode:' in dfs_r(img, f'stat {path}')


def livres(img):
    """(blocos livres, inodes livres, tamanho do bloco) do ext4, pelo superbloco."""
    r = subprocess.run(['debugfs', '-R', 'stats', img], capture_output=True, text=True,
                       env=dict(os.environ, LC_ALL='C', LANG='C'))
    st = r.stdout or ''
    v = {k: re.search(rf'(?m)^{k}:\s+(\d+)', st) for k in ('Free blocks', 'Free inodes', 'Block size')}
    if not all(v.values()):
        raise SystemExit("ERRO: nao consegui ler blocos e inodes livres do vendor - abortado.")
    return tuple(int(v[k].group(1)) for k in ('Free blocks', 'Free inodes', 'Block size'))


def conferir_conteudo_no_ext4(img, entradas, tmp):
    """Cada arquivo do manifesto, lido de volta da imagem, tem de ser byte a byte a copia
    congelada da origem (pega tambem um write do debugfs que falhou por falta de espaco)."""
    for e in entradas:
        if e['tipo'] != 'regular':
            continue
        alvo = f'{tmp}/chk_manifesto'
        if os.path.exists(alvo):
            os.remove(alvo)
        dump(img, e['img'], alvo)
        if not os.path.exists(alvo) or open(alvo, 'rb').read() != open(e['copia'], 'rb').read():
            raise SystemExit(f"ERRO: conteudo de {e['destino']} na imagem difere da origem - abortado.")


def vendor_slot(stock):
    """Le da tabela do stock o offset do prefixo e o tamanho do payload do vendor.
    Devolve (pfx, size). Aborta (SystemExit, nada e gravado) se o container nao for um
    LOAD coerente: magic, record 14 dentro do arquivo e tamanho igual ao do prefixo."""
    total = os.path.getsize(stock)
    with open(stock, 'rb') as f:
        head = f.read(TABLE_OFF + N_RECORDS * TABLE_ENTRY)
        if len(head) < TABLE_OFF + N_RECORDS * TABLE_ENTRY or head[:4] != b'LOAD':
            raise SystemExit("ERRO: o stock nao e um container LOAD (magic/tabela ausente) - abortado.")
        ent = head[TABLE_OFF + VENDOR_REC * TABLE_ENTRY:TABLE_OFF + (VENDOR_REC + 1) * TABLE_ENTRY]
        tsize, pfx = struct.unpack('>II', ent[0x14:0x1c])
        if pfx < TABLE_OFF + N_RECORDS * TABLE_ENTRY or pfx + 8 + tsize > total:
            raise SystemExit(
                f"ERRO: record {VENDOR_REC} da tabela (offset 0x{pfx:x}, tamanho {tsize}) "
                f"fora do arquivo ({total} B) - abortado.")
        f.seek(pfx)
        psize = struct.unpack('>I', f.read(4))[0]
    if psize != tsize:
        raise SystemExit(
            f"ERRO: tamanho do prefixo do vendor ({psize}) difere do da tabela ({tsize}) - abortado.")
    return pfx, tsize


def config_model(path):
    """CONFIG_MODEL do [Global] de um ZYCustom.ini (None se nao achar). Leitura latin-1:
    o arquivo mistura ASCII, chines GBK e mojibake, e so interessa a linha em ASCII."""
    with open(path, encoding='latin-1') as f:
        m = re.search(r'(?m)^CONFIG_MODEL\s*=\s*([A-Za-z0-9_]+)', f.read())
    return m.group(1) if m else None


BITS_INVERTIDOS = bytes(int(f'{i:08b}'[::-1], 2) for i in range(256))


def crc_faixa(f, ini, n):
    """CRC-32/MPEG-2 de n bytes a partir de ini: o zlib.crc32 (refletido) sobre os bytes com os
    bits invertidos, e o registrador invertido de volta. Igual ao crc_header, bit a bit."""
    f.seek(ini)
    c = 0
    while n:
        b = f.read(min(n, 1 << 24))
        if not b:
            raise SystemExit(f"ERRO: arquivo curto ao calcular CRC em 0x{ini:x} - abortado.")
        n -= len(b)
        c = zlib.crc32(b.translate(BITS_INVERTIDOS), c)
    return int(f'{c ^ 0xFFFFFFFF:032b}'[::-1], 2)


def crc32_mpeg2(path):
    with open(path, 'rb') as f:
        return crc_faixa(f, 0, os.path.getsize(path))


def crc_header(buf):
    crc = 0xFFFFFFFF
    for x in buf:
        crc ^= (x << 24)
        crc &= 0xffffffff
        for _ in range(8):
            crc = ((crc << 1) ^ CRC_POLY) & 0xffffffff if (crc & 0x80000000) else (crc << 1) & 0xffffffff
    return crc


def dfs(img, cmds):
    subprocess.run(['debugfs', '-w', '-f', cmds, img],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)


def dfs_r(img, cmd):
    r = subprocess.run(['debugfs', '-R', cmd, img],
                       capture_output=True, text=True)
    return (r.stdout or '') + (r.stderr or '')


def dfs_out(img, cmd):
    return subprocess.run(['debugfs', '-R', cmd, img], capture_output=True, text=True).stdout


def dump(img, path, out):
    subprocess.run(['debugfs', '-R', f'dump {path} {out}', img],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)


def parse_stat(text):
    mode = uid = gid = None
    m = re.search(r'Mode:\s*0*([0-7]+)', text)
    if m:
        mode = m.group(1).zfill(4) if len(m.group(1)) <= 4 else m.group(1)
        if len(mode) == 3:
            mode = '0' + mode
    m = re.search(r'User:\s*(\d+)\s+Group:\s*(\d+)', text)
    if m:
        uid, gid = m.group(1), m.group(2)
    return mode, uid, gid


def parse_selinux(text):
    """Extrai so o contexto (u:object_r:...), sem o prefixo 'security.selinux (N) = '."""
    m = re.search(r'(u:object_r:[A-Za-z0-9_:]+:s0)', text)
    if m:
        return m.group(1)
    m = re.search(r'(system_u:object_r:[A-Za-z0-9_:]+:s0)', text)
    if m:
        return m.group(1)
    return None


def parse_type(text):
    # "Type: regular    Mode:  0644" — so a palavra apos Type:
    m = re.search(r'Type:\s+(\S+)', text)
    return m.group(1).strip() if m else None


def sif_mode_value(perm_str):
    """debugfs 'sif mode 0644' APAGA S_IFREG e vira 'bad type'.
    Precisa de mode com tipo: 0100644 (= S_IFREG|0644)."""
    perm = int(perm_str, 8) & 0o7777
    return f'0{(0o100000 | perm):o}'


def read_meta(img, path, *, allow_fallback=True):
    """Le mode/uid/gid/selinux do arquivo no ext4.
    allow_fallback=True: se faltar algo, usa META_FALLBACK V1.0.0.9 (so no stock).
    allow_fallback=False: exige leitura real (gate pos-edit — sem falso-sucesso).
    """
    st = dfs_r(img, f'stat {path}')
    mode, uid, gid = parse_stat(st)
    ftype = parse_type(st)
    selinux = parse_selinux(st) or parse_selinux(dfs_r(img, f'ea_get {path} security.selinux'))
    fb = META_FALLBACK.get(path, {}) if allow_fallback else {}
    meta = {
        'mode': mode or fb.get('mode'),
        'uid': uid or fb.get('uid', '0'),
        'gid': gid or fb.get('gid', '0'),
        'selinux': selinux or fb.get('selinux'),
        'type': ftype,
    }
    if not meta['mode'] or not meta['selinux']:
        raise SystemExit(
            f"ERRO: nao consegui ler metadados de {path} "
            f"(mode={mode!r} selinux={selinux!r} type={ftype!r} fallback={allow_fallback})")
    # normaliza mode com 4 digitos octais (so bits de permissao na exibicao)
    meta['mode'] = meta['mode'][-4:].zfill(4)
    return meta


def meta_cmds(path, meta, tipo='regular'):
    """Comandos debugfs para carimbar mode/uid/gid + security.selinux.
    mode com S_IFREG (S_IFDIR numa pasta); selinux com NUL terminal (\\000) como no stock (34 bytes)."""
    se = meta['selinux']
    mode_sif = sif_mode_value(meta['mode'])
    if tipo == 'directory':
        mode_sif = f"0{(0o040000 | (int(meta['mode'], 8) & 0o7777)):o}"
    return (
        f"sif {path} mode {mode_sif}\n"
        f"sif {path} uid {meta['uid']}\n"
        f"sif {path} gid {meta['gid']}\n"
        f"ea_set {path} security.selinux {se}\\000\n"
    )


def verify_meta(img, path, expected, tipo='regular'):
    """Confere o tipo (regular ou directory), mode/uid/gid/selinux; aborta se group/world-writable."""
    got = read_meta(img, path, allow_fallback=False)
    mode_int = int(got['mode'], 8)
    if mode_int & 0o022:
        raise SystemExit(
            f"ERRO: {path} mode={got['mode']} e group/world-writable "
            f"(init do Android recusa .rc assim). Abortando."
        )
    ftype = (got.get('type') or '').lower()
    if tipo not in ftype:
        raise SystemExit(
            f"ERRO: {path} Type={got.get('type')!r} (esperado {tipo}). "
            f"Provavel sif mode sem S_IFREG/S_IFDIR."
        )
    errs = []
    if got['mode'] != expected['mode']:
        errs.append(f"mode {got['mode']} != {expected['mode']}")
    if got['uid'] != expected['uid']:
        errs.append(f"uid {got['uid']} != {expected['uid']}")
    if got['gid'] != expected['gid']:
        errs.append(f"gid {got['gid']} != {expected['gid']}")
    if got['selinux'] != expected['selinux']:
        errs.append(f"selinux {got['selinux']!r} != {expected['selinux']!r}")
    if errs:
        raise SystemExit(f"ERRO: metadados de {path} divergem do esperado: " + "; ".join(errs))
    return got


def features(img):
    m = re.search(r'(?m)^Filesystem features:\s*(.*)$', dfs_out(img, 'stats'))
    return m.group(1).split() if m else []


def no_lugar(raw, sp_stock, sp_novo, novos):
    """Grava cada (caminho, arquivo) de novos nos MESMOS blocos de dados do stock, direto nos
    chunks RAW de uma copia do sparse, e ajusta so o i_size (low 32 bits, inode +4) do inode.
    Exige o mesmo numero de blocos, blocos e inode em chunk RAW e ext4 sem metadata_csum
    (o checksum do inode nao e refeito). Aborta antes de gravar qualquer coisa fora do tmp."""
    if 'metadata_csum' in features(raw):
        raise SystemExit("ERRO: vendor com metadata_csum: a gravacao nos mesmos blocos nao refaz o "
                         "checksum do inode - abortado.")
    blk, _total, chunks = sparse.parse(sp_stock)
    mapa = sparse.block_map(blk, chunks)
    shutil.copyfile(sp_stock, sp_novo)
    with open(sp_novo, 'r+b') as f:
        for path, src in novos:
            dados = open(src, 'rb').read()
            blocos = [int(x) for x in dfs_out(raw, f'blocks {path}').split()]
            precisa = -(-len(dados) // blk)
            if not blocos or precisa != len(blocos):
                raise SystemExit(
                    f"ERRO: {path} novo tem {len(dados)} B ({precisa} blocos) e o do stock ocupa "
                    f"{len(blocos)} blocos: nao cabe nos mesmos blocos (use --realocar) - abortado.")
            im = re.search(r'located at block (\d+), offset 0x([0-9a-fA-F]+)', dfs_out(raw, f'imap {path}'))
            ondes = [mapa.get(b) for b in blocos] + [mapa.get(int(im.group(1))) if im else None]
            if any(not e or e[0] != 'raw' for e in ondes):
                raise SystemExit(f"ERRO: {path}: bloco de dados ou do inode fora de chunk RAW - abortado.")
            inode = ondes[-1][1] + int(im.group(2), 16)
            f.seek(inode + 0x6c)
            if f.read(4) != b'\x00' * 4:
                raise SystemExit(f"ERRO: {path}: i_size_high do inode nao e zero - abortado.")
            buf = dados + b'\x00' * (len(blocos) * blk - len(dados))
            for i, e in enumerate(ondes[:-1]):
                f.seek(e[1])
                f.write(buf[i * blk:(i + 1) * blk])
            f.seek(inode + 4)
            f.write(struct.pack('<I', len(dados)))
            print(f"     {path}: {len(dados)} B nos blocos {blocos} (inode no bloco {im.group(1)})")


def ler_cabecalho(f):
    """(cabecalho de header_len bytes, header_len, file_len, [(img_length, offset)] x 19)."""
    f.seek(0)
    base = f.read(0x14)
    if len(base) < 0x14 or base[:4] != b'LOAD':
        raise SystemExit("ERRO: nao e um container LOAD (magic ausente) - abortado.")
    hlen = struct.unpack('>I', base[8:12])[0]
    if hlen < IMG_OFF + N_RECORDS * TABLE_ENTRY or hlen > 0x10000:
        raise SystemExit(f"ERRO: header_len 0x{hlen:x} fora do esperado - abortado.")
    f.seek(0)
    hdr = f.read(hlen)
    flen = struct.unpack('>Q', hdr[0x0c:0x14])[0]
    recs = [struct.unpack('>II', hdr[IMG_OFF + TABLE_ENTRY * i:IMG_OFF + TABLE_ENTRY * i + 8])
            for i in range(N_RECORDS)]
    return hdr, hlen, flen, recs


def checksum1(hdr):
    h = bytearray(hdr)
    h[4:8] = b'\x00' * 4
    return crc_header(bytes(h))


def cabecalho_novo(hdr_stock, novo_len):
    """Cabecalho do stock com o record 14 de novo_len bytes: img_length dele, offsets dos
    records que vem depois, file_len e checksum1. Com novo_len igual, o cabecalho do stock."""
    h = bytearray(hdr_stock)
    b14 = IMG_OFF + TABLE_ENTRY * VENDOR_REC
    old_len, pfx = struct.unpack('>II', h[b14:b14 + 8])
    delta = novo_len - old_len
    if delta:
        struct.pack_into('>I', h, b14, novo_len)
        for i in range(N_RECORDS):
            b = IMG_OFF + TABLE_ENTRY * i
            off = struct.unpack('>I', h[b + 4:b + 8])[0]
            if off > pfx:
                struct.pack_into('>I', h, b + 4, off + delta)
        struct.pack_into('>Q', h, 0x0c, struct.unpack('>Q', h[0x0c:0x14])[0] + delta)
        struct.pack_into('>I', h, 4, checksum1(h))
    return bytes(h)


def copiar_faixa(src, dst, ini, n):
    src.seek(ini)
    while n:
        b = src.read(min(n, 1 << 24))
        if not b:
            raise SystemExit("ERRO: stock curto ao montar a saida - abortado.")
        dst.write(b)
        n -= len(b)


def montar(stock, saida, payload, crc):
    """Saida = cabecalho (com o tamanho novo do record 14, se mudou) + o stock ate o prefixo do
    vendor + [len][crc] + payload + o resto do stock byte a byte."""
    with open(stock, 'rb') as s:
        hdr, hlen, _flen, recs = ler_cabecalho(s)
        size, pfx = recs[VENDOR_REC]
        n = os.path.getsize(payload)
        with open(saida, 'wb') as o, open(payload, 'rb') as p:
            o.write(cabecalho_novo(hdr, n))
            copiar_faixa(s, o, hlen, pfx - hlen)
            o.write(struct.pack('>II', n, crc))
            shutil.copyfileobj(p, o, 1 << 24)
            copiar_faixa(s, o, pfx + 8 + size, os.path.getsize(stock) - (pfx + 8 + size))


def iguais_faixas(fa, ia, fb, ib, n):
    fa.seek(ia)
    fb.seek(ib)
    while n:
        k = min(n, 1 << 24)
        if fa.read(k) != fb.read(k):
            return False
        n -= k
    return True


def forma_sparse(f, ini, n, problemas):
    """Percorre o sparse de n bytes em ini: so RAW e DONTCARE, total_sz coerente, soma dos
    blocos = total_blks, consumido = n. Devolve (blk, total_blks)."""
    f.seek(ini)
    magic, _ma, _mi, fhdr, chdr, blk, total, nch, _crc = struct.unpack('<IHHHHIIII', f.read(28))
    if magic != sparse.SPARSE_MAGIC or fhdr != 28 or chdr != 12 or blk != 4096:
        problemas.append(f"sparse do record {VENDOR_REC}: cabecalho fora do formato do stock")
        return blk, total
    pos, soma, tipos = 28, 0, set()
    for _ in range(nch):
        if pos + 12 > n:
            problemas.append(f"sparse do record {VENDOR_REC}: chunk passa do img_length")
            return blk, total
        f.seek(ini + pos)
        tipo, _r, cnt, tsz = struct.unpack('<HHII', f.read(12))
        if tipo == sparse.RAW and tsz != 12 + cnt * blk or tipo == sparse.DONTCARE and tsz != 12:
            problemas.append(f"sparse do record {VENDOR_REC}: chunk 0x{tipo:x} com total_sz {tsz} incoerente")
        if tipo not in (sparse.RAW, sparse.DONTCARE) and tipo not in tipos:
            problemas.append(f"sparse do record {VENDOR_REC}: chunk 0x{tipo:x} (so RAW e DONTCARE, a forma do stock)")
        tipos.add(tipo)
        pos += tsz
        soma += cnt
    if soma != total:
        problemas.append(f"sparse do record {VENDOR_REC}: soma dos chunks {soma} != total_blks {total}")
    if pos != n:
        problemas.append(f"sparse do record {VENDOR_REC}: ocupa {pos} B e o img_length e {n} "
                         f"({n - pos:+d} B soltos depois do ultimo chunk)")
    return blk, total


def arvore(raw, pasta):
    """{caminho: (tipo, modo, uid, gid, xattrs, conteudo)} de todo o ext4; conteudo = md5 do
    arquivo regular, destino do link simbolico, '' no resto."""
    os.makedirs(pasta)
    subprocess.run(['debugfs', '-R', f'rdump / {pasta}', raw], capture_output=True)
    subprocess.run(['chmod', '-R', 'u+rwX', pasta], capture_output=True)
    caminhos = []
    for d, ds, fs in os.walk(pasta):
        caminhos += ['/' + os.path.relpath(os.path.join(d, x), pasta) for x in ds + fs]
    caminhos.sort()
    cmds = pasta + '.cmds'
    open(cmds, 'w').write(''.join(f'stat "{c}"\n' for c in caminhos))
    saida = subprocess.run(['debugfs', '-f', cmds, raw], capture_output=True, text=True).stdout
    blocos = re.split(r'(?m)^debugfs: stat ', saida)[1:]
    if len(blocos) != len(caminhos):
        raise SystemExit("ERRO: debugfs stat nao devolveu um bloco por caminho - abortado.")
    t = {}
    for c, b in zip(caminhos, blocos):
        m = re.search(r'Type:\s+(\S+)\s+Mode:\s+(\d+)', b)
        u = re.search(r'User:\s+(\d+)\s+Group:\s+(\d+)', b)
        xa = re.search(r'(?ms)^Extended attributes:\n((?:  .*\n)*)', b)
        local = os.path.join(pasta, c[1:])
        if os.path.islink(local):
            cont = os.readlink(local)
        elif os.path.isfile(local):
            cont = hashlib.md5(open(local, 'rb').read()).hexdigest()
        else:
            cont = ''
        t[c] = (m.groups() if m else None, u.groups() if u else None, xa.group(1) if xa else '', cont)
    return t


def verificar_bin(binario, stock, entradas=()):
    """Confere o .bin pronto, relido do disco, contra o stock. Devolve a lista de problemas
    (vazia = aprovado): cabecalho (header_len, file_len, checksum1, so os campos que o tamanho
    do record 14 muda), os 19 records (contiguos, prefixo = tabela, os outros byte a byte iguais
    aos do stock, CRC do 14), a forma do sparse do 14 e a arvore inteira do vendor: e2fsck
    limpo, so os 3 fixes e as entradas do manifesto mudam, metadados de todos os inodes iguais."""
    p = []
    with open(binario, 'rb') as o, open(stock, 'rb') as s:
        hdr, hlen, flen, recs = ler_cabecalho(o)
        hdr_s, hlen_s, _flen_s, recs_s = ler_cabecalho(s)
        tam = os.path.getsize(binario)
        if flen != tam:
            p.append(f"file_len @0x0c = {flen}, o arquivo tem {tam} B")
        if checksum1(hdr) != struct.unpack('>I', hdr[4:8])[0]:
            p.append("checksum1 @0x04 nao confere")
        if hlen != hlen_s or hdr != cabecalho_novo(hdr_s, recs[VENDOR_REC][0]):
            p.append("cabecalho difere do stock fora dos campos do tamanho do record 14")
        o.seek(hlen)
        blen = struct.unpack('>I', o.read(4))[0]
        esperado = hlen + 8 + blen
        if not iguais_faixas(o, hlen, s, hlen_s, 8 + blen):
            p.append("blob do loader (prefixo em header_len) difere do stock")
        for i, (ln, off) in enumerate(recs):
            if off != esperado:
                p.append(f"record {i}: offset 0x{off:x}, esperado 0x{esperado:x} (contiguo)")
                break
            o.seek(off)
            plen, pcrc = struct.unpack('>II', o.read(8))
            if plen != ln:
                p.append(f"record {i}: prefixo {plen} != img_length {ln}")
            if i == VENDOR_REC:
                if crc_faixa(o, off + 8, ln) != pcrc:
                    p.append(f"record {i}: CRC gravado 0x{pcrc:08x} nao confere com o payload")
            elif ln != recs_s[i][0] or not iguais_faixas(o, off, s, recs_s[i][1], 8 + ln):
                p.append(f"record {i}: difere do stock")
            esperado = off + 8 + ln
        if esperado != tam:
            p.append(f"o ultimo record termina em 0x{esperado:x} e o arquivo em 0x{tam:x}")
        ln, off = recs[VENDOR_REC]
        b14 = IMG_OFF + TABLE_ENTRY * VENDOR_REC
        fb, fe = struct.unpack('>QQ', hdr[b14 + 8:b14 + 24])
        blk, total = forma_sparse(o, off + 8, ln, p)
        if fe - fb < total * blk:
            p.append(f"record {VENDOR_REC}: {total} blocos nao cabem na faixa da eMMC ({fe - fb} B)")
        if p:
            return p
        tmp = tempfile.mkdtemp(prefix='pflver_')
        try:
            for nome, f, (n, desl) in (('saida', o, recs[VENDOR_REC]), ('stock', s, recs_s[VENDOR_REC])):
                with open(f'{tmp}/{nome}.sp', 'wb') as d:
                    copiar_faixa(f, d, desl + 8, n)
                sparse.expand(f'{tmp}/{nome}.sp', f'{tmp}/{nome}.raw')
                os.remove(f'{tmp}/{nome}.sp')
            fsck = subprocess.run(['e2fsck', '-fn', f'{tmp}/saida.raw'], capture_output=True)
            if fsck.returncode != 0:
                p.append(f"e2fsck -fn do vendor da saida nao esta limpo (codigo {fsck.returncode})")
            ta, tb = arvore(f'{tmp}/stock.raw', f'{tmp}/stock'), arvore(f'{tmp}/saida.raw', f'{tmp}/saida')
        finally:
            subprocess.run(['chmod', '-R', 'u+rwX', tmp], capture_output=True)
            shutil.rmtree(tmp, ignore_errors=True)
    manifesto = {e['img']: e for e in entradas}
    mudam = set(TARGET_PATHS) | set(manifesto)
    for c in sorted(set(ta) | set(tb)):
        if c not in tb:
            p.append(f"{c}: sumiu da imagem")
        elif c not in ta:
            if c not in manifesto:
                p.append(f"{c}: novo e fora do manifesto")
        elif ta[c][:3] != tb[c][:3]:
            p.append(f"{c}: metadados mudaram ({ta[c][:3]} -> {tb[c][:3]})")
        elif ta[c][3] != tb[c][3] and c not in mudam:
            p.append(f"{c}: conteudo mudou e nao devia")
    for c, e in manifesto.items():
        if c not in tb:
            continue
        m = e['meta']
        tipo, modo = tb[c][0] if tb[c][0] else (None, '')
        if (tipo, modo.zfill(4)[-4:], tb[c][1]) != (e['tipo'], m['mode'], (m['uid'], m['gid'])) \
                or f'"{m["selinux"]}\\000"' not in tb[c][2]:
            p.append(f"{c}: metadados {tb[c][:3]} != manifesto")
        if e['tipo'] == 'regular' and tb[c][3] != hashlib.md5(open(e['origem'], 'rb').read()).hexdigest():
            p.append(f"{c}: conteudo difere da origem do manifesto")
    return p


def main(stock, zy, out, manifesto=None, realocar=False):
    if manifesto and not realocar:
        raise SystemExit("ERRO: --conteudo cria arquivos novos e so cabe com --realocar: sem FILL, o slot "
                         "do stock nao tem folga (doc 47 s10) - abortado, nada foi gravado.")
    entradas = ler_conteudo(manifesto) if manifesto else []
    tmp = tempfile.mkdtemp(prefix='pflbin_')
    parcial = out + '.tmp'
    try:
        # copia congelada de cada origem do manifesto, com nome sem espaco (o debugfs separa
        # argumentos por espaco); e ela que vai para a imagem e contra ela que se confere
        for i, e in enumerate(entradas):
            if e['tipo'] == 'regular':
                e['copia'] = f'{tmp}/manifesto_{i}'
                shutil.copyfile(e['origem'], e['copia'])
        # 1) offset e size do payload vendor (record 14 da tabela) + extrai o sparse
        PFX, size = vendor_slot(stock)
        with open(stock, 'rb') as f:
            f.seek(PFX + 8)
            open(f'{tmp}/vendor.img', 'wb').write(f.read(size))
        print(f"[1] vendor (record {VENDOR_REC}) em 0x{PFX:x}: sparse extraido, {size} bytes")

        # 2) expande para ext4 raw
        blk, total, chunks = sparse.expand(f'{tmp}/vendor.img', f'{tmp}/orig.raw')
        shutil.copy(f'{tmp}/orig.raw', f'{tmp}/edit.raw')

        # 2a) o ini novo tem de ser DO MESMO MODELO do stock: o CONFIG_MODEL difere entre o
        #     V1.0.0.9 (KJM_5H039_412) e o V1.0.0.1 sem USB-C (..._NOTYPEC_TP, doc 42). Gravar o
        #     ini de um no stock do outro rebaixaria o CONFIG_MODEL; recusa antes de gravar.
        dump(f'{tmp}/orig.raw', '/etc/ZYCustom.ini', f'{tmp}/zy.stock')
        cm_stock = config_model(f'{tmp}/zy.stock') if os.path.exists(f'{tmp}/zy.stock') else None
        cm_novo = config_model(zy)
        if not cm_stock or cm_stock != cm_novo:
            raise SystemExit(
                f"ERRO: CONFIG_MODEL do ini ({cm_novo!r}) difere do do stock ({cm_stock!r}). "
                "Use o ini corrigido do MESMO modelo do stock: ZYCustom_390.ini (V1.0.0.9) ou "
                "ZYCustom_390.NOTYPEC.ini (V1.0.0.1, sem USB-C) - abortado, nada foi gravado.")
        print(f"[2a] CONFIG_MODEL do ini = do stock ({cm_stock})")

        # 2b) captura metadados STOCK dos 3 alvos (antes de sobrescrever)
        stock_meta = {}
        print("[2b] metadados stock:")
        for p in TARGET_PATHS:
            stock_meta[p] = read_meta(f'{tmp}/orig.raw', p)
            m = stock_meta[p]
            print(f"     {p}: mode={m['mode']} uid={m['uid']} gid={m['gid']} selinux={m['selinux']}")

        # 2c) manifesto contra o stock: um destino que ja existe tem de ser do mesmo tipo e ter
        #     exatamente os metadados declarados (trocar o conteudo, nunca o rotulo ou o modo); um
        #     destino novo precisa da pasta-mae no stock ou declarada no manifesto; e tem de haver
        #     blocos e inodes livres (cada arquivo novo leva um bloco de xattr: inode de 128 B).
        if entradas:
            novas = set()
            for e in sorted(entradas, key=lambda x: x['img'].count('/')):
                mae = os.path.dirname(e['img'])
                if mae != '/' and not existe(f'{tmp}/orig.raw', mae) and mae not in novas:
                    raise SystemExit(
                        f"ERRO: a pasta de {e['destino']} nao existe no stock nem esta no manifesto - abortado.")
                e['existe'] = existe(f'{tmp}/orig.raw', e['img'])
                if e['existe']:
                    verify_meta(f'{tmp}/orig.raw', e['img'], e['meta'], e['tipo'])
                elif e['tipo'] == 'directory':
                    novas.add(e['img'])
            blocos_livres, inodes_livres, bs = livres(f'{tmp}/orig.raw')
            precisa_b = sum((-(-os.path.getsize(e['copia']) // bs) + 2) if e['tipo'] == 'regular' else 2
                            for e in entradas if not (e['existe'] and e['tipo'] == 'directory'))
            precisa_i = sum(1 for e in entradas if not e['existe'])
            if precisa_b > blocos_livres or precisa_i > inodes_livres:
                raise SystemExit(
                    f"ERRO: falta espaco no vendor: precisa de {precisa_b} blocos e {precisa_i} inodes, "
                    f"livres {blocos_livres} e {inodes_livres} - abortado.")
            print(f"[2c] manifesto: {len(entradas)} entradas conferidas contra o stock "
                  f"(~{precisa_b} blocos de {blocos_livres} livres)")

        # 3) prepara build.prop e init.bigfish.rc a partir do proprio stock; o ini vai por uma copia
        #    sem espaco no nome (o debugfs separa argumentos por espaco)
        shutil.copyfile(zy, f'{tmp}/zy.novo')
        dump(f'{tmp}/orig.raw', '/build.prop', f'{tmp}/bp')
        open(f'{tmp}/bp.mod', 'w').write(
            open(f'{tmp}/bp').read().replace('wifi_disconnect_on_boot=1', 'wifi_disconnect_on_boot=0'))
        dump(f'{tmp}/orig.raw', '/etc/init/hw/init.bigfish.rc', f'{tmp}/rc')
        rc = open(f'{tmp}/rc').read()
        marker = 'service xiriservice /system/bin/xiriservice\n'
        if marker in rc and 'disabled' not in rc.split(marker, 1)[1][:40]:
            rc = rc.replace(marker, marker + '    disabled\n', 1)
        open(f'{tmp}/rc.mod', 'w').write(rc)

        novos = (('/etc/ZYCustom.ini', f'{tmp}/zy.novo'), ('/build.prop', f'{tmp}/bp.mod'),
                 ('/etc/init/hw/init.bigfish.rc', f'{tmp}/rc.mod'))
        if realocar:
            gravar_realocado(tmp, stock_meta, entradas, novos, blk, total)
        else:
            print("[4] os 3 arquivos nos mesmos blocos do stock (layout de chunks e slot iguais):")
            no_lugar(f'{tmp}/orig.raw', f'{tmp}/vendor.img', f'{tmp}/vendor.new', novos)

        # 5) round-trip: o sparse novo, expandido, tem os metadados do stock (e do manifesto) e o
        #    conteudo pedido nos 3 arquivos e em cada entrada
        sparse.expand(f'{tmp}/vendor.new', f'{tmp}/check.raw')
        print("[5] revalidacao pos-pack:")
        for p in TARGET_PATHS:
            got = verify_meta(f'{tmp}/check.raw', p, stock_meta[p])
            print(f"     OK {p}: mode={got['mode']} type={got.get('type')} "
                  f"selinux={got['selinux']}")
        for e in entradas:
            got = verify_meta(f'{tmp}/check.raw', e['img'], e['meta'], e['tipo'])
            print(f"     OK {e['destino']}: mode={got['mode']} type={got.get('type')} "
                  f"selinux={got['selinux']}")
        conferir_conteudo_no_ext4(f'{tmp}/check.raw', entradas, tmp)

        def conteudo(path):
            alvo = f'{tmp}/chk_conteudo'
            if os.path.exists(alvo):
                os.remove(alvo)
            dump(f'{tmp}/check.raw', path, alvo)
            return open(alvo, 'rb').read() if os.path.exists(alvo) else None

        for path, src in novos:
            if conteudo(path) != open(src, 'rb').read():
                raise SystemExit(f"ERRO: {path} final difere do pedido - abortado.")
        bp_final = conteudo('/build.prop')
        if b'wifi_disconnect_on_boot=0' not in bp_final or b'wifi_disconnect_on_boot=1' in bp_final:
            raise SystemExit("ERRO: /build.prop final sem a troca wifi_disconnect_on_boot=0 - abortado.")
        rc_final = conteudo('/etc/init/hw/init.bigfish.rc')
        if marker.encode() not in rc_final or b'disabled' not in rc_final.split(marker.encode(), 1)[1][:40]:
            raise SystemExit("ERRO: init.bigfish.rc final sem o 'disabled' do xiriservice - abortado.")
        print("[5c] conteudo final conferido: ZYCustom.ini = o ini dado, wifi_disconnect_on_boot=0 e "
              "xiriservice disabled")

        # 6) CRC novo da particao e 7) a saida, num nome provisorio
        newcrc = crc32_mpeg2(f'{tmp}/vendor.new')
        novo_len = os.path.getsize(f'{tmp}/vendor.new')
        print(f"[6] CRC vendor novo: 0x{newcrc:08x}; record {VENDOR_REC} com {novo_len} B "
              f"({novo_len - size:+d} B contra o stock)")
        montar(stock, parcial, f'{tmp}/vendor.new', newcrc)

        # 8) conferencia independente do arquivo pronto; so entao ele ganha o nome final
        problemas = verificar_bin(parcial, stock, entradas)
        if problemas:
            raise SystemExit(f"[done] {out}  FALHOU, nada foi gravado:\n  " + "\n  ".join(problemas))
        os.replace(parcial, out)
        extra = f" + {len(entradas)} entradas do manifesto" if entradas else ''
        modo = 'realocado' if realocar else 'nos mesmos blocos do stock'
        print(f"[8] verificar_bin: cabecalho, 19 records, sparse so RAW/DONTCARE no img_length e arvore do vendor OK")
        print(f"[done] {out}  VALIDO ({modo}; conteudo + metadados stock nos 3 arquivos{extra})")
        print("       AVISO: ainda teste em hardware com pendrive de resgate oficial ao lado.")
    finally:
        if os.path.exists(parcial):
            os.remove(parcial)
        shutil.rmtree(tmp, ignore_errors=True)


def gravar_realocado(tmp, stock_meta, entradas, novos, blk, total):
    """--realocar: os 3 arquivos e o manifesto pelo debugfs, metadados carimbados e conferidos,
    e2fsck, superbloco fixo e re-pack (RAW/DONTCARE) em vendor.new, do tamanho que der."""
    MT, CT = '20191231210000', '20081231140000'   # mtime / (ctime=atime=crtime), determinismo

    def tempos(path):
        return (f"sif {path} mtime {MT}\nsif {path} ctime {CT}\n"
                f"sif {path} atime {CT}\nsif {path} crtime {CT}\n")

    def edit(path, src):
        return f"rm {path}\nwrite {src} {path}\n" + tempos(path) + meta_cmds(path, stock_meta[path])

    # manifesto: pastas novas primeiro (das mais rasas para as mais fundas), depois os arquivos
    def manifesto_cmds():
        c = ''
        for e in sorted(entradas, key=lambda x: (x['tipo'] != 'directory', x['img'].count('/'), x['img'])):
            if e['tipo'] == 'directory':
                if not e['existe']:
                    c += f"mkdir {e['img']}\n" + tempos(e['img']) + meta_cmds(e['img'], e['meta'], 'directory')
            else:
                c += (f"rm {e['img']}\n" if e['existe'] else '') + f"write {e['copia']} {e['img']}\n" \
                    + tempos(e['img']) + meta_cmds(e['img'], e['meta'])
        return c

    cmds = f'{tmp}/cmds'
    open(cmds, 'w').write(''.join(edit(p, src) for p, src in novos) + manifesto_cmds())
    dfs(f'{tmp}/edit.raw', cmds)
    # e2fsck -fy: 0 = limpo, 1/2 = corrigiu (esperado apos o debugfs); >= 4 = erros
    # NAO corrigidos ou falha operacional -> a imagem nao e confiavel.
    fsck = subprocess.run(['e2fsck', '-fy', f'{tmp}/edit.raw'],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    if fsck.returncode >= 4:
        raise SystemExit(
            f"ERRO: e2fsck terminou com codigo {fsck.returncode} (>= 4) - imagem nao "
            "confiavel, abortado.")

    # Reaplica metadados apos e2fsck (defesa: e2fsck nao deve stripar, mas garantimos)
    cmds2 = f'{tmp}/cmds_meta'
    open(cmds2, 'w').write(''.join(meta_cmds(p, stock_meta[p]) for p in TARGET_PATHS)
                           + ''.join(meta_cmds(e['img'], e['meta'], e['tipo']) for e in entradas))
    dfs(f'{tmp}/edit.raw', cmds2)

    # Gate fatal: metadados == stock (e == manifesto); nenhum .rc group-writable
    print("[4b] verificando metadados pos-edit:")
    for p in TARGET_PATHS:
        got = verify_meta(f'{tmp}/edit.raw', p, stock_meta[p])
        print(f"     OK {p}: mode={got['mode']} selinux={got['selinux']}")
    for e in entradas:
        got = verify_meta(f'{tmp}/edit.raw', e['img'], e['meta'], e['tipo'])
        print(f"     OK {e['destino']}: {e['tipo']} mode={got['mode']} uid={got['uid']} "
              f"gid={got['gid']} selinux={got['selinux']}")
    conferir_conteudo_no_ext4(f'{tmp}/edit.raw', entradas, tmp)

    # determinismo: o debugfs/e2fsck carimbam s_wtime e s_lastcheck
    FIXED = struct.pack('<I', 0x5e0be100)   # 2019-12-31, mesma era do stock
    with open(f'{tmp}/edit.raw', 'r+b') as f:
        f.seek(1024 + 0x30)
        f.write(FIXED)   # s_wtime
        f.seek(1024 + 0x40)
        f.write(FIXED)   # s_lastcheck
    print("[4] 3 arquivos + manifesto + metadados stock + e2fsck + superbloco fixado")

    psz, nch, ptotal = sparse.pack(f'{tmp}/edit.raw', f'{tmp}/vendor.new', blk=blk)
    if ptotal != total:
        raise SystemExit(f"ERRO: total_blocks pack={ptotal} != stock={total}")
    print(f"[4c] sparse pack (RAW/DONTCARE): {psz} bytes, {nch} chunks")


def uso():
    print("uso: build_fix_bin.py <stock.bin> <ZYCustom.ini> <saida.bin> [--realocar [--conteudo <manifesto>]]\n"
          "     build_fix_bin.py --verificar <saida.bin> <stock.bin> [--conteudo <manifesto>]")
    sys.exit(1)


if __name__ == '__main__':
    args = sys.argv[1:]
    manifesto = None
    if '--conteudo' in args:
        k = args.index('--conteudo')
        if k + 1 >= len(args):
            uso()
        manifesto = args[k + 1]
        del args[k:k + 2]
    realocar = '--realocar' in args
    if realocar:
        args.remove('--realocar')
    if args[:1] == ['--verificar'] and len(args) == 3 and not realocar:
        problemas = verificar_bin(args[1], args[2], ler_conteudo(manifesto) if manifesto else ())
        print('\n'.join(f"  {x}" for x in problemas) or "  nenhum problema")
        print(f"[verificar] {args[1]}  {'FALHOU' if problemas else 'APROVADO'}")
        sys.exit(1 if problemas else 0)
    if len(args) != 3 or any(a.startswith('--') for a in args):
        uso()
    main(*args, manifesto=manifesto, realocar=realocar)
