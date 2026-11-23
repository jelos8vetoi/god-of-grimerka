"""ДВОР, редизайн V3: сцена «МИКРОРАЙОН 67» только из принятых по стилю моделей, с зимой и вечерним светом.
blender --background --python tools/blender/dvor_scene_v3.py
Читает topdown_layout/DVOR_TOPDOWN_RECOMMENDED.layout.json, пишет blender_source/dvor_scene_v3.blend и previews/v3_*.png."""
import os, sys, math, random
_src = open(os.path.join(os.path.dirname(__file__), 'dvor_blockout.py'), encoding='utf-8').read()
exec(_src.split("x0, x1 = L['x']; y0, y1 = L['y']")[0])
x0, x1 = L['x']; y0, y1 = L['y']
rnd = random.Random(67)
OWN = set(bpy.data.materials)          # свои материалы земли — снег на них не накладывается

def gmat(nm, col, rough=0.9):
    m = mat(nm, col)
    b = m.node_tree.nodes.get('Principled BSDF')
    if b: b.inputs['Roughness'].default_value = rough
    return m
MATS.update({'snow': gmat('snow_g', (0.80, 0.84, 0.92)), 'road': gmat('asphalt', (0.07, 0.075, 0.085), 0.55), 'walk': gmat('walk', (0.50, 0.53, 0.58)),
             'slush': gmat('slush', (0.30, 0.29, 0.28), 0.6), 'path': gmat('trod', (0.62, 0.66, 0.74)), 'lot': gmat('lot', (0.12, 0.125, 0.14), 0.6)})
OWN = set(bpy.data.materials)

box('ground', (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) + 400, (y1 - y0) + 400, -0.3, 0.0, 'snow')
solid = []
for it in L['items']:
    x, y, w, h, m, c = it['x'], it['y'], it['w'], it['h'], it['model'], it['cat']
    if c == 'road' and not it.get('mark'):
        street = it['id'].startswith('ROAD')
        box(it['id'], x, y, w, h, 0.0, 0.05, 'road' if street else 'lot')
        if street:      # слякоть у бордюров и накат посередине
            if w > h:
                for s in (-1, 1): box('slush', x, y + s * (h / 2 - 0.5), w, 1.0, 0.05, 0.07, 'slush')
            else:
                for s in (-1, 1): box('slush', x + s * (w / 2 - 0.5), y, 1.0, h, 0.05, 0.07, 'slush')
        solid.append((x, y, w, h)); continue
    if c == 'walk':
        box(it['id'], x, y, w, h, 0.0, 0.035, 'walk'); continue
    if not m: continue
    src = model(m)
    if src is None: print('NO MODEL', m); continue
    _, _, lo, hi = src
    sx, sy = hi.x - lo.x, hi.y - lo.y
    yaw = it['yaw']
    if not it.get('mark') and not m.startswith('game:'):
        base = 0 if abs(sx - w) + abs(sy - h) <= abs(sy - w) + abs(sx - h) else 90
        yaw = base + (180 if it['yaw'] in (180, -90) else 0)
    put(m, x, y, yaw, max(w, h) if m.startswith('game:') else None, it['id'])
    solid.append((x, y, w, h))
for mx, my in ((-12, 100), (24, 100), (-12, 124), (24, 124)):
    put('game:g67_floodlight_mast', mx, my, 0, 3.6, 'mast')

def free(x, y, pad=2.5):
    for sx, sy, sw, sh_ in solid:
        if abs(x - sx) < sw / 2 + pad and abs(y - sy) < sh_ / 2 + pad: return False
    for pts in L.get('paths', []):
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            dx, dy = bx - ax, by - ay; t = max(0, min(1, ((x - ax) * dx + (y - ay) * dy) / max(dx * dx + dy * dy, 1e-6)))
            if math.hypot(x - ax - dx * t, y - ay - dy * t) < 2.2: return False
    return x0 + 5 < x < x1 - 5 and y0 + 5 < y < y1 - 5

# места камер держим свободными от деревьев и сугробов
for cxy in ((-58, -20.5), (-22, -104), (-72, 34), (-52, -17.5), (-34, 92), (10, 30), (40, -31), (78, -21), (-74, -78), (-30, 4), (92, 96), (82, -68)):
    solid.append((cxy[0], cxy[1], 14, 14))
# ---------------- тропы: утоптанный снег по маршрутам и к подъездам
for pts in L.get('paths', []):
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        ln = math.hypot(bx - ax, by - ay)
        o = box('trod', (ax + bx) / 2, (ay + by) / 2, ln + 1.0, 1.6, 0.0, 0.025, 'path'); o.rotation_euler = (0, 0, math.atan2(by - ay, bx - ax))
# ---------------- деревья: сухие деревья и редкие ели
TREES = ['tree_dead_1', 'tree_dead_3', 'tree_dead_5', 'tree_dead_1', 'tree_dead_3']
def tree(x, y):
    put(rnd.choice(TREES), x, y, rnd.uniform(0, 360), None, 'tree', rnd.uniform(0.85, 1.25)); solid.append((x, y, 2.5, 2.5))
for (ax, ay, bx, by, n, pines) in ((-34, -104, 32, -62, 14, 3), (-124, -110, -70, -62, 16, 3), (74, -112, 128, -62, 14, 3), (82, 44, 144, 132, 18, 4),
                                   (-46, 8, 40, 44, 16, 0), (-146, -140, 146, -132, 22, 6), (-146, 96, -74, 104, 6, 0), (76, -40, 146, -30, 5, 0), (-72, 92, -24, 102, 4, 0)):
    k = 0; tries = 0
    while k < n and tries < n * 30:
        tries += 1; x, y = rnd.uniform(ax, bx), rnd.uniform(ay, by)
        if not free(x, y): continue
        k += 1
        if k <= pines: put('snow_pine_%d' % rnd.randint(1, 3), x, y, rnd.uniform(0, 360), None, 'pine'); solid.append((x, y, 2.5, 2.5))
        else: tree(x, y)
for x in range(-140, 56, 13):
    if free(x, -34.5, 1.0): tree(x, -34.5)
for y in range(-128, 136, 14):
    if abs(y + 24) > 10 and free(77, y, 1.0): tree(77, y)
# ---------------- машины
cars = ['car_zhiguli_1', 'car_zhiguli_2', 'car_zhiguli_3', 'car_zhiguli_4', 'car_vaz_21099']
for x in range(-136, 140, 17):
    if rnd.random() < 0.5 and abs(x - 66) > 12 and not (26 < x < 58): put(rnd.choice(cars), x + rnd.uniform(-3, 3), -21.0, 90 + rnd.choice((0, 180)), None, 'car')
for x, y, yw in ((-28, -106, 0), (-78, -108, 90), (-118, -62, 0), (30, -60, 90), (124, -104, 90), (96, 122, 0), (104, 116, 180), (112, 120, 0), (-74, 12, 0), (-74, 58, 180), (46, 88, 90), (-30, 88, 90), (118, 30, 90)):
    put(rnd.choice(cars), x, y, yw, None, 'car')
put('van_uaz452', -66, 30, 0, None, 'uaz'); put('van_uaz452', 100, 30, 90, None, 'uaz')
# ---------------- у подъездов: лавка, урна, фонарь; санки и клумбы
ENTR = []
for it in L['items']:
    if it['cat'] == 'res' and not it.get('mark'):
        wide = it['w'] > it['h']
        south = it['y'] > -90 if wide else None
        for t in (-0.25, 0.25):
            if wide: ex, ey = it['x'] + it['w'] * t, it['y'] + (-(it['h'] / 2 + 2.2) if south else (it['h'] / 2 + 2.2))
            else: ex, ey = it['x'] + (-(it['w'] / 2 + 2.2) if it['x'] > 0 else (it['w'] / 2 + 2.2)), it['y'] + it['h'] * t
            ENTR.append((ex, ey))
            put(rnd.choice(('bench_ussr', 'bench_siberian', 'bench_concrete')), ex + (2.2 if wide else 0), ey + (0 if wide else 2.2), 0 if wide else 90, None, 'bench')
            put('urn_red', ex + (3.8 if wide else 0), ey + (0 if wide else 3.8), 0, None, 'urn')
for i, (ex, ey) in enumerate(ENTR):
    if i % 5 == 0: put('sled', ex - 1.5, ey + 0.6, rnd.uniform(0, 360), None, 'sled')
    if i % 3 == 0: put('flowerbed', ex - 4.0, ey, 0, None, 'bed')
# ---------------- баки, шкафы, сугробы
for x, y in ((-72, -112), (58, -70), (78, -66), (-58, -40), (90, 56), (140, 126), (-64, 96), (26, -66)):
    put('dumpster_blue', x, y, 0, None, 'dump'); put('dumpster_blue', x + 1.6, y, 0, None, 'dump'); put('snow_pile', x + 4.2, y + 0.5, rnd.uniform(0, 360), None, 'pile', 0.7)
for x, y, yw in ((30, -64, 90), (-28, -40, 0), (76, -100, 90), (92, 64, 90), (-66, 2, 0), (56, -12, 90)):
    put(rnd.choice(('elbox_green', 'elbox_rusty_pair')), x, y, yw, None, 'elbox')
for x in range(-142, 146, 9):
    if rnd.random() < 0.7 and abs(x - 66) > 9:
        put('snow_pile', x, rnd.choice((-16.2, -31.8)), rnd.uniform(0, 360), None, 'pile', rnd.uniform(0.8, 1.6))
for y in range(-138, 140, 9):
    if rnd.random() < 0.6 and abs(y + 24) > 9:
        put('snow_pile', rnd.choice((58.2, 73.8)), y, rnd.uniform(0, 360), None, 'pile', rnd.uniform(0.8, 1.6))
for it in L['items']:
    if it['id'].startswith(('PARK', 'LANE')):
        for k in range(max(2, int(max(it['w'], it['h']) / 14))):
            px = it['x'] + rnd.choice((-1, 1)) * (it['w'] / 2 + 1.2) if it['w'] < it['h'] else it['x'] + rnd.uniform(-it['w'] / 2, it['w'] / 2)
            py = it['y'] + rnd.uniform(-it['h'] / 2, it['h'] / 2) if it['w'] < it['h'] else it['y'] + rnd.choice((-1, 1)) * (it['h'] / 2 + 1.2)
            if free(px, py, 0.3): put('snow_pile', px, py, rnd.uniform(0, 360), None, 'pile', rnd.uniform(0.9, 1.9))
# ---------------- заборы, фонари
def fence_line(ax, ay, bx, by):
    ln = math.hypot(bx - ax, by - ay); n = int(ln / 3.43); yw = math.degrees(math.atan2(by - ay, bx - ax)) + 90
    for i in range(n):
        t = (i + 0.5) / n; put('fence_rhombus', ax + (bx - ax) * t, ay + (by - ay) * t, yw, None, 'fence')
fence_line(x0 + 3, y1 - 2.4, x1 - 3, y1 - 2.4); fence_line(x0 + 2.4, y0 + 4, x0 + 2.4, y1 - 4); fence_line(x1 - 2.4, y0 + 4, x1 - 2.4, y1 - 4)
fence_line(-142, -3, -78, -3)
LAMPS = []
for i, lx in enumerate(range(int(x0) + 12, int(x1) - 8, 26)):
    if abs(lx - 66) > 8: put('lamp_%d' % (1 + i % 2), lx, -30.6, 90, None, 'lamp', 2.4); LAMPS.append((lx, -28.6, 8.0, 'street'))
for ly in range(int(y0) + 14, int(y1) - 8, 26):
    if abs(ly + 24) > 8: put('lamp_3', 59.4, ly, 0, None, 'lamp', 2.4); LAMPS.append((61.6, ly, 8.0, 'street'))
for x, y in ((0, -100), (-20, -78), (26, -74), (-96, -104), (-110, -66), (104, -104), (120, -72), (116, 104), (96, 96), (-10, 14), (36, 30), (-46, 100), (20, 100), (-30, 60), (40, 60), (-70, 34), (-70, 78), (112, 34)):
    if free(x, y, 0.5): put('lamp_5', x, y, rnd.uniform(0, 360), None, 'ylamp', 2.0); LAMPS.append((x, y, 6.2, 'yard'))
for ex, ey in ENTR: LAMPS.append((ex, ey, 2.6, 'door'))
for x in (-44, -36, -30, -20, -12, -6, 0, 44): LAMPS.append((x, -12.5, 2.6, 'shop'))
LAMPS += [(84, -13, 3.0, 'shop'), (96, -62, 3.0, 'shop'), (-60, 36, 2.4, 'shop'), (-56, 14, 3.0, 'shop')]
for c in ((-12, 100), (24, 100), (-12, 124), (24, 124)): LAMPS.append((c[0], c[1], 11.0, 'rink'))
# ---------------- горизонт
for mid, tx, ty, yw in (('tower_16_wide', -40, y1 + 80, 0), ('tower_9_wide', 60, y1 + 70, 0), ('tower_16_slab', x0 - 80, 60, 0), ('tower_9_slab', x0 - 70, -40, 0),
                        ('tower_9_wide', x1 + 80, 70, 90), ('tower_16_slab', x1 + 70, -50, 0), ('tower_9_slab', -40, y0 - 80, 90), ('tower_16_wide', 90, y0 - 90, 0), ('smoke_stacks', -110, y1 + 30, 0)):
    put(mid, tx, ty, yw, None, 'skyline')

# ---------------- снег на всех моделях: белим грани, смотрящие вверх
for m in bpy.data.materials:
    if m in OWN or not m.use_nodes: continue
    nt = m.node_tree; b = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if b is None: continue
    inp = b.inputs['Base Color']
    geo = nt.nodes.new('ShaderNodeNewGeometry'); sep = nt.nodes.new('ShaderNodeSeparateXYZ'); mr = nt.nodes.new('ShaderNodeMapRange'); mix = nt.nodes.new('ShaderNodeMixRGB')
    nt.links.new(geo.outputs['Normal'], sep.inputs[0]); nt.links.new(sep.outputs['Z'], mr.inputs['Value'])
    mr.inputs['From Min'].default_value = 0.72; mr.inputs['From Max'].default_value = 0.93; mr.clamp = True
    if inp.links: nt.links.new(inp.links[0].from_socket, mix.inputs['Color1'])
    else: mix.inputs['Color1'].default_value = inp.default_value
    mix.inputs['Color2'].default_value = (0.86, 0.9, 0.97, 1); nt.links.new(mr.outputs['Result'], mix.inputs['Fac'])
    nt.links.new(mix.outputs['Color'], inp)

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, 'blender_source', 'dvor_scene_v3.blend'))

# ---------------- свет и кадры
sc.render.engine = 'BLENDER_EEVEE'
sc.world.use_nodes = True
bg = sc.world.node_tree.nodes.get('Background')
sun = bpy.data.objects.new('sky', bpy.data.lights.new('sky', 'SUN')); sc.collection.objects.link(sun)
LIGHTS = []
for i, (lx, ly, lz, kind) in enumerate(LAMPS):
    li = bpy.data.objects.new('l%d' % i, bpy.data.lights.new('l%d' % i, 'POINT')); sc.collection.objects.link(li)
    li.location = (lx, ly, lz); li.data.shadow_soft_size = 0.3; li.data.use_shadow = kind in ('street', 'rink') and i % 2 == 0
    li['kind'] = kind; LIGHTS.append(li)
PW = {'street': 2600, 'yard': 1500, 'door': 220, 'shop': 420, 'rink': 6500}
COL = {'street': (1.0, 0.66, 0.34), 'yard': (1.0, 0.7, 0.4), 'door': (1.0, 0.78, 0.5), 'shop': (1.0, 0.86, 0.66), 'rink': (0.92, 0.96, 1.0)}
def mood(nm):
    k = {'dusk': (0.03, 0.06, 0.16, 1.0, 0.9, 1.0), 'night': (0.006, 0.012, 0.04, 0.35, 0.5, 1.5), 'day': (0.55, 0.6, 0.68, 2.6, 1.2, 0.0)}[nm]
    bg.inputs[0].default_value = (k[0], k[1], k[2], 1); bg.inputs[1].default_value = 1.0
    sun.data.energy = k[3]; sun.data.color = (0.6, 0.72, 1.0) if nm != 'day' else (0.95, 0.96, 1.0)
    sun.rotation_euler = (math.radians(62), 0, math.radians(40)); sun.data.angle = math.radians(20)
    sc.view_settings.exposure = k[4] - 0.6
    for li in LIGHTS:
        li.data.energy = PW[li['kind']] * k[5]; li.data.color = COL[li['kind']]

def view(nm, pos, look, lens=28, res=(1920, 1080), ortho=None):
    cam.location = pos
    d = Vector(look) - Vector(pos)
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    cam.data.type = 'ORTHO' if ortho else 'PERSP'
    if ortho: cam.data.ortho_scale = ortho
    cam.data.lens = lens; cam.data.clip_start = 0.3; cam.data.clip_end = 3000
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.filepath = os.path.join(ROOT, 'previews', 'v3_' + nm + '.png')
    bpy.ops.render.render(write_still=True); print('VIEW', nm, flush=True)

cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
mood('dusk')
view('01_main_street', (-58, -20.5, 1.9), (40, -16, 4), lens=26)
view('02_home_yard', (-22, -104, 2.0), (16, -72, 5), lens=24)
view('03_garages', (-72, 34, 1.9), (-140, 34.5, 1.6), lens=24)
view('04_market', (-52, -17.5, 1.8), (-10, -9, 2.4), lens=26)
view('05_hockey_rink', (-34, 92, 6.5), (10, 114, 1.0), lens=24)
view('06_aerial', (cx - 30, y0 - 150, 170), (cx, cy - 10, 0), lens=30)
view('07_towers_gate', (10, 30, 1.9), (6, 80, 13), lens=24)
view('08_bus_stop', (40, -31, 1.9), (52, -15, 2.2), lens=26)
view('09_crossroads_mcqueen', (78, -21, 1.7), (93, -9, 1.3), lens=28)
view('10_brick_yard', (-74, -78, 1.9), (-110, -112, 7), lens=24)
view('11_wasteland', (-30, 4, 1.9), (0, 60, 10), lens=24)
view('12_panel_yard', (92, 96, 1.9), (128, 90, 10), lens=24)
view('13_shop', (82, -68, 1.9), (96, -52, 3.5), lens=26)
mood('night')
view('L_night_main_street', (-58, -20.5, 1.9), (40, -16, 4), lens=26, res=(1280, 720))
view('L_night_home_yard', (-22, -104, 2.0), (16, -72, 5), lens=24, res=(1280, 720))
mood('day')
view('L_day_main_street', (-58, -20.5, 1.9), (40, -16, 4), lens=26, res=(1280, 720))
view('L_day_home_yard', (-22, -104, 2.0), (16, -72, 5), lens=24, res=(1280, 720))
view('00_top', (cx, cy, 600), (cx, cy + 0.001, 0), res=(1500, 1500), ortho=(y1 - y0) + 14)
print('DONE')
