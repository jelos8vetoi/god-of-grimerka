"""g67_gazebo_set — стол беседки: газета «ДВОРОВАЯ ПРАВДА № 8», кулёк семечек из газеты с рассыпанной шелухой, термос со снятой крышкой-стаканом,
гранёный стакан, домино. Начало — на столешнице."""
import sys
import os
import math
sys.path.insert(0, os.path.dirname(__file__))
import g67_common as C

R = math.radians
C.reset()
M = {
    "paper": C.mat("paper", (0.78, 0.76, 0.68), under=(0.55, 0.5, 0.38), wear=0.1, dirt=0.5, rough=0.9, scale=5, flat=True),
    "ink": C.mat("ink", (0.05, 0.05, 0.06), flat=True, dirt=0.1, rough=0.8),
    "husk": C.mat("husk", (0.12, 0.1, 0.08), flat=True, dirt=0.1, rough=0.8),
    "thermos": C.mat("thermos", (0.12, 0.34, 0.22), under=(0.34, 0.16, 0.07), wear=0.55, dirt=1.0, rough=0.45, scale=70),
    "steel": C.mat("steel", (0.62, 0.63, 0.66), under=(0.4, 0.2, 0.1), wear=0.35, dirt=0.9, rough=0.35, scale=90),
    "glass": C.mat("glass", (0.6, 0.7, 0.66), flat=True, dirt=0.5, rough=0.1),
    "dom": C.mat("dom", (0.88, 0.85, 0.75), under=(0.6, 0.55, 0.4), wear=0.2, dirt=0.9, rough=0.5, scale=25),
    "red": C.mat("red", (0.7, 0.08, 0.06), flat=True, dirt=0.3, rough=0.6),
    "cup": C.mat("cup", (0.1, 0.1, 0.12), under=(0.3, 0.2, 0.1), wear=0.3, dirt=0.8, rough=0.5, scale=90),
}
P = []
# газета: сгиб посередине, заголовок и колонки
P.append(C.box("news_a", (0.24, 0.36, 0.0025), (-0.13, 0.02, 0.0013), rot=(0, R(-1.2), R(3)), bevel=0.0006, m=M["paper"], seg=1))
P.append(C.box("news_b", (0.24, 0.36, 0.0025), (0.115, 0.02, 0.0013), rot=(0, R(1.2), R(3)), bevel=0.0006, m=M["paper"], seg=1))
P.append(C.text("head", "ДВОРОВАЯ ПРАВДА", 0.04, (0.0, 0.17, 0.0032), font=C.FONT_IMPACT, extrude=0, m=M["ink"]))
P.append(C.text("num", "№ 8", 0.026, (0.18, 0.13, 0.0032), font=C.FONT_IMPACT, extrude=0, m=M["red"]))
P.append(C.box("rule", (0.46, 0.0016, 0.0005), (0.0, 0.15, 0.0031), bevel=0, m=M["ink"], seg=1))
sub = ["ГОЛУБИ ОТКАЗАЛИСЬ", "КОММЕНТИРОВАТЬ", "ПРОПАЛА ЛОПАТА"]
for k, ln in enumerate(sub):
    P.append(C.text("sub%d" % k, ln, 0.014 if k < 2 else 0.012, (-0.13, 0.09 - k * 0.028, 0.0032), font=C.FONT_BOLD, extrude=0, m=M["ink"]))
for r in range(5):
    for c in range(2):
        P.append(C.box("col", (0.1, 0.0015, 0.0005), (-0.17 + c * 0.12, -0.02 - r * 0.026, 0.0031), bevel=0, m=M["ink"], seg=1))
P.append(C.box("photo", (0.1, 0.07, 0.0006), (0.145, 0.04, 0.0032), bevel=0, m=M["ink"], seg=1))
# кулёк семечек: конус из газеты, неровный край, шелуха вокруг
cone = C.cyl("cone", 0.065, 0.14, (0.28, -0.07, 0.07), rot=(R(25), R(10), 0), verts=10, bevel=0.002, m=M["paper"], r2=0.014)
cone.rotation_euler = (R(70), 0, R(20))
cone.location = (0.3, -0.05, 0.045)
P.append(cone)
P.append(C.sphere("seeds", 0.052, (0.255, -0.035, 0.045), scale=(1.0, 0.8, 0.5), seg=8, m=M["husk"]))
import random
random.seed(8)
for k in range(24):
    a = random.uniform(0, 6.28)
    d = random.uniform(0.05, 0.17)
    P.append(C.box("shell%d" % k, (0.011, 0.005, 0.002), (0.22 + math.cos(a) * d, -0.05 + math.sin(a) * d * 0.7, 0.004), rot=(0, 0, a * 3), bevel=0, m=M["husk"], seg=1))
# термос со снятой крышкой-стаканом: корпус, пробка, стакан рядом
P.append(C.cyl("thermos", 0.04, 0.3, (-0.33, -0.2, 0.15), verts=14, bevel=0.004, m=M["thermos"]))
P.append(C.cyl("therm_top", 0.034, 0.02, (-0.33, -0.2, 0.31), verts=12, bevel=0.003, m=M["steel"]))
P.append(C.cyl("therm_mouth", 0.026, 0.006, (-0.33, -0.2, 0.322), verts=12, bevel=0, m=M["ink"]))
P.append(C.cyl("therm_cup", 0.043, 0.08, (-0.22, -0.19, 0.04), rot=(R(90), 0, R(30)), verts=14, bevel=0.003, m=M["cup"]))
P.append(C.box("therm_strap", (0.01, 0.01, 0.1), (-0.33, -0.15, 0.17), bevel=0.001, m=M["ink"], seg=1))
# гранёный стакан с остатком чая
P.append(C.cyl("glass", 0.033, 0.095, (-0.12, -0.24, 0.0475), verts=12, bevel=0.001, m=M["glass"], r2=0.028))
P.append(C.cyl("tea", 0.028, 0.045, (-0.12, -0.24, 0.0245), verts=12, bevel=0, m=M["red"], r2=0.0255))
# домино: шесть костей, часть рядом, часть «рыбой»
dots = {0: [], 1: [(0, 0)], 2: [(-1, -1), (1, 1)], 3: [(-1, -1), (0, 0), (1, 1)], 4: [(-1, -1), (-1, 1), (1, -1), (1, 1)], 5: [(-1, -1), (-1, 1), (0, 0), (1, -1), (1, 1)], 6: [(-1, -1), (-1, 0), (-1, 1), (1, -1), (1, 0), (1, 1)]}
tiles = [(0.0, -0.24, 10, 3, 4), (0.075, -0.235, -4, 6, 2), (0.15, -0.23, 14, 1, 5), (-0.02, -0.17, 100, 0, 6), (0.07, -0.16, 78, 2, 2), (0.14, -0.155, 82, 4, 1)]
for k, (x, y, a, d1, d2) in enumerate(tiles):
    P.append(C.box("dom%d" % k, (0.028, 0.056, 0.01), (x, y, 0.005), rot=(0, 0, R(a)), bevel=0.0015, m=M["dom"]))
    ca, sa = math.cos(R(a)), math.sin(R(a))
    for half, val in ((-1, d1), (1, d2)):
        for (dx, dy) in dots[val]:
            lx, ly = dx * 0.0068, half * 0.014 + dy * 0.0058
            P.append(C.cyl("pip", 0.0026, 0.002, (x + lx * ca - ly * sa, y + lx * sa + ly * ca, 0.0108), verts=6, bevel=0, m=M["ink"]))
views = [((0.8, -0.85, 0.65), (0.0, -0.05, 0.08)), ((0.28, -0.45, 0.32), (0.0, 0.05, 0.02))]
C.finish("g67_gazebo_set", P, views, size=2048)
