"""Лист превью Sketchfab: python tools/sf_sheet.py <выход.png> uid[:подпись] …  (превью из %TEMP%\sf_thumbs)"""
import sys, os
from PIL import Image, ImageDraw
T = os.path.join(os.environ.get('TEMP', '/tmp'), 'sf_thumbs')
out = sys.argv[1]
items = sys.argv[2:]
W, H = 320, 240
cols = min(4, len(items))
rows = (len(items) + cols - 1) // cols
sh = Image.new('RGB', (W * cols, H * rows), (30, 30, 30))
d = ImageDraw.Draw(sh)
for i, it in enumerate(items):
    uid, _, cap = it.partition(':')
    p = os.path.join(T, uid + '.jpg')
    if os.path.exists(p):
        im = Image.open(p).convert('RGB'); im.thumbnail((W, H - 18)); sh.paste(im, ((i % cols) * W, (i // cols) * H))
    d.text(((i % cols) * W + 4, (i // cols) * H + H - 16), (cap or uid[:8]) , fill=(255, 255, 0))
sh.save(out); print(out)
