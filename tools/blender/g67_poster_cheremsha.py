"""g67_poster_cheremsha — плакат «ЧЕРЕМША ПОМНИТ» 0,6×0,85 м: советский плакатный стиль, красно-кремовая гамма, зелёное существо из листьев
черемши протягивает пучок. Композиция собирается из плоских форм и рендерится в 1024×1448 текстуру (godot/assets/golda67/g67_poster_cheremsha.png)."""
import sys
import os
import math
sys.path.insert(0, os.path.dirname(__file__))
import bpy
import bmesh
import g67_common as C
from mathutils import Vector, Euler

R = math.radians
C.reset()
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"
sc.render.resolution_x, sc.render.resolution_y = 1024, 1448
sc.render.film_transparent = False
sc.view_settings.view_transform = "Standard"
W, H = 0.6, 0.85


def flat(name, col, rough=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*col, 1)
    em.inputs["Strength"].default_value = 1.0
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    return m


def _quad_mesh(name, verts):
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in verts]
    bm.faces.new(vs)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return me


def disc(name, r, x, y, z, col, sx=1.0, sy=1.0, rot=0.0, verts=48):
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=True, radius=r, segments=verts)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.location = (x, y, z)
    o.rotation_euler = Euler((R(90), rot, 0))
    o.scale = (sx, 1, sy)
    o.data.materials.append(col)
    return o


def rect(name, w, h, x, z, col, rot=0.0, y=0.0):
    me = _quad_mesh(name, [(-w / 2, 0, -h / 2), (w / 2, 0, -h / 2), (w / 2, 0, h / 2), (-w / 2, 0, h / 2)])
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.location = (x, y, z)
    o.rotation_euler = Euler((0, rot, 0))
    o.data.materials.append(col)
    return o


cream = flat("cream", (0.92, 0.85, 0.66))
cream2 = flat("cream2", (0.97, 0.93, 0.8))
red = flat("red", (0.68, 0.08, 0.07))
dred = flat("dred", (0.42, 0.04, 0.05))
green = flat("green", (0.18, 0.5, 0.18))
dgreen = flat("dgreen", (0.08, 0.3, 0.12))
lgreen = flat("lgreen", (0.45, 0.72, 0.25))
black = flat("black", (0.06, 0.05, 0.05))
white = flat("white", (0.98, 0.97, 0.9))
gold = flat("gold", (0.9, 0.7, 0.2))
y0 = 0.0
# фон: бумага, лучи и солнце
rect("paper", W, H, 0, 0, cream, y=y0)
for k in range(14):
    a = R(-80 + k * 160 / 13.0)
    rect("ray%d" % k, 0.012 if k % 2 else 0.02, 0.9, 0.0 + math.sin(a) * 0.0, -0.05, red if k % 2 == 0 else cream2, rot=a, y=y0 - 0.001)
disc("sun", 0.2, 0.0, y0 - 0.002, 0.03, red)
disc("sun2", 0.15, 0.0, y0 - 0.003, 0.03, gold)
# рамка
for (w, h, x, z) in ((W, 0.02, 0, H / 2 - 0.02), (W, 0.02, 0, -H / 2 + 0.02), (0.02, H, -W / 2 + 0.02, 0), (0.02, H, W / 2 - 0.02, 0)):
    rect("frame", w, h, x, z, dred, y=y0 - 0.004)
# шапка с заголовком
rect("band_top", W - 0.06, 0.15, 0, H / 2 - 0.12, red, y=y0 - 0.005)
for line, zz, sz in (("ЧЕРЕМША", H / 2 - 0.095, 0.092), ("ПОМНИТ", H / 2 - 0.18, 0.092)):
    t = C.text("title", line, sz, (0, y0 - 0.0065, zz), rot=(R(90), 0, 0), font=C.FONT_IMPACT, extrude=0, m=cream2)
# существо: туловище из листьев, голова, руки, пучок
DZ = -0.075
body = [(0.0, -0.12, 0.3, 0.46, R(0)), (-0.1, -0.1, 0.16, 0.4, R(22)), (0.1, -0.1, 0.16, 0.4, R(-22)), (-0.17, -0.16, 0.12, 0.3, R(48)), (0.17, -0.16, 0.12, 0.3, R(-48))]
for k, (x, z, sx, sz, rot) in enumerate(body):
    disc("leaf%d" % k, 0.16, x, y0 - 0.007 - k * 0.0003, z + DZ, green if k % 2 == 0 else dgreen, sx=sx * 2.2, sy=sz * 1.4, rot=rot)
    rect("vein%d" % k, 0.004, sz * 0.4, x, z + DZ, lgreen, rot=rot, y=y0 - 0.008 - k * 0.0003)
disc("head", 0.075, 0.0, y0 - 0.0105, 0.115 + DZ, lgreen, sx=1.0, sy=1.05)
for sx in (-1, 1):
    disc("eye", 0.019, sx * 0.03, y0 - 0.0112, 0.128 + DZ, white)
    disc("pupil", 0.009, sx * 0.03, y0 - 0.0115, 0.126 + DZ, black)
    rect("brow", 0.022, 0.006, sx * 0.032, 0.153 + DZ, black, rot=R(sx * -14), y=y0 - 0.0113)
rect("mouth", 0.05, 0.008, 0.0, 0.082 + DZ, black, rot=R(-3), y=y0 - 0.0113)
# листья-«волосы» на голове
for k, a in enumerate((-40, -15, 15, 40)):
    disc("hair%d" % k, 0.05, math.sin(R(a)) * 0.06, y0 - 0.0108, 0.17 + DZ + abs(a) * 0.0006, dgreen, sx=0.3, sy=0.8, rot=R(a))
# рука с пучком черемши, протянутая зрителю
for k in range(5):
    a = R(-28 + k * 14)
    disc("bunch%d" % k, 0.04, 0.2 + math.sin(a) * 0.03, y0 - 0.0115 - k * 0.0003, -0.08 + math.cos(a) * 0.05, lgreen if k % 2 else green, sx=0.22, sy=1.5, rot=a)
rect("band", 0.03, 0.04, 0.2, -0.13, red, y=y0 - 0.012)
# подпись и звезда
rect("band_bot", W - 0.06, 0.1, 0, -H / 2 + 0.085, red, y=y0 - 0.02)
C.text("sub", "ЧТО ИМЕННО — УТОЧНЯЕТСЯ", 0.034, (0, y0 - 0.0215, -H / 2 + 0.085), rot=(R(90), 0, 0), font=C.FONT_BOLD, extrude=0, m=cream2)
for k in range(5):
    a = R(90 + k * 72)
    b = R(90 + k * 72 + 36)
disc("star", 0.04, -0.2, y0 - 0.0105, -0.2, gold, verts=5, rot=R(18))
# износ бумаги: сгибы и потёртости (тёмные полосы, полупрозрачные)
fold = flat("fold", (0.78, 0.7, 0.5))
for (w, h, x, z) in ((W, 0.0025, 0, 0.0),):
    rect("fold", w, h, x, z, fold, y=y0 - 0.014)
cam_d = bpy.data.cameras.new("c")
cam_d.type = "ORTHO"
cam_d.ortho_scale = H
cam = bpy.data.objects.new("c", cam_d)
bpy.context.collection.objects.link(cam)
cam.location = (0, -1.0, 0)
cam.rotation_euler = (R(90), 0, 0)
sc.camera = cam
w = bpy.data.worlds.new("w")
w.use_nodes = True
w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.0, 0.0, 0.0, 1)
sc.world = w
out = os.path.join(C.OUT, "g67_poster_cheremsha.png")
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
sc.render.filepath = os.path.join(C.RENDERS, "g67_poster_cheremsha_1.png")
sc.render.resolution_x, sc.render.resolution_y = 1280, 720
bpy.ops.render.render(write_still=True)
print("G67MODEL g67_poster_cheremsha: текстура", out)
