"""Prepare opaque trunk and two real groundcover meshes from Poly Haven glTF."""
import bpy
import json
import sys
from pathlib import Path

source, dest = map(Path, sys.argv[sys.argv.index("--") + 1:])
for asset, mesh_index, primitive, fraction, name in [
    ("tree_small_02", 0, 2, .075, "trunk"),
    ("shrub_02", 1, 0, .32, "shrub"),
    ("grass_medium_01", 3, 0, 1, "grass"),
]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    folder = source / asset
    doc = json.loads((folder / (asset + ".gltf")).read_text())
    selected = doc["meshes"][mesh_index]["primitives"][primitive]
    selected.pop("material", None)
    doc["meshes"] = [{"primitives": [selected]}]
    doc["nodes"] = [{"mesh": 0}]
    doc["scenes"] = [{"nodes": [0]}]
    for key in ("materials", "textures", "images", "samplers"):
        doc.pop(key, None)
    subset = folder / "subset.gltf"
    subset.write_text(json.dumps(doc))
    bpy.ops.import_scene.gltf(filepath=str(subset.resolve()))
    ob = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    if fraction < 1:
        modifier = ob.modifiers.new("Game silhouette", "DECIMATE")
        modifier.ratio = fraction
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.ops.wm.obj_export(filepath=str((dest / (name + ".obj")).resolve()),
                          export_materials=False, export_triangulated_mesh=True)
