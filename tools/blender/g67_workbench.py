"""g67_workbench — гаражный верстак: уголок и доски, тиски, раскиданный инструмент, банка с болтами, настольная лампа на гусиной шее,
масляные пятна, ветошь, под столом канистра и аккумулятор."""
import sys
import os
import math
sys.path.insert(0, os.path.dirname(__file__))
import g67_common as C

R = math.radians
C.reset()
M = {
    "wood": C.mat("wood", (0.48, 0.34, 0.19), under=(0.32, 0.22, 0.12), wear=0.45, dirt=1.0, rough=0.85, scale=35, grain=(0.08, 1.0, 1.0)),
    "angle": C.mat("angle", (0.16, 0.3, 0.2), under=(0.34, 0.15, 0.07), wear=0.55, dirt=1.0, rough=0.5, scale=40),
    "steel": C.mat("steel", (0.55, 0.56, 0.58), under=(0.4, 0.2, 0.1), wear=0.5, dirt=1.0, rough=0.4, scale=80),
    "vise": C.mat("vise", (0.12, 0.2, 0.4), under=(0.34, 0.15, 0.07), wear=0.6, dirt=1.0, rough=0.5, scale=60),
    "red": C.mat("red", (0.7, 0.08, 0.06), under=(0.35, 0.15, 0.08), wear=0.4, dirt=0.9, rough=0.5, scale=90),
    "oil": C.mat("oil", (0.03, 0.025, 0.02), flat=True, dirt=0.0, rough=0.25),
    "cloth": C.mat("cloth", (0.45, 0.4, 0.3), flat=True, dirt=1.0, rough=0.95),
    "glass": C.mat("glass", (0.55, 0.62, 0.58), flat=True, dirt=0.7, rough=0.15),
    "bolt": C.mat("bolt", (0.38, 0.33, 0.3), under=(0.35, 0.17, 0.08), wear=0.7, dirt=0.8, rough=0.5, scale=150),
    "black": C.mat("black", (0.04, 0.04, 0.045), flat=True, dirt=0.8, rough=0.6),
    "canister": C.mat("canister", (0.14, 0.38, 0.22), under=(0.34, 0.15, 0.07), wear=0.55, dirt=1.0, rough=0.5, scale=50),
    "lamp": C.mat("lamp", (0.76, 0.72, 0.6), under=(0.4, 0.3, 0.2), wear=0.35, dirt=0.9, rough=0.45, scale=70),
    "bulb": C.mat("bulb", (1.0, 0.92, 0.7), flat=True, dirt=0.0, rough=0.2),
}
P = []
W, D, H = 1.6, 0.7, 0.9
# столешница: три доски вдоль и стальная окантовка из уголка
for k in range(3):
    P.append(C.box("top%d" % k, (W, D / 3 - 0.004, 0.04), (0, -D / 3 + k * D / 3, H - 0.02), rot=(0, 0, R((k - 1) * 0.4)), bevel=0.004, m=M["wood"]))
P.append(C.box("edge_f", (W + 0.02, 0.035, 0.045), (0, -D / 2 - 0.0, H - 0.025), bevel=0.003, m=M["angle"]))
P.append(C.box("edge_b", (W + 0.02, 0.035, 0.045), (0, D / 2, H - 0.025), bevel=0.003, m=M["angle"]))
for sx in (-1, 1):
    P.append(C.box("edge_s", (0.035, D, 0.045), (sx * (W / 2 + 0.0), 0, H - 0.025), bevel=0.003, m=M["angle"]))
# ножки-уголки, стяжки и нижняя полка
for sx in (-1, 1):
    for sy in (-1, 1):
        x, y = sx * (W / 2 - 0.03), sy * (D / 2 - 0.03)
        P.append(C.box("leg_a", (0.05, 0.005, H - 0.045), (x, y + sy * 0.0225, (H - 0.045) / 2), bevel=0.001, m=M["angle"], seg=1))
        P.append(C.box("leg_b", (0.005, 0.05, H - 0.045), (x + sx * 0.0225, y, (H - 0.045) / 2), bevel=0.001, m=M["angle"], seg=1))
        P.append(C.cyl("foot", 0.032, 0.012, (x, y, 0.006), verts=10, bevel=0.002, m=M["steel"]))
for sy in (-1, 1):
    P.append(C.box("rail", (W - 0.06, 0.04, 0.03), (0, sy * (D / 2 - 0.03), 0.22), bevel=0.002, m=M["angle"]))
P.append(C.box("shelf", (W - 0.06, D - 0.05, 0.025), (0, 0, 0.245), rot=(0, 0, R(-0.5)), bevel=0.003, m=M["wood"]))
for sx in (-0.4, 0.4):
    P.append(C.box("brace", (0.03, D - 0.06, 0.03), (sx, 0, 0.58), bevel=0.002, m=M["angle"]))
# сварные швы валиком у ног
for sx in (-1, 1):
    for sy in (-1, 1):
        P.append(C.torus("weld", 0.018, 0.005, (sx * (W / 2 - 0.03), sy * (D / 2 - 0.03), 0.22), ms=10, mn=4, m=M["bolt"]))
# тиски у левого переднего угла: корпус, подвижная губка, винт с ручкой
vx, vy = -W / 2 + 0.16, -D / 2 + 0.05
P.append(C.box("vise_base", (0.15, 0.1, 0.05), (vx, vy, H + 0.025), bevel=0.005, m=M["vise"]))
P.append(C.box("vise_jaw_f", (0.14, 0.04, 0.06), (vx, vy - 0.045, H + 0.075), bevel=0.004, m=M["vise"]))
P.append(C.box("vise_jaw_b", (0.14, 0.04, 0.06), (vx, vy + 0.05, H + 0.075), bevel=0.004, m=M["steel"]))
P.append(C.cyl("vise_screw", 0.011, 0.22, (vx, vy - 0.1, H + 0.04), rot=(R(90), 0, 0), verts=8, bevel=0, m=M["steel"]))
P.append(C.cyl("vise_handle", 0.008, 0.16, (vx, vy - 0.205, H + 0.04), rot=(0, R(90), 0), verts=6, bevel=0, m=M["black"]))
# инструмент: ключи, молоток, отвёртки
def wrench(nm, x, y, a, ln):
    P.append(C.box(nm, (ln, 0.022, 0.008), (x, y, H + 0.004), rot=(0, 0, R(a)), bevel=0.002, m=M["steel"], seg=1))
    for e in (-1, 1):
        P.append(C.torus(nm + "_h", 0.014, 0.006, (x + e * ln / 2 * math.cos(R(a)), y + e * ln / 2 * math.sin(R(a)), H + 0.006), ms=8, mn=3, m=M["steel"]))
wrench("wr1", 0.12, -0.18, 12, 0.24)
wrench("wr2", 0.26, -0.1, -28, 0.2)
wrench("wr3", -0.18, 0.1, 70, 0.17)
P.append(C.cyl("hm_handle", 0.014, 0.3, (0.5, 0.12, H + 0.014), rot=(0, R(90), R(24)), verts=8, bevel=0.002, m=M["wood"]))
P.append(C.box("hm_head", (0.1, 0.035, 0.035), (0.5 + 0.145 * math.cos(R(24)) * -1, 0.12 + 0.145 * math.sin(R(24)) * -1, H + 0.02), rot=(0, 0, R(24)), bevel=0.004, m=M["steel"]))
for k, (x, y, a) in enumerate(((0.05, 0.16, 105), (0.33, 0.2, 80))):
    P.append(C.cyl("sd%d_shaft" % k, 0.0045, 0.17, (x, y, H + 0.006), rot=(0, R(90), R(a)), verts=6, bevel=0, m=M["steel"]))
    P.append(C.cyl("sd%d_grip" % k, 0.013, 0.09, (x + 0.12 * math.cos(R(a)), y + 0.12 * math.sin(R(a)), H + 0.014), rot=(0, R(90), R(a)), verts=8, bevel=0.002, m=M["red"]))
# банка с болтами и россыпь
P.append(C.cyl("jar", 0.05, 0.13, (-0.5, -0.1, H + 0.065), verts=14, bevel=0.003, m=M["glass"]))
P.append(C.cyl("jar_lid", 0.045, 0.012, (-0.5, -0.1, H + 0.136), verts=12, bevel=0.002, m=M["steel"]))
for k in range(9):
    P.append(C.cyl("bolt%d" % k, 0.0045, 0.03, (-0.45 + (k % 3) * 0.04 + 0.02 * (k // 3), -0.34 + (k // 3) * 0.04, H + 0.006), rot=(0, R(90), R(k * 37)), verts=6, bevel=0, m=M["bolt"]))
# настольная лампа на гусиной шее
P.append(C.cyl("lamp_base", 0.06, 0.03, (0.62, 0.22, H + 0.015), verts=12, bevel=0.004, m=M["lamp"]))
P.append(C.cable("lamp_neck", [(0.62, 0.22, H + 0.03), (0.62, 0.22, H + 0.14), (0.58, 0.18, H + 0.27), (0.46, 0.1, H + 0.3)], r=0.009, m=M["steel"], res=6))
P.append(C.cyl("lamp_shade", 0.075, 0.1, (0.42, 0.09, H + 0.27), rot=(0, R(110), R(25)), verts=14, bevel=0.004, m=M["lamp"], r2=0.03))
P.append(C.sphere("bulb", 0.022, (0.4, 0.085, H + 0.24), seg=8, m=M["bulb"]))
P.append(C.cable("lamp_wire", [(0.62, 0.24, H + 0.01), (0.7, 0.33, H - 0.05), (0.78, 0.3, H - 0.4), (0.78, 0.2, 0.0)], r=0.005, m=M["black"]))
# масляные пятна и ветошь
for k, (x, y, r) in enumerate(((0.2, -0.05, 0.09), (-0.05, 0.02, 0.06), (0.55, -0.15, 0.07))):
    P.append(C.cyl("oil%d" % k, r, 0.002, (x, y, H + 0.001), verts=12, bevel=0, m=M["oil"]))
P.append(C.sphere("rag", 0.07, (0.7, -0.17, H + 0.02), scale=(1.5, 1.0, 0.45), seg=10, m=M["cloth"]))
# под столом: канистра и аккумулятор на полке
P.append(C.box("canister", (0.3, 0.14, 0.34), (-0.62, 0.0, 0.2575 + 0.17), bevel=0.012, m=M["canister"]))
P.append(C.cyl("can_cap", 0.025, 0.03, (-0.52, 0.0, 0.6), verts=10, bevel=0.003, m=M["black"]))
P.append(C.box("can_handle", (0.1, 0.03, 0.03), (-0.62, 0.0, 0.6), bevel=0.004, m=M["canister"]))
P.append(C.box("battery", (0.24, 0.17, 0.2), (0.3, 0.0, 0.2575 + 0.1), bevel=0.006, m=M["black"]))
for sx in (-0.07, 0.07):
    P.append(C.cyl("term", 0.013, 0.025, (0.3 + sx, -0.03, 0.2575 + 0.2125), verts=8, bevel=0.002, m=M["steel"]))
P.append(C.cable("batt_cable", [(0.23, -0.03, 0.47), (0.1, -0.1, 0.36), (-0.05, -0.1, 0.27)], r=0.007, m=M["red"]))

views = [((2.2, -2.1, 1.5), (0.0, 0.0, 0.55)), ((0.95, -0.95, 1.25), (-0.05, -0.05, 0.9))]
C.finish("g67_workbench", P, views)
