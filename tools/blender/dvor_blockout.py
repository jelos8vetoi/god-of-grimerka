"""ДВОР, редизайн: 3D-блокаут из раскладки плана (tools/dvor_plan.py) и библиотеки частей.
blender --background --python tools/blender/dvor_blockout.py -- [DVOR_TOPDOWN_RECOMMENDED]
Пишет blender_source/dvor_blockout.blend и previews/blockout_*.png. Это прототип композиции, не игровая сцена."""
import bpy, os, sys, json, math
from mathutils import Vector
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
ROOT = os.path.join(REPO, 'godot', 'assets', 'golda67', 'dvor_redesign_work')
name = sys.argv[-1] if sys.argv[-1].startswith('DVOR_') else 'DVOR_TOPDOWN_RECOMMENDED'
L = json.load(open(os.path.join(ROOT, 'topdown_layout', name + '.layout.json'), encoding='utf-8'))
LIB = json.load(open(os.path.join(ROOT, 'architecture_parts', 'library.json'), encoding='utf-8'))

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = 'BLENDER_WORKBENCH'
sh = sc.display.shading; sh.light = 'STUDIO'; sh.color_type = 'TEXTURE'; sh.show_cavity = True; sh.show_shadows = True; sh.shadow_intensity = 0.35
sc.display.light_direction = (0.4, 0.5, 0.75)
sc.world = bpy.data.worlds.new('w'); sc.world.color = (0.10, 0.12, 0.18)
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam

def mat(nm, col):
    m = bpy.data.materials.new(nm); m.diffuse_color = col + (1,)
    m.use_nodes = True
    b = m.node_tree.nodes.get('Principled BSDF')
    if b: b.inputs['Base Color'].default_value = col + (1,); b.inputs['Roughness'].default_value = 0.85
    return m
MATS = {'snow': mat('snow', (0.86, 0.89, 0.94)), 'road': mat('road', (0.23, 0.24, 0.27)), 'ice': mat('ice', (0.62, 0.78, 0.9)),
        'board': mat('board', (0.85, 0.82, 0.74)), 'red': mat('red', (0.7, 0.12, 0.1)), 'box': mat('box', (0.55, 0.5, 0.45)), 'walk': mat('walk', (0.7, 0.72, 0.76))}

def box(nm, x, y, w, h, z0, z1, m):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, (z0 + z1) / 2)); o = bpy.context.object
    o.scale = (w, h, z1 - z0); o.name = nm; o.data.materials.append(MATS[m]); return o

def bbox(objs):
    lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
    return lo, hi

CACHE = {}
def model(mid):
    """Корень модели (пустышка с сетками) и размер основания. Библиотека — как есть; модели игры — нормированы, размер задаётся при постановке."""
    if mid in CACHE: return CACHE[mid]
    if mid.startswith('game:'):
        rel = mid[5:]
        path = os.path.join(REPO, 'godot', 'assets', (rel if '/' in rel else 'golda67/' + rel) + '.glb')
    else:
        path = os.path.join(ROOT, 'architecture_parts', LIB[mid]['section'], mid + '.glb')
    if not os.path.exists(path):
        CACHE[mid] = None; print('MISSING', path); return None
    before = set(sc.objects)
    bpy.ops.import_scene.gltf(filepath=path); bpy.context.view_layer.update()
    new = [o for o in sc.objects if o not in before]
    ms = [o for o in new if o.type == 'MESH']
    root = bpy.data.objects.new('SRC_' + mid, None); sc.collection.objects.link(root)
    for o in new:
        if o.parent is None: o.parent = root
    bpy.context.view_layer.update()
    lo, hi = bbox(ms)
    CACHE[mid] = (root, new, lo, hi)
    root.location = (0, 0, -500)      # исходник прячем под землю
    return CACHE[mid]

def put(mid, x, y, yaw_deg, fit=None, nm='', k0=None):
    src = model(mid)
    if src is None: return None
    root, objs, lo, hi = src
    sx, sy = hi.x - lo.x, hi.y - lo.y
    k = 1.0
    if fit is not None: k = fit / max(sx, sy, 1e-6)
    if k0 is not None: k = k0
    holder = bpy.data.objects.new(nm or mid, None); sc.collection.objects.link(holder)
    mp = {}
    for o in objs:
        c = o.copy(); sc.collection.objects.link(c); mp[o] = c
    for o, c in mp.items():
        c.parent = mp.get(o.parent, holder if o.parent is root or o.parent is None else None)
        if o.parent is root: c.parent = holder
    cx, cy = (lo.x + hi.x) / 2, (lo.y + hi.y) / 2
    inner = bpy.data.objects.new('i', None); sc.collection.objects.link(inner); inner.parent = holder
    for o, c in mp.items():
        if c.parent is holder: c.parent = inner
    inner.location = (-cx * k, -cy * k, -lo.z * k); inner.scale = (k, k, k)
    holder.location = (x, y, 0); holder.rotation_euler = (0, 0, math.radians(yaw_deg))
    return holder

x0, x1 = L['x']; y0, y1 = L['y']
box('ground', (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) + 160, (y1 - y0) + 160, -0.3, 0.0, 'snow')
for it in L['items']:
    x, y, w, h, m = it['x'], it['y'], it['w'], it['h'], it['model']
    if it['cat'] == 'road':
        box(it['id'], x, y, w, h, 0.0, 0.04, 'road')
    if m == 'site':
        # долгострой: бетонный каркас в два этажа, пожарная лестница
        for fl in (0.0, 3.4, 6.8):
            box('slab', x, y, w, h, fl, fl + 0.3, 'box')
        for ix in range(6):
            for iy in range(4):
                box('col', x - w / 2 + 1 + ix * (w - 2) / 5, y - h / 2 + 1 + iy * (h - 2) / 3, 0.5, 0.5, 0, 6.8, 'box')
        put('stair_steel', x + w / 2 + 2, y - 4, 0, None, 'stair', 0.5)
        continue
    if m == 'court':
        box('ice', x, y, w, h, 0.0, 0.06, 'ice')
        for bx, by, bw, bh in ((x, y - h / 2, w, 0.25), (x, y + h / 2, w, 0.25), (x - w / 2, y, 0.25, h), (x + w / 2, y, 0.25, h)):
            box('board', bx, by, bw, bh, 0.0, 1.25, 'board')
        box('carpet', x, y + 2, 1.6, h - 8, 0.06, 0.09, 'red')
        for mx, my in ((x - w / 2 - 1, y - h / 2 - 1), (x + w / 2 + 1, y - h / 2 - 1), (x - w / 2 - 1, y + h / 2 + 1), (x + w / 2 + 1, y + h / 2 + 1)):
            put('game:g67_floodlight_mast', mx, my, 0, 3.6, 'mast')
        continue
    if not m: continue
    src = model(m)
    if src is None:
        box(it['id'], x, y, w, h, 0, it['hgt'], 'box'); continue
    _, _, lo, hi = src
    sx, sy = hi.x - lo.x, hi.y - lo.y
    yaw = it['yaw']
    if not it.get('mark') and not m.startswith('game:'):
        # основание модели должно лечь в прямоугольник плана: 0/180 или 90/270
        base = 0 if abs(sx - w) + abs(sy - h) <= abs(sy - w) + abs(sx - h) else 90
        yaw = base + (180 if it['yaw'] in (180, -90) else 0)
    fit = None
    if m.startswith('game:'):
        fit = max(w, h) if not it.get('mark') else max(w, h) * 1.0
        if 'mast' in m: fit = None
    put(m, x, y, yaw, fit, it['id'])

# заборы, фонари и дальний план
BIG = (x1 - x0) > 200
fence = 'fence_rhombus' if BIG else 'fence_concrete'
step = 3.43 if BIG else 6.5
for i in range(int((x1 - x0 - 4) / step)):
    put(fence, x0 + 3 + i * step, y1 - 2.4, 90 if BIG else 0, None, 'fence_n')
for i in range(int((y1 - y0 - 6) / step)):
    put(fence, x0 + 2.4, y0 + 4 + i * step, 0 if BIG else 90, None, 'fence_w')
if BIG:
    for i, lx in enumerate(range(int(x0) + 12, int(x1) - 8, 26)):
        if abs(lx - 66) > 8: put('lamp_%d' % (1 + i % 2), lx, -29.4, 90, None, 'lamp', 2.4)
    for i, ly in enumerate(range(int(y0) + 14, int(y1) - 8, 26)):
        if abs(ly + 24) > 8: put('lamp_3', 60.6, ly, 0, None, 'lamp', 2.4)
far = 70 if BIG else 44
for mid, tx, ty, yw in (('tower_16_wide', -60, y1 + far, 0), ('tower_9_wide', 40, y1 + far - 8, 0), ('tower_16_slab', x0 - far, 60, 0), ('tower_9_slab', x0 - far + 6, -40, 0),
                        ('tower_9_wide', x1 + far, 70, 90), ('tower_16_slab', x1 + far - 10, -50, 0), ('tower_9_slab', -40, y0 - far, 90), ('tower_16_wide', 90, y0 - far - 10, 0)):
    put(mid, tx, ty, yw, None, 'skyline')


# ---------------------------------------------------------------- проработка большого района (только вариант C)
LAMPS = []
if BIG:
    import random
    rnd = random.Random(67)
    MATS['path'] = mat('path', (0.72, 0.74, 0.78)); MATS['banner'] = mat('banner', (0.75, 0.1, 0.08)); MATS['pipe'] = mat('pipe', (0.6, 0.58, 0.52))
    solid = [(it['x'], it['y'], it['w'], it['h']) for it in L['items'] if not it.get('mark') and it['cat'] in ('res', 'gar', 'road', 'boss') or it['id'] in ('SITE', 'PITCH')]
    def free(x, y, pad=2.5):
        for sx, sy, sw, sh_ in solid:
            if abs(x - sx) < sw / 2 + pad and abs(y - sy) < sh_ / 2 + pad: return False
        for pts in L.get('paths', []):
            for (ax, ay), (bx, by) in zip(pts, pts[1:]):
                dx, dy = bx - ax, by - ay; t = max(0, min(1, ((x - ax) * dx + (y - ay) * dy) / max(dx * dx + dy * dy, 1e-6)))
                if math.hypot(x - ax - dx * t, y - ay - dy * t) < 2.2: return False
        return x0 + 5 < x < x1 - 5 and y0 + 5 < y < y1 - 5
    def gput(mid, x, y, size, yaw=None, nm='d'):
        src = model('game:' + mid)
        if src is None: return None
        d = src[3] - src[2]
        return put('game:' + mid, x, y, rnd.uniform(0, 360) if yaw is None else yaw, None, nm, size / max(d.x, d.y, d.z, 1e-6))
    # тропы по маршрутам
    for pts in L.get('paths', []):
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            ln = math.hypot(bx - ax, by - ay)
            o = box('path', (ax + bx) / 2, (ay + by) / 2, ln + 1.2, 1.8, 0.0, 0.03, 'path'); o.rotation_euler = (0, 0, math.atan2(by - ay, bx - ax))
    # деревья и кусты по дворам
    for (ax, ay, bx, by, n, kinds) in ((-34, -104, 32, -62, 16, 'tpp'), (-122, -112, -70, -60, 18, 'tpp'), (74, -112, 128, -62, 16, 'tpp'), (82, 46, 144, 132, 20, 'tpp'),
                                       (-52, 0, 58, 44, 14, 'ut'), (-70, 92, -20, 100, 5, 'tp'), (-146, -140, 146, -132, 26, 'tp'), (-146, 96, -74, 104, 6, 't'), (76, -40, 146, -30, 6, 'tp')):
        k = 0; tries = 0
        while k < n and tries < n * 30:
            tries += 1; x, y = rnd.uniform(ax, bx), rnd.uniform(ay, by)
            if not free(x, y): continue
            c = rnd.choice(kinds); k += 1
            if c == 't': gput('racing/bare_tree', x, y, rnd.uniform(7, 10))
            elif c == 'b': gput('racing/birch_tree', x, y, rnd.uniform(8, 11))
            elif c == 'u': gput('racing/bush', x, y, rnd.uniform(1.2, 2.0))
            else: put('snow_pine_%d' % rnd.randint(1, 3), x, y, rnd.uniform(0, 360), None, 'pine')
            solid.append((x, y, 2.5, 2.5))
    # аллея берёз вдоль улицы Облачной и столбы вдоль Битной
    for x in range(-140, 56, 13):
        if free(x, -34.5, 1.0): gput('racing/bare_tree', x, -34.5, rnd.uniform(7, 9))
    for y in range(-130, 136, 40):
        if abs(y + 24) > 8: gput('racing/power_pole', 74.5, y, 8.5, 0)
    # машины у бордюра, во дворах и в ГСК
    cars = ['car_zhiguli_1', 'car_zhiguli_2', 'car_zhiguli_3', 'car_zhiguli_4', 'car_vaz_21099']
    for x in range(-136, 140, 17):
        if rnd.random() < 0.55 and abs(x - 66) > 10: put(rnd.choice(cars), x + rnd.uniform(-3, 3), -18.9, 90 + rnd.choice((0, 180)), None, 'car')
    for x, y, yw in ((-28, -106, 0), (-78, -108, 90), (-118, -62, 0), (30, -60, 90), (124, -104, 90), (96, 122, 0), (104, 116, 180), (112, 120, 0), (-74, 12, 0), (-74, 58, 180), (46, 86, 90), (-30, 86, 90)):
        put(rnd.choice(cars), x, y, yw, None, 'car')
    gput('racing/old_van', -52, -12, 5.2, 90); gput('racing/old_van', 78, 20, 5.2, 0); gput('racing/old_car', -112, 33, 4.3, 90); gput('racing/old_car', -90, 78, 4.3, 90)
    # лавки, урны, бельё, баки, шкафы у домов
    for it in L['items']:
        if it['cat'] == 'res' and not it.get('mark') and it['hgt'] < 25 and it['id'] != 'H3A':
            lx, ly = (it['x'], it['y'] - it['h'] / 2 - 2.0) if it['w'] > it['h'] else (it['x'] - it['w'] / 2 - 2.0, it['y'])
            if it['y'] < -90 or it['x'] > 120: lx, ly = (it['x'], it['y'] + it['h'] / 2 + 2.0) if it['w'] > it['h'] else (it['x'] - it['w'] / 2 - 2.0, it['y'])
            yw = 90 if it['w'] > it['h'] else 0
            put(rnd.choice(('bench_concrete', 'bench_siberian')), lx - 4, ly, yw if 'concrete' in 'x' else (0 if it['w'] > it['h'] else 90), None, 'bench')
            put('bench_siberian', lx + 5, ly, 0 if it['w'] > it['h'] else 90, None, 'bench')
            put('game:g67_urn', lx + 0.5, ly, 0, 0.7, 'urn')
    for x, y in ((-104, -96), (104, -100), (14, -76), (122, 80)):
        put('game:g67_laundry_lines', x, y, rnd.choice((0, 90)), 7.0, 'laundry')
    for x, y in ((-72, -112), (58, -70), (78, -66), (-58, -40), (90, 56), (140, 126), (-64, 96)):
        put('dumpster_blue', x, y, 0, None, 'dump'); put('dumpster_blue', x + 1.6, y, 0, None, 'dump'); gput('racing/trash_pile', x + 3.4, y + 0.6, 2.0)
    for x, y, yw in ((30, -64, 90), (-28, -44, 0), (76, -100, 90), (92, 64, 90), (-66, 2, 0)):
        put(rnd.choice(('elbox_green', 'elbox_rusty_pair')), x, y, yw, None, 'elbox')
    # сугробы вдоль дорог
    for x in range(-140, 144, 12):
        if rnd.random() < 0.6 and abs(x - 66) > 8: put('game:g67_snowdrift', x, rnd.choice((-17.2, -30.8)), rnd.uniform(0, 360), rnd.uniform(3, 5), 'drift')
    for y in range(-136, 138, 12):
        if rnd.random() < 0.5 and abs(y + 24) > 8: put('game:g67_snowdrift', rnd.choice((59.2, 72.8)), y, rnd.uniform(0, 360), rnd.uniform(3, 5), 'drift')
    # заборы: стройка, южная и западная стороны ГСК
    def fence_line(ax, ay, bx, by, gap=None):
        ln = math.hypot(bx - ax, by - ay); n = int(ln / 3.43); yw = math.degrees(math.atan2(by - ay, bx - ax)) + 90
        for i in range(n):
            t = (i + 0.5) / n
            if gap and gap[0] < t < gap[1]: continue
            put('fence_rhombus', ax + (bx - ax) * t, ay + (by - ay) * t, yw, None, 'fence')
    fence_line(-41, 8, -3, 8, (0.35, 0.55)); fence_line(-41, 36, -3, 36); fence_line(-41, 8, -41, 36); fence_line(-3, 8, -3, 36, (0.4, 0.62))
    fence_line(-142, -3, -78, -3); fence_line(-143, -3, -143, 92)
    # теплотрасса на опорах с П-образным переходом, растяжка турнира между башнями
    for x in range(-48, 46, 3):
        if abs(x - 8) < 4: continue
        o = box('pipe', x + 1.5, 48, 3.1, 0.9, 1.0, 1.9, 'pipe')
        if x % 9 == 0: box('leg', x, 48, 0.3, 1.2, 0, 1.0, 'box')
    for sx in (4, 12): box('pipe', sx, 48, 0.9, 0.9, 1.0, 4.6, 'pipe')
    box('pipe', 8, 48, 8.9, 0.9, 3.8, 4.7, 'pipe')
    box('banner', 6, 70, 26.4, 0.12, 11.0, 12.8, 'banner')
    # мелочь: шины у шиномонтажа, бочки и хлам в гаражах, рекламный щит, дворовые фонари
    for i in range(4): gput('racing/tire_stack', 90 + i * 1.1, -13.5 + (i % 2) * 0.5, 1.2)
    for i in range(14):
        x, y = rnd.uniform(-138, -76), rnd.choice((6.5, 15.5, 29, 38, 51.5, 60.5, 74, 83))
        gput(rnd.choice(('racing/barrel', 'racing/tire_stack', 'racing/trash_pile')), x, y, rnd.uniform(1.0, 1.8))
    gput('racing/billboard', 78, -36, 9.0, 200)
    for x, y in ((0, -100), (-20, -78), (26, -70), (-96, -104), (-108, -66), (104, -104), (120, -72), (116, 104), (96, 96), (-10, 14), (36, 30), (-46, 100), (20, 100), (-30, 60), (40, 60)):
        if free(x, y, 0.5): put('lamp_5', x, y, rnd.uniform(0, 360), None, 'ylamp', 2.0); LAMPS.append((x, y, 6.2))
    for lx in range(int(x0) + 12, int(x1) - 8, 26): LAMPS.append((lx, -27.5, 8.0))
    for ly in range(int(y0) + 14, int(y1) - 8, 26): LAMPS.append((62.5, ly, 8.0))
    for c in ((-7, 100), (19, 100), (-7, 124), (19, 124)): LAMPS.append((c[0], c[1], 11.0))

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, 'blender_source', 'dvor_blockout%s.blend' % ('_c' if (x1 - x0) > 200 else '')))

def view(nm, pos, look, lens=28, res=(1600, 900), ortho=None):
    cam.location = pos
    d = Vector(look) - Vector(pos)
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    cam.data.type = 'ORTHO' if ortho else 'PERSP'
    if ortho: cam.data.ortho_scale = ortho
    cam.data.lens = lens; cam.data.clip_start = 0.3; cam.data.clip_end = 2500
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.filepath = os.path.join(ROOT, 'previews', 'blockout_' + nm + '.png')
    bpy.ops.render.render(write_still=True); print('VIEW', nm, flush=True)

cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
P = 'c_' if BIG else ''
sh.show_shadows = False
view(P + '01_top', (cx, cy, 500), (cx, cy + 0.001, 0), res=(1500, 1500), ortho=(y1 - y0) + 14)
sh.show_shadows = True
if BIG:
    view('c_02_aerial_south', (cx - 30, y0 - 150, 170), (cx, cy - 10, 0), lens=30)
    view('c_03_aerial_northeast', (x1 + 110, y1 + 90, 130), (cx + 10, cy + 20, 0), lens=30)
    view('c_04_aerial_west', (x0 - 120, cy + 20, 110), (cx - 30, cy + 20, 4), lens=30)
    view('c_05_from_home_door', (-6, -107.5, 1.9), (10, -60, 7), lens=22)
    view('c_06_arch_to_street', (14, -40, 1.8), (10, 60, 12), lens=22)
    view('c_07_market', (-60, -17, 1.8), (10, -9, 3), lens=22)
    view('c_08_crossroads_mcqueen', (74, -19, 1.8), (92, -8, 1.5), lens=22)
    view('c_09_wasteland_to_towers', (10, 6, 1.8), (6, 80, 14), lens=22)
    view('c_10_gsk_lane', (-72, 33, 1.8), (-140, 34, 1.5), lens=22)
    view('c_11_court_from_gate', (6, 96, 2.0), (6, 122, 2.5), lens=20)
    view('c_12_boiler_stadium', (-64, 100, 1.8), (-100, 120, 14), lens=22)
    view('c_13_brick_yard', (-70, -86, 1.8), (-110, -100, 6), lens=22)
    view('c_14_panel_yard', (80, 96, 1.8), (124, 90, 10), lens=22)
else:
    view('02_aerial_south', (cx - 20, y0 - 75, 85), (cx, cy + 5, 0), lens=32)
    view('03_aerial_northeast', (x1 + 60, y1 + 50, 70), (cx, cy, 0), lens=32)
    view('04_aerial_west', (x0 - 70, cy - 10, 60), (cx, cy + 5, 4), lens=32)
    view('05_from_home_door', (-6, -29.5, 1.9), (8, 20, 6), lens=22)
    view('06_courtyard_to_arch', (6, 2, 1.8), (16, 27, 5), lens=24)
    view('07_garage_lane', (-31, -29, 1.8), (-33, 6, 2.2), lens=22)
    view('08_back_lane_to_court', (-22, 40, 1.8), (16, 52, 3), lens=22)
    view('09_kiosk_corner', (12, -29, 1.8), (30, -42, 2.5), lens=22)
    view('10_court_from_gate', (16, 42, 2.0), (16, 64, 2.5), lens=20)
    view('11_nook', (-30, 20, 1.8), (-44, 30, 2), lens=22)
if BIG:
    # вечерние кадры: синие сумерки, тёплые фонари
    try:
        sc.render.engine = 'BLENDER_EEVEE'
        sc.world.use_nodes = True
        bg = sc.world.node_tree.nodes.get('Background')
        if bg: bg.inputs[0].default_value = (0.02, 0.045, 0.13, 1); bg.inputs[1].default_value = 1.0
        sun = bpy.data.objects.new('moon', bpy.data.lights.new('moon', 'SUN')); sc.collection.objects.link(sun)
        sun.data.energy = 0.55; sun.data.color = (0.55, 0.68, 1.0); sun.rotation_euler = (math.radians(58), 0, math.radians(35))
        for i, (lx, ly, lz) in enumerate(LAMPS):
            li = bpy.data.objects.new('l%d' % i, bpy.data.lights.new('l%d' % i, 'POINT')); sc.collection.objects.link(li)
            li.location = (lx, ly, lz); li.data.energy = 5200 if lz > 10 else 2600; li.data.color = (1.0, 0.95, 0.9) if lz > 10 else (1.0, 0.62, 0.3)
            li.data.shadow_soft_size = 0.4; li.data.use_shadow = i % 3 == 0
        sc.view_settings.exposure = 0.6
        view('c_e1_street_dusk', (-30, -19, 1.8), (50, -14, 3), lens=24, res=(1600, 900))
        view('c_e2_home_yard_dusk', (-6, -107.5, 1.9), (10, -60, 7), lens=22, res=(1600, 900))
        view('c_e3_towers_gate_dusk', (8, 22, 1.8), (6, 80, 14), lens=24, res=(1600, 900))
        view('c_e4_mcqueen_dusk', (80, -20, 1.6), (93, -10, 1.2), lens=28, res=(1600, 900))
        view('c_e5_gsk_dusk', (-72, 56, 1.8), (-140, 57, 1.5), lens=22, res=(1600, 900))
        view('c_e6_aerial_dusk', (cx - 30, y0 - 150, 170), (cx, cy - 10, 0), lens=30, res=(1600, 900))
    except Exception as e:
        print('EVENING FAILED', e)
print('DONE')
