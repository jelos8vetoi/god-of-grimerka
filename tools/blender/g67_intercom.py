"""g67_intercom — панель домофона 90-х: стальная рамка, решётка динамика, 12 кнопок (btn8 — отдельный узел, затёрта сильнее всех),
треснувшее табло, выжженное пятно, наклейка-объявление внахлёст, провод в гофре. Лицо к -Y (в Godot +Z), начало — низ панели у стены."""
import sys
import os
import math
sys.path.insert(0, os.path.dirname(__file__))
import g67_common as C

C.reset()
M = {
    "frame": C.mat("frame", (0.27, 0.33, 0.28), under=(0.33, 0.15, 0.07), wear=0.55, dirt=0.8, rough=0.5, scale=70),
    "plate": C.mat("plate", (0.46, 0.47, 0.48), under=(0.34, 0.2, 0.1), wear=0.42, dirt=1.0, rough=0.4, scale=110),
    "btn": C.mat("btn", (0.62, 0.6, 0.5), under=(0.4, 0.3, 0.2), wear=0.25, dirt=0.8, rough=0.45, scale=200),
    "btn8": C.mat("btn8", (0.34, 0.31, 0.26), under=(0.2, 0.15, 0.1), wear=0.7, dirt=1.0, rough=0.7, scale=260),
    "glass": C.mat("glass", (0.02, 0.03, 0.03), flat=True, dirt=0.5, rough=0.15),
    "red": C.mat("red", (0.9, 0.06, 0.04), flat=True, dirt=0.1, rough=0.3),
    "char": C.mat("char", (0.025, 0.02, 0.018), flat=True, dirt=0.0, rough=0.95),
    "paper": C.mat("paper", (0.86, 0.84, 0.76), flat=True, dirt=0.7, rough=0.9),
    "ink": C.mat("ink", (0.03, 0.03, 0.04), flat=True, dirt=0.0, rough=0.8),
    "cable": C.mat("cable", (0.04, 0.045, 0.05), flat=True, dirt=0.6, rough=0.55),
    "screw": C.mat("screw", (0.3, 0.3, 0.3), under=(0.3, 0.14, 0.07), wear=0.6, dirt=0.8, rough=0.5, scale=300),
}
parts = []
F = -1.0     # лицо к -Y

# корпус: стальная рамка с загнутой кромкой и вдавленная лицевая панель
parts.append(C.box("frame", (0.30, 0.05, 0.45), (0, -0.025, 0.225), bevel=0.007, m=M["frame"]))
parts.append(C.box("lip_top", (0.31, 0.012, 0.012), (0, -0.056, 0.444), bevel=0.003, m=M["frame"]))
parts.append(C.box("lip_bot", (0.31, 0.012, 0.012), (0, -0.056, 0.006), bevel=0.003, m=M["frame"]))
parts.append(C.box("face", (0.262, 0.008, 0.412), (0, -0.052, 0.225), bevel=0.004, m=M["plate"]))
# решётка динамика: ряд прорезей (тёмные вставки)
for i in range(7):
    parts.append(C.box("slot%d" % i, (0.19, 0.003, 0.0085), (0, -0.0575, 0.395 - i * 0.0185), bevel=0, m=M["char"], seg=1))
parts.append(C.box("grille_frame", (0.215, 0.003, 0.142), (0, -0.0545, 0.347), bevel=0.0015, m=M["frame"], seg=1))
# табло: стекло, красные сегменты, трещина
parts.append(C.box("disp", (0.15, 0.006, 0.05), (0, -0.0585, 0.268), bevel=0.003, m=M["glass"]))
seg = {"0": (1, 1, 1, 0, 1, 1, 1), "6": (1, 1, 0, 1, 1, 1, 1), "7": (1, 0, 1, 0, 0, 1, 0)}
def digit(ch, x):
    s = seg[ch]
    sw, sl = 0.0045, 0.0165
    pos = [(0, 0.021, sl, sw), (-0.0105, 0.0105, sw, sl), (0.0105, 0.0105, sw, sl), (0, 0.0, sl, sw), (-0.0105, -0.0105, sw, sl), (0.0105, -0.0105, sw, sl), (0, -0.021, sl, sw)]
    for k, on in enumerate(s):
        if not on:
            continue
        px, pz, w, h = pos[k]
        parts.append(C.box("seg_%s_%d_%.2f" % (ch, k, x), (w, 0.002, h), (x + px, -0.0625, 0.268 + pz), bevel=0, m=M["red"], seg=1))
digit("6", -0.04)
digit("7", 0.0)
digit("0", 0.04)
parts.append(C.box("crack1", (0.0022, 0.0015, 0.036), (0.052, -0.0635, 0.27), rot=(0, math.radians(28), 0), bevel=0, m=M["ink"], seg=1))
parts.append(C.box("crack2", (0.0016, 0.0015, 0.02), (0.059, -0.0638, 0.262), rot=(0, math.radians(-50), 0), bevel=0, m=M["ink"], seg=1))
# 12 кнопок: 3 колонки × 4 ряда; «8» — отдельный подвижный узел
labels = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]
btn8 = None
for i, lb in enumerate(labels):
    col, row = i % 3, i // 3
    x = (col - 1) * 0.062
    z = 0.196 - row * 0.049
    isb8 = lb == "8"
    b = C.cyl("btn8" if isb8 else "btn%d" % i, 0.0165, 0.008, (x, -0.0575, z), rot=(math.radians(90), 0, 0), verts=14, bevel=0.0022, m=M["btn8"] if isb8 else M["btn"])
    ring = C.cyl("ring%d" % i, 0.0215, 0.004, (x, -0.0555, z), rot=(math.radians(90), 0, 0), verts=14, bevel=0.0012, m=M["screw"], cap=True)
    t = C.text("lab%d" % i, lb, 0.017, (x, -0.0626, z), rot=(math.radians(90), 0, 0), font=C.FONT_BOLD, extrude=0, m=M["ink"])
    parts.append(ring)
    if isb8:
        b = C.join("btn8", [b, t])
        btn8 = b
    else:
        parts.append(t)
    parts.append(b)
# выжженное пятно рядом с семёркой и мелкие подпалины
parts.append(C.cyl("burn", 0.021, 0.002, (-0.069, -0.0572, 0.1), rot=(math.radians(90), 0, 0), verts=14, bevel=0, m=M["char"]))
parts.append(C.cyl("burn2", 0.011, 0.002, (-0.1, -0.0572, 0.088), rot=(math.radians(90), 0, 0), verts=10, bevel=0, m=M["char"]))
# винты по углам со шлицем
for sx in (-0.128, 0.128):
    for sz in (0.02, 0.43):
        parts.append(C.cyl("screw", 0.0075, 0.005, (sx, -0.058, sz), rot=(math.radians(90), 0, 0), verts=10, bevel=0, m=M["screw"]))
        parts.append(C.box("slotscrew", (0.011, 0.002, 0.0018), (sx, -0.0612, sz), rot=(0, math.radians(35), 0), bevel=0, m=M["ink"], seg=1))
# наклейка-объявление внахлёст в правом нижнем углу
parts.append(C.box("paper", (0.108, 0.0012, 0.125), (0.074, -0.0635, 0.375), rot=(0, math.radians(-8), 0), bevel=0.0004, m=M["paper"], seg=1))
parts.append(C.text("ad1", "ПРОДАЮ", 0.016, (0.076, -0.0647, 0.415), rot=(math.radians(90), math.radians(8), 0), font=C.FONT_IMPACT, extrude=0, m=M["ink"]))
parts.append(C.text("ad2", "ГАРАЖ 8", 0.014, (0.075, -0.0647, 0.393), rot=(math.radians(90), math.radians(8), 0), font=C.FONT_BOLD, extrude=0, m=M["ink"]))
parts.append(C.text("ad3", "НЕ СПРАШИВАЙ", 0.0085, (0.073, -0.0647, 0.372), rot=(math.radians(90), math.radians(8), 0), font=C.FONT_BOLD, extrude=0, m=M["ink"]))
for k in range(5):
    parts.append(C.box("tab%d" % k, (0.014, 0.0011, 0.028), (0.032 + k * 0.0165, -0.0645, 0.3225), rot=(0, math.radians(-8), 0), bevel=0, m=M["paper"], seg=1))
# провод в гофре вверх и в стену
cab = C.cable("cable", [(0.09, -0.02, 0.44), (0.09, -0.035, 0.475), (0.085, -0.03, 0.505), (0.07, -0.005, 0.52)], r=0.0095, m=M["cable"])
parts.append(cab)
for k in range(7):
    z = 0.452 + k * 0.0075
    parts.append(C.torus("rib%d" % k, 0.0095, 0.0022, (0.09 - 0.004 * (k / 6.0), -0.03 - 0.005 * math.sin(k / 6.0 * 3.14), z), ms=10, mn=4, m=M["cable"]))

# шестерня файла: объекты одним атласом
views = [((0.62, -0.95, 0.55), (0.0, -0.04, 0.23)), ((0.16, -0.36, 0.22), (0.0, -0.05, 0.19))]
wall = C.box("wallbg", (1.0, 0.1, 1.0), (0, 0.05, 0.5), bevel=0)
C.finish("g67_intercom", parts, views)
