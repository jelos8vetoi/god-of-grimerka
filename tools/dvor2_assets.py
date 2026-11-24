"""ДВОР 2: собрать игровые ассеты нового района. Один запуск делает всё:
  1) Blender: tools/blender/dvor_arch.py (арка дома № 81) и tools/blender/dvor2_export.py (части района одной сеткой, тяжёлые упрощены);
  2) Godot: scripts/glbslim.gd — текстуры внутри .glb до 1024 (дома) или 512 (предметы), JPEG;
  3) пишет godot/assets/golda67/dvor2/<id>.glb и данные godot/data/dvor2/{layout,props,manifest}.json.
Готовые .glb и данные лежат в git — для запуска игры ничего пересобирать не нужно. Этот скрипт — чтобы воспроизвести их из библиотеки частей
(godot/assets/golda67/dvor_redesign_work/architecture_parts, в git не идёт — исходные модели владельца и Sketchfab).
python tools/dvor2_assets.py [--skip-blender]
Нужны: Blender 5.x (путь — переменная BLENDER или значение ниже), Godot 4.7.2 в tools/godot/."""
import os, sys, json, subprocess, shutil, tempfile
R = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
W = os.path.join(R, 'godot', 'assets', 'golda67', 'dvor_redesign_work')
BL = os.environ.get('BLENDER', r'D:\SteamLibrary\steamapps\common\Blender\blender.exe')
GD = os.path.join(R, 'tools', 'godot', 'Godot_v4.7.2-stable_win64_console.exe')
if not os.path.exists(GD): GD = os.path.join(R, 'tools', 'godot', 'Godot_v4.7.2-stable_win64.exe')
SRC = os.path.join(tempfile.gettempdir(), 'dvor', 'dvor2_src')
OUT = os.path.join(R, 'godot', 'assets', 'golda67', 'dvor2'); DATA = os.path.join(R, 'godot', 'data', 'dvor2')
os.makedirs(OUT, exist_ok=True); os.makedirs(DATA, exist_ok=True)
if '--skip-blender' not in sys.argv:
    subprocess.run([BL, '--background', '--python', os.path.join(R, 'tools', 'blender', 'dvor_arch.py')], check=True, stdout=subprocess.DEVNULL)
    subprocess.run([BL, '--background', '--python', os.path.join(R, 'tools', 'blender', 'dvor2_export.py'), '--', SRC], check=True, stdout=subprocess.DEVNULL)
man = json.load(open(os.path.join(SRC, 'manifest.json'), encoding='utf-8'))
lib = json.load(open(os.path.join(W, 'architecture_parts', 'library.json'), encoding='utf-8'))
man['res_arch_81']['stairs'] = lib['res_arch_81']['stairs']
total = 0
for i in sorted(man):
    big = max(man[i]['size']); lim = 1024 if (man[i]['section'] == 'buildings' or big > 12) else 512
    dst = os.path.join(OUT, i + '.glb')
    r = subprocess.run([GD, '--headless', '--path', os.path.join(R, 'godot'), '--script', 'res://scripts/glbslim.gd', '--', os.path.join(SRC, i + '.glb'), dst, str(lim)], capture_output=True, text=True, encoding='utf-8', errors='replace')
    if not os.path.exists(dst): shutil.copy(os.path.join(SRC, i + '.glb'), dst); print('COPY (не облегчилось)', i)
    man[i]['kb'] = round(os.path.getsize(dst) / 1024); total += man[i]['kb']
    print(i, man[i]['kb'], 'КБ', flush=True)
json.dump(man, open(os.path.join(DATA, 'manifest.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
shutil.copy(os.path.join(W, 'topdown_layout', 'DVOR_TOPDOWN_RECOMMENDED.layout.json'), os.path.join(DATA, 'layout.json'))
shutil.copy(os.path.join(W, 'topdown_layout', 'DVOR_PROPS.json'), os.path.join(DATA, 'props.json'))
print('ИТОГО', len(man), 'моделей', round(total / 1024), 'МБ')
