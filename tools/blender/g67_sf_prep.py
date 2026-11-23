"""Sketchfab → игра: python ... -- <имя> <высота_м> <треугольники> [<поворот_Z_град>] [<макс_текстура>] [<ось: z|x|y — по какому габариту масштабировать>]
Берёт blender_source/sketchfab_src/<имя>/ (glb или scene.gltf), сливает меши в один, масштаб в метры, низ на ноль, центр по XY, упрощение, текстуры,
экспорт в godot/assets/golda67/podzemka/<имя>.glb, два рендера. Лицо должно смотреть в −Y Blender (в Godot +Z): поворот подбирается параметром."""
import sys, os, math, glob
sys.path.insert(0, os.path.dirname(__file__))
os.environ.setdefault("G67_PZ", "1")
import bpy
import g67_common as C
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
name, height, tris = a[0], float(a[1]), int(a[2])
rotz = float(a[3]) if len(a) > 3 else 0.0
maxtex = int(a[4]) if len(a) > 4 else 1024
axis = a[5] if len(a) > 5 else "z"
src_dir = os.path.join(C.ROOT, "godot", "assets", "golda67", "blender_source", "sketchfab_src", name)
cands = glob.glob(os.path.join(src_dir, "*.glb")) + glob.glob(os.path.join(src_dir, "*.gltf"))
C.reset()
bpy.ops.import_scene.gltf(filepath=cands[0])
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in bpy.context.scene.objects:
    o.select_set(False)
for o in objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = objs[0]
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
split_key = os.environ.get("SF_SPLIT")
split_obj = None
if split_key:
    sp = [o for o in objs if split_key in o.name]
    rest = [o for o in objs if split_key not in o.name]
    if sp and rest:
        bpy.ops.object.select_all(action="DESELECT")
        for o in sp:
            o.select_set(True)
        bpy.context.view_layer.objects.active = sp[0]
        if len(sp) > 1:
            bpy.ops.object.join()
        split_obj = bpy.context.view_layer.objects.active
        split_obj.name = os.environ.get("SF_SPLIT_NAME", "split_part")
        objs = rest
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
if len(objs) > 1:
    bpy.ops.object.join()
ob = bpy.context.view_layer.objects.active
for o in list(bpy.context.scene.objects):
    if o != ob and o != split_obj:
        bpy.data.objects.remove(o)
for _o in [ob] + ([split_obj] if split_obj else []):
    _o.rotation_euler = (0, 0, math.radians(rotz))
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
bpy.context.view_layer.objects.active = ob
mn = Vector((min((ob.matrix_world @ v.co)[i] for v in ob.data.vertices) for i in range(3)))
mx = Vector((max((ob.matrix_world @ v.co)[i] for v in ob.data.vertices) for i in range(3)))
size = mx - mn
dim = {"z": size.z, "x": size.x, "y": size.y}[axis]
k = height / dim if dim > 1e-6 else 1.0
for _o in [ob] + ([split_obj] if split_obj else []):
    _o.scale = (k, k, k)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
bpy.context.view_layer.objects.active = ob
mn = Vector((min((ob.matrix_world @ v.co)[i] for v in ob.data.vertices) for i in range(3)))
mx = Vector((max((ob.matrix_world @ v.co)[i] for v in ob.data.vertices) for i in range(3)))
for _o in [ob] + ([split_obj] if split_obj else []):
    _o.location = Vector((-(mn.x + mx.x) / 2, -(mn.y + mx.y) / 2, -mn.z))
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
if split_obj:
    bpy.context.view_layer.objects.active = split_obj
    bpy.ops.object.select_all(action="DESELECT")
    split_obj.select_set(True)
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
bpy.context.view_layer.objects.active = ob
cutz = os.environ.get("SF_CUTZ")
if cutz:
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    kill = [f for f in bm.faces if f.calc_center_median().z > float(cutz)]
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bm.to_mesh(ob.data)
    bm.free()
t0 = sum(len(p.vertices) - 2 for p in ob.data.polygons)
if t0 > tris:
    d = ob.modifiers.new("dec", "DECIMATE")
    d.ratio = tris / float(t0)
    bpy.ops.object.modifier_apply(modifier="dec")
t1 = sum(len(p.vertices) - 2 for p in ob.data.polygons)
for p in ob.data.polygons:
    p.use_smooth = True
for im in bpy.data.images:
    if max(im.size) > maxtex:
        kk = maxtex / float(max(im.size))
        im.scale(max(1, int(im.size[0] * kk)), max(1, int(im.size[1] * kk)))
size = Vector((max(v.co[i] for v in ob.data.vertices) - min(v.co[i] for v in ob.data.vertices) for i in range(3)))
print("G67SF %s: треугольников %d → %d, габарит X %.2f Y %.2f Z %.2f м" % (name, t0, t1, size.x, size.y, size.z))
h = max(size)
views = [((h * 0.9, -h * 2.2, size.z * 0.7), (0, 0, size.z * 0.45)), ((-h * 1.4, -h * 1.2, size.z * 0.9), (0, 0, size.z * 0.45))]
C.render("sf_" + name, views, ground=True)
bpy.ops.object.select_all(action="DESELECT")
ob.select_set(True)
if split_obj:
    split_obj.select_set(True)
bpy.context.view_layer.objects.active = ob
out = os.path.join(C.OUT, name + ".glb")
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_apply=True, export_yup=True, export_image_format="JPEG", export_jpeg_quality=88)
print("G67SF экспорт", out, round(os.path.getsize(out) / 1048576.0, 2), "МБ")
