"""Minimal stdlib DEX reader: dumps strings, classes (fields/methods/static final values).
Usage: python -I dexdump.py <dex_dir> <out_dir>
Never executes target code; only parses bytes."""
import struct, sys, os, json, glob

def uleb(b, o):
    r = s = 0
    while True:
        x = b[o]; o += 1
        r |= (x & 0x7f) << s; s += 7
        if x < 0x80: return r, o

def mutf8(b, o):
    _, o = uleb(b, o)
    e = b.index(0, o)
    return b[o:e].decode('utf-8', 'replace')

class Dex:
    def __init__(s, path):
        b = s.b = open(path, 'rb').read()
        h = struct.unpack_from('<8s I 20s 20I', b, 0)
        f = h[3:]
        (fsz, hsz, endian, lsz, loff, moff, sidsz, sidoff, tidsz, tidoff,
         pidsz, pidoff, fidsz, fidoff, midsz, midoff, cdsz, cdoff, dsz, doff) = f
        s.strings = [mutf8(b, struct.unpack_from('<I', b, sidoff + 4 * i)[0]) for i in range(sidsz)]
        s.types = [s.strings[struct.unpack_from('<I', b, tidoff + 4 * i)[0]] for i in range(tidsz)]
        s.fields = []
        for i in range(fidsz):
            c, t, n = struct.unpack_from('<HHI', b, fidoff + 8 * i)
            s.fields.append((s.types[c], s.types[t], s.strings[n]))
        s.methods = []
        for i in range(midsz):
            c, p, n = struct.unpack_from('<HHI', b, midoff + 8 * i)
            s.methods.append((s.types[c], s.strings[n]))
        s.cdoff, s.cdsz = cdoff, cdsz

    def ev(s, o):
        b = s.b; a = b[o]; o += 1
        t, arg = a & 0x1f, a >> 5
        n = arg + 1
        if t in (0x00, 0x02, 0x03, 0x04, 0x06):  # byte short char int long
            raw = b[o:o + n]; o += n
            v = int.from_bytes(raw, 'little', signed=t != 0x03)
            return v, o
        if t in (0x10, 0x11):
            raw = b[o:o + n]; o += n
            sz = 4 if t == 0x10 else 8
            raw = raw.ljust(sz, b'\0') if False else (b'\0' * (sz - n) + raw)
            return struct.unpack('<f' if sz == 4 else '<d', raw)[0], o
        if t == 0x17:
            v = int.from_bytes(b[o:o + n], 'little'); o += n
            return s.strings[v], o
        if t in (0x15, 0x16, 0x18, 0x19, 0x1a, 0x1b):
            v = int.from_bytes(b[o:o + n], 'little'); o += n
            return f'<idx{t:x}:{v}>', o
        if t == 0x1c:
            c, o = uleb(b, o); out = []
            for _ in range(c):
                v, o = s.ev(o); out.append(v)
            return out, o
        if t == 0x1d:
            _, o = uleb(b, o); c, o = uleb(b, o)
            for _ in range(c):
                _, o = uleb(b, o); _, o = s.ev(o)
            return '<annotation>', o
        if t == 0x1e: return None, o
        if t == 0x1f: return bool(arg), o
        raise ValueError(f'bad value type {t:x}')

    def classes(s):
        b = s.b
        for i in range(s.cdsz):
            (ci, acc, sup, ifo, srcf, anno, cdat, sval) = struct.unpack_from('<8I', b, s.cdoff + 32 * i)
            name = s.types[ci]
            sup_n = s.types[sup] if sup != 0xffffffff else None
            ifaces = []
            if ifo:
                n = struct.unpack_from('<I', b, ifo)[0]
                ifaces = [s.types[struct.unpack_from('<H', b, ifo + 4 + 2 * k)[0]] for k in range(n)]
            sf, inf, dm, vm = [], [], [], []
            if cdat:
                o = cdat
                a, o = uleb(b, o); c2, o = uleb(b, o); d, o = uleb(b, o); v, o = uleb(b, o)
                for lst, cnt, tbl in ((sf, a, s.fields), (inf, c2, s.fields)):
                    idx = 0
                    for _ in range(cnt):
                        di, o = uleb(b, o); _, o = uleb(b, o); idx += di
                        lst.append(tbl[idx])
                for lst, cnt in ((dm, d), (vm, v)):
                    idx = 0
                    for _ in range(cnt):
                        di, o = uleb(b, o); _, o = uleb(b, o); _, o = uleb(b, o); idx += di
                        lst.append(s.methods[idx][1])
            vals = []
            if sval:
                try:
                    n, o = uleb(b, sval)  # encoded_array: size then values, no type byte
                    for _ in range(n):
                        v, o = s.ev(o); vals.append(v)
                except Exception as e:
                    vals = [f'<err {e}>']
            statics = {}
            for k, fld in enumerate(sf):
                statics[fld[2]] = (fld[1], vals[k] if k < len(vals) else None)
            yield dict(name=name, super=sup_n, ifaces=ifaces, statics=statics,
                       ifields=[(f[2], f[1]) for f in inf], methods=sorted(set(dm + vm)))

def main():
    src, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    allstr = set()
    with open(os.path.join(out, 'classes.jsonl'), 'w', encoding='utf-8') as cf:
        for p in sorted(glob.glob(os.path.join(src, 'classes*.dex'))):
            d = Dex(p)
            allstr.update(d.strings)
            for c in d.classes():
                c['dex'] = os.path.basename(p)
                cf.write(json.dumps(c, ensure_ascii=False, default=str) + '\n')
    with open(os.path.join(out, 'strings.txt'), 'w', encoding='utf-8') as sf:
        for x in sorted(allstr):
            sf.write(x.replace('\n', '\\n') + '\n')

if __name__ == '__main__':
    main()
