"""Перекодировать встроенные текстуры .glb (JPEG через PIL: базовый, без ICC/EXIF) — Godot иногда молча не вытаскивает baseColor из JPEG, записанного Blender.
python tools/g67_glb_fixtex.py файл.glb [файл2.glb …]  (перезаписывает файлы)"""
import sys, json, struct, io
from PIL import Image


def run(path):
    d = open(path, "rb").read()
    jl = struct.unpack("<I", d[12:16])[0]
    js = json.loads(d[20:20 + jl])
    off = 20 + jl
    bl = struct.unpack("<I", d[off:off + 4])[0]
    b = d[off + 8:off + 8 + bl]
    imgs = {im["bufferView"]: im for im in js.get("images", [])}
    chunks = []
    pos = 0
    for i, bv in enumerate(js["bufferViews"]):
        data = b[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]]
        if i in imgs:
            im = Image.open(io.BytesIO(data)).convert("RGB")
            out = io.BytesIO()
            im.save(out, "JPEG", quality=90, optimize=False, progressive=False, subsampling=0)
            data = out.getvalue()
            imgs[i]["mimeType"] = "image/jpeg"
        pad = (-len(data)) % 4
        bv["byteOffset"] = pos
        bv["byteLength"] = len(data)
        chunks.append(data + b"\0" * pad)
        pos += len(data) + pad
    nb = b"".join(chunks)
    js["buffers"][0]["byteLength"] = len(nb)
    jb = json.dumps(js, separators=(",", ":")).encode("utf8")
    jb += b" " * ((-len(jb)) % 4)
    total = 12 + 8 + len(jb) + 8 + len(nb)
    open(path, "wb").write(struct.pack("<4sII", b"glTF", 2, total) + struct.pack("<I4s", len(jb), b"JSON") + jb + struct.pack("<I4s", len(nb), b"BIN\0") + nb)
    print("перекодировано", path, round(total / 1048576.0, 1), "МБ")


for p in sys.argv[1:]:
    run(p)
