"""Smali-lite disassembler built on dexdump.Dex. Parses bytes only, never runs target code.
python -I dexasm.py index <dex_dir> <out_file>          -> 'class<TAB>const-string' for every class
python -I dexasm.py dump  <dex_dir> <out_dir> <prefix>... -> one listing per class whose name starts with a prefix
"""
import sys, os, glob, struct
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dexdump import Dex, uleb

L = {}
for op in range(256):
    L[op] = 1
for ops, n in [((0x02, 0x05, 0x08, 0x13, 0x15, 0x16, 0x19, 0x1a, 0x1c, 0x1f, 0x20, 0x22, 0x23, 0x29, 0xfe, 0xff), 2),
               ((0x03, 0x06, 0x09, 0x14, 0x17, 0x1b, 0x24, 0x25, 0x26, 0x2a, 0x2b, 0x2c, 0xfc, 0xfd), 3),
               ((0x18,), 5), ((0xfa, 0xfb), 4)]:
    for o in ops: L[o] = n
for r, n in [((0x2d, 0x38), 2), ((0x38, 0x3e), 2), ((0x44, 0x6e), 2), ((0x6e, 0x73), 3), ((0x74, 0x79), 3),
             ((0x90, 0xb0), 2), ((0xd0, 0xe3), 2)]:
    for o in range(*r): L[o] = n

INV = {0x6e: 'virtual', 0x6f: 'super', 0x70: 'direct', 0x71: 'static', 0x72: 'interface',
       0x74: 'virtual', 0x75: 'super', 0x76: 'direct', 0x77: 'static', 0x78: 'interface'}
FOPS = {**{o: 'iget' for o in range(0x52, 0x59)}, **{o: 'iput' for o in range(0x59, 0x60)},
        **{o: 'sget' for o in range(0x60, 0x67)}, **{o: 'sput' for o in range(0x67, 0x6e)}}
IF = {0x32: '==', 0x33: '!=', 0x34: '<', 0x35: '>=', 0x36: '>', 0x37: '<='}
BIN = ['add', 'sub', 'mul', 'div', 'rem', 'and', 'or', 'xor', 'shl', 'shr', 'ushr']

def code_items(d):
    b = d.b
    for i in range(d.cdsz):
        ci, *_, cdat, sval = struct.unpack_from('<8I', b, d.cdoff + 32 * i)
        if not cdat: continue
        o = cdat
        a, o = uleb(b, o); c, o = uleb(b, o); dm, o = uleb(b, o); vm, o = uleb(b, o)
        for _ in range(a + c):
            _, o = uleb(b, o); _, o = uleb(b, o)
        ms = []
        for cnt in (dm, vm):
            idx = 0
            for _ in range(cnt):
                di, o = uleb(b, o); _, o = uleb(b, o); co, o = uleb(b, o); idx += di
                ms.append((d.methods[idx][1], co))
        yield d.types[ci], ms

def insns(d, co):
    b = d.b
    regs, ins, outs, tries, dbg, n = struct.unpack_from('<HHHHII', b, co)
    base = co + 16
    u = lambda k: struct.unpack_from('<H', b, base + 2 * k)[0]
    pc = 0
    while pc < n:
        w = u(pc); op = w & 0xff
        if op == 0 and w in (0x100, 0x200, 0x300):  # payloads
            if w == 0x100: sz = u(pc + 1); ln = sz * 2 + 4
            elif w == 0x200: sz = u(pc + 1); ln = sz * 4 + 2
            else:
                ew = u(pc + 1); cnt = struct.unpack_from('<I', b, base + 2 * pc + 4)[0]
                ln = (ew * cnt + 1) // 2 + 4
            pc += ln; continue
        yield pc, op, w, base + 2 * pc, u
        pc += L[op]

def fmt(d, pc, op, w, at, u):
    b = d.b
    A, B = (w >> 8) & 0xf, w >> 12
    AA = w >> 8
    if op == 0x12: v = B - 16 if B > 7 else B; return f'v{A} = {v} (0x{v & 0xff:x})'
    if op in (0x13, 0x16): v = struct.unpack_from('<h', b, at + 2)[0]; return f'v{AA} = {v} (0x{v & 0xffff:x})'
    if op in (0x14, 0x17): v = struct.unpack_from('<i', b, at + 2)[0]; return f'v{AA} = {v} (0x{v & 0xffffffff:x})'
    if op == 0x15: return f'v{AA} = 0x{u(pc + 1) << 16:x}'
    if op == 0x18: v = struct.unpack_from('<q', b, at + 2)[0]; return f'v{AA} = {v}L'
    if op == 0x1a: return f'v{AA} = "{d.strings[u(pc + 1)]}"'
    if op == 0x1b: return f'v{AA} = "{d.strings[struct.unpack_from("<I", b, at + 2)[0]]}"'
    if op == 0x1c: return f'v{AA} = class {d.types[u(pc + 1)]}'
    if op == 0x22: return f'v{AA} = new {d.types[u(pc + 1)]}'
    if op == 0x23: return f'v{A} = new {d.types[u(pc + 1)]}[v{B}]'
    if op == 0x26:
        off = struct.unpack_from('<i', b, at + 2)[0]
        p = at + off * 2
        ew = struct.unpack_from('<H', b, p + 2)[0]; cnt = struct.unpack_from('<I', b, p + 4)[0]
        data = b[p + 8:p + 8 + ew * cnt]
        if ew == 1: vals = ' '.join(f'{x:02x}' for x in data[:256])
        else: vals = ' '.join(str(int.from_bytes(data[k:k + ew], 'little', signed=True)) for k in range(0, min(len(data), 256 * ew), ew))
        return f'v{AA} fill[{ew}x{cnt}] {vals}'
    if op in INV or op in (0x24, 0x25):
        m = d.methods[u(pc + 1)] if op not in (0x24, 0x25) else (d.types[u(pc + 1)], 'filled-new-array')
        if op >= 0x74 or op == 0x25:
            c = u(pc + 2); args = f'v{c}..v{c + AA - 1}'
        else:
            cnt = B; g = u(pc + 2)
            rs = [g & 0xf, (g >> 4) & 0xf, (g >> 8) & 0xf, (g >> 12) & 0xf, A][:cnt]
            args = ','.join(f'v{r}' for r in rs)
        return f'{INV.get(op, "")} {m[0]}->{m[1]}({args})'
    if op in FOPS:
        f = d.fields[u(pc + 1)]
        reg = f'v{AA}' if op >= 0x60 else f'v{A}, v{B}'
        return f'{FOPS[op]} {reg} {f[0]}->{f[2]}'
    if 0x0a <= op <= 0x0c: return f'v{AA} = result'
    if op in (0x0e, 0x0f, 0x10, 0x11): return 'return' + ('' if op == 0x0e else f' v{AA}')
    if op in IF: return f'if v{A} {IF[op]} v{B} goto +{struct.unpack_from("<h", b, at + 2)[0]}'
    if 0x38 <= op <= 0x3d: return f'if v{AA} {list(IF.values())[op - 0x38]} 0 goto +{struct.unpack_from("<h", b, at + 2)[0]}'
    if op in (0x28, 0x29, 0x2a): return 'goto'
    if op in (0x2b, 0x2c):
        off = struct.unpack_from('<i', b, at + 2)[0]; q = at + off * 2
        n = struct.unpack_from('<H', b, q + 2)[0]
        if op == 0x2b:
            first = struct.unpack_from('<i', b, q + 4)[0]; keys = list(range(first, first + n))
            tg = [struct.unpack_from('<i', b, q + 8 + 4 * k)[0] for k in range(n)]
        else:
            keys = [struct.unpack_from('<i', b, q + 4 + 4 * k)[0] for k in range(n)]
            tg = [struct.unpack_from('<i', b, q + 4 + 4 * n + 4 * k)[0] for k in range(n)]
        return f'switch v{AA} ' + ' '.join(f'0x{k & 0xffffffff:x}->{pc + t:x}' for k, t in zip(keys, tg))
    if 0x44 <= op <= 0x4a: return f'aget v{AA}'
    if 0x4b <= op <= 0x51: g = u(pc + 1); return f'v{g & 0xff}[v{g >> 8}] = v{AA}'
    if 0xd0 <= op <= 0xd7: return f'v{A} = v{B} {BIN[op - 0xd0] if op - 0xd0 < 8 else "?"} {struct.unpack_from("<h", b, at + 2)[0]}'
    if 0xd8 <= op <= 0xe2:
        g = u(pc + 1); lit = struct.unpack('b', bytes([g >> 8]))[0]
        return f'v{AA} = v{g & 0xff} {BIN[op - 0xd8]} {lit} (0x{lit & 0xff:x})'
    if 0x90 <= op <= 0xaf: return f'binop{op:x}'
    if 0xb0 <= op <= 0xcf: return f'binop2addr{op:x} v{A}, v{B}'
    if 0x01 <= op <= 0x09: return None
    return f'op{op:02x}'

def main():
    mode, src = sys.argv[1], sys.argv[2]
    dexes = [Dex(p) for p in sorted(glob.glob(os.path.join(src, 'classes*.dex')))]
    if mode == 'index':
        with open(sys.argv[3], 'w', encoding='utf-8') as f:
            for d in dexes:
                for cls, ms in code_items(d):
                    seen = set()
                    for _, co in ms:
                        if not co: continue
                        for pc, op, w, at, u in insns(d, co):
                            if op == 0x1a: seen.add(d.strings[u(pc + 1)])
                            elif op == 0x1b: seen.add(d.strings[struct.unpack_from('<I', d.b, at + 2)[0]])
                    for s in seen:
                        f.write(cls + '\t' + s.replace('\n', '\\n').replace('\t', ' ') + '\n')
    else:
        out, prefixes = sys.argv[3], tuple(sys.argv[4:])
        os.makedirs(out, exist_ok=True)
        for d in dexes:
            for cls, ms in code_items(d):
                if not cls.startswith(prefixes): continue
                fn = cls[1:-1].replace('/', '.').replace('$', '~')[:180] + '.txt'
                with open(os.path.join(out, fn), 'a', encoding='utf-8') as f:
                    f.write(f'### {cls}\n')
                    for name, co in ms:
                        f.write(f'\n.method {name}\n')
                        if not co: continue
                        for pc, op, w, at, u in insns(d, co):
                            try:
                                t = fmt(d, pc, op, w, at, u)
                            except Exception as e:
                                t = f'<err {e}>'
                            if t: f.write(f'  {pc:4x}: {t}\n')

if __name__ == '__main__':
    main()
