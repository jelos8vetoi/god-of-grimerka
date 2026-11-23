"""Вертел Tripo: отделить гриль-нагреватель (за мясом, y > порога) от мяса+вертела+поддона — первое вращается как узел `spit`, второй неподвижен.
Запуск: G67_PZ=1 blender --background --python g67_pz_spit_split.py"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
os.environ.setdefault("G67_PZ", "1")
import bpy, bmesh
import g67_common as C
path = os.path.join(C.OUT, "g67_pz_shawarma_spit.glb")
src = os.path.join(C.ROOT, "godot", "assets", "golda67", "blender_source", "podzemka", "tripo_src", "g67_pz_shawarma_spit.glb")
C.reset()
bpy.ops.import_scene.gltf(filepath=src)
ob = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
print("G67SPLIT исходный меш: треугольников", sum(len(p.vertices) - 2 for p in ob.data.polygons))
bpy.context.view_layer.objects.active = ob
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="DESELECT")
bpy.ops.object.mode_set(mode="OBJECT")
THR = 7.0
n = 0
for p in ob.data.polygons:
    c = ob.matrix_world @ p.center
    p.select = c.y > THR
    n += 1 if p.select else 0
print("G67SPLIT граней грилля:", n, "из", len(ob.data.polygons))
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.separate(type="SELECTED")
bpy.ops.object.mode_set(mode="OBJECT")
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in objs:
    cy = sum((o.matrix_world @ v.co).y for v in o.data.vertices) / len(o.data.vertices)
    o.name = "grill" if cy > 3.0 else "spit"
    o.data.name = o.name
    print("G67SPLIT", o.name, sum(len(p.vertices) - 2 for p in o.data.polygons), "треугольников")
for o in objs:
    bpy.context.view_layer.objects.active = o
    t = sum(len(p.vertices) - 2 for p in o.data.polygons)
    goal = 12000 if o.name == "spit" else 3500
    d = o.modifiers.new("dec", "DECIMATE")
    d.ratio = min(1.0, goal / float(t))
    bpy.ops.object.modifier_apply(modifier="dec")
    print("G67SPLIT после упрощения", o.name, sum(len(p.vertices) - 2 for p in o.data.polygons))
for im in bpy.data.images:
    if im.size[0] > 2048:
        k = 2048.0 / im.size[0]
        im.scale(int(im.size[0] * k), int(im.size[1] * k))
C.render("tripo_spit_split", [((70, -110, 55), (0, 0, 45)), ((120, 60, 80), (0, 0, 45))], ground=False)
bpy.ops.object.select_all(action="DESELECT")
for o in objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = objs[0]
bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True, export_image_format="JPEG", export_jpeg_quality=85)
print("G67SPLIT экспорт", path)
