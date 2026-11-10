"""Rebuild byte-array templates per method by tracking consts and aput-byte. Bytes only, no execution.
python -I tmpl.py <dex_dir> <class_prefix>..."""
import sys, os, glob, struct
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.stdout.reconfigure(encoding='utf-8')
from dexdump import Dex
from dexasm import code_items, insns

def run(d, co):
    R = {}; arrays = {}; order = []; labels = []
    for pc, op, w, at, u in insns(d, co):
        A, B, AA = (w >> 8) & 0xf, w >> 12, w >> 8
        if op == 0x12: R[A] = (B - 16 if B > 7 else B)
        elif op in (0x13,): R[AA] = struct.unpack_from('<h', d.b, at + 2)[0]
        elif op == 0x14: R[AA] = struct.unpack_from('<i', d.b, at + 2)[0]
        elif op == 0x15: R[AA] = u(pc + 1) << 16
        elif op in (0x01, 0x04, 0x07): R[A] = R.get(B)
        elif op in (0x02, 0x05, 0x08): R[AA] = R.get(u(pc + 1))
        elif op == 0x1a: R[AA] = ('s', d.strings[u(pc + 1)]); labels.append(d.strings[u(pc + 1)])
        elif op == 0x23:
            n = R.get(B)
            key = ('arr', len(order)); order.append([n if isinstance(n, int) else None, {}])
            R[A] = key
        elif op == 0x26:
            off = struct.unpack_from('<i', d.b, at + 2)[0]; p = at + off * 2
            ew, cnt = struct.unpack_from('<HI', d.b, p + 2)
            k = R.get(AA)
            if isinstance(k, tuple) and k[0] == 'arr' and ew == 1:
                for i, x in enumerate(d.b[p + 8:p + 8 + cnt]): order[k[1]][1][i] = x
        elif op == 0x4f:  # aput-byte vAA, vBB[vCC]
            g = u(pc + 1); arr, idx = R.get(g & 0xff), R.get(g >> 8)
            if isinstance(arr, tuple) and arr[0] == 'arr' and isinstance(idx, int):
                v = R.get(AA)
                order[arr[1]][1][idx] = (v & 0xff) if isinstance(v, int) else None
        elif 0x0a <= op <= 0x0c: R[AA] = None
        elif op == 0x8d: R[A] = (R[B] & 0xff) if isinstance(R.get(B), int) else None
        elif op in (0x44,0x45,0x46,0x47,0x48,0x49,0x4a, 0x52,0x53,0x54,0x55,0x56,0x57,0x58,0x60,0x61,0x62,0x63,0x64,0x65,0x66, 0x1f):
            if op >= 0x52 and op < 0x60: R[A] = None
            elif op != 0x1f: R[AA] = None
        elif 0x7b <= op <= 0x8f or 0xb0 <= op <= 0xcf: R[A] = None
        elif 0x90 <= op <= 0xaf or 0xd8 <= op <= 0xe2: R[AA] = None
        elif 0xd0 <= op <= 0xd7: R[A] = None
        elif op == 0x22: R[AA] = None
    return order, labels

def show(arr):
    n, m = arr
    if not m: return 'dynamic (built with helpers/streams)'
    size = n if n is not None else (max(m) + 1 if m else 0)
    return ' '.join((f'{m[i]:02x}' if isinstance(m[i], int) else '??') if i in m else '00' for i in range(size)) + ('' if n is not None else ' (dyn size)')

for p in sorted(glob.glob(os.path.join(sys.argv[1], 'classes*.dex'))):
    d = Dex(p)
    for cls, ms in code_items(d):
        if not cls.startswith(tuple(sys.argv[2:])): continue
        for name, co in ms:
            if not co: continue
            order, labels = run(d, co)
            arrs = [a for a in order if a[1] and a[1].get(0) in (0xab, 0xea)][:1]
            uses = any(op in (0x70, 0x76) and d.methods[u(pc + 1)][0] == 'Lcom/wakeup/commponent/module/ble/BleOrderModel;' for pc, op, w, at, u in insns(d, co))
            if uses and not arrs: arrs = [[0, {}]]
            if arrs:
                lab = [l for l in labels if any(ord(c) > 0x2e80 for c in l)]
                for a in arrs:
                    print(f'{cls[1:-1].split("/")[-1]}.{name}\t{show(a)}\t{"|".join(lab[:2])}')
