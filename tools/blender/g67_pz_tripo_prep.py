"""Подготовка моделей владельца (Tripo): исходник — в blender_source/podzemka/tripo_src (без изменений), рендер до/после, упрощение сетки, текстуры 2048, экспорт на место.
Запуск: G67_PZ=1 blender --background --python g67_pz_tripo_prep.py -- <файл_без_glb>:<целевые_треугольники>[:<имя_итога>] ..."""
import sys
import os
import math
import shutil
sys.path.insert(0, os.path.dirname(__file__))
os.environ.setdefault("G67_PZ", "1")
import bpy
import g67_common as C
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SRC = os.path.join(C.ROOT, "godot", "assets", "golda67", "blender_source", "podzemka", "tripo_src")
os.makedirs(SRC, exist_ok=True)
open(os.path.join(SRC, ".gdignore"), "a").close()


def scene_objs():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def bbox(objs):
    mn = Vector((1e9, 1e9, 1e9))
    mx = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            mn = Vector((min(mn.x, w.x), min(mn.y, w.y), min(mn.z, w.z)))
            mx = Vector((max(mx.x, w.x), max(mx.y, w.y), max(mx.z, w.z)))
    return mn, mx


def tri_count(objs):
    return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)


for spec in ARGS:
    parts = spec.split(":")
    name = parts[0]
    target = int(parts[1])
    out_name = parts[2] if len(parts) > 2 else name
    path = os.path.join(C.OUT, name + ".glb")
    src_copy = os.path.join(SRC, name + ".glb")
    if not os.path.exists(src_copy):
        shutil.copy2(path, src_copy)
    C.reset()
    bpy.ops.import_scene.gltf(filepath=src_copy)
    objs = scene_objs()
    mn, mx = bbox(objs)
    size = mx - mn
    t0 = tri_count(objs)
    print("G67TRIPO %s: треугольников %d, габарит %.2f × %.2f × %.2f (X × Y × Z, Z вверх), мин %s, макс %s" % (name, t0, size.x, size.y, size.z, tuple(round(v, 2) for v in mn), tuple(round(v, 2) for v in mx)))
    cx = (mn.x + mx.x) / 2
    cy = (mn.y + mx.y) / 2
    h = size.z
    views = [((cx + h * 0.5, cy - h * 2.2, mn.z + h * 0.6), (cx, cy, mn.z + h * 0.5)), ((cx + h * 2.0, cy + h * 0.2, mn.z + h * 0.6), (cx, cy, mn.z + h * 0.5))]
    C.render("tripo_%s_before" % out_name, views, ground=False)
    # упрощение с сохранением UV
    for o in objs:
        if t0 > target:
            bpy.context.view_layer.objects.active = o
            d = o.modifiers.new("dec", "DECIMATE")
            d.ratio = max(0.02, target / float(t0))
            d.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier="dec")
    t1 = tri_count(objs)
    # текстуры до 2048
    for im in bpy.data.images:
        if im.size[0] > 2048 or im.size[1] > 2048:
            k = 2048.0 / max(im.size[0], im.size[1])
            im.scale(int(im.size[0] * k), int(im.size[1] * k))
    C.render("tripo_%s_after" % out_name, views, ground=False)
    bpy.ops.object.select_all(action="DESELECT")
    for o in scene_objs():
        o.select_set(True)
    bpy.context.view_layer.objects.active = scene_objs()[0]
    out_path = os.path.join(C.OUT, out_name + ".glb")
    bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True, export_image_format="JPEG", export_jpeg_quality=85)
    print("G67TRIPO %s → %s: треугольников %d → %d, файл %.1f МБ" % (name, out_name, t0, t1, os.path.getsize(out_path) / 1048576.0))
