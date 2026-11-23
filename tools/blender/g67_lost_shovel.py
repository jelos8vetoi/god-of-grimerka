"""g67_lost_shovel — та самая пропавшая лопата: снеговая, фанерная, с железной кромкой, черенок перемотан изолентой. Модель стоит вертикально
(длинная ось — Z, высота 1,4 м); на крышу гаража кладётся поворотом в коде. Пасхалка без текста."""
import sys
import os
import math
sys.path.insert(0, os.path.dirname(__file__))
import g67_common as C

R = math.radians
C.reset()
M = {
    "ply": C.mat("ply", (0.55, 0.4, 0.22), under=(0.36, 0.26, 0.14), wear=0.45, dirt=1.0, rough=0.85, scale=60, grain=(0.1, 1.0, 1.0)),
    "stick": C.mat("stick", (0.5, 0.36, 0.2), under=(0.34, 0.24, 0.13), wear=0.4, dirt=0.9, rough=0.8, scale=70, grain=(1.0, 1.0, 0.08)),
    "iron": C.mat("iron", (0.48, 0.5, 0.52), under=(0.4, 0.2, 0.1), wear=0.6, dirt=1.0, rough=0.4, scale=80),
    "tape": C.mat("tape", (0.1, 0.2, 0.62), flat=True, dirt=0.8, rough=0.5),
    "rivet": C.mat("rivet", (0.35, 0.3, 0.28), under=(0.35, 0.17, 0.08), wear=0.7, dirt=0.8, rough=0.5, scale=150),
}
P = []
# совок (внизу): фанера с лёгким изгибом и железная окантовка
P.append(C.box("scoop", (0.25, 0.016, 0.31), (0, 0, 0.16), rot=(R(-3), 0, 0), bevel=0.004, m=M["ply"]))
P.append(C.box("edge", (0.255, 0.022, 0.035), (0, 0.001, 0.015), bevel=0.003, m=M["iron"]))
for sx in (-1, 1):
    P.append(C.box("side", (0.018, 0.028, 0.29), (sx * 0.1265, 0.0, 0.165), bevel=0.003, m=M["iron"]))
for sx in (-0.09, -0.03, 0.03, 0.09):
    P.append(C.cyl("rivet", 0.005, 0.006, (sx, -0.013, 0.015), rot=(R(90), 0, 0), verts=6, bevel=0, m=M["rivet"]))
# обойма, держащая черенок, и сам черенок (чуть кривой)
P.append(C.box("clamp", (0.07, 0.04, 0.09), (0, 0.022, 0.33), bevel=0.004, m=M["iron"]))
P.append(C.cyl("stick", 0.0165, 1.12, (0, 0.028, 0.88), rot=(R(1.2), 0, 0), verts=10, bevel=0.002, m=M["stick"]))
# Д-образная ручка вверху
P.append(C.cyl("grip", 0.016, 0.16, (0, 0.04, 1.395), rot=(0, R(90), 0), verts=10, bevel=0.002, m=M["stick"]))
for sx in (-1, 1):
    P.append(C.cyl("grip_leg", 0.0145, 0.1, (sx * 0.075, 0.036, 1.35), verts=8, bevel=0.002, m=M["stick"]))
# изолента: три витка и хвост на черенке
for z in (1.02, 1.045, 1.07):
    P.append(C.cyl("tape", 0.0215, 0.02, (0, 0.03, z), verts=12, bevel=0, m=M["tape"]))
P.append(C.box("tape_tail", (0.02, 0.003, 0.05), (0.014, 0.004, 1.0), rot=(0, R(8), R(20)), bevel=0, m=M["tape"], seg=1))
views = [((1.9, -2.3, 1.1), (0.0, 0.0, 0.7)), ((0.45, -0.6, 0.3), (0.0, 0.0, 0.2))]
C.finish("g67_lost_shovel", P, views)
