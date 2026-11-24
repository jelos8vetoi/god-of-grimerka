"""ДВОР, редизайн: вторая партия моделей владельца (2026-11-24) и две модели со Sketchfab -> библиотека частей.
blender --background --python tools/blender/dvor_extract2.py   (дополняет architecture_parts/library.json)"""
import os, json
_src = open(os.path.join(os.path.dirname(__file__), 'dvor_extract.py'), encoding='utf-8').read()
exec(_src.split('# ---------------- жилой комплекс')[0])
LIB.update(json.load(open(os.path.join(OUT, 'library.json'), encoding='utf-8')))

def top(o, depth=3):
    """Предок на заданной глубине от корня сцены — так наборы Sketchfab делятся на отдельные предметы."""
    chain = []
    while o is not None:
        chain.append(o); o = o.parent
    chain.reverse()
    return chain[min(depth, len(chain) - 1)]

def whole(name, pid, sec, note, k=1.0, height=None, pick=None):
    sc, cam, ms = load(name)
    if pick:
        keep = pick(ms)
        for o in ms:
            if o not in keep: bpy.data.objects.remove(o)
        ms = keep
    o = join(sc, ms, pid)
    if height:
        lo, hi = bbox([o]); k = height / (hi.z - lo.z)
    place(o, k); emit(sc, cam, o, sec, pid, name, note)

def pieces(name, prefix, sec, note, k=1.0, depth=3, limit=99, key=None):
    sc, cam, ms = load(name)
    grp = {}
    for o in ms: grp.setdefault(top(o, depth).name, []).append(o)
    objs = [join(sc, g, 'p%d' % i) for i, g in enumerate(grp.values())]
    objs.sort(key=key or (lambda o: bbox([o])[0].x))
    for i, o in enumerate(objs[:limit]):
        place(o, k); emit(sc, cam, o, sec, '%s_%d' % (prefix, i + 1), name, note)
    print('PIECES', name, len(objs))

def main_only(ms):
    big = max(ms, key=lambda o: (bbox([o])[1] - bbox([o])[0]).length)
    lo, hi = bbox([big]); pad = (hi - lo) * 0.03
    def inside(o):
        l, h = bbox([o]); c = (l + h) / 2
        return all(lo[i] - pad[i] <= c[i] <= hi[i] + pad[i] for i in range(3))
    return [o for o in ms if inside(o)]

whole('soviet_residential_building', 'res_brick_5', 'buildings', 'кирпичная пятиэтажка, скатная крыша', 0.85)
whole('soviet_panel_house', 'res_panel_9', 'buildings', 'панельная девятиэтажка-башня, антенны', 0.17)
whole('low_poly_-_soviet__apartment_building_8k', 'res_panel_7', 'buildings', 'серая панельная семиэтажка', height=21.0)
whole('russian_panel_house_asset', 'res_long_9', 'buildings', 'длинный девятиэтажный дом-«стена»', height=27.0, pick=main_only)
pieces('soviet_panelki__voxel_style_apartment_buildings', 'res_voxel', 'buildings', 'пятиэтажка в воксельной манере', 1.0, depth=3, key=lambda o: bbox([o])[0].y)
whole('football_stadium', 'pitch_fenced', 'streets', 'футбольная коробка с сеткой и воротами', height=8.0)
whole('laz-699_soviet_bus', 'bus_laz', 'props', 'автобус ЛАЗ-699')
whole('lightning_mcqueen_xbox_360', 'mcqueen', 'props', 'Молния Маккуин (персонаж Disney/Pixar, модель из игры для Xbox 360)', 0.3)
whole('low-poly_russian_kiosk_meal_bread_and_techno', 'market_row_3', 'streets', 'три ларька в ряд: мясо, хлеб, «ТЕХНО-СКЛАД»')
whole('old_soviet_bench_rework', 'bench_concrete', 'props', 'лавка с бетонными боковинами')
whole('old_soviet_railway_station_kiosk', 'kiosk_grey', 'streets', 'серый киоск с шатровой крышей')
whole('post-soviet_kiosk_psx_style', 'kiosk_blue', 'streets', 'бело-синий ларёк')
whole('roadside_building', 'shop_cafe_tyre', 'buildings', 'придорожный дом: кафе, магазин, шиномонтаж, банкомат')
whole('roadside_shop_and_cafe_updated', 'shop_house', 'buildings', 'дом с магазином, пристройкой и двориком за забором', 0.05)
whole('soviet_brick_storage__garage_low_poly', 'garage_row_brick', 'garages', 'кирпичный ряд боксов на 26 м')
whole('staircase_modular_frame_-_steel', 'stair_steel', 'props', 'стальная пожарная лестница в четыре марша')
whole('the_soviet_fence', 'fence_rhombus', 'walls', 'бетонная плита забора «ромбик»')
pieces('zhiguli_soviet_cars', 'car_zhiguli', 'props', '«Жигули»', 1.0, depth=3)
whole('dvor_smoke_stacks', 'smoke_stacks', 'buildings', 'дымовые трубы котельной (Sketchfab, FrodoUndead, CC-BY)', height=42.0)
whole('dvor_white_tower', 'white_tower', 'buildings', 'водонапорная башня-конструктивизм (Sketchfab, monray, CC-BY)', height=29.0)
pieces('simple_collection_of_low_poly_street_lights_v3', 'lamp', 'streets', 'уличный фонарь', 1.0, depth=3, limit=6, key=lambda o: -(bbox([o])[1].z - bbox([o])[0].z))
pieces('simple_low_poly_street_trafic_lights', 'traffic', 'streets', 'светофор', 1.0, depth=3, limit=3, key=lambda o: -(bbox([o])[1].z - bbox([o])[0].z))

json.dump(LIB, open(os.path.join(OUT, 'library.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('DONE', len(LIB))
