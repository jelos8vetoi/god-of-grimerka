"""g67_box_nothing — фанерный ящик с железными уголками: навесной замок висит открытый, крышка lid на петлях (ось у задней кромки),
трафаретная надпись «НЕ ОТКРЫВАТЬ, ТАМ НИЧЕГО НЕТ», внутри пусто, сбоку почтовые наклейки. Крышка открывается поворотом узла lid
вокруг X на -100° (Blender; в Godot тот же знак)."""
import sys
import os
import math
sys.path.insert(0, os.path.dirname(__file__))
import g67_common as C

R = math.radians
C.reset()
M = {
    "ply": C.mat("ply", (0.55, 0.38, 0.2), under=(0.38, 0.27, 0.14), wear=0.42, dirt=1.0, rough=0.85, scale=45, bump=0.5, grain=(0.08, 1.0, 1.0)),
    "plyy": C.mat("plyy", (0.55, 0.38, 0.2), under=(0.38, 0.27, 0.14), wear=0.42, dirt=1.0, rough=0.85, scale=45, bump=0.5, grain=(1.0, 0.08, 1.0)),
    "ply_in": C.mat("ply_in", (0.62, 0.45, 0.26), under=(0.45, 0.32, 0.18), wear=0.2, dirt=0.9, rough=0.9, scale=18),
    "iron": C.mat("iron", (0.13, 0.24, 0.42), under=(0.34, 0.15, 0.07), wear=0.58, dirt=0.9, rough=0.5, scale=40),
    "steel": C.mat("steel", (0.5, 0.5, 0.52), under=(0.38, 0.2, 0.1), wear=0.6, dirt=0.9, rough=0.35, scale=60),
    "white": C.mat("white", (0.85, 0.83, 0.76), under=(0.7, 0.66, 0.56), wear=0.2, dirt=0.4, rough=0.7, scale=30, bump=0.0),
    "paper": C.mat("paper", (0.82, 0.78, 0.66), flat=True, dirt=0.8, rough=0.9),
    "stamp": C.mat("stamp", (0.7, 0.08, 0.07), flat=True, dirt=0.3, rough=0.7),
    "ink": C.mat("ink", (0.04, 0.04, 0.05), flat=True, dirt=0.0, rough=0.8),
}
P = []
W, D, H = 0.70, 0.60, 0.44          # ящик без крышки: стенки по 2 см
t = 0.02
P.append(C.box("bottom", (W, D, t), (0, 0, t * 0.5), bevel=0.004, m=M["ply_in"]))
P.append(C.box("wall_f", (W, t, H), (0, -D / 2 + t / 2, H / 2), bevel=0.004, m=M["ply"]))
P.append(C.box("wall_b", (W, t, H), (0, D / 2 - t / 2, H / 2), bevel=0.004, m=M["ply"]))
P.append(C.box("wall_l", (t, D - 2 * t, H), (-W / 2 + t / 2, 0, H / 2), bevel=0.004, m=M["plyy"]))
P.append(C.box("wall_r", (t, D - 2 * t, H), (W / 2 - t / 2, 0, H / 2), bevel=0.004, m=M["plyy"]))
# внутренняя планка-упор и пыль на дне (пусто!)
P.append(C.box("inner_rail", (W - 0.06, 0.02, 0.025), (0, D / 2 - 0.04, H - 0.05), bevel=0.002, m=M["ply_in"]))
# железные уголки по вертикальным рёбрам: две полосы, как скоба
for sx in (-1, 1):
    for sy in (-1, 1):
        P.append(C.box("ang_a", (0.035, 0.004, H), (sx * (W / 2 - 0.0175), sy * (D / 2 + 0.002), H / 2), bevel=0.0008, m=M["iron"], seg=1))
        P.append(C.box("ang_b", (0.004, 0.035, H), (sx * (W / 2 + 0.002), sy * (D / 2 - 0.0175), H / 2), bevel=0.0008, m=M["iron"], seg=1))
        for k in range(3):
            zz = 0.07 + k * 0.15
            P.append(C.cyl("rivet", 0.0045, 0.004, (sx * (W / 2 - 0.0175), sy * (D / 2 + 0.005), zz), rot=(R(90), 0, 0), verts=8, bevel=0, m=M["steel"]))
# стягивающие полосы по верхней кромке и по низу
P.append(C.box("band_t_f", (W + 0.01, 0.005, 0.03), (0, -D / 2 - 0.0025, H - 0.02), bevel=0.001, m=M["iron"], seg=1))
P.append(C.box("band_b_f", (W + 0.01, 0.005, 0.03), (0, -D / 2 - 0.0025, 0.03), bevel=0.001, m=M["iron"], seg=1))
# лицевая надпись трафаретом (белая краска)
P.append(C.text("st1", "НЕ ОТКРЫВАТЬ,", 0.055, (0, -D / 2 - 0.0035, 0.265), rot=(R(90), 0, 0), font=C.FONT_IMPACT, extrude=0, m=M["white"]))
P.append(C.text("st2", "ТАМ НИЧЕГО НЕТ", 0.055, (0, -D / 2 - 0.0035, 0.19), rot=(R(90), 0, 0), font=C.FONT_IMPACT, extrude=0, m=M["white"]))
# почтовые наклейки на правой стенке
for k, (yy, zz, rot) in enumerate(((-0.12, 0.30, 4), (0.08, 0.22, -6), (-0.02, 0.1, 2))):
    P.append(C.box("lab%d" % k, (0.0015, 0.13, 0.075), (W / 2 + 0.001, yy, zz), rot=(R(rot), 0, 0), bevel=0, m=M["paper"], seg=1))
    P.append(C.box("lab_st%d" % k, (0.0018, 0.035, 0.012), (W / 2 + 0.0015, yy + 0.03, zz - 0.02), bevel=0, m=M["stamp"], seg=1))
    P.append(C.box("lab_ln%d" % k, (0.0018, 0.09, 0.004), (W / 2 + 0.0015, yy - 0.012, zz + 0.012), bevel=0, m=M["ink"], seg=1))
# крышка на петлях: ось по X у задней кромки (y = +D/2), поверх ящика
lid_parts = []
lz = H + 0.0125
lid_parts.append(C.box("lid_plate", (W + 0.02, D + 0.02, 0.025), (0, 0, lz), bevel=0.005, m=M["plyy"]))
lid_parts.append(C.box("lid_cross1", (W - 0.04, 0.05, 0.015), (0, -0.16, H + 0.0325), bevel=0.003, m=M["ply"]))
lid_parts.append(C.box("lid_cross2", (W - 0.04, 0.05, 0.015), (0, 0.16, H + 0.0325), bevel=0.003, m=M["ply"]))
for sx in (-1, 1):
    lid_parts.append(C.box("lid_iron", (0.04, D + 0.02, 0.004), (sx * (W / 2 - 0.02), 0, lz + 0.0145), bevel=0.001, m=M["iron"], seg=1))
lid_parts.append(C.box("hasp", (0.045, 0.07, 0.004), (0, -D / 2 - 0.012, lz + 0.0145), bevel=0.0008, m=M["steel"], seg=1))
lid_parts.append(C.box("hasp_ring", (0.03, 0.01, 0.045), (0, -D / 2 - 0.0125, lz - 0.005), bevel=0.0008, m=M["steel"], seg=1))
lid = C.join("lid", lid_parts)
C.pivot(lid, (0, D / 2, H + 0.0125))
P.append(lid)
# петли: накладки на задней стенке
for sx in (-0.22, 0.22):
    P.append(C.box("hinge", (0.07, 0.006, 0.05), (sx, D / 2 + 0.003, H - 0.01), bevel=0.001, m=M["steel"], seg=1))
    P.append(C.cyl("hinge_pin", 0.0075, 0.075, (sx, D / 2 + 0.008, H + 0.006), rot=(0, R(90), 0), verts=8, bevel=0, m=M["steel"]))
# скоба замка на ящике и открытый навесной замок
P.append(C.box("staple", (0.03, 0.012, 0.03), (0, -D / 2 - 0.006, H - 0.045), bevel=0.001, m=M["steel"], seg=1))
lock_body = C.box("lock_body", (0.052, 0.022, 0.045), (0.02, -D / 2 - 0.02, H - 0.1), rot=(0, R(-12), 0), bevel=0.004, m=M["steel"])
shackle = C.torus("shackle", 0.0155, 0.0042, (0.026, -D / 2 - 0.02, H - 0.063), rot=(R(90), R(40), R(-12)), ms=16, mn=6, m=M["steel"])
P.append(lock_body)
P.append(shackle)
P.append(C.cyl("keyhole", 0.0045, 0.003, (0.02, -D / 2 - 0.0325, H - 0.108), rot=(R(90), 0, 0), verts=8, bevel=0, m=M["ink"]))

views = [((1.15, -1.25, 0.95), (0.0, 0.0, 0.25)), ((0.42, -0.62, 0.52), (0.0, -0.3, 0.3))]
C.finish("g67_box_nothing", P, views, size=2048)
