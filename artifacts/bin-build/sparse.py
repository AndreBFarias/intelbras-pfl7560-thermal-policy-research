#!/usr/bin/env python3
import struct
import os

SPARSE_MAGIC = 0xed26ff3a
RAW, FILL, DONTCARE, CRC = 0xCAC1, 0xCAC2, 0xCAC3, 0xCAC4

def parse(path):
    with open(path, 'rb') as f:
        hdr = f.read(28)
        magic, major, minor, fhdr, chdr, blk, total_blocks, total_chunks, crc = \
            struct.unpack('<IHHHHIIII', hdr)
        assert magic == SPARSE_MAGIC, f"magic {magic:#x} nao e sparse"
        assert blk % 4 == 0
        f.seek(fhdr)
        chunks, out_blk = [], 0
        for _ in range(total_chunks):
            ctype, _r, csz, tsz = struct.unpack('<HHII', f.read(12))
            if ctype == RAW:
                off = f.tell(); f.seek(csz * blk, 1)
                chunks.append(('raw', out_blk, csz, off, None))
            elif ctype == FILL:
                fill = struct.unpack('<I', f.read(4))[0]
                chunks.append(('fill', out_blk, csz, None, fill))
            elif ctype == DONTCARE:
                chunks.append(('dontcare', out_blk, csz, None, None))
            elif ctype == CRC:
                f.read(4); chunks.append(('crc', out_blk, 0, None, None)); continue
            else:
                raise Exception(f"chunk desconhecido {ctype:#x}")
            out_blk += csz
    return blk, total_blocks, chunks

def expand(path, outpath):
    blk, total, chunks = parse(path)
    with open(path, 'rb') as f, open(outpath, 'wb') as o:
        for ct, ob, cnt, off, fill in chunks:
            if ct == 'raw':
                f.seek(off); o.write(f.read(cnt * blk))
            elif ct == 'fill':
                o.write(struct.pack('<I', fill) * (cnt * blk // 4))
            elif ct == 'dontcare':
                o.write(b'\x00' * (cnt * blk))
    return blk, total, chunks

def block_map(blk, chunks):
    m = {}
    for ct, ob, cnt, off, fill in chunks:
        if ct == 'crc':
            continue
        for i in range(cnt):
            m[ob + i] = ('raw', off + i * blk) if ct == 'raw' else (ct,)
    return m

def pack(raw_path, out_path, blk=4096):
    import mmap
    size = os.path.getsize(raw_path)
    if size % blk:
        raise ValueError(f"raw size {size} nao multiplo de {blk}")
    total = size // blk
    zero = b'\x00' * blk

    regions = []
    with open(raw_path, 'rb') as f:
        mm = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
        try:
            for i in range(total):
                kind = 'dontcare' if mm[i * blk:(i + 1) * blk] == zero else 'raw'
                if regions and regions[-1][0] == kind:
                    regions[-1][2] += 1
                else:
                    regions.append([kind, i, 1])
        finally:
            mm.close()

    nchunks = len(regions)
    with open(raw_path, 'rb') as f, open(out_path, 'wb') as o:
        mm = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
        try:
            o.write(struct.pack('<IHHHHIIII',
                                SPARSE_MAGIC, 1, 0, 28, 12, blk, total, nchunks, 0))
            for kind, start, cnt in regions:
                if kind == 'raw':
                    data_len = cnt * blk
                    o.write(struct.pack('<HHII', RAW, 0, cnt, 12 + data_len))
                    o.write(mm[start * blk: start * blk + data_len])
                else:
                    o.write(struct.pack('<HHII', DONTCARE, 0, cnt, 12))
        finally:
            mm.close()
    return os.path.getsize(out_path), nchunks, total

if __name__ == '__main__':
    import sys
    blk, total, chunks = parse(sys.argv[1])
    nr = sum(1 for c in chunks if c[0] == 'raw')
    nf = sum(1 for c in chunks if c[0] == 'fill')
    nd = sum(1 for c in chunks if c[0] == 'dontcare')
    print(f"block size={blk} total_blocks={total} chunks={len(chunks)} (raw={nr} fill={nf} dontcare={nd})")
