"""ДВОР, редизайн V3: третья партия — модели, отобранные на Sketchfab (все CC-BY), -> библиотека частей.
blender --background --python tools/blender/dvor_extract3.py"""
import os, json
_src = open(os.path.join(os.path.dirname(__file__), 'dvor_extract2.py'), encoding='utf-8').read()
exec(_src.split("whole('soviet_residential_building'")[0])

def no_plane(ms):
    """Убрать подложку-плоскость (у «буханки» под колёсами чёрный лист)."""
    return [o for o in ms if (bbox([o])[1].z - bbox([o])[0].z) > 0.05 * max((bbox(ms)[1] - bbox(ms)[0]).z, 1e-6)]

whole('dvor_dead_tree_ps1', 'tree_dead_tall', 'props', 'сухое дерево, PS1-манера (Wersaus33)', height=9.0)
pieces('dvor_dead_trees', 'tree_dead', 'props', 'сухое дерево из набора (FlunkedPunk)', 0.45, depth=3)
whole('dvor_flowerbed', 'flowerbed', 'props', 'бетонная клумба (Unka II)', 0.5)
whole('dvor_garage_block', 'garage_block_rusty', 'garages', 'ржавый гаражный блок с открытыми воротами (olegolegperepelica)')
pieces('dvor_garages_pack', 'garage_metal', 'garages', 'металлический гараж из набора (olegolegperepelica)', 1.0, depth=3)
whole('dvor_hockey_rink', 'hockey_rink', 'streets', 'хоккейная коробка с бортами, стеклом и воротами (rockleyr)', 26.0)
whole('dvor_kiosk_90s', 'kiosk_90s', 'streets', 'павильон 90-х с витринами (Vagabondare)')
whole('dvor_kiosk_rusty', 'kiosk_rusty', 'streets', 'ржавый киоск (randombug)', 0.8)
whole('dvor_payphone', 'payphone', 'props', 'таксофон (Richard Speight)', 1.6)
whole('dvor_seesaw', 'seesaw', 'props', 'качалка (targa)')
whole('dvor_sled', 'sled', 'props', 'санки (sam)', 0.25)
whole('dvor_slide', 'slide_rusty', 'props', 'ржавая горка (shtran)')
whole('dvor_snow_pile', 'snow_pile', 'props', 'сугроб с грязным снегом (Creates 3D)')
whole('dvor_swings', 'swings', 'props', 'качели (TheLastCookie-404)')
whole('dvor_trash_can', 'urn_red', 'props', 'урна (Unka II)', 0.38)
whole('dvor_uaz452', 'van_uaz452', 'props', 'УАЗ-452 «буханка» (Sergey Egelsky)', 2.0, pick=no_plane)
whole('dvor_ussr_bench', 'bench_ussr', 'props', 'лавка на гнутых трубах (TheLastCookie-404)')

json.dump(LIB, open(os.path.join(OUT, 'library.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('DONE', len(LIB))
