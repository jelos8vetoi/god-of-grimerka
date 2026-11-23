"""ДВОР, редизайн: библиотека частей из исходных GLB владельца (оригиналы не меняются).
blender --background --python tools/blender/dvor_extract.py
Пишет architecture_parts/<раздел>/<id>.glb (метры, низ на нуле, центр основания в начале координат),
previews/<id>.png и architecture_parts/library.json (размеры, треугольники, источник)."""
import bpy, bmesh, os, json, math
from mathutils import Vector
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'godot', 'assets', 'golda67', 'dvor_redesign_work'))
SRC = os.path.join(ROOT, 'source_references'); OUT = os.path.join(ROOT, 'architecture_parts'); PRE = os.path.join(ROOT, 'previews')
LIB = {}

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sh = sc.display.shading; sh.light = 'STUDIO'; sh.color_type = 'TEXTURE'; sh.show_cavity = True
    sc.world = bpy.data.worlds.new('w'); sc.world.color = (0.16, 0.17, 0.2)
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam
    return sc, cam

def load(name):
    sc, cam = reset()
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, name + '.glb'))
    bpy.context.view_layer.update()
    return sc, cam, [o for o in sc.objects if o.type == 'MESH']

def bbox(objs):
    lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
    return lo, hi

def par(o):
    return o.parent.name if o.parent else ''

def join(sc, objs, name):
    """Склеить объекты в один с запечёнными мировыми преобразованиями."""
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.hide_set(False); o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    o.name = name
    return o

def place(o, scale=1.0, yaw=0.0):
    """Масштаб, поворот, низ на ноль, центр основания в начало координат."""
    o.scale = (scale,) * 3; o.rotation_euler = (0, 0, yaw)
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    lo, hi = bbox([o])
    o.location = (-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z)
    bpy.context.view_layer.update()
    bpy.ops.object.transform_apply(location=True)

def shot(sc, cam, objs, path, az=35, el=26, res=(640, 480)):
    lo, hi = bbox(objs); c = (lo + hi) / 2; r = max((hi - lo).length / 2, 0.05)
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = r * 2.15
    a, e = math.radians(az), math.radians(el)
    d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    cam.location = c + d * (r * 4 + 5); cam.rotation_euler = d.to_track_quat('Z', 'Y').to_euler()
    cam.data.clip_end = r * 10 + 50
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.filepath = path; bpy.ops.render.render(write_still=True)

def emit(sc, cam, o, section, pid, src, note):
    for x in sc.objects:
        if x.type == 'MESH': x.hide_render = x is not o
    lo, hi = bbox([o])
    shot(sc, cam, [o], os.path.join(PRE, pid + '.png'))
    shot(sc, cam, [o], os.path.join(PRE, pid + '_b.png'), az=215)
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
    path = os.path.join(OUT, section, pid + '.glb')
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format='GLB', export_yup=True, export_apply=True)
    LIB[pid] = {'section': section, 'source': src, 'size': [round(v, 2) for v in (hi - lo)],
                'tris': sum(len(p.vertices) - 2 for p in o.data.polygons), 'mats': len(o.data.materials),
                'mb': round(os.path.getsize(path) / 1e6, 1), 'note': note}
    print('PART', pid, LIB[pid]['size'], LIB[pid]['tris'], flush=True)

def split_x(o, rule):
    """Разделить сетку на две по островам: rule(lo, hi, центр грани) -> True — в первую часть."""
    bm = bmesh.new(); bm.from_mesh(o.data); bm.faces.ensure_lookup_table()
    seen = set(); first = set()
    for f in bm.faces:
        if f.index in seen: continue
        stack = [f]; isl = []
        seen.add(f.index)
        while stack:
            g = stack.pop(); isl.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen:
                        seen.add(h.index); stack.append(h)
        xs = [v.co.x for g in isl for v in g.verts]
        lo, hi = min(xs), max(xs)
        for g in isl:
            if rule(lo, hi, g.calc_center_median()):
                first.add(g.index)
    bm.free()
    a = o.copy(); a.data = o.data.copy(); bpy.context.scene.collection.objects.link(a)
    for ob, keep_first in ((o, True), (a, False)):
        bm = bmesh.new(); bm.from_mesh(ob.data)
        kill = [f for f in bm.faces if (f.index in first) != keep_first]
        bmesh.ops.delete(bm, geom=kill, context='FACES'); bm.to_mesh(ob.data); bm.free()
    return o, a

# ---------------- жилой комплекс: два корпуса отдельно
sc, cam, ms = load('soviet_apartment_building__russian_far_east')
skip = ('Site', 'Path', 'Curb', 'Foliage', 'Stem', 'Road', 'Parking', 'GrassClusters', 'SpeedTable')
bld = [o for o in ms if not any(k in par(o) for k in skip)]
for o in ms:
    if o not in bld: bpy.data.objects.remove(o)
# корпуса стоят уступом и срослись торцами: на месте стыка стены нет. Закрываем копией глухого торца того же корпуса
for nm, x in (('EndWalls_W', -0.13), ('EndWalls_E', 0.13)):
    e = next(o for o in bld if par(o).startswith(nm))
    c = e.copy(); c.data = e.data.copy(); sc.collection.objects.link(c)
    bpy.context.view_layer.update()
    lo, hi = bbox([e]); cx = (lo.x + hi.x) / 2
    for v in c.data.vertices:
        w = c.matrix_world @ v.co
        w.x = x - (w.x - cx)
        v.co = c.matrix_world.inverted() @ w
    c.data.flip_normals(); c.data.update()
    bld.append(c)
whole = join(sc, bld, 'sov')
def rule(lo, hi, c):
    if hi <= 0.005: return True
    if lo >= -1.2: return False
    return c.x < -0.4
a, b = split_x(whole, rule)
src = 'soviet_apartment_building__russian_far_east'
for o, pid, note in ((a, 'res_block_a', 'четырёхэтажка, западный корпус'), (b, 'res_block_b', 'четырёхэтажка, восточный корпус')):
    place(o); emit(sc, cam, o, 'buildings', pid, src, note)

# ---------------- башни-панельки дальнего плана (набор в масштабе макета: x3.9)
sc, cam, ms = load('street_city_7_for_games_free')
groups = {}
for o in ms:
    lo, hi = bbox([o])
    if hi.z - lo.z > 6: groups.setdefault(par(o).split('_Material')[0], []).append(o)
print('TOWER GROUPS', {k: len(v) for k, v in groups.items()})
keep = {'Plane.028': 'tower_16_wide', 'Plane.027': 'tower_16_slab', 'Cube.012': 'tower_9_wide', 'Cube.014': 'tower_9_slab'}
done = []
for p, pid in keep.items():
    if p not in groups: print('NO GROUP', p); continue
    o = join(sc, groups[p], pid); done.append((o, pid))
for o, pid in done:
    place(o, 3.9)
    emit(sc, cam, o, 'buildings', pid, 'street_city_7_for_games_free', 'панельная башня-оболочка: только дальний план за границей района')

# ---------------- фастфуд без пилонов бренда
sc, cam, ms = load('mcdonalds-restaurant-low-poly')
body = [o for o in ms if par(o) != '5_2']
for o in ms:
    if o not in body: bpy.data.objects.remove(o)
o = join(sc, body, 'fastfood'); place(o)
emit(sc, cam, o, 'buildings', 'fastfood_lot', 'mcdonalds-restaurant-low-poly', 'ресторан с проездом и забором; пилоны с логотипом сняты')

# ---------------- гаражи
for name, pid, k, note in (('garage_rusty_01', 'garage_shell_graffiti', 0.75, 'металлический гараж в граффити'),
                           ('old_garage', 'garage_brick_double', 0.001, 'кирпичный бокс на двое ворот, шиферная крыша'),
                           ('russian_garage_low-poly_game_model_4k_pbr_tex', 'garage_concrete_45', 0.0047, 'бетонный гараж № 45, красные ворота')):
    sc, cam, ms = load(name); o = join(sc, ms, pid); place(o, k); emit(sc, cam, o, 'garages', pid, name, note)
sc, cam, ms = load('low_poly_garages')
ms.sort(key=lambda o: bbox([o])[0].y)
objs = [join(sc, [o], 'garage_tin_%d' % (i + 1)) for i, o in enumerate(ms)]
for i, o in enumerate(objs):
    place(o); emit(sc, cam, o, 'garages', 'garage_tin_%d' % (i + 1), 'low_poly_garages', 'жестяной гараж, цвет %d' % (i + 1))

# ---------------- реквизит
for name, pid, k, sec, note in (('1991_vaz_21099', 'car_vaz_21099', 0.01, 'props', 'ВАЗ-21099'),
                                ('bench_siberian_classic_01', 'bench_siberian', 1.0, 'props', 'лавка'),
                                ('dumpster_russian_blue', 'dumpster_blue', 1.0, 'props', 'мусорный бак'),
                                ('electrical_box_-_free', 'elbox_green', 1.0, 'props', 'электрошкаф'),
                                ('rusty_street_electrical_boxes_1', 'elbox_rusty_pair', 1.0, 'props', 'два ржавых шкафа'),
                                ('old_russian_bus_stop', 'bus_stop_blue', 1.0, 'streets', 'остановка из профлиста со знаком'),
                                ('wall_low_poly', 'fence_concrete', 0.008, 'walls', 'бетонная плита забора и два столба'),
                                ('tree_low_poly_lowpoly', 'tree_leafy_pair', 1.0, 'props', 'два лиственных дерева (летние)'),
                                ('ceiling_lamp-10mb', 'lamp_tube', 1.0, 'props', 'линейный светильник')):
    sc, cam, ms = load(name); o = join(sc, ms, pid); place(o, k); emit(sc, cam, o, sec, pid, name, note)
sc, cam, ms = load('snow_pine_tree_and_bush_pack_lowpoly')
ms = [o for o in ms if (bbox([o])[1].z - bbox([o])[0].z) > 0.3 and (bbox([o])[1].x - bbox([o])[0].x) < 12]
grp = {}
for o in ms: grp.setdefault(par(o).split('_')[0] or o.name, []).append(o)
objs = [join(sc, g, 'x%d' % i) for i, g in enumerate(grp.values())]
objs.sort(key=lambda o: -(bbox([o])[1].z - bbox([o])[0].z))
for i, o in enumerate(objs):
    place(o); emit(sc, cam, o, 'props', 'snow_pine_%d' % (i + 1), 'snow_pine_tree_and_bush_pack_lowpoly', 'заснеженная ель или куст')

json.dump(LIB, open(os.path.join(OUT, 'library.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('DONE', len(LIB))
