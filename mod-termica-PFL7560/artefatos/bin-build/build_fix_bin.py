#!/usr/bin/env python3
# ============================================================================
#  build_fix_bin.py - reconstroi o PFL7560.bin com a correcao embutida.
#
#  Edita SO a particao vendor (record 14) mantendo o tamanho do payload, para
#  que o checksum1 do container ("LOAD") continue valido; recalcula apenas o
#  CRC-32/MPEG-2 daquela particao. Ver mod-termica-PFL7560/15-bin-definitivo.md.
#
#  Requisitos: python3, debugfs, e2fsck (e2fsprogs). Precisa de sparse.py ao lado.
#  Uso:
#    python3 build_fix_bin.py <stock_PFL7560.bin> <ZYCustom.ini_modificado> <saida.bin>
# ============================================================================
import sys, os, struct, shutil, subprocess, tempfile
import sparse

PFX = 0x4b0b1d54                      # prefixo [size BE][crc BE] da particao vendor
CRC_POLY = 0x04C11DB7

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
            for x in b:
                crc = ((crc << 8) & 0xffffffff) ^ t[((crc >> 24) ^ x) & 0xff]
    return crc

def crc_header(buf):
    crc = 0xFFFFFFFF
    for x in buf:
        crc ^= (x << 24); crc &= 0xffffffff
        for _ in range(8):
            crc = ((crc << 1) ^ CRC_POLY) & 0xffffffff if (crc & 0x80000000) else (crc << 1) & 0xffffffff
    return crc

def dfs(img, cmds):
    subprocess.run(['debugfs', '-w', '-f', cmds, img],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)

def dump(img, path, out):
    subprocess.run(['debugfs', '-R', f'dump {path} {out}', img],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)

def main():
    stock, zy, out = sys.argv[1], sys.argv[2], sys.argv[3]
    tmp = tempfile.mkdtemp(prefix='pflbin_')
    # 1) size do payload vendor + extrai o sparse
    with open(stock, 'rb') as f:
        f.seek(PFX); size = struct.unpack('>I', f.read(4))[0]
        f.seek(PFX + 8); open(f'{tmp}/vendor.img', 'wb').write(f.read(size))
    print(f"[1] vendor sparse extraido: {size} bytes")
    # 2) expande para ext4 raw
    blk, total, chunks = sparse.expand(f'{tmp}/vendor.img', f'{tmp}/orig.raw')
    shutil.copy(f'{tmp}/orig.raw', f'{tmp}/edit.raw')
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
    # 4) edita os 3 arquivos via debugfs (mantem contagem de blocos).
    #    Timestamps FIXOS (determinismo: o debugfs write carimba a hora atual;
    #    fixamos batendo com a convencao do stock -> build byte-reproduzivel).
    MT, CT = '20191231210000', '20081231140000'   # mtime / (ctime=atime=crtime)
    def edit(path, src):
        return (f"rm {path}\nwrite {src} {path}\n"
                f"sif {path} mtime {MT}\nsif {path} ctime {CT}\n"
                f"sif {path} atime {CT}\nsif {path} crtime {CT}\n")
    cmds = f'{tmp}/cmds'
    open(cmds, 'w').write(
        edit('/etc/ZYCustom.ini', zy)
        + edit('/build.prop', f'{tmp}/bp.mod')
        + edit('/etc/init/hw/init.bigfish.rc', f'{tmp}/rc.mod'))
    dfs(f'{tmp}/edit.raw', cmds)
    subprocess.run(['e2fsck', '-fy', f'{tmp}/edit.raw'],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    # determinismo: o debugfs/e2fsck carimbam s_wtime (superbloco+0x30) e
    # s_lastcheck (+0x40) com a hora atual. Sem metadata_csum, fixamos direto.
    FIXED = struct.pack('<I', 0x5e0be100)   # 2019-12-31, mesma era do stock
    with open(f'{tmp}/edit.raw', 'r+b') as f:
        f.seek(1024 + 0x30); f.write(FIXED)   # s_wtime
        f.seek(1024 + 0x40); f.write(FIXED)   # s_lastcheck
    print("[4] 3 arquivos substituidos + e2fsck + superbloco fixado")
    # 5) patch in-place no sparse: so blocos alterados, todos devem ser RAW
    bmap = sparse.block_map(blk, chunks)
    shutil.copy(f'{tmp}/vendor.img', f'{tmp}/vendor.new')
    o = open(f'{tmp}/orig.raw', 'rb'); e = open(f'{tmp}/edit.raw', 'rb'); n = open(f'{tmp}/vendor.new', 'r+b')
    nch = 0
    for i in range(total):
        a = o.read(blk); b = e.read(blk)
        if a != b:
            typ = bmap.get(i, (None,))
            if typ[0] != 'raw':
                raise SystemExit(f"ERRO: bloco {i} alterado esta fora de chunk RAW ({typ}); "
                                 "tamanho mudaria - build abortado.")
            n.seek(typ[1]); n.write(b); nch += 1
    o.close(); e.close(); n.close()
    assert os.path.getsize(f'{tmp}/vendor.new') == size, "tamanho do sparse mudou!"
    print(f"[5] patch in-place: {nch} blocos, tamanho preservado ({size})")
    # 6) CRC novo da particao
    newcrc = crc32_mpeg2(f'{tmp}/vendor.new')
    print(f"[6] CRC vendor novo: 0x{newcrc:08x}")
    # 7) monta a saida
    shutil.copy(stock, out)
    vnew = open(f'{tmp}/vendor.new', 'rb').read()
    with open(out, 'r+b') as f:
        f.seek(PFX + 8); f.write(vnew)
        f.seek(PFX + 4); f.write(struct.pack('>I', newcrc))
    # 8) verifica checksum1 (deve ficar inalterado)
    with open(out, 'rb') as f:
        hdr = bytearray(f.read(0x2b4))
    stored1 = struct.unpack('>I', hdr[4:8])[0]; hdr[4:8] = b'\x00\x00\x00\x00'
    c1 = crc_header(hdr)
    ok = (c1 == stored1) and (os.path.getsize(out) == os.path.getsize(stock))
    print(f"[8] checksum1 @0x04 = 0x{c1:08x} (armazenado 0x{stored1:08x}) -> {'OK' if c1==stored1 else 'ERRO'}")
    print(f"[done] {out}  {'VALIDO' if ok else 'FALHOU'}")
    shutil.rmtree(tmp, ignore_errors=True)

if __name__ == '__main__':
    if len(sys.argv) != 4:
        print(__doc__ or "uso: build_fix_bin.py <stock.bin> <ZYCustom.ini> <saida.bin>"); sys.exit(1)
    main()
