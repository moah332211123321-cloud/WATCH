"""Minimal stdlib readers for resources.arsc string tables and binary AndroidManifest.xml. Bytes only.
python -I androidres.py strings <resources.arsc> <out.tsv>     -> locale<TAB>name<TAB>value
python -I androidres.py manifest <AndroidManifest.xml> <out.txt> -> element<TAB>android:name (+ a few attrs)
"""
import struct, sys

def pool(b, o):
    typ, hsz, size, cnt, scnt, flags, sstart, _ = struct.unpack_from('<HHIIIIII', b, o)
    utf8 = flags & 0x100
    offs = struct.unpack_from(f'<{cnt}I', b, o + hsz)
    base = o + sstart; out = []
    for off in offs:
        p = base + off
        if utf8:
            n = b[p]; p += 2 if n & 0x80 else 1
            n = b[p];
            if n & 0x80: n = ((n & 0x7f) << 8) | b[p + 1]; p += 2
            else: p += 1
            out.append(b[p:p + n].decode('utf-8', 'replace'))
        else:
            n = struct.unpack_from('<H', b, p)[0]; p += 2
            if n & 0x8000: n = ((n & 0x7fff) << 16) | struct.unpack_from('<H', b, p)[0]; p += 2
            out.append(b[p:p + 2 * n].decode('utf-16-le', 'replace'))
    return out

def locale(cfg):
    lang, country = cfg[8:10], cfg[10:12]
    l = lang.decode('latin1').strip('\0') if lang[0] < 0x80 else '?'
    c = country.decode('latin1').strip('\0') if country[0] < 0x80 else ''
    return (l + ('-' + c if c else '')) or 'default'

def arsc(path, out):
    b = open(path, 'rb').read()
    _, hsz, size, npk = struct.unpack_from('<HHII', b, 0)
    o = hsz; gpool = None
    rows = []
    while o < size:
        typ, h, sz = struct.unpack_from('<HHI', b, o)
        if typ == 0x0001: gpool = pool(b, o)
        elif typ == 0x0200:
            typestr_off, _, keystr_off = struct.unpack_from('<III', b, o + 268)
            types = pool(b, o + typestr_off); keys = pool(b, o + keystr_off)
            p = o + h
            while p < o + sz:
                t2, h2, s2 = struct.unpack_from('<HHI', b, p)
                if t2 == 0x0201:
                    tid = b[p + 8]; flags = b[p + 9]
                    n, start = struct.unpack_from('<II', b, p + 12)
                    cfg = b[p + 20:p + 20 + struct.unpack_from('<I', b, p + 20)[0]]
                    if types[tid - 1] == 'string':
                        loc = locale(cfg)
                        sparse = flags & 1
                        for i in range(n):
                            if sparse:
                                idx, eo = struct.unpack_from('<HH', b, p + h2 + 4 * i); eo *= 4
                            else:
                                eo = struct.unpack_from('<I', b, p + h2 + 4 * i)[0]
                                if eo == 0xffffffff: continue
                            e = p + start + eo
                            esz, ef, key = struct.unpack_from('<HHI', b, e)
                            if ef & 1: continue
                            vt, vd = b[e + esz + 3], struct.unpack_from('<I', b, e + esz + 4)[0]
                            if vt == 3:
                                rows.append((loc, keys[key], gpool[vd]))
                p += s2
        o += sz
    with open(out, 'w', encoding='utf-8') as f:
        for r in rows: f.write('\t'.join(x.replace('\n', '\\n').replace('\t', ' ') for x in r) + '\n')
    print(len(rows), 'string rows')

def manifest(path, out):
    b = open(path, 'rb').read()
    o = 8; strs = []
    lines = []
    while o < len(b):
        typ, h, sz = struct.unpack_from('<HHI', b, o)
        if typ == 0x0001: strs = pool(b, o)
        elif typ == 0x0102:
            name = strs[struct.unpack_from('<I', b, o + 20)[0]]
            astart, asz, acnt = struct.unpack_from('<HHH', b, o + 24)
            attrs = {}
            for i in range(acnt):
                a = o + 16 + astart + i * asz
                ns, an, raw, _, _, dt, dv = struct.unpack_from('<IIIHBBI', b, a)
                k = strs[an]
                v = strs[raw] if raw != 0xffffffff else (strs[dv] if dt == 3 else dv)
                attrs[k] = v
            keep = {k: attrs[k] for k in ('name', 'exported', 'label', 'scheme', 'host', 'value', 'resource') if k in attrs}
            lines.append(name + '\t' + '\t'.join(f'{k}={v}' for k, v in keep.items()))
        o += sz
    with open(out, 'w', encoding='utf-8') as f: f.write('\n'.join(lines) + '\n')
    print(len(lines), 'elements')

if __name__ == '__main__':
    {'strings': arsc, 'manifest': manifest}[sys.argv[1]](sys.argv[2], sys.argv[3])
