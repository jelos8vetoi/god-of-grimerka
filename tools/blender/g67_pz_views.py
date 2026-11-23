"""Шесть ортогональных рендеров модели: python ... -- <glb> <префикс>. Печатает габарит; ortho_scale = 1.25 × наибольший размер, кадр 1000 × 1000
(пиксель → метры: размер_модели × 1.25 / 1000 на пиксель). Виды: front(−Y), back, left(−X), right, top, iso."""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
os.environ.setdefault("G67_PZ", "1")
import bpy
import g67_common as C
from mathutils import Vector
glb, prefix = sys.argv[sys.argv.index("--") + 1:][:2]
C.reset()
bpy.ops.import_scene.gltf(filepath=glb)
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
mn = Vector((1e9,) * 3)
mx = Vector((-1e9,) * 3)
for o in objs:
    for c in o.bound_box:
        w = o.matrix_world @ Vector(c)
        mn = Vector((min(mn.x, w.x), min(mn.y, w.y), min(mn.z, w.z)))
        mx = Vector((max(mx.x, w.x), max(mx.y, w.y), max(mx.z, w.z)))
ctr = (mn + mx) / 2
size = mx - mn
print("G67VIEW bbox min %s max %s size %s" % (tuple(round(v, 3) for v in mn), tuple(round(v, 3) for v in mx), tuple(round(v, 3) for v in size)))
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"
sc.render.resolution_x = sc.render.resolution_y = 1000
sc.view_settings.view_transform = "Standard"
C._lights()
cd = bpy.data.cameras.new("c")
cd.type = "ORTHO"
cd.ortho_scale = max(size) * 1.25
cam = bpy.data.objects.new("c", cd)
bpy.context.collection.objects.link(cam)
sc.camera = cam
D = max(size) * 3
views = {"front": (0, -1, 0), "back": (0, 1, 0), "left": (-1, 0, 0), "right": (1, 0, 0), "top": (0, 0, 1), "iso": (0.7, -0.7, 0.5)}
for name, d in views.items():
    v = Vector(d).normalized()
    cam.location = ctr + v * D
    up = "Y" if name != "top" else "Y"
    cam.rotation_euler = (-v).to_track_quat("-Z", up).to_euler()
    if name == "iso":
        cd.type = "PERSP"
        cd.lens = 50
        cam.location = ctr + v * max(size) * 2.4
    else:
        cd.type = "ORTHO"
    sc.render.filepath = os.path.join(C.RENDERS, "%s_%s.png" % (prefix, name))
    bpy.ops.render.render(write_still=True)
print("G67VIEW done", prefix)
