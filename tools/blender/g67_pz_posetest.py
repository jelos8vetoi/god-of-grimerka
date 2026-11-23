"""Контрольные позы рига: python ... -- <rigged.glb> <префикс_выхода>. 6 поз: руки вверх, руки вперёд, присед, широкий шаг, скручивание, наклон головы. Кадры → <префикс>_<поза>.png"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
os.environ.setdefault("G67_PZ", "1")
import bpy
import g67_common as C
from mathutils import Matrix, Vector
glb, prefix = sys.argv[sys.argv.index("--") + 1:][:2]
C.reset()
bpy.ops.import_scene.gltf(filepath=glb)
arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
print("G67POSE кости:", len(arm.pose.bones), [b.name for b in arm.pose.bones][:6])
bpy.context.view_layer.objects.active = arm


def bone(name):
    for b in arm.pose.bones:
        if b.name.replace("mixamorig:", "").replace("mixamorig_", "") == name:
            return b
    raise KeyError(name)


def rot(name, axis, deg):
    pb = bone(name)
    bpy.context.view_layer.update()
    W = arm.matrix_world
    head = W @ pb.head
    R = Matrix.Translation(head) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-head)
    pb.matrix = W.inverted() @ (R @ (W @ pb.matrix))
    bpy.context.view_layer.update()


def reset():
    for b in arm.pose.bones:
        b.rotation_mode = "QUATERNION"
        b.rotation_quaternion = (1, 0, 0, 0)
        b.location = (0, 0, 0)
        b.scale = (1, 1, 1)
    bpy.context.view_layer.update()


POSES = {
    "arms_up": [("LeftArm", "Y", -90), ("RightArm", "Y", 90)],
    "arms_forward": [("LeftArm", "Z", -90), ("RightArm", "Z", 90)],
    "crouch": [("LeftUpLeg", "X", -70), ("RightUpLeg", "X", -70), ("LeftLeg", "X", 100), ("RightLeg", "X", 100), ("Spine", "X", -15)],
    "stride": [("LeftUpLeg", "X", -50), ("RightUpLeg", "X", 30), ("LeftLeg", "X", 20), ("LeftArm", "X", 30)],
    "twist": [("Spine", "Z", 30), ("Spine1", "Z", 25), ("Spine2", "Z", 20)],
    "head_tilt": [("Head", "Y", 30), ("Neck", "Y", 10), ("Head", "X", -25)],
}
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"
sc.render.resolution_x = sc.render.resolution_y = 700
sc.view_settings.view_transform = "Standard"
C._lights()
reset()
zs = [(arm.matrix_world @ pb.head).z for pb in arm.pose.bones] + [(arm.matrix_world @ pb.tail).z for pb in arm.pose.bones]
xs = [(arm.matrix_world @ pb.head).x for pb in arm.pose.bones]
ctr = Vector((0, 0, (min(zs) + max(zs)) / 2))
L = max(zs) - min(zs)
L = max(L, (max(xs) - min(xs)) * 0.8) * 1.1
print("G67POSE ctr", tuple(round(v, 2) for v in ctr), "L", round(L, 2))
cd = bpy.data.cameras.new("c")
cd.type = "ORTHO"
cd.ortho_scale = L * 1.05
cam = bpy.data.objects.new("c", cd)
bpy.context.collection.objects.link(cam)
sc.camera = cam
cam.location = ctr + Vector((math.sin(math.radians(32)) * L * 3, -math.cos(math.radians(32)) * L * 3, 0))
cam.rotation_euler = (math.radians(90), 0, math.radians(32))
for name, ops in POSES.items():
    reset()
    for (b, ax, d) in ops:
        try:
            rot(b, ax, d)
        except KeyError as e:
            print("G67POSE нет кости", e)
    sc.render.filepath = os.path.join(C.RENDERS, "%s_%s.png" % (prefix, name))
    bpy.ops.render.render(write_still=True)
print("G67POSE готово", prefix)
