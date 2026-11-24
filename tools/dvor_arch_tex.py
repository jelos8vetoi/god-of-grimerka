"""ДВОР: текстуры арки и спуска в Подземку (кафель, бетон, металл, ступени, таблички). Рисуются кодом, 512 px.
python tools/dvor_arch_tex.py -> godot/assets/golda67/dvor_redesign_work/arch_tex/*.png"""
import os, random
from PIL import Image, ImageDraw, ImageFilter, ImageFont
OUT = os.path.join(os.path.dirname(__file__), '..', 'godot', 'assets', 'golda67', 'dvor_redesign_work', 'arch_tex')
os.makedirs(OUT, exist_ok=True)
R = random.Random(812)
S = 512

def noise(img, amt, blur=0.0, seed=1):
    r = random.Random(seed); n = Image.new('L', img.size)
    n.putdata([r.randint(0, 255) for _ in range(img.size[0] * img.size[1])])
    if blur: n = n.filter(ImageFilter.GaussianBlur(blur))
    return Image.blend(img, Image.merge('RGB', (n, n, n)), amt)

def stains(img, n, col, seed):
    r = random.Random(seed); d = ImageDraw.Draw(img, 'RGBA')
    for _ in range(n):
        x, y = r.randint(0, S), r.randint(0, S); w, h = r.randint(6, 40), r.randint(40, 220)
        d.ellipse((x - w, y, x + w, y + h), fill=col + (r.randint(14, 46),))
    return img.filter(ImageFilter.GaussianBlur(1.2))

def tiles():
    """Грязный бело-голубой кафель 8 × 8 плиток: швы, сколы, отбитые плитки, потёки снизу."""
    im = Image.new('RGB', (S, S), (70, 72, 70)); d = ImageDraw.Draw(im); t = S // 8
    for j in range(8):
        for i in range(8):
            if R.random() < 0.06:      # отбитая плитка — видно раствор
                d.rectangle((i * t + 2, j * t + 2, i * t + t - 3, j * t + t - 3), fill=(96 + R.randint(-8, 8), 92, 84)); continue
            blue = (j in (2, 5)) or R.random() < 0.05
            c = (118, 150, 172) if blue else (196, 198, 190)
            k = R.randint(-14, 10); c = tuple(max(0, min(255, v + k)) for v in c)
            d.rectangle((i * t + 2, j * t + 2, i * t + t - 3, j * t + t - 3), fill=c)
            if R.random() < 0.18:      # скол уголка
                cx, cy = i * t + R.choice((4, t - 12)), j * t + R.choice((4, t - 12)); d.polygon([(cx, cy), (cx + 9, cy), (cx, cy + 9)], fill=(92, 90, 84))
    im = noise(im, 0.10, 0.6, 3); im = stains(im, 46, (48, 40, 30), 5)
    g = Image.new('L', (S, S)); gd = ImageDraw.Draw(g)
    for y in range(S): gd.line((0, y, S, y), fill=int(max(0, (y - S * 0.55) / (S * 0.45)) * 120))
    return Image.composite(Image.new('RGB', (S, S), (58, 52, 44)), im, g)

def concrete(base=(118, 116, 110), seed=7, panels=True):
    im = Image.new('RGB', (S, S), base); im = noise(im, 0.22, 2.2, seed); im = noise(im, 0.10, 0.0, seed + 1); d = ImageDraw.Draw(im)
    if panels:
        for x in (0, S // 2): d.line((x, 0, x, S), fill=(62, 60, 56), width=3)
        d.line((0, S // 2, S, S // 2), fill=(62, 60, 56), width=3)
    return stains(im, 30, (40, 36, 30), seed + 2)

def metal():
    im = Image.new('RGB', (S, S), (52, 60, 58)); im = noise(im, 0.18, 1.0, 11); d = ImageDraw.Draw(im, 'RGBA'); r = random.Random(12)
    for _ in range(140):
        x, y, q = r.randint(0, S), r.randint(0, S), r.randint(3, 26)
        d.ellipse((x - q, y - q, x + q, y + q), fill=(120 + r.randint(-20, 20), 62, 28, r.randint(40, 130)))
    return im.filter(ImageFilter.GaussianBlur(0.8))

def steps():
    """Ступень: тёмный гранит, стёртая светлая кромка, слякоть."""
    im = Image.new('RGB', (S, S), (74, 74, 78)); im = noise(im, 0.20, 0.8, 21); d = ImageDraw.Draw(im, 'RGBA')
    d.rectangle((0, 0, S, 46), fill=(150, 148, 140, 150)); r = random.Random(22)
    for _ in range(90):
        x, y, q = r.randint(0, S), r.randint(40, S), r.randint(4, 30); d.ellipse((x - q, y - q // 2, x + q, y + q // 2), fill=(196, 200, 206, r.randint(30, 110)))
    return im.filter(ImageFilter.GaussianBlur(0.7))

def sign(text, size, bg, fg, w=512, h=128, border=None, dirt=True, seed=31):
    im = Image.new('RGB', (w, h), bg); d = ImageDraw.Draw(im)
    f = ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', size)
    lines = text.split('\n'); th = sum(d.textbbox((0, 0), ln, font=f)[3] for ln in lines) + 6 * (len(lines) - 1); y = (h - th) // 2 - 4
    for ln in lines:
        bb = d.textbbox((0, 0), ln, font=f); d.text(((w - bb[2]) // 2, y), ln, font=f, fill=fg); y += bb[3] + 6
    if border: d.rectangle((3, 3, w - 4, h - 4), outline=border, width=4)
    if dirt:
        r = random.Random(seed); dd = ImageDraw.Draw(im, 'RGBA')
        for _ in range(60):
            x, y2, q = r.randint(0, w), r.randint(0, h), r.randint(2, 18); dd.ellipse((x - q, y2 - q, x + q, y2 + q), fill=(70, 46, 24, r.randint(20, 70)))
        im = im.filter(ImageFilter.GaussianBlur(0.5))
    return im

tiles().save(os.path.join(OUT, 'tile.png'))
concrete().save(os.path.join(OUT, 'concrete.png'))
concrete((92, 90, 88), 17, False).save(os.path.join(OUT, 'floor.png'))
metal().save(os.path.join(OUT, 'metal.png'))
steps().save(os.path.join(OUT, 'step.png'))
sign('ПОДЗЕМНЫЙ ПЕРЕХОД', 40, (36, 58, 96), (214, 216, 208), border=(214, 216, 208)).save(os.path.join(OUT, 'sign_perehod.png'))
sign('ВЫХОД (ПЛАТНО)', 46, (232, 200, 40), (24, 22, 18), seed=33).save(os.path.join(OUT, 'sign_vyhod.png'))
sign('ВЫХОД ПЛАТНЫЙ.\nПАНИКУ ПРИНИМАЕМ\nБЕСПЛАТНО', 30, (232, 200, 40), (24, 22, 18), h=160, seed=35).save(os.path.join(OUT, 'sign_panika.png'))
sign('67 ₽', 84, (232, 200, 40), (190, 24, 20), w=256, h=128, seed=37).save(os.path.join(OUT, 'sign_67.png'))
sign('FORTUNA 812', 34, (20, 20, 22), (232, 200, 40), w=384, h=96, border=(232, 200, 40), seed=39).save(os.path.join(OUT, 'sign_fortuna.png'))
sign('ЗАКРЫТО\nключ у Миши', 34, (206, 204, 196), (40, 40, 44), w=320, h=160, seed=41).save(os.path.join(OUT, 'sign_closed.png'))
print('ok', sorted(os.listdir(OUT)))
