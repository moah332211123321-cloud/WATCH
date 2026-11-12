"""Turn the user's watch-face files into 240x288 PNG backgrounds for Sawar's photo face.

Inputs:
- WearFit-style `.bin` dials (research/watchface-format.md 3b): u32 LE record count N, N x 20-byte
  records (type, flags, u16, x, y, w, h u16 LE, start, end u32 LE). An image is a RGB565 LE palette
  at [start, end) followed by w*h one-byte palette indices (no compression). Type 0x19 with end 0
  is a photo slot (the user's own picture). Only static parts are drawn: the watch draws the time.
- Apple `.watchface` share files (zip): a photo face's own picture from Resources/, otherwise the
  face snapshot (its hands/time are frozen in the picture; the PNG name says so).

Every output is exactly the target size: near-same aspect is filled, other shapes (round 360x360,
square 240x240) are fitted whole on black. Identical pictures are written once.

usage: python -I dial_bg.py <input folder> <png out folder> [width height]
Writes _report.txt in the out folder with one line per input file.
"""
import hashlib, io, os, struct, sys, zipfile
from PIL import Image, ImageOps


def decode(d, rec):
    t, f, u, x, y, w, h, s, e = rec
    if (e - s) % 2 or not 0 < e - s <= 512 or e + w * h > len(d) or w * h == 0:
        return None
    pal = [struct.unpack_from("<H", d, s + 2 * k)[0] for k in range((e - s) // 2)]
    idx = d[e:e + w * h]
    if max(idx) >= len(pal):
        return None
    im = Image.frombytes("P", (w, h), idx)
    im.putpalette([c for v in pal for c in ((v >> 11) << 3, ((v >> 5) & 63) << 2, (v & 31) << 3)])
    return im.convert("RGB")


def first_frame(im):
    """Animated backgrounds stack frames vertically; keep the first (frame height near 1.2 x width)."""
    w, h = im.size
    if h <= w * 1.4:
        return im
    for fh in sorted(range(int(w * 0.95), int(w * 1.3) + 1), key=lambda v: abs(v - w * 1.2)):
        if h % fh == 0:
            return im.crop((0, 0, w, fh))
    return None


def dial(d):
    """(image, note) or (None, reason)."""
    n = struct.unpack_from("<I", d)[0]
    if not 0 < n < 2000 or 4 + 20 * n > len(d):
        return None, "not a dial file"
    recs = [struct.unpack_from("<BBHHHHHII", d, 4 + 20 * i) for i in range(n)]
    for r in recs:
        if r[3:5] == (0, 0) and r[5] >= 100 and r[6] >= 100:
            if r[0] == 0x19 and r[8] == 0:
                break  # photo slot: background is the user's own picture
            im = decode(d, r)
            im = im and first_frame(im)
            if im:
                return im, ""
            break
    # no usable background: draw the static parts (type 9) on black
    static = [r for r in recs if r[0] == 0x09 and r[6] <= 400]
    if not static:
        return None, "only live parts (digits/hands/photo slot), nothing fixed to draw"
    W = max(r[3] + r[5] for r in static); H = max(r[4] + r[6] for r in static)
    W, H = (360, 360) if max(W, H) > 300 else (240, 288)
    canvas = Image.new("RGB", (W, H))
    drawn = 0
    for r in static:
        im = decode(d, r)
        if im:
            canvas.paste(im, (r[3], r[4])); drawn += 1
    return (canvas, "static parts on black") if drawn else (None, "unknown image encoding")


def watchface(path):
    z = zipfile.ZipFile(path)
    names = z.namelist()
    photo = [n for n in names if n.startswith("Resources/") and n.lower().endswith((".jpg", ".jpeg", ".png"))]
    if photo:
        return Image.open(io.BytesIO(z.read(photo[0]))).convert("RGB"), ""
    snap = next((n for n in ("no_borders_snapshot.png", "snapshot.png") if n in names), None)
    if snap:
        return Image.open(io.BytesIO(z.read(snap))).convert("RGB"), "fixed-time"
    return None, "no picture inside"


def fit(im, W, H):
    if abs(im.width / im.height - W / H) < 0.06:
        return ImageOps.fit(im, (W, H), Image.LANCZOS)
    out = Image.new("RGB", (W, H))
    small = ImageOps.contain(im, (W, H), Image.LANCZOS)
    out.paste(small, ((W - small.width) // 2, (H - small.height) // 2))
    return out


def main(src, dst, W=240, H=288):
    os.makedirs(dst, exist_ok=True)
    seen, report, made = {}, [], 0
    for fn in sorted(os.listdir(src)):
        path = os.path.join(src, fn)
        if fn.endswith(".bin"):
            try:
                im, note = dial(open(path, "rb").read())
            except (struct.error, ValueError) as e:
                im, note = None, f"broken file ({e})"
        elif fn.endswith(".watchface"):
            try:
                im, note = watchface(path)
            except (zipfile.BadZipFile, OSError) as e:
                im, note = None, f"broken file ({e})"
        else:
            continue
        if im is None:
            report.append(f"{fn}\tSKIPPED\t{note}"); continue
        size = f"{im.width}x{im.height}"
        im = fit(im, W, H)
        key = hashlib.sha1(im.tobytes()).hexdigest()
        if key in seen:
            report.append(f"{fn}\tSAME AS\t{seen[key]}"); continue
        out = fn.rsplit(".", 1)[0] + ("_fixed-time" if note == "fixed-time" else "") + ".png"
        seen[key] = out
        im.save(os.path.join(dst, out), optimize=True); made += 1
        report.append(f"{fn}\tOK\t{out}\tfrom {size}{' (' + note + ')' if note else ''}")
    open(os.path.join(dst, "_report.txt"), "w", encoding="utf-8").write("\n".join(report) + "\n")
    print(f"made {made} PNG from {len(report)} files")
    for kind in ("SAME AS", "SKIPPED"):
        print(kind, sum(1 for r in report if f"\t{kind}\t" in r))


if __name__ == "__main__":
    # self-check: a one-colour 100x100 dial decodes to that colour and fits to the target size
    sample = struct.pack("<I", 1) + struct.pack("<BBHHHHHII", 9, 1, 0, 0, 0, 100, 100, 24, 26) \
        + struct.pack("<H", 0xF800) + bytes(10000)
    im, _ = dial(sample)
    assert im.getpixel((5, 5)) == (248, 0, 0) and fit(im, 240, 288).size == (240, 288)
    main(sys.argv[1], sys.argv[2], *map(int, sys.argv[3:5]))
