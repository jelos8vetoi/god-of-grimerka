"""ДВОР, редизайн V4: четвёртая партия — зимние деревья, школа, шкаф, длинный панельный дом, знаки.
blender --background --python tools/blender/dvor_extract4.py"""
import os, json
_src = open(os.path.join(os.path.dirname(__file__), 'dvor_extract2.py'), encoding='utf-8').read()
exec(_src.split("whole('soviet_residential_building'")[0])

def main_cluster(ms):
    """Дом и россыпь модулей лежат в одном файле: отделяем дом по самому большому разрыву вдоль длинной оси."""
    cs = sorted((((bbox([o])[0].y + bbox([o])[1].y) / 2, o) for o in ms), key=lambda t: t[0])
    ys = [c for c, _ in cs]
    gaps = [(ys[i + 1] - ys[i], i) for i in range(len(ys) - 1)]
    g, i = max(gaps)
    a, b = [o for _, o in cs[:i + 1]], [o for _, o in cs[i + 1:]]
    return a if len(a) > len(b) else b

pieces('dvor_ps1_pines', 'pine_ps1', 'props', 'заснеженная ель, PS1-манера (Vova Truestory)', 0.5, depth=3)
whole('dvor_winter_tree', 'tree_winter', 'props', 'голое зимнее дерево с ветками (JSLGames)', height=8.5)
whole('dvor_school', 'school', 'buildings', 'трёхэтажная школа с крыльцом (dimmeyster)', 14.0)
whole('dvor_transformer', 'elbox_tall', 'props', 'высокий электрошкаф (MrUnity)')
whole('russian_panel_house_asset', 'res_long_9', 'buildings', 'длинный девятиэтажный дом-«стена»', height=27.0, pick=main_cluster)
pieces('modular_russian_road_signs_pack_urban', 'sign', 'streets', 'дорожный знак из набора (Unka II)', 1.0, depth=3, limit=14, key=lambda o: -(bbox([o])[1].z - bbox([o])[0].z))

whole('dvor_yard_shelter', 'yard_shelter', 'props', 'дворовый навес со столом и лавками (Elasta Kristya)', height=2.9)
whole('dvor_gazebo', 'gazebo', 'props', 'деревянная беседка-шестигранник (anadaren)', height=3.4)
whole('dvor_pole_concrete', 'pole_concrete', 'streets', 'бетонный столб (Kuutti Siitonen)', height=9.0)
whole('dvor_pole_wires', 'pole_wires', 'streets', 'столб с пролётом проводов (3d.caster)', height=9.0)

json.dump(LIB, open(os.path.join(OUT, 'library.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('DONE', len(LIB))
