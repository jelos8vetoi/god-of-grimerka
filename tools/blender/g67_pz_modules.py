"""Модульный набор ПОДЗЕМКИ (4 × 4 м): стены, углы, колонна, полы, потолки, арка, лестница, двери, решётка, рольставня.
Стена: ширина 4 по X, лицо в −Y (в Godot +Z), высота 3,2; пол: верх на z = 0, центр; потолок: низ на z = 0, центр."""
import sys
import os
import math
sys.path.insert(0, os.path.dirname(__file__))
import g67_pz_common as Z
import g67_common as C

R = math.radians
H = 3.2


def M():
    return {
        "tile": Z.tile_mat("tile", "xz"),
        "tile_col": Z.tile_mat("tile_col", "xz", z0=0.75),
        "tile_c": Z.tile_mat("tile_c", "xz", stripe=False, base=(0.8, 0.8, 0.74)),
        "ftile": Z.tile_mat("ftile", "xy", stripe=False, size=0.3, base=(0.55, 0.56, 0.55), dirt=0.8),
        "conc": Z.conc("conc"),
        "conc_l": Z.conc("conc_l", base=(0.62, 0.62, 0.6), scale=4.0),
        "white": Z.paint("white", (0.82, 0.8, 0.74), wear=0.6),
        "steel": Z.steel("steel"),
        "dsteel": Z.paint("dsteel", (0.22, 0.27, 0.3), wear=0.6),
        "green": Z.paint("green", (0.1, 0.42, 0.2), wear=0.5),
        "yellow": Z.paint("yellow", (0.9, 0.7, 0.1), wear=0.7),
        "black": C.mat("black", (0.04, 0.04, 0.045), flat=True, dirt=0.7, rough=0.7),
        "rubber": C.mat("rubber", (0.05, 0.05, 0.055), flat=True, dirt=0.8, rough=0.85),
        "lamp": Z.glow("lamp", (1.0, 0.98, 0.88)),
        "lbox": Z.glow("lbox", (1.0, 0.82, 0.3)),
        "puddle": C.mat("puddle", (0.12, 0.15, 0.2), flat=True, dirt=0.0, rough=0.04),
        "stain": C.mat("stain", (0.2, 0.17, 0.12), flat=True, dirt=0.0, rough=0.8),
        "paper": C.mat("paper", (0.8, 0.78, 0.7), flat=True, dirt=0.8, rough=0.9),
        "ink": C.mat("ink", (0.05, 0.05, 0.06), flat=True, dirt=0.0, rough=0.8),
        "wood": C.mat("wood", (0.5, 0.35, 0.2), under=(0.3, 0.2, 0.11), wear=0.4, dirt=1.0, rough=0.85, scale=10, grain=(0.07, 1.0, 1.0)),
        "red": Z.paint("red", (0.7, 0.08, 0.06)),
    }


def views_wall():
    return [((3.2, -5.0, 2.0), (0, 0, 1.4)), ((1.0, -1.8, 1.4), (0.4, 0, 1.3))]


def wall_base(m, mat="tile", w=4.0, h=H):
    P = [C.box("wall", (w, 0.3, h), (0, 0.15, h / 2), bevel=0.01, m=m[mat])]
    # окантовка зелёной полосы и плинтус
    P.append(C.box("cap", (w, 0.03, 0.05), (0, -0.012, 1.12), bevel=0.006, m=m["green"], seg=1))
    P.append(C.box("plinth", (w, 0.025, 0.08), (0, -0.01, 0.04), bevel=0.005, m=m["conc"], seg=1))
    # сколы кафеля — бетонные заплатки
    for i, (x, z, sx, sz) in enumerate(((-1.3, 0.5, 0.22, 0.16), (1.1, 1.9, 0.14, 0.2), (0.3, 0.3, 0.3, 0.12), (-0.4, 2.3, 0.1, 0.1))):
        P.append(C.box("chip%d" % i, (sx, 0.012, sz), (x, -0.004, z), rot=(0, R(i * 9), 0), bevel=0.002, m=m["conc_l"], seg=1))
    # подтёки
    for i, x in enumerate((-1.6, 0.9, 1.7)):
        P.append(C.box("streak%d" % i, (0.05, 0.004, 0.9), (x, -0.003, 2.3), bevel=0, m=m["stain"], seg=1))
    return P


def wall_a(m=None):
    m = m or M()
    return wall_base(m), views_wall()


def wall_b(m=None):
    m = m or M()
    P = wall_base(m)
    # световой короб с рекламой
    P.append(C.box("lbox_f", (1.7, 0.1, 1.0), (0.2, -0.05, 1.95), bevel=0.012, m=m["dsteel"]))
    P.append(C.box("lbox_g", (1.58, 0.012, 0.88), (0.2, -0.105, 1.95), bevel=0, m=m["lbox"], seg=1))
    P.append(C.text("ad", "ПЕРВЫЙ ПРОХОД\nПОЧТИ БЕСПЛАТНЫЙ", 0.17, (0.2, -0.114, 1.95), rot=(R(90), 0, 0), font=C.FONT_IMPACT, extrude=0, m=m["ink"]))
    P.append(C.cable("wire", [(0.2, 0.0, 2.5), (0.5, -0.02, 2.9), (0.9, -0.02, 3.2)], r=0.01, m=m["black"]))
    return P, views_wall()


def wall_c(m=None):
    m = m or M()
    P = wall_base(m)
    # техническая дверь в нише
    P.append(C.box("frame", (1.35, 0.12, 2.3), (-0.5, -0.03, 1.15), bevel=0.01, m=m["dsteel"]))
    P.append(C.box("door", (1.1, 0.06, 2.1), (-0.5, -0.1, 1.07), bevel=0.01, m=m["dsteel"]))
    P.append(C.box("handle", (0.05, 0.05, 0.2), (-0.1, -0.15, 1.05), bevel=0.008, m=m["steel"]))
    P.append(C.box("lock", (0.1, 0.03, 0.14), (-0.1, -0.13, 1.25), bevel=0.006, m=m["black"]))
    P.append(C.box("nplate", (0.5, 0.01, 0.24), (-0.5, -0.135, 1.75), bevel=0, m=m["yellow"], seg=1))
    P.append(C.text("sten", "ТЕХ.\nПОМЕЩЕНИЕ", 0.07, (-0.5, -0.142, 1.75), rot=(R(90), 0, 0), font=C.FONT_IMPACT, extrude=0, m=m["ink"]))
    for i in range(3):
        P.append(C.cyl("rivet", 0.012, 0.01, (-0.95, -0.14, 0.4 + i * 0.7), rot=(R(90), 0, 0), verts=8, bevel=0, m=m["steel"]))
    return P, views_wall()


def wall_d(m=None):
    m = m or M()
    P = []
    # стена с нишей 1,8 × 2,2 глубиной 0,25: боковины и верх из кафеля, дно — бетон
    P.append(C.box("wl", (1.1, 0.3, H), (-1.45, 0.15, H / 2), bevel=0.01, m=m["tile"]))
    P.append(C.box("wr", (1.1, 0.3, H), (1.45, 0.15, H / 2), bevel=0.01, m=m["tile"]))
    P.append(C.box("wt", (1.8, 0.3, H - 2.2), (0, 0.15, 2.2 + (H - 2.2) / 2), bevel=0.01, m=m["tile"]))
    P.append(C.box("wb", (1.8, 0.05, 2.2), (0, 0.275, 1.1), bevel=0.008, m=m["conc"]))
    P.append(C.box("shelf", (1.7, 0.2, 0.04), (0, 0.15, 1.0), bevel=0.006, m=m["steel"]))
    P.append(C.box("niche_lamp", (1.5, 0.06, 0.05), (0, 0.18, 2.15), bevel=0.005, m=m["lamp"], seg=1))
    P.append(C.box("cap", (4.0, 0.03, 0.05), (0, -0.012, 1.12), bevel=0.006, m=m["green"], seg=1))
    P.append(C.box("plinth", (4.0, 0.025, 0.08), (0, -0.01, 0.04), bevel=0.005, m=m["conc"], seg=1))
    for i in range(4):
        P.append(C.box("tag%d" % i, (0.2, 0.004, 0.14), (-1.4 + i * 0.15, -0.003, 2.2 + 0.2 * (i % 2)), rot=(0, R(i * 11), 0), bevel=0, m=m["paper"], seg=1))
    return P, views_wall()


def wall_conc(m=None):
    m = m or M()
    P = [C.box("wall", (4.0, 0.3, H), (0, 0.15, H / 2), bevel=0.012, m=m["conc"])]
    for i in range(3):   # стыки плит и скобы
        P.append(C.box("joint%d" % i, (0.02, 0.012, H), (-1.33 + i * 1.33, -0.004, H / 2), bevel=0, m=m["black"], seg=1))
    for i in range(4):
        P.append(C.box("stain%d" % i, (0.3, 0.004, 0.1), (-1.5 + i * 1.0, -0.003, 0.5 + 0.7 * (i % 3)), bevel=0, m=m["stain"], seg=1))
    P.append(C.box("plinth", (4.0, 0.03, 0.15), (0, -0.01, 0.075), bevel=0.006, m=m["conc_l"], seg=1))
    return P, views_wall()


def corner_in(m=None):
    m = m or M()
    return [C.box("fillet", (0.4, 0.4, H), (0, 0.2, H / 2), bevel=0.03, m=m["tile"]), C.box("cap", (0.42, 0.42, 0.05), (0, 0.2, 1.12), bevel=0.006, m=m["green"], seg=1)], [((1.6, -2.4, 1.8), (0, 0, 1.4))]


def corner_out(m=None):
    m = m or M()
    P = [C.box("post", (0.4, 0.4, H), (0, 0.2, H / 2), bevel=0.04, m=m["tile"])]
    P.append(C.box("guard", (0.08, 0.08, 1.4), (-0.18, -0.02, 0.7), bevel=0.01, m=m["steel"]))
    P.append(C.box("cap", (0.44, 0.44, 0.05), (0, 0.2, 1.12), bevel=0.006, m=m["green"], seg=1))
    return P, [((1.6, -2.4, 1.8), (0, 0, 1.4))]


def column(m=None):
    m = m or M()
    P = [C.box("low", (0.6, 0.6, 1.5), (0, 0, 0.75), bevel=0.03, m=m["tile_col"]),
         C.box("up", (0.56, 0.56, H - 1.5), (0, 0, 1.5 + (H - 1.5) / 2), bevel=0.02, m=m["white"]),
         C.box("band", (0.64, 0.64, 0.4), (0, 0, 0.35), bevel=0.04, m=m["rubber"]),
         C.box("cap", (0.66, 0.66, 0.05), (0, 0, 1.52), bevel=0.01, m=m["green"], seg=1),
         C.box("capital", (0.7, 0.7, 0.12), (0, 0, H - 0.06), bevel=0.02, m=m["conc_l"])]
    P.append(C.box("sticker", (0.2, 0.004, 0.28), (0.1, -0.302, 2.0), bevel=0, m=m["paper"], seg=1))
    return P, [((2.2, -2.8, 1.9), (0, 0, 1.5))]


def floor_base(m, mat="conc"):
    P = [C.box("slab", (4.0, 4.0, 0.12), (0, 0, -0.06), bevel=0.006, m=m[mat])]
    P.append(C.box("jx", (4.0, 0.025, 0.006), (0, 0, 0.001), bevel=0, m=m["black"], seg=1))
    P.append(C.box("jy", (0.025, 4.0, 0.006), (0, 0, 0.001), bevel=0, m=m["black"], seg=1))
    return P


def views_floor():
    return [((3.8, -4.0, 3.2), (0, 0, 0)), ((1.2, -1.6, 1.2), (0, 0, 0))]


def floor_dry(m=None):
    m = m or M()
    P = floor_base(m)
    for i, (x, y) in enumerate(((-1.2, 0.8), (1.0, -1.1), (0.4, 1.4))):
        P.append(C.cyl("oil%d" % i, 0.22 + 0.05 * i, 0.003, (x, y, 0.003), verts=12, bevel=0, m=m["stain"]))
    return P, views_floor()


def floor_wet(m=None):
    m = m or M()
    P = floor_base(m)
    P.append(C.cyl("puddle", 1.0, 0.004, (-0.3, 0.2, 0.004), verts=18, bevel=0, m=m["puddle"]))
    P[-1].scale = (1.0, 0.7, 1.0)
    P.append(C.cyl("puddle2", 0.45, 0.004, (1.2, -1.0, 0.004), verts=14, bevel=0, m=m["puddle"]))
    return P, views_floor()


def floor_hatch(m=None):
    m = m or M()
    P = floor_base(m)
    P.append(C.cyl("ring", 0.42, 0.03, (0, 0, 0.0), verts=24, bevel=0.004, m=m["dsteel"]))
    P.append(C.cyl("lid", 0.37, 0.02, (0, 0, 0.012), verts=24, bevel=0.004, m=m["steel"]))
    for k in range(5):
        P.append(C.box("rib%d" % k, (0.62, 0.025, 0.012), (0, -0.2 + k * 0.1, 0.028), bevel=0.003, m=m["dsteel"], seg=1))
    return P, views_floor()


def floor_toll(m=None):
    m = m or M()
    P = floor_base(m)
    for i in range(5):
        P.append(C.box("yl%d" % i, (0.22, 4.0, 0.006), (-1.6 + i * 0.8, 0, 0.004), rot=(0, 0, R(0)), bevel=0, m=m["yellow"], seg=1))
    P.append(C.text("pay", "ПЛАТНАЯ ЗОНА", 0.26, (0, -1.5, 0.008), rot=(0, 0, 0), font=C.FONT_IMPACT, extrude=0, m=m["yellow"]))
    return P, views_floor()


def ceil_base(m):
    return [C.box("slab", (4.0, 4.0, 0.2), (0, 0, 0.1), bevel=0.008, m=m["conc_l"])]


def views_ceil():
    return [((3.6, -3.8, -2.4), (0, 0, 0.1)), ((1.0, -1.4, -1.4), (0, 0, 0.1))]


def ceil_beam(m=None):
    m = m or M()
    P = ceil_base(m)
    P.append(C.box("beam", (4.0, 0.4, 0.35), (0, 0, -0.175), bevel=0.012, m=m["conc"]))
    P.append(C.box("crack", (0.6, 0.02, 0.004), (1.0, 1.2, -0.002), rot=(0, 0, R(30)), bevel=0, m=m["black"], seg=1))
    return P, views_ceil()


def ceil_lamp(m=None):
    m = m or M()
    P = ceil_base(m)
    P.append(C.box("housing", (1.3, 0.3, 0.08), (0, 0, -0.04), bevel=0.01, m=m["dsteel"]))
    P.append(C.box("tube1", (1.15, 0.045, 0.03), (0, -0.07, -0.09), bevel=0.01, m=m["lamp"], seg=1))
    P.append(C.box("tube2", (1.15, 0.045, 0.03), (0, 0.07, -0.09), bevel=0.01, m=m["lamp"], seg=1))
    for i in range(7):
        P.append(C.box("grid%d" % i, (0.012, 0.3, 0.02), (-0.6 + i * 0.2, 0, -0.105), bevel=0, m=m["steel"], seg=1))
    P.append(C.box("gridl", (1.3, 0.012, 0.02), (0, 0, -0.105), bevel=0, m=m["steel"], seg=1))
    return P, views_ceil()


def ceil_vent(m=None):
    m = m or M()
    P = ceil_base(m)
    P.append(C.box("frame", (0.9, 0.9, 0.06), (0, 0, -0.03), bevel=0.01, m=m["steel"]))
    for i in range(7):
        P.append(C.box("louver%d" % i, (0.8, 0.07, 0.015), (0, -0.33 + i * 0.11, -0.07), rot=(R(25), 0, 0), bevel=0.002, m=m["dsteel"], seg=1))
    P.append(C.box("stain", (1.2, 1.2, 0.004), (0, 0, -0.002), bevel=0, m=m["stain"], seg=1))
    return P, views_ceil()


def ceil_pipes(m=None):
    m = m or M()
    P = ceil_base(m)
    for i, (y, r) in enumerate(((-1.2, 0.09), (-0.7, 0.05), (1.1, 0.07))):
        P.append(C.cyl("pipe%d" % i, r, 4.0, (0, y, -0.15), rot=(0, R(90), 0), verts=14, bevel=0.003, m=m["steel"]))
        for k in range(3):
            P.append(C.box("clamp%d_%d" % (i, k), (0.05, r * 2.6, r * 2.8), (-1.5 + k * 1.5, y, -0.1), bevel=0.006, m=m["dsteel"]))
    P.append(C.box("tray", (4.0, 0.5, 0.06), (0, 0.3, -0.25), bevel=0.006, m=m["dsteel"]))
    for k in range(3):
        P.append(C.cable("cab%d" % k, [(-2.0, 0.2 + k * 0.1, -0.22), (-1.0, 0.2 + k * 0.1, -0.34), (0, 0.2 + k * 0.1, -0.4), (1.0, 0.2 + k * 0.1, -0.34), (2.0, 0.2 + k * 0.1, -0.22)], r=0.012, m=m["black"]))
    return P, views_ceil()


def arch(m=None):
    m = m or M()
    P = [C.box("wl", (0.5, 0.3, H), (-1.75, 0.15, H / 2), bevel=0.01, m=m["tile"]),
         C.box("wr", (0.5, 0.3, H), (1.75, 0.15, H / 2), bevel=0.01, m=m["tile"]),
         C.box("wt", (3.0, 0.3, H - 2.7), (0, 0.15, 2.7 + (H - 2.7) / 2), bevel=0.01, m=m["tile_c"])]
    for s in (-1, 1):
        P.append(C.box("jamb", (0.1, 0.34, 2.7), (s * 1.45, 0.15, 1.35), bevel=0.01, m=m["conc_l"]))
    P.append(C.box("lintel", (3.0, 0.34, 0.1), (0, 0.15, 2.65), bevel=0.01, m=m["conc_l"]))
    for i in range(8):   # жёлто-чёрная кромка
        P.append(C.box("hz%d" % i, (0.2, 0.01, 0.07), (-1.4 + i * 0.4, -0.012, 2.58), rot=(0, R(25), 0), bevel=0, m=m["yellow" if i % 2 == 0 else "black"], seg=1))
    return P, views_wall()


def door_tech(m=None):
    m = m or M()
    P = [C.box("frame", (1.4, 0.2, 2.4), (0, 0.1, 1.2), bevel=0.01, m=m["dsteel"]),
         C.box("hole", (1.15, 0.22, 2.15), (0, 0.1, 1.08), bevel=0, m=m["black"]),
         C.box("door_leaf", (1.1, 0.06, 2.1), (0, -0.04, 1.06), bevel=0.01, m=m["dsteel"]),
         C.box("handle", (0.05, 0.05, 0.22), (0.4, -0.1, 1.05), bevel=0.008, m=m["steel"]),
         C.box("lock", (0.1, 0.03, 0.14), (0.4, -0.08, 1.3), bevel=0.006, m=m["black"]),
         C.box("nplate", (0.6, 0.01, 0.2), (0, -0.075, 1.8), bevel=0, m=m["yellow"], seg=1)]
    P.append(C.text("st", "ВХОД ЗАПРЕЩЁН", 0.06, (0, -0.082, 1.8), rot=(R(90), 0, 0), font=C.FONT_IMPACT, extrude=0, m=m["ink"]))
    for k in range(3):
        P.append(C.cyl("hinge", 0.025, 0.14, (-0.56, -0.02, 0.4 + k * 0.6), verts=8, bevel=0, m=m["steel"]))
    return P, [((2.0, -3.0, 1.6), (0, 0, 1.1)), ((0.6, -1.2, 1.3), (0.2, 0, 1.2))]


def grille(m=None):
    m = m or M()
    P = [C.box("frame", (3.0, 0.12, 2.6), (0, 0.06, 1.3), bevel=0.01, m=m["dsteel"]),
         C.box("hole", (2.8, 0.14, 2.4), (0, 0.06, 1.3), bevel=0, m=m["black"])]
    for i in range(13):
        P.append(C.cyl("bar%d" % i, 0.014, 2.4, (-1.3 + i * 0.2167, -0.02, 1.3), verts=8, bevel=0, m=m["steel"]))
    for z in (0.5, 1.3, 2.1):
        P.append(C.box("rail", (2.8, 0.03, 0.05), (0, -0.02, z), bevel=0.004, m=m["dsteel"]))
    P.append(C.box("grille_leaf", (0.04, 0.04, 0.04), (1.3, -0.04, 1.3), bevel=0, m=m["steel"], seg=1))
    P.append(C.box("lockbox", (0.2, 0.06, 0.2), (1.2, -0.06, 1.2), bevel=0.01, m=m["black"]))
    return P, [((2.4, -3.2, 1.7), (0, 0, 1.3))]


def shutter(m=None):
    m = m or M()
    P = [C.box("box", (3.2, 0.3, 0.35), (0, 0.05, 2.75), bevel=0.02, m=m["dsteel"]),
         C.box("gl", (0.12, 0.2, 2.6), (-1.55, 0.05, 1.3), bevel=0.01, m=m["steel"]),
         C.box("gr", (0.12, 0.2, 2.6), (1.55, 0.05, 1.3), bevel=0.01, m=m["steel"])]
    for i in range(22):
        P.append(C.box("shutter_sheet", (2.96, 0.05, 0.1), (0, -0.01, 2.5 - i * 0.11), bevel=0.01, m=m["steel"], seg=1))
    P.append(C.box("lockb", (0.15, 0.08, 0.1), (0, -0.06, 0.12), bevel=0.01, m=m["black"]))
    return P, [((2.4, -3.4, 1.6), (0, 0, 1.3)), ((0.6, -1.4, 1.1), (0, 0, 1.0))]


def stairs(m=None):
    m = m or M()
    """Лестничный марш 6 × 16 м, спуск 5 м: 28 ступеней; начало — верх по центру, спуск в −Y"""
    n = 28
    rise = 5.0 / n
    run_ = 16.0 / n
    P = []
    for i in range(n):
        z = 5.0 - (i + 1) * rise
        P.append(C.box("step%d" % i, (6.0, run_, 5.0 - z), (0, -(i + 0.5) * run_, (5.0 - z) / 2 + z - (5.0 - z) / 2 + (5.0 - z) / 2), bevel=0.01, m=m["conc"], seg=1))
        P.append(C.box("nose%d" % i, (5.7, 0.07, 0.025), (0, -(i + 0.04) * run_, 5.0 - (i) * rise - 0.01), bevel=0.003, m=m["rubber"], seg=1))
    # перила
    for sx in (-2.9, 0.0, 2.9):
        P.append(C.cable("rail", [(sx, 0, 6.0), (sx, -16.0, 1.0)], r=0.03, m=m["steel"], res=2))
        for k in range(0, 9):
            t = k / 8.0
            P.append(C.cyl("post", 0.02, 1.0, (sx, -16.0 * t, 5.5 - 5.0 * t), verts=6, bevel=0, m=m["dsteel"]))
    return P, [((6.0, 3.0, 8.0), (0, -8.0, 3.0)), ((3.0, -2.0, 6.2), (0, -6.0, 3.8))], 1024


def tunnel(m=None):
    m = m or M()
    """Тоннельная секция 4 × 4 × 2,8: бетонные стены, потолок, пол; трубы трёх диаметров с хомутами и вентилем, кабельный лоток, плафон в сетке"""
    P = [C.box("fl", (4.0, 4.0, 0.12), (0, 0, -0.06), bevel=0.006, m=m["conc"]),
         C.box("ce", (4.0, 4.0, 0.2), (0, 0, 2.9), bevel=0.01, m=m["conc_l"]),
         C.box("wl", (0.2, 4.0, 2.8), (-1.9, 0, 1.4), bevel=0.01, m=m["conc"]),
         C.box("wr", (0.2, 4.0, 2.8), (1.9, 0, 1.4), bevel=0.01, m=m["conc"])]
    for i, (z, r) in enumerate(((2.3, 0.09), (1.9, 0.05), (1.5, 0.07))):
        P.append(C.cyl("pipe%d" % i, r, 4.0, (-1.76, 0, z), rot=(R(90), 0, 0), verts=14, bevel=0.003, m=m["steel"]))
        for k in range(3):
            P.append(C.box("clamp%d_%d" % (i, k), (r * 2.8, 0.06, r * 2.8), (-1.78, -1.4 + k * 1.4, z), bevel=0.006, m=m["dsteel"]))
    P.append(C.cyl("valve_b", 0.07, 0.12, (-1.66, 0.4, 2.3), rot=(0, R(90), 0), verts=10, bevel=0.004, m=m["red"]))
    P.append(C.cyl("vent_wheel", 0.1, 0.02, (-1.55, 0.4, 2.3), rot=(0, R(90), 0), verts=12, bevel=0.003, m=m["red"]))
    P.append(C.box("tray", (0.4, 4.0, 0.05), (1.7, 0, 2.5), bevel=0.006, m=m["dsteel"]))
    for k in range(3):
        P.append(C.cable("cab%d" % k, [(1.6 + k * 0.1, -2.0, 2.52), (1.6 + k * 0.1, -1.0, 2.38), (1.6 + k * 0.1, 0, 2.3), (1.6 + k * 0.1, 1.0, 2.38), (1.6 + k * 0.1, 2.0, 2.52)], r=0.014, m=m["black"]))
    P.append(C.box("lamp_h", (0.35, 0.5, 0.2), (0, 0, 2.7), bevel=0.01, m=m["dsteel"]))
    P.append(C.box("lamp_g", (0.28, 0.42, 0.04), (0, 0, 2.58), bevel=0, m=m["lamp"], seg=1))
    for i in range(5):
        P.append(C.box("cage%d" % i, (0.34, 0.012, 0.012), (0, -0.2 + i * 0.1, 2.56), bevel=0, m=m["steel"], seg=1))
    P.append(C.cyl("puddle", 0.8, 0.004, (0, 0.3, 0.004), verts=14, bevel=0, m=m["puddle"]))
    return P, [((3.0, -4.6, 2.0), (0, 0, 1.4)), ((1.0, -2.2, 1.7), (-1.5, 0, 1.9))]


BUILD = {"wall_a": wall_a, "wall_b": wall_b, "wall_c": wall_c, "wall_d": wall_d, "wall_conc": wall_conc, "corner_in": corner_in, "corner_out": corner_out,
         "column": column, "floor_dry": floor_dry, "floor_wet": floor_wet, "floor_hatch": floor_hatch, "floor_toll": floor_toll,
         "ceil_beam": ceil_beam, "ceil_lamp": ceil_lamp, "ceil_vent": ceil_vent, "ceil_pipes": ceil_pipes, "arch": arch, "door_tech": door_tech,
         "grille": grille, "shutter": shutter, "stairs": stairs, "tunnel": tunnel}
Z.run(BUILD, 1024)
