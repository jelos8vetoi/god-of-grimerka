"""ДВОР 2: игровые ассеты района из библиотеки частей.
Берёт только те части, что стоят в районе (план, таблица декораций, сцена), сливает сетки в одну (меньше вызовов отрисовки),
упрощает тяжёлые и пишет <id>.glb во временную папку; дальше tools/dvor2_assets.py уменьшает текстуры и кладёт в godot/assets/golda67/dvor2/.
blender --background --python tools/blender/dvor2_export.py -- <папка_выхода>"""
import bpy, os, sys, json
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'godot', 'assets', 'golda67', 'dvor_redesign_work'))
OUT = sys.argv[-1]; os.makedirs(OUT, exist_ok=True)
LIB = json.load(open(os.path.join(ROOT, 'architecture_parts', 'library.json'), encoding='utf-8'))
LAY = json.load(open(os.path.join(ROOT, 'topdown_layout', 'DVOR_TOPDOWN_RECOMMENDED.layout.json'), encoding='utf-8'))
PR = json.load(open(os.path.join(ROOT, 'topdown_layout', 'DVOR_PROPS.json'), encoding='utf-8'))
ids = {i['model'] for i in LAY['items'] if i['model'] and not i['model'].startswith('game:')} | {p['m'] for p in PR['props']}
ids |= {'fence_rhombus', 'lamp_1', 'lamp_2', 'lamp_3', 'lamp_5', 'sign_1', 'sign_5', 'sign_10', 'sign_11', 'sign_13', 'pole_wires', 'pole_concrete',
        'tower_16_wide', 'tower_9_wide', 'tower_16_slab', 'tower_9_slab', 'smoke_stacks', 'res_long_9'}
ids = sorted(i for i in ids if i in LIB)
KEEP = ('gate_L', 'gate_R', 'gate_chain')          # отдельные объекты арки — для анимации открытия
def limit(i):
    s = LIB[i]['section']; sz = LIB[i]['size']; big = max(sz)
    if i == 'pitch_fenced': return 30000
    if s == 'buildings' or big > 12: return 40000
    if i.startswith(('tree_', 'pine_', 'snow_pine', 'bush_')): return 2500
    if big < 1.2: return 900
    if big < 3: return 2500
    return 8000
man = {}
for i in ids:
    bpy.ops.wm.read_factory_settings(use_empty=True); sc = bpy.context.scene
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, 'architecture_parts', LIB[i]['section'], i + '.glb'))
    ms = [o for o in sc.objects if o.type == 'MESH']
    main = [o for o in ms if o.name not in KEEP]
    bpy.ops.object.select_all(action='DESELECT')
    for o in ms:
        o.select_set(True)
    bpy.context.view_layer.objects.active = main[0]
    bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
    bpy.ops.object.select_all(action='DESELECT')
    for o in main: o.select_set(True)
    bpy.context.view_layer.objects.active = main[0]
    if len(main) > 1: bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active; body.name = i
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons); lim = limit(i)
    if tris > lim:
        m = body.modifiers.new('d', 'DECIMATE'); m.ratio = lim / tris
        bpy.context.view_layer.objects.active = body; bpy.ops.object.modifier_apply(modifier='d')
    for o in list(sc.objects):
        if o.type != 'MESH': bpy.data.objects.remove(o)
    t2 = sum(len(p.vertices) - 2 for o in sc.objects for p in o.data.polygons)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, i + '.glb'), export_format='GLB', use_selection=True, export_apply=True)
    vs = [o.matrix_world @ v.co for o in sc.objects for v in o.data.vertices]
    man[i] = {'size': [round(max(v[k] for v in vs) - min(v[k] for v in vs), 2) for k in range(3)], 'lo': [round(min(v[k] for v in vs), 2) for k in range(3)],
              'tris': t2, 'was': tris, 'section': LIB[i]['section'], 'source': LIB[i]['source']}
    print('EXPORT', i, tris, '->', t2, flush=True)
json.dump(man, open(os.path.join(OUT, 'manifest.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('DONE', len(man))
