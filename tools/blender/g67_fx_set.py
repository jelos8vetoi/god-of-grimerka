"""Фасадные детали двора для части 3: g67_fx_balcony_a (застеклённый балкон с санками и лыжами), g67_fx_balcony_b (открытый, с бельём и велосипедом),
g67_fx_ac (кондиционер-ящик с подтёком), g67_fx_dish (спутниковая тарелка на кронштейне), g67_fx_canopy (козырёк подъезда), g67_fx_door (железная дверь
с кодовым замком и слоями объявлений). Начало — на стене (у задней плоскости), лицо к -Y. Один скрипт: blender --background --python g67_fx_set.py [имя]"""
import sys
import os
import math
sys.path.insert(0, os.path.dirname(__file__))
import g67_common as C

R = math.radians
ONLY = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else ""


def mats():
    return {
        "conc": C.mat("conc", (0.55, 0.55, 0.53), under=(0.38, 0.3, 0.24), wear=0.4, dirt=1.0, rough=0.9, scale=14, bump=0.6),
        "conc2": C.mat("conc2", (0.62, 0.6, 0.55), under=(0.4, 0.33, 0.26), wear=0.35, dirt=1.0, rough=0.9, scale=14, bump=0.6),
        "frame": C.mat("frame", (0.75, 0.72, 0.64), under=(0.4, 0.28, 0.16), wear=0.6, dirt=1.0, rough=0.7, scale=40, grain=(0.08, 1.0, 1.0)),
        "glass": C.mat("glass", (0.28, 0.4, 0.42), flat=True, dirt=0.9, rough=0.1),
        "iron": C.mat("iron", (0.22, 0.28, 0.26), under=(0.36, 0.16, 0.07), wear=0.6, dirt=1.0, rough=0.5, scale=20),
        "rust": C.mat("rust", (0.35, 0.16, 0.08), under=(0.3, 0.14, 0.07), wear=0.8, dirt=1.0, rough=0.75, scale=30),
        "wood": C.mat("wood", (0.5, 0.35, 0.18), under=(0.34, 0.24, 0.13), wear=0.4, dirt=1.0, rough=0.85, scale=40, grain=(0.08, 1.0, 1.0)),
        "red": C.mat("red", (0.62, 0.07, 0.07), under=(0.34, 0.15, 0.07), wear=0.5, dirt=0.9, rough=0.5, scale=30),
        "blue": C.mat("blue", (0.12, 0.25, 0.5), under=(0.34, 0.15, 0.07), wear=0.5, dirt=0.9, rough=0.5, scale=30),
        "white": C.mat("white", (0.86, 0.86, 0.82), under=(0.5, 0.45, 0.35), wear=0.3, dirt=1.0, rough=0.5, scale=25),
        "cloth1": C.mat("cloth1", (0.7, 0.25, 0.25), flat=True, dirt=0.8, rough=0.95),
        "cloth2": C.mat("cloth2", (0.3, 0.45, 0.65), flat=True, dirt=0.8, rough=0.95),
        "cloth3": C.mat("cloth3", (0.85, 0.8, 0.6), flat=True, dirt=0.8, rough=0.95),
        "rubber": C.mat("rubber", (0.04, 0.04, 0.045), flat=True, dirt=0.8, rough=0.8),
        "snow": C.mat("snow", (0.93, 0.95, 0.99), flat=True, dirt=0.1, rough=0.9),
        "stain": C.mat("stain", (0.12, 0.2, 0.15), flat=True, dirt=0.0, rough=0.4),
        "paper": C.mat("paper", (0.85, 0.83, 0.74), flat=True, dirt=0.8, rough=0.9),
        "ink": C.mat("ink", (0.04, 0.04, 0.05), flat=True, dirt=0.0, rough=0.8),
        "lamp": C.mat("lamp", (1.0, 0.85, 0.55), flat=True, dirt=0.0, rough=0.3),
    }


def balcony_a(M):
    P = []
    W, D, Hh = 2.4, 0.9, 1.4
    P.append(C.box("slab", (W, D, 0.12), (0, -D / 2, 0.06), bevel=0.01, m=M["conc"]))
    for sx in (-1, 1):
        P.append(C.box("wall_s", (0.08, D, Hh), (sx * (W / 2 - 0.04), -D / 2, 0.12 + Hh / 2), bevel=0.008, m=M["conc2"]))
    P.append(C.box("wall_back", (W, 0.1, Hh), (0, 0.05, 0.12 + Hh / 2), bevel=0.008, m=M["conc2"]))
    P.append(C.box("parapet", (W - 0.16, 0.07, 0.55), (0, -D + 0.035, 0.12 + 0.275), bevel=0.008, m=M["conc2"]))
    # деревянные рамы остекления: три створки, одна без стекла, одна треснула
    fw = (W - 0.16) / 3.0
    fz0, fz1 = 0.12 + 0.55, 0.12 + Hh
    for k in range(3):
        x = -W / 2 + 0.08 + fw * (k + 0.5)
        for (w, h, px, pz) in ((fw, 0.05, x, fz1 - 0.025), (fw, 0.05, x, fz0 + 0.025), (0.05, fz1 - fz0, x - fw / 2 + 0.025, (fz0 + fz1) / 2), (0.05, fz1 - fz0, x + fw / 2 - 0.025, (fz0 + fz1) / 2)):
            P.append(C.box("fr", (w, 0.05, h), (px, -D + 0.03, pz), bevel=0.004, m=M["frame"], seg=1))
        if k != 1:
            P.append(C.box("gl", (fw - 0.1, 0.006, fz1 - fz0 - 0.1), (x, -D + 0.03, (fz0 + fz1) / 2), bevel=0, m=M["glass"], seg=1))
        else:
            P.append(C.box("gl_half", (fw - 0.1, 0.006, (fz1 - fz0) * 0.45), (x, -D + 0.03, fz0 + 0.07 + (fz1 - fz0) * 0.22), bevel=0, m=M["glass"], seg=1))
        P.append(C.box("hdl", (0.012, 0.03, 0.08), (x + fw / 2 - 0.08, -D + 0.01, (fz0 + fz1) / 2), bevel=0.002, m=M["iron"], seg=1))
    # санки, лыжи, коробки внутри
    P.append(C.box("sled", (0.9, 0.34, 0.04), (-0.55, -0.45, 0.2), rot=(0, R(8), R(-8)), bevel=0.006, m=M["red"]))
    for sy in (-0.1, 0.1):
        P.append(C.box("runner", (1.0, 0.02, 0.03), (-0.55, -0.45 + sy * 1.4, 0.15), rot=(0, R(8), R(-8)), bevel=0.003, m=M["iron"], seg=1))
    for sx in (0.0, 0.1):
        P.append(C.box("ski", (0.06, 0.012, 1.45), (0.55 + sx, -0.12, 0.85), rot=(R(3), R(4), 0), bevel=0.003, m=M["blue"], seg=1))
    P.append(C.box("crate", (0.5, 0.4, 0.4), (0.2, -0.55, 0.32), rot=(0, 0, R(12)), bevel=0.01, m=M["wood"]))
    P.append(C.box("snow_par", (W - 0.14, 0.12, 0.04), (0, -D + 0.035, 0.12 + 0.57), bevel=0.014, m=M["snow"]))
    return P, [((4.0, -4.2, 2.2), (0, -0.45, 0.8)), ((1.2, -2.0, 1.1), (-0.3, -0.5, 0.7))]


def balcony_b(M):
    P = []
    W, D = 2.2, 0.85
    P.append(C.box("slab", (W, D, 0.12), (0, -D / 2, 0.06), bevel=0.01, m=M["conc"]))
    P.append(C.box("wall_back", (W, 0.1, 1.2), (0, 0.05, 0.72), bevel=0.008, m=M["conc2"]))
    # решётка ограждения: стойки и поручень
    for k in range(10):
        P.append(C.box("bal", (0.025, 0.025, 0.95), (-W / 2 + 0.06 + k * (W - 0.12) / 9.0, -D + 0.03, 0.12 + 0.475), bevel=0.002, m=M["iron"], seg=1))
    P.append(C.box("rail_t", (W, 0.05, 0.04), (0, -D + 0.03, 1.1), bevel=0.003, m=M["iron"]))
    P.append(C.box("rail_b", (W, 0.04, 0.03), (0, -D + 0.03, 0.2), bevel=0.002, m=M["iron"]))
    P.append(C.box("rail_s1", (0.04, D, 0.04), (-W / 2 + 0.02, -D / 2, 1.1), bevel=0.003, m=M["iron"]))
    P.append(C.box("rail_s2", (0.04, D, 0.04), (W / 2 - 0.02, -D / 2, 1.1), bevel=0.003, m=M["iron"]))
    # бельевая верёвка с вещами
    P.append(C.cable("rope", [(-W / 2 + 0.05, -0.2, 1.7), (-0.4, -0.2, 1.62), (0.4, -0.2, 1.63), (W / 2 - 0.05, -0.2, 1.7)], r=0.004, m=M["rubber"]))
    P.append(C.box("post_l", (0.04, 0.04, 0.65), (-W / 2 + 0.05, -0.2, 1.43), bevel=0.002, m=M["iron"], seg=1))
    P.append(C.box("post_r", (0.04, 0.04, 0.65), (W / 2 - 0.05, -0.2, 1.43), bevel=0.002, m=M["iron"], seg=1))
    cm = ("cloth1", "cloth2", "cloth3", "cloth1", "cloth2")
    for k in range(5):
        x = -0.85 + k * 0.42
        P.append(C.box("cl%d" % k, (0.3 if k % 2 == 0 else 0.22, 0.01, 0.45 if k % 2 == 0 else 0.6), (x, -0.2, 1.38 - (0.0 if k % 2 == 0 else 0.07)), rot=(0, R((k - 2) * 3), R(k * 2)), bevel=0.002, m=M[cm[k]], seg=1))
    # велосипед у стены
    def wheel(x):
        P.append(C.torus("bw", 0.3, 0.014, (x, -0.2, 0.42), rot=(R(90), 0, 0), ms=18, mn=4, m=M["rubber"]))
        P.append(C.cyl("bhub", 0.02, 0.03, (x, -0.2, 0.42), rot=(R(90), 0, 0), verts=8, bevel=0, m=M["iron"]))
    wheel(-0.55)
    wheel(0.35)
    P.append(C.box("bframe1", (0.95, 0.025, 0.025), (-0.1, -0.2, 0.55), rot=(0, R(-18), 0), bevel=0.002, m=M["red"], seg=1))
    P.append(C.box("bframe2", (0.5, 0.025, 0.025), (0.03, -0.2, 0.62), rot=(0, R(30), 0), bevel=0.002, m=M["red"], seg=1))
    P.append(C.box("seat", (0.2, 0.07, 0.04), (-0.55, -0.2, 0.9), bevel=0.006, m=M["rubber"]))
    P.append(C.box("bar", (0.07, 0.4, 0.03), (0.4, -0.2, 0.95), bevel=0.003, m=M["iron"]))
    P.append(C.box("snow_rail", (W, 0.09, 0.03), (0, -D + 0.03, 1.13), bevel=0.012, m=M["snow"]))
    return P, [((3.8, -4.0, 2.4), (0, -0.4, 0.8)), ((1.4, -1.8, 1.1), (-0.2, -0.3, 0.8))]


def ac(M):
    P = []
    P.append(C.box("body", (0.72, 0.28, 0.5), (0, -0.14, 0.45), bevel=0.012, m=M["white"]))
    P.append(C.box("grille", (0.5, 0.012, 0.4), (-0.06, -0.29, 0.45), bevel=0.004, m=M["iron"], seg=1))
    for k in range(9):
        P.append(C.box("slat", (0.46, 0.014, 0.012), (-0.06, -0.298, 0.28 + k * 0.038), bevel=0, m=M["white"], seg=1))
    P.append(C.cyl("fan", 0.17, 0.012, (-0.06, -0.286, 0.45), rot=(R(90), 0, 0), verts=14, bevel=0, m=M["rubber"]))
    P.append(C.box("side_vent", (0.012, 0.2, 0.34), (0.37, -0.14, 0.45), bevel=0, m=M["iron"], seg=1))
    for sx in (-0.28, 0.28):
        P.append(C.box("bracket", (0.05, 0.3, 0.04), (sx, -0.15, 0.17), bevel=0.003, m=M["iron"]))
        P.append(C.box("bracket_d", (0.04, 0.04, 0.3), (sx, -0.3, 0.1), rot=(R(35), 0, 0), bevel=0.003, m=M["iron"], seg=1))
    P.append(C.cable("pipe", [(0.3, -0.05, 0.3), (0.45, -0.1, 0.2), (0.5, -0.05, 0.05), (0.5, 0.0, -0.4)], r=0.018, m=M["rubber"]))
    # подтёк: тёмная зелёная полоса от поддона вниз по стене
    for k, (x, w, h) in enumerate(((-0.1, 0.06, 0.9), (0.12, 0.03, 0.55), (-0.25, 0.025, 0.4))):
        P.append(C.box("stain%d" % k, (w, 0.003, h), (x, 0.002, 0.2 - h / 2 + 0.05), bevel=0, m=M["stain"], seg=1))
    P.append(C.box("drip", (0.07, 0.02, 0.03), (-0.1, -0.29, 0.18), bevel=0, m=M["stain"], seg=1))
    return P, [((1.6, -2.0, 1.1), (0.0, -0.1, 0.35)), ((0.5, -0.8, 0.45), (-0.05, -0.2, 0.3))]


def dish(M):
    P = []
    P.append(C.box("plate", (0.14, 0.012, 0.2), (0, -0.006, 0.35), bevel=0.004, m=M["iron"]))
    P.append(C.box("arm", (0.04, 0.35, 0.04), (0, -0.19, 0.4), bevel=0.003, m=M["iron"]))
    # чаша: сплюснутая сфера, повернутая к небу и в сторону
    bowl = C.sphere("bowl", 0.36, (0.05, -0.42, 0.58), scale=(1.0, 0.16, 1.0), seg=20, m=M["white"])
    bowl.rotation_euler = (R(-62), 0, R(15))
    P.append(bowl)
    P.append(C.torus("rim", 0.355, 0.012, (0.05, -0.42, 0.58), rot=(R(-62), 0, R(15)), ms=24, mn=4, m=M["white"]))
    # конвертер на штанге
    P.append(C.cyl("boom", 0.008, 0.46, (0.12, -0.55, 0.76), rot=(R(-62) + R(90), 0, R(15)), verts=6, bevel=0, m=M["iron"]))
    P.append(C.cyl("lnb", 0.025, 0.07, (0.17, -0.765, 0.895), rot=(R(28), 0, R(15)), verts=8, bevel=0.003, m=M["rubber"]))
    P.append(C.cable("coax", [(0.17, -0.74, 0.88), (0.1, -0.5, 0.5), (0.02, -0.2, 0.3), (0.0, 0.0, 0.1)], r=0.005, m=M["rubber"]))
    for k, (sx, sz) in enumerate(((-0.05, 0.25), (0.05, 0.25), (-0.05, 0.45), (0.05, 0.45))):
        P.append(C.cyl("bolt", 0.008, 0.012, (sx, -0.014, sz), rot=(R(90), 0, 0), verts=6, bevel=0, m=M["rust"]))
    P.append(C.box("rust_streak", (0.06, 0.003, 0.4), (0.0, 0.001, 0.1), bevel=0, m=M["rust"], seg=1))
    return P, [((1.6, -2.0, 1.2), (0.05, -0.3, 0.6)), ((0.7, -0.9, 0.8), (0.1, -0.4, 0.7))]


def canopy(M):
    P = []
    W, D = 2.2, 1.3
    P.append(C.box("slab", (W, D, 0.14), (0, -D / 2, 2.35), bevel=0.012, m=M["conc"]))
    P.append(C.box("rim_f", (W, 0.1, 0.1), (0, -D + 0.05, 2.45), bevel=0.01, m=M["conc2"]))
    for sx in (-1, 1):
        P.append(C.cyl("pipe", 0.045, 2.3, (sx * (W / 2 - 0.12), -D + 0.12, 1.15), verts=12, bevel=0.003, m=M["iron"]))
        P.append(C.box("pipe_base", (0.14, 0.14, 0.015), (sx * (W / 2 - 0.12), -D + 0.12, 0.008), bevel=0.003, m=M["iron"]))
    P.append(C.box("snow", (W - 0.1, D - 0.1, 0.07), (0, -D / 2, 2.455), bevel=0.03, m=M["snow"]))
    # плафон в решётке под козырьком
    P.append(C.box("lamp_base", (0.3, 0.2, 0.05), (0, -0.55, 2.26), bevel=0.01, m=M["iron"]))
    P.append(C.box("lamp_glass", (0.26, 0.17, 0.05), (0, -0.55, 2.215), bevel=0.01, m=M["lamp"]))
    for k in range(5):
        P.append(C.box("lamp_bar", (0.28, 0.008, 0.008), (0, -0.62 + k * 0.034, 2.18), bevel=0, m=M["iron"], seg=1))
    # потёки ржавчины и трещина на плите
    for k, x in enumerate((-0.7, 0.2, 0.75)):
        P.append(C.box("rustS%d" % k, (0.05, D * 0.5, 0.004), (x, -D * 0.55, 2.278), bevel=0, m=M["rust"], seg=1))
    return P, [((4.4, -4.6, 2.3), (0, -0.65, 1.3)), ((0.8, -1.2, 1.6), (0.0, -0.6, 2.3))]


def door(M):
    P = []
    W, Hh = 1.05, 2.05
    P.append(C.box("frame_l", (0.1, 0.16, Hh + 0.1), (-W / 2 - 0.05, -0.08, (Hh + 0.1) / 2), bevel=0.008, m=M["iron"]))
    P.append(C.box("frame_r", (0.1, 0.16, Hh + 0.1), (W / 2 + 0.05, -0.08, (Hh + 0.1) / 2), bevel=0.008, m=M["iron"]))
    P.append(C.box("frame_t", (W + 0.2, 0.16, 0.1), (0, -0.08, Hh + 0.05), bevel=0.008, m=M["iron"]))
    P.append(C.box("leaf", (W, 0.06, Hh), (0, -0.09, Hh / 2), bevel=0.006, m=M["blue"]))
    # накладные рёбра жёсткости и заклёпки
    for (w, h, x, z) in ((W - 0.14, 0.05, 0, 0.35), (W - 0.14, 0.05, 0, Hh - 0.3), (0.05, Hh - 0.5, -W / 2 + 0.1, Hh / 2), (0.05, Hh - 0.5, W / 2 - 0.1, Hh / 2)):
        P.append(C.box("rib", (w, 0.012, h), (x, -0.126, z), bevel=0.002, m=M["blue"], seg=1))
    for k in range(10):
        P.append(C.cyl("rv", 0.008, 0.01, (-W / 2 + 0.1 + (k % 5) * 0.2, -0.134, 0.35 if k < 5 else Hh - 0.3), rot=(R(90), 0, 0), verts=6, bevel=0, m=M["rust"]))
    # ручка-скоба, глазок, кодовый замок 3×4, доводчик-пружина
    P.append(C.cyl("bar_h", 0.015, 0.4, (0.34, -0.17, 1.1), verts=8, bevel=0.002, m=M["iron"]))
    for z in (0.92, 1.28):
        P.append(C.box("bar_mnt", (0.04, 0.07, 0.04), (0.34, -0.15, z), bevel=0.002, m=M["iron"], seg=1))
    P.append(C.cyl("peep", 0.012, 0.015, (0.0, -0.125, 1.55), rot=(R(90), 0, 0), verts=8, bevel=0, m=M["rust"]))
    P.append(C.box("keypad", (0.14, 0.03, 0.22), (-0.38, -0.14, 1.12), bevel=0.004, m=M["iron"]))
    for i in range(12):
        P.append(C.box("key", (0.028, 0.012, 0.028), (-0.38 + (i % 3 - 1) * 0.04, -0.158, 1.19 - (i // 3) * 0.04), bevel=0.002, m=M["white"], seg=1))
    P.append(C.box("closer", (0.4, 0.04, 0.05), (-0.2, -0.16, 1.98), bevel=0.004, m=M["rust"]))
    P.append(C.cyl("spring", 0.012, 0.5, (-0.0, -0.17, 1.9), rot=(0, R(90), R(10)), verts=6, bevel=0, m=M["iron"]))
    # слои объявлений: несколько листов внахлёст, у каждого строки
    import random
    random.seed(11)
    for k in range(9):
        x = random.uniform(-0.3, 0.3)
        z = random.uniform(1.25, 1.85)
        P.append(C.box("ad%d" % k, (0.2, 0.002, 0.28), (x, -0.1285 - k * 0.0006, z), rot=(0, R(random.uniform(-9, 9)), 0), bevel=0, m=M["paper"], seg=1))
        for ln in range(3):
            P.append(C.box("ln", (0.16, 0.0015, 0.008), (x, -0.131 - k * 0.0006, z + 0.07 - ln * 0.03), bevel=0, m=M["ink"], seg=1))
    # порог и снег
    P.append(C.box("sill", (W + 0.2, 0.4, 0.04), (0, -0.2, 0.02), bevel=0.006, m=M["conc"]))
    P.append(C.box("snow_sill", (W, 0.24, 0.03), (0, -0.25, 0.055), bevel=0.012, m=M["snow"]))
    return P, [((2.8, -3.4, 1.6), (0, -0.1, 1.0)), ((0.7, -0.9, 1.3), (-0.2, -0.13, 1.2))]


BUILD = {"balcony_a": balcony_a, "balcony_b": balcony_b, "ac": ac, "dish": dish, "canopy": canopy, "door": door}
for nm, fn in BUILD.items():
    if ONLY and nm != ONLY:
        continue
    C.reset()
    M = mats()
    P, views = fn(M)
    C.finish("g67_fx_" + nm, P, views)
