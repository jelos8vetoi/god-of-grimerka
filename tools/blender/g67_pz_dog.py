"""Собака DOG CASINO 67: мультяшный ротвейлер-здоровяк, сидит. Цельная форма из метаболов (головa, тело, челюсть, лапа — отдельные «семейства»), подпалины рисуются масками
в мировых координатах, пасть распахнута, язык вывален. Узлы: head, jaw, tongue, tail, ear_l, ear_r, paw_fr. Рост сидя ≈ 0,75 м, лицо — в −Y (в Godot +Z)."""
import sys
import os
import math
sys.path.insert(0, os.path.dirname(__file__))
import g67_pz_common as Z
import g67_common as C
import bpy
from mathutils import Vector

R = math.radians
TAU = math.tau
QUICK = bool(os.environ.get("G67_QUICK"))
TARGET_TRIS = {"body": 3800, "head": 5200, "jaw": 900, "pawfr": 700}


def meta(name, elems, res=0.022, thr=0.6):
    mb = bpy.data.metaballs.new(name)
    mb.resolution = res
    mb.render_resolution = res
    mb.threshold = thr
    for (x, y, z, a, b, c) in elems:
        e = mb.elements.new(type="ELLIPSOID")
        e.co = (x, y, z)
        big = max(a, b, c)
        e.radius = big / 0.672
        e.size_x, e.size_y, e.size_z = a / big, b / big, c / big
        e.stiffness = 2.0
    o = bpy.data.objects.new(name, mb)
    bpy.context.collection.objects.link(o)
    return o


def to_mesh(o, mat, ratio=None, target=None):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.view_layer.objects.active
    n = len(o.data.polygons)
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    if target and tris > target:
        d = o.modifiers.new("dec", "DECIMATE")
        d.ratio = target / float(tris)
        bpy.ops.object.modifier_apply(modifier="dec")
    for p in o.data.polygons:
        p.use_smooth = True
    o.data.materials.append(mat)
    o.select_set(False)
    return o


def fur_mat():
    """чёрно-шоколадная шерсть с рыжими подпалинами (маски в мировых координатах): морда, брови, грудь, низ лап"""
    m = bpy.data.materials.new("fur")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = C._n(nt, "ShaderNodeOutputMaterial", 2600, 0)
    pb = C._n(nt, "ShaderNodeBsdfPrincipled", 2300, 0)
    nt.links.new(pb.outputs["BSDF"], out.inputs["Surface"])
    geo = C._n(nt, "ShaderNodeNewGeometry", 0, 0)
    pts = [((0.0, -0.4, 0.46), 0.11), ((0.0, -0.42, 0.5), 0.08), ((-0.1, -0.34, 0.44), 0.07), ((0.1, -0.34, 0.44), 0.07),
           ((-0.11, -0.3, 0.7), 0.04), ((0.11, -0.3, 0.7), 0.04), ((0.0, -0.18, 0.28), 0.13), ((0.0, -0.22, 0.38), 0.09),
           ((-0.13, -0.2, 0.05), 0.1), ((0.13, -0.2, 0.05), 0.1), ((-0.21, -0.02, 0.04), 0.09), ((0.21, -0.02, 0.04), 0.09),
           ((-0.16, -0.3, 0.42), 0.05), ((0.16, -0.3, 0.42), 0.05)]
    acc = None
    x = 300
    for i, (p, r) in enumerate(pts):
        vm = C._n(nt, "ShaderNodeVectorMath", x, 300 - 140 * (i % 6), operation="DISTANCE")
        vm.inputs[1].default_value = p
        nt.links.new(geo.outputs["Position"], vm.inputs[0])
        mr = C._n(nt, "ShaderNodeMapRange", x + 220, 300 - 140 * (i % 6))
        mr.inputs["From Min"].default_value = r * 0.55
        mr.inputs["From Max"].default_value = r * 1.15
        mr.inputs["To Min"].default_value = 1.0
        mr.inputs["To Max"].default_value = 0.0
        mr.clamp = True
        nt.links.new(vm.outputs["Value"], mr.inputs["Value"])
        if acc is None:
            acc = mr.outputs["Result"]
        else:
            mx = C._n(nt, "ShaderNodeMath", x + 440, 300 - 140 * (i % 6), operation="MAXIMUM")
            nt.links.new(acc, mx.inputs[0])
            nt.links.new(mr.outputs["Result"], mx.inputs[1])
            acc = mx.outputs["Value"]
        x += 120
    nz = C._n(nt, "ShaderNodeTexNoise", 1500, -300, noise_dimensions="3D")
    nz.inputs["Scale"].default_value = 28.0
    nz.inputs["Detail"].default_value = 6.0
    nt.links.new(geo.outputs["Position"], nz.inputs["Vector"])
    rr = C._n(nt, "ShaderNodeValToRGB", 1750, -300)
    rr.color_ramp.elements[0].color = (0.035, 0.02, 0.016, 1)
    rr.color_ramp.elements[1].color = (0.11, 0.065, 0.045, 1)
    nt.links.new(nz.outputs["Fac"], rr.inputs["Fac"])
    # шерсть светлеет к макушке (градиент по высоте)
    og = C._n(nt, "ShaderNodeRGB", 1750, -550)
    og.outputs[0].default_value = (0.78, 0.33, 0.07, 1)
    mix = C._n(nt, "ShaderNodeMixRGB", 2050, 0)
    nt.links.new(acc, mix.inputs["Fac"])
    nt.links.new(rr.outputs["Color"], mix.inputs["Color1"])
    nt.links.new(og.outputs[0], mix.inputs["Color2"])
    nt.links.new(mix.outputs["Color"], pb.inputs["Base Color"])
    pb.inputs["Roughness"].default_value = 0.62
    bp = C._n(nt, "ShaderNodeBump", 2050, -400)
    bp.inputs["Strength"].default_value = 0.5
    bp.inputs["Distance"].default_value = 0.01
    nt.links.new(nz.outputs["Fac"], bp.inputs["Height"])
    nt.links.new(bp.outputs["Normal"], pb.inputs["Normal"])
    return m


def gloss(name, col, rough=0.12):
    return C.mat(name, col, flat=True, dirt=0.0, rough=rough)


def build():
    m = {
        "fur": fur_mat(),
        "nose": gloss("nose", (0.04, 0.035, 0.04), 0.12),
        "inner": gloss("inner", (0.35, 0.03, 0.04), 0.3),
        "tooth": gloss("tooth", (0.92, 0.9, 0.82), 0.2),
        "tongue": gloss("tongue", (0.95, 0.4, 0.5), 0.14),
        "white": gloss("white", (0.95, 0.95, 0.92), 0.08),
        "iris": gloss("iris", (0.28, 0.13, 0.05), 0.1),
        "black": gloss("black", (0.02, 0.02, 0.02), 0.1),
        "collar": C.mat("collar", (0.65, 0.07, 0.06), under=(0.3, 0.05, 0.04), wear=0.35, dirt=0.6, rough=0.55, scale=30),
        "steel": Z.steel("steel", base=(0.75, 0.77, 0.8), wear=0.3),
        "gold": C.mat("gold", (0.95, 0.72, 0.18), under=(0.5, 0.35, 0.08), wear=0.2, dirt=0.4, rough=0.22, scale=40),
        "ink": gloss("ink", (0.05, 0.04, 0.03), 0.7),
    }
    P = []
    # --- тело: грудь, круп, шея, бёдра, передние лапы (кроме правой), задние лапы
    body = meta("body", [
        (0, -0.02, 0.30, 0.27, 0.25, 0.28), (0, 0.17, 0.20, 0.28, 0.27, 0.2), (0, -0.12, 0.47, 0.21, 0.19, 0.15),
        (-0.22, 0.12, 0.14, 0.13, 0.17, 0.13), (0.22, 0.12, 0.14, 0.13, 0.17, 0.13),
        (-0.2, -0.04, 0.035, 0.09, 0.14, 0.04), (0.2, -0.04, 0.035, 0.09, 0.14, 0.04),
        (-0.13, -0.15, 0.15, 0.09, 0.09, 0.16), (-0.13, -0.2, 0.035, 0.1, 0.13, 0.045),
        (-0.15, -0.28, 0.035, 0.026, 0.026, 0.026), (-0.1, -0.29, 0.035, 0.026, 0.026, 0.026),
        (0, -0.2, 0.52, 0.17, 0.08, 0.04), (0, -0.19, 0.46, 0.17, 0.08, 0.03)])     # складки шеи
    pawfr = meta("pawfr", [(0.13, -0.15, 0.15, 0.09, 0.09, 0.16), (0.13, -0.2, 0.035, 0.1, 0.13, 0.045), (0.1, -0.28, 0.035, 0.026, 0.026, 0.026), (0.15, -0.29, 0.035, 0.026, 0.026, 0.026)])
    head = meta("head", [
        (0, -0.12, 0.58, 0.22, 0.19, 0.19),                                                       # череп
        (-0.07, -0.31, 0.5, 0.1, 0.14, 0.1), (0.07, -0.31, 0.5, 0.1, 0.14, 0.1),                   # квадратная морда
        (-0.15, -0.25, 0.44, 0.08, 0.09, 0.08), (0.15, -0.25, 0.44, 0.08, 0.09, 0.08),               # брыли, щёки
        (-0.1, -0.27, 0.66, 0.075, 0.06, 0.04), (0.1, -0.27, 0.66, 0.075, 0.06, 0.04),             # надбровья
        (0, -0.25, 0.68, 0.13, 0.035, 0.025), (0, -0.22, 0.71, 0.12, 0.035, 0.022), (0, -0.19, 0.74, 0.1, 0.035, 0.02),   # складки лба
        (0, -0.43, 0.54, 0.06, 0.05, 0.05),                                                         # нос
        (-0.1, -0.4, 0.43, 0.04, 0.035, 0.03), (0.1, -0.4, 0.43, 0.04, 0.035, 0.03)])             # уголки улыбки
    jaw = meta("jaw", [(0, -0.3, 0.3, 0.16, 0.13, 0.045), (-0.1, -0.34, 0.31, 0.05, 0.05, 0.04), (0.1, -0.34, 0.31, 0.05, 0.05, 0.04), (0, -0.2, 0.29, 0.14, 0.08, 0.04)])
    objs = {"body": to_mesh(body, m["fur"], target=TARGET_TRIS["body"]), "pawfr": to_mesh(pawfr, m["fur"], target=TARGET_TRIS["pawfr"]),
            "head": to_mesh(head, m["fur"], target=TARGET_TRIS["head"]), "jaw": to_mesh(jaw, m["fur"], target=TARGET_TRIS["jaw"])}
    bp = [objs["body"]]
    hp = [objs["head"]]
    jp = [objs["jaw"]]
    # --- рот: нутро, зубы, язык
    hp.append(C.sphere("mouth", 0.08, (0, -0.3, 0.405), scale=(1.8, 0.9, 0.55), seg=14, m=m["inner"]))
    for k in range(13):
        x = -0.15 + k * 0.025
        up = C.cyl("tu%d" % k, 0.011, 0.034, (x, -0.405 + 0.09 * (x / 0.15) ** 2, 0.445), verts=6, bevel=0, m=m["tooth"], r2=0.001)
        up.rotation_euler = (R(180), 0, 0)
        hp.append(up)
        lo = C.cyl("tl%d" % k, 0.01, 0.028, (x, -0.385 + 0.09 * (x / 0.15) ** 2, 0.335), verts=6, bevel=0, m=m["tooth"], r2=0.001)
        jp.append(lo)
    # --- глаза навыкате, косят в стороны
    for s, gaze in ((-1, 0.012), (1, -0.012)):
        hp.append(C.sphere("eyew", 0.048, (s * 0.088, -0.285, 0.655), seg=14, m=m["white"]))
        hp.append(C.sphere("iris", 0.022, (s * 0.088 + gaze * 1.3, -0.329, 0.664), scale=(1, 0.5, 1), seg=10, m=m["iris"]))
        hp.append(C.sphere("pupil", 0.011, (s * 0.088 + gaze * 1.3, -0.338, 0.664), scale=(1, 0.4, 1), seg=8, m=m["black"]))
        hp.append(C.sphere("glint", 0.006, (s * 0.088 + gaze * 1.3 - 0.007, -0.341, 0.673), seg=5, m=m["white"]))
    # --- нос с бликом
    hp.append(C.sphere("noseb", 0.058, (0, -0.465, 0.545), scale=(1.15, 0.75, 0.82), seg=14, m=m["nose"]))
    hp.append(C.sphere("noseh", 0.011, (-0.02, -0.492, 0.575), scale=(1.6, 0.4, 0.8), seg=6, m=m["white"]))
    for s in (-1, 1):
        hp.append(C.sphere("nostril", 0.012, (s * 0.027, -0.512, 0.53), scale=(0.7, 0.4, 1.2), seg=6, m=m["black"]))
    # --- ошейник с шипами и медальоном
    bp.append(C.torus("collar", 0.205, 0.03, (0, -0.1, 0.405), rot=(R(14), 0, 0), ms=28, mn=8, m=m["collar"]))
    for k in range(15):
        a = R(-100) + k * R(200) / 14.0
        px = math.sin(a) * 0.205
        py = -0.1 - math.cos(a) * 0.205
        sp = C.cyl("spike%d" % k, 0.017, 0.05, (px, py - 0.0, 0.405 + (py + 0.1) * -0.24), verts=8, bevel=0, m=m["steel"], r2=0.002)
        sp.rotation_euler = (R(90) + R(14) * 0.0, 0, -a + R(180) * 0 )
        sp.rotation_euler = (R(90), 0, math.atan2(px, -(py + 0.1)) * -1)
        bp.append(sp)
    bp.append(C.cyl("tag", 0.045, 0.012, (0, -0.31, 0.33), rot=(R(90), 0, 0), verts=18, bevel=0.003, m=m["gold"]))
    bp.append(C.text("t67", "67", 0.05, (0, -0.318, 0.33), rot=(R(90), 0, 0), font=C.FONT_IMPACT, extrude=0.004, m=m["ink"]))
    # --- хвост-обрубок
    tail = C.cable("tail", [(0, 0.27, 0.17), (0, 0.35, 0.19), (0, 0.4, 0.26)], r=0.05, m=m["fur"], res=3)
    # --- уши: небольшие треугольные, висят, кончики вперёд
    ears = []
    for s, nm in ((-1, "ear_l"), (1, "ear_r")):
        e = C.sphere(nm, 0.1, (s * 0.135, -0.1, 0.69), scale=(0.3, 0.8, 0.9), seg=12, m=m["fur"])
        e.rotation_euler = (R(-25), R(s * 38), 0)
        ears.append(e)
    # --- язык: корень во рту и длинный язык, свисающий набок
    tg = [C.sphere("tong_b", 0.05, (0.0, -0.34, 0.36), scale=(1.5, 1.4, 0.35), seg=10, m=m["tongue"]),
          C.cable("tong_c", [(0.02, -0.38, 0.36), (0.09, -0.47, 0.34), (0.14, -0.49, 0.26), (0.15, -0.47, 0.16)], r=0.027, m=m["tongue"], res=5),
          C.sphere("tong_t", 0.04, (0.15, -0.47, 0.14), scale=(1.0, 0.4, 1.3), seg=10, m=m["tongue"]),
          C.box("tong_l", (0.006, 0.008, 0.18), (0.145, -0.49, 0.24), rot=(0, R(-8), 0), bevel=0, m=m["black"], seg=1)]
    tongue = C.join("tongue", tg)
    P += [C.join("body", bp), C.join("head", hp), C.join("jaw", jp), tongue, tail] + ears + [objs["pawfr"]]
    objs["pawfr"].name = "paw_fr"
    P[-1] = objs["pawfr"]
    return P


views = [((0, -2.1, 0.75), (0, 0, 0.45)), ((1.5, -1.5, 0.95), (0, -0.1, 0.45)), ((0.55, -0.95, 0.7), (0, -0.28, 0.5))]
C.reset()
P = build()
if QUICK:
    C.render("g67_pz_dog_quick", views)
else:
    n = C.finish("g67_pz_dog", P, views, size=2048)
    C.render("g67_pz_dog_close", [views[2]]) if not os.environ.get("G67_FAST") else None
