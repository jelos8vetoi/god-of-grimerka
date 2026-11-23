"""ДВОР, редизайн: планы сверху (PNG + SVG) и раскладка для 3D-блокаута (JSON) из одного описания.
python tools/dvor_plan.py  ->  godot/assets/golda67/dvor_redesign_work/topdown_layout/
Координаты плана: метры, X — восток, Y — север (в Godot: x = X, z = -Y)."""
import json, os, math
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(__file__), '..', 'godot', 'assets', 'golda67', 'dvor_redesign_work', 'topdown_layout')
PX = 9  # пикселей на метр
CAT = {  # категория: (заливка, обводка, подпись в легенде)
    'res': ((196, 160, 96), (90, 66, 30), 'Жилые дома'),
    'gar': ((150, 92, 62), (70, 40, 26), 'Гаражи и технические постройки'),
    'open': ((226, 230, 236), (170, 176, 186), 'Открытые пространства (снег, тропы)'),
    'road': ((92, 96, 104), (56, 58, 64), 'Дороги и парковки'),
    'act': ((240, 190, 60), (150, 110, 10), 'Будущие интерактивные зоны'),
    'boss': ((200, 60, 56), (110, 20, 20), 'Босс-арена (коробка Миши)'),
    'sec': ((150, 104, 190), (84, 50, 120), 'Секретные и второстепенные участки'),
    'deco': ((52, 60, 78), (30, 34, 46), 'Декорации, недоступно'),
}
def font(sz, bold=False):
    try: return ImageFont.truetype('arialbd.ttf' if bold else 'arial.ttf', sz)
    except Exception: return ImageFont.load_default()

def R(id, cat, cx, cy, w, h, label='', model='', yaw=0, z=0.0, hgt=3.0):
    return {'k': 'rect', 'id': id, 'cat': cat, 'cx': cx, 'cy': cy, 'w': w, 'h': h, 'label': label, 'model': model, 'yaw': yaw, 'hgt': hgt}
def Z(n, cx, cy, r, label): return {'k': 'zone', 'n': n, 'cx': cx, 'cy': cy, 'r': r, 'label': label}
def P(kind, pts, label=''): return {'k': 'path', 'kind': kind, 'pts': pts, 'label': label}
def M(cx, cy, label, cat='gar', model='', yaw=0, r=1.2): return {'k': 'mark', 'cx': cx, 'cy': cy, 'label': label, 'cat': cat, 'model': model, 'yaw': yaw, 'r': r}
def T(cx, cy, text, sz=13, col=(40, 44, 54)): return {'k': 'text', 'cx': cx, 'cy': cy, 'text': text, 'sz': sz, 'col': col}

def garages(prefix, x, y0, n, face, pitch=3.2, start=1):
    """Ряд жестяных гаражей вдоль Y: x — центр ряда, face — куда ворота (1 — восток, -1 — запад)."""
    out = []
    for i in range(n):
        out.append(R('%s%d' % (prefix, i + 1), 'gar', x, y0 + i * pitch, 4.4, 2.9, '', 'garage_tin_%d' % ((i + start) % 5 + 1), 90 if face > 0 else -90, hgt=2.5))
    return out
def garages_x(prefix, x0, y, n, face, pitch=3.2, start=1):
    out = []
    for i in range(n):
        out.append(R('%s%d' % (prefix, i + 1), 'gar', x0 + i * pitch, y, 2.9, 4.4, '', 'garage_tin_%d' % ((i + start) % 5 + 1), 180 if face < 0 else 0, hgt=2.5))
    return out

# ============================================================ ВАРИАНТ A — компактный квартал «Колодец»
A = {'name': 'ВАРИАНТ A — компактный квартал «КОЛОДЕЦ»', 'file': 'DVOR_TOPDOWN_VARIANT_A', 'x': (-58, 58), 'y': (-53, 71), 'items': [
    R('snow', 'open', 0, 9, 116, 124),
    # границы-декорации
    R('D_S', 'deco', 0, -51.5, 116, 3, 'улица Облачная (за домом, недоступно)'),
    R('D_W', 'deco', -56.5, 10, 3, 120, ''),
    R('D_N', 'deco', 0, 69.5, 116, 3, 'бетонный забор · теплотрасса · башни на горизонте'),
    R('ROAD_E', 'road', 55, 9, 6, 122, ''),
    R('WALK_E', 'open', 50.5, 9, 3, 122, ''),
    # жилые дома
    R('H1', 'res', -6, -40, 32, 18, 'H1 · ДОМ 67\nдом Пахана', 'res_block_a', 180, hgt=13.3),
    R('H2', 'res', 40, -6, 18, 35, 'H2 · ДОМ 65', 'res_block_b', 90, hgt=13.3),
    R('H3', 'res', -8, 27, 32, 18, 'H3 · ДОМ 69', 'res_block_a', 0, hgt=13.3),
    R('H3A', 'res', 16, 27, 15.2, 9, 'АРКА', 'game:g67_house_arch', 0, hgt=13.6),
    # гаражный квартал
    *garages('GW', -52.5, -27.5, 10, 1),
    *garages('GIa', -41.2, -21, 6, -1, start=2),
    *garages('GIb', -36.8, -21, 6, 1, start=4),
    R('G_SHELL', 'gar', -29.5, -27, 2.7, 6.3, '', 'garage_shell_graffiti', 90, hgt=1.9),
    R('G_BRICK', 'gar', -47, 10, 7.2, 11.3, 'МАСТЕРСКАЯ', 'garage_brick_double', 0, hgt=4.4),
    R('G_45', 'gar', -37.5, 9, 3.8, 6, '№45', 'garage_concrete_45', 0, hgt=2.8),
    R('G_64', 'gar', -32, 9, 4.2, 3.6, '№64', 'game:g67_garage_open', 0, hgt=2.8),
    R('TP', 'gar', 38, 24, 5, 4.4, 'ТП', 'game:racing/transformer_booth', 0, hgt=3.4),
    # дороги и парковки
    R('PARK', 'road', 21, -33, 18, 10, 'парковка'),
    R('LANE_G1', 'road', -46.8, -12, 6.6, 34, ''),
    R('LANE_G2', 'road', -31, -12, 7, 34, ''),
    R('LANE_B', 'road', 5, 40, 90, 8, 'ЗАДНИЙ ПРОЕЗД'),
    R('SVC', 'road', 38, 17, 22, 7, 'хоздвор'),
    # арена
    R('COURT', 'boss', 16, 55.2, 26, 22.5, 'КОРОБКА МИШИ\n26 × 22,5 м', 'court', 0, hgt=1.2),
    M(16, 64.5, 'трон', 'boss', 'game:g67_misha_throne', 180),
    M(33, 55, 'трибуна', 'boss', 'game:g67_tribune', -90, 2.2),
    M(-1, 62, 'машина Миши', 'boss', 'game:g67_misha_car', 90, 1.8),
    # секреты и второстепенное
    R('NOOK', 'sec', -42, 28, 24, 16, 'НЫЧКА\nбеседка за мастерской'),
    R('SLOT', 'sec', -27.2, 37, 3.2, 4, ''),
    R('ROOFS', 'sec', -39, -13, 8.8, 19.2, 'крыши\nгаражей'),
    R('BEHIND', 'sec', 26, 48, 4, 10, ''),
    # ориентиры и реквизит
    M(4, -8, 'детская площадка', 'open', 'game:racing/playground', 0, 5.5),
    M(-10, -4, 'ковровыбивалка, вешалка', 'open', 'game:g67_carpet_rack', 0, 1.4),
    M(-36, 24, '', 'sec', 'game:racing/gazebo', 20, 2.2),
    M(25, -45, '«ШАУРМА 67»', 'act', 'game:g67_shawarma_kiosk', 0, 2.4),
    M(50.5, -30, 'остановка', 'road', 'bus_stop_blue', -90, 2.6),
    M(30, 16, 'баки', 'gar', 'dumpster_blue', 0, 1.2),
    M(46, 20, 'электрошкафы', 'gar', 'elbox_rusty_pair', 180, 1.0),
    M(3, -29.5, '', 'open', 'bench_siberian', 0, 1.0),
    M(18, 6, 'ели', 'open', 'snow_pine_1', 0, 2.4), M(-16, 10, '', 'open', 'snow_pine_2', 0, 2.0), M(22, 9, '', 'open', 'snow_pine_3', 0, 1.2),
    M(17, -33, '', 'road', 'car_vaz_21099', 0, 1.2), M(22, -33.5, '', 'road', 'car_vaz_21099', 180, 1.2),
    # входы
    T(-6, -29.6, '▲ дверь подъезда (дом)', 12, (120, 30, 20)),
    T(16, 43.2, '▲ калитка', 12, (120, 20, 20)),
    # будущие интерактивные зоны
    Z(1, 13, -15, 3, 'Двор-колодец: площадка'), Z(2, -31, -16, 3, 'Гаражный остров и проезды'), Z(3, 27, -29.5, 3, 'Парковка у «ШАУРМЫ 67»'),
    Z(4, 44, 15, 3, 'Хоздвор у ТП'), Z(5, -14, 40, 3, 'Задний проезд перед коробкой'), Z(6, 21, 21.5, 2.6, 'Арка'),
    Z(7, -50, 33, 3, 'Нычка с беседкой'), Z(8, -47, 18.5, 2.6, 'Мастерская'), Z(9, 50.5, -20, 2.6, 'Остановка и тротуар'),
    # маршруты
    P('main', [(-6, -30), (-2, -18), (4, -2), (12, 12), (16, 22), (16, 32), (16, 43.5)], 'главный: подъезд → двор → арка → калитка'),
    P('alt', [(-4, -12), (-22, -10), (-31, -8), (-31, 4), (-30, 16), (-28, 30), (-27.2, 37), (-20, 40), (2, 41)], 'гаражи → нычка → дыра в заборе → задний проезд'),
    P('alt', [(8, -26), (21, -28), (30, -27), (50.5, -27), (50.5, 14), (40, 17), (32, 30), (32, 39), (26, 41)], 'парковка → тротуар → хоздвор → задний проезд'),
]}

# ============================================================ ВАРИАНТ B — открытый район «Улица и пустырь»
B = {'name': 'ВАРИАНТ B — открытый район «УЛИЦА И ПУСТЫРЬ»', 'file': 'DVOR_TOPDOWN_VARIANT_B', 'x': (-78, 78), 'y': (-58, 58), 'items': [
    R('snow', 'open', 0, 0, 156, 116),
    R('ROAD_S', 'road', 0, -53.5, 156, 9, 'улица Облачная'),
    R('WALK_S', 'open', 0, -47.5, 156, 3, ''),
    R('D_N', 'deco', 0, 56.5, 156, 3, 'забор · теплотрасса · башни на горизонте'),
    R('D_W', 'deco', -76.5, 4, 3, 102, ''), R('D_E', 'deco', 76.5, 4, 3, 102, ''),
    R('FF', 'road', -55, -27, 32, 30, 'ФАСТФУД\n(участок 32 × 30 м)', 'fastfood_lot', 0, hgt=7),
    R('H1', 'res', -8, -30, 32, 18, 'H1 · ДОМ 67\nдом Пахана', 'res_block_a', 180, hgt=13.3),
    R('H2', 'res', 62, -8, 18, 35, 'H2 · ДОМ 65', 'res_block_b', 90, hgt=13.3),
    R('H4', 'res', -62, 14, 18, 32, 'H4 · ДОМ 71', 'res_block_a', 90, hgt=13.3),
    R('PARK', 'road', 31, -31, 34, 24, 'парковка'),
    *garages_x('GN', -68, 50, 17, -1),
    *garages_x('GS', -50, 38.5, 8, 1, start=3),
    R('LANE_G', 'road', -40, 44.3, 62, 7, 'гаражный проезд'),
    R('G_BRICK', 'gar', -6, 46, 11.3, 7.2, 'МАСТЕРСКАЯ', 'garage_brick_double', 90, hgt=4.4),
    R('G_45', 'gar', -20, 37.5, 6, 3.8, '№45', 'garage_concrete_45', 90, hgt=2.8),
    R('G_64', 'gar', -14, 37.5, 4.2, 3.6, '№64', 'game:g67_garage_open', 0, hgt=2.8),
    R('TP', 'gar', 62, 26, 5, 4.4, 'ТП', 'game:racing/transformer_booth', 0, hgt=3.4),
    R('COURT', 'boss', 34, 34, 26, 22.5, 'КОРОБКА МИШИ\n26 × 22,5 м', 'court', 0, hgt=1.2),
    M(34, 43.5, 'трон', 'boss', 'game:g67_misha_throne', 180), M(51, 34, 'трибуна', 'boss', 'game:g67_tribune', -90, 2.2), M(17, 42, 'машина Миши', 'boss', 'game:g67_misha_car', 90, 1.8),
    R('NOOK', 'sec', -36, 16, 14, 12, ''), R('BEHIND', 'sec', -72, 44.3, 5, 7, ''),
    M(-6, -2, 'детская площадка', 'open', 'game:racing/playground', 0, 5.5),
    M(-36, 16, 'беседка', 'sec', 'game:racing/gazebo', 0, 2.2),
    M(18, -41, '«ШАУРМА 67»', 'act', 'game:g67_shawarma_kiosk', 0, 2.4),
    M(4, -47.5, 'остановка', 'road', 'bus_stop_blue', 180, 2.6),
    M(56, 16, 'баки', 'gar', 'dumpster_blue', 0, 1.2),
    M(10, 10, 'ели', 'open', 'snow_pine_1', 0, 2.4), M(-20, 6, '', 'open', 'snow_pine_2', 0, 2.0),
    T(-8, -19.6, '▲ дверь подъезда (дом)', 12, (120, 30, 20)), T(34, 21, '▲ калитка', 12, (120, 20, 20)),
    Z(1, 4, -10, 3, 'Домашний двор: площадка'), Z(2, -58, 44.3, 3, 'Гаражный проезд'), Z(3, 44, -24, 3, 'Парковка у «ШАУРМЫ 67»'),
    Z(4, -34, -30, 3, 'Фастфуд: проезд и двор'), Z(5, 22, 10, 3, 'Пустырь перед коробкой'), Z(6, 68, 20, 3, 'Хоздвор у ТП'),
    Z(7, -36, 25, 2.6, 'Беседка'), Z(8, 2.5, 40, 2.6, 'Мастерская'), Z(9, -4, -47.5, 2.6, 'Остановка'),
    P('main', [(-8, -20), (-6, -8), (6, 6), (22, 14), (34, 22)], 'главный: подъезд → двор → пустырь → калитка'),
    P('alt', [(-10, -8), (-30, 6), (-40, 24), (-40, 44), (-12, 44), (6, 40), (20, 36)], 'беседка → гаражный проезд → коробка с запада'),
    P('alt', [(8, -34), (20, -44), (48, -44), (50, -12), (52, 8), (56, 22), (50, 30)], 'парковка → вдоль дома 65 → хоздвор → коробка с востока'),
]}

def to_px(v, x0, y1):  # метры -> пиксели (Y вверх)
    return (int(round((v[0] - x0) * PX)) + 60, int(round((y1 - v[1]) * PX)) + 70)

def draw(V, extra_title=''):
    x0, x1 = V['x']; y0, y1 = V['y']
    W = int((x1 - x0) * PX) + 60 + 430; H = max(int((y1 - y0) * PX) + 70 + 60, 900)
    im = Image.new('RGB', (W, H), (246, 244, 238)); d = ImageDraw.Draw(im, 'RGBA')
    svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" font-family="Arial">' % (W, H), '<rect width="100%%" height="100%%" fill="rgb(246,244,238)"/>']
    tp = lambda p: to_px(p, x0, y1)
    def rect(it):
        a = tp((it['cx'] - it['w'] / 2, it['cy'] + it['h'] / 2)); b = tp((it['cx'] + it['w'] / 2, it['cy'] - it['h'] / 2))
        f, o, _ = CAT[it['cat']]
        d.rectangle([a, b], fill=f + (255,), outline=o, width=2 if it['cat'] != 'open' else 1)
        svg.append('<rect x="%d" y="%d" width="%d" height="%d" fill="rgb%s" stroke="rgb%s" stroke-width="2"><title>%s</title></rect>' % (a[0], a[1], b[0] - a[0], b[1] - a[1], f, o, it['id']))
        if it['cat'] == 'deco':
            for k in range(a[0] - (b[1] - a[1]), b[0], 14):
                d.line([(max(k, a[0]), a[1] + max(0, a[0] - k)), (min(k + (b[1] - a[1]), b[0]), a[1] + min(b[1] - a[1], b[0] - k))], fill=(90, 100, 124, 160), width=1)
        if it['label']:
            lines = it['label'].split('\n'); sz = 13 if min(b[0] - a[0], b[1] - a[1]) > 50 else 11
            col = (250, 248, 240) if it['cat'] in ('deco', 'road', 'boss', 'gar', 'sec') else (50, 36, 14)
            fo = font(sz, True); ty = (a[1] + b[1]) / 2 - len(lines) * (sz + 3) / 2
            for ln in lines:
                tw = d.textlength(ln, font=fo); d.text(((a[0] + b[0]) / 2 - tw / 2, ty), ln, fill=col, font=fo)
                svg.append('<text x="%d" y="%d" font-size="%d" font-weight="bold" text-anchor="middle" fill="rgb%s">%s</text>' % ((a[0] + b[0]) / 2, ty + sz, sz, col, ln))
                ty += sz + 3
    order = ['open', 'deco', 'road', 'sec', 'gar', 'res', 'boss']
    for c in order:
        for it in V['items']:
            if it['k'] == 'rect' and it['cat'] == c and it['id'] == 'snow': rect(it)
    # сетка 10 м
    fo = font(10)
    for gx in range(int(math.ceil(x0 / 10.0)) * 10, x1 + 1, 10):
        a = tp((gx, y1)); b = tp((gx, y0)); d.line([a, b], fill=(120, 130, 150, 70), width=1); d.text((a[0] - 8, a[1] - 14), str(gx), fill=(90, 96, 110), font=fo)
        svg.append('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="rgb(120,130,150)" stroke-opacity="0.3"/>' % (a + b))
    for gy in range(int(math.ceil(y0 / 10.0)) * 10, y1 + 1, 10):
        a = tp((x0, gy)); b = tp((x1, gy)); d.line([a, b], fill=(120, 130, 150, 70), width=1); d.text((a[0] - 30, a[1] - 6), str(gy), fill=(90, 96, 110), font=fo)
        svg.append('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="rgb(120,130,150)" stroke-opacity="0.3"/>' % (a + b))
    for c in order:
        for it in V['items']:
            if it['k'] == 'rect' and it['cat'] == c and it['id'] != 'snow': rect(it)
    for it in V['items']:
        if it['k'] == 'path':
            pts = [tp(p) for p in it['pts']]; col = (255, 255, 255) if it['kind'] == 'main' else (60, 150, 230)
            edge = (30, 30, 30)
            for i in range(len(pts) - 1):
                (ax, ay), (bx, by) = pts[i], pts[i + 1]; L = math.hypot(bx - ax, by - ay); n = max(int(L / 16), 1)
                for k in range(n):
                    s, e = k / n, (k + 0.55) / n
                    d.line([(ax + (bx - ax) * s, ay + (by - ay) * s), (ax + (bx - ax) * e, ay + (by - ay) * e)], fill=edge, width=7 if it['kind'] == 'main' else 6)
                    d.line([(ax + (bx - ax) * s, ay + (by - ay) * s), (ax + (bx - ax) * e, ay + (by - ay) * e)], fill=col, width=4 if it['kind'] == 'main' else 3)
            svg.append('<polyline points="%s" fill="none" stroke="rgb%s" stroke-width="4" stroke-dasharray="10 7"/>' % (' '.join('%d,%d' % p for p in pts), col))
    for it in V['items']:
        if it['k'] == 'zone':
            c = tp((it['cx'], it['cy'])); r = it['r'] * PX
            d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=(240, 190, 60, 46), outline=(190, 130, 0, 255), width=3)
            d.ellipse([c[0] - 11, c[1] - r - 11, c[0] + 11, c[1] - r + 11], fill=(240, 190, 60, 255), outline=(110, 80, 0), width=2)
            fo2 = font(13, True); tw = d.textlength(str(it['n']), font=fo2); d.text((c[0] - tw / 2, c[1] - r - 8), str(it['n']), fill=(40, 28, 0), font=fo2)
            svg.append('<circle cx="%d" cy="%d" r="%d" fill="rgb(240,190,60)" fill-opacity="0.18" stroke="rgb(190,130,0)" stroke-width="3"/><text x="%d" y="%d" font-size="13" font-weight="bold" text-anchor="middle">%d</text>' % (c[0], c[1], r, c[0], c[1] - r + 5, it['n']))
    for it in V['items']:
        if it['k'] == 'mark':
            c = tp((it['cx'], it['cy'])); r = it['r'] * PX; f, o, _ = CAT[it['cat']]
            if it['cat'] == 'open': f, o = (120, 150, 120), (60, 90, 60)
            d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=f + (235,), outline=o, width=2)
            svg.append('<circle cx="%d" cy="%d" r="%d" fill="rgb%s" stroke="rgb%s" stroke-width="2"/>' % (c[0], c[1], r, f, o))
            if it['label']:
                fo2 = font(11, True); tw = d.textlength(it['label'], font=fo2)
                d.rectangle([c[0] - tw / 2 - 3, c[1] + r + 1, c[0] + tw / 2 + 3, c[1] + r + 16], fill=(255, 255, 255, 215))
                d.text((c[0] - tw / 2, c[1] + r + 2), it['label'], fill=(30, 30, 36), font=fo2)
                svg.append('<text x="%d" y="%d" font-size="11" font-weight="bold" text-anchor="middle">%s</text>' % (c[0], c[1] + r + 13, it['label']))
        if it['k'] == 'text':
            c = tp((it['cx'], it['cy'])); fo2 = font(it['sz'], True); tw = d.textlength(it['text'], font=fo2)
            d.rectangle([c[0] - tw / 2 - 3, c[1] - 2, c[0] + tw / 2 + 3, c[1] + it['sz'] + 3], fill=(255, 255, 255, 220))
            d.text((c[0] - tw / 2, c[1]), it['text'], fill=it['col'], font=fo2)
            svg.append('<text x="%d" y="%d" font-size="%d" font-weight="bold" text-anchor="middle" fill="rgb%s">%s</text>' % (c[0], c[1] + it['sz'], it['sz'], it['col'], it['text']))
    # заголовок, север, масштаб, легенда
    d.text((60, 18), V['name'] + extra_title, fill=(24, 24, 30), font=font(24, True))
    d.text((60, 46), 'ГОЛДА 67 · ДВОР, редизайн · %d × %d м · сетка 10 м · X — восток, Y — север' % (x1 - x0, y1 - y0), fill=(70, 74, 86), font=font(13))
    svg.append('<text x="60" y="40" font-size="24" font-weight="bold">%s</text>' % (V['name'] + extra_title))
    lx = int((x1 - x0) * PX) + 60 + 26; ly = 80
    d.polygon([(lx + 30, ly), (lx + 14, ly + 44), (lx + 30, ly + 34), (lx + 46, ly + 44)], fill=(30, 30, 36)); d.text((lx + 23, ly + 48), 'С', fill=(30, 30, 36), font=font(18, True))
    d.line([(lx + 90, ly + 30), (lx + 90 + 20 * PX, ly + 30)], fill=(30, 30, 36), width=4)
    for k in (0, 10, 20): d.line([(lx + 90 + k * PX, ly + 22), (lx + 90 + k * PX, ly + 38)], fill=(30, 30, 36), width=3)
    d.text((lx + 90, ly + 42), '0        10       20 м', fill=(30, 30, 36), font=font(13, True))
    ly += 90; d.text((lx, ly), 'ЛЕГЕНДА', fill=(24, 24, 30), font=font(15, True)); ly += 26
    for c in ('res', 'gar', 'open', 'road', 'act', 'boss', 'sec', 'deco'):
        f, o, t = CAT[c]; d.rectangle([lx, ly, lx + 26, ly + 18], fill=f + (255,), outline=o, width=2); d.text((lx + 36, ly + 1), t, fill=(30, 30, 36), font=font(13)); ly += 26
    ly += 6
    d.line([(lx, ly + 8), (lx + 26, ly + 8)], fill=(30, 30, 30), width=7); d.line([(lx, ly + 8), (lx + 26, ly + 8)], fill=(255, 255, 255), width=4); d.text((lx + 36, ly), 'Главный маршрут', fill=(30, 30, 36), font=font(13)); ly += 24
    d.line([(lx, ly + 8), (lx + 26, ly + 8)], fill=(30, 30, 30), width=6); d.line([(lx, ly + 8), (lx + 26, ly + 8)], fill=(60, 150, 230), width=3); d.text((lx + 36, ly), 'Обходные маршруты', fill=(30, 30, 36), font=font(13)); ly += 34
    d.text((lx, ly), 'ЗОНЫ ДЛЯ БУДУЩИХ МЕХАНИК', fill=(24, 24, 30), font=font(14, True)); ly += 24
    for it in V['items']:
        if it['k'] == 'zone':
            d.ellipse([lx, ly, lx + 20, ly + 20], fill=(240, 190, 60), outline=(110, 80, 0), width=2)
            tw = d.textlength(str(it['n']), font=font(12, True)); d.text((lx + 10 - tw / 2, ly + 3), str(it['n']), fill=(40, 28, 0), font=font(12, True))
            d.text((lx + 30, ly + 2), it['label'], fill=(30, 30, 36), font=font(13)); ly += 25
    ly += 10; d.text((lx, ly), 'МАРШРУТЫ', fill=(24, 24, 30), font=font(14, True)); ly += 22
    for it in V['items']:
        if it['k'] == 'path':
            words = it['label'].split(' '); line = ''
            for wd in words:
                if d.textlength(line + ' ' + wd, font=font(12)) > 380:
                    d.text((lx, ly), line, fill=(50, 54, 64), font=font(12)); ly += 16; line = '   ' + wd
                else: line = (line + ' ' + wd).strip() if line else '• ' + wd
            d.text((lx, ly), line, fill=(50, 54, 64), font=font(12)); ly += 20
    svg.append('</svg>')
    return im, '\n'.join(svg)

def layout(V):
    out = []
    for it in V['items']:
        if it['k'] == 'rect' and it['id'] != 'snow':
            out.append({'id': it['id'], 'cat': it['cat'], 'x': it['cx'], 'y': it['cy'], 'w': it['w'], 'h': it['h'], 'model': it['model'], 'yaw': it['yaw'], 'hgt': it['hgt'], 'label': it['label'].replace('\n', ' ')})
        if it['k'] == 'mark' and it['model']:
            out.append({'id': it['label'] or it['model'], 'cat': it['cat'], 'x': it['cx'], 'y': it['cy'], 'w': it['r'] * 2, 'h': it['r'] * 2, 'model': it['model'], 'yaw': it['yaw'], 'hgt': 2.0, 'label': it['label'], 'mark': True})
    return {'name': V['name'], 'x': V['x'], 'y': V['y'], 'items': out}

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for V in (A, B):
        im, svg = draw(V); im.save(os.path.join(OUT, V['file'] + '.png')); open(os.path.join(OUT, V['file'] + '.svg'), 'w', encoding='utf-8').write(svg)
        json.dump(layout(V), open(os.path.join(OUT, V['file'] + '.layout.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    Rv = dict(A); Rv['file'] = 'DVOR_TOPDOWN_RECOMMENDED'; Rv['name'] = 'РЕКОМЕНДУЕМЫЙ ПЛАН — «КОЛОДЕЦ» (вариант A)'
    im, svg = draw(Rv); im.save(os.path.join(OUT, 'DVOR_TOPDOWN_RECOMMENDED.png')); open(os.path.join(OUT, 'DVOR_TOPDOWN_RECOMMENDED.svg'), 'w', encoding='utf-8').write(svg)
    json.dump(layout(Rv), open(os.path.join(OUT, 'DVOR_TOPDOWN_RECOMMENDED.layout.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print('ok')
