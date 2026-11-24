"""ДВОР, редизайн V4: пятая партия — мелочь с Poly Haven (CC0): блоки, покрышка, мешок, бочка, баки.
Исходники: source_references/polyhaven/<id>/ (качает %TEMP%/dvor/ph_get.py), в .glb переводит ph_conv.py.
blender --background --python tools/blender/dvor_extract5.py"""
import os, json
_src = open(os.path.join(os.path.dirname(__file__), 'dvor_extract2.py'), encoding='utf-8').read()
exec(_src.split("whole('soviet_residential_building'")[0])

whole('ph_concrete_road_barrier', 'barrier_1', 'streets', 'бетонный блок в полоску (Poly Haven, CC0)')
whole('ph_concrete_road_barrier_02', 'barrier_2', 'streets', 'бетонный блок (Poly Haven, CC0)')
whole('ph_old_tyre', 'tyre_old', 'props', 'старая покрышка (Poly Haven, CC0)')
whole('ph_trashbag', 'trashbag', 'props', 'мусорный мешок (Poly Haven, CC0)')
whole('ph_barrel_03', 'barrel_blue', 'props', 'синяя бочка (Poly Haven, CC0)')
whole('ph_metal_trash_can', 'trash_cans', 'props', 'два ржавых бака с крышками (Poly Haven, CC0)')

json.dump(LIB, open(os.path.join(OUT, 'library.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('DONE', len(LIB))
