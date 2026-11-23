"""Общее для моделей района 2 «ПОДЗЕМКА»: материалы кафеля, бетона, эмиссии, тексты. Запуск скриптов: G67_PZ=1 blender --background --python ..."""
import sys
import os
import math
sys.path.insert(0, os.path.dirname(__file__))
os.environ.setdefault("G67_PZ", "1")
import bpy
import g67_common as C

R = math.radians
ONLY = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else ""


def tile_mat(name, plane="xz", stripe=True, size=0.15, base=(0.86, 0.86, 0.8), dirt=0.6, z0=1.6):
    """Кафель «кабанчик» с зелёной полосой (до 1,1 м): процедурно, запекается. plane: xz — стены, xy — полы."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = C._n(nt, "ShaderNodeOutputMaterial", 2400, 0)
    pb = C._n(nt, "ShaderNodeBsdfPrincipled", 2100, 0)
    nt.links.new(pb.outputs["BSDF"], out.inputs["Surface"])
    tc = C._n(nt, "ShaderNodeTexCoord", 0, 0)
    sep = C._n(nt, "ShaderNodeSeparateXYZ", 200, 0)
    nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
    com = C._n(nt, "ShaderNodeCombineXYZ", 400, 0)
    if plane == "xz":
        nt.links.new(sep.outputs["X"], com.inputs["X"])
        nt.links.new(sep.outputs["Z"], com.inputs["Y"])
    else:
        nt.links.new(sep.outputs["X"], com.inputs["X"])
        nt.links.new(sep.outputs["Y"], com.inputs["Y"])
    br = C._n(nt, "ShaderNodeTexBrick", 650, 200)
    br.offset = 0.0
    br.inputs["Scale"].default_value = 1.0 / size
    br.inputs["Mortar Size"].default_value = 0.035
    br.inputs["Mortar Smooth"].default_value = 0.1
    br.inputs["Bias"].default_value = 0.0
    br.inputs["Brick Width"].default_value = 1.0
    br.inputs["Row Height"].default_value = 1.0
    br.inputs["Color1"].default_value = (*base, 1)
    br.inputs["Color2"].default_value = (base[0] * 0.93, base[1] * 0.93, base[2] * 0.9, 1)
    br.inputs["Mortar"].default_value = (0.5, 0.49, 0.44, 1)
    nt.links.new(com.outputs["Vector"], br.inputs["Vector"])
    # зелёная полоса
    col = br.outputs["Color"]
    if stripe and plane == "xz":
        lt = C._n(nt, "ShaderNodeMath", 650, -200, operation="LESS_THAN")
        lt.inputs[1].default_value = 1.1 - z0
        nt.links.new(sep.outputs["Z"], lt.inputs[0])
        mx = C._n(nt, "ShaderNodeMixRGB", 1000, 100)
        nt.links.new(lt.outputs["Value"], mx.inputs["Fac"])
        nt.links.new(br.outputs["Color"], mx.inputs["Color1"])
        mx.inputs["Color2"].default_value = (0.08, 0.38, 0.17, 1)
        # тёмная кромка полосы
        lt2 = C._n(nt, "ShaderNodeMath", 650, -400, operation="LESS_THAN")
        lt2.inputs[1].default_value = 1.14 - z0
        nt.links.new(sep.outputs["Z"], lt2.inputs[0])
        sub = C._n(nt, "ShaderNodeMath", 850, -400, operation="SUBTRACT")
        nt.links.new(lt2.outputs["Value"], sub.inputs[0])
        nt.links.new(lt.outputs["Value"], sub.inputs[1])
        mx2 = C._n(nt, "ShaderNodeMixRGB", 1200, 100)
        nt.links.new(sub.outputs["Value"], mx2.inputs["Fac"])
        nt.links.new(mx.outputs["Color"], mx2.inputs["Color1"])
        mx2.inputs["Color2"].default_value = (0.04, 0.2, 0.09, 1)
        col = mx2.outputs["Color"]
    # грязь: пятна, подтёки вниз, низ потемнее
    nz = C._n(nt, "ShaderNodeTexNoise", 650, -650, noise_dimensions="3D")
    nz.inputs["Scale"].default_value = 2.2
    nz.inputs["Detail"].default_value = 5.0
    mp = C._n(nt, "ShaderNodeMapping", 450, -650)
    mp.inputs["Scale"].default_value = (3.0, 3.0, 0.5) if plane == "xz" else (2.0, 2.0, 2.0)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    nt.links.new(mp.outputs["Vector"], nz.inputs["Vector"])
    rr = C._n(nt, "ShaderNodeValToRGB", 900, -650)
    rr.color_ramp.elements[0].position = 0.5
    rr.color_ramp.elements[1].position = 0.75
    nt.links.new(nz.outputs["Fac"], rr.inputs["Fac"])
    fac = C._n(nt, "ShaderNodeMath", 1150, -650, operation="MULTIPLY")
    fac.inputs[1].default_value = dirt
    nt.links.new(rr.outputs["Alpha"], fac.inputs[0])
    dm = C._n(nt, "ShaderNodeMixRGB", 1500, 100)
    nt.links.new(fac.outputs["Value"], dm.inputs["Fac"])
    nt.links.new(col, dm.inputs["Color1"])
    dm.inputs["Color2"].default_value = (0.2, 0.17, 0.12, 1)
    nt.links.new(dm.outputs["Color"], pb.inputs["Base Color"])
    # шероховатость и рельеф швов
    rm = C._n(nt, "ShaderNodeMapRange", 1500, -300)
    rm.inputs["From Min"].default_value = 0.0
    rm.inputs["From Max"].default_value = 1.0
    rm.inputs["To Min"].default_value = 0.95
    rm.inputs["To Max"].default_value = 0.28
    nt.links.new(br.outputs["Fac"], rm.inputs["Value"])
    nt.links.new(rm.outputs["Result"], pb.inputs["Roughness"])
    bp = C._n(nt, "ShaderNodeBump", 1500, -500)
    bp.inputs["Strength"].default_value = 0.6
    bp.inputs["Distance"].default_value = 0.02
    nt.links.new(br.outputs["Fac"], bp.inputs["Height"])
    nt.links.new(bp.outputs["Normal"], pb.inputs["Normal"])
    return m


def conc(name, base=(0.46, 0.46, 0.45), wear=0.4, dirt=1.0, scale=5.0, rough=0.9):
    return C.mat(name, base, under=(0.3, 0.28, 0.25), wear=wear, dirt=dirt, rough=rough, scale=scale, bump=0.7, streaks=0.7)


def glow(name, col, strength=1.0):
    """Эмиссионный материал: после запекания даёт цвет, в игре его включают отдельным материалом (узлы-группы)."""
    return C.mat(name, col, flat=True, dirt=0.0, rough=0.35)


def steel(name, base=(0.6, 0.62, 0.64), wear=0.5):
    return C.mat(name, base, under=(0.35, 0.18, 0.09), wear=wear, dirt=1.0, rough=0.4, scale=16, streaks=0.7)


def paint(name, col, wear=0.5):
    return C.mat(name, col, under=(0.3, 0.2, 0.14), wear=wear, dirt=0.9, rough=0.45, scale=14, streaks=0.5)


def run(build_map, size=1024):
    for nm, fn in build_map.items():
        if ONLY and nm != ONLY:
            continue
        C.reset()
        out = fn()
        P, views = out[0], out[1]
        sz = out[2] if len(out) > 2 else size
        P = [o for o in P if o is not None]
        C.finish("g67_pz_" + nm, P, views, size=sz)
