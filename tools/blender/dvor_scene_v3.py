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
             'slush': gmat('slush', (0.30, 0.29, 0.28), 0.6), 'path': gmat('trod', (0.62, 0.66, 0.74)), 'lot': gmat('lot', (0.12, 0.125, 0.14), 0.6),
             'ice': gmat('ice', (0.50, 0.62, 0.74), 0.12), 'rut': gmat('rut', (0.035, 0.038, 0.045), 0.3), 'pack': gmat('pack', (0.42, 0.44, 0.48), 0.7),
             'signbg': gmat('signbg', (0.05, 0.03, 0.03), 0.6)})
OWN = set(bpy.data.materials)
GLOW_IDS = set(); COURT = None
for nm_, sc1, st in (('snow', 0.5, 0.35), ('path', 1.4, 0.5), ('pack', 2.0, 0.4), ('slush', 1.6, 0.6)):
    m_ = MATS[nm_]; nt_ = m_.node_tree; b_ = nt_.nodes['Principled BSDF']
    g_ = nt_.nodes.new('ShaderNodeNewGeometry'); n1 = nt_.nodes.new('ShaderNodeTexNoise'); n1.inputs['Scale'].default_value = sc1; n1.inputs['Detail'].default_value = 6
    nt_.links.new(g_.outputs['Position'], n1.inputs['Vector'])
    bp = nt_.nodes.new('ShaderNodeBump'); bp.inputs['Strength'].default_value = st; bp.inputs['Distance'].default_value = 0.25
    nt_.links.new(n1.outputs['Fac'], bp.inputs['Height']); nt_.links.new(bp.outputs['Normal'], b_.inputs['Normal'])
    n2 = nt_.nodes.new('ShaderNodeTexNoise'); n2.inputs['Scale'].default_value = 0.06; nt_.links.new(g_.outputs['Position'], n2.inputs['Vector'])
    mx_ = nt_.nodes.new('ShaderNodeMixRGB'); c_ = b_.inputs['Base Color'].default_value
    mx_.inputs['Color1'].default_value = (c_[0] * 0.82, c_[1] * 0.84, c_[2] * 0.88, 1); mx_.inputs['Color2'].default_value = (min(1, c_[0] * 1.08), min(1, c_[1] * 1.08), min(1, c_[2] * 1.06), 1)
    nt_.links.new(n2.outputs['Fac'], mx_.inputs['Fac']); nt_.links.new(mx_.outputs['Color'], b_.inputs['Base Color'])

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
                box('pack', x, y, w, 0.9, 0.05, 0.062, 'pack')
                for s in (-2.6, -1.2, 1.2, 2.6): box('rut', x, y + s, w, 0.42, 0.05, 0.058, 'rut')
            else:
                for s in (-1, 1): box('slush', x + s * (w / 2 - 0.5), y, 1.0, h, 0.05, 0.07, 'slush')
                box('pack', x, y, 0.9, h, 0.05, 0.062, 'pack')
                for s in (-2.6, -1.2, 1.2, 2.6): box('rut', x + s, y, 0.42, h, 0.05, 0.058, 'rut')
        else:           # дворовые проезды: накатанный снег и наледь
            for k in range(max(1, int(w * h / 160))):
                o = box('ice', x + rnd.uniform(-w / 2 + 1.5, w / 2 - 1.5), y + rnd.uniform(-h / 2 + 1.5, h / 2 - 1.5), rnd.uniform(1.6, 3.6), rnd.uniform(1.0, 2.2), 0.05, 0.056, 'ice')
                o.rotation_euler = (0, 0, rnd.uniform(0, 3.14))
        solid.append((x, y, w, h)); continue
    if c == 'walk':
        box(it['id'], x, y, w, h, 0.0, 0.035, 'walk'); continue
    if it['id'] == 'COURT':      # каноничная коробка Миши 26 × 22,5 м: борта и калитка из игры, лёд
        bx0, bx1, by0, by1 = x - w / 2, x + w / 2, y - h / 2, y + h / 2
        box('court_ice', x, y, w, h, 0.0, 0.04, 'ice')
        KB = (h / 5) / max(model('game:g67_court_board')[3].y - model('game:g67_court_board')[2].y, 1e-6)
        def board(xc, yc, yw, ln):      # один масштаб на все секции, длина — растяжением вдоль борта с нахлёстом: щелей нет
            hb = put('game:g67_court_board', xc, yc, yw, None, 'board', KB)
            hb.scale = (1, ln * 1.035 / (h / 5), 1)
        GW = 4.4
        for i in range(6):
            seg = w / 6; board(bx0 + (i + 0.5) * seg, by1, 90, seg)
        for i in range(5):
            seg = h / 5; board(bx0, by0 + (i + 0.5) * seg, 0, seg); board(bx1, by0 + (i + 0.5) * seg, 180, seg)
        for sgn in (-1, 1):             # южный борт: по три секции слева и справа вплотную к калитке
            run = w / 2 - GW / 2 + 0.55; seg = run / 3      # борт заходит под стойку калитки
            for i in range(3): board(x + sgn * (GW / 2 - 0.55 + (i + 0.5) * seg), by0, -90, seg)
        gsrc = model('game:g67_court_gate')
        if gsrc and not gsrc[0].get('opened'):      # створку калитки открываем внутрь коробки (в игре она должна открываться)
            import bmesh
            from mathutils import Matrix
            for o in gsrc[1]:
                if o.type != 'MESH': continue
                bm = bmesh.new(); bm.from_mesh(o.data)
                xs = [v.co.x for v in bm.verts]; ys = [v.co.y for v in bm.verts]; zs = [v.co.z for v in bm.verts]
                cx_, hw = (min(xs) + max(xs)) / 2, (max(xs) - min(xs)) / 2; cy_, hd = (min(ys) + max(ys)) / 2, (max(ys) - min(ys)) / 2; z0_, zh = min(zs), max(zs) - min(zs)
                seen = set(); leaf = []
                for v in bm.verts:
                    if v.index in seen: continue
                    st = [v]; isl = []
                    while st:
                        q = st.pop()
                        if q.index in seen: continue
                        seen.add(q.index); isl.append(q)
                        for e in q.link_edges: st.append(e.other_vert(q))
                    if all(abs((q.co.x - cx_) / hw) < 0.345 and 0.055 < (q.co.z - z0_) / zh < 0.69 for q in isl): leaf += isl
                piv = (cx_ - 0.31 * hw, cy_ - 0.59 * hd, 0)
                bmesh.ops.rotate(bm, verts=leaf, cent=piv, matrix=Matrix.Rotation(math.radians(105), 3, 'Z'))
                bm.to_mesh(o.data); bm.free(); print('GATE LEAF', len(leaf))
            gsrc[0]['opened'] = 1
        put('game:g67_court_gate', x, by0, 0, GW, 'gate')
        COURT = (bx0, bx1, by0, by1); solid.append((x, y, w + 4, h + 4)); continue
    if not m: continue
    if c == 'res' or m in ('school', 'shop_house'): GLOW_IDS.add(m)
    src = model(m)
    if src is None: print('NO MODEL', m); continue
    _, _, lo, hi = src
    sx, sy = hi.x - lo.x, hi.y - lo.y
    yaw = it['yaw']
    if not it.get('mark') and not m.startswith('game:'):
        base = 0 if abs(sx - w) + abs(sy - h) <= abs(sy - w) + abs(sx - h) else 90
        yaw = base + (180 if it['yaw'] in (180, -90) else 0)
    h_ = put(m, x, y, yaw, max(w, h) if m.startswith('game:') else None, it['id'])
    if it['id'] == 'SHAWA' and h_: h_.rotation_euler.z += math.radians(90)
    solid.append((x, y, w, h))
MASTS = [(COURT[0] - 1.2, COURT[2] - 1.2), (COURT[1] + 1.2, COURT[2] - 1.2), (COURT[0] - 1.2, COURT[3] + 1.2), (COURT[1] + 1.2, COURT[3] + 1.2)]
for mx, my in MASTS:
    put('game:g67_floodlight_mast', mx, my, 0, 3.6, 'mast')
# вывеска «ШАУРМА 67» на принятом ларьке 90-х: световой короб над окном выдачи
FONT = bpy.data.fonts.load('C:/Windows/Fonts/impact.ttf')
def sign_text(txt, x, y, z, size, col, power, face=-1):
    cu = bpy.data.curves.new('txt', 'FONT'); cu.body = txt; cu.font = FONT; cu.size = size; cu.align_x = 'CENTER'; cu.align_y = 'CENTER'; cu.extrude = 0.02
    o = bpy.data.objects.new('sign_' + txt, cu); sc.collection.objects.link(o)
    o.location = (x, y, z); o.rotation_euler = (math.radians(90), 0, 0 if face < 0 else math.radians(180))
    m = bpy.data.materials.new('sg_' + txt); m.use_nodes = True; b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*col, 1); b.inputs['Emission Color'].default_value = (*col, 1); b.inputs['Emission Strength'].default_value = power
    cu.materials.append(m); OWN.add(m); return o
for it in L['items']:
    if it['id'] == 'SHAWA':
        fy = it['y'] - it['h'] / 2 - 0.12
        o = box('shawa_board', it['x'], fy, 4.6, 0.12, 3.25, 4.25, 'signbg')
        sign_text('ШАУРМА 67', it['x'], fy - 0.08, 3.78, 0.70, (1.0, 0.5, 0.08), 2.2)
        sign_text('КРУГЛОСУТОЧНО', it['x'], fy - 0.08, 3.38, 0.20, (1.0, 0.16, 0.1), 2.0)

def free(x, y, pad=2.5):
    for sx, sy, sw, sh_ in solid:
        if abs(x - sx) < sw / 2 + pad and abs(y - sy) < sh_ / 2 + pad: return False
    for pts in L.get('paths', []):
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            dx, dy = bx - ax, by - ay; t = max(0, min(1, ((x - ax) * dx + (y - ay) * dy) / max(dx * dx + dy * dy, 1e-6)))
            if math.hypot(x - ax - dx * t, y - ay - dy * t) < 2.2: return False
    return x0 + 5 < x < x1 - 5 and y0 + 5 < y < y1 - 5

# места камер держим свободными от деревьев и сугробов
for cxy in ((-58, -20.5), (-22, -104), (-72, 34), (-52, -17.5), (-34, 92), (10, 30), (40, -31), (78, -21), (-74, -78), (-30, 4), (92, 96), (86, 104), (82, -18.6), (82, -68), (-20, 93), (-63.2, 33), (-52, -2), (-84, 96), (37, -19.5), (-98, -62)):
    solid.append((cxy[0], cxy[1], 14, 14))
# ---------------- тропы: утоптанный снег по маршрутам и к подъездам
for pts in L.get('paths', []):
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        ln = math.hypot(bx - ax, by - ay)
        o = box('trod', (ax + bx) / 2, (ay + by) / 2, ln + 1.0, 1.6, 0.0, 0.025, 'path'); o.rotation_euler = (0, 0, math.atan2(by - ay, bx - ax))
# ---------------- деревья: сухие деревья и редкие ели
TREES = ['tree_dead_1', 'tree_dead_3', 'tree_dead_5', 'tree_winter', 'tree_winter', 'tree_winter', 'tree_dead_2', 'tree_dead_4']
TREES = [t for t in TREES if t in LIB]
def tree(x, y):
    put(rnd.choice(TREES), x, y, rnd.uniform(0, 360), None, 'tree', rnd.uniform(0.85, 1.25)); solid.append((x, y, 2.5, 2.5))
for (ax, ay, bx, by, n, pines) in ((-34, -104, 32, -62, 14, 3), (-124, -110, -70, -62, 16, 3), (74, -112, 128, -62, 14, 3), (82, 44, 144, 132, 18, 4),
                                   (-46, 8, 40, 44, 16, 0), (-146, -140, 146, -132, 22, 6), (-146, 96, -74, 104, 6, 0), (76, -40, 146, -30, 5, 0), (-72, 92, -24, 102, 4, 0)):
    k = 0; tries = 0
    while k < n and tries < n * 30:
        tries += 1; x, y = rnd.uniform(ax, bx), rnd.uniform(ay, by)
        if not free(x, y): continue
        k += 1
        if k <= pines:
            if k % 2: put('pine_ps1_1', x, y, rnd.uniform(0, 360), None, 'pines', rnd.uniform(0.8, 1.05)); solid.append((x, y, 12, 12))
            else: put('snow_pine_%d' % rnd.randint(1, 3), x, y, rnd.uniform(0, 360), None, 'pine'); solid.append((x, y, 2.5, 2.5))
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
for x, y in ((-72, -112), (58, -70), (78, -66), (-58, -40), (90, 56), (140, 126), (-64, 96), (26, -66)):
    for k in range(3): put('trashbag', x - 1.4 + rnd.uniform(-0.5, 0.5), y + rnd.uniform(-0.9, 0.9), rnd.uniform(0, 360), None, 'bag', rnd.uniform(0.9, 1.3))
for x, y in ((90.5, -5), (91.2, -4.2), (90.2, -3.6), (79, -3.2), (-56, 20.5), (-63, 36), (-64.5, 37), (104, 25.5), (-48, -72), (-90, 9)):
    put('tyre_old', x, y, rnd.uniform(0, 360), None, 'tyre')
for x, y in ((-55.5, 9.5), (-56.4, 10.2), (97, 25), (126, 25.2), (-49, -98), (-62, 52)): put('barrel_blue', x, y, rnd.uniform(0, 360), None, 'barrel')
for x, y in ((-40, -14), (-3, -14), (48, -14.5), (88, -13.5), (-104, 104)): put('trash_cans', x, y, rnd.uniform(0, 360), None, 'cans')
for x, y, yw in ((-70, -46.5, 0), (-71.8, -46.5, 0), (-66.2, 93, 0), (-73.8, 93, 0), (92, 34.5, 90), (-9, 93.5, 0), (21, 93.5, 0), (-30, -108, 90), (62, 142, 0), (70, 142, 0), (62, -142, 0), (70, -142, 0)):
    put(rnd.choice(('barrier_1', 'barrier_2')), x, y, yw, None, 'barrier')
# ================= ДЕКОРАЦИИ V5: чтобы район не был пустым
FIRES = []
def at(mid, x, y, yaw=None, k=None, z=0.0, nm='deco'):
    if mid not in LIB: return None
    h = put(mid, x, y, rnd.uniform(0, 360) if yaw is None else yaw, None, nm, k)
    if h and z: h.location.z = z
    return h
def scat(mids, n, box_, k=(1.0, 1.0), pad=1.2, block=1.6):
    ax, ay, bx, by = box_; done = 0; tries = 0
    while done < n and tries < n * 40:
        tries += 1; x, y = rnd.uniform(ax, bx), rnd.uniform(ay, by)
        if not free(x, y, pad): continue
        at(rnd.choice(mids), x, y, None, rnd.uniform(*k)); solid.append((x, y, block, block)); done += 1
YARDS = {'home': (-34, -104, 32, -62), 'sw': (-124, -110, -70, -62), 'se': (74, -112, 128, -62), 'ne': (82, 44, 144, 132), 'waste': (-46, 8, 40, 44), 'north': (-72, 92, 60, 100), 'school': (-144, 98, -76, 112)}
# площадки: ракета, снеговики, бельё, навесные мелочи
for x, y, yw in ((-8, -76, 20), (110, 100, 100), (-90, -96, 0)): at('rocket_slide', x, y, yw); solid.append((x, y, 8, 8))
for x, y in ((6, -80), (14, -88), (-102, -92), (118, -96), (112, 90), (-20, 30), (-60, 106), (30, 34), (-92, 104), (124, 88)): at('snowman', x, y, None, rnd.uniform(0.85, 1.2)); solid.append((x, y, 1.5, 1.5))
for x, y, yw in ((-24, -70, 0), (22, -96, 90), (-116, -96, 0), (-80, -74, 90), (88, -96, 0), (128, -72, 90), (92, 110, 0), (126, 98, 90), (-30, 62, 0), (44, 58, 90)):
    if free(x, y, 0.5): at('laundry', x, y, yw); solid.append((x, y, 8, 8))
at('boombox', -16, -93, 200, None, 0.78); at('boombox', -112, -76, 30, None, 0.32)
for x, y in ((-10, -84), (16, -92), (-92, -92), (-4, -79), (112, 96), (-100, 110)): at('cat_statue', x + 0.9, y + 0.4, None, rnd.uniform(0.8, 1.2))
# у подъездов: доски объявлений, почтовые ящики, шкафы
for i, (ex, ey) in enumerate(ENTR):
    if i % 2 == 0: at('info_stand', ex - 3.2, ey + (0.0 if i % 4 else 0.3), 0 if abs(ex) < 200 and i % 4 < 2 else 90)
    if i % 3 == 1: at('utility_box', ex + 5.4, ey, 0)
    if i % 4 == 3: at('crow_2', ex + rnd.uniform(-3, 3), ey + rnd.uniform(-2.5, 2.5))
for x, y in ((90, -62), (-46, -14.5), (50, -14.6), (-104, 110), (80, -14)): at('mailbox', x, y, 180, 1.15)
# улица и рынок: щиты, коробки, ящики, поддоны, бочки-печки
for x, y, yw in ((-96, -15.6, 90), (112, -15.6, 90), (-118, 110, 90)): at('billboard_soviet', x, y, yw)
for x, y, yw in ((76, -34, 0), (56, 40, 90), (-140, -34, 0)): at('billboard_ad', x, y, yw)
for kx in (-44, -36, -30, -25, -20, -12, -6, 0, 44):
    for j in range(rnd.randint(2, 4)):
        at(rnd.choice(('box_cardboard', 'crate_plastic', 'crate_plastic')), kx + rnd.uniform(-2.2, 2.2), -5.6 + rnd.uniform(-0.6, 0.6), None, rnd.uniform(1.0, 1.5))
    if rnd.random() < 0.5: at('crate_plastic', kx + rnd.uniform(-1.5, 1.5), -13.6, None, 1.3)
for x, y in ((-40, -4.5), (-8, -4.2), (90, -2.5), (98, -40), (40, -4.6), (-57, 22), (118, 14), (-52, 40)): at('pallets', x, y, None, rnd.uniform(0.6, 0.9)); solid.append((x, y, 3, 3))
for x, y in ((-33, -14.4), (88.5, -3.4), (-57.5, 18.5), (110, 26), (-66, 60), (4, 96.5), (-4, -14.4)):
    at('barrel_stove', x, y); FIRES.append((x, y))
# у гаражей: диваны, покрышки, брёвна
for x, y, yw in ((-58, 24.5, 100), (114, 25.2, 0), (-46, -66, 180), (-66, 84, 90)): at('sofa_set', x, y, yw); solid.append((x, y, 4, 4))
for x, y in ((-20, 20), (12, 36), (-36, 30), (26, 16), (-110, -70), (100, -70)): at('log_dead', x, y)
for x, y in ((-10, 32), (22, 26), (-30, 14), (-84, -86), (132, 50), (-66, 104)): at('stump', x, y)
for i, (x, y) in enumerate(((-40, -66), (-36.4, -66), (124, -64), (127.6, -64), (88, 112), (-124, -106), (-120.4, -106), (58, 100))):
    if free(x, y, 0.2): at('garage_metal_%d' % (1 + i % 7), x, y, 0); solid.append((x, y, 4, 7))
# люки на дорогах и во дворах
for x in range(-130, 140, 34): at('manhole', x, -22.4, 0)
for y in range(-120, 130, 38): at('manhole', 64.4, y, 0)
for x, y in ((0, -100), (-64, -90), (114, 30), (6, 88), (-70, 40), (108, -86), (-98, -76)): at('manhole', x, y, 0)
# машины вдоль дворовых проездов
for y in range(-122, -50, 9):
    if rnd.random() < 0.6: at(rnd.choice(cars), -61.9, y + rnd.uniform(-1, 1), rnd.choice((0, 180)))
for y in range(4, 88, 10):
    if rnd.random() < 0.5: at(rnd.choice(cars), -68.1, y + rnd.uniform(-1, 1), rnd.choice((0, 180)))
for x in range(96, 134, 9):
    if rnd.random() < 0.6: at(rnd.choice(cars), x, 32.2, rnd.choice((90, -90)))
for x in range(-46, 60, 10):
    if abs(x - 6) > 9 and rnd.random() < 0.55: at(rnd.choice(cars), x, 85.4, rnd.choice((90, -90)))
# кусты вдоль фасадов и ещё деревья, сугробы, вороны во дворах
for it in L['items']:
    if it['cat'] != 'res' or it.get('mark'): continue
    wide = it['w'] > it['h']; ln = max(it['w'], it['h'])
    for sgn in (-1, 1):
        for i in range(int(ln / 4.5)):
            t = -ln / 2 + 2.5 + i * 4.5 + rnd.uniform(-0.6, 0.6)
            bx_, by_ = (it['x'] + t, it['y'] + sgn * (it['h'] / 2 + 2.9)) if wide else (it['x'] + sgn * (it['w'] / 2 + 2.9), it['y'] + t)
            if any(abs(bx_ - ex) < 5.5 and abs(by_ - ey) < 5.5 for ex, ey in ENTR): continue
            if rnd.random() < 0.7 and free(bx_, by_, 0.2): at('bush_bare', bx_, by_, None, rnd.uniform(0.6, 1.1))
for nm, bx in YARDS.items():
    scat(TREES, 9 if nm != 'waste' else 14, bx, (0.8, 1.25), 2.5, 2.5)
    scat(['bush_bare'], 12, bx, (0.6, 1.2), 1.5)
    scat(['snow_pile'], 7, bx, (0.5, 1.2), 2.0, 3.0)
    scat(['crow_2'], 6, bx, (1.0, 1.3), 0.8, 0.5)
scat(['bush_bare'], 40, (-146, -140, 146, -132), (0.7, 1.3), 1.0)
scat(['bush_bare', 'tree_winter'], 24, (-146, 132, 146, 140), (0.7, 1.2), 1.0)
print('DECO done', flush=True)
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
for c in MASTS: LAMPS.append((c[0], c[1], 11.0, 'rink'))
for fx, fy in FIRES: LAMPS.append((fx, fy, 1.1, 'fire'))
LAMPS += [(44, -15.2, 2.5, 'shawa'), (-110, 111, 4.0, 'shop'), (-120, 111, 4.0, 'door'), (-100, 111, 4.0, 'door'), (-96, 104, 6.2, 'yard'), (-124, 104, 6.2, 'yard'), (-16, -93, 2.4, 'door'), (-112, -76, 2.6, 'door'), (118, 82, 2.6, 'door')]
# ---------------- дорожные знаки (столбик и щиток из набора), столбы с проводами
def road_sign(pid, x, y, yaw):
    put('sign_1', x, y, 0, None, 'signpole', 0.3)
    h = put(pid, x, y, yaw, None, 'signplate', 0.3)
    if h: h.location.z = 2.1
for pid, x, y, yw in (('sign_5', 56.5, -17.2, 0), ('sign_10', 59.6, -30.2, 0), ('sign_10', 72.4, -17.8, 180), ('sign_11', 59.6, -17.8, 90), ('sign_11', 72.4, -30.2, -90),
                      ('sign_13', -8, 92.6, 0), ('sign_13', -64, -47, 90), ('sign_11', 20, -30.2, 0), ('sign_11', 20, -17.8, 180), ('sign_10', -73.6, -30.2, 0), ('sign_13', 96, 33.8, 0)):
    if pid in LIB: road_sign(pid, x, y, yw)
for px in range(-44, 62, 16): put('pole_wires', px, 93.2, 90, None, 'wires')
for py in range(4, 90, 16): put('pole_wires', -144.5, py, 0, None, 'wires')
for py in range(-136, -40, 16): put('pole_wires', -66.5, py, 0, None, 'wires')
for x, y in ((-76, 22), (-76, 45), (-76, 67), (112, 26), (-36, 100)): put('pole_concrete', x, y, rnd.choice((0, 90)), None, 'cpole')
# ---------------- горизонт
for mid, tx, ty, yw in (('tower_16_wide', -40, y1 + 80, 0), ('tower_9_wide', 60, y1 + 70, 0), ('tower_16_slab', x0 - 80, 60, 0), ('tower_9_slab', x0 - 70, -40, 0),
                        ('tower_9_wide', x1 + 80, 70, 90), ('tower_16_slab', x1 + 70, -50, 0), ('tower_9_slab', -40, y0 - 80, 90), ('tower_16_wide', 90, y0 - 90, 0), ('smoke_stacks', -110, y1 + 30, 0)):
    put(mid, tx, ty, yw, None, 'skyline'); GLOW_IDS.add(mid)
if 'res_long_9' in LIB:      # длинные дома-«стены» по краям района
    put('res_long_9', x1 + 42, 20, 0, None, 'wall_e', 0.75); put('res_long_9', -70, y0 - 44, 90, None, 'wall_s', 0.75); GLOW_IDS.add('res_long_9')
GLOW_IDS = {g for g in GLOW_IDS if g.startswith(('res_block', 'res_brick', 'res_panel_7', 'school', 'res_long'))}
GLOW = set()
for mid in GLOW_IDS:
    if CACHE.get(mid):
        for o in CACHE[mid][1]:
            if o.type == 'MESH': GLOW.update(s.material for s in o.material_slots if s.material)
GLOWN = []
def window_glow(m, b):
    """Окна: тёмные участки текстуры на стенах светятся тёплым, по случайным «квартирам» (ячейки 3,2 × 2,8 м)."""
    nt = m.node_tree; inp = b.inputs['Base Color']
    if not inp.links: return
    N = nt.nodes.new; Lk = nt.links.new
    bw = N('ShaderNodeRGBToBW'); Lk(inp.links[0].from_socket, bw.inputs[0])
    dark = N('ShaderNodeMapRange'); dark.inputs['From Min'].default_value = 0.15; dark.inputs['From Max'].default_value = 0.06; dark.clamp = True; Lk(bw.outputs[0], dark.inputs['Value'])
    geo = N('ShaderNodeNewGeometry')
    sc_ = N('ShaderNodeVectorMath'); sc_.operation = 'MULTIPLY'; sc_.inputs[1].default_value = (1 / 3.2, 1 / 3.2, 1 / 2.8); Lk(geo.outputs['Position'], sc_.inputs[0])
    off = N('ShaderNodeVectorMath'); off.operation = 'ADD'; off.inputs[1].default_value = (0.37, 0.41, 0.2); Lk(sc_.outputs[0], off.inputs[0])
    fl = N('ShaderNodeVectorMath'); fl.operation = 'FLOOR'; Lk(off.outputs[0], fl.inputs[0])
    wn = N('ShaderNodeTexWhiteNoise'); wn.noise_dimensions = '3D'; Lk(fl.outputs[0], wn.inputs['Vector'])
    lit = N('ShaderNodeMath'); lit.operation = 'GREATER_THAN'; lit.inputs[1].default_value = 0.66; Lk(wn.outputs['Value'], lit.inputs[0])
    sep = N('ShaderNodeSeparateXYZ'); Lk(geo.outputs['Normal'], sep.inputs[0])
    ab = N('ShaderNodeMath'); ab.operation = 'ABSOLUTE'; Lk(sep.outputs['Z'], ab.inputs[0])
    wall = N('ShaderNodeMath'); wall.operation = 'LESS_THAN'; wall.inputs[1].default_value = 0.3; Lk(ab.outputs[0], wall.inputs[0])
    m1 = N('ShaderNodeMath'); m1.operation = 'MULTIPLY'; Lk(dark.outputs[0], m1.inputs[0]); Lk(lit.outputs[0], m1.inputs[1])
    m2 = N('ShaderNodeMath'); m2.operation = 'MULTIPLY'; Lk(m1.outputs[0], m2.inputs[0]); Lk(wall.outputs[0], m2.inputs[1])
    pw = N('ShaderNodeMath'); pw.operation = 'MULTIPLY'; Lk(m2.outputs[0], pw.inputs[0]); pw.inputs[1].default_value = 1.1
    ramp = N('ShaderNodeMixRGB'); ramp.inputs['Color1'].default_value = (1.0, 0.62, 0.26, 1); ramp.inputs['Color2'].default_value = (0.45, 0.62, 1.0, 1); Lk(wn.outputs['Color'], ramp.inputs['Fac'])
    cool = N('ShaderNodeMath'); cool.operation = 'GREATER_THAN'; cool.inputs[1].default_value = 0.92; Lk(wn.outputs['Value'], cool.inputs[0]); Lk(cool.outputs[0], ramp.inputs['Fac'])
    Lk(ramp.outputs[0], b.inputs['Emission Color']); Lk(pw.outputs[0], b.inputs['Emission Strength'])
    GLOWN.append(pw)

# ---------------- снег на всех моделях: белим грани, смотрящие вверх
for m in bpy.data.materials:
    if m in OWN or not m.use_nodes: continue
    nt = m.node_tree; b = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if b is None: continue
    inp = b.inputs['Base Color']
    if m in GLOW: window_glow(m, b)
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
wnt = sc.world.node_tree          # небо: градиент от зарева у горизонта к тёмному зениту
tc = wnt.nodes.new('ShaderNodeTexCoord'); sx_ = wnt.nodes.new('ShaderNodeSeparateXYZ'); SKY = wnt.nodes.new('ShaderNodeValToRGB')
wnt.links.new(tc.outputs['Generated'], sx_.inputs[0]); wnt.links.new(sx_.outputs['Z'], SKY.inputs['Fac']); wnt.links.new(SKY.outputs['Color'], bg.inputs[0])
SKY.color_ramp.elements[0].position = 0.0; SKY.color_ramp.elements[1].position = 0.45; SKY.color_ramp.elements.new(0.08)
bpy.ops.mesh.primitive_cube_add(size=1, location=((x0 + x1) / 2, (y0 + y1) / 2, 35)); hz = bpy.context.object; hz.name = 'haze'; hz.scale = ((x1 - x0) + 500, (y1 - y0) + 500, 70)
hm = bpy.data.materials.new('haze'); hm.use_nodes = True; hnt = hm.node_tree
for n_ in list(hnt.nodes):
    if n_.type != 'OUTPUT_MATERIAL': hnt.nodes.remove(n_)
HAZE = hnt.nodes.new('ShaderNodeVolumeScatter'); hnt.links.new(HAZE.outputs[0], next(n_ for n_ in hnt.nodes if n_.type == 'OUTPUT_MATERIAL').inputs['Volume'])
HAZE.inputs['Anisotropy'].default_value = 0.35; hz.data.materials.append(hm)
HAZE.inputs['Color'].default_value = (0.82, 0.86, 1.0, 1)
try:
    sc.eevee.volumetric_end = 600; sc.eevee.volumetric_tile_size = '4'
except Exception as e: print('VOL', e)
sun = bpy.data.objects.new('sky', bpy.data.lights.new('sky', 'SUN')); sc.collection.objects.link(sun)
LIGHTS = []
for i, (lx, ly, lz, kind) in enumerate(LAMPS):
    li = bpy.data.objects.new('l%d' % i, bpy.data.lights.new('l%d' % i, 'POINT')); sc.collection.objects.link(li)
    li.location = (lx, ly, lz); li.data.shadow_soft_size = 0.3; li.data.use_shadow = kind in ('street', 'rink') and i % 2 == 0
    li['kind'] = kind; LIGHTS.append(li)
PW = {'street': 2600, 'yard': 1500, 'door': 220, 'shop': 420, 'rink': 6500, 'shawa': 420, 'fire': 260}
COL = {'street': (1.0, 0.66, 0.34), 'yard': (1.0, 0.7, 0.4), 'door': (1.0, 0.78, 0.5), 'shop': (1.0, 0.86, 0.66), 'rink': (0.92, 0.96, 1.0), 'shawa': (1.0, 0.55, 0.16), 'fire': (1.0, 0.36, 0.08)}
SKYC = {'dusk': ((0.40, 0.17, 0.13), (0.10, 0.085, 0.24), (0.018, 0.03, 0.11), 0.0011, 1.0),
        'night': ((0.06, 0.05, 0.09), (0.02, 0.024, 0.07), (0.006, 0.01, 0.035), 0.0014, 1.3),
        'day': ((0.62, 0.66, 0.72), (0.56, 0.61, 0.69), (0.46, 0.53, 0.64), 0.0006, 0.0)}
def mood(nm):
    k = {'dusk': (0.03, 0.06, 0.16, 0.5, 0.9, 1.0), 'night': (0.006, 0.012, 0.04, 0.35, 0.5, 1.5), 'day': (0.55, 0.6, 0.68, 2.6, 1.2, 0.0)}[nm]
    bg.inputs[1].default_value = 1.0
    s = SKYC[nm]; els = sorted(SKY.color_ramp.elements, key=lambda e: e.position)
    for e, c in zip(els, s[:3]): e.color = (*c, 1)
    HAZE.inputs['Density'].default_value = s[3]
    for n in GLOWN: n.inputs[1].default_value = 1.1 * s[4]
    sun.data.energy = k[3]; sun.data.color = (0.6, 0.72, 1.0) if nm != 'day' else (0.95, 0.96, 1.0)
    sun.rotation_euler = (math.radians(62), 0, math.radians(40)); sun.data.angle = math.radians(20)
    sc.view_settings.exposure = k[4] - 0.6
    for li in LIGHTS:
        li.data.energy = PW[li['kind']] * k[5]; li.data.color = COL[li['kind']]

ONLY = [a[7:] for a in sys.argv if a.startswith('--only=')]
ONLY = ONLY[0].split(',') if ONLY else None
def view(nm, pos, look, lens=28, res=(1920, 1080), ortho=None):
    if ONLY and not any(nm.startswith(o) for o in ONLY): return
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
view('05_hockey_rink', (-20, 93, 5.5), (9, 114, 1.2), lens=24)
view('17_court_gate', (-1, 91.5, 2.4), (8, 108, 1.4), lens=24)
view('14_school', (-84, 96, 1.9), (-108, 120, 6), lens=24)
view('15_shawarma', (37, -19.5, 1.8), (45, -11, 2.8), lens=28)
view('16_gazebo_yard', (-98, -62, 1.9), (-112, -80, 2.2), lens=26)
view('18_garage_corner', (-63.2, 33, 1.8), (-57, 20, 1.2), lens=24)
view('19_market_back', (-52, -2, 1.8), (-20, -7, 1.6), lens=26)
view('06_aerial', (cx - 30, y0 - 150, 170), (cx, cy - 10, 0), lens=30)
view('07_towers_gate', (10, 30, 1.9), (6, 80, 13), lens=24)
view('08_bus_stop', (40, -31, 1.9), (52, -15, 2.2), lens=26)
view('09_crossroads_mcqueen', (82, -18.6, 1.7), (93, -9.5, 1.3), lens=28)
view('10_brick_yard', (-74, -78, 1.9), (-110, -112, 7), lens=24)
view('11_wasteland', (-30, 4, 1.9), (0, 60, 10), lens=24)
view('12_panel_yard', (86, 104, 2.0), (126, 86, 9), lens=24)
view('13_shop', (82, -68, 1.9), (96, -52, 3.5), lens=26)
mood('night')
view('L_night_main_street', (-58, -20.5, 1.9), (40, -16, 4), lens=26, res=(1280, 720))
view('L_night_home_yard', (-22, -104, 2.0), (16, -72, 5), lens=24, res=(1280, 720))
mood('day')
view('L_day_main_street', (-58, -20.5, 1.9), (40, -16, 4), lens=26, res=(1280, 720))
view('L_day_home_yard', (-22, -104, 2.0), (16, -72, 5), lens=24, res=(1280, 720))
view('00_top', (cx, cy, 600), (cx, cy + 0.001, 0), res=(1500, 1500), ortho=(y1 - y0) + 14)
print('DONE')
