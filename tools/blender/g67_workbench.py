"""g67_workbench — гаражный верстак: уголок и доски со щелями и прожжённым кругом, задняя перфопанель с висящим инструментом и календарём,
тиски с воротком, выдвинутый ящик, банки с болтами, паяльник на подставке, карбюратор на газете, лампа с конусом, внизу канистра,
аккумулятор с «крокодилами» и стопка покрышек. Лицо к -Y, начало — на полу по центру."""
import sys
import os
import math
import random
sys.path.insert(0, os.path.dirname(__file__))
import g67_common as C
from mathutils import Vector

R = math.radians
C.reset()
random.seed(5)
M = {
    "wood": C.mat("wood", (0.5, 0.35, 0.2), under=(0.3, 0.2, 0.11), wear=0.4, dirt=1.0, rough=0.85, scale=9, grain=(0.07, 1.0, 1.0), streaks=0.3),
    "woodb": C.mat("woodb", (0.46, 0.32, 0.18), under=(0.28, 0.19, 0.1), wear=0.45, dirt=1.0, rough=0.85, scale=9, grain=(1.0, 1.0, 0.07), streaks=0.3),
    "angle": C.mat("angle", (0.17, 0.32, 0.22), under=(0.34, 0.15, 0.07), wear=0.6, dirt=1.0, rough=0.5, scale=8, streaks=0.9),
    "steel": C.mat("steel", (0.58, 0.59, 0.62), under=(0.4, 0.2, 0.1), wear=0.5, dirt=1.0, rough=0.35, scale=12, streaks=0.6),
    "vise": C.mat("vise", (0.1, 0.2, 0.42), under=(0.34, 0.15, 0.07), wear=0.65, dirt=1.0, rough=0.45, scale=12, streaks=0.7),
    "red": C.mat("red", (0.72, 0.08, 0.06), under=(0.35, 0.15, 0.08), wear=0.45, dirt=0.9, rough=0.5, scale=25),
    "oil": C.mat("oil", (0.03, 0.025, 0.02), flat=True, dirt=0.0, rough=0.2),
    "burn": C.mat("burn", (0.04, 0.025, 0.015), flat=True, dirt=0.0, rough=0.9),
    "cloth": C.mat("cloth", (0.42, 0.38, 0.28), flat=True, dirt=1.0, rough=0.95),
    "tin": C.mat("tin", (0.78, 0.7, 0.45), under=(0.4, 0.22, 0.1), wear=0.5, dirt=1.0, rough=0.4, scale=18, streaks=0.8),
    "label": C.mat("label", (0.55, 0.08, 0.06), flat=True, dirt=0.7, rough=0.7),
    "bolt": C.mat("bolt", (0.4, 0.35, 0.32), under=(0.35, 0.17, 0.08), wear=0.7, dirt=0.8, rough=0.5, scale=30),
    "black": C.mat("black", (0.04, 0.04, 0.045), flat=True, dirt=0.8, rough=0.6),
    "canister": C.mat("canister", (0.14, 0.4, 0.24), under=(0.34, 0.15, 0.07), wear=0.55, dirt=1.0, rough=0.4, scale=10, streaks=0.9),
    "lamp": C.mat("lamp", (0.78, 0.74, 0.6), under=(0.4, 0.3, 0.2), wear=0.4, dirt=0.9, rough=0.4, scale=14),
    "bulb": C.mat("bulb", (1.0, 0.92, 0.7), flat=True, dirt=0.0, rough=0.2),
    "paper": C.mat("paper", (0.74, 0.72, 0.62), flat=True, dirt=0.8, rough=0.9),
    "ink": C.mat("ink", (0.05, 0.05, 0.06), flat=True, dirt=0.0, rough=0.8),
    "peg": C.mat("peg", (0.52, 0.4, 0.24), under=(0.3, 0.2, 0.11), wear=0.4, dirt=1.0, rough=0.85, scale=9, streaks=0.4),
    "rubber": C.mat("rubber", (0.05, 0.05, 0.055), flat=True, dirt=0.8, rough=0.85),
}
P = []
W, D, H = 1.6, 0.7, 0.9
# столешница: четыре доски со щелями, у каждой чуть свой перекос, окантовка уголком
bw = (D - 3 * 0.014) / 4
for k in range(4):
    y = -D / 2 + bw / 2 + k * (bw + 0.014)
    P.append(C.box("top%d" % k, (W, bw, 0.04), (0, y, H - 0.02), rot=(0, R(random.uniform(-0.4, 0.4)), R((k - 1.5) * 0.25)), bevel=0.004, m=M["wood" if k % 2 == 0 else "woodb"]))
P.append(C.cyl("burn_ring", 0.07, 0.002, (0.1, -0.18, H + 0.001), verts=20, bevel=0, m=M["burn"]))
P.append(C.cyl("burn_in", 0.045, 0.003, (0.1, -0.18, H + 0.0015), verts=16, bevel=0, m=M["wood"]))
P.append(C.box("edge_f", (W + 0.02, 0.035, 0.045), (0, -D / 2, H - 0.025), bevel=0.003, m=M["angle"]))
P.append(C.box("edge_b", (W + 0.02, 0.035, 0.045), (0, D / 2, H - 0.025), bevel=0.003, m=M["angle"]))
for sx in (-1, 1):
    P.append(C.box("edge_s", (0.035, D, 0.045), (sx * W / 2, 0, H - 0.025), bevel=0.003, m=M["angle"]))
# ножки-уголки, стяжки, раскосы строго в плоскостях ног, нижняя полка
for sx in (-1, 1):
    for sy in (-1, 1):
        x, y = sx * (W / 2 - 0.03), sy * (D / 2 - 0.03)
        P.append(C.box("leg_a", (0.05, 0.005, H - 0.045), (x, y + sy * 0.0225, (H - 0.045) / 2), bevel=0.001, m=M["angle"], seg=1))
        P.append(C.box("leg_b", (0.005, 0.05, H - 0.045), (x + sx * 0.0225, y, (H - 0.045) / 2), bevel=0.001, m=M["angle"], seg=1))
        P.append(C.cyl("foot", 0.032, 0.012, (x, y, 0.006), verts=10, bevel=0.002, m=M["steel"]))
for sy in (-1, 1):
    P.append(C.box("rail", (W - 0.06, 0.035, 0.03), (0, sy * (D / 2 - 0.03), 0.22), bevel=0.002, m=M["angle"]))
for sx in (-1, 1):
    P.append(C.box("rail_s", (0.035, D - 0.06, 0.03), (sx * (W / 2 - 0.03), 0, 0.22), bevel=0.002, m=M["angle"]))
    br = C.box("brace", (0.03, 0.78, 0.025), (sx * (W / 2 - 0.03), 0, 0.5), rot=(R(-47), 0, 0), bevel=0.002, m=M["angle"], seg=1)
    P.append(br)
P.append(C.box("shelf", (W - 0.06, D - 0.05, 0.025), (0, 0, 0.245), bevel=0.003, m=M["wood"]))
for sx in (-1, 1):
    for sy in (-1, 1):
        P.append(C.torus("weld", 0.018, 0.005, (sx * (W / 2 - 0.03), sy * (D / 2 - 0.03), 0.22), ms=10, mn=4, m=M["bolt"]))
# задняя перфопанель с висящим инструментом
PB_Z0, PB_H = H + 0.0, 0.62
P.append(C.box("pegboard", (W - 0.04, 0.02, PB_H), (0, D / 2 + 0.01, PB_Z0 + PB_H / 2), bevel=0.003, m=M["peg"]))
P.append(C.box("peg_frame_t", (W, 0.03, 0.03), (0, D / 2 + 0.012, PB_Z0 + PB_H + 0.012), bevel=0.003, m=M["angle"]))
for ix in range(12):
    for iz in range(5):
        if (ix * 3 + iz * 5) % 3 != 0:
            continue
        P.append(C.cyl("hole", 0.005, 0.004, (-0.7 + ix * 0.127, D / 2 - 0.001, PB_Z0 + 0.07 + iz * 0.12), rot=(R(90), 0, 0), verts=6, bevel=0, m=M["black"]))
# ножовка: рама-дуга, полотно, ручка
saw_pts = [(-0.55, D / 2 - 0.02, PB_Z0 + 0.46), (-0.58, D / 2 - 0.02, PB_Z0 + 0.54), (-0.3, D / 2 - 0.02, PB_Z0 + 0.58), (-0.12, D / 2 - 0.02, PB_Z0 + 0.5)]
P.append(C.cable("saw_frame", saw_pts, r=0.006, m=M["steel"], res=4))
P.append(C.box("saw_blade", (0.46, 0.002, 0.03), (-0.34, D / 2 - 0.021, PB_Z0 + 0.465), rot=(0, R(-3), 0), bevel=0, m=M["steel"], seg=1))
P.append(C.box("saw_grip", (0.04, 0.025, 0.1), (-0.58, D / 2 - 0.022, PB_Z0 + 0.5), rot=(0, R(12), 0), bevel=0.005, m=M["red"]))
# ключи на гвоздях по размеру
for k in range(5):
    ln = 0.22 - k * 0.02
    x = 0.1 + k * 0.09
    P.append(C.box("pw%d" % k, (0.022, 0.006, ln), (x, D / 2 - 0.012, PB_Z0 + 0.5 - (0.22 - ln) / 2), rot=(0, R((k - 2) * 3), 0), bevel=0.002, m=M["steel"], seg=1))
    P.append(C.torus("pwr%d" % k, 0.013, 0.005, (x, D / 2 - 0.012, PB_Z0 + 0.5 + ln / 2 - 0.0), rot=(R(90), 0, 0), ms=8, mn=3, m=M["steel"]))
    P.append(C.cyl("nail%d" % k, 0.004, 0.02, (x, D / 2 - 0.015, PB_Z0 + 0.615), rot=(R(90), 0, 0), verts=5, bevel=0, m=M["black"]))
# моток проволоки и календарь
P.append(C.torus("wire_coil", 0.055, 0.016, (0.62, D / 2 - 0.03, PB_Z0 + 0.38), rot=(R(90), 0, 0), ms=14, mn=5, m=M["steel"]))
P.append(C.torus("wire_coil2", 0.045, 0.012, (0.62, D / 2 - 0.03, PB_Z0 + 0.38), rot=(R(90), 0, 0), ms=12, mn=4, m=M["bolt"]))
P.append(C.box("calendar", (0.2, 0.004, 0.28), (-0.12, D / 2 - 0.014, PB_Z0 + 0.22), rot=(0, R(2), 0), bevel=0.001, m=M["paper"], seg=1))
P.append(C.box("cal_pic", (0.17, 0.0015, 0.1), (-0.12, D / 2 - 0.0165, PB_Z0 + 0.27), bevel=0, m=M["label"], seg=1))
P.append(C.text("cal_y", "2016", 0.05, (-0.12, D / 2 - 0.0172, PB_Z0 + 0.15), rot=(R(90), 0, R(180)), font=C.FONT_IMPACT, extrude=0, m=M["ink"]))
# тиски: основание, неподвижная и подвижная губки, ходовой винт, вороток
vx, vy = -W / 2 + 0.17, -D / 2 + 0.12
P.append(C.box("vise_base", (0.16, 0.2, 0.04), (vx, vy, H + 0.02), bevel=0.005, m=M["vise"]))
P.append(C.box("vise_body", (0.13, 0.12, 0.07), (vx, vy + 0.03, H + 0.075), bevel=0.006, m=M["vise"]))
P.append(C.box("jaw_fix", (0.12, 0.018, 0.05), (vx, vy + 0.075, H + 0.1), bevel=0.003, m=M["steel"]))
P.append(C.box("jaw_mov", (0.12, 0.018, 0.05), (vx, vy - 0.03, H + 0.1), bevel=0.003, m=M["steel"]))
P.append(C.cyl("vise_screw", 0.011, 0.26, (vx, vy - 0.07, H + 0.06), rot=(R(90), 0, 0), verts=8, bevel=0, m=M["steel"]))
P.append(C.cyl("vise_t", 0.0075, 0.17, (vx, vy - 0.2, H + 0.06), rot=(0, R(90), 0), verts=6, bevel=0, m=M["black"]))
for sx in (-1, 1):
    P.append(C.sphere("vise_knob", 0.012, (vx + sx * 0.085, vy - 0.2, H + 0.06), seg=6, m=M["black"]))
# выдвинутый ящик под столешницей справа
P.append(C.box("apron", (0.5, 0.02, 0.1), (0.5, -D / 2 + 0.01, H - 0.09), bevel=0.003, m=M["wood"]))
dz, dy = H - 0.095, -D / 2 - 0.2
P.append(C.box("drawer_front", (0.46, 0.022, 0.09), (0.5, dy - 0.2, dz), bevel=0.004, m=M["woodb"]))
P.append(C.box("drawer_bottom", (0.44, 0.4, 0.012), (0.5, dy, dz - 0.04), bevel=0.002, m=M["wood"]))
for sx in (-1, 1):
    P.append(C.box("drawer_side", (0.012, 0.4, 0.07), (0.5 + sx * 0.22, dy, dz - 0.005), bevel=0.002, m=M["wood"]))
P.append(C.box("drawer_back", (0.44, 0.012, 0.07), (0.5, dy + 0.2, dz - 0.005), bevel=0.002, m=M["wood"]))
P.append(C.cyl("drawer_knob", 0.014, 0.025, (0.5, dy - 0.225, dz), rot=(R(90), 0, 0), verts=10, bevel=0.002, m=M["steel"]))
for k in range(6):
    P.append(C.cyl("dbolt%d" % k, 0.005, 0.03, (0.4 + (k % 3) * 0.06, dy + 0.05 - (k // 3) * 0.06, dz - 0.028), rot=(0, R(90), R(k * 31)), verts=6, bevel=0, m=M["bolt"]))
P.append(C.box("dtape", (0.06, 0.03, 0.03), (0.6, dy - 0.05, dz - 0.025), bevel=0.003, m=M["black"]))
# банки из-под кофе с болтами
for k, (x, y) in enumerate(((-0.45, 0.05), (-0.33, 0.12))):
    P.append(C.cyl("tin%d" % k, 0.05, 0.12, (x, y, H + 0.06), verts=14, bevel=0.002, m=M["tin"]))
    P.append(C.cyl("tin_label%d" % k, 0.0515, 0.06, (x, y, H + 0.06), verts=14, bevel=0, m=M["label"]))
    for b in range(5):
        P.append(C.cyl("tb%d_%d" % (k, b), 0.0045, 0.035, (x + random.uniform(-0.025, 0.025), y + random.uniform(-0.025, 0.025), H + 0.135 + b * 0.001), rot=(R(random.uniform(-25, 25)), R(random.uniform(-25, 25)), 0), verts=6, bevel=0, m=M["bolt"]))
# паяльник на подставке
P.append(C.box("sold_stand", (0.07, 0.07, 0.015), (-0.12, 0.2, H + 0.0075), bevel=0.002, m=M["steel"]))
for k in range(5):
    P.append(C.torus("sold_coil%d" % k, 0.02, 0.003, (-0.12, 0.2, H + 0.025 + k * 0.01), ms=10, mn=3, m=M["steel"]))
sold = C.cyl("sold_iron", 0.012, 0.2, (-0.07, 0.2, H + 0.06), rot=(0, R(70), 0), verts=8, bevel=0.002, m=M["red"])
P.append(sold)
P.append(C.cable("sold_wire", [(0.02, 0.2, H + 0.025), (0.15, 0.25, H + 0.01), (0.35, 0.3, H + 0.003), (0.55, 0.32, H - 0.1)], r=0.004, m=M["black"]))
# карбюратор на газете
P.append(C.box("news", (0.3, 0.22, 0.003), (0.35, 0.1, H + 0.0016), rot=(0, 0, R(12)), bevel=0, m=M["paper"], seg=1))
for k in range(4):
    P.append(C.box("news_ln", (0.22, 0.004, 0.0008), (0.35, 0.03 + k * 0.03, H + 0.0035), rot=(0, 0, R(12)), bevel=0, m=M["ink"], seg=1))
P.append(C.cyl("carb_body", 0.035, 0.09, (0.36, 0.1, H + 0.045), rot=(R(90), 0, R(12)), verts=12, bevel=0.003, m=M["steel"]))
P.append(C.cyl("carb_float", 0.04, 0.05, (0.36, 0.1, H + 0.05), verts=12, bevel=0.003, m=M["tin"]))
P.append(C.cyl("carb_choke", 0.025, 0.012, (0.31, 0.085, H + 0.05), rot=(R(90), 0, R(12)), verts=10, bevel=0, m=M["black"]))
for k in range(4):
    P.append(C.cyl("carb_screw", 0.005, 0.01, (0.4 + k * 0.012, 0.12, H + 0.01 + k * 0.004), verts=6, bevel=0, m=M["bolt"]))
# лампа на гусиной шее с конусным плафоном
P.append(C.cyl("lamp_base", 0.06, 0.03, (0.65, -0.1, H + 0.015), verts=12, bevel=0.004, m=M["lamp"]))
P.append(C.cable("lamp_neck", [(0.65, -0.1, H + 0.03), (0.65, -0.1, H + 0.22), (0.58, -0.13, H + 0.34), (0.46, -0.1, H + 0.34)], r=0.008, m=M["steel"], res=6))
P.append(C.cyl("lamp_shade", 0.015, 0.11, (0.43, -0.1, H + 0.31), rot=(0, 0, 0), verts=14, bevel=0.004, m=M["lamp"], r2=0.075))
P.append(C.sphere("bulb", 0.022, (0.43, -0.1, H + 0.27), seg=8, m=M["bulb"]))
P.append(C.cable("lamp_wire", [(0.65, -0.08, H + 0.01), (0.7, 0.2, H + 0.0), (0.76, 0.35, H - 0.2), (0.76, 0.34, 0.05)], r=0.005, m=M["black"]))
# масляные пятна и ветошь
for k, (x, y, r) in enumerate(((0.25, -0.06, 0.07), (-0.1, -0.1, 0.05), (0.55, -0.2, 0.06))):
    P.append(C.cyl("oil%d" % k, r, 0.002, (x, y, H + 0.001), verts=12, bevel=0, m=M["oil"]))
P.append(C.sphere("rag", 0.07, (0.1, 0.22, H + 0.02), scale=(1.5, 1.0, 0.45), seg=10, m=M["cloth"]))
# под столом: канистра с горлышком и ручкой, аккумулятор с проводами, стопка покрышек
cz = 0.2575
P.append(C.box("canister", (0.3, 0.14, 0.34), (-0.5, 0.0, cz + 0.17), bevel=0.014, m=M["canister"]))
P.append(C.cyl("can_neck", 0.026, 0.05, (-0.42, 0.0, cz + 0.365), verts=10, bevel=0.003, m=M["canister"]))
P.append(C.cyl("can_cap", 0.032, 0.02, (-0.42, 0.0, cz + 0.4), verts=10, bevel=0.003, m=M["black"]))
P.append(C.torus("can_handle", 0.045, 0.011, (-0.54, 0.0, cz + 0.37), rot=(R(90), 0, 0), ms=12, mn=4, m=M["canister"]))
P.append(C.box("battery", (0.24, 0.17, 0.2), (0.22, 0.0, cz + 0.1), bevel=0.008, m=M["black"]))
for sx, mm in ((-0.07, M["red"]), (0.07, M["steel"])):
    P.append(C.cyl("term", 0.013, 0.03, (0.22 + sx, -0.03, cz + 0.215), verts=8, bevel=0.002, m=mm))
P.append(C.cable("croc_a", [(0.15, -0.03, cz + 0.23), (0.05, -0.12, cz + 0.2), (-0.05, -0.12, cz + 0.05), (-0.1, -0.08, cz + 0.02)], r=0.006, m=M["red"]))
P.append(C.cable("croc_b", [(0.29, -0.03, cz + 0.23), (0.34, -0.12, cz + 0.15), (0.4, -0.1, cz + 0.05), (0.45, -0.05, cz + 0.02)], r=0.006, m=M["black"]))
P.append(C.box("croc1", (0.03, 0.012, 0.02), (-0.105, -0.08, cz + 0.018), bevel=0.002, m=M["red"], seg=1))
P.append(C.box("croc2", (0.03, 0.012, 0.02), (0.455, -0.05, cz + 0.018), bevel=0.002, m=M["steel"], seg=1))
for k in range(2):
    P.append(C.torus("tire%d" % k, 0.22, 0.07, (0.58 + k * 0.01, 0.0, 0.07 + 0.06 + k * 0.125), ms=16, mn=6, m=M["rubber"]))
P.append(C.cyl("rim", 0.15, 0.03, (0.58, 0.0, 0.165), verts=14, bevel=0.003, m=M["steel"]))

views = [((2.4, -2.1, 1.7), (0.0, 0.0, 0.7)), ((0.9, -1.1, 1.45), (-0.1, 0.1, 1.0))]
C.finish("g67_workbench", P, views, size=2048)
