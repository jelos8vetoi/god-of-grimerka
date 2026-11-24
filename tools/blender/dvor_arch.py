"""ДВОР: дом № 81 с проездной аркой и спуском в Подземку (решение владельца 2026-11-25 — арку сделать в Blender).
Основа — принятая секция res_block_b: в ней прорезан сквозной проезд 10,5 × 4,6 м; внутри — кафель, колонны, балки,
лестница вниз 6 × 15 м (перепад 5 м, как у зоны «СПУСК» Подземки), решётка из двух створок (отдельные объекты gate_L / gate_R
с началом координат на петлях — для анимации открытия), цепь с замком, таблички.
blender --background --python tools/blender/dvor_arch.py
-> architecture_parts/buildings/res_arch_81.glb, blender_source/dvor_arch_81.blend, previews/res_arch_81*.png, запись в library.json
Оси модели: X — вдоль дома, Y — сквозь дом (фасад с решёткой смотрит на −Y), Z — вверх. Начало координат — центр основания дома."""
import bpy, bmesh, os, json, math
from mathutils import Vector
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'godot', 'assets', 'golda67', 'dvor_redesign_work'))
TEX = os.path.join(ROOT, 'arch_tex'); OUT = os.path.join(ROOT, 'architecture_parts')
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=os.path.join(OUT, 'buildings', 'res_block_b.glb'))
ms = [o for o in sc.objects if o.type == 'MESH']
bpy.ops.object.select_all(action='DESELECT')
for o in ms: o.select_set(True)
bpy.context.view_layer.objects.active = ms[0]
bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
if len(ms) > 1: bpy.ops.object.join()
house = bpy.context.view_layer.objects.active; house.name = 'house_81'
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for o in list(sc.objects):
    if o.type != 'MESH': bpy.data.objects.remove(o)
lo = Vector((min(v.co.x for v in house.data.vertices), min(v.co.y for v in house.data.vertices), 0)); hi = Vector((max(v.co.x for v in house.data.vertices), max(v.co.y for v in house.data.vertices), 0))
Y0, Y1 = lo.y, hi.y                      # фасады
AX = 5.25; AZ = 4.6                      # полуширина и высота проезда
SX0, SX1 = -AX, 0.75                     # полоса лестницы
GY = Y0 + 2.2                            # линия решётки
N = 30; TR = 0.5; RI = 5.0 / N           # ступени
SY1 = GY + N * TR                        # конец марша
print('HOUSE', [round(v, 2) for v in (lo.x, hi.x, Y0, Y1)], 'stairs', round(GY, 2), round(SY1, 2))

# ---------- прорезаем проезд: режем сетку плоскостями и убираем всё внутри объёма арки
bm = bmesh.new(); bm.from_mesh(house.data)
for co, no in (((-AX, 0, 0), (1, 0, 0)), ((AX, 0, 0), (1, 0, 0)), ((0, 0, AZ), (0, 0, 1))):
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=co, plane_no=no)
kill = [f for f in bm.faces if abs(f.calc_center_median().x) < AX - 0.001 and f.calc_center_median().z < AZ - 0.001]
bmesh.ops.delete(bm, geom=kill, context='FACES'); print('CUT faces', len(kill))
bm.to_mesh(house.data); bm.free()

# ---------- материалы
def tmat(name, file, rough=0.8, emit=0.0, metal=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True; b = m.node_tree.nodes['Principled BSDF']
    t = m.node_tree.nodes.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(os.path.join(TEX, file))
    m.node_tree.links.new(t.outputs['Color'], b.inputs['Base Color']); b.inputs['Roughness'].default_value = rough; b.inputs['Metallic'].default_value = metal
    if emit:
        m.node_tree.links.new(t.outputs['Color'], b.inputs['Emission Color']); b.inputs['Emission Strength'].default_value = emit
    return m
def cmat(name, col, rough=0.6, emit=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True; b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*col, 1); b.inputs['Roughness'].default_value = rough
    if emit: b.inputs['Emission Color'].default_value = (*col, 1); b.inputs['Emission Strength'].default_value = emit
    return m
M = {'tile': tmat('arch_tile', 'tile.png', 0.35), 'conc': tmat('arch_concrete', 'concrete.png', 0.9), 'floor': tmat('arch_floor', 'floor.png', 0.85),
     'step': tmat('arch_step', 'step.png', 0.6), 'metal': tmat('arch_metal', 'metal.png', 0.55, 0, 0.6), 'lamp': cmat('arch_lamp', (1.0, 0.82, 0.5), 0.3, 6.0),
     'dark': cmat('arch_dark', (0.012, 0.012, 0.014), 1.0)}
for s in ('perehod', 'vyhod', 'panika', '67', 'fortuna', 'closed'): M['s_' + s] = tmat('arch_sign_' + s, 'sign_%s.png' % s, 0.7, 0.25 if s in ('vyhod', '67', 'panika') else 0.0)

class Mesh:
    """Сборщик сетки: коробки и щитки с развёрткой по метрам (2 м на текстуру)."""
    def __init__(self, name):
        self.name = name; self.v = []; self.f = []; self.uv = []; self.mi = []; self.mats = []
    def _m(self, mat):
        if M[mat] not in self.mats: self.mats.append(M[mat])
        return self.mats.index(M[mat])
    def quad(self, mat, pts, uvs=None, tile=2.0):
        i = len(self.v); self.v += [tuple(p) for p in pts]; self.f.append((i, i + 1, i + 2, i + 3)); self.mi.append(self._m(mat))
        if uvs is None:
            n = (Vector(pts[1]) - Vector(pts[0])).cross(Vector(pts[3]) - Vector(pts[0])); a = max(range(3), key=lambda k: abs(n[k]))
            u, w = [k for k in range(3) if k != a]; uvs = [(p[u] / tile, p[w] / tile) for p in pts]
        self.uv.append(uvs)
    def box(self, mat, x0, x1, y0, y1, z0, z1, tile=2.0):
        p = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
        for q in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)): self.quad(mat, [p[k] for k in q], None, tile)
    def plate(self, mat, cx, y, cz, w, h, face=-1, along='x'):
        """Табличка w × h, лицом по −Y / +Y (along='x') или по ±X (along='y'); текстура целиком."""
        if along == 'x':
            pts = [(cx - w / 2 * -face, y, cz - h / 2), (cx + w / 2 * -face, y, cz - h / 2), (cx + w / 2 * -face, y, cz + h / 2), (cx - w / 2 * -face, y, cz + h / 2)]
        else:
            pts = [(y, cx + w / 2 * -face, cz - h / 2), (y, cx - w / 2 * -face, cz - h / 2), (y, cx - w / 2 * -face, cz + h / 2), (y, cx + w / 2 * -face, cz + h / 2)]
        self.quad(mat, pts, [(0, 0), (1, 0), (1, 1), (0, 1)])
    def build(self, origin=(0, 0, 0)):
        me = bpy.data.meshes.new(self.name); me.from_pydata([tuple(Vector(p) - Vector(origin)) for p in self.v], [], self.f)
        for m in self.mats: me.materials.append(m)
        uvl = me.uv_layers.new(name='UVMap')
        for poly in me.polygons:
            poly.material_index = self.mi[poly.index]
            for k, li in enumerate(poly.loop_indices): uvl.data[li].uv = self.uv[poly.index][k]
        me.update(); o = bpy.data.objects.new(self.name, me); sc.collection.objects.link(o); o.location = origin
        return o

L = Mesh('arch_liner')
# стены проезда: кафель до 2,4 м, выше бетон
for sx in (-1, 1):
    xa, xb = (-AX - 0.3, -AX) if sx < 0 else (AX, AX + 0.3)
    L.box('conc', xa, xb, Y0 + 0.02, Y1 - 0.02, 2.4, AZ)
    L.box('tile', xa - (0 if sx < 0 else -0.0), xb + (0.03 if sx < 0 else 0), Y0 + 0.02, Y1 - 0.02, 0.0, 2.4) if sx < 0 else L.box('tile', xa - 0.03, xb, Y0 + 0.02, Y1 - 0.02, 0.0, 2.4)
    L.box('conc', xa - 0.05 if sx > 0 else xa, xb + 0.05 if sx < 0 else xb, Y0 + 0.02, Y1 - 0.02, 2.4, 2.5)      # поясок над кафелем
# потолок и поперечные балки
L.box('conc', -AX, AX, Y0 + 0.02, Y1 - 0.02, AZ, AZ + 0.3)
yb = Y0 + 0.4
while yb < Y1 - 0.4:
    L.box('conc', -AX, AX, yb - 0.2, yb + 0.2, AZ - 0.45, AZ); yb += 4.4
# порталы на фасадах: бетонная рама вокруг проёма
for y0, y1 in ((Y0 - 0.12, Y0 + 0.1), (Y1 - 0.1, Y1 + 0.12)):
    L.box('conc', -AX - 0.45, -AX, y0, y1, 0, AZ + 0.45); L.box('conc', AX, AX + 0.45, y0, y1, 0, AZ + 0.45); L.box('conc', -AX - 0.45, AX + 0.45, y0, y1, AZ, AZ + 0.45)
# колонны между лестницей и проходом
for cy in (Y0 + 0.5, GY + 4.6, GY + 9.2, Y1 - 0.5):
    L.box('conc', 0.75, 1.25, cy - 0.25, cy + 0.25, 0, AZ - 0.45); L.box('tile', 0.72, 1.28, cy - 0.28, cy + 0.28, 0, 1.2)
# пол: проход, площадка перед решёткой, перекрытие над нижней частью марша
L.box('floor', 1.25, AX, Y0 - 0.1, Y1 + 0.1, -0.2, 0.02)
L.box('floor', SX0, 1.25, Y0 - 0.1, GY, -0.2, 0.02)
COVER = GY + 8.5
L.box('floor', SX0, 1.25, COVER, Y1 + 0.1, -0.3, 0.02)
L.box('floor', 0.75, 1.25, GY, COVER, -0.2, 0.02)
# лестница: 30 ступеней, перепад 5 м
for i in range(N):
    L.box('step', SX0, SX1, GY + i * TR, GY + (i + 1) * TR + 0.02, -(i + 1) * RI - 0.35, -(i + 1) * RI, 1.0)
# нижняя площадка и поворот коридора на восток, под проход (здесь — точка стыка с Подземкой)
BZ = -5.0
L.box('floor', SX0, AX, SY1, Y1 - 0.05, BZ - 0.3, BZ)
L.box('tile', SX0, AX, Y1 - 0.05, Y1 + 0.25, BZ, BZ + 2.7)                 # торцевая стена
L.box('conc', SX0, AX, SY1 - 6.0, Y1 + 0.25, BZ + 2.7, BZ + 3.0)           # потолок низа
L.box('tile', SX1, AX, SY1 - 0.3, SY1, BZ, BZ + 2.7)                       # стена коридора со стороны марша
L.box('dark', AX - 0.05, AX + 0.3, SY1, Y1 - 0.05, BZ, BZ + 2.7)           # тёмный торец коридора — граница сцены
# стены лестничной шахты
L.box('tile', SX0 - 0.3, SX0 + 0.03, GY, Y1 + 0.25, BZ - 0.3, 0.0)
L.box('tile', SX1 - 0.03, SX1 + 0.3, GY, SY1 - 0.3, BZ - 0.3, 0.0)
L.box('tile', SX0, SX1, COVER - 0.02, COVER + 0.25, -2.75, -0.3)           # лоб перекрытия над маршем
# парапет и поручни
L.box('conc', SX1, 1.25, GY, COVER, 0.0, 0.95)
for hx in (SX0 + 0.12, SX1 - 0.12):
    for i in range(0, N, 3):
        L.box('metal', hx - 0.02, hx + 0.02, GY + i * TR + 0.23, GY + i * TR + 0.27, -(i + 1) * RI, -(i + 1) * RI + 0.95)
    p0 = (hx, GY + 0.25, -RI + 0.95); p1 = (hx, GY + (N - 1) * TR + 0.25, -N * RI + 0.95)
    L.quad('metal', [(hx - 0.03, p0[1], p0[2]), (hx + 0.03, p0[1], p0[2]), (hx + 0.03, p1[1], p1[2]), (hx - 0.03, p1[1], p1[2])])
    L.quad('metal', [(hx - 0.03, p1[1], p1[2] - 0.05), (hx + 0.03, p1[1], p1[2] - 0.05), (hx + 0.03, p0[1], p0[2] - 0.05), (hx - 0.03, p0[1], p0[2] - 0.05)])
# решётка от парапета до потолка вдоль марша — через парапет к лестнице не перелезть
xb = 1.0; y = GY
while y < COVER:
    L.box('metal', xb - 0.015, xb + 0.015, y - 0.015, y + 0.015, 0.95, AZ - 0.45); y += 0.16
L.box('metal', xb - 0.03, xb + 0.03, GY, COVER, 0.95, 1.01); L.box('metal', xb - 0.03, xb + 0.03, GY, COVER, 2.6, 2.66)
# рама решётки и глухая решётка над ней
for px in (SX0 + 0.06, (SX0 + SX1) / 2, SX1 - 0.06):
    if px != (SX0 + SX1) / 2: L.box('metal', px - 0.06, px + 0.06, GY - 0.06, GY + 0.06, 0, AZ - 0.45)
L.box('metal', SX0, SX1, GY - 0.07, GY + 0.07, 2.6, 2.78)
x = SX0 + 0.2
while x < SX1 - 0.1:
    L.box('metal', x - 0.015, x + 0.015, GY - 0.015, GY + 0.015, 2.78, AZ - 0.45); x += 0.16
# светильники в сетке под потолком
LAMPS = [(-2.2, GY - 1.0), (-2.2, GY + 4.0), (3.2, Y0 + 3.0), (3.2, 0.0), (3.2, Y1 - 3.0)]
for lx, ly in LAMPS:
    L.box('lamp', lx - 0.35, lx + 0.35, ly - 0.09, ly + 0.09, AZ - 0.62, AZ - 0.5)
    L.box('metal', lx - 0.42, lx + 0.42, ly - 0.14, ly + 0.14, AZ - 0.5, AZ - 0.45)
    for q in (-0.38, -0.19, 0.0, 0.19, 0.38): L.box('metal', lx + q - 0.008, lx + q + 0.008, ly - 0.13, ly + 0.13, AZ - 0.68, AZ - 0.5)
BOT = (-2.2, SY1 - 2.0)
L.box('lamp', BOT[0] - 0.35, BOT[0] + 0.35, BOT[1] - 0.09, BOT[1] + 0.09, BZ + 2.58, BZ + 2.7)
# таблички и ценники
L.plate('s_perehod', (SX0 + SX1) / 2, GY - 0.09, 3.25, 3.4, 0.85)
L.plate('s_vyhod', (SX0 + SX1) / 2, COVER - 0.04, -1.2, 2.4, 0.6)
L.plate('s_panika', GY + 3.0, SX0 + 0.04, -0.9, 1.6, 0.5, 1, 'y')
L.plate('s_67', GY - 1.1, -AX + 0.04, 1.55, 0.5, 0.25, 1, 'y')
L.plate('s_67', 1.0, Y0 + 0.21, 1.5, 0.44, 0.22)
L.plate('s_fortuna', GY - 0.5, -AX + 0.04, 0.55, 0.62, 0.155, 1, 'y')
liner = L.build()

def leaf(name, hx, w):
    """Створка: петля на x = hx, полотно тянется на w (w < 0 — влево)."""
    g = Mesh(name); a, b = (hx, hx + w) if w > 0 else (hx + w, hx)
    for z in (0.08, 1.3, 2.5): g.box('metal', a, b, GY - 0.025, GY + 0.025, z, z + 0.06)
    for xx in (a, b - 0.05): g.box('metal', xx, xx + 0.05, GY - 0.025, GY + 0.025, 0.08, 2.56)
    x = a + 0.16
    while x < b - 0.08:
        g.box('metal', x - 0.014, x + 0.014, GY - 0.014, GY + 0.014, 0.14, 2.5); x += 0.15
    return g.build((hx, GY, 0))
half = (SX1 - SX0) / 2 - 0.14
gl = leaf('gate_L', SX0 + 0.12, half); gr = leaf('gate_R', SX1 - 0.12, -half)
C = Mesh('gate_chain'); mid = (SX0 + SX1) / 2      # цепь с замком и табличка «ЗАКРЫТО» — убираются при открытии
for k in range(9):
    C.box('metal', mid - 0.36 + k * 0.08, mid - 0.31 + k * 0.08, GY - 0.05 - (0.03 if k % 2 else 0), GY - 0.02 - (0.03 if k % 2 else 0), 1.22 - abs(k - 4) * 0.012, 1.27 - abs(k - 4) * 0.012)
C.box('metal', mid - 0.07, mid + 0.07, GY - 0.1, GY - 0.05, 1.02, 1.2)
C.plate('s_closed', mid + 0.9, GY - 0.04, 1.65, 0.6, 0.3)
chain = C.build()

# ---------- сохраняем
for o in (liner, gl, gr, chain): o.parent = house
bpy.context.view_layer.update()
os.makedirs(os.path.join(ROOT, 'blender_source'), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, 'blender_source', 'dvor_arch_81.blend'))
bpy.ops.object.select_all(action='SELECT')
glb = os.path.join(OUT, 'buildings', 'res_arch_81.glb')
bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', use_selection=True, export_apply=True)
tris = sum(len(p.vertices) - 2 for o in sc.objects if o.type == 'MESH' for p in o.data.polygons)
lib = json.load(open(os.path.join(OUT, 'library.json'), encoding='utf-8'))
lib['res_arch_81'] = {'section': 'buildings', 'source': 'soviet_apartment_building__russian_far_east + tools/blender/dvor_arch.py', 'size': [round(hi.x - lo.x, 2), round(Y1 - Y0, 2), 13.28],
                      'tris': tris, 'mats': len(bpy.data.materials), 'mb': round(os.path.getsize(glb) / 1e6, 1), 'note': 'дом № 81 с аркой и спуском в Подземку; створки gate_L / gate_R и gate_chain — отдельные объекты',
                      'stairs': {'gate_y': round(GY, 2), 'x': [SX0, SX1], 'run': N * TR, 'drop': 5.0, 'bottom_y': round(SY1, 2), 'link': [round((SX1 + AX) / 2, 2), round((SY1 + Y1) / 2, 2), BZ], 'lamps': LAMPS}}
json.dump(lib, open(os.path.join(OUT, 'library.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('ARCH tris', tris)

# ---------- проверочные снимки
sc.render.engine = 'BLENDER_WORKBENCH'; sh = sc.display.shading; sh.light = 'STUDIO'; sh.color_type = 'TEXTURE'; sh.show_cavity = True
sc.world = bpy.data.worlds.new('w'); sc.world.color = (0.3, 0.32, 0.36)
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam
sc.render.resolution_x, sc.render.resolution_y = 1280, 720
def shot(nm, pos, look, lens=22):
    cam.location = pos; cam.rotation_euler = (Vector(look) - Vector(pos)).to_track_quat('-Z', 'Y').to_euler(); cam.data.lens = lens; cam.data.clip_start = 0.1
    sc.render.filepath = os.path.join(ROOT, 'previews', 'res_arch_81_' + nm + '.png'); bpy.ops.render.render(write_still=True)
shot('a_front', (-4, Y0 - 16, 2.2), (0, Y0, 3.2))
shot('b_gate', (-1.0, Y0 - 3.2, 1.75), (-2.4, GY + 4, 0.4))
shot('c_stairs_down', (-2.2, GY + 1.2, -0.2), (-2.2, SY1, -4.6), 18)
shot('d_from_below', (-2.2, SY1 + 0.6, BZ + 1.6), (-2.2, GY, 1.2), 18)
shot('e_walkway', (3.2, Y0 - 1.0, 1.7), (2.6, Y1, 1.8))
print('DONE')
