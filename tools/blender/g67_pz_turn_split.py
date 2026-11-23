"""Турникет Sketchfab: отделить трипод (рычаги и втулка) в узел turnstile_arm по связным частям. Запуск: G67_PZ=1 blender --background --python g67_pz_turn_split.py [-- apply]"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
os.environ.setdefault("G67_PZ", "1")
import bpy
import g67_common as C
from mathutils import Vector
src = os.path.join(C.ROOT, "godot", "assets", "golda67", "blender_source", "sketchfab_src", "sf_turnstile", "sf_turnstile.glb")
C.reset()
bpy.ops.import_scene.gltf(filepath=src)
parts = [o for o in bpy.context.scene.objects if o.type == "MESH"]
info = []
for o in parts:
    vs = [o.matrix_world @ v.co for v in o.data.vertices]
    mn = Vector((min(v[i] for v in vs) for i in range(3)))
    mx = Vector((max(v[i] for v in vs) for i in range(3)))
    t = sum(len(p.vertices) - 2 for p in o.data.polygons)
    info.append((o, mn, mx, t))
    print("G67TS part", o.name, "tris", t, "min", tuple(round(x, 2) for x in mn), "max", tuple(round(x, 2) for x in mx))
