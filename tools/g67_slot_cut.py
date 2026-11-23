"""Нарезка спрайтов слота из снимка владельца (slot_reference.jpg): фон с рамой без символов, спрайты символов, кнопка спина. Сетка поля: 5 столбцов × 3 строки."""
import os
from PIL import Image, ImageFilter
ROOT = os.path.join(os.path.dirname(__file__), "..", "godot", "assets", "golda67", "podzemka", "slot")
im = Image.open(os.path.join(ROOT, "src", "slot_reference.jpg")).convert("RGB")
px = im.load()
W, H = im.size
GRID_X = [128, 284, 438, 596, 752, 908]      # границы пяти столбцов
GRID_Y = [95, 232, 368, 503]                 # границы трёх строк


def up(img):
    return img.resize((img.width * 2, img.height * 2), Image.LANCZOS)


def key(img, ref, lo=38, hi=80):
    """убрать однотонный фон (тёмное дерево): прозрачность по расстоянию от ref"""
    rgba = img.convert("RGBA")
    p = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, _ = p[x, y]
            d = ((r - ref[0]) ** 2 + (g - ref[1]) ** 2 + (b - ref[2]) ** 2) ** 0.5
            a = 0 if d < lo else (255 if d > hi else int(255 * (d - lo) / (hi - lo)))
            p[x, y] = (r, g, b, a)
    return rgba


wood = px[145, 300]
print("дерево", wood)
# спрайты
cells = {
    "sym_dog": (288, 98, 436, 224), "sym_dog2": (288, 240, 436, 362),
    "sym_house": (440, 58, 594, 232), "sym_paw": (437, 214, 596, 388),
}
for name, box in cells.items():
    c = im.crop(box)
    if name in ("sym_house", "sym_paw"):
        c = key(c, wood)
    else:
        c = c.convert("RGBA")
    up(c).filter(ImageFilter.SMOOTH).save(os.path.join(ROOT, name + ".png"))
letters = {"sym_a": (166, 120, 242, 208), "sym_k": (166, 254, 242, 342)}
for name, box in letters.items():
    up(key(im.crop(box), wood, 50, 95)).save(os.path.join(ROOT, name + ".png"))
# кнопка спина
up(key(im.crop((745, 478, 850, 585)), (30, 120, 40), 0, 1) if False else im.crop((748, 480, 848, 560)).convert("RGBA")).save(os.path.join(ROOT, "btn_spin.png"))
# фон: поле барабанов закрашено деревом (кусок из пустого места колонки), всё остальное — как на снимке
bg = im.copy()
patch = im.crop((131, 100, 150, 480)).resize((GRID_X[-1] - GRID_X[0], GRID_Y[-1] - GRID_Y[0]), Image.BICUBIC).filter(ImageFilter.GaussianBlur(2))
bg.paste(patch, (GRID_X[0], GRID_Y[0]))
bg.resize((W * 2, H * 2), Image.LANCZOS).save(os.path.join(ROOT, "bg.png"))
print("готово", os.listdir(ROOT))
