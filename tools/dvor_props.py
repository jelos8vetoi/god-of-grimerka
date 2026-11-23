"""ДВОР: расстановка декораций кластерами — без случайных координат (решение владельца 2026-11-25).
Каждый предмет стоит по правилу своего кластера: подъезд, мусорная площадка, гаражный угол, задворки ларька, парковка, аллея.
python tools/dvor_props.py -> topdown_layout/DVOR_PROPS.json (читает сцена), DVOR_PROP_PLACEMENT_MAP.png, таблица для DVOR_PROP_PLACEMENT_GUIDE.md
Проверки: предмет не в доме, не на проезжей части (кроме машин и люков), не на тропе, не ближе суммы радиусов к соседу."""
import os, json, math
W = os.path.join(os.path.dirname(__file__), '..', 'godot', 'assets', 'golda67', 'dvor_redesign_work')
LAY = json.load(open(os.path.join(W, 'topdown_layout', 'DVOR_TOPDOWN_RECOMMENDED.layout.json'), encoding='utf-8'))
LIB = json.load(open(os.path.join(W, 'architecture_parts', 'library.json'), encoding='utf-8'))
IT = {i['id']: i for i in LAY['items']}
PROPS = []; CLUSTERS = []; ENTR = []; FIRES = []
CUR = ['']
def cluster(name, x, y, role):
    CLUSTERS.append({'name': name, 'x': x, 'y': y, 'role': role, 'n': 0}); CUR[0] = name
def P(m, x, y, yaw=0, k=None, z=0.0):
    PROPS.append({'m': m, 'x': round(x, 2), 'y': round(y, 2), 'yaw': yaw, 'k': k, 'z': z, 'c': CUR[0]})
def turn(i): return (i * 137 + 40) % 360          # поворот дерева вокруг своей оси — не положение
TREES = ['tree_dead_1', 'tree_winter', 'tree_dead_3', 'tree_winter', 'tree_dead_5', 'tree_dead_2', 'tree_winter', 'tree_dead_4']
TK = [1.0, 0.92, 1.12, 1.0, 0.86, 1.18, 1.05, 0.95]
CARS = ['car_zhiguli_1', 'car_vaz_21099', 'car_zhiguli_3', 'car_zhiguli_2', 'car_zhiguli_4']
def trees(pts, start=0):
    for i, (x, y) in enumerate(pts): P(TREES[(i + start) % 8], x, y, turn(i + start), TK[(i + start) % 8])
def row(m, ax, ay, bx, by, step, skip=(), k=None, yaw=None):
    n = int(math.hypot(bx - ax, by - ay) / step)
    for i in range(n + 1):
        x, y = ax + (bx - ax) * i / max(n, 1), ay + (by - ay) * i / max(n, 1)
        if any(abs(x - sx) < sr and abs(y - sy) < sr for sx, sy, sr in skip): continue
        mm = m[i % len(m)] if isinstance(m, (list, tuple)) else m
        P(mm, x, y, turn(i) if yaw is None else yaw, (k[i % len(k)] if isinstance(k, (list, tuple)) else k))

# ================= ПОДЪЕЗДЫ: лавка, урна, доска объявлений, шкаф, санки, клумба
BENCH = ['bench_ussr', 'bench_siberian', 'bench_concrete']
n_e = 0
for it in LAY['items']:
    if it['cat'] != 'res' or it.get('mark'): continue
    wide = it['w'] > it['h']; south = it['y'] > -90
    cluster('подъезды ' + it['id'], it['x'], it['y'], 'лавка, урна и доска объявлений у каждой двери; санки и клумба — через одну')
    for t in (-0.25, 0.25):
        if wide: ex, ey, ux, uy, ox, oy = it['x'] + it['w'] * t, it['y'] + (-(it['h'] / 2 + 2.2) if south else (it['h'] / 2 + 2.2)), 1, 0, 0, (-1 if south else 1)
        else:
            west = it['x'] > 0
            ex, ey, ux, uy, ox, oy = it['x'] + (-(it['w'] / 2 + 2.2) if west else (it['w'] / 2 + 2.2)), it['y'] + it['h'] * t, 0, 1, (-1 if west else 1), 0
        ENTR.append((round(ex, 2), round(ey, 2)))
        b = BENCH[n_e % 3]; long_y = LIB[b]['size'][1] > LIB[b]['size'][0]
        P(b, ex + ux * 2.4, ey + uy * 2.4, (90 if long_y else 0) if wide else (0 if long_y else 90))
        P('urn_red', ex + ux * 4.0, ey + uy * 4.0)
        if n_e % 2 == 0: P('info_stand', ex - ux * 3.2, ey - uy * 3.2, 0 if wide else 90)
        if n_e % 3 == 1: P('utility_box', ex + ux * 5.6 - ox * 1.2, ey + uy * 5.6 - oy * 1.2, 0 if wide else 90)
        if n_e % 5 == 0: P('sled', ex - ux * 1.5 + ox * 0.9, ey - uy * 1.5 + oy * 0.9, 35)
        if n_e % 3 == 0: P('flowerbed', ex - ux * 5.4 + ox * 1.6, ey - uy * 5.4 + oy * 1.6)
        if n_e % 3 == 0: P('cat_statue', ex - ux * 5.4 + ox * 3.0, ey - uy * 5.4 + oy * 3.0, 200 if oy else 110)
        n_e += 1
    # кусты вдоль фасадов: ровный ряд, у дверей — разрыв
    ln = max(it['w'], it['h'])
    for sgn in (-1, 1):
        for i in range(int((ln - 4) / 5.0) + 1):
            t = -ln / 2 + 2.5 + i * 5.0
            bx, by = (it['x'] + t, it['y'] + sgn * (it['h'] / 2 + 2.9)) if wide else (it['x'] + sgn * (it['w'] / 2 + 2.9), it['y'] + t)
            if any(abs(bx - ex) < 6.5 and abs(by - ey) < 6.5 for ex, ey in ENTR): continue
            if it['id'] == 'H9' and abs(t) < 8: continue          # проезд арки свободен
            if i % 3 != 2: P('bush_bare', bx, by, turn(i), [0.8, 1.0, 0.9][i % 3])

# ================= АЛЛЕИ вдоль улиц и у школы
cluster('аллея улицы Облачной', -40, -34.5, 'ряд деревьев между тротуаром и дворами, разрывы у проездов и троп')
row(TREES, -140, -34.5, 56, -34.5, 13, skip=((-64, -34.5, 6), (20, -34.5, 6), (60, -34.5, 6)), k=TK)
row(TREES, 82, -34.5, 142, -34.5, 15, k=TK)
cluster('аллея улицы Битной', 77, 40, 'ряд деревьев вдоль восточного тротуара')
row(TREES, 77, -128, 77, 134, 14, skip=((77, -24, 11), (77, 30, 6), (77, 88, 7)), k=TK)
cluster('аллея у школы', -110, 108, 'ряд деревьев перед школой, памятник на оси входа')
row(TREES, -136, 108, -86, 108, 10, skip=((-110, 108, 4.5),), k=TK)
P('monument', -110, 104, 180)
P('snowman', -100, 104.5, 150, 1.0); P('snowman', -96.8, 103.2, 200, 0.85); P('sled', -98.5, 102.2, 20)
P('mailbox', -104, 111.5, 180, 1.15); P('trash_cans', -118, 111.6, 0)
cluster('ветрозащита у железной дороги', 0, -137, 'сплошной ряд елей и кустов вдоль насыпи')
row(['pine_ps1_1', 'bush_bare', 'snow_pine_2', 'bush_bare', 'snow_pine_1', 'bush_bare'], -138, -137.5, 140, -137.5, 9.5, skip=((66, -137.5, 9),), k=[0.9, 1.1, 1.0, 0.9, 1.0, 1.2])
cluster('кусты у северного забора', 0, 138, 'ряд вдоль бетонного забора')
row(['bush_bare', 'tree_winter', 'bush_bare'], -140, 138.5, 140, 138.5, 10, skip=((66, 138.5, 9), (44, 138.5, 12)), k=[1.0, 0.9, 1.2])

# ================= ДВОРЫ: деревья по краям площадок, площадки, бельё
cluster('двор Пахана', 0, -84, 'площадка в центре: горка, качели, ракета, снеговики; деревья кольцом вокруг; бельё у дома 69; ели у дома 65')
trees([(-26, -97), (-29, -84), (-25, -70), (-13, -66), (5, -66), (19, -69), (27, -77), (24, -99), (-9, -99)])
P('pine_ps1_1', 24, -86, 100, 0.85)
P('rocket_slide', -8, -76, 20); P('snowman', 6.5, -79.5, 200, 1.05); P('snowman', 13.5, -86.5, 160, 0.9); P('sled', 4.5, -80.6, 70)
P('laundry', -24, -76, 0); P('boombox', -16, -93, 200, None, 0.78)
cluster('двор 71–75', -100, -86, 'качели, ракета и беседка; деревья вдоль домов; бельё у дома 73')
trees([(-121, -104), (-110, -101), (-84, -104), (-76, -96), (-76, -70), (-88, -66), (-104, -66), (-121, -68), (-123, -92)], 3)
P('pine_ps1_1', -82, -82, 30, 0.85)
P('rocket_slide', -90, -96, 0); P('snowman', -102, -92.5, 120, 1.0); P('laundry', -112, -98, 90); P('boombox', -112, -76, 30, None, 0.32)
cluster('двор 61–63', 104, -86, 'горка и качалка у парковки; деревья по краю; бельё у дома 63')
trees([(78, -104), (80, -88), (80, -72), (92, -104), (126, -108), (124, -70), (111, -70), (92, -72)], 5)
P('pine_ps1_1', 84, -96, 200, 0.8); P('snowman', 118, -96.5, 240, 1.0); P('laundry', 104, -103, 90)
cluster('двор панелек', 114, 92, 'качели, горка, ракета, беседка; деревья между домами')
trees([(112, 74), (114, 60), (110, 48), (122, 48), (144, 84), (122, 106), (88, 100), (86, 84), (86, 66), (124, 129), (118, 131)], 2)
P('rocket_slide', 110, 101, 100); P('snowman', 112.5, 89.5, 200, 1.0); P('laundry', 136, 85, 0)
cluster('пустырь', -4, 26, 'две рощицы по сторонам тропы, брёвна и пни; тропа свободна')
trees([(-40, 14), (-34, 22), (-38, 32), (-28, 38), (-24, 26), (-30, 12), (-18, 18), (-14, 34), (-20, 42)], 1)
trees([(22, 14), (30, 22), (26, 34), (34, 38), (36, 12), (18, 40), (-2, 16)], 4)
P('log_dead', -26, 20.5, 25); P('log_dead', 28, 28, 110); P('stump', -34, 27, 0); P('stump', 24, 20, 90); P('snowman', -21, 30, 300, 0.9)
cluster('у беседки-передышки', -34, 80, 'беседка перед башнями: магнитофон на полу, деревья за спиной')
trees([(-41, 74), (-27, 73), (-42, 86)], 6); P('boombox', -34, 80, 30, None, 0.32); P('urn_red', -30.2, 82.6)

# ================= МУСОРНЫЕ ПЛОЩАДКИ: два бака у проезда, мешки, сугроб, иногда старая мебель
def bins(name, x, y, sofa=False, side=1):
    cluster('мусорка ' + name, x, y, 'два бака у проезда (подъезд мусоровоза), мешки рядом, сугроб от расчистки' + (', выброшенный диван' if sofa else ''))
    P('dumpster_blue', x, y); P('dumpster_blue', x + 1.6, y)
    P('trashbag', x - 1.2, y + 0.3, 20, 1.1); P('trashbag', x - 1.5, y - 0.4, 200, 0.95); P('trashbag', x + 2.8, y + 0.4, 90, 1.2)
    P('snow_pile', x + 0.8, y + side * 3.0, 15, 0.7); P('crow_2', x + 0.8, y - side * 1.4, 140, 1.2)
    if sofa: P('sofa_set', x + 5.2, y, 180)
bins('двора Пахана', 33.5, -106.5, True); bins('двора 71–75', -70.5, -112, False); bins('двора 61–63', 122, -76, True, -1)
bins('двора панелек', 88.5, 113, False); bins('ГСК', -66, 96, True); bins('рынка', -49.5, -4, False); bins('школы', -90, 112.5, False, -1)

# ================= РЫНОК, «ШАУРМА 67», ОСТАНОВКА
cluster('рынок: задворки киосков', -22, -5.6, 'за каждым киоском — коробки и ящики с товаром; поддоны; бочка-печка у торговцев; бак и почта у входа')
BACK = [[('box_cardboard', -1.2, 0.0, 10, 1.3), ('crate_plastic', -0.3, 0.2, 80, 1.3), ('crate_plastic', -0.3, 0.2, 100, 1.3, 0.34)],
        [('crate_plastic', 0.6, 0.0, 0, 1.3), ('crate_plastic', 1.2, 0.1, 30, 1.3), ('box_cardboard', 0.2, -0.3, 60, 1.2)],
        [('box_cardboard', -0.6, 0.1, 40, 1.4), ('box_cardboard', 0.3, 0.0, 0, 1.2), ('box_cardboard', -0.2, 0.05, 20, 1.0, 0.46)]]
for i, kx in enumerate((-44, -36, -30, -25, -20, -12, -6, 0)):
    for q in BACK[i % 3]: P(q[0], kx + q[1], -5.4 + q[2], q[3], q[4], q[5] if len(q) > 5 else 0.0)
P('pallets', -40, -3.6, 0, 0.7); P('pallets', -9, -3.4, 90, 0.7)
P('barrel_stove', -33, -14.3); FIRES.append((-33, -14.3)); P('trash_cans', -40.5, -14.2, 0); P('trash_cans', -3, -14.2, 0); P('mailbox', -46.6, -14.4, 180, 1.15)
cluster('«ШАУРМА 67»', 44, -9.5, 'место очереди перед окном свободно; за ларьком ящики и поддоны; бак сбоку; почтовый ящик у остановки')
for q in BACK[1]: P(q[0], 44 + q[1], -5.4 + q[2], q[3], q[4])
P('pallets', 39.2, -5.2, 0, 0.7); P('trash_cans', 48.4, -14.4, 0); P('mailbox', 50.2, -14.6, 180, 1.15); P('barrel_stove', 40.2, -13.6); FIRES.append((40.2, -13.6))
cluster('шиномонтаж и Молния', 86, -6, 'стопка покрышек у ворот, бочка-печка, поддоны; Молния стоит у бокса')
for x, y, z in ((90.5, -5.0, 0), (91.3, -4.4, 0), (90.3, -3.8, 0), (90.7, -4.5, 0.17), (79.2, -3.2, 0)): P('tyre_old', x, y, 0, None, z)
P('barrel_stove', 88.6, -3.2); FIRES.append((88.6, -3.2)); P('pallets', 77.6, -2.6, 0, 0.6); P('trash_cans', 88, -13.4, 0); P('mailbox', 79.6, -14.2, 180, 1.15)
cluster('«ПРОДУКТЫ 24»', 96, -50, 'разгрузка сзади: поддоны и коробки; почтовый ящик и урна у входа')
P('pallets', 99, -38.4, 0, 0.7)
for q in BACK[0]: P(q[0], 93 + q[1], -38.6 + q[2], q[3], q[4], q[5] if len(q) > 5 else 0.0)
P('mailbox', 90, -62, 180, 1.15); P('urn_red', 102, -62.2)

# ================= ГАРАЖИ
cluster('мастерская ГСК', -58, 20, 'рабочий угол мастера: покрышки, бочки, печка, поддоны, диван для перекура')
for x, y, z in ((-56, 20.5, 0), (-55.3, 21.0, 0), (-56.2, 21.4, 0), (-55.8, 20.9, 0.17)): P('tyre_old', x, y, 0, None, z)
P('barrel_stove', -55.4, 18.2); FIRES.append((-55.4, 18.2)); P('pallets', -56.6, 23.6, 90, 0.6); P('barrel_blue', -55.4, 9.4); P('barrel_blue', -55.2, 10.4); P('sofa_set', -56.4, 26.2, 90)
cluster('открытый блок № 64', -60, 46, 'покрышки у ворот, бочка за углом')
P('tyre_old', -63, 36.2); P('tyre_old', -64.4, 36.9); P('barrel_blue', -62, 56)
cluster('гаражи у дома Пахана', -50, -92, 'покрышки и бочка у ворот; ракушки и диван у гаража в граффити')
P('tyre_old', -49, -98); P('tyre_old', -48.4, -97.3); P('barrel_blue', -49, -100.2); P('garage_metal_1', -40, -65.6, 0); P('garage_metal_3', -36.3, -65.6, 0); P('sofa_set', -48.2, -63.4, 180)
cluster('гаражный двор у башен', 114, 24, 'территория смотрящего: диван, печка, бочки, покрышки, поддоны, «буханка»')
P('sofa_set', 114, 25.4, 0); P('barrel_stove', 110.2, 26); FIRES.append((110.2, 26)); P('barrel_blue', 97, 25); P('barrel_blue', 126.2, 25.2); P('tyre_old', 104, 25.6); P('tyre_old', 104.7, 26.1); P('pallets', 118, 14.2, 0, 0.6)
cluster('ракушки двора 61–63', 126, -64, 'две жестяные ракушки у торца дома')
P('garage_metal_2', 124, -63.6, 0); P('garage_metal_4', 127.7, -63.6, 0)

# ================= МАШИНЫ: карманы парковок, вдоль бордюра, у гаражей
def lot(name, pid, rows, pat):
    it = IT[pid]; cluster('парковка ' + name, it['x'], it['y'], 'машины носом к краю, по разметке карманов; в конце — вал снега от расчистки')
    n = int((it['w'] - 3) / 2.8); k = 0
    for ri, ry in enumerate(rows):
        for i in range(n):
            if pat[(i + ri * 2) % len(pat)] == '1': P(CARS[k % 5], it['x'] - it['w'] / 2 + 2.2 + i * 2.8, it['y'] + ry, 0 if ri == 0 else 180); k += 1
    P('snow_pile', it['x'] + it['w'] / 2 + 2.4, it['y'], 90, 1.5); P('snow_pile', it['x'] - it['w'] / 2 - 2.2, it['y'] + it['h'] / 2 - 2, 60, 1.0)
lot('двора Пахана', 'PARK1', (2.4, -2.4), '10110'); lot('двора 61–63', 'PARK2', (3.8, -3.8), '11010'); lot('двора панелек', 'PARK3', (4.6, -4.6), '10101')
cluster('машины вдоль улицы Облачной', 0, -21, 'припаркованы у северного бордюра, вне остановки и перекрёстка')
for i, x in enumerate((-128, -112, -84, -40, -16, 12, 98, 120, 136)): P(CARS[i % 5], x, -21.3, 90 if i % 2 else -90)
cluster('машины в проездах', -62, -90, 'вдоль дворовых проездов с одной стороны, чтобы оставался проезд')
for i, y in enumerate((-118, -104, -92, -70, -58)): P(CARS[(i + 2) % 5], -61.9, y, 0 if i % 2 else 180)
for i, y in enumerate((10, 52, 70)): P(CARS[(i + 1) % 5], -68.2, y, 0)
P('van_uaz452', -71.8, 30, 180); P('van_uaz452', 100, 31.8, 90); P(CARS[0], 122, 32.2, 90); P(CARS[3], 108.5, 32.2, -90)
for i, x in enumerate((-40, -26, 34, 48)): P(CARS[(i + 3) % 5], x, 85.5, 90 if i % 2 else -90)
P(CARS[1], -120, 30.6, 90); P(CARS[4], -92, 36.4, -90); P(CARS[2], -110, 75.6, 90)

# ================= СНЕГ ОТ РАСЧИСТКИ: валы между тротуаром и дорогой, равномерно, с разрывами у проездов
cluster('снежные валы улицы Облачной', 0, -24, 'вал вдоль обоих бордюров через 9 м; разрывы у остановки, перекрёстка, проездов и троп')
SK = [1.0, 1.4, 0.9, 1.6, 1.2]
SKIP_X = ((66, 0, 10), (-64, 0, 5), (-70, 0, 5), (18, 0, 6), (44, 0, 15), (-26, 0, 0))
i = 0
for x in range(-142, 146, 9):
    if any(abs(x - sx) < sr for sx, _, sr in SKIP_X): continue
    P('snow_pile', x, -16.3 if i % 2 == 0 else -31.7, 0 if i % 3 else 180, SK[i % 5]); i += 1
cluster('снежные валы улицы Битной', 66, 0, 'вал вдоль обоих бордюров через 9 м')
i = 0
for y in range(-138, 140, 9):
    if abs(y + 24) < 10 or abs(y - 88) < 7 or abs(y - 30) < 6: continue
    P('snow_pile', 58.3 if i % 2 == 0 else 73.7, y, 90, SK[(i + 2) % 5]); i += 1

# ================= ЛЮКИ, БЛОКИ, ЩИТЫ, ВОРОНЫ
cluster('люки', 0, -22.4, 'по оси полос на улицах через равные промежутки; по одному в каждом проезде')
for x in range(-130, 140, 34): P('manhole', x, -22.4, 0)
for y in range(-120, 130, 38): P('manhole', 64.4, y, 0)
for x, y in ((0, -100), (-64, -90), (114, 30), (6, 88), (-70, 40), (108, -86), (-98, -76)): P('manhole', x, y, 0)
cluster('бетонные блоки', 0, 0, 'закрывают сквозной проезд во дворы и тупики улиц; два — по краям арки')
for x, y, yw, m in ((-70, -46.5, 0, 1), (-71.8, -46.5, 0, 2), (-66.2, 93, 0, 1), (-73.8, 93, 0, 2), (92, 34.5, 90, 1), (62, 142, 0, 1), (70, 142, 0, 2), (62, -142, 0, 2), (70, -142, 0, 1),
                     (33.9, 108.6, 90, 1), (33.9, 123.4, 90, 2)):
    P('barrier_%d' % m, x, y, yw)
cluster('щиты', 0, 0, 'советские — на улице у дворов; рекламные — у перекрёстка и на въездах')
P('billboard_soviet', -96, -15.6, 90); P('billboard_soviet', 110, -14.2, 90); P('billboard_ad', 76, -36.5, 0); P('billboard_ad', 55, 40, 90); P('billboard_ad', -141, -36.5, 0)
cluster('вороны', 0, 0, 'у еды и мусора: рынок, ларёк, лавки')
for x, y in ((-28, -13.2), (-27.2, -13.8), (46.2, -15.4), (0.5, -78), (-99, -84.5), (115, 94.6), (-18, 28)): P('crow_2', x, y, 60, 1.2)

# ================= ПРОВЕРКА
def rad(p):
    s = LIB[p['m']]['size']; return max(s[0], s[1]) / 2 * (p['k'] or 1.0)
FLAT = ('manhole',); ONROAD = FLAT + tuple(CARS) + ('van_uaz452',)
HOUSES = [i for i in LAY['items'] if i['model'] and not i.get('mark') and i['cat'] in ('res', 'gar', 'act', 'boss') ] + [IT['COURT'], IT['PITCH']]
ROADS = [i for i in LAY['items'] if i['id'].startswith('ROAD')]
CAMS = ((-58, -20.5), (-22, -104), (-72, 34), (-52, -17.5), (-20, 93), (10, 30), (40, -31), (82, -18.6), (-74, -78), (-30, 4), (86, 104), (82, -68), (-84, 96), (37, -19.5), (-98, -62), (-66.5, 22), (-52, -2), (-1, 91.5), (24, 104))
def inside(p, it, pad):
    return abs(p['x'] - it['x']) < it['w'] / 2 + pad and abs(p['y'] - it['y']) < it['h'] / 2 + pad
def near_path(p, d):
    for pts in LAY.get('paths', []):
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            dx, dy = bx - ax, by - ay; t = max(0, min(1, ((p['x'] - ax) * dx + (p['y'] - ay) * dy) / max(dx * dx + dy * dy, 1e-6)))
            if math.hypot(p['x'] - ax - dx * t, p['y'] - ay - dy * t) < d: return True
    return False
def check():
    ok = []; bad = []
    for p in PROPS:
        if p['m'] not in LIB: bad.append((p, 'нет модели')); continue
        r = rad(p); why = ''
        if any(inside(p, h, min(r, 0.6) * 0.5) for h in HOUSES) and p['m'] not in FLAT: why = 'в постройке'
        elif p['m'] not in ONROAD and any(inside(p, rd, 0) for rd in ROADS): why = 'на проезжей части'
        elif p['m'].startswith(('tree_', 'pine_', 'snow_pine', 'bush_', 'snow_pile', 'laundry', 'rocket')) and near_path(p, 1.6 + min(r, 1.5) * 0.5): why = 'на тропе'
        elif p['m'].startswith(('tree_', 'pine_', 'snow_pine')) and any(math.hypot(p['x'] - cx, p['y'] - cy) < 5 for cx, cy in CAMS): why = 'перед точкой съёмки'
        elif p['z'] == 0 and p['m'] not in FLAT:
            for q in ok:
                if q['z'] == 0 and q['m'] not in FLAT and math.hypot(p['x'] - q['x'], p['y'] - q['y']) < 0.75 * (min(r, 2.2) + min(rad(q), 2.2)) and not (p['c'] == q['c'] and ((r < 1.0 and rad(q) < 1.0) or (p['m'] in ONROAD and q['m'] in ONROAD))):
                    why = 'вплотную к «%s»' % q['m']; break
        (bad if why else ok).append((p, why) if why else p)
    return ok, bad

if __name__ == '__main__':
    ok, bad = check()
    for c in CLUSTERS: c['n'] = sum(1 for p in ok if p['c'] == c['name'])
    json.dump({'props': ok, 'clusters': CLUSTERS, 'entr': ENTR, 'fires': FIRES}, open(os.path.join(W, 'topdown_layout', 'DVOR_PROPS.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=0)
    print('props', len(ok), 'dropped', len(bad), 'clusters', len(CLUSTERS))
    for p, why in bad: print('  DROP', p['m'], p['x'], p['y'], '|', p['c'], '|', why)
    # карта расстановки
    from PIL import Image, ImageDraw, ImageFont
    S = 6; x0, x1 = LAY['x']; y0, y1 = LAY['y']
    im = Image.new('RGB', (int((x1 - x0) * S), int((y1 - y0) * S)), (232, 236, 242)); d = ImageDraw.Draw(im)
    def px(x, y): return ((x - x0) * S, (y1 - y) * S)
    for it in LAY['items']:
        if it.get('mark') or it['id'] == 'snow': continue
        col = {'res': (196, 164, 100), 'gar': (150, 96, 70), 'road': (96, 100, 108), 'walk': (176, 180, 188), 'boss': (200, 70, 60), 'act': (236, 190, 60)}.get(it['cat'])
        if col:
            a = px(it['x'] - it['w'] / 2, it['y'] + it['h'] / 2); b = px(it['x'] + it['w'] / 2, it['y'] - it['h'] / 2); d.rectangle((a[0], a[1], b[0], b[1]), fill=col)
    CAT = (('tree_', (60, 110, 70)), ('pine', (30, 90, 60)), ('snow_pine', (30, 90, 60)), ('bush', (120, 150, 110)), ('car_', (40, 60, 160)), ('van_', (40, 60, 160)), ('snow_pile', (255, 255, 255)),
           ('dumpster', (20, 20, 20)), ('manhole', (70, 70, 70)))
    for p in ok:
        col = next((c for k, c in CAT if p['m'].startswith(k)), (200, 40, 40)); r = max(2, rad(p) * S * 0.6); a = px(p['x'], p['y'])
        d.ellipse((a[0] - r, a[1] - r, a[0] + r, a[1] + r), fill=col, outline=(30, 30, 30))
    f = ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', 13)
    for i, c in enumerate(CLUSTERS):
        if c['x'] == 0 and c['y'] == 0: continue
        a = px(c['x'], c['y']); t = str(i + 1); d.ellipse((a[0] - 11, a[1] - 11, a[0] + 11, a[1] + 11), fill=(250, 230, 90), outline=(20, 20, 20)); d.text((a[0] - 4 * len(t), a[1] - 8), t, font=f, fill=(20, 20, 20))
    im.save(os.path.join(W, 'topdown_layout', 'DVOR_PROP_PLACEMENT_MAP.png'))
    rows = ['| № | Кластер | Центр (X; Y) | Предметов | Правило расстановки |', '|---|---|---|---|---|']
    for i, c in enumerate(CLUSTERS): rows.append('| %d | %s | %s | %d | %s |' % (i + 1, c['name'], ('%g; %g' % (c['x'], c['y'])) if (c['x'] or c['y']) else 'по району', c['n'], c['role']))
    open(os.path.join(W, 'topdown_layout', 'DVOR_PROPS_TABLE.md'), 'w', encoding='utf-8').write('\n'.join(rows) + '\n')
