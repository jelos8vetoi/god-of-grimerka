"""Ларёк шаурмы «ШАУРМА 812» — «герой кадра»: вертел с мясом из неровных пластов (геометрия + displace по шуму), корочка с подпалинами и жирным блеском,
срезанный бок, нагреватель с красными спиралями, слайсер, лаваш, контейнеры с нарезкой, соусы, завёрнутые шаурмы (одна надкушена), жирные пятна на стекле."""
import sys
import os
import math
import random
sys.path.insert(0, os.path.dirname(__file__))
import g67_pz_common as Z
import g67_pz_props as PR
import g67_common as C
import bpy

R = math.radians
TAU = math.tau


def _node_mat(name, stops, noise_scale=9.0, rough=(0.25, 0.7), burn=0.5, bump=0.5):
    """мясная/овощная процедурка: шум → рампа цветов; пятна подпалин; шероховатость пятнами (жир); рельеф"""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = C._n(nt, "ShaderNodeOutputMaterial", 1600, 0)
    pb = C._n(nt, "ShaderNodeBsdfPrincipled", 1300, 0)
    nt.links.new(pb.outputs["BSDF"], out.inputs["Surface"])
    tc = C._n(nt, "ShaderNodeTexCoord", 0, 0)
    n1 = C._n(nt, "ShaderNodeTexNoise", 250, 200, noise_dimensions="3D")
    n1.inputs["Scale"].default_value = noise_scale
    n1.inputs["Detail"].default_value = 8.0
    nt.links.new(tc.outputs["Object"], n1.inputs["Vector"])
    ramp = C._n(nt, "ShaderNodeValToRGB", 550, 200)
    for i, (pos, col) in enumerate(stops):
        if i >= len(ramp.color_ramp.elements):
            ramp.color_ramp.elements.new(pos)
        ramp.color_ramp.elements[i].position = pos
        ramp.color_ramp.elements[i].color = (*col, 1)
    nt.links.new(n1.outputs["Fac"], ramp.inputs["Fac"])
    n2 = C._n(nt, "ShaderNodeTexNoise", 250, -100, noise_dimensions="3D")
    n2.inputs["Scale"].default_value = noise_scale * 0.45
    n2.inputs["Detail"].default_value = 4.0
    nt.links.new(tc.outputs["Object"], n2.inputs["Vector"])
    br = C._n(nt, "ShaderNodeValToRGB", 550, -100)
    br.color_ramp.elements[0].position = 0.55
    br.color_ramp.elements[1].position = 0.7
    nt.links.new(n2.outputs["Fac"], br.inputs["Fac"])
    bm = C._n(nt, "ShaderNodeMath", 800, -100, operation="MULTIPLY")
    bm.inputs[1].default_value = burn
    nt.links.new(br.outputs["Alpha"], bm.inputs[0])
    mix = C._n(nt, "ShaderNodeMixRGB", 1000, 150)
    nt.links.new(bm.outputs["Value"], mix.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], mix.inputs["Color1"])
    mix.inputs["Color2"].default_value = (0.035, 0.015, 0.008, 1)
    nt.links.new(mix.outputs["Color"], pb.inputs["Base Color"])
    rm = C._n(nt, "ShaderNodeMapRange", 1000, -250)
    rm.inputs["To Min"].default_value = rough[0]
    rm.inputs["To Max"].default_value = rough[1]
    nt.links.new(n2.outputs["Fac"], rm.inputs["Value"])
    nt.links.new(rm.outputs["Result"], pb.inputs["Roughness"])
    bp = C._n(nt, "ShaderNodeBump", 1000, -450)
    bp.inputs["Strength"].default_value = bump
    nt.links.new(n1.outputs["Fac"], bp.inputs["Height"])
    nt.links.new(bp.outputs["Normal"], pb.inputs["Normal"])
    return m


def displace(o, strength, size, seed=1):
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    sub = o.modifiers.new("sub", "SUBSURF")
    sub.levels = 1
    sub.render_levels = 1
    bpy.ops.object.modifier_apply(modifier="sub")
    tex = bpy.data.textures.new("n%d" % seed, "CLOUDS")
    tex.noise_scale = size
    tex.noise_depth = 3
    d = o.modifiers.new("d", "DISPLACE")
    d.texture = tex
    d.strength = strength
    d.mid_level = 0.5
    bpy.ops.object.modifier_apply(modifier="d")
    o.select_set(False)


def meat_cone(m, cx, cy, z0, rng):
    """слоёная стопка: 28 пластов, ширина растёт к верху; у каждого свой радиус, наклон, рваный край (displace)"""
    P = []
    n = 19
    for i in range(n):
        t = i / (n - 1.0)
        r = 0.085 + 0.12 * (t ** 0.8) + rng.uniform(-0.03, 0.03)
        if i > n - 4 and False:
            r *= 0.88 - 0.1 * (i - (n - 4))     # скруглённая «шапка»
        h = 0.075
        z = z0 + i * 0.043
        o = C.cyl("layer%d" % i, r, h, (cx + rng.uniform(-0.008, 0.008), cy + rng.uniform(-0.008, 0.008), z), rot=(R(rng.uniform(-7, 7)), R(rng.uniform(-7, 7)), R(rng.uniform(0, 360))), verts=16, bevel=0.004, m=m["meat"], seg=1)
        displace(o, 0.034, 0.045, i + 1)
        P.append(o)
        if i % 5 == 2:     # жирные прослойки светлее
            f = C.cyl("fat%d" % i, r * 0.97, 0.008, (cx, cy, z + 0.017), verts=14, bevel=0, m=m["fat"], seg=1)
            displace(f, 0.008, 0.05, 40 + i)
            P.append(f)
    # срезанный бок: светлое мясо с волокнами, как будто срезали ножом сверху вниз
    cut = C.box("cutface", (0.16, 0.05, 0.62), (cx - 0.02, cy - 0.12, z0 + 0.4), rot=(0, 0, R(-8)), bevel=0.01, m=m["meat_cut"], seg=1)
    displace(cut, 0.012, 0.05, 99)
    P.append(cut)
    for k in range(7):    # волокна среза
        P.append(C.box("fib%d" % k, (0.012, 0.006, 0.5), (cx - 0.08 + k * 0.025, cy - 0.15, z0 + 0.4), bevel=0.001, m=m["meat_dark"], seg=1))
    P.append(C.cyl("rod", 0.014, 1.15, (cx, cy, z0 + 0.4), verts=8, bevel=0, m=m["steel"]))
    P.append(C.cyl("mplate", 0.1, 0.012, (cx, cy, z0 - 0.02), verts=16, bevel=0.002, m=m["steel"]))
    P.append(C.cyl("tray", 0.24, 0.03, (cx, cy, z0 - 0.06), verts=20, bevel=0.004, m=m["steel"], r2=0.2))
    for k in range(3):   # капли жира в поддон
        P.append(C.sphere("drip%d" % k, 0.012, (cx + rng.uniform(-0.1, 0.1), cy + rng.uniform(-0.1, 0.1), z0 - 0.04), scale=(1, 1, 0.5), seg=6, m=m["fat"]))
    return P


def heater(m, x, y, z):
    P = [C.box("hback", (0.6, 0.06, 0.9), (x, y + 0.2, z), bevel=0.01, m=m["dsteel"])]
    for i in range(4):
        P.append(C.cable("coil%d" % i, [(x - 0.22, y + 0.15, z - 0.3 + i * 0.2), (x - 0.1, y + 0.15, z - 0.26 + i * 0.2), (x + 0.1, y + 0.15, z - 0.34 + i * 0.2), (x + 0.22, y + 0.15, z - 0.3 + i * 0.2)], r=0.012, m=m["lred"], res=3))
    P.append(C.box("hvisor", (0.64, 0.12, 0.05), (x, y + 0.12, z + 0.5), bevel=0.01, m=m["dsteel"]))
    P.append(C.box("hbase", (0.64, 0.14, 0.05), (x, y + 0.12, z - 0.5), bevel=0.01, m=m["dsteel"]))
    return P


def slicer(m, x, y, z):
    P = [C.box("blade", (0.04, 0.012, 0.42), (x, y, z), rot=(0, R(8), R(25)), bevel=0.003, m=m["steel"], seg=1),
         C.box("grip", (0.035, 0.03, 0.14), (x + 0.1, y, z - 0.28), rot=(0, R(8), R(25)), bevel=0.008, m=m["black"])]
    return P


def lavash(m, x, y, z, rng):
    P = []
    for i in range(11):
        o = C.box("lav%d" % i, (0.42, 0.3, 0.004), (x + rng.uniform(-0.01, 0.01), y + rng.uniform(-0.01, 0.01), z + i * 0.004), rot=(0, 0, R(rng.uniform(-6, 6))), bevel=0.001, m=m["lavash"], seg=1)
        displace(o, 0.004, 0.08, 120 + i)
        P.append(o)
    P.append(C.cyl("lavroll", 0.02, 0.3, (x + 0.1, y, z + 0.06), rot=(R(90), 0, 0), verts=10, bevel=0, m=m["lavash"]))
    return P


def veg_tray(m, x, y, z, kind, rng):
    P = [C.box("gn", (0.34, 0.24, 0.06), (x, y, z + 0.03), bevel=0.006, m=m["steel"])]
    P.append(C.box("gn_in", (0.31, 0.21, 0.05), (x, y, z + 0.04), bevel=0, m=m["dsteel"], seg=1))
    if kind == "tomato":
        for i in range(9):
            P.append(C.sphere("tom%d" % i, 0.036, (x - 0.1 + (i % 3) * 0.1, y - 0.06 + (i // 3) * 0.06, z + 0.075), scale=(1, 1, 0.55), seg=8, m=m["tomato"]))
    elif kind == "cucumber":
        for i in range(14):
            o = C.cyl("cuc%d" % i, 0.03, 0.007, (x - 0.12 + (i % 7) * 0.04, y - 0.04 + (i // 7) * 0.08, z + 0.07 + 0.006 * (i % 3)), rot=(R(rng.uniform(-18, 18)), R(rng.uniform(-18, 18)), 0), verts=12, bevel=0.001, m=m["cucumber"])
            P.append(o)
    elif kind == "cabbage":
        for i in range(14):
            P.append(C.box("cab%d" % i, (0.06, 0.012, 0.01), (x + rng.uniform(-0.12, 0.12), y + rng.uniform(-0.08, 0.08), z + 0.07 + rng.uniform(0, 0.03)), rot=(0, R(rng.uniform(-30, 30)), R(rng.uniform(0, 180))), bevel=0.002, m=m["cabbage"], seg=1))
    elif kind == "onion":
        for i in range(10):
            P.append(C.torus("on%d" % i, 0.03, 0.006, (x - 0.1 + (i % 5) * 0.05, y - 0.04 + (i // 5) * 0.08, z + 0.075 + 0.005 * (i % 2)), rot=(R(rng.uniform(-20, 20)), 0, 0), ms=12, mn=4, m=m["onion"]))
    else:
        for i in range(9):
            P.append(C.cyl("car%d" % i, 0.008, 0.2, (x + rng.uniform(-0.1, 0.1), y - 0.08 + (i // 3) * 0.08, z + 0.075 + 0.01 * (i % 3)), rot=(R(90), 0, R(rng.uniform(-60, 60))), verts=6, bevel=0, m=m["carrot"]))
    return P


def sauce(m, x, y, z, mat):
    P = [C.cyl("sb", 0.035, 0.22, (x, y, z + 0.11), verts=12, bevel=0.006, m=m[mat], r2=0.03),
         C.cyl("sbn", 0.016, 0.06, (x, y, z + 0.25), verts=10, bevel=0.003, m=m[mat], r2=0.006),
         C.cyl("sbl", 0.0365, 0.08, (x, y, z + 0.1), verts=12, bevel=0, m=m["paper"])]
    for k in range(3):
        P.append(C.box("sdr%d" % k, (0.006, 0.006, 0.05 + 0.02 * k), (x + 0.03 * math.sin(k * 2), y - 0.03 * math.cos(k * 2), z + 0.2 - 0.02 * k), bevel=0.001, m=m[mat], seg=1))
    return P


def wrap(m, x, y, z, bitten=False, rng=None):
    P = [C.cyl("wr", 0.04, 0.2, (x, y, z + 0.04), rot=(R(90), R(0), R(rng.uniform(-20, 20))), verts=12, bevel=0.005, m=m["paper"], r2=0.03)]
    P.append(C.cyl("wr_t", 0.045, 0.1, (x, y, z + 0.042), rot=(R(90), 0, 0), verts=12, bevel=0.003, m=m["lavash"]))
    if bitten:
        P.append(C.cyl("fill", 0.036, 0.02, (x + 0.1, y, z + 0.04), rot=(0, R(90), 0), verts=12, bevel=0, m=m["cabbage"]))
        P.append(C.sphere("fm", 0.018, (x + 0.1, y - 0.008, z + 0.048), scale=(0.4, 1, 1), seg=6, m=m["meat"]))
        P.append(C.sphere("ft", 0.016, (x + 0.1, y + 0.012, z + 0.036), scale=(0.4, 1, 0.8), seg=6, m=m["tomato"]))
    return P


def grease(m, glass_x, y, z, rng):
    P = []
    for i in range(14):
        P.append(C.cyl("gp%d" % i, rng.uniform(0.012, 0.04), 0.002, (glass_x + rng.uniform(-0.8, 0.8), y, z + rng.uniform(-0.3, 0.3)), rot=(R(90), 0, 0), verts=10, bevel=0, m=m["grease"]))
    return P


def kiosk_shawarma():
    m = PR.M()
    rng = random.Random(7)
    m["meat"] = _node_mat("meat", [(0.0, (0.1, 0.04, 0.02)), (0.35, (0.3, 0.14, 0.065)), (0.7, (0.46, 0.25, 0.12)), (1.0, (0.58, 0.36, 0.2))], 16.0, (0.5, 0.92), 1.0, 1.4)
    m["fat"] = _node_mat("fat", [(0.0, (0.75, 0.55, 0.32)), (1.0, (0.92, 0.78, 0.55))], 20.0, (0.1, 0.35), 0.1, 0.3)
    m["meat_cut"] = _node_mat("meat_cut", [(0.0, (0.62, 0.36, 0.2)), (0.5, (0.78, 0.55, 0.38)), (1.0, (0.88, 0.7, 0.55))], 28.0, (0.35, 0.7), 0.05, 0.6)
    m["meat_dark"] = C.mat("meat_dark", (0.3, 0.14, 0.06), flat=True, dirt=0.3, rough=0.6)
    m["lavash"] = _node_mat("lavash", [(0.0, (0.72, 0.55, 0.32)), (0.5, (0.9, 0.78, 0.55)), (1.0, (0.96, 0.88, 0.7))], 14.0, (0.8, 0.95), 0.4, 0.5)
    m["tomato"] = C.mat("tomato", (0.78, 0.1, 0.06), flat=True, dirt=0.2, rough=0.35)
    m["cucumber"] = C.mat("cucumber", (0.35, 0.6, 0.2), flat=True, dirt=0.2, rough=0.4)
    m["cabbage"] = C.mat("cabbage", (0.82, 0.9, 0.62), flat=True, dirt=0.2, rough=0.6)
    m["onion"] = C.mat("onion", (0.88, 0.75, 0.85), flat=True, dirt=0.2, rough=0.5)
    m["carrot"] = C.mat("carrot", (0.95, 0.45, 0.08), flat=True, dirt=0.2, rough=0.5)
    m["grease"] = C.mat("grease", (0.75, 0.72, 0.6), flat=True, dirt=0.0, rough=0.2)
    P = []
    PR.kiosk_frame(m, P)
    PR.sign(P, m, "ШАУРМА 812", 2.4, 0.45, (0, -1.6, 2.5), bg="red", fg="ink", glow=True)
    # вертел на прилавке справа, нагреватель за ним
    if os.environ.get("G67_OWN_MEAT"):
        P += meat_cone(m, 0.55, -0.7, 1.12, rng)
        P += heater(m, 0.55, -0.7, 1.55)
    P += slicer(m, 0.05, -0.55, 1.4)
    # лаваш, нарезка, соусы, готовые шаурмы
    P += lavash(m, -0.95, -0.75, 1.045, rng)
    for i, k in enumerate(("tomato", "cucumber", "cabbage", "onion", "carrot")):
        P += veg_tray(m, -0.45 + (i % 3) * 0.37 - 0.0, 0.25 + (i // 3) * 0.28, 1.04, k, rng)
    P += sauce(m, -0.2, -0.95, 1.04, "red")
    P += sauce(m, -0.05, -0.95, 1.04, "white")
    P += wrap(m, -0.55, -1.0, 1.045, False, rng) + wrap(m, -0.75, -1.0, 1.045, True, rng) + wrap(m, 0.2, -1.0, 1.045, False, rng)
    # ценник, меню
    P.append(C.box("menu", (0.7, 0.03, 0.5), (-0.95, 0.8, 1.9), bevel=0, m=m["paper"], seg=1))
    P.append(C.text("tm", "С ЧЕРЕМШОЙ\nНЕ ПРЕДЛАГАТЬ", 0.06, (-0.95, 0.78, 1.9), rot=(R(90), 0, R(180)), font=C.FONT_IMPACT, extrude=0, m=m["ink"]))
    for i in range(3):
        P.append(C.box("price%d" % i, (0.2, 0.01, 0.1), (-0.3 + i * 0.25, -1.05, 1.18), bevel=0, m=m["yellow"], seg=1))
        P.append(C.text("pt%d" % i, ("67", "6,7", "812")[i], 0.07, (-0.3 + i * 0.25, -1.058, 1.18), rot=(R(90), 0, 0), font=C.FONT_IMPACT, extrude=0, m=m["ink"]))
    P.append(C.box("napk", (0.12, 0.1, 0.1), (0.85, -0.95, 1.09), bevel=0.006, m=m["paper"]))
    return P, PR.views()


if __name__ == "__main__":
    C.reset()
    P, views = kiosk_shawarma()
    n = C.finish("g67_pz_kiosk_shawarma", P, views, size=2048)
    if not os.environ.get("G67_FAST"):
        C.render("g67_pz_shawarma_meat", [((0.55 + 0.9, -0.7 - 1.0, 1.9), (0.55, -0.7, 1.7)), ((0.55 + 0.35, -0.7 - 0.55, 1.7), (0.55, -0.7, 1.65))])
