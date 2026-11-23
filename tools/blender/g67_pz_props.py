"""Ларьки и галерея, турникеты и кассы, автоматы зала. Лицо — в −Y (в Godot +Z), начало — на полу по центру основания."""
import sys
import os
import math
sys.path.insert(0, os.path.dirname(__file__))
import g67_pz_common as Z
import g67_common as C

R = math.radians


def M():
    return {
        "zinc": C.mat("zinc", (0.62, 0.65, 0.66), under=(0.4, 0.3, 0.2), wear=0.55, dirt=1.0, rough=0.35, scale=14, streaks=0.8),
        "dsteel": Z.paint("dsteel", (0.2, 0.25, 0.28), wear=0.6),
        "steel": Z.steel("steel"),
        "black": C.mat("black", (0.04, 0.04, 0.045), flat=True, dirt=0.7, rough=0.7),
        "rubber": C.mat("rubber", (0.05, 0.05, 0.055), flat=True, dirt=0.8, rough=0.85),
        "green": Z.paint("green", (0.1, 0.45, 0.2)),
        "yellow": Z.paint("yellow", (0.92, 0.72, 0.1), wear=0.7),
        "red": Z.paint("red", (0.7, 0.08, 0.06)),
        "blue": Z.paint("blue", (0.12, 0.25, 0.55)),
        "white": Z.paint("white", (0.85, 0.84, 0.8), wear=0.5),
        "lbox": Z.glow("lbox", (1.0, 0.85, 0.35)),
        "lgreen": Z.glow("lgreen", (0.3, 1.0, 0.45)),
        "lred": Z.glow("lred", (1.0, 0.2, 0.15)),
        "lblue": Z.glow("lblue", (0.4, 0.75, 1.0)),
        "lwarm": Z.glow("lwarm", (1.0, 0.75, 0.4)),
        "lamp": Z.glow("lamp", (1.0, 0.98, 0.88)),
        "wood": C.mat("wood", (0.5, 0.35, 0.2), under=(0.3, 0.2, 0.11), wear=0.4, dirt=1.0, rough=0.85, scale=10, grain=(0.07, 1.0, 1.0)),
        "glassm": C.mat("glassm", (0.35, 0.5, 0.55), flat=True, dirt=0.5, rough=0.06),
        "paper": C.mat("paper", (0.82, 0.8, 0.7), flat=True, dirt=0.8, rough=0.9),
        "ink": C.mat("ink", (0.05, 0.05, 0.06), flat=True, dirt=0.0, rough=0.8),
        "meat": C.mat("meat", (0.5, 0.26, 0.12), flat=True, dirt=0.3, rough=0.7),
        "conc": Z.conc("conc"),
        "tile": Z.tile_mat("tile", "xz"),
        "sock1": C.mat("sock1", (0.8, 0.2, 0.2), flat=True, dirt=0.5, rough=0.95),
        "sock2": C.mat("sock2", (0.2, 0.5, 0.8), flat=True, dirt=0.5, rough=0.95),
        "sock3": C.mat("sock3", (0.9, 0.85, 0.3), flat=True, dirt=0.5, rough=0.95),
        "circuit": C.mat("circuit", (0.1, 0.4, 0.2), flat=True, dirt=0.3, rough=0.5),
    }


def sign(P, m, text, w, h, loc, bg="yellow", fg="ink", size=None, rot=(0, 0, 0), lines=1, glow=False):
    P.append(C.box("sg", (w, 0.06, h), loc, rot=rot, bevel=0.01, m=m["dsteel"]))
    P.append(C.box("sgp", (w - 0.06, 0.012, h - 0.06), (loc[0], loc[1] - 0.034, loc[2]), rot=rot, bevel=0, m=m["lbox" if glow else bg], seg=1))
    P.append(C.text("sgt", text, size or h * 0.55 / lines, (loc[0], loc[1] - 0.045, loc[2]), rot=(R(90),) + tuple(rot[1:]), font=C.FONT_IMPACT, extrude=0, m=m[fg]))


def views(d=3.6, h=1.8):
    return [((d, -d * 1.3, h), (0, 0, h * 0.6)), ((d * 0.35, -d * 0.55, h * 0.8), (0, 0, h * 0.55))]


def kiosk_frame(m, P, W=3.0, D=2.2, Hh=2.6):
    """каркас ларька из оцинковки: задняя стена и бока, козырёк, прилавок, световой короб"""
    P.append(C.box("floor", (W, D, 0.08), (0, 0, 0.04), bevel=0.01, m=m["conc"]))
    P.append(C.box("back", (W, 0.08, Hh), (0, D / 2 - 0.04, Hh / 2), bevel=0.01, m=m["zinc"]))
    for s in (-1, 1):
        P.append(C.box("side", (0.08, D, Hh), (s * (W / 2 - 0.04), 0, Hh / 2), bevel=0.01, m=m["zinc"]))
    for i in range(5):  # профильные рёбра жести
        P.append(C.box("rib", (0.03, 0.02, Hh), (-1.2 + i * 0.6, D / 2 - 0.09, Hh / 2), bevel=0.004, m=m["steel"], seg=1))
    P.append(C.box("roof", (W + 0.3, D + 0.4, 0.08), (0, -0.1, Hh + 0.04), rot=(R(-4), 0, 0), bevel=0.01, m=m["zinc"]))
    P.append(C.box("counter", (W, 0.5, 0.08), (0, -D / 2 + 0.05, 1.0), bevel=0.01, m=m["steel"]))
    P.append(C.box("front_low", (W, 0.06, 1.0), (0, -D / 2 + 0.2, 0.5), bevel=0.01, m=m["zinc"]))
    P.append(C.box("awning", (W + 0.2, 0.6, 0.04), (0, -D / 2 - 0.2, Hh - 0.15), rot=(R(12), 0, 0), bevel=0.01, m=m["green"]))
    P.append(C.box("eave", (W + 0.2, 0.05, 0.12), (0, -D / 2 - 0.5, Hh - 0.33), bevel=0.01, m=m["green"]))
    P.append(C.box("bulbbar", (W, 0.03, 0.03), (0, -D / 2 - 0.35, Hh - 0.2), bevel=0, m=m["steel"], seg=1))
    for i in range(7):
        P.append(C.sphere("bulb", 0.035, (-1.35 + i * 0.45, -D / 2 - 0.36, Hh - 0.24), seg=8, m=m["lwarm"]))
    P.append(C.cable("wire", [(1.6, -0.6, Hh - 0.1), (1.7, -0.3, Hh - 0.6), (1.62, 0.2, 1.4)], r=0.012, m=m["black"]))


def kiosk_shawarma(m=None):
    m = m or M()
    P = []
    kiosk_frame(m, P)
    sign(P, m, "ШАУРМА 812", 2.4, 0.45, (0, -1.6, 2.5), bg="red", fg="ink", glow=True)
    P.append(C.cyl("spit", 0.17, 0.6, (0.2, -0.6, 1.5), verts=14, bevel=0.01, m=m["meat"], r2=0.1))
    P.append(C.cyl("rod", 0.014, 0.9, (0.2, -0.6, 1.5), verts=6, bevel=0, m=m["steel"]))
    P.append(C.box("grill", (0.5, 0.08, 0.6), (0.2, -0.3, 1.5), bevel=0.01, m=m["lred"]))
    P.append(C.box("menu", (0.7, 0.03, 0.5), (-0.9, -1.0, 1.9), bevel=0, m=m["paper"], seg=1))
    P.append(C.text("tm", "С ЧЕРЕМШОЙ\nНЕ ПРЕДЛАГАТЬ", 0.06, (-0.9, -1.02, 1.9), rot=(R(90), 0, 0), font=C.FONT_IMPACT, extrude=0, m=m["ink"]))
    P.append(C.box("sauce1", (0.12, 0.12, 0.25), (-0.6, -0.9, 1.17), bevel=0.02, m=m["red"]))
    P.append(C.box("sauce2", (0.12, 0.12, 0.25), (-0.4, -0.9, 1.17), bevel=0.02, m=m["yellow"]))
    return P, views()


def kiosk_phones(m=None):
    m = m or M()
    P = []
    kiosk_frame(m, P)
    sign(P, m, "РЕМОНТ ТЕЛЕФОНОВ\nЧИНИМ ДО ПОЛНОЙ ПОЛОМКИ", 2.6, 0.55, (0, -1.6, 2.5), bg="blue", fg="ink", lines=2, glow=True)
    for i in range(5):
        P.append(C.box("phone%d" % i, (0.09, 0.15, 0.012), (-1.0 + i * 0.3, -0.95, 1.05), rot=(0, 0, R(i * 17)), bevel=0.003, m=m["black"] if i % 2 else m["circuit"], seg=1))
    P.append(C.cyl("iron", 0.012, 0.25, (0.9, -0.9, 1.1), rot=(R(80), 0, R(20)), verts=6, bevel=0, m=m["red"]))
    P.append(C.box("lamp_arm", (0.04, 0.04, 0.5), (-1.3, -0.8, 1.3), bevel=0.005, m=m["dsteel"]))
    P.append(C.box("lamp_h", (0.25, 0.1, 0.06), (-1.2, -0.8, 1.55), bevel=0.01, m=m["lamp"]))
    return P, views()


def kiosk_socks(m=None):
    m = m or M()
    P = []
    kiosk_frame(m, P)
    sign(P, m, "НОСКИ. БАФЫ.\nОБМЕНУ НЕ ПОДЛЕЖАТ", 2.6, 0.55, (0, -1.6, 2.5), bg="yellow", fg="ink", lines=2, glow=True)
    k = 0
    for r in range(4):
        for c in range(9):
            mm = ("sock1", "sock2", "sock3")[(r + c) % 3]
            P.append(C.box("sock%d" % k, (0.1, 0.03, 0.22), (-1.2 + c * 0.3, 1.0, 1.35 + r * 0.28), bevel=0.01, m=m[mm]))
            k += 1
    for c in range(9):
        P.append(C.box("peg%d" % c, (0.02, 0.1, 0.02), (-1.2 + c * 0.3, 1.0, 1.5), bevel=0, m=m["steel"], seg=1))
    return P, views()


def kiosk_keys(m=None):
    m = m or M()
    P = []
    kiosk_frame(m, P)
    sign(P, m, "КЛЮЧИ ЗА 8 МИНУТ\nОТ ЧЕГО — НЕ НАШЕ ДЕЛО", 2.6, 0.55, (0, -1.6, 2.5), bg="green", fg="ink", lines=2, glow=True)
    P.append(C.box("board", (2.2, 0.04, 0.9), (0, 0.95, 1.6), bevel=0.01, m=m["wood"]))
    for i in range(16):
        P.append(C.box("key%d" % i, (0.05, 0.012, 0.16), (-1.0 + (i % 8) * 0.28, 0.9, 1.8 - (i // 8) * 0.35), bevel=0.003, m=m["steel"], seg=1))
        P.append(C.cyl("keyr%d" % i, 0.03, 0.012, (-1.0 + (i % 8) * 0.28, 0.9, 1.9 - (i // 8) * 0.35), rot=(R(90), 0, 0), verts=8, bevel=0, m=m["steel"]))
    P.append(C.box("mach", (0.5, 0.4, 0.4), (0.9, -0.5, 1.25), bevel=0.02, m=m["dsteel"]))
    P.append(C.box("mwheel", (0.2, 0.02, 0.2), (0.9, -0.72, 1.3), bevel=0.01, m=m["steel"]))
    return P, views()


def kiosk_odds(m=None):
    m = m or M()
    P = []
    kiosk_frame(m, P)
    sign(P, m, "МЕЛОЧИ", 1.8, 0.45, (0, -1.6, 2.5), bg="red", fg="ink", glow=True)
    for r in range(3):
        for c in range(6):
            P.append(C.box("item%d_%d" % (r, c), (0.16, 0.1, 0.12 + 0.03 * ((r + c) % 3)), (-1.0 + c * 0.38, 0.9, 1.2 + r * 0.4), bevel=0.01, m=m[("sock1", "sock2", "sock3", "yellow", "green", "blue")[(r * 6 + c) % 6]]))
    P.append(C.box("shelf1", (2.4, 0.3, 0.04), (0, 0.9, 1.12), bevel=0.004, m=m["wood"]))
    P.append(C.box("shelf2", (2.4, 0.3, 0.04), (0, 0.9, 1.52), bevel=0.004, m=m["wood"]))
    P.append(C.box("shelf3", (2.4, 0.3, 0.04), (0, 0.9, 1.92), bevel=0.004, m=m["wood"]))
    return P, views()


def kiosk_exchange(m=None):
    m = m or M()
    P = []
    kiosk_frame(m, P)
    sign(P, m, "ОБМЕН\nСДАЧА — ПОТОМ", 2.2, 0.55, (0, -1.6, 2.5), bg="yellow", fg="ink", lines=2, glow=True)
    P.append(C.box("window_f", (1.3, 0.12, 0.9), (0, -1.0, 1.55), bevel=0.01, m=m["dsteel"]))
    P.append(C.box("glass", (1.1, 0.02, 0.7), (0, -1.07, 1.55), bevel=0, m=m["glassm"], seg=1))
    P.append(C.box("tray", (0.4, 0.3, 0.03), (0, -1.15, 1.12), bevel=0.005, m=m["steel"]))
    P.append(C.box("speak", (0.25, 0.02, 0.18), (0.5, -1.09, 1.6), bevel=0, m=m["black"], seg=1))
    for i in range(7):
        P.append(C.box("slot%d" % i, (0.04, 0.02, 0.14), (-0.45 + i * 0.05, -1.06, 1.6), bevel=0, m=m["black"], seg=1))
    return P, views()


def bench(m=None):
    m = m or M()
    P = [C.box("bseat", (1.8, 0.45, 0.06), (0, 0, 0.48), bevel=0.01, m=m["wood"]),
         C.box("back", (1.8, 0.06, 0.4), (0, 0.22, 0.8), rot=(R(-8), 0, 0), bevel=0.01, m=m["wood"])]
    for s in (-0.75, 0.75):
        P.append(C.box("leg", (0.06, 0.45, 0.48), (s, 0, 0.24), bevel=0.008, m=m["dsteel"]))
    return P, [((2.4, -2.6, 1.4), (0, 0, 0.5)), ((0.8, -1.1, 0.8), (0, 0, 0.5))], 512


def bin_(m=None):
    m = m or M()
    P = [C.cyl("bin", 0.22, 0.7, (0, 0, 0.35), verts=14, bevel=0.01, m=m["green"], r2=0.19),
         C.cyl("rim", 0.24, 0.05, (0, 0, 0.72), verts=14, bevel=0.005, m=m["steel"]),
         C.cyl("hole", 0.15, 0.02, (0, 0, 0.74), verts=12, bevel=0, m=m["black"])]
    P.append(C.box("ash", (0.18, 0.18, 0.04), (0, 0.2, 0.55), bevel=0.005, m=m["steel"]))
    return P, [((1.4, -1.6, 1.1), (0, 0, 0.4)), ((0.5, -0.7, 0.7), (0, 0, 0.4))], 512


def arrow_sign(m=None):
    m = m or M()
    P = [C.cyl("pole", 0.03, 2.4, (0, 0, 1.2), verts=8, bevel=0, m=m["dsteel"]),
         C.box("base", (0.3, 0.3, 0.06), (0, 0, 0.03), bevel=0.01, m=m["conc"])]
    for i, (txt, z, col) in enumerate((("ВЫХОД БЕСПЛАТНЫЙ →", 2.2, "green"), ("← ПРОХОД ПО ТАРИФУ", 1.8, "yellow"))):
        P.append(C.box("pl%d" % i, (1.4, 0.05, 0.3), (0.5 if i == 0 else -0.5, -0.04, z), bevel=0.01, m=m[col]))
        P.append(C.text("t%d" % i, txt, 0.1, (0.5 if i == 0 else -0.5, -0.07, z), rot=(R(90), 0, 0), font=C.FONT_IMPACT, extrude=0, m=m["ink"]))
    return P, [((2.4, -3.0, 1.9), (0, 0, 1.5)), ((0.8, -1.3, 2.1), (0.2, 0, 2.0))]


def cross_green(m=None):
    m = m or M()
    P = [C.box("pl", (0.9, 0.12, 0.9), (0, 0, 0.45), bevel=0.02, m=m["dsteel"])]
    P.append(C.box("v", (0.2, 0.05, 0.7), (0, -0.07, 0.45), bevel=0.01, m=m["lgreen"], seg=1))
    P.append(C.box("h", (0.7, 0.05, 0.2), (0, -0.07, 0.45), bevel=0.01, m=m["lgreen"], seg=1))
    P.append(C.box("arm", (0.06, 0.4, 0.06), (0, 0.2, 0.9), bevel=0.005, m=m["dsteel"]))
    return P, [((1.6, -2.0, 0.8), (0, 0, 0.45)), ((0.5, -0.9, 0.6), (0, 0, 0.45))], 512


def turnstile(m=None):
    m = m or M()
    """Турникет метро: массивная тумба из нержавейки с круглыми торцами, окно индикатора (стрелка/крест, эмиссия), приёмник карты, монетоприёмник,
    жёлто-чёрная полоса, наклейка тарифа, царапины; створки turnstile_gate на осях в тумбе, трипод turnstile_arm/turnstile_rotor"""
    m = m or M()
    P = [C.box("post", (0.34, 1.1, 1.0), (0, 0, 0.55), bevel=0.11, m=m["steel"]),
         C.box("base", (0.5, 1.2, 0.05), (0, 0, 0.025), bevel=0.008, m=m["rubber"]),
         C.box("top", (0.38, 1.14, 0.07), (0, 0, 1.06), bevel=0.03, m=m["dsteel"]),
         C.box("ind_frame", (0.2, 0.012, 0.2), (-0.172, -0.3, 0.9), bevel=0.004, m=m["black"]),
         C.box("ind_arrow", (0.04, 0.008, 0.12), (-0.18, -0.3, 0.9), bevel=0, m=m["lgreen"], seg=1),
         C.box("ind_head", (0.12, 0.008, 0.04), (-0.18, -0.3, 0.85), rot=(0, R(35), 0), bevel=0, m=m["lgreen"], seg=1),
         C.box("reader", (0.2, 0.26, 0.05), (0, -0.33, 1.12), rot=(R(-12), 0, 0), bevel=0.012, m=m["black"]),
         C.box("reader_glow", (0.1, 0.012, 0.012), (0, -0.4, 1.135), bevel=0, m=m["lblue"], seg=1),
         C.box("coin_plate", (0.1, 0.01, 0.14), (-0.172, 0.2, 0.9), bevel=0.003, m=m["black"], seg=1),
         C.box("coin_slot", (0.012, 0.012, 0.07), (-0.178, 0.2, 0.9), bevel=0, m=m["steel"], seg=1),
         C.box("stripe_a", (0.345, 0.2, 0.06), (0, -0.35, 0.42), bevel=0, m=m["yellow"], seg=1),
         C.box("tariff", (0.01, 0.2, 0.14), (-0.172, 0.0, 0.65), bevel=0, m=m["yellow"], seg=1),
         C.text("tt", "ВХОД 8", 0.05, (-0.178, 0.0, 0.65), rot=(R(90), 0, R(90)), font=C.FONT_IMPACT, extrude=0, m=m["ink"])]
    for i in range(6):
        P.append(C.box("scr%d" % i, (0.002, 0.2 + 0.05 * (i % 3), 0.004), (-0.172, 0.35 - 0.15 * i, 0.4 + 0.11 * i), rot=(R(10 * i), 0, 0), bevel=0, m=m["steel"], seg=1))
    for s_ in (-1, 1):
        g = C.box("turnstile_gate", (0.03, 0.46, 0.85), (s_ * 0.36, -0.28, 0.0), bevel=0.01, m=m["glassm"])
        g.location = (s_ * 0.36, -0.28, 0.9)
        C.pivot(g, (s_ * 0.2, 0.0, 0.9))
        P.append(g)
        P.append(C.box("hinge", (0.06, 0.06, 0.12), (s_ * 0.2, 0.0, 0.9), bevel=0.01, m=m["dsteel"]))
    ro = C.cyl("turnstile_rotor", 0.05, 0.1, (0.0, 0.5, 0.95), verts=12, bevel=0.005, m=m["dsteel"])
    P.append(ro)
    for k in range(3):
        a = k * math.tau / 3
        P.append(C.cyl("turnstile_arm", 0.018, 0.48, (math.sin(a) * 0.24, 0.5, 0.95 + math.cos(a) * 0.24), rot=(0, a + R(90) * 0, 0), verts=8, bevel=0, m=m["steel"]))
    return P, [((2.4, -3.0, 1.6), (0, 0, 0.7)), ((0.8, -1.2, 1.3), (0, 0, 0.9))]


def booth(m=None):
    m = m or M()
    """Кассовая будка gate1: 2 × 1,6 × 2,6, окно со стеклом, лоток для денег, вывеска"""
    P = [C.box("floor", (2.0, 1.6, 0.1), (0, 0, 0.05), bevel=0.01, m=m["conc"]),
         C.box("back", (2.0, 0.1, 2.6), (0, 0.75, 1.3), bevel=0.01, m=m["zinc"]),
         C.box("sl", (0.1, 1.6, 2.6), (-0.95, 0, 1.3), bevel=0.01, m=m["zinc"]),
         C.box("sr", (0.1, 1.6, 2.6), (0.95, 0, 1.3), bevel=0.01, m=m["zinc"]),
         C.box("roof", (2.2, 1.8, 0.1), (0, 0, 2.65), bevel=0.01, m=m["dsteel"]),
         C.box("front_low", (2.0, 0.1, 1.05), (0, -0.75, 0.55), bevel=0.01, m=m["zinc"]),
         C.box("front_up", (2.0, 0.1, 0.55), (0, -0.75, 2.3), bevel=0.01, m=m["zinc"]),
         C.box("counter", (2.0, 0.4, 0.06), (0, -0.92, 1.1), bevel=0.01, m=m["steel"]),
         C.box("glass", (1.8, 0.02, 0.95), (0, -0.74, 1.78), bevel=0, m=m["glassm"], seg=1),
         C.box("tray", (0.4, 0.25, 0.03), (0, -0.88, 1.15), bevel=0.005, m=m["dsteel"])]
    sign(P, m, "КАССА", 1.2, 0.3, (0, -0.85, 2.45), bg="yellow", fg="ink", glow=True)
    P.append(C.box("chair", (0.4, 0.4, 0.05), (0.3, 0.2, 0.55), bevel=0.01, m=m["dsteel"]))
    P.append(C.box("monitor", (0.35, 0.05, 0.28), (-0.5, -0.35, 1.3), bevel=0.01, m=m["black"]))
    P.append(C.box("tariff", (0.5, 0.01, 0.35), (0.7, -0.76, 1.95), bevel=0, m=m["paper"], seg=1))
    return P, [((3.4, -4.2, 2.2), (0, 0, 1.3)), ((1.0, -2.0, 1.7), (0, -0.7, 1.4))]


def cash_shield(m=None):
    m = m or M()
    """Касса-щит босса: стена касс с окнами; стекло — узел glass; семь окон и восьмое заложено кирпичом"""
    W = 14.0
    P = [C.box("wall", (W, 0.5, 3.2), (0, 0.25, 1.6), bevel=0.02, m=m["zinc"])]
    P.append(C.box("counter", (W, 0.7, 0.1), (0, -0.2, 1.1), bevel=0.01, m=m["steel"]))
    for i in range(8):
        x = -6.0 + i * 1.7
        if i == 7:
            for r in range(5):
                for c in range(3):
                    P.append(C.box("brick", (0.34, 0.05, 0.14), (x - 0.3 + c * 0.35 + (0.17 if r % 2 else 0), -0.03, 1.4 + r * 0.17), bevel=0.004, m=m["red"], seg=1))
            P.append(C.box("brickf", (1.2, 0.08, 1.2), (x, 0.02, 1.8), bevel=0.01, m=m["dsteel"]))
            P.append(C.text("n8", "8", 0.4, (x, -0.05, 2.65), rot=(R(90), 0, 0), font=C.FONT_IMPACT, extrude=0.01, m=m["black"]))
            continue
        P.append(C.box("win%d" % i, (1.2, 0.1, 1.0), (x, -0.02, 1.8), bevel=0.01, m=m["dsteel"]))
        P.append(C.box("glass", (1.05, 0.02, 0.85), (x, -0.1, 1.8), bevel=0, m=m["glassm"], seg=1))
        P.append(C.box("tray%d" % i, (0.3, 0.3, 0.03), (x, -0.3, 1.16), bevel=0.005, m=m["dsteel"]))
        P.append(C.box("num%d" % i, (0.3, 0.03, 0.3), (x, -0.06, 2.65), bevel=0.01, m=m["lbox"]))
        P.append(C.text("t%d" % i, str(i + 1), 0.25, (x, -0.08, 2.65), rot=(R(90), 0, 0), font=C.FONT_IMPACT, extrude=0, m=m["ink"]))
    P.append(C.box("plate", (4.0, 0.03, 0.3), (0, -0.04, 3.0), bevel=0, m=m["yellow"], seg=1))
    P.append(C.text("sgn", "КАССА № 8 НЕ СУЩЕСТВУЕТ", 0.2, (0, -0.06, 3.0), rot=(R(90), 0, 0), font=C.FONT_IMPACT, extrude=0, m=m["ink"]))
    return P, [((6.0, -9.0, 2.4), (0, 0, 1.7)), ((-3.0, -3.5, 1.9), (-4.0, 0, 1.8))], 2048


def tariff_board(m=None):
    m = m or M()
    """Табло тарифов: панель и отдельные строки под эмиссию (материал lbox)"""
    P = [C.box("panel", (4.0, 0.15, 2.0), (0, 0, 1.0), bevel=0.02, m=m["dsteel"]),
         C.box("screen", (3.8, 0.02, 1.8), (0, -0.085, 1.0), bevel=0, m=m["black"], seg=1)]
    rows = (("ВХОД — 8", "lbox"), ("ВЫХОД — 67", "lbox"), ("ВОПРОС — 67", "lbox"), ("ОТВЕТ — ПО ДОГОВОРЁННОСТИ", "lbox"), ("ПОСТОЯТЬ — 8/МИН", "lbox"), ("ВДОХ — ПЕРВЫЙ БЕСПЛАТНО", "lgreen"))
    for i, (t, c) in enumerate(rows):
        P.append(C.text("row%d" % i, t, 0.2, (0, -0.1, 1.72 - i * 0.3), rot=(R(90), 0, 0), font=C.FONT_IMPACT, extrude=0, m=m[c]))
    P.append(C.box("frame_t", (4.1, 0.2, 0.08), (0, 0, 2.03), bevel=0.01, m=m["yellow"]))
    P.append(C.box("frame_b", (4.1, 0.2, 0.08), (0, 0, -0.03), bevel=0.01, m=m["yellow"]))
    for s in (-1, 1):
        P.append(C.cable("hang", [(s * 1.8, 0, 2.05), (s * 1.8, 0.05, 2.6), (s * 1.8, 0.1, 3.0)], r=0.015, m=m["steel"], res=2))
    return P, [((4.0, -5.0, 1.6), (0, 0, 1.0)), ((1.2, -1.8, 1.4), (-0.3, 0, 1.2))], 1024


def receipt_printer(m=None):
    m = m or M()
    P = [C.box("cabinet", (0.9, 0.6, 0.7), (0, 0, 0.35), bevel=0.04, m=m["dsteel"]),
         C.box("top", (0.8, 0.5, 0.05), (0, 0, 0.72), bevel=0.01, m=m["steel"]),
         C.box("slot", (0.5, 0.04, 0.03), (0, -0.31, 0.5), bevel=0, m=m["black"], seg=1),
         C.cyl("receipt_roll", 0.14, 0.4, (0, 0.1, 0.9), rot=(0, R(90), 0), verts=16, bevel=0.005, m=m["paper"]),
         C.box("paper", (0.4, 0.5, 0.004), (0, -0.55, 0.3), rot=(R(-35), 0, 0), bevel=0, m=m["paper"], seg=1),
         C.box("led", (0.05, 0.02, 0.05), (0.3, -0.31, 0.62), bevel=0, m=m["lgreen"], seg=1)]
    for i in range(3):
        P.append(C.box("ln%d" % i, (0.3, 0.003, 0.012), (0, -0.56 - i * 0.04, 0.33 - i * 0.03), rot=(R(-35), 0, 0), bevel=0, m=m["ink"], seg=1))
    return P, [((1.8, -2.2, 1.3), (0, 0, 0.5)), ((0.6, -0.9, 0.8), (0, -0.2, 0.5))], 512


def fortuna_wheel(m=None):
    m = m or M()
    """Колесо FORTUNA: обод с лампочками, секторы (цены), ось; узел fortuna_sign_wheel вращается"""
    n = 12
    P = [C.torus("fortuna_sign_wheel", 1.5, 0.12, (0, 0, 1.6), rot=(R(90), 0, 0), ms=36, mn=8, m=m["red"])]
    P.append(C.cyl("hub", 0.3, 0.2, (0, 0, 1.6), rot=(R(90), 0, 0), verts=16, bevel=0.01, m=m["yellow"]))
    for i in range(n):
        a = i * math.tau / n
        P.append(C.box("spoke%d" % i, (0.08, 0.06, 1.3), (math.sin(a) * 0.9, 0, 1.6 + math.cos(a) * 0.9), rot=(0, a, 0), bevel=0.008, m=m["yellow" if i % 2 else "red"]))
        P.append(C.sphere("bulb%d" % i, 0.08, (math.sin(a) * 1.5, -0.14, 1.6 + math.cos(a) * 1.5), seg=8, m=m["lbox"]))
        P.append(C.text("pr%d" % i, ("67", "812", "6,7", "0", "67", "812", "6,7", "0", "67", "812", "6,7", "0")[i], 0.16, (math.sin(a) * 1.05, -0.08, 1.6 + math.cos(a) * 1.05), rot=(R(90), 0, 0), font=C.FONT_IMPACT, extrude=0, m=m["ink"]))
    P.append(C.box("stand", (0.4, 0.3, 0.12), (0, 0.1, 0.06), bevel=0.01, m=m["dsteel"]))
    P.append(C.box("leg", (0.3, 0.25, 0.3), (0, 0.1, 0.28), bevel=0.01, m=m["dsteel"]))
    P.append(C.text("sgn", "FORTUNA 812", 0.28, (0, -0.15, 3.35), rot=(R(90), 0, 0), font=C.FONT_IMPACT, extrude=0.01, m=m["yellow"]))
    return P, [((3.8, -5.0, 2.2), (0, 0, 1.6)), ((1.2, -2.2, 2.0), (-0.3, 0, 1.8))], 1024


def queue_stand(m=None):
    m = m or M()
    P = [C.cyl("post", 0.03, 0.95, (0, 0, 0.5), verts=8, bevel=0, m=m["steel"]),
         C.cyl("base", 0.18, 0.04, (0, 0, 0.02), verts=14, bevel=0.005, m=m["steel"]),
         C.sphere("top", 0.05, (0, 0, 1.0), seg=8, m=m["steel"]),
         C.box("tape", (1.4, 0.04, 0.05), (0.7, 0, 0.88), rot=(0, R(-4), 0), bevel=0.002, m=m["yellow"], seg=1)]
    P.append(C.cable("tape_sag", [(0, 0, 0.9), (0.5, 0, 0.84), (1.0, 0, 0.84), (1.4, 0, 0.9)], r=0.015, m=m["red"], res=2))
    return P, [((2.4, -2.6, 1.3), (0.5, 0, 0.6)), ((1.0, -1.0, 1.0), (0.4, 0, 0.8))], 512


def storage(m=None):
    m = m or M()
    """Камера хранения: стена ячеек 4 × 3 (3 м × 2,2), одна дверца открыта, вывеска"""
    P = [C.box("frame", (3.2, 0.5, 2.4), (0, 0.25, 1.2), bevel=0.02, m=m["dsteel"])]
    k = 0
    for r in range(4):
        for c in range(5):
            x = -1.2 + c * 0.6
            z = 0.35 + r * 0.55
            if r == 1 and c == 2:
                P.append(C.box("hole", (0.54, 0.4, 0.5), (x, 0.1, z), bevel=0, m=m["black"]))
                P.append(C.box("door_open", (0.5, 0.03, 0.5), (x + 0.4, -0.25, z), rot=(0, 0, R(0)), bevel=0.005, m=m["yellow"]))
                P.append(C.box("bag", (0.35, 0.25, 0.3), (x, 0.05, z - 0.08), bevel=0.04, m=m["blue"]))
            else:
                P.append(C.box("door%d" % k, (0.54, 0.03, 0.5), (x, -0.01, z), bevel=0.006, m=m[("yellow", "green", "blue", "red")[(r + c) % 4]]))
                P.append(C.box("knob%d" % k, (0.04, 0.03, 0.04), (x + 0.2, -0.04, z), bevel=0.004, m=m["steel"], seg=1))
                P.append(C.text("no%d" % k, str(k + 1), 0.1, (x - 0.15, -0.03, z + 0.1), rot=(R(90), 0, 0), font=C.FONT_IMPACT, extrude=0, m=m["ink"]))
            k += 1
    sign(P, m, "КАМЕРА ХРАНЕНИЯ\nХРАНИМ. ВЫДАЁМ — ПО ТАРИФУ", 3.0, 0.5, (0, -0.1, 2.7), bg="green", fg="ink", lines=2, glow=True)
    return P, [((3.4, -4.0, 2.0), (0, 0, 1.3)), ((1.0, -1.7, 1.4), (0, 0, 1.0))]


def vend_base(m, body, name, W=0.95, D=0.8, Hh=1.9):
    P = [C.box("cabinet", (W, D, Hh), (0, 0, Hh / 2), bevel=0.03, m=m[body]),
         C.box("base", (W + 0.04, D + 0.04, 0.08), (0, 0, 0.04), bevel=0.01, m=m["rubber"]),
         C.box("tray", (0.5, 0.12, 0.2), (0.0, -D / 2 - 0.0, 0.3), bevel=0.01, m=m["black"]),
         C.box("pay", (0.2, 0.02, 0.3), (0.35, -D / 2 - 0.01, 1.1), bevel=0.003, m=m["black"], seg=1),
         C.box("pad", (0.12, 0.012, 0.16), (0.35, -D / 2 - 0.02, 1.15), bevel=0, m=m["lgreen"], seg=1)]
    return P


def vend_drinks(m=None):
    m = m or M()
    P = vend_base(m, "blue", "drinks")
    P.append(C.box("glass", (0.6, 0.02, 1.2), (-0.12, -0.41, 1.15), bevel=0, m=m["glassm"], seg=1))
    for r in range(4):
        for c in range(4):
            P.append(C.cyl("can%d_%d" % (r, c), 0.045, 0.14, (-0.32 + c * 0.13, -0.33, 0.7 + r * 0.28), verts=8, bevel=0.004, m=m[("red", "yellow", "green", "white")[(r + c) % 4]]))
    P.append(C.box("lb", (0.9, 0.02, 0.22), (0, -0.41, 1.78), bevel=0, m=m["lblue"], seg=1))
    P.append(C.text("lbt", "НАПИТКИ ПО ТАРИФУ", 0.09, (0, -0.42, 1.78), rot=(R(90), 0, 0), font=C.FONT_IMPACT, extrude=0, m=m["ink"]))
    return P, [((2.2, -2.8, 1.6), (0, 0, 1.0)), ((0.7, -1.2, 1.3), (0, -0.4, 1.1))]


def vend_snacks(m=None):
    m = m or M()
    P = vend_base(m, "red", "snacks")
    P.append(C.box("glass", (0.6, 0.02, 1.2), (-0.12, -0.41, 1.15), bevel=0, m=m["glassm"], seg=1))
    for r in range(5):
        P.append(C.box("coil%d" % r, (0.56, 0.02, 0.012), (-0.12, -0.35, 0.65 + r * 0.24), bevel=0, m=m["steel"], seg=1))
        for c in range(4):
            P.append(C.box("pack%d_%d" % (r, c), (0.1, 0.03, 0.16), (-0.32 + c * 0.13, -0.33, 0.75 + r * 0.24), bevel=0.004, m=m[("yellow", "green", "blue", "red")[(r * 2 + c) % 4]]))
    P.append(C.box("lb", (0.9, 0.02, 0.22), (0, -0.41, 1.78), bevel=0, m=m["lbox"], seg=1))
    P.append(C.text("lbt", "ЕДА ПО ТАРИФУ", 0.1, (0, -0.42, 1.78), rot=(R(90), 0, 0), font=C.FONT_IMPACT, extrude=0, m=m["ink"]))
    return P, [((2.2, -2.8, 1.6), (0, 0, 1.0)), ((0.7, -1.2, 1.3), (0, -0.4, 1.1))]


def vend_change(m=None):
    m = m or M()
    P = vend_base(m, "dsteel", "change", W=0.8, D=0.7, Hh=1.6)
    P.append(C.box("scr", (0.5, 0.02, 0.28), (-0.05, -0.36, 1.35), bevel=0, m=m["lgreen"], seg=1))
    P.append(C.text("sc", "СДАЧУ ДАЁТ. ПОТОМ.", 0.05, (-0.05, -0.37, 1.35), rot=(R(90), 0, 0), font=C.FONT_IMPACT, extrude=0, m=m["ink"]))
    P.append(C.box("bill", (0.3, 0.03, 0.06), (-0.05, -0.37, 0.95), bevel=0.004, m=m["black"]))
    P.append(C.box("coin", (0.2, 0.08, 0.1), (-0.05, -0.37, 0.5), bevel=0.01, m=m["black"]))
    P.append(C.box("sticker", (0.3, 0.004, 0.14), (0.1, -0.362, 0.75), bevel=0, m=m["yellow"], seg=1))
    P.append(C.text("st", "ДЖЕЛОС\nAPPROVED", 0.04, (0.1, -0.366, 0.75), rot=(R(90), 0, 0), font=C.FONT_IMPACT, extrude=0, m=m["ink"]))
    return P, [((2.0, -2.6, 1.5), (0, 0, 0.9)), ((0.6, -1.1, 1.2), (0, -0.35, 1.0))]


def arcade_a(m=None):
    m = m or M()
    """Игровой автомат (силуэт 1): высокий, скошенная панель, экран, рычаг"""
    P = [C.box("cabinet", (0.8, 0.7, 1.2), (0, 0.1, 0.6), bevel=0.03, m=m["blue"]),
         C.box("top", (0.8, 0.5, 0.7), (0, 0.15, 1.55), bevel=0.03, m=m["blue"]),
         C.box("marq", (0.8, 0.08, 0.3), (0, -0.14, 1.85), rot=(R(-12), 0, 0), bevel=0.01, m=m["lbox"]),
         C.box("screen", (0.6, 0.04, 0.45), (0, -0.12, 1.4), rot=(R(-8), 0, 0), bevel=0.005, m=m["lblue"]),
         C.box("deck", (0.8, 0.4, 0.06), (0, -0.2, 1.05), rot=(R(-12), 0, 0), bevel=0.01, m=m["dsteel"]),
         C.cyl("stick", 0.015, 0.14, (-0.15, -0.28, 1.15), verts=6, bevel=0, m=m["black"]),
         C.sphere("ball", 0.04, (-0.15, -0.28, 1.24), seg=8, m=m["red"]),
         C.cyl("b1", 0.03, 0.02, (0.1, -0.3, 1.1), rot=(R(78), 0, 0), verts=10, bevel=0, m=m["lred"]),
         C.cyl("b2", 0.03, 0.02, (0.22, -0.3, 1.1), rot=(R(78), 0, 0), verts=10, bevel=0, m=m["lgreen"])]
    P.append(C.text("t", "ЛАПА 67", 0.09, (0, -0.19, 1.85), rot=(R(78), 0, 0), font=C.FONT_IMPACT, extrude=0, m=m["ink"]))
    P.append(C.box("coin", (0.1, 0.03, 0.14), (0, -0.36, 0.8), bevel=0.004, m=m["black"]))
    return P, [((2.2, -2.6, 1.7), (0, 0, 1.0)), ((0.7, -1.1, 1.5), (0, -0.2, 1.2))]


def arcade_b(m=None):
    m = m or M()
    """Игровой автомат (силуэт 2): барный, низкий, с наклонным экраном и боковыми «крыльями»"""
    P = [C.box("cabinet", (0.7, 0.7, 1.0), (0, 0.1, 0.5), bevel=0.03, m=m["red"]),
         C.box("screen", (0.55, 0.05, 0.4), (0, -0.2, 1.2), rot=(R(-25), 0, 0), bevel=0.005, m=m["lgreen"]),
         C.box("hood", (0.75, 0.55, 0.12), (0, 0.05, 1.5), bevel=0.02, m=m["red"]),
         C.box("wl", (0.06, 0.6, 0.8), (-0.4, 0.05, 1.1), rot=(0, 0, R(8)), bevel=0.01, m=m["yellow"]),
         C.box("wr", (0.06, 0.6, 0.8), (0.4, 0.05, 1.1), rot=(0, 0, R(-8)), bevel=0.01, m=m["yellow"]),
         C.box("deck", (0.7, 0.3, 0.05), (0, -0.3, 0.85), bevel=0.01, m=m["dsteel"])]
    for i in range(4):
        P.append(C.cyl("btn%d" % i, 0.03, 0.02, (-0.18 + i * 0.12, -0.32, 0.9), rot=(R(80), 0, 0), verts=10, bevel=0, m=m[("lred", "lgreen", "lblue", "lbox")[i]]))
    P.append(C.box("tray", (0.3, 0.08, 0.14), (0, -0.37, 0.25), bevel=0.01, m=m["black"]))
    return P, [((2.0, -2.6, 1.6), (0, 0, 0.9)), ((0.6, -1.1, 1.3), (0, -0.2, 1.0))]


def vend_broken(m=None):
    m = m or M()
    P = vend_base(m, "green", "broken")
    P.append(C.box("hole", (0.5, 0.05, 0.6), (-0.1, -0.41, 1.2), bevel=0, m=m["black"], seg=1))
    P.append(C.box("door", (0.55, 0.03, 0.9), (0.55, -0.55, 1.2), rot=(0, 0, R(55)), bevel=0.006, m=m["green"]))
    for i, c in enumerate(("red", "yellow", "blue", "black")):
        P.append(C.cable("w%d" % i, [(-0.2 + i * 0.1, -0.4, 1.3), (-0.2 + i * 0.1, -0.7, 1.0), (-0.25 + i * 0.1, -0.8, 0.6), (-0.3 + i * 0.12, -0.9, 0.05)], r=0.012, m=m[c]))
    P.append(C.box("spark", (0.04, 0.02, 0.04), (-0.1, -0.7, 1.0), bevel=0, m=m["lbox"], seg=1))
    P.append(C.box("tilt", (0.0, 0.0, 0.0), (0, 0, 0), bevel=0, m=m["black"], seg=1)) if False else None
    return P, [((2.2, -2.8, 1.6), (0, -0.2, 1.0)), ((0.8, -1.3, 1.3), (0, -0.4, 1.1))]


BUILD = {"kiosk_shawarma": kiosk_shawarma, "kiosk_phones": kiosk_phones, "kiosk_socks": kiosk_socks, "kiosk_keys": kiosk_keys, "kiosk_odds": kiosk_odds,
         "kiosk_exchange": kiosk_exchange, "bench": bench, "bin": bin_, "arrow_sign": arrow_sign, "cross_green": cross_green,
         "turnstile": turnstile, "booth": booth, "cash_shield": cash_shield, "tariff_board": tariff_board, "receipt_printer": receipt_printer,
         "fortuna_wheel": fortuna_wheel, "queue_stand": queue_stand, "storage": storage, "vend_drinks": vend_drinks, "vend_snacks": vend_snacks,
         "vend_change": vend_change, "arcade_a": arcade_a, "arcade_b": arcade_b, "vend_broken": vend_broken}

if __name__ == "__main__":
    Z.run(BUILD, 1024)
