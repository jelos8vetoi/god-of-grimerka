"""Общие помощники для моделей двора «ГОЛДА 67» в Blender 5.x (запуск: blender.exe --background --python tools/blender/<модель>.py).
Геометрия — bmesh/модификаторы, материалы — процедурные (краска/ржавчина/грязь/потёртости кромок), запекаются в 3 текстуры
(basecolor с AO, roughness в G, normal) и экспортируются в glb. Лицо модели — к -Y Blender (= +Z в Godot), начало — на земле по центру."""
import bpy
import bmesh
import math
import os
import sys
import random
import numpy as np
from mathutils import Vector, Matrix, Euler

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "godot", "assets", "golda67")
RENDERS = os.path.join(os.path.expanduser("~"), "Desktop", "GOLDA67_PLAYTEST_DEVIN", "blender_renders")
TMP = os.path.join(os.environ.get("TEMP", "/tmp"), "g67_bake")
FONT_BOLD = "C:/Windows/Fonts/arialbd.ttf"
FONT_IMPACT = "C:/Windows/Fonts/impact.ttf"
FONT_MONO = "C:/Windows/Fonts/consola.ttf"


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    random.seed(67)
    os.makedirs(TMP, exist_ok=True)
    os.makedirs(RENDERS, exist_ok=True)


# ----------------------------------------------------------------------------- материалы
def _n(nt, typ, x, y, **kw):
    n = nt.nodes.new(typ)
    n.location = (x, y)
    for k, v in kw.items():
        setattr(n, k, v)
    return n


def mat(name, base, under=(0.28, 0.12, 0.06), rust=0.5, wear=0.45, dirt=0.6, rough=0.5, bump=0.35, scale=6.0, flat=False, grain=None, streaks=0.5):
    """Процедурный материал для запекания: base — краска, under — ржавчина/грунт под ней, wear — доля облезшей краски,
    dirt — грязь в углах и снизу, flat=True — без износа (стекло, бумага, резина)"""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = _n(nt, "ShaderNodeOutputMaterial", 1800, 0)
    pb = _n(nt, "ShaderNodeBsdfPrincipled", 1500, 0)
    nt.links.new(pb.outputs["BSDF"], out.inputs["Surface"])
    tc = _n(nt, "ShaderNodeTexCoord", -1400, 0)
    if grain is not None:      # волокно: координаты по осям сжаты — шум вытянут вдоль дерева
        mp = _n(nt, "ShaderNodeMapping", -1250, 0)
        mp.inputs["Scale"].default_value = grain
        nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
        tc = mp
    n1 = _n(nt, "ShaderNodeTexNoise", -1100, 300, noise_dimensions="3D")
    n1.inputs["Scale"].default_value = scale
    n1.inputs["Detail"].default_value = 8.0
    n1.inputs["Roughness"].default_value = 0.6
    nt.links.new(tc.outputs["Object"] if grain is None else tc.outputs["Vector"], n1.inputs["Vector"])
    n2 = _n(nt, "ShaderNodeTexNoise", -1100, 0, noise_dimensions="3D")
    n2.inputs["Scale"].default_value = scale * 2.5
    n2.inputs["Detail"].default_value = 4.0
    nt.links.new(tc.outputs["Object"] if grain is None else tc.outputs["Vector"], n2.inputs["Vector"])
    vor = _n(nt, "ShaderNodeTexVoronoi", -1100, -300, voronoi_dimensions="3D", feature="DISTANCE_TO_EDGE")
    vor.inputs["Scale"].default_value = scale * 3.0
    nt.links.new(tc.outputs["Object"] if grain is None else tc.outputs["Vector"], vor.inputs["Vector"])
    # кромка: расхождение фаски и геометрической нормали
    bev = _n(nt, "ShaderNodeBevel", -1100, -600)
    bev.inputs["Radius"].default_value = 0.012
    geo = _n(nt, "ShaderNodeNewGeometry", -1100, -800)
    dot = _n(nt, "ShaderNodeVectorMath", -850, -700, operation="DOT_PRODUCT")
    nt.links.new(bev.outputs["Normal"], dot.inputs[0])
    nt.links.new(geo.outputs["Normal"], dot.inputs[1])
    edge = _n(nt, "ShaderNodeMapRange", -650, -700)
    edge.inputs["From Min"].default_value = 0.999
    edge.inputs["From Max"].default_value = 0.93
    nt.links.new(dot.outputs["Value"], edge.inputs["Value"])
    ao = _n(nt, "ShaderNodeAmbientOcclusion", -1100, -1000)
    ao.inputs["Distance"].default_value = 0.18
    # маска облезлой краски: шум + кромки + трещины
    add = _n(nt, "ShaderNodeMath", -650, 250, operation="ADD")
    nt.links.new(n1.outputs["Fac"], add.inputs[0])
    nt.links.new(edge.outputs["Result"], add.inputs[1])
    add2 = _n(nt, "ShaderNodeMath", -450, 250, operation="ADD")
    nt.links.new(add.outputs["Value"], add2.inputs[0])
    mulv = _n(nt, "ShaderNodeMath", -650, -250, operation="MULTIPLY")
    nt.links.new(n2.outputs["Fac"], mulv.inputs[0])
    mulv.inputs[1].default_value = 0.12
    nt.links.new(mulv.outputs["Value"], add2.inputs[1])
    ramp = _n(nt, "ShaderNodeValToRGB", -250, 250)
    thr = 1.55 - wear * 0.8
    ramp.color_ramp.elements[0].position = thr
    ramp.color_ramp.elements[1].position = thr + 0.07
    nt.links.new(add2.outputs["Value"], ramp.inputs["Fac"])
    # ржавчина: вариации цвета
    rr = _n(nt, "ShaderNodeValToRGB", -650, 600)
    rr.color_ramp.elements[0].color = (*[c * 0.55 for c in under], 1)
    rr.color_ramp.elements[1].color = (*[min(1.0, c * 1.5 + 0.04) for c in under], 1)
    nt.links.new(n1.outputs["Fac"], rr.inputs["Fac"])
    paint = _n(nt, "ShaderNodeRGB", -650, 850)
    paint.outputs[0].default_value = (*base, 1)
    pv = _n(nt, "ShaderNodeMixRGB", -450, 800, blend_type="MULTIPLY")
    pv.inputs["Fac"].default_value = 0.0 if flat else 0.12
    nt.links.new(paint.outputs[0], pv.inputs["Color1"])
    nt.links.new(n2.outputs["Color"], pv.inputs["Color2"])
    chip = _n(nt, "ShaderNodeMixRGB", -50, 500)
    nt.links.new(pv.outputs["Color"], chip.inputs["Color1"])
    nt.links.new(rr.outputs["Color"], chip.inputs["Color2"])
    if flat:
        chip.inputs["Fac"].default_value = 0.0
    else:
        nt.links.new(ramp.outputs["Color"], chip.inputs["Fac"])
    # грязь: ambient occlusion + низ предмета
    zc = _n(nt, "ShaderNodeSeparateXYZ", -850, -1000)
    nt.links.new(tc.outputs["Object"] if grain is None else tc.outputs["Vector"], zc.inputs[0])
    zr = _n(nt, "ShaderNodeMapRange", -650, -1000)
    zr.inputs["From Min"].default_value = 0.0
    zr.inputs["From Max"].default_value = 0.5
    zr.inputs["To Min"].default_value = 1.0
    zr.inputs["To Max"].default_value = 0.0
    nt.links.new(zc.outputs["Z"], zr.inputs["Value"])
    inv = _n(nt, "ShaderNodeMath", -650, -1200, operation="SUBTRACT")
    inv.inputs[0].default_value = 1.0
    nt.links.new(ao.outputs["AO"], inv.inputs[1])
    dm = _n(nt, "ShaderNodeMath", -450, -1100, operation="ADD")
    nt.links.new(inv.outputs["Value"], dm.inputs[0])
    nt.links.new(zr.outputs["Result"], dm.inputs[1])
    dm.use_clamp = True
    dn = _n(nt, "ShaderNodeMath", -250, -1100, operation="MULTIPLY")
    nt.links.new(dm.outputs["Value"], dn.inputs[0])
    nt.links.new(n1.outputs["Fac"], dn.inputs[1])
    dsc = _n(nt, "ShaderNodeMath", -50, -1100, operation="MULTIPLY")
    dsc.inputs[1].default_value = dirt * 1.6
    dsc.use_clamp = True
    nt.links.new(dn.outputs["Value"], dsc.inputs[0])
    grime = _n(nt, "ShaderNodeMixRGB", 300, 400)
    nt.links.new(chip.outputs["Color"], grime.inputs["Color1"])
    grime.inputs["Color2"].default_value = (0.05, 0.04, 0.03, 1)
    nt.links.new(dsc.outputs["Value"], grime.inputs["Fac"])
    # подтёки: шум, вытянутый вниз по Z, ржавым поверх, сильнее у кромок и снизу
    mpS = _n(nt, "ShaderNodeMapping", 300, 900)
    mpS.inputs["Scale"].default_value = (scale * 2.5, scale * 2.5, scale * 0.12)
    nt.links.new((tc.outputs["Vector"] if grain is not None else tc.outputs["Object"]), mpS.inputs["Vector"])
    nS = _n(nt, "ShaderNodeTexNoise", 500, 900, noise_dimensions="3D")
    nS.inputs["Scale"].default_value = 1.0
    nS.inputs["Detail"].default_value = 3.0
    nt.links.new(mpS.outputs["Vector"], nS.inputs["Vector"])
    rS = _n(nt, "ShaderNodeValToRGB", 700, 900)
    rS.color_ramp.elements[0].position = 0.62
    rS.color_ramp.elements[1].position = 0.74
    nt.links.new(nS.outputs["Fac"], rS.inputs["Fac"])
    sm = _n(nt, "ShaderNodeMath", 900, 900, operation="MULTIPLY")
    sm.inputs[1].default_value = 0.0 if flat else streaks * 0.45
    nt.links.new(rS.outputs["Alpha"], sm.inputs[0])
    sc2 = _n(nt, "ShaderNodeMath", 1050, 900, operation="MULTIPLY")
    nt.links.new(sm.outputs["Value"], sc2.inputs[0])
    nt.links.new(zr.outputs["Result"], sc2.inputs[1])
    sx = _n(nt, "ShaderNodeMixRGB", 1250, 600)
    nt.links.new(grime.outputs["Color"], sx.inputs["Color1"])
    sx.inputs["Color2"].default_value = (*[c * 0.7 for c in under], 1)
    nt.links.new(sc2.outputs["Value"], sx.inputs["Fac"])
    nt.links.new(sx.outputs["Color"], pb.inputs["Base Color"])
    # шероховатость: краска гладче, ржавчина и грязь шершавее
    rmix = _n(nt, "ShaderNodeMath", 300, 0, operation="ADD")
    rmix.use_clamp = True
    rsc = _n(nt, "ShaderNodeMath", 50, 0, operation="MULTIPLY")
    rsc.inputs[1].default_value = 0.55
    if flat:
        rsc.inputs[0].default_value = 0.0
    else:
        nt.links.new(ramp.outputs["Alpha"], rsc.inputs[0])
    rmix.inputs[0].default_value = rough
    nt.links.new(rsc.outputs["Value"], rmix.inputs[1])
    rd = _n(nt, "ShaderNodeMath", 520, 0, operation="ADD")
    rd.use_clamp = True
    nt.links.new(rmix.outputs["Value"], rd.inputs[0])
    rds = _n(nt, "ShaderNodeMath", 300, -150, operation="MULTIPLY")
    rds.inputs[1].default_value = 0.3
    nt.links.new(dsc.outputs["Value"], rds.inputs[0])
    nt.links.new(rds.outputs["Value"], rd.inputs[1])
    nt.links.new(rd.outputs["Value"], pb.inputs["Roughness"])
    # неровности
    bp = _n(nt, "ShaderNodeBump", 1100, -300)
    bp.inputs["Strength"].default_value = bump
    bp.inputs["Distance"].default_value = 0.02
    nt.links.new(n1.outputs["Fac"], bp.inputs["Height"])
    if not flat:
        nt.links.new(bp.outputs["Normal"], pb.inputs["Normal"])
    pb.inputs["Metallic"].default_value = 0.0
    return m


def apply_mat(o, m):
    o.data.materials.clear()
    o.data.materials.append(m)


# ----------------------------------------------------------------------------- геометрия
def _finish_obj(o, bevel, smooth=True, seg=2):
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    if bevel > 0:
        md = o.modifiers.new("bv", "BEVEL")
        md.width = bevel
        md.segments = seg
        md.limit_method = "ANGLE"
        md.angle_limit = math.radians(35)
        bpy.ops.object.modifier_apply(modifier=md.name)
    if smooth:
        bpy.ops.object.shade_smooth()
        try:
            bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
        except Exception:
            pass
    o.select_set(False)
    return o


def box(name, size, loc, rot=(0, 0, 0), bevel=0.008, m=None, seg=2):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = Euler(rot)
    if m:
        o.data.materials.append(m)
    return _finish_obj(o, bevel, seg=seg)


def cyl(name, r, h, loc, rot=(0, 0, 0), verts=20, bevel=0.005, m=None, r2=None, cap=True, seg=1):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=verts, radius1=r, radius2=(r if r2 is None else r2), depth=h)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = Euler(rot)
    if m:
        o.data.materials.append(m)
    return _finish_obj(o, bevel, seg=seg)


def sphere(name, r, loc, scale=(1, 1, 1), seg=16, m=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=max(6, seg // 2), radius=r)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.location = loc
    o.scale = scale
    if m:
        o.data.materials.append(m)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.shade_smooth()
    o.select_set(False)
    return o


def torus(name, major, minor, loc, rot=(0, 0, 0), ms=24, mn=8, m=None):
    bm = bmesh.new()
    verts = []
    for i in range(ms):
        a = 2 * math.pi * i / ms
        ring = []
        for j in range(mn):
            b = 2 * math.pi * j / mn
            r = major + minor * math.cos(b)
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), minor * math.sin(b))))
        verts.append(ring)
    for i in range(ms):
        for j in range(mn):
            bm.faces.new((verts[i][j], verts[(i + 1) % ms][j], verts[(i + 1) % ms][(j + 1) % mn], verts[i][(j + 1) % mn]))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = Euler(rot)
    if m:
        o.data.materials.append(m)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.shade_smooth()
    o.select_set(False)
    return o


def cable(name, pts, r=0.008, m=None, res=4):
    """Провод по точкам (Безье со сглаживанием), провисает сам, если точки заданы с провисом"""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = r
    cu.bevel_resolution = 1
    cu.resolution_u = max(2, res - 1)
    sp = cu.splines.new("BEZIER")
    sp.bezier_points.add(len(pts) - 1)
    for p, v in zip(sp.bezier_points, pts):
        p.co = Vector(v)
        p.handle_left_type = "AUTO"
        p.handle_right_type = "AUTO"
    o = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    if m:
        o.data.materials.append(m)
    o.select_set(False)
    return o


def text(name, body, size, loc, rot=(0, 0, 0), font=FONT_IMPACT, extrude=0.003, m=None, align="CENTER", spacing=1.0):
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = body
    cu.size = size
    cu.extrude = extrude
    cu.align_x = align
    cu.align_y = "CENTER"
    cu.space_line = spacing
    cu.resolution_u = 2
    cu.bevel_resolution = 0
    cu.font = bpy.data.fonts.load(font)
    o = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = Euler(rot)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    if m:
        o.data.materials.append(m)
    o.select_set(False)
    return o


def pivot(o, point):
    """Сделать точку point (в мировых координатах) началом узла: ось вращения подвижной части"""
    p = Vector(point)
    o.data.transform(Matrix.Translation(-(p - o.location)))
    o.location = p


def join(name, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    r = bpy.context.view_layer.objects.active
    r.name = name
    r.data.name = name
    r.select_set(False)
    return r


def tris(objs):
    n = 0
    for o in objs:
        dg = bpy.context.evaluated_depsgraph_get()
        me = o.evaluated_get(dg).to_mesh()
        me.calc_loop_triangles()
        n += len(me.loop_triangles)
        o.evaluated_get(dg).to_mesh_clear()
    return n


# ----------------------------------------------------------------------------- запекание
def _img(name, size, col=(0, 0, 0, 1), cs="sRGB"):
    im = bpy.data.images.new(name, size, size, alpha=False, float_buffer=False)
    im.colorspace_settings.name = cs
    im.generated_color = col
    im.pixels = list(col) * (size * size)
    return im


def bake_atlas(objs, name, size=1024):
    """Развёртка всех объектов в один атлас, запекание basecolor+AO, roughness, normal; возвращает итоговый материал"""
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 24
    sc.cycles.use_denoising = False
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        if not o.data.uv_layers:
            o.data.uv_layers.new(name="UVMap")
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.012, scale_to_bounds=False)
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(margin=0.006, rotate=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    imgs = {
        "bc": _img(name + "_bc", size, (0.5, 0.5, 0.5, 1)),
        "ao": _img(name + "_ao", size, (1, 1, 1, 1), "Non-Color"),
        "rm": _img(name + "_rm", size, (0.5, 0.5, 0.5, 1), "Non-Color"),
        "n": _img(name + "_n", size, (0.5, 0.5, 1.0, 1), "Non-Color"),
    }
    # каждому материалу — узел картинки (активный) под запекаемый проход
    texnodes = []
    for o in objs:
        for slot in o.material_slots:
            nt = slot.material.node_tree
            if not any(n.name == "BAKE_TEX" for n in nt.nodes):
                tn = nt.nodes.new("ShaderNodeTexImage")
                tn.name = "BAKE_TEX"
                tn.location = (2000, -400)
            texnodes.append(nt.nodes["BAKE_TEX"])
    texnodes = list({id(n): n for n in texnodes}.values())

    def run(kind, bake_type, **kw):
        for tn in texnodes:
            tn.image = imgs[kind]
            tn.select = True
            tn.id_data.nodes.active = tn
        bpy.ops.object.bake(type=bake_type, margin=10, margin_type="EXTEND", use_clear=True, **kw)

    run("bc", "DIFFUSE", pass_filter={"COLOR"})
    run("ao", "AO")
    run("rm", "ROUGHNESS")
    run("n", "NORMAL")
    W = size * size * 4

    def px(im):
        a = np.empty(W, dtype=np.float32)
        im.pixels.foreach_get(a)
        return a.reshape(-1, 4)

    bc = px(imgs["bc"])
    ao = px(imgs["ao"])
    rm = px(imgs["rm"])
    bc[:, :3] *= (0.72 + 0.28 * ao[:, :1])
    orm = np.ones_like(bc)
    orm[:, 0] = ao[:, 0]
    orm[:, 1] = rm[:, 0]
    orm[:, 2] = 0.0
    final = {}
    for key, arr, cs in (("bc", bc, "sRGB"), ("orm", orm, "Non-Color")):
        im = bpy.data.images.new(name + "_" + key, size, size, alpha=False)
        im.colorspace_settings.name = cs
        im.pixels.foreach_set(arr.reshape(-1))
        im.filepath_raw = os.path.join(TMP, name + "_" + key + ".png")
        im.file_format = "PNG"
        im.save()
        final[key] = im
    imgs["n"].filepath_raw = os.path.join(TMP, name + "_n.png")
    imgs["n"].file_format = "PNG"
    imgs["n"].save()
    final["n"] = imgs["n"]
    # итоговый материал: один на всю модель
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = _n(nt, "ShaderNodeOutputMaterial", 800, 0)
    pb = _n(nt, "ShaderNodeBsdfPrincipled", 500, 0)
    nt.links.new(pb.outputs["BSDF"], out.inputs["Surface"])
    t1 = _n(nt, "ShaderNodeTexImage", 0, 300)
    t1.image = final["bc"]
    nt.links.new(t1.outputs["Color"], pb.inputs["Base Color"])
    t2 = _n(nt, "ShaderNodeTexImage", 0, 0)
    t2.image = final["orm"]
    sep = _n(nt, "ShaderNodeSeparateColor", 250, 0)
    nt.links.new(t2.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Green"], pb.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], pb.inputs["Metallic"])
    t3 = _n(nt, "ShaderNodeTexImage", 0, -300)
    t3.image = final["n"]
    nm = _n(nt, "ShaderNodeNormalMap", 250, -300)
    nt.links.new(t3.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], pb.inputs["Normal"])
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(m)
    for im in final.values():
        im.pack()
    return m


# ----------------------------------------------------------------------------- рендер и экспорт
def _lights():
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.09, 0.1, 0.14, 1)
    bg.inputs["Strength"].default_value = 1.0
    bpy.context.scene.world = w
    k = bpy.data.lights.new("key", "AREA")
    k.energy = 220
    k.size = 3.0
    ko = bpy.data.objects.new("key", k)
    bpy.context.collection.objects.link(ko)
    ko.location = (-2.5, -3.0, 3.2)
    ko.rotation_euler = Euler((math.radians(55), 0, math.radians(-38)))
    wl = bpy.data.lights.new("warm", "POINT")
    wl.energy = 260
    wl.color = (1.0, 0.68, 0.38)
    wl.shadow_soft_size = 0.2
    wo = bpy.data.objects.new("warm", wl)
    bpy.context.collection.objects.link(wo)
    wo.location = (1.6, -1.2, 1.6)


def render(name, views, ground=True, res=(1280, 720)):
    """views: [(camera_loc, target)] — по одному png на вид: <имя>_1.png, <имя>_2.png"""
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    _lights()
    if ground:
        g = box("floor", (6, 6, 0.05), (0, 0, -0.025), bevel=0)
        gm = bpy.data.materials.new("floor")
        gm.use_nodes = True
        gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.32, 0.33, 0.36, 1)
        gm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
        g.data.materials.append(gm)
    cam_d = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_d)
    bpy.context.collection.objects.link(cam)
    sc.camera = cam
    paths = []
    for i, (loc, tgt) in enumerate(views):
        cam.location = Vector(loc)
        cam.rotation_euler = (Vector(tgt) - cam.location).to_track_quat("-Z", "Y").to_euler()
        cam_d.lens = 50
        sc.render.filepath = os.path.join(RENDERS, "%s_%d.png" % (name, i + 1))
        bpy.ops.render.render(write_still=True)
        paths.append(sc.render.filepath)
    if ground:
        bpy.data.objects.remove(g)
    return paths


def export(name, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                              export_image_format="AUTO", export_materials="EXPORT", export_texcoords=True, export_normals=True)
    return path


def finish(name, objs, views, size=1024, do_export=True):
    """Запечь, посчитать треугольники, отрендерить (до экспорта: рендер идёт с запечённым материалом) и экспортировать"""
    if os.environ.get("G67_FAST"):
        per = sorted(((tris([o]), o.name) for o in objs), reverse=True)
        print("G67MODEL быстрый просмотр", name, "всего", sum(p[0] for p in per), per[:10])
        return 0
    bake_atlas(objs, name, size)
    n = tris(objs)
    paths = render(name, views)
    p = export(name, objs) if do_export else ""
    print("G67MODEL %s: треугольников %d, glb %s, рендеры %s" % (name, n, p, paths))
    return n
