"""g67_swing_set — дворовые качели: сварная П-рама из труб, облезлая в три слоя краска, сиденье-доска на цепях — узел seat
(ось на верхней перекладине), вторая подвеска оборвана: висит одна цепь. Тонкая шапка снега на перекладине."""
import sys
import os
import math
sys.path.insert(0, os.path.dirname(__file__))
import g67_common as C
from mathutils import Vector

R = math.radians
C.reset()
M = {
    "frame": C.mat("frame", (0.1, 0.24, 0.48), under=(0.36, 0.16, 0.07), wear=0.6, dirt=1.0, rough=0.5, scale=14),
    "paint2": C.mat("paint2", (0.55, 0.1, 0.12), under=(0.36, 0.16, 0.07), wear=0.55, dirt=1.0, rough=0.5, scale=14),
    "chain": C.mat("chain", (0.3, 0.3, 0.32), under=(0.38, 0.17, 0.08), wear=0.75, dirt=1.0, rough=0.5, scale=60),
    "seat": C.mat("seat", (0.5, 0.35, 0.18), under=(0.34, 0.24, 0.13), wear=0.5, dirt=1.0, rough=0.85, scale=35, grain=(1.0, 0.08, 1.0)),
    "snow": C.mat("snow", (0.93, 0.95, 0.99), flat=True, dirt=0.12, rough=0.9),
    "steel": C.mat("steel", (0.5, 0.5, 0.52), under=(0.4, 0.2, 0.1), wear=0.6, dirt=1.0, rough=0.4, scale=40),
    "weld": C.mat("weld", (0.28, 0.24, 0.22), under=(0.34, 0.16, 0.07), wear=0.7, dirt=1.0, rough=0.7, scale=60),
}
P = []
TOP = 2.15
HX, HY = 1.2, 0.75


def pipe(nm, a, b, r, m):
    a, b = Vector(a), Vector(b)
    mid = (a + b) / 2
    c = C.cyl(nm, r, (b - a).length, tuple(mid), verts=12, bevel=0.002, m=m)
    c.rotation_euler = Vector((0, 0, 1)).rotation_difference(b - a).to_euler()
    return c


# две A-образные стойки и верхняя труба
for sx in (-HX, HX):
    for sy in (-HY, HY):
        P.append(pipe("leg", (sx, sy, 0.0), (sx, 0.0, TOP), 0.04, M["frame"]))
        P.append(C.box("foot", (0.2, 0.14, 0.012), (sx, sy, 0.006), bevel=0.003, m=M["steel"]))
        for bx in (-0.07, 0.07):
            for by in (-0.045, 0.045):
                P.append(C.cyl("bolt", 0.009, 0.014, (sx + bx, sy + by, 0.018), verts=6, bevel=0, m=M["weld"]))
    P.append(pipe("cross", (sx, -HY * 0.45, 0.65), (sx, HY * 0.45, 0.65), 0.03, M["paint2"]))
    P.append(C.torus("weld_top", 0.05, 0.012, (sx, 0, TOP - 0.02), rot=(R(90), 0, 0), ms=10, mn=4, m=M["weld"]))
P.append(pipe("bar", (-HX - 0.05, 0.0, TOP), (HX + 0.05, 0.0, TOP), 0.042, M["frame"]))
# шапка снега на перекладине и на стойках сверху
P.append(C.box("snow_bar", (2.3, 0.09, 0.035), (0.0, 0.0, TOP + 0.052), bevel=0.014, m=M["snow"]))
for sx in (-1, 1):
    P.append(C.sphere("snow_cap", 0.07, (sx * HX, 0, TOP + 0.045), scale=(1.1, 1.0, 0.45), seg=8, m=M["snow"]))
# серьги-крепления подвесов на перекладине
for hx in (-0.5, 0.6):
    P.append(C.torus("hanger_ring", 0.03, 0.007, (hx, 0.0, TOP - 0.05), rot=(R(90), 0, 0), ms=10, mn=4, m=M["steel"]))


def chain(nm, x, y, z_top, z_bot):
    out = []
    n = max(2, int((z_top - z_bot) / 0.085))
    for k in range(n):
        z = z_top - k * (z_top - z_bot) / n
        out.append(C.torus("%s_%d" % (nm, k), 0.024, 0.0075, (x, y, z), rot=(R(90) if k % 2 else 0, 0, R(90) if k % 2 == 0 else 0), ms=8, mn=3, m=M["chain"]))
    return out


# исправная подвеска (узел seat): две цепи и доска-сиденье; ось вращения — на перекладине
seat_parts = chain("c1", -0.5 - 0.22, 0.0, TOP - 0.05, 0.58) + chain("c2", -0.5 + 0.22, 0.0, TOP - 0.05, 0.58)
seat_parts.append(C.box("board", (0.52, 0.2, 0.04), (-0.5, 0.0, 0.54), bevel=0.006, m=M["seat"]))
for sx in (-0.22, 0.22):
    seat_parts.append(C.cyl("seat_eye", 0.012, 0.05, (-0.5 + sx, 0.0, 0.575), verts=8, bevel=0, m=M["steel"]))
seat_parts.append(C.box("seat_snow", (0.46, 0.14, 0.012), (-0.5, 0.0, 0.572), bevel=0.005, m=M["snow"]))
seat = C.join("seat", seat_parts)
C.pivot(seat, (-0.5, 0.0, TOP))
P.append(seat)
# оборванная подвеска: одна цепь, второй конец болтается на последнем звене
P += chain("bk", 0.6, 0.0, TOP - 0.05, 0.95)
P.append(C.torus("broken_link", 0.02, 0.0045, (0.6, 0.0, 0.93), rot=(R(40), R(30), 0), ms=8, mn=3, m=M["chain"]))
P.append(C.box("torn_eye", (0.07, 0.02, 0.012), (0.6, 0.0, 0.89), rot=(0, R(20), 0), bevel=0.002, m=M["steel"]))

views = [((4.6, -4.4, 2.5), (0.0, 0.0, 1.0)), ((1.2, -2.3, 0.9), (-0.5, 0.0, 0.7))]
C.finish("g67_swing_set", P, views)
