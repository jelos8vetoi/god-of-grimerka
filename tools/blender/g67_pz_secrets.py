"""Секреты ПОДЗЕМКИ: хомяк и хомячий город, собака, будка, слот-автомат DOG CASINO 67, бутылки, аварийный запас, микроволновка, шахматы, баллон, ошейник."""
import sys
import os
import math
sys.path.insert(0, os.path.dirname(__file__))
import g67_pz_common as Z
import g67_common as C
from mathutils import Vector, Matrix

R = math.radians
TAU = math.tau


def M():
    return {
        "wood": C.mat("wood", (0.45, 0.28, 0.14), under=(0.28, 0.17, 0.09), wear=0.35, dirt=1.0, rough=0.7, scale=9, grain=(0.07, 1.0, 1.0), streaks=0.3),
        "wood2": C.mat("wood2", (0.62, 0.42, 0.2), under=(0.3, 0.2, 0.1), wear=0.4, dirt=1.0, rough=0.75, scale=9, grain=(0.07, 1.0, 1.0)),
        "earth": C.mat("earth", (0.3, 0.2, 0.12), under=(0.2, 0.13, 0.08), wear=0.2, dirt=1.0, rough=1.0, scale=4, bump=0.9, streaks=0.2),
        "steel": Z.steel("steel"),
        "dsteel": Z.paint("dsteel", (0.2, 0.25, 0.28), wear=0.6),
        "black": C.mat("black", (0.04, 0.04, 0.045), flat=True, dirt=0.7, rough=0.6),
        "white": Z.paint("white", (0.88, 0.86, 0.8), wear=0.4),
        "red": Z.paint("red", (0.75, 0.07, 0.06), wear=0.3),
        "dred": Z.paint("dred", (0.5, 0.05, 0.05), wear=0.4),
        "yellow": Z.paint("yellow", (0.95, 0.75, 0.1), wear=0.4),
        "green": Z.paint("green", (0.1, 0.5, 0.22), wear=0.4),
        "blue": Z.paint("blue", (0.12, 0.3, 0.7), wear=0.4),
        "gold": C.mat("gold", (0.95, 0.72, 0.18), under=(0.5, 0.35, 0.08), wear=0.2, dirt=0.5, rough=0.22, scale=40),
        "lbulb": Z.glow("lbulb", (1.0, 0.85, 0.4)),
        "lred": Z.glow("lred", (1.0, 0.2, 0.15)),
        "lgreen": Z.glow("lgreen", (0.3, 1.0, 0.45)),
        "lpink": Z.glow("lpink", (1.0, 0.35, 0.75)),
        "lcyan": Z.glow("lcyan", (0.3, 0.95, 1.0)),
        "lamp": Z.glow("lamp", (1.0, 0.95, 0.8)),
        "glassm": C.mat("glassm", (0.4, 0.55, 0.6), flat=True, dirt=0.4, rough=0.05),
        "paper": C.mat("paper", (0.85, 0.82, 0.72), flat=True, dirt=0.6, rough=0.9),
        "ink": C.mat("ink", (0.05, 0.05, 0.06), flat=True, dirt=0.0, rough=0.8),
        "rubber": C.mat("rubber", (0.05, 0.05, 0.055), flat=True, dirt=0.8, rough=0.85),
        "cream": C.mat("cream", (0.9, 0.78, 0.55), flat=True, dirt=0.3, rough=0.9),
        "brown": C.mat("brown", (0.55, 0.32, 0.15), flat=True, dirt=0.3, rough=0.9),
        "grey": C.mat("grey", (0.55, 0.55, 0.55), flat=True, dirt=0.3, rough=0.9),
        "pink": C.mat("pink", (0.95, 0.65, 0.65), flat=True, dirt=0.2, rough=0.9),
        "orange": C.mat("orange", (0.95, 0.5, 0.12), flat=True, dirt=0.2, rough=0.9),
        "tan": C.mat("tan", (0.7, 0.5, 0.3), flat=True, dirt=0.3, rough=0.9),
        "dgreen": C.mat("dgreen", (0.15, 0.3, 0.15), flat=True, dirt=0.3, rough=0.4),
        "brownglass": C.mat("brownglass", (0.25, 0.12, 0.04), flat=True, dirt=0.3, rough=0.08),
        "clear": C.mat("clear", (0.7, 0.8, 0.82), flat=True, dirt=0.2, rough=0.06),
        "wine": C.mat("wine", (0.1, 0.25, 0.12), flat=True, dirt=0.3, rough=0.08),
        "blueg": C.mat("blueg", (0.1, 0.25, 0.5), flat=True, dirt=0.3, rough=0.1),
    }


def V(d, h):
    return [((d, -d * 1.3, h), (0, 0, h * 0.5)), ((d * 0.4, -d * 0.6, h * 0.8), (0, 0, h * 0.55))]


# ----------------------------------------------------------------------------- хомяк
def hamster_build(m, fur, belly, crown=False, ear_in="pink"):
    body = C.sphere("body", 0.15, (0, 0, 0.16), scale=(1.0, 1.15, 0.95), seg=16, m=m[fur])
    bp = [body, C.sphere("belly", 0.11, (0, -0.07, 0.13), scale=(1.0, 0.7, 1.0), seg=12, m=m[belly])]
    head = C.sphere("head", 0.105, (0, -0.1, 0.3), scale=(1.0, 0.95, 0.92), seg=14, m=m[fur])
    hp = [head]
    ch = [C.sphere("c1", 0.07, (-0.075, -0.155, 0.27), seg=10, m=m[belly]), C.sphere("c2", 0.07, (0.075, -0.155, 0.27), seg=10, m=m[belly])]
    cheeks = C.join("cheeks", ch)
    for s_ in (-1, 1):
        hp.append(C.sphere("ear", 0.036, (s_ * 0.07, -0.07, 0.385), scale=(1, 0.5, 1.1), seg=8, m=m[fur]))
        hp.append(C.sphere("earin", 0.022, (s_ * 0.07, -0.088, 0.385), scale=(1, 0.4, 1.1), seg=8, m=m[ear_in]))
        hp.append(C.sphere("eye", 0.016, (s_ * 0.04, -0.185, 0.325), seg=8, m=m["black"]))
        hp.append(C.sphere("eyeh", 0.005, (s_ * 0.04 - 0.004, -0.2, 0.335), seg=4, m=m["white"]))
        bp.append(C.sphere("paw", 0.03, (s_ * 0.07, -0.19, 0.12), scale=(1, 1.2, 0.7), seg=8, m=m[belly]))
        bp.append(C.sphere("foot", 0.04, (s_ * 0.09, -0.08, 0.025), scale=(1, 1.6, 0.6), seg=8, m=m[belly]))
    hp.append(C.sphere("nose", 0.013, (0, -0.2, 0.305), seg=6, m=m["pink"]))
    hp.append(C.box("tooth", (0.012, 0.006, 0.02), (0, -0.2, 0.28), bevel=0.002, m=m["white"], seg=1))
    bp.append(C.sphere("tailn", 0.025, (0, 0.17, 0.1), seg=6, m=m[fur]))
    if crown:
        hp.append(C.cyl("cr_base", 0.07, 0.025, (0, -0.1, 0.42), verts=12, bevel=0.003, m=m["gold"]))
        for k in range(5):
            a_ = k * TAU / 5
            hp.append(C.cyl("cr%d" % k, 0.016, 0.045, (math.sin(a_) * 0.06, -0.1 + math.cos(a_) * 0.06, 0.455), verts=6, bevel=0, m=m["gold"], r2=0.004))
        hp.append(C.sphere("jewel", 0.014, (0, -0.16, 0.425), seg=6, m=m["lred"]))
    return [C.join("body", bp), C.join("head", hp), cheeks]


def hamster_a(m=None):
    m = m or M()
    return hamster_build(m, "tan", "cream"), V(0.8, 0.4), 512


def hamster_b(m=None):
    m = m or M()
    return hamster_build(m, "orange", "cream"), V(0.8, 0.4), 512


def hamster_c(m=None):
    m = m or M()
    return hamster_build(m, "grey", "white"), V(0.8, 0.4), 512


def hamster_gold(m=None):
    m = m or M()
    return hamster_build(m, "gold", "cream", crown=True), V(0.8, 0.45), 512


def hamster_wall(m=None):
    m = m or M()
    """Стена нор 9 × 4: земля и доски, 24 норы (hole_NN — пустышки-узлы), три яруса мостков"""
    W, Hh = 9.0, 4.0
    P = [C.box("earth", (W, 0.8, Hh), (0, 0.4, Hh / 2), bevel=0.05, m=m["earth"])]
    n = 0
    for tier in range(3):
        z = 0.6 + tier * 1.25
        P.append(C.box("plank%d" % tier, (W, 0.4, 0.07), (0, -0.2, z - 0.1), bevel=0.01, m=m["wood"]))
        for k in range(9):
            P.append(C.box("post%d_%d" % (tier, k), (0.08, 0.08, 1.2), (-4.2 + k * 1.05, -0.38, z + 0.5), bevel=0.01, m=m["wood"]))
        P.append(C.box("rail%d" % tier, (W, 0.05, 0.05), (0, -0.4, z + 0.95), bevel=0.005, m=m["wood"]))
        for c in range(8):
            x = -3.9 + c * 1.1
            hole = C.cyl("hole_%02d" % (n + 1), 0.2, 0.06, (x, 0.0, z + 0.4), rot=(R(90), 0, 0), verts=14, bevel=0, m=m["black"])
            P.append(hole)
            P.append(C.torus("rim%d" % n, 0.2, 0.05, (x, -0.02, z + 0.4), rot=(R(90), 0, 0), ms=14, mn=5, m=m["earth"]))
            n += 1
            if n >= 24:
                break
        if n >= 24:
            break
    # таблички города
    for i, (t, x, z) in enumerate((("УЛ. ЗЕРНОВАЯ, 8", -3.2, 3.5), ("МЭРИЯ", 0.0, 3.6), ("НЕ КОРМИТЬ.\nМЫ САМИ", 3.0, 3.5), ("ХОМЯК-БАНК:\nВКЛАДЫ ЗА ЩЁКУ", -1.6, 2.35))):
        P.append(C.box("pl%d" % i, (1.5, 0.05, 0.5), (x, -0.45, z), bevel=0.01, m=m["wood2"]))
        P.append(C.text("tx%d" % i, t, 0.12 if "\n" not in t else 0.1, (x, -0.49, z), rot=(R(90), 0, 0), font=C.FONT_IMPACT, extrude=0, m=m["ink"], spacing=0.9))
    for i in range(4):   # экраны курса семечки
        P.append(C.box("scr%d" % i, (0.5, 0.04, 0.32), (-3.6 + i * 2.4, -0.45, 1.5), bevel=0.005, m=m["lgreen"], seg=1))
        P.append(C.cable("graph%d" % i, [(-3.8 + i * 2.4, -0.48, 1.4), (-3.7 + i * 2.4, -0.48, 1.55), (-3.6 + i * 2.4, -0.48, 1.45), (-3.5 + i * 2.4, -0.48, 1.62)], r=0.01, m=m["black"], res=2))
    return P, [((6.0, -9.0, 3.0), (0, 0, 2.0)), ((-2.0, -3.5, 1.6), (-1.0, 0, 1.6))], 2048


def hamster_props(m=None):
    m = m or M()
    """колесо (узел wheel), кормушка с семечками, мостик, труба-переход"""
    P = [C.torus("wheel", 0.5, 0.04, (0, 0, 0.62), rot=(0, R(90), 0), ms=28, mn=6, m=m["steel"])]
    for k in range(10):
        P.append(C.box("rung%d" % k, (0.04, 0.03, 0.95), (0, 0, 0.62), rot=(R(k * 18), 0, 0), bevel=0.003, m=m["steel"], seg=1))
    P.append(C.box("stand", (0.06, 0.9, 0.06), (0.15, 0, 0.1), bevel=0.01, m=m["dsteel"]))
    P.append(C.box("stand2", (0.06, 0.9, 0.06), (-0.15, 0, 0.1), bevel=0.01, m=m["dsteel"]))
    P.append(C.box("axle", (0.5, 0.04, 0.04), (0, 0, 0.62), bevel=0.005, m=m["dsteel"]))
    # кормушка
    P.append(C.cyl("bowl", 0.25, 0.1, (1.2, 0, 0.05), verts=16, bevel=0.01, m=m["red"], r2=0.2))
    for k in range(14):
        P.append(C.sphere("seed%d" % k, 0.02, (1.2 + math.cos(k) * 0.12, math.sin(k * 2) * 0.12, 0.12), scale=(1, 0.5, 0.5), seg=5, m=m["black" if k % 2 else "white"]))
    # мостик
    for k in range(8):
        P.append(C.box("pl%d" % k, (0.5, 0.12, 0.03), (-1.6, -0.4 + k * 0.12, 0.3 + math.sin(k / 7.0 * math.pi) * 0.1), bevel=0.003, m=m["wood2"]))
    for s in (-1, 1):
        P.append(C.cable("rope", [(-1.6 + s * 0.28, -0.4, 0.5), (-1.6 + s * 0.28, 0.0, 0.62), (-1.6 + s * 0.28, 0.5, 0.5)], r=0.012, m=m["cream"], res=3))
    # труба-переход
    P.append(C.cyl("tube", 0.16, 1.0, (2.5, 0, 0.17), rot=(0, R(90), 0), verts=16, bevel=0.005, m=m["clear"]))
    P.append(C.torus("tube_r1", 0.16, 0.02, (2.0, 0, 0.17), rot=(0, R(90), 0), ms=16, mn=5, m=m["dsteel"]))
    P.append(C.torus("tube_r2", 0.16, 0.02, (3.0, 0, 0.17), rot=(0, R(90), 0), ms=16, mn=5, m=m["dsteel"]))
    return P, [((3.0, -3.6, 1.6), (0.8, 0, 0.3)), ((1.0, -1.6, 1.0), (0, 0, 0.5))], 1024


# ----------------------------------------------------------------------------- собака и будка
def dog(m=None):
    m = m or M()
    """Приземистая ушастая собака: узлы head, jaw, tail, ear_l, ear_r, paw_fr; начало — между лап на земле"""
    P = [C.sphere("torso", 0.22, (0, 0.05, 0.3), scale=(0.9, 1.5, 0.85), seg=16, m=m["brown"]),
         C.sphere("chest", 0.2, (0, -0.2, 0.3), scale=(0.95, 0.9, 1.0), seg=12, m=m["brown"]),
         C.sphere("belly", 0.15, (0, 0.05, 0.22), scale=(0.9, 1.3, 0.6), seg=10, m=m["cream"])]
    head = [C.sphere("head", 0.15, (0, -0.38, 0.5), scale=(1.0, 1.0, 0.92), seg=14, m=m["brown"]),
            C.sphere("snout", 0.1, (0, -0.52, 0.45), scale=(0.8, 1.2, 0.7), seg=12, m=m["cream"]),
            C.sphere("nose", 0.035, (0, -0.62, 0.48), seg=8, m=m["black"]),
            C.sphere("eyl", 0.026, (-0.07, -0.5, 0.56), seg=8, m=m["black"]), C.sphere("eyr", 0.026, (0.07, -0.5, 0.56), seg=8, m=m["black"]),
            C.sphere("brl", 0.03, (-0.07, -0.49, 0.6), scale=(1.3, 0.5, 0.4), seg=6, m=m["brown"]), C.sphere("brr", 0.03, (0.07, -0.49, 0.6), scale=(1.3, 0.5, 0.4), seg=6, m=m["brown"])]
    P.append(C.join("head", head))
    P.append(C.box("jaw", (0.12, 0.17, 0.04), (0, -0.52, 0.38), bevel=0.015, m=m["pink"]))
    P.append(C.sphere("ear_l", 0.075, (-0.14, -0.35, 0.5), scale=(0.35, 0.8, 1.2), seg=10, m=m["dgreen"]))
    P.append(C.sphere("ear_r", 0.075, (0.14, -0.35, 0.5), scale=(0.35, 0.8, 1.2), seg=10, m=m["dgreen"]))
    P[-2].rotation_euler = (0, R(20), 0)
    P[-1].rotation_euler = (0, R(-20), 0)
    for sx, sy, nm in ((-0.12, -0.22, "paw_fl"), (0.12, -0.22, "paw_fr"), (-0.12, 0.3, "paw_bl"), (0.12, 0.3, "paw_br")):
        P.append(C.cyl("leg", 0.05, 0.2, (sx, sy, 0.11), verts=8, bevel=0.005, m=m["brown"]))
        P.append(C.sphere(nm, 0.06, (sx, sy - 0.01, 0.04), scale=(1, 1.3, 0.6), seg=8, m=m["cream"]))
    P.append(C.cable("tail", [(0, 0.3, 0.4), (0, 0.42, 0.5), (0, 0.46, 0.62), (0, 0.4, 0.72)], r=0.04, m=m["brown"], res=3))
    P.append(C.torus("collar", 0.14, 0.022, (0, -0.33, 0.43), rot=(R(80), 0, 0), ms=14, mn=5, m=m["red"]))
    P.append(C.cyl("tag", 0.035, 0.01, (0, -0.46, 0.36), rot=(R(90), 0, 0), verts=10, bevel=0, m=m["gold"]))
    for i in range(3):
        P.append(C.sphere("spot%d" % i, 0.07, (-0.14 + i * 0.14, 0.12 + 0.1 * i, 0.45 - 0.02 * i), scale=(1, 1, 0.3), seg=6, m=m["cream"]))
    return P, V(1.6, 0.8), 1024


def kennel(m=None):
    m = m or M()
    P = [C.box("fl", (1.2, 1.4, 0.1), (0, 0, 0.05), bevel=0.01, m=m["wood"]),
         C.box("bk", (1.2, 0.06, 0.9), (0, 0.67, 0.55), bevel=0.01, m=m["wood2"]),
         C.box("sl", (0.06, 1.4, 0.9), (-0.57, 0, 0.55), bevel=0.01, m=m["wood2"]),
         C.box("sr", (0.06, 1.4, 0.9), (0.57, 0, 0.55), bevel=0.01, m=m["wood2"]),
         C.box("fu", (1.2, 0.06, 0.4), (0, -0.67, 0.95), bevel=0.01, m=m["wood2"]),
         C.box("fl_l", (0.3, 0.06, 0.55), (-0.45, -0.67, 0.37), bevel=0.01, m=m["wood2"]),
         C.box("fl_r", (0.3, 0.06, 0.55), (0.45, -0.67, 0.37), bevel=0.01, m=m["wood2"])]
    for s in (-1, 1):
        P.append(C.box("roof", (0.9, 1.6, 0.05), (s * 0.36, 0, 1.28), rot=(0, s * R(32), 0), bevel=0.01, m=m["dred"]))
    P.append(C.box("ridge", (0.1, 1.64, 0.06), (0, 0, 1.52), bevel=0.01, m=m["dred"]))
    P.append(C.box("pl", (0.8, 0.03, 0.18), (0, -0.7, 1.05), bevel=0, m=m["paper"], seg=1))
    P.append(C.text("nm", "ЛАПА", 0.12, (0, -0.72, 1.05), rot=(R(90), 0, 0), font=C.FONT_IMPACT, extrude=0, m=m["ink"]))
    P.append(C.cyl("bowl", 0.17, 0.08, (0.75, -0.9, 0.04), verts=14, bevel=0.005, m=m["red"], r2=0.14))
    P.append(C.torus("chain", 0.35, 0.012, (-0.7, -0.9, 0.2), rot=(R(90), 0, 0), ms=16, mn=4, m=m["steel"]))
    return P, [((3.0, -3.8, 1.9), (0, 0, 0.7)), ((1.0, -1.7, 1.0), (0, -0.5, 0.6))], 1024


# ----------------------------------------------------------------------------- слот-автомат
SYM = ("dog", "paw", "bone", "collar", "house", "bowl")


def symbol(P, m, kind, x, y, z, s=1.0):
    """символ барабана: геометрия лицом в −Y, центр (x, y, z); размер ≈ 0.17 * s"""
    if kind == "dog":
        P.append(C.sphere("sd", 0.075 * s, (x, y, z), seg=10, m=m["tan"]))
        P.append(C.sphere("sdn", 0.04 * s, (x, y - 0.05 * s, z - 0.025 * s), seg=8, m=m["cream"]))
        P.append(C.sphere("sdno", 0.014 * s, (x, y - 0.085 * s, z - 0.015 * s), seg=5, m=m["black"]))
        for sx in (-1, 1):
            P.append(C.sphere("sde", 0.04 * s, (x + sx * 0.08 * s, y + 0.0, z + 0.03 * s), scale=(0.5, 0.7, 1.2), seg=8, m=m["brown"]))
            P.append(C.sphere("sdy", 0.012 * s, (x + sx * 0.035 * s, y - 0.065 * s, z + 0.03 * s), seg=5, m=m["black"]))
    elif kind == "paw":
        P.append(C.sphere("sp", 0.055 * s, (x, y, z - 0.03 * s), scale=(1.1, 0.6, 0.9), seg=10, m=m["brown"]))
        for k in range(4):
            P.append(C.sphere("spt", 0.026 * s, (x + (k - 1.5) * 0.045 * s, y, z + 0.035 * s + (0.012 * s if k in (1, 2) else 0)), scale=(1, 0.6, 1.2), seg=6, m=m["brown"]))
    elif kind == "bone":
        P.append(C.cyl("sb", 0.016 * s, 0.14 * s, (x, y, z), rot=(0, R(90), R(25)), verts=8, bevel=0, m=m["white"]))
        for sx in (-1, 1):
            for sz in (-1, 1):
                P.append(C.sphere("sbe", 0.03 * s, (x + sx * 0.065 * s * math.cos(R(25)), y, z + sx * 0.065 * s * math.sin(R(25)) + sz * 0.018 * s), seg=6, m=m["white"]))
    elif kind == "collar":
        P.append(C.torus("sc", 0.07 * s, 0.014 * s, (x, y, z), rot=(R(90), 0, 0), ms=14, mn=5, m=m["red"]))
        P.append(C.cyl("sct", 0.028 * s, 0.01 * s, (x, y - 0.01, z - 0.07 * s), rot=(R(90), 0, 0), verts=10, bevel=0, m=m["gold"]))
    elif kind == "house":
        P.append(C.box("sh", (0.1 * s, 0.03, 0.07 * s), (x, y, z - 0.02 * s), bevel=0.003, m=m["wood2"]))
        P.append(C.box("shr", (0.13 * s, 0.035, 0.03 * s), (x, y, z + 0.035 * s), bevel=0.003, m=m["dred"]))
        P.append(C.box("shd", (0.03 * s, 0.035, 0.04 * s), (x, y - 0.005, z - 0.035 * s), bevel=0, m=m["black"], seg=1))
    elif kind == "bowl":
        P.append(C.cyl("sw", 0.07 * s, 0.035 * s, (x, y, z - 0.02 * s), rot=(R(90), 0, 0), verts=12, bevel=0.003, m=m["red"], r2=0.04 * s))
        P.append(C.sphere("sws", 0.03 * s, (x, y - 0.02, z + 0.015 * s), scale=(1, 0.5, 0.5), seg=6, m=m["brown"]))


def reel(m, idx, x):
    r = 0.27
    parts = [C.cyl("casino_reel_%02d" % idx, r, 0.3, (x, -0.2, 0.95), rot=(0, R(90), 0), verts=24, bevel=0.003, m=m["white"])]
    for k, kind in enumerate(SYM):
        a = k * TAU / 6
        # плашка символа на ободе: центр на радиусе r, лицом наружу
        py = -0.2 - math.sin(a) * (r + 0.004)
        pz = 0.95 + math.cos(a) * (r + 0.004)
        strip = C.box("strip", (0.27, 0.01, 0.2), (x, py, pz), rot=(a, 0, 0), bevel=0, m=m["yellow" if k % 2 else "cream"], seg=1)
        parts.append(strip)
        tmp = []
        symbol(tmp, m, kind, x, -0.2 - (r + 0.012), 0.95, 1.25)
        phi = a - R(90)
        c0 = Vector((x, -0.2, 0.95))
        Rm = Matrix.Translation(c0) @ Matrix.Rotation(phi, 4, "X") @ Matrix.Translation(-c0)
        for o in tmp:
            o.matrix_world = Rm @ o.matrix_world
        parts += tmp
    return parts


def slot_machine(m=None):
    m = m or M()
    """Слот-автомат DOG CASINO 67: рама, будка-вывеска, лампочки (bulbs_a/b), 3 барабана, табло SPIN n / 67, индикатор JACKPOT, красная кнопка, лоток"""
    P = []
    # рама и корпус
    P.append(C.box("cab", (1.2, 0.8, 1.35), (0, 0, 0.675), bevel=0.04, m=m["wood"]))
    P.append(C.box("plinth", (1.28, 0.88, 0.12), (0, 0, 0.06), bevel=0.02, m=m["dsteel"]))
    for s in (-1, 1):
        P.append(C.box("pilaster", (0.08, 0.1, 1.35), (s * 0.55, -0.4, 0.675), bevel=0.015, m=m["wood2"]))
    # окно барабанов
    P.append(C.box("win_back", (1.0, 0.1, 0.5), (0, -0.2, 0.95), bevel=0.01, m=m["black"]))
    reels = []
    for i, x in enumerate((-0.33, 0.0, 0.33)):
        reels.append(reel(m, i + 1, x))
    for rp in reels:
        # барабан: цилиндр первым — начало узла в его центре; плашки склеиваются в него
        P.append(C.join(rp[0].name, rp))
    P.append(C.box("win_f_t", (1.06, 0.06, 0.06), (0, -0.46, 1.23), bevel=0.01, m=m["gold"]))
    P.append(C.box("win_f_b", (1.06, 0.06, 0.06), (0, -0.46, 0.67), bevel=0.01, m=m["gold"]))
    P.append(C.box("pay_line", (0.98, 0.014, 0.012), (0, -0.47, 0.95), bevel=0, m=m["lred"], seg=1))
    # верх — будка
    P.append(C.box("house_b", (1.2, 0.8, 0.5), (0, 0, 1.6), bevel=0.03, m=m["dred"]))
    for s in (-1, 1):
        P.append(C.box("roof", (0.82, 1.0, 0.07), (s * 0.34, -0.02, 2.0), rot=(0, s * R(35), 0), bevel=0.012, m=m["red"]))
    P.append(C.box("ridge", (0.14, 1.04, 0.07), (0, -0.02, 2.2), bevel=0.012, m=m["yellow"]))
    P.append(C.box("sign_pl", (1.0, 0.07, 0.34), (0, -0.44, 1.62), bevel=0.015, m=m["dsteel"]))
    P.append(C.text("sign", "DOG CASINO 67", 0.15, (0, -0.5, 1.62), rot=(R(90), 0, 0), font=C.FONT_IMPACT, extrude=0.03, m=m["gold"]))
    P.append(C.cyl("door_hole", 0.14, 0.04, (0, -0.42, 1.85), rot=(R(90), 0, 0), verts=14, bevel=0, m=m["black"]))
    # лампочки по периметру: две группы
    ba, bb = [], []
    k = 0
    pts = []
    for i in range(9):
        pts.append((-0.56 + i * 0.14, 0.9 - 0.0))
    for z in (0.15, 1.38):
        for i in range(9):
            pts.append((-0.56 + i * 0.14, z))
    for z in (0.35, 0.55, 0.75, 0.95, 1.15):
        pts.append((-0.6, z))
        pts.append((0.6, z))
    for (x, z) in pts[9:]:
        b = C.sphere("bulb", 0.03, (x, -0.47, z), seg=6, m=m["lbulb"])
        (ba if k % 2 == 0 else bb).append(b)
        k += 1
    for i in range(7):
        a = i / 6.0
        b = C.sphere("bulbr", 0.028, (-0.62 + 0.62 * a * 2 - 0.0, -0.5, 1.45 + 0.0), seg=6, m=m["lbulb"])
        (ba if i % 2 == 0 else bb).append(b)
    P.append(C.join("bulbs_a", ba))
    P.append(C.join("bulbs_b", bb))
    # табло SPIN, JACKPOT, результат
    P.append(C.box("spin_board", (0.46, 0.04, 0.16), (-0.3, -0.44, 1.3), bevel=0.005, m=m["black"]))
    P.append(C.text("spin_t", "SPIN: 0 / 67", 0.075, (-0.3, -0.47, 1.3), rot=(R(90), 0, 0), font=C.FONT_MONO, extrude=0, m=m["lred"]))
    P.append(C.box("jp_panel", (0.46, 0.04, 0.16), (0.3, -0.44, 1.3), bevel=0.005, m=m["lpink"]))
    P.append(C.text("jp_t", "67 SPIN\nJACKPOT", 0.06, (0.3, -0.47, 1.3), rot=(R(90), 0, 0), font=C.FONT_IMPACT, extrude=0, m=m["ink"]))
    P.append(C.box("result", (0.9, 0.04, 0.1), (0, -0.44, 0.58), bevel=0.005, m=m["lcyan"], seg=1))
    # пульт: кнопка, лоток, динамики
    P.append(C.box("deck", (1.2, 0.35, 0.08), (0, -0.55, 0.45), rot=(R(-8), 0, 0), bevel=0.015, m=m["dsteel"]))
    P.append(C.cyl("btn_base", 0.11, 0.05, (0, -0.58, 0.5), rot=(R(-8), 0, 0), verts=20, bevel=0.005, m=m["black"]))
    P.append(C.cyl("spin_button", 0.095, 0.07, (0, -0.585, 0.56), rot=(R(-8), 0, 0), verts=20, bevel=0.01, m=m["lred"]))
    P.append(C.text("spin_lbl", "SPIN", 0.05, (0, -0.65, 0.5), rot=(R(82), 0, 0), font=C.FONT_IMPACT, extrude=0, m=m["white"]))
    P.append(C.box("tray", (0.6, 0.2, 0.14), (0, -0.46, 0.2), bevel=0.02, m=m["steel"]))
    P.append(C.box("tray_in", (0.5, 0.15, 0.1), (0, -0.5, 0.22), bevel=0.01, m=m["black"]))
    for i in range(7):
        P.append(C.cyl("coin", 0.03, 0.008, (-0.12 + i * 0.04, -0.52, 0.27), rot=(R(90), 0, 0), verts=10, bevel=0, m=m["gold"]))
    for s in (-1, 1):
        P.append(C.cyl("spk", 0.1, 0.04, (s * 0.45, -0.41, 0.4), rot=(R(90), 0, 0), verts=16, bevel=0.005, m=m["black"]))
        P.append(C.torus("spk_r", 0.1, 0.01, (s * 0.45, -0.43, 0.4), rot=(R(90), 0, 0), ms=16, mn=4, m=m["gold"]))
    P.append(C.box("coin_slot", (0.08, 0.03, 0.16), (0.42, -0.41, 0.88), bevel=0.005, m=m["black"]))
    P.append(C.box("sticker", (0.24, 0.004, 0.1), (-0.43, -0.405, 0.85), bevel=0, m=m["yellow"], seg=1))
    P.append(C.cable("cord", [(0.4, 0.4, 0.1), (0.6, 0.6, 0.02), (1.0, 0.7, 0.02), (1.4, 0.9, 0.02)], r=0.02, m=m["black"]))
    return P, [((2.6, -3.0, 1.9), (0, 0, 1.1)), ((0.5, -1.3, 1.0), (0, -0.4, 0.95))], 2048


# ----------------------------------------------------------------------------- бутылки, пачка, микроволновка, шахматы, баллон, ошейник
def bottle(P, m, kind, glass, label, cap):
    if kind == 1:   # пиво: длинное горлышко
        P.append(C.cyl("b", 0.036, 0.2, (0, 0, 0.12), verts=14, bevel=0.004, m=m[glass]))
        P.append(C.cyl("sh", 0.036, 0.05, (0, 0, 0.245), verts=14, bevel=0.004, m=m[glass], r2=0.014))
        P.append(C.cyl("n", 0.014, 0.1, (0, 0, 0.32), verts=10, bevel=0.002, m=m[glass]))
        P.append(C.cyl("lab", 0.0375, 0.09, (0, 0, 0.12), verts=14, bevel=0, m=m[label]))
    elif kind == 2:   # водка: приземистая
        P.append(C.cyl("b", 0.05, 0.22, (0, 0, 0.12), verts=14, bevel=0.006, m=m[glass]))
        P.append(C.cyl("sh", 0.05, 0.03, (0, 0, 0.245), verts=14, bevel=0.004, m=m[glass], r2=0.02))
        P.append(C.cyl("n", 0.02, 0.07, (0, 0, 0.29), verts=10, bevel=0.002, m=m[glass]))
        P.append(C.cyl("lab", 0.0515, 0.11, (0, 0, 0.12), verts=14, bevel=0, m=m[label]))
    elif kind == 3:   # вино: высокая, изогнутое плечо
        P.append(C.cyl("b", 0.04, 0.22, (0, 0, 0.12), verts=14, bevel=0.004, m=m[glass]))
        P.append(C.cyl("sh", 0.04, 0.08, (0, 0, 0.26), verts=14, bevel=0.004, m=m[glass], r2=0.016))
        P.append(C.cyl("n", 0.016, 0.1, (0, 0, 0.35), verts=10, bevel=0.002, m=m[glass]))
        P.append(C.cyl("lab", 0.0415, 0.12, (0, 0, 0.12), verts=14, bevel=0, m=m[label]))
    elif kind == 4:   # газировка: пластик, рёбристый низ
        P.append(C.cyl("b", 0.05, 0.26, (0, 0, 0.14), verts=14, bevel=0.006, m=m[glass]))
        P.append(C.cyl("sh", 0.05, 0.05, (0, 0, 0.295), verts=14, bevel=0.004, m=m[glass], r2=0.02))
        P.append(C.cyl("n", 0.022, 0.04, (0, 0, 0.34), verts=10, bevel=0.002, m=m[glass]))
        for k in range(6):
            P.append(C.cyl("foot%d" % k, 0.012, 0.03, (math.sin(k * 1.05) * 0.04, math.cos(k * 1.05) * 0.04, 0.015), verts=6, bevel=0, m=m[glass]))
        P.append(C.cyl("lab", 0.0515, 0.12, (0, 0, 0.15), verts=14, bevel=0, m=m[label]))
    else:   # фляга
        P.append(C.box("b", (0.12, 0.05, 0.2), (0, 0, 0.12), bevel=0.02, m=m[glass]))
        P.append(C.cyl("n", 0.025, 0.05, (0, 0, 0.245), verts=10, bevel=0.002, m=m[glass]))
        P.append(C.box("lab", (0.1, 0.055, 0.1), (0, 0, 0.12), bevel=0.004, m=m[label]))
    P.append(C.cyl("cap", 0.018 if kind in (1, 3, 5) else 0.025, 0.02, (0, 0, {1: 0.375, 2: 0.335, 3: 0.405, 4: 0.37, 5: 0.28}[kind]), verts=10, bevel=0.002, m=m[cap]))
    P.append(C.box("sticker", (0.04, 0.004, 0.04), (0.0, -0.056, 0.2), bevel=0, m=m["yellow"], seg=1))


def bottle_n(kind, glass, label, cap):
    def fn(m=None):
        m = m or M()
        P = []
        bottle(P, m, kind, glass, label, cap)
        return P, [((0.9, -1.2, 0.5), (0, 0, 0.18)), ((0.35, -0.5, 0.3), (0, 0, 0.2))], 512
    return fn


def emergency_pack(m=None):
    m = m or M()
    P = [C.box("box", (0.28, 0.14, 0.2), (0, 0, 0.1), bevel=0.012, m=m["white"]),
         C.box("band", (0.28, 0.142, 0.05), (0, 0, 0.1), bevel=0.005, m=m["red"]),
         C.box("cr_v", (0.04, 0.003, 0.12), (-0.08, -0.072, 0.1), bevel=0, m=m["red"], seg=1),
         C.box("cr_h", (0.12, 0.003, 0.04), (-0.08, -0.072, 0.1), bevel=0, m=m["red"], seg=1),
         C.box("handle", (0.14, 0.02, 0.03), (0, 0, 0.215), bevel=0.01, m=m["dsteel"])]
    P.append(C.text("t1", "АВАРИЙНЫЙ ЗАПАС", 0.025, (0.04, -0.074, 0.14), rot=(R(90), 0, 0), font=C.FONT_IMPACT, extrude=0, m=m["ink"]))
    P.append(C.text("t2", "0.5", 0.07, (0.07, -0.074, 0.06), rot=(R(90), 0, 0), font=C.FONT_IMPACT, extrude=0, m=m["ink"]))
    return P, [((0.8, -1.0, 0.6), (0, 0, 0.1)), ((0.3, -0.35, 0.3), (0, 0, 0.1))], 512


def microwave(m=None):
    m = m or M()
    P = [C.box("body", (0.55, 0.4, 0.32), (0, 0, 0.16), bevel=0.025, m=m["white"]),
         C.box("cavity", (0.38, 0.05, 0.24), (-0.06, -0.18, 0.16), bevel=0, m=m["black"], seg=1),
         C.box("door_leaf", (0.4, 0.03, 0.26), (-0.06, -0.205, 0.16), bevel=0.01, m=m["dsteel"]),
         C.box("window", (0.34, 0.012, 0.2), (-0.06, -0.225, 0.16), bevel=0, m=m["glassm"], seg=1),
         C.box("panel", (0.1, 0.02, 0.26), (0.21, -0.2, 0.16), bevel=0.005, m=m["black"]),
         C.cyl("dial", 0.025, 0.02, (0.21, -0.215, 0.2), rot=(R(90), 0, 0), verts=10, bevel=0, m=m["steel"]),
         C.box("display", (0.07, 0.01, 0.03), (0.21, -0.213, 0.27), bevel=0, m=m["lgreen"], seg=1),
         C.box("light", (0.3, 0.005, 0.18), (-0.06, -0.176, 0.16), bevel=0, m=m["lamp"], seg=1),
         C.cyl("plate", 0.14, 0.012, (-0.06, -0.06, 0.045), verts=18, bevel=0.002, m=m["glassm"])]
    P.append(C.box("handle", (0.02, 0.03, 0.2), (0.16, -0.23, 0.16), bevel=0.006, m=m["steel"]))
    return P, [((1.2, -1.6, 0.7), (0, 0, 0.16)), ((0.4, -0.7, 0.4), (0, -0.1, 0.16))], 512


def chess(m=None):
    m = m or M()
    P = [C.box("board", (0.5, 0.5, 0.03), (0, 0, 0.015), bevel=0.005, m=m["brown"])]
    for i in range(8):
        for j in range(8):
            if (i + j) % 2 == 0:
                P.append(C.box("sq", (0.0625, 0.0625, 0.004), (-0.219 + i * 0.0625, -0.219 + j * 0.0625, 0.032), bevel=0, m=m["cream"], seg=1))
    def piece(x, y, mm, h, r):
        P.append(C.cyl("pc", r, h, (x, y, 0.03 + h / 2), verts=8, bevel=0.003, m=m[mm], r2=r * 0.6))
        P.append(C.sphere("pt", r * 0.7, (x, y, 0.03 + h), seg=6, m=m[mm]))
    for i in range(8):
        piece(-0.219 + i * 0.0625, -0.157, "white", 0.04, 0.02)
        piece(-0.219 + i * 0.0625, 0.157, "black", 0.04, 0.02)
    for i, h in enumerate((0.06, 0.055, 0.07, 0.08, 0.1, 0.07, 0.055, 0.06)):
        if i != 3:
            piece(-0.219 + i * 0.0625, -0.219, "white", h, 0.022)
        piece(-0.219 + i * 0.0625, 0.219, "black", h, 0.022)
    return P, [((0.7, -0.9, 0.7), (0, 0, 0.05)), ((0.2, -0.35, 0.3), (0, 0, 0.05))], 512


def gas_balloon(m=None):
    m = m or M()
    P = [C.cyl("tank", 0.14, 0.8, (0, 0, 0.45), verts=18, bevel=0.01, m=m["green"]),
         C.sphere("dome", 0.14, (0, 0, 0.85), scale=(1, 1, 0.45), seg=14, m=m["green"]),
         C.cyl("neck", 0.04, 0.08, (0, 0, 0.93), verts=10, bevel=0.004, m=m["steel"]),
         C.box("reg", (0.12, 0.08, 0.1), (0, 0, 1.0), bevel=0.01, m=m["dsteel"]),
         C.cyl("gauge", 0.04, 0.02, (0, -0.06, 1.02), rot=(R(90), 0, 0), verts=12, bevel=0, m=m["white"]),
         C.cyl("foot", 0.16, 0.05, (0, 0, 0.025), verts=18, bevel=0.005, m=m["dsteel"])]
    P.append(C.text("g", "ГЕЛИЙ", 0.08, (0, -0.145, 0.5), rot=(R(90), 0, 0), font=C.FONT_IMPACT, extrude=0, m=m["white"]))
    cols = ("red", "yellow", "blue", "lpink", "orange", "green")
    for i in range(6):
        a = i * 1.0
        x, y, z = math.sin(a) * 0.25, math.cos(a) * 0.12, 1.9 + (i % 3) * 0.2
        P.append(C.sphere("balloon%d" % i, 0.16, (x, y, z), scale=(1, 1, 1.18), seg=12, m=m[cols[i]]))
        P.append(C.cable("string%d" % i, [(x, y, z - 0.18), (x * 0.6, y * 0.6, 1.4), (0.02, 0.0, 1.04)], r=0.004, m=m["white"], res=2))
    return P, [((2.0, -2.6, 1.6), (0, 0, 1.2)), ((0.8, -1.1, 1.3), (0, 0, 1.2))], 512


def collar67(m=None):
    m = m or M()
    P = [C.torus("band", 0.12, 0.022, (0, 0, 0.14), rot=(R(80), 0, 0), ms=24, mn=8, m=m["red"])]
    for i in range(14):
        a = i * TAU / 14
        P.append(C.cyl("stud%d" % i, 0.012, 0.014, (math.sin(a) * 0.12, -math.cos(a) * 0.12 * math.sin(R(80)) , 0.14 + math.cos(a) * 0.12 * math.cos(R(80)) * 0 + math.cos(a) * 0.12 * 0.17), verts=6, bevel=0, m=m["gold"]))
    P.append(C.cyl("tag", 0.05, 0.012, (0, -0.125, 0.02), rot=(R(90), 0, 0), verts=14, bevel=0.003, m=m["gold"]))
    P.append(C.text("n", "67", 0.05, (0, -0.134, 0.02), rot=(R(90), 0, 0), font=C.FONT_IMPACT, extrude=0.004, m=m["ink"]))
    P.append(C.torus("ring", 0.016, 0.005, (0, -0.12, 0.075), rot=(R(90), 0, 0), ms=8, mn=4, m=m["steel"]))
    return P, [((0.6, -0.8, 0.5), (0, 0, 0.12)), ((0.2, -0.3, 0.2), (0, 0, 0.08))], 512


BUILD = {"hamster_a": hamster_a, "hamster_b": hamster_b, "hamster_c": hamster_c, "hamster_gold": hamster_gold, "hamster_wall": hamster_wall,
         "hamster_props": hamster_props, "dog": dog, "kennel": kennel, "slot_machine": slot_machine,
         "bottle_1": bottle_n(1, "brownglass", "paper", "red"), "bottle_2": bottle_n(2, "clear", "blue", "steel"), "bottle_3": bottle_n(3, "wine", "cream", "gold"),
         "bottle_4": bottle_n(4, "clear", "red", "green"), "bottle_5": bottle_n(5, "steel", "orange", "black"),
         "emergency_pack": emergency_pack, "microwave": microwave, "chess": chess, "gas_balloon": gas_balloon, "collar67": collar67}
Z.run(BUILD, 1024)
