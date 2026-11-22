"""g67_puhosos — «ПУХОСОС-8», самодельная уборочная машина: бак от стиральной машины на тележке с колёсами от коляски, мотор от «Дружбы»,
гофрошланг (узел hose, ось — у бака) с воронкой из ведра, выхлоп из водосточной трубы, велосипедный руль сзади, табличка, мешок для пуха."""
import sys
import os
import math
sys.path.insert(0, os.path.dirname(__file__))
import g67_common as C
from mathutils import Vector

R = math.radians
C.reset()
M = {
    "wood": C.mat("wood", (0.5, 0.36, 0.2), under=(0.34, 0.24, 0.13), wear=0.4, dirt=1.0, rough=0.85, scale=30, grain=(0.1, 1.0, 1.0)),
    "tank": C.mat("tank", (0.93, 0.94, 0.92), under=(0.36, 0.17, 0.08), wear=0.33, dirt=0.8, rough=0.3, scale=11),
    "motor": C.mat("motor", (0.85, 0.42, 0.06), under=(0.35, 0.16, 0.06), wear=0.55, dirt=1.0, rough=0.5, scale=45),
    "steel": C.mat("steel", (0.55, 0.56, 0.58), under=(0.4, 0.2, 0.1), wear=0.5, dirt=0.9, rough=0.4, scale=45),
    "zinc": C.mat("zinc", (0.6, 0.62, 0.65), under=(0.42, 0.22, 0.12), wear=0.45, dirt=1.0, rough=0.4, scale=30),
    "pipe": C.mat("pipe", (0.32, 0.18, 0.12), under=(0.3, 0.14, 0.07), wear=0.6, dirt=1.0, rough=0.55, scale=30),
    "rubber": C.mat("rubber", (0.04, 0.04, 0.045), flat=True, dirt=0.8, rough=0.8),
    "hosec": C.mat("hosec", (0.1, 0.16, 0.2), flat=True, dirt=0.9, rough=0.5),
    "plate": C.mat("plate", (0.4, 0.07, 0.1), under=(0.3, 0.14, 0.08), wear=0.3, dirt=0.8, rough=0.4, scale=60),
    "gold": C.mat("gold", (0.8, 0.62, 0.2), flat=True, dirt=0.4, rough=0.35),
    "cloth": C.mat("cloth", (0.36, 0.34, 0.3), flat=True, dirt=1.0, rough=0.95),
    "tape": C.mat("tape", (0.1, 0.2, 0.62), flat=True, dirt=0.7, rough=0.5),
    "rust": C.mat("rust", (0.35, 0.16, 0.08), under=(0.3, 0.14, 0.07), wear=0.8, dirt=1.0, rough=0.7, scale=40),
}
P = []

# тележка: платформа на брусьях, перекос и подпорки
P.append(C.box("deck", (0.95, 0.62, 0.035), (0.0, 0.0, 0.2), rot=(0, 0, R(1.5)), bevel=0.006, m=M["wood"]))
for sx in (-0.33, 0.33):
    P.append(C.box("beam", (0.06, 0.66, 0.05), (sx, 0.0, 0.165), bevel=0.005, m=M["wood"]))
P.append(C.box("brace", (0.8, 0.03, 0.03), (0, 0.22, 0.21), rot=(0, 0, R(-3)), bevel=0.003, m=M["steel"]))
P.append(C.box("cleat", (0.08, 0.5, 0.03), (0.46, 0.0, 0.215), bevel=0.003, m=M["wood"]))


def wheel(name, r, x, y, w=0.035, spokes=4):
    z = r
    P.append(C.torus(name + "_tire", r - 0.02, 0.022, (x, y, z), rot=(0, R(90), 0), ms=14, mn=5, m=M["rubber"]))
    P.append(C.cyl(name + "_rim", r - 0.03, w, (x, y, z), rot=(0, R(90), 0), verts=16, bevel=0.002, m=M["steel"]))
    P.append(C.cyl(name + "_hub", 0.02, w + 0.03, (x, y, z), rot=(0, R(90), 0), verts=8, bevel=0.002, m=M["rust"]))
    for k in range(spokes):
        a = 2 * math.pi * k / spokes
        sp = C.box(name + "_spoke%d" % k, (w * 0.5, 0.008, r - 0.04), (x + (0.02 if x > 0 else -0.02), y + 0, z), bevel=0, m=M["steel"], seg=1)
        sp.rotation_euler = (a, 0, 0)
        sp.location = (x + (0.02 if x > 0 else -0.02), y + math.sin(a) * 0.5 * (r - 0.04) * -1, z + math.cos(a) * 0.5 * (r - 0.04))
        P.append(sp)


wheel("wl", 0.14, -0.5, 0.17)
wheel("wr", 0.14, 0.5, 0.17)
P.append(C.cyl("axle", 0.012, 1.0, (0, 0.17, 0.14), rot=(0, R(90), 0), verts=8, bevel=0, m=M["steel"]))
for sx in (-0.38, 0.38):
    P.append(C.cyl("caster_w%.2f" % sx, 0.055, 0.03, (sx, -0.25, 0.055), rot=(0, R(90), 0), verts=14, bevel=0.003, m=M["rubber"]))
    P.append(C.box("caster_fork", (0.045, 0.03, 0.08), (sx, -0.25, 0.12), bevel=0.003, m=M["steel"]))

# бак от стиральной машины: эмалевый барабан с крышкой и ручками
P.append(C.cyl("tank", 0.27, 0.56, (-0.14, 0.05, 0.5), verts=24, bevel=0.012, m=M["tank"], seg=2))
P.append(C.cyl("tank_rim", 0.285, 0.04, (-0.14, 0.05, 0.78), verts=24, bevel=0.006, m=M["tank"]))
P.append(C.cyl("tank_lid", 0.25, 0.035, (-0.14, 0.05, 0.815), verts=24, bevel=0.01, m=M["zinc"]))
P.append(C.cyl("lid_knob", 0.03, 0.04, (-0.14, 0.05, 0.855), verts=10, bevel=0.005, m=M["rubber"]))
for sx in (-1, 1):
    P.append(C.torus("tank_handle", 0.045, 0.011, (-0.14 + sx * 0.285, 0.05, 0.62), rot=(R(90), 0, R(90)), ms=12, mn=5, m=M["steel"]))
for z in (0.3, 0.7):
    P.append(C.torus("strap", 0.272, 0.009, (-0.14, 0.05, z), ms=16, mn=3, m=M["steel"]))
# крепёж бака к платформе
for ang in (0, 120, 240):
    P.append(C.box("tank_leg", (0.05, 0.02, 0.07), (-0.14 + 0.25 * math.cos(R(ang + 30)), 0.05 + 0.25 * math.sin(R(ang + 30)), 0.24), bevel=0.003, m=M["steel"]))

# табличка ПУХОСОС-8 на баке: бордовая плашка и золотые буквы
P.append(C.box("plate", (0.3, 0.006, 0.105), (-0.14, -0.222, 0.56), rot=(0, 0, R(-2)), bevel=0.004, m=M["plate"]))
P.append(C.text("plt1", "ПУХОСОС-8", 0.052, (-0.14, -0.2275, 0.575), rot=(R(90), 0, R(-2)), font=C.FONT_IMPACT, extrude=0, m=M["gold"]))
P.append(C.text("plt2", "сосёт пух · пуха нет", 0.0135, (-0.14, -0.2275, 0.525), rot=(R(90), 0, R(-2)), font=C.FONT_BOLD, extrude=0, m=M["gold"]))
for sx in (-0.275, -0.005):
    P.append(C.cyl("plate_rivet", 0.005, 0.004, (sx, -0.2265, 0.56), rot=(R(90), 0, 0), verts=8, bevel=0, m=M["steel"]))

# мотор от «Дружбы»: оранжевый кожух, воздушный фильтр, ручка стартёра
P.append(C.box("motor", (0.22, 0.2, 0.2), (0.3, 0.1, 0.33), bevel=0.012, m=M["motor"]))
P.append(C.cyl("fan", 0.085, 0.07, (0.42, 0.1, 0.34), rot=(0, R(90), 0), verts=14, bevel=0.004, m=M["steel"]))
P.append(C.cyl("filter", 0.055, 0.07, (0.3, 0.1, 0.46), verts=12, bevel=0.005, m=M["zinc"]))
P.append(C.cyl("starter", 0.03, 0.035, (0.3, 0.215, 0.36), rot=(R(90), 0, 0), verts=10, bevel=0.004, m=M["rubber"]))
P.append(C.cable("starter_cord", [(0.3, 0.23, 0.36), (0.33, 0.27, 0.3), (0.36, 0.3, 0.25)], r=0.005, m=M["rubber"]))
P.append(C.cyl("starter_grip", 0.013, 0.07, (0.36, 0.3, 0.24), rot=(0, R(90), 0), verts=8, bevel=0.002, m=M["tape"]))
# выхлоп из водосточной трубы с колпаком
P.append(C.cyl("exhaust", 0.038, 0.52, (0.2, 0.2, 0.62), verts=12, bevel=0.004, m=M["pipe"]))
P.append(C.cyl("exhaust_cap", 0.065, 0.022, (0.2, 0.2, 0.9), verts=12, bevel=0.004, m=M["pipe"], r2=0.02))
for z in (0.45, 0.7):
    P.append(C.torus("exh_clamp", 0.04, 0.007, (0.2, 0.2, z), ms=14, mn=4, m=M["steel"]))

# руль от велосипеда сзади: стойка, перекладина, ручки
P.append(C.cyl("stem", 0.015, 0.7, (0.0, 0.3, 0.55), rot=(R(-12), 0, 0), verts=8, bevel=0.002, m=M["steel"]))
P.append(C.cyl("bar", 0.011, 0.52, (0.0, 0.34, 0.9), rot=(0, R(90), 0), verts=8, bevel=0.002, m=M["steel"]))
for sx in (-0.27, 0.27):
    P.append(C.cyl("grip", 0.017, 0.1, (sx, 0.34, 0.9), rot=(0, R(90), 0), verts=10, bevel=0.003, m=M["rubber"]))
P.append(C.cyl("brake_lever", 0.006, 0.12, (-0.22, 0.31, 0.905), rot=(R(80), 0, R(-10)), verts=6, bevel=0, m=M["steel"]))
P.append(C.cable("brake_cable", [(-0.22, 0.31, 0.9), (-0.25, 0.28, 0.7), (-0.2, 0.2, 0.4)], r=0.004, m=M["rubber"]))

# мешок для пуха: пустой, обвис (сдутая «подушка»), на хомуте у патрубка
neck = C.cyl("bag_neck", 0.04, 0.1, (0.18, -0.16, 0.5), rot=(0, R(90), 0), verts=10, bevel=0.004, m=M["zinc"])
P.append(neck)
bag = C.sphere("bag", 0.15, (0.27, -0.17, 0.3), scale=(0.5, 0.12, 1.35), seg=14, m=M["cloth"])
bag.rotation_euler = (0, R(6), 0)
P.append(bag)
P.append(C.torus("bag_clamp", 0.043, 0.008, (0.215, -0.16, 0.5), rot=(0, R(90), 0), ms=12, mn=4, m=M["steel"]))
P.append(C.torus("bag_tape", 0.043, 0.012, (0.235, -0.16, 0.5), rot=(0, R(90), 0), ms=12, mn=4, m=M["tape"]))

# гофрошланг (узел hose, ось у бака) с воронкой из ведра
hpts = [(-0.14, -0.27, 0.43), (-0.2, -0.45, 0.35), (-0.33, -0.55, 0.22), (-0.48, -0.62, 0.17)]
hose_parts = [C.cable("hose_tube", hpts, r=0.031, m=M["hosec"], res=6)]
for k in range(7):
    t = k / 6.0
    # точка на ломаной с кубическим сглаживанием
    seg_i = min(2, int(t * 3))
    u = t * 3 - seg_i
    a, b = hpts[seg_i], hpts[seg_i + 1]
    p = [a[i] + (b[i] - a[i]) * u for i in range(3)]
    hose_parts.append(C.torus("hrib%d" % k, 0.031, 0.0065, tuple(p), rot=(R(90), 0, R(35)), ms=10, mn=4, m=M["hosec"]))
funnel = C.cyl("funnel", 0.045, 0.22, (-0.56, -0.66, 0.11), rot=(R(18), 0, R(8)), verts=18, bevel=0.005, m=M["zinc"], r2=0.17)
hose_parts.append(funnel)
hose_parts.append(C.torus("funnel_rim", 0.17, 0.011, (-0.585, -0.775, 0.215), rot=(R(18), 0, R(8)), ms=18, mn=5, m=M["zinc"]))
hose_parts.append(C.torus("hose_clamp", 0.036, 0.008, (-0.17, -0.34, 0.4), rot=(R(80), 0, 0), ms=12, mn=4, m=M["steel"]))
hose = C.join("hose", hose_parts)
C.pivot(hose, (-0.14, -0.27, 0.43))
P.append(hose)
P.append(C.cyl("hose_port", 0.045, 0.06, (-0.14, -0.28, 0.43), rot=(R(90), 0, 0), verts=12, bevel=0.004, m=M["steel"]))
# провод от мотора к баку и изолента
P.append(C.cable("wire", [(0.2, 0.0, 0.4), (0.08, -0.12, 0.34), (-0.05, -0.2, 0.46), (-0.12, -0.18, 0.56)], r=0.006, m=M["tape"]))
P.append(C.cyl("motor_tape", 0.115, 0.03, (0.3, 0.1, 0.27), verts=14, bevel=0, m=M["tape"]))

views = [((1.9, -1.9, 1.35), (0.0, 0.0, 0.42)), ((0.55, -1.05, 0.62), (-0.14, -0.2, 0.52))]
C.finish("g67_puhosos", P, views, size=2048)
