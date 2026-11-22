"""g67_garage_radio — старая переносная магнитола на ящике из-под бутылок: шкала с частотами, ручка настройки (узел knob),
антенна (узел antenna, погнута, примотана изолентой), решётка динамика, ручка для переноски, кассетная дека с открытой крышкой."""
import sys
import os
import math
sys.path.insert(0, os.path.dirname(__file__))
import g67_common as C

R = math.radians
C.reset()
M = {
    "crate": C.mat("crate", (0.1, 0.34, 0.2), under=(0.16, 0.2, 0.1), wear=0.35, dirt=1.0, rough=0.55, scale=60),
    "body": C.mat("body", (0.4, 0.07, 0.09), under=(0.3, 0.14, 0.08), wear=0.5, dirt=0.9, rough=0.45, scale=70),
    "face": C.mat("face", (0.78, 0.72, 0.56), under=(0.5, 0.42, 0.3), wear=0.25, dirt=1.0, rough=0.4, scale=40),
    "dark": C.mat("dark", (0.04, 0.04, 0.045), under=(0.1, 0.07, 0.05), wear=0.2, dirt=0.6, rough=0.6, scale=90),
    "steel": C.mat("steel", (0.66, 0.67, 0.7), under=(0.4, 0.22, 0.12), wear=0.18, dirt=0.9, rough=0.35, scale=120),
    "glass": C.mat("glass", (0.85, 0.8, 0.6), flat=True, dirt=0.6, rough=0.2),
    "ink": C.mat("ink", (0.04, 0.04, 0.05), flat=True, dirt=0.0, rough=0.8),
    "red": C.mat("red", (0.85, 0.08, 0.05), flat=True, dirt=0.0, rough=0.4),
    "tape": C.mat("tape", (0.08, 0.2, 0.62), flat=True, dirt=0.7, rough=0.5),
    "gold": C.mat("gold", (0.75, 0.58, 0.2), under=(0.35, 0.22, 0.08), wear=0.4, dirt=0.8, rough=0.35, scale=140),
    "cass": C.mat("cass", (0.9, 0.75, 0.2), flat=True, dirt=0.5, rough=0.5),
}
P = []
Y = -1.0

# ящик из-под бутылок: зелёный пластик с гнёздами и усиленными рёбрами
P.append(C.box("crate", (0.46, 0.30, 0.16), (0, 0, 0.08), bevel=0.01, m=M["crate"]))
for sx in (-0.1, 0.1):
    for sz in (0.045, 0.115):
        P.append(C.box("hole_f", (0.12, 0.004, 0.045), (sx, -0.152, sz), bevel=0, m=M["dark"], seg=1))
        P.append(C.box("hole_b", (0.12, 0.004, 0.045), (sx, 0.152, sz), bevel=0, m=M["dark"], seg=1))
for sy in (-0.07, 0.07):
    P.append(C.box("hole_s", (0.004, 0.09, 0.07), (-0.232, sy, 0.085), bevel=0, m=M["dark"], seg=1))
    P.append(C.box("hole_s2", (0.004, 0.09, 0.07), (0.232, sy, 0.085), bevel=0, m=M["dark"], seg=1))
for sx in (-0.2, 0.2):
    P.append(C.box("rib", (0.03, 0.31, 0.012), (sx, 0, 0.165), bevel=0.003, m=M["crate"], seg=1))

for sx in (-1, 1):
    P.append(C.box("grip", (0.004, 0.1, 0.03), (sx * 0.2325, 0, 0.12), bevel=0.001, m=M["dark"], seg=1))
    P.append(C.box("grip_edge", (0.012, 0.11, 0.006), (sx * 0.228, 0, 0.143), bevel=0.001, m=M["crate"], seg=1))
# корпус магнитолы
zb = 0.16 + 0.095
P.append(C.box("radio_body", (0.40, 0.15, 0.19), (0, 0, zb), bevel=0.012, m=M["body"], seg=2))
P.append(C.box("radio_face", (0.38, 0.01, 0.17), (0, -0.0775, zb), bevel=0.004, m=M["face"]))
# решётка динамика: кольца и центральный конус
spk = (-0.105, -0.0845, zb - 0.01)
P.append(C.cyl("spk_bed", 0.058, 0.004, spk, rot=(R(90), 0, 0), verts=24, bevel=0, m=M["dark"]))
for k, rr in enumerate((0.012, 0.027, 0.042, 0.055)):
    P.append(C.torus("spk_ring%d" % k, rr, 0.0028, (spk[0], spk[1] - 0.002, spk[2]), rot=(R(90), 0, 0), ms=18, mn=4, m=M["dark"]))
P.append(C.cyl("spk_cone", 0.012, 0.01, (spk[0], spk[1] - 0.004, spk[2]), rot=(R(90), 0, 0), verts=12, bevel=0.002, m=M["dark"], r2=0.006))
# вмятина на решётке (вдавленная, перекошенная дуга)
P.append(C.box("dent", (0.035, 0.003, 0.012), (-0.135, -0.0875, zb - 0.032), rot=(0, R(35), 0), bevel=0, m=M["ink"], seg=1))
# шкала с частотами и стрелка
P.append(C.box("dial", (0.15, 0.004, 0.036), (0.085, -0.0825, zb + 0.058), bevel=0.003, m=M["glass"]))
for i, f in enumerate(("66", "68", "70", "72", "74")):
    P.append(C.text("f%d" % i, f, 0.0085, (0.032 + i * 0.0275, -0.0855, zb + 0.062), rot=(R(90), 0, 0), font=C.FONT_BOLD, extrude=0, m=M["ink"]))
    P.append(C.box("tick%d" % i, (0.0012, 0.001, 0.012), (0.032 + i * 0.0275, -0.0855, zb + 0.048), bevel=0, m=M["ink"], seg=1))
P.append(C.box("needle", (0.002, 0.0015, 0.034), (0.092, -0.0868, zb + 0.058), bevel=0, m=M["red"], seg=1))
P.append(C.text("mhz", "МГц  FM", 0.007, (0.085, -0.0855, zb + 0.039), rot=(R(90), 0, 0), font=C.FONT_BOLD, extrude=0, m=M["ink"]))
# ручка настройки (узел knob) и громкость
knob = C.cyl("knob", 0.021, 0.018, (0.152, -0.088, zb + 0.015), rot=(R(90), 0, 0), verts=16, bevel=0.003, m=M["dark"])
mark = C.box("knob_mark", (0.003, 0.003, 0.014), (0.152, -0.0975, zb + 0.026), bevel=0, m=M["gold"], seg=1)
knob = C.join("knob", [knob, mark])
P.append(knob)
P.append(C.cyl("vol", 0.015, 0.014, (0.086, -0.0855, zb + 0.015), rot=(R(90), 0, 0), verts=12, bevel=0.002, m=M["dark"]))
# кассетная дека с открытой крышкой
P.append(C.box("deck", (0.15, 0.012, 0.075), (0.083, -0.081, zb - 0.045), bevel=0.003, m=M["dark"]))
P.append(C.box("cassette", (0.1, 0.007, 0.062), (0.083, -0.088, zb - 0.045), bevel=0.002, m=M["cass"]))
for rx in (0.062, 0.104):
    P.append(C.cyl("reel", 0.0125, 0.004, (rx, -0.092, zb - 0.045), rot=(R(90), 0, 0), verts=10, bevel=0, m=M["ink"]))
door = C.box("cass_door", (0.15, 0.003, 0.075), (0.083, -0.081, zb - 0.045), bevel=0.002, m=M["glass"], seg=1)
C.pivot(door, (0.083, -0.087, zb - 0.0825))
door.rotation_euler = (R(-62), 0, 0)
P.append(door)
# кнопки деки
for k in range(4):
    P.append(C.box("tbtn%d" % k, (0.026, 0.012, 0.013), (0.0235 + k * 0.034, -0.088, zb - 0.075), bevel=0.002, m=M["steel"], seg=1))
# ножки/винты и дырочка динамика
for sx in (-0.18, 0.18):
    P.append(C.cyl("screw", 0.006, 0.005, (sx, -0.0815, zb + 0.07), rot=(R(90), 0, 0), verts=8, bevel=0, m=M["steel"]))
# ручка для переноски
P.append(C.cable("handle", [(-0.15, 0.0, zb + 0.095), (-0.1, 0.0, zb + 0.15), (0.1, 0.0, zb + 0.15), (0.15, 0.0, zb + 0.095)], r=0.011, m=M["dark"], res=5))
for sx in (-0.15, 0.15):
    P.append(C.cyl("handle_mount", 0.016, 0.012, (sx, 0.0, zb + 0.097), verts=10, bevel=0.002, m=M["steel"]))
# антенна: телескоп из звеньев, погнута, перемотана изолентой (узел antenna, ось — основание)
base = (0.17, 0.06, zb + 0.095)
d1 = (0.62, 0.42, 0.66)
segs = []
cur = list(base)
dirs = [d1, d1, (0.9, 0.3, 0.3), (0.95, 0.1, -0.1)]
for i, (dx, dy, dz) in enumerate(dirs):
    ln = math.sqrt(dx * dx + dy * dy + dz * dz)
    dx, dy, dz = dx / ln, dy / ln, dz / ln
    L = 0.085
    mid = (cur[0] + dx * L * 0.5, cur[1] + dy * L * 0.5, cur[2] + dz * L * 0.5)
    c = C.cyl("ant%d" % i, 0.0075 - i * 0.0014, L, mid, verts=10, bevel=0, m=M["steel"])
    from mathutils import Vector
    c.rotation_euler = (Vector((0, 0, 1)).rotation_difference(Vector((dx, dy, dz)))).to_euler()
    segs.append(c)
    cur = [cur[0] + dx * L, cur[1] + dy * L, cur[2] + dz * L]
    if i == 1:
        t = C.cyl("tape", 0.0105, 0.02, tuple(cur), verts=10, bevel=0, m=M["tape"])
        t.rotation_euler = (Vector((0, 0, 1)).rotation_difference(Vector((dx, dy, dz)))).to_euler()
        segs.append(t)
tip = C.sphere("ant_tip", 0.0042, tuple(cur), seg=8, m=M["steel"])
segs.append(tip)
ant = C.join("antenna", segs)
C.pivot(ant, base)
P.append(ant)

views = [((0.8, -1.0, 0.7), (0.06, 0.0, 0.26)), ((0.17, -0.4, 0.32), (0.04, -0.08, 0.26))]
C.finish("g67_garage_radio", P, views)
