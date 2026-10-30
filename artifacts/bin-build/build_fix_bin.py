#!/usr/bin/env python3
# ============================================================================
#  build_fix_bin.py - reconstroi o PFL7560.bin com a correcao embutida.
#
#  Edita SO a particao vendor (record 14) mantendo o tamanho do payload, para
#  que o checksum1 do container ("LOAD") continue valido; recalcula apenas o
#  CRC-32/MPEG-2 daquela particao. Ver docs/research/15-bin-definitivo.md.
#
#  Apos debugfs write, RESTAURA metadados do stock (mode/uid/gid + xattr
#  security.selinux). Sem isso o init do Android recusa .rc group-writable
#  (0664) e o boot trava na logo — causa do PFL7560-FIX em quarentena.
#
#  Requisitos: python3, debugfs, e2fsck (e2fsprogs). Precisa de sparse.py ao lado.
#  Uso:
#    python3 build_fix_bin.py <stock_PFL7560.bin> <ZYCustom.ini_modificado> <saida.bin>
# ============================================================================
import re
import sys
import os
import struct
import shutil
import subprocess
import tempfile
import sparse

PFX = 0x4b0b1d54                      # prefixo [size BE][crc BE] da particao vendor
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


def crc32_mpeg2(path):
    t = []
    for i in range(256):
        c = (i << 24) & 0xffffffff
        for _ in range(8):
            c = ((c << 1) ^ CRC_POLY) & 0xffffffff if (c & 0x80000000) else (c << 1) & 0xffffffff
        t.append(c)
    crc = 0xFFFFFFFF
    with open(path, 'rb') as f:
        while True:
            b = f.read(1 << 20)
            if not b:
                break
            # local binds = menos lookup por byte (80 MB de sparse)
            tb = t
            for x in b:
                crc = ((crc << 8) & 0xffffffff) ^ tb[((crc >> 24) ^ x) & 0xff]
    return crc


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


def meta_cmds(path, meta):
    """Comandos debugfs para carimbar mode/uid/gid + security.selinux.
    mode com S_IFREG; selinux com NUL terminal (\\000) como no stock (34 bytes)."""
    se = meta['selinux']
    mode_sif = sif_mode_value(meta['mode'])
    return (
        f"sif {path} mode {mode_sif}\n"
        f"sif {path} uid {meta['uid']}\n"
        f"sif {path} gid {meta['gid']}\n"
        f"ea_set {path} security.selinux {se}\\000\n"
    )


def verify_meta(img, path, expected):
    """Confere type=regular, mode/uid/gid/selinux; aborta se group/world-writable."""
    got = read_meta(img, path, allow_fallback=False)
    mode_int = int(got['mode'], 8)
    if mode_int & 0o022:
        raise SystemExit(
            f"ERRO: {path} mode={got['mode']} e group/world-writable "
            f"(init do Android recusa .rc assim). Abortando."
        )
    ftype = (got.get('type') or '').lower()
    if 'regular' not in ftype:
        raise SystemExit(
            f"ERRO: {path} Type={got.get('type')!r} (esperado regular). "
            f"Provavel sif mode sem S_IFREG."
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
        raise SystemExit(f"ERRO: metadados de {path} divergem do stock: " + "; ".join(errs))
    return got


def main():
    stock, zy, out = sys.argv[1], sys.argv[2], sys.argv[3]
    tmp = tempfile.mkdtemp(prefix='pflbin_')
    try:
        # 1) size do payload vendor + extrai o sparse
        with open(stock, 'rb') as f:
            f.seek(PFX)
            size = struct.unpack('>I', f.read(4))[0]
            f.seek(PFX + 8)
            open(f'{tmp}/vendor.img', 'wb').write(f.read(size))
        print(f"[1] vendor sparse extraido: {size} bytes")

        # 2) expande para ext4 raw
        blk, total, chunks = sparse.expand(f'{tmp}/vendor.img', f'{tmp}/orig.raw')
        shutil.copy(f'{tmp}/orig.raw', f'{tmp}/edit.raw')

        # 2b) captura metadados STOCK dos 3 alvos (antes de sobrescrever)
        stock_meta = {}
        print("[2b] metadados stock:")
        for p in TARGET_PATHS:
            stock_meta[p] = read_meta(f'{tmp}/orig.raw', p)
            m = stock_meta[p]
            print(f"     {p}: mode={m['mode']} uid={m['uid']} gid={m['gid']} selinux={m['selinux']}")

        # 3) prepara build.prop e init.bigfish.rc a partir do proprio stock
        dump(f'{tmp}/orig.raw', '/build.prop', f'{tmp}/bp')
        open(f'{tmp}/bp.mod', 'w').write(
            open(f'{tmp}/bp').read().replace('wifi_disconnect_on_boot=1', 'wifi_disconnect_on_boot=0'))
        dump(f'{tmp}/orig.raw', '/etc/init/hw/init.bigfish.rc', f'{tmp}/rc')
        rc = open(f'{tmp}/rc').read()
        marker = 'service xiriservice /system/bin/xiriservice\n'
        if marker in rc and 'disabled' not in rc.split(marker, 1)[1][:40]:
            rc = rc.replace(marker, marker + '    disabled\n', 1)
        open(f'{tmp}/rc.mod', 'w').write(rc)

        # 4) edita os 3 arquivos via debugfs + restaura metadados do stock
        #    Timestamps FIXOS (determinismo).
        MT, CT = '20191231210000', '20081231140000'   # mtime / (ctime=atime=crtime)

        def edit(path, src):
            meta = stock_meta[path]
            return (
                f"rm {path}\nwrite {src} {path}\n"
                f"sif {path} mtime {MT}\nsif {path} ctime {CT}\n"
                f"sif {path} atime {CT}\nsif {path} crtime {CT}\n"
                + meta_cmds(path, meta)
            )

        cmds = f'{tmp}/cmds'
        open(cmds, 'w').write(
            edit('/etc/ZYCustom.ini', zy)
            + edit('/build.prop', f'{tmp}/bp.mod')
            + edit('/etc/init/hw/init.bigfish.rc', f'{tmp}/rc.mod'))
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
        open(cmds2, 'w').write(''.join(meta_cmds(p, stock_meta[p]) for p in TARGET_PATHS))
        dfs(f'{tmp}/edit.raw', cmds2)

        # Gate fatal: metadados == stock; nenhum .rc group-writable
        print("[4b] verificando metadados pos-edit:")
        for p in TARGET_PATHS:
            got = verify_meta(f'{tmp}/edit.raw', p, stock_meta[p])
            print(f"     OK {p}: mode={got['mode']} selinux={got['selinux']}")

        # determinismo: o debugfs/e2fsck carimbam s_wtime e s_lastcheck
        FIXED = struct.pack('<I', 0x5e0be100)   # 2019-12-31, mesma era do stock
        with open(f'{tmp}/edit.raw', 'r+b') as f:
            f.seek(1024 + 0x30)
            f.write(FIXED)   # s_wtime
            f.seek(1024 + 0x40)
            f.write(FIXED)   # s_lastcheck
        print("[4] 3 arquivos + metadados stock + e2fsck + superbloco fixado")

        # 5) re-empacota sparse a partir do raw editado.
        #    (ea_set aloca blocos de xattr que caem em chunks dontcare do sparse
        #    original — patch in-place nao basta. Pack + pad ate o size stock
        #    mantem a tabela LOAD e o checksum1 inalterados.)
        psz, nch, ptotal = sparse.pack(f'{tmp}/edit.raw', f'{tmp}/vendor.new', blk=blk)
        if ptotal != total:
            raise SystemExit(f"ERRO: total_blocks pack={ptotal} != stock={total}")
        if psz > size:
            raise SystemExit(
                f"ERRO: sparse empacotado ({psz}) maior que o slot stock ({size}). "
                "Precisaria realocar a tabela LOAD — abortado.")
        if psz < size:
            with open(f'{tmp}/vendor.new', 'ab') as n:
                n.write(b'\x00' * (size - psz))
            print(f"[5] sparse pack: {psz} bytes, {nch} chunks; pad +{size - psz} -> {size}")
        else:
            print(f"[5] sparse pack: {psz} bytes, {nch} chunks (size exato)")
        assert os.path.getsize(f'{tmp}/vendor.new') == size

        # round-trip: expandir de novo e revalidar metadados (pad zeros nao altera raw)
        sparse.expand(f'{tmp}/vendor.new', f'{tmp}/check.raw')
        print("[5b] revalidacao pos-pack:")
        for p in TARGET_PATHS:
            got = verify_meta(f'{tmp}/check.raw', p, stock_meta[p])
            print(f"     OK {p}: mode={got['mode']} type={got.get('type')} "
                  f"selinux={got['selinux']}")

        # round-trip do conteudo: as trocas do wifi e do xiri tem de estar na imagem final
        # (o replace/insert acima falha em silencio se o stock nao tiver o texto procurado)
        def conteudo(path):
            alvo = f'{tmp}/chk_conteudo'
            if os.path.exists(alvo):
                os.remove(alvo)
            dump(f'{tmp}/check.raw', path, alvo)
            return open(alvo, encoding='utf-8').read() if os.path.exists(alvo) else ''

        bp_final = conteudo('/build.prop')
        if bp_final != open(f'{tmp}/bp.mod').read() or 'wifi_disconnect_on_boot=0' not in bp_final \
                or 'wifi_disconnect_on_boot=1' in bp_final:
            raise SystemExit("ERRO: /build.prop final sem a troca wifi_disconnect_on_boot=0 - abortado.")
        rc_final = conteudo('/etc/init/hw/init.bigfish.rc')
        if rc_final != open(f'{tmp}/rc.mod').read() or marker not in rc_final \
                or 'disabled' not in rc_final.split(marker, 1)[1][:40]:
            raise SystemExit("ERRO: init.bigfish.rc final sem o 'disabled' do xiriservice - abortado.")
        print("[5c] conteudo final conferido: wifi_disconnect_on_boot=0 e xiriservice disabled")

        # 6) CRC novo da particao (sobre os `size` bytes do sparse, incl. pad)
        newcrc = crc32_mpeg2(f'{tmp}/vendor.new')
        print(f"[6] CRC vendor novo: 0x{newcrc:08x}")

        # 7) monta a saida (mesmo tamanho do stock; so payload vendor muda)
        shutil.copy(stock, out)
        vnew = open(f'{tmp}/vendor.new', 'rb').read()
        with open(out, 'r+b') as f:
            f.seek(PFX + 8)
            f.write(vnew)
            f.seek(PFX + 4)
            f.write(struct.pack('>I', newcrc))

        # 8) verifica checksum1 (deve ficar inalterado — tabela intacta)
        with open(out, 'rb') as f:
            hdr = bytearray(f.read(0x2b4))
        stored1 = struct.unpack('>I', hdr[4:8])[0]
        hdr[4:8] = b'\x00\x00\x00\x00'
        c1 = crc_header(hdr)
        ok = (c1 == stored1) and (os.path.getsize(out) == os.path.getsize(stock))
        print(f"[8] checksum1 @0x04 = 0x{c1:08x} (armazenado 0x{stored1:08x}) -> "
              f"{'OK' if c1 == stored1 else 'ERRO'}")
        if not ok:
            raise SystemExit(f"[done] {out}  FALHOU (checksum1 ou tamanho)")
        print(f"[done] {out}  VALIDO (conteudo + metadados stock nos 3 arquivos)")
        print("       AVISO: ainda teste em hardware com pendrive de resgate oficial ao lado.")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == '__main__':
    if len(sys.argv) != 4:
        print("uso: build_fix_bin.py <stock.bin> <ZYCustom.ini> <saida.bin>")
        sys.exit(1)
    main()
