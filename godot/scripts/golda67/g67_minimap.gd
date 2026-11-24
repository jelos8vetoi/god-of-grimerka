class_name G67Minimap
extends Control
## Мини-карта и текущая цель «ГОЛДА 67» (левый верхний угол HUD): нового ДВОРА и ПОДЗЕМКИ.
## Карта плоская: прямоугольники настоящей геометрии — план района data/dvor2/layout.json (G67Dvor2.layout) и
## таблица помещений G67Podzemka.ROOMS; ничего трёхмерного для карты не строится. Север — вверху, герой в центре.
## Маркеры: жёлтый — герой, красный — враги и их территории, голубой — жители, зелёный — можно подойти,
## фиолетовый — КРОТ и события, оранжевый — торговец, белый — обычное, шеврон — переход между районами.
## Заначки на карте не показываются. Цель и её место — goal(); маршрут — AStarGrid2D по сетке района (обход домов).
## Масштаб — клавиша M (три ступени). Числа — константы ниже.

const SIZE := 232.0              # сторона карты, px при высоте окна 900
const ZOOMS := [48.0, 85.0, 150.0]      # сколько метров от героя до края карты
const CELL_DV := 3.0             # клетка сетки маршрута во дворе, м
const CELL_PZ := 1.5             # в Подземке
const PATH_EVERY := 1.2          # как часто пересчитывается маршрут, с
const MARK_EVERY := 0.2

const C_BG := Color(0.07, 0.075, 0.085, 0.86)
const C_EDGE := Color(0.86, 0.84, 0.78, 0.55)
const C_ROAD := Color(0.24, 0.25, 0.27)
const C_WALK := Color(0.19, 0.2, 0.22)
const C_HOUSE := Color(0.13, 0.135, 0.15)
const C_HOUSE_E := Color(0.72, 0.7, 0.64, 0.6)
const C_GAR := Color(0.2, 0.19, 0.18)
const C_ROOM := Color(0.2, 0.21, 0.23)
const C_YOU := Color(1.0, 0.82, 0.25)
const C_FOE := Color(0.95, 0.27, 0.22)
const C_NPC := Color(0.45, 0.78, 1.0)
const C_USE := Color(0.45, 0.92, 0.5)
const C_EVENT := Color(0.74, 0.5, 1.0)
const C_TRADE := Color(1.0, 0.6, 0.2)
const C_PLAIN := Color(0.85, 0.85, 0.85)
const C_ROUTE := Color(1.0, 0.82, 0.25, 0.85)

var G: Golda67
var zoom_i := 1
var kind := ""                   # "dvor" | "podzemka" | ""
var world_id := 0
var rects: Array = []            # [Rect2 в мире (x, z), вид]
var names: Array = []            # [Vector2, подпись]
var grid: AStarGrid2D
var cell := 3.0
var path := PackedVector2Array()
var marks: Array = []            # [ключ, Vector2, цвет, вид, размер]
var born := {}                   # ключ -> когда маркер появился (плавное появление)
var cur_goal := {}
var _tp := 0.0
var _tm := 0.0
var map: Control
var head: Label
var text: Label

static func attach(g67: Golda67) -> G67Minimap:
	var m := G67Minimap.new()
	m.G = g67
	m.name = "G67Minimap"
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g67.game.hud_root.add_child(m)
	m._build()
	return m

func _build() -> void:
	position = Vector2(18, 16)
	map = MapView.new()
	map.owner_map = self
	map.size = Vector2(SIZE, SIZE)
	map.clip_contents = true
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(map)
	head = _label(11, Color(0.8, 0.78, 0.7), Vector2(2, SIZE + 6))
	text = _label(15, Color(0.98, 0.93, 0.8), Vector2(2, SIZE + 22))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size = Vector2(SIZE + 60.0, 0)

func _label(sz: int, col: Color, pos: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", MGUI.font("ui_b"))
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func cycle_zoom() -> void:
	zoom_i = (zoom_i + 1) % ZOOMS.size()

func shown() -> bool:
	return G != null and G.place == "run" and G.world != null and (G.world.dvor != null or G67District.is_podzemka()) and G.hub_ui == null and G.clip == null

# ------------------------------------------------------------------ геометрия района
func _rebuild() -> void:
	rects = []
	names = []
	path = PackedVector2Array()
	born = {}
	world_id = G.world.get_instance_id()
	grid = AStarGrid2D.new()
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	if G.world.dvor != null:
		kind = "dvor"
		cell = CELL_DV
		var lay: Dictionary = G.world.dvor.layout
		var x0 := float(lay["x"][0])
		var x1 := float(lay["x"][1])
		var y0 := float(lay["y"][0])
		var y1 := float(lay["y"][1])
		grid.region = Rect2i(int(floor(x0 / cell)), int(floor(-y1 / cell)), int(ceil((x1 - x0) / cell)), int(ceil((y1 - y0) / cell)))
		grid.cell_size = Vector2(cell, cell)
		grid.update()
		for it_v in (lay["items"] as Array):
			var it: Dictionary = it_v
			var cat := String(it["cat"])
			var r := Rect2(float(it["x"]) - float(it["w"]) * 0.5, -float(it["y"]) - float(it["h"]) * 0.5, float(it["w"]), float(it["h"]))
			var model := String(it.get("model", ""))
			var vid := ""
			if String(it["id"]) == "COURT":
				vid = "court"
			elif cat == "road" and model == "":
				vid = "road"
			elif cat == "walk":
				vid = "walk"
			elif cat == "res":
				vid = "house"
			elif cat == "gar" and model != "" and model != "payphone":
				vid = "gar"
			elif cat == "act" and model == "kiosk_90s":
				vid = "gar"
			if vid == "":
				continue
			rects.append([r, vid])
			if vid in ["house", "gar"] and model != "res_arch_81":
				_solid(r)
		rects.sort_custom(func(a, b): return _order(String(a[1])) < _order(String(b[1])))
		var dv: G67Dvor2 = G.world.dvor
		names = [[_xz(G67Dvor2.to3(G67Dvor2.KIOSK.x, G67Dvor2.KIOSK.y)), "ШАУРМА 67"], [_xz(G67Dvor2.to3(G67Dvor2.RAGS.x, G67Dvor2.RAGS.y + 5.0)), "РЫНОК"],
			[_xz(G67Dvor2.to3(-107.0, 45.0)), "ГСК"], [_xz(dv.court_center()), "КОРОБКА"], [_xz(G67Dvor2.to3(G67Dvor2.HOME_DOOR.x, G67Dvor2.HOME_DOOR.y - 9.0)), "ДОМ 67"]]
	else:
		kind = "podzemka"
		cell = CELL_PZ
		var bb := Rect2()
		var first := true
		for id in G67Podzemka.ROOMS:
			var q: Array = G67Podzemka.ROOMS[id]
			var r := Rect2(float(q[0]), float(q[2]), float(q[1]) - float(q[0]), float(q[3]) - float(q[2]))
			rects.append([r, "room"])
			bb = r if first else bb.merge(r)
			first = false
		bb = bb.grow(cell * 2.0)
		grid.region = Rect2i(int(floor(bb.position.x / cell)), int(floor(bb.position.y / cell)), int(ceil(bb.size.x / cell)), int(ceil(bb.size.y / cell)))
		grid.cell_size = Vector2(cell, cell)
		grid.update()
		var rg := grid.region
		for cy in range(rg.position.y, rg.end.y):            # ходить можно только там, где есть помещение
			for cx in range(rg.position.x, rg.end.x):
				var c := Vector2((float(cx) + 0.5) * cell, (float(cy) + 0.5) * cell)
				var inside := false
				for rr in rects:
					if (rr[0] as Rect2).grow(0.2).has_point(c):
						inside = true
						break
				if not inside:
					grid.set_point_solid(Vector2i(cx, cy), true)
		names = [[_room_c("cash"), "КАССЫ"], [_room_c("casino"), "CASINO"], [_room_c("arena"), "АРЕНА"], [_room_c("arcade"), "АВТОМАТЫ"], [_room_c("gallery"), "ГАЛЕРЕЯ"]]

func _order(v: String) -> int:
	return {"road": 0, "walk": 1, "court": 2, "room": 2, "gar": 3, "house": 4}.get(v, 2)

func _room_c(id: String) -> Vector2:
	var q: Array = G67Podzemka.ROOMS[id]
	return Vector2((float(q[0]) + float(q[1])) * 0.5, (float(q[2]) + float(q[3])) * 0.5)

func _solid(r: Rect2) -> void:
	var a := Vector2i(int(floor(r.position.x / cell)), int(floor(r.position.y / cell)))
	var b := Vector2i(int(floor(r.end.x / cell)), int(floor(r.end.y / cell)))
	for cy in range(a.y, b.y + 1):
		for cx in range(a.x, b.x + 1):
			if grid.is_in_boundsv(Vector2i(cx, cy)):
				grid.set_point_solid(Vector2i(cx, cy), true)

static func _xz(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)

# ------------------------------------------------------------------ цель забега
## Что делать дальше: {"text": строка, "pos": Vector3 или null}. Читает состояние забега, ничего не меняет.
func goal() -> Dictionary:
	if G.place != "run" or G.run.is_empty():
		return {"text": "", "pos": null}
	var p = G.game.player
	if G.turf != null and G.world.dvor != null:
		var T: G67Turf = G.turf
		var dv: G67Dvor2 = G.world.dvor
		if G.room_state == "boss":
			return {"text": "Победи Мишу", "pos": null}
		if not T.active.is_empty():
			return {"text": "Разберись с местной группой · осталось %d" % T.left(), "pos": T.active["c"]}
		if dv.gate_open:
			return {"text": "Спускайся в Подземку — арка дома № 81", "pos": dv.stairs_top()}
		for e in T.encs:
			if not (e["bag"] as Dictionary).is_empty():
				return {"text": "Обыщи сумку", "pos": e["c"]}
		var done := 0
		for e in T.encs:
			if String(e["state"]) in ["cleared", "gone"] and e["d"].has("posts") and not bool(e["d"].get("nofoes", false)):
				done += 1
		if done == 0:
			return {"text": "Найди первую территорию противников", "pos": T.encs[0]["c"]}
		if not bool(G.run.get("rags", false)):
			return {"text": "Загляни на рынок", "pos": G67Dvor2.to3(G67Dvor2.RAGS.x, G67Dvor2.RAGS.y)}
		for e in T.encs:
			if bool(e["d"]["must"]) and not String(e["state"]) in ["cleared", "gone"]:
				return {"text": ("Разберись со смотрящим" if String(e["d"]["type"]) == "elite" else "Разберись с местной группой") + (" (вторая попытка)" if int(e["flees"]) > 0 else ""), "pos": e["c"]}
		if not T.need_done():
			for e in T.encs:
				if not String(e["state"]) in ["cleared", "gone"] and not bool(e["d"].get("nofoes", false)):
					return {"text": "Долг за побег: разберись с группой", "pos": e["c"]}
		if G.world.points.any(func(pt): return String(pt["id"]) == "krot") and not bool(G.run.get("krot_seen", false)) and p.global_position.distance_to(_pt("krot")) < 60.0:
			return {"text": "Найди КРОТА", "pos": _pt("krot")}
		if not bool(G.run.get("rested", false)) and p.hp < p.max_hp * 0.7:
			return {"text": "Подготовься к встрече с Мишей: беседка или шаурма", "pos": G67Dvor2.to3(G67Dvor2.REST.x, G67Dvor2.REST.y)}
		return {"text": "Победи Мишу — коробка на севере", "pos": dv.court_center() + Vector3(0, 0, dv.court.size.y * 0.5 + 1.5)}
	if G67District.is_podzemka():
		if G.room_state == "boss":
			return {"text": "Победи FORTUNA 812", "pos": null}
		if G.room_state == "fight":
			return {"text": "Разберись с этими · осталось %d" % (G.alive() + G.pending.size()), "pos": null}
		var best = null
		var bd := INF
		var what := ""
		for g in G.world.gates:
			var gp: Vector3 = g["pos"]
			var d := gp.distance_to(p.global_position)
			if d < bd:
				bd = d
				best = gp
				what = String(G67Data.ROOM_NAMES[String((g["option"] as Dictionary)["type"])])
		if best != null:
			return {"text": ("Дальше — %s" % what) if G.world.gates.size() == 1 else "Выбери, куда дальше: ближайшее — %s" % what, "pos": best}
		if G.room_state in ["reward"]:
			return {"text": "Забери награду", "pos": null}
		return {"text": "Спускайся к первому турникету", "pos": G67District.zone_of("gate1").get("c", null)}
	return {"text": "", "pos": null}

func _pt(id: String) -> Vector3:
	for pt in G.world.points:
		if String(pt["id"]) == id:
			return pt["pos"]
	return Vector3.INF

# ------------------------------------------------------------------ маркеры
func _mark(key: String, pos: Vector3, col: Color, shape: String, sz := 4.0) -> void:
	marks.append([key, Vector2(pos.x, pos.z), col, shape, sz])
	if not born.has(key):
		born[key] = Time.get_ticks_msec()

func _collect() -> void:
	marks = []
	var W = G.world
	if kind == "dvor" and G.turf != null:
		for e in G.turf.encs:
			var st := String(e["state"])
			var id := String(e["id"])
			if not (e["bag"] as Dictionary).is_empty():
				_mark("bag_" + id, e["c"], C_USE, "diamond", 5.0)
			if st in ["cleared", "gone"]:
				continue
			if bool(e["d"].get("nofoes", false)):
				_mark("cf_" + id, e["c"], C_EVENT, "diamond", 5.0)
			else:
				_mark("turf_" + id, e["c"], C_FOE, "zone_on" if st == "fight" else "zone", 9.0)
		if G.folk != null:
			for f in G.folk.folk:
				if is_instance_valid(f["rig"]) and not String(f["id"]).begins_with("ev_") and not String(f["id"]).begins_with("cf_"):
					_mark("npc_" + String(f["id"]), (f["rig"] as Node3D).global_position, C_NPC, "dot", 2.6)
			if not G.folk.trader.is_empty() and not G.folk.trader_closed():
				_mark("trader", (G.folk.trader["rig"] as Node3D).global_position, C_TRADE, "square", 5.0)
		if W.dvor.gate_open:
			_mark("exit_pz", W.dvor.stairs_top(), C_YOU, "exit", 7.0)
	for pt in W.points:
		var id := String(pt["id"])
		var pos: Vector3 = pt["pos"]
		if id.begins_with("secret") or id.begins_with("stash") or id.begins_with("bottle") or id.begins_with("clip_") or id.begins_with("bag_") or id == "trader_dv":
			continue                       # заначки и секреты на карте не показываются
		if id == "krot" or id.begins_with("evdv_") or id in ["slot", "shutter", "hamster_door"]:
			_mark("p_" + id, pos, C_EVENT, "diamond", 5.0)
		elif id == "to_dvor":
			_mark("p_" + id, pos, C_YOU, "exit", 7.0)
		elif id == "home":
			_mark("p_" + id, pos, C_PLAIN, "square", 4.0)
		elif id.begins_with("gate"):
			_mark("p_" + id, pos, C_USE, "arrow", 6.0)
		else:
			_mark("p_" + id, pos, C_USE, "dot", 3.4)
	if G.room_state in ["fight", "boss"]:
		for en in G.game.enemies:
			if is_instance_valid(en) and en.alive() and not bool(en.get("post")):
				_mark("foe_%d" % en.get_instance_id(), en.global_position, C_FOE, "dot", 3.2 if String(en.boss_id) == "" else 5.0)

# ------------------------------------------------------------------ маршрут
func _cell_of(v: Vector2) -> Vector2i:
	return Vector2i(int(floor(v.x / cell)), int(floor(v.y / cell)))

func _free_near(c: Vector2i) -> Vector2i:
	if grid.is_in_boundsv(c) and not grid.is_point_solid(c):
		return c
	for r in range(1, 9):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q := c + Vector2i(dx, dy)
				if grid.is_in_boundsv(q) and not grid.is_point_solid(q):
					return q
	return Vector2i(999999, 0)

func _route(from: Vector3, to: Vector3) -> void:
	path = PackedVector2Array()
	if grid == null:
		return
	var a := _free_near(_cell_of(_xz(from)))
	var b := _free_near(_cell_of(_xz(to)))
	if a.x == 999999 or b.x == 999999:
		return
	var pts := grid.get_point_path(a, b)
	if pts.size() < 2:
		return
	path.append(_xz(from))
	for i in range(1, pts.size() - 1):
		path.append(pts[i] + Vector2(cell, cell) * 0.5)
	path.append(_xz(to))

func _process(dt: float) -> void:
	var on := shown()
	visible = on
	if not on:
		return
	var vs := get_viewport_rect().size
	var k := clampf(vs.y / 900.0, 0.7, 2.0)
	scale = Vector2(k, k)
	if G.world.get_instance_id() != world_id:
		_rebuild()
		_tp = 0.0
		_tm = 0.0
	_tm -= dt
	if _tm <= 0.0:
		_tm = MARK_EVERY
		_collect()
		cur_goal = goal()
		var d: Dictionary = G.district()
		head.text = "%s · ГОЛДА %d%s" % [String(d["name"]), int(G.run.get("golda", 0)), (" · АРТЕФАКТОВ %d/%d" % [G.arts().size(), G.slots()]) if not G.arts().is_empty() else ""]
		var gp = cur_goal.get("pos")
		var far := ""
		if gp != null and gp != Vector3.INF:
			far = " · %d м" % int(Vector2(gp.x - G.game.player.global_position.x, gp.z - G.game.player.global_position.z).length())
		text.text = String(cur_goal.get("text", "")) + far
	_tp -= dt
	if _tp <= 0.0:
		_tp = PATH_EVERY
		var gp2 = cur_goal.get("pos")
		if gp2 != null and gp2 != Vector3.INF:
			_route(G.game.player.global_position, gp2)
		else:
			path = PackedVector2Array()
	map.queue_redraw()

## Рисунок карты: всё в координатах мира, сдвиг и масштаб — от героя
class MapView extends Control:
	var owner_map: G67Minimap
	func _draw() -> void:
		var M := owner_map
		if M == null or M.G == null or not M.shown():
			return
		var p = M.G.game.player
		var pv: Vector3 = p.vis_pos() if p.has_method("vis_pos") else p.global_position
		var me := Vector2(pv.x, pv.z)
		var half := size * 0.5
		var s: float = half.x / float(G67Minimap.ZOOMS[M.zoom_i])
		draw_rect(Rect2(Vector2.ZERO, size), G67Minimap.C_BG)
		for rr in M.rects:
			var r: Rect2 = rr[0]
			var q := Rect2((r.position - me) * s + half, r.size * s)
			if not q.intersects(Rect2(Vector2.ZERO, size)):
				continue
			match String(rr[1]):
				"road": draw_rect(q, G67Minimap.C_ROAD)
				"walk": draw_rect(q, G67Minimap.C_WALK)
				"room":
					draw_rect(q, G67Minimap.C_ROOM)
				"court":
					draw_rect(q, Color(0.2, 0.26, 0.32))
					draw_rect(q, Color(0.6, 0.8, 1.0, 0.7), false, 1.0)
				"gar":
					draw_rect(q, G67Minimap.C_GAR)
					draw_rect(q, Color(0.6, 0.58, 0.52, 0.35), false, 1.0)
				"house":
					draw_rect(q, G67Minimap.C_HOUSE)
					draw_rect(q, G67Minimap.C_HOUSE_E, false, 1.0)
		if M.kind == "podzemka":                     # контуры помещений поверх заливки
			for rr in M.rects:
				var r2: Rect2 = rr[0]
				draw_rect(Rect2((r2.position - me) * s + half, r2.size * s), Color(0.8, 0.78, 0.7, 0.16), false, 1.0)
		if M.path.size() >= 2:
			var pts := PackedVector2Array()
			for v in M.path:
				pts.append((v - me) * s + half)
			var ph := fmod(Time.get_ticks_msec() * 0.004, 8.0)
			for i in range(pts.size() - 1):          # пунктир «бежит» к цели
				var a := pts[i]
				var b := pts[i + 1]
				var L := a.distance_to(b)
				var t := -ph
				while t < L:
					var t0 := maxf(t, 0.0)
					var t1 := minf(t + 4.0, L)
					if t1 > t0:
						draw_line(a.lerp(b, t0 / L), a.lerp(b, t1 / L), G67Minimap.C_ROUTE, 1.6)
					t += 8.0
		if M.zoom_i < 2 or M.kind == "podzemka":
			var f := MGUI.font("caps")
			for nm in M.names:
				var at: Vector2 = ((nm[0] as Vector2) - me) * s + half
				if Rect2(Vector2.ZERO, size).grow(-6).has_point(at):
					var w := f.get_string_size(String(nm[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
					draw_string(f, at - Vector2(w * 0.5, -3), String(nm[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.85, 0.83, 0.76, 0.75))
		var now := Time.get_ticks_msec()
		for m in M.marks:
			var at2: Vector2 = ((m[1] as Vector2) - me) * s + half
			var col: Color = m[2]
			var age := float(now - int(M.born.get(String(m[0]), now))) / 300.0
			var kk := clampf(age, 0.0, 1.0)
			col.a *= kk
			var sz: float = float(m[4]) * (1.6 - 0.6 * kk)
			var shape := String(m[3])
			if shape in ["zone", "zone_on"]:
				var rad := maxf(sz, 9.0 * s)
				if Rect2(Vector2.ZERO, size).grow(rad).has_point(at2):
					var pulse := 0.5 + 0.5 * sin(float(now) * 0.006)
					draw_circle(at2, rad, Color(col.r, col.g, col.b, (0.3 + 0.2 * pulse) if shape == "zone_on" else 0.14))
					draw_arc(at2, rad, 0.0, TAU, 28, Color(col.r, col.g, col.b, 0.9 * kk), 1.4)
				continue
			if not Rect2(Vector2.ZERO, size).has_point(at2):
				continue
			match shape:
				"dot":
					draw_circle(at2, sz, col)
				"square":
					draw_rect(Rect2(at2 - Vector2(sz, sz) * 0.8, Vector2(sz, sz) * 1.6), col)
					draw_rect(Rect2(at2 - Vector2(sz, sz) * 0.8, Vector2(sz, sz) * 1.6), Color(0, 0, 0, 0.7), false, 1.0)
				"diamond":
					draw_colored_polygon(PackedVector2Array([at2 + Vector2(0, -sz), at2 + Vector2(sz, 0), at2 + Vector2(0, sz), at2 + Vector2(-sz, 0)]), col)
				"arrow":
					draw_colored_polygon(PackedVector2Array([at2 + Vector2(0, -sz), at2 + Vector2(sz * 0.8, sz * 0.7), at2 + Vector2(-sz * 0.8, sz * 0.7)]), col)
				"exit":
					draw_rect(Rect2(at2 - Vector2(sz, sz), Vector2(sz, sz) * 2.0), Color(0.05, 0.05, 0.06, 0.9 * kk))
					draw_rect(Rect2(at2 - Vector2(sz, sz), Vector2(sz, sz) * 2.0), col, false, 1.5)
					draw_polyline(PackedVector2Array([at2 + Vector2(-sz * 0.55, -sz * 0.3), at2 + Vector2(0, sz * 0.35), at2 + Vector2(sz * 0.55, -sz * 0.3)]), col, 1.8)
		var gp = M.cur_goal.get("pos")
		if gp != null and gp != Vector3.INF:             # цель: кольцо на месте или стрелка на краю карты
			var gt := (Vector2(gp.x, gp.z) - me) * s + half
			if Rect2(Vector2.ZERO, size).grow(-8).has_point(gt):
				draw_arc(gt, 7.0 + 2.0 * sin(float(now) * 0.006), 0.0, TAU, 20, G67Minimap.C_YOU, 1.6)
			else:
				var dir := (gt - half).normalized()
				var edge := half + dir * (half.x - 9.0) / maxf(absf(dir.x), absf(dir.y))
				var n := Vector2(-dir.y, dir.x)
				draw_colored_polygon(PackedVector2Array([edge + dir * 7.0, edge - dir * 4.0 + n * 5.0, edge - dir * 4.0 - n * 5.0]), G67Minimap.C_YOU)
		var f2 := float(p.face)
		var fw := Vector2(sin(f2), cos(f2))
		var sd := Vector2(-fw.y, fw.x)
		draw_colored_polygon(PackedVector2Array([half + fw * 9.0, half - fw * 5.0 + sd * 5.5, half - fw * 2.0, half - fw * 5.0 - sd * 5.5]), G67Minimap.C_YOU)
		draw_polyline(PackedVector2Array([half + fw * 9.0, half - fw * 5.0 + sd * 5.5, half - fw * 2.0, half - fw * 5.0 - sd * 5.5, half + fw * 9.0]), Color(0, 0, 0, 0.8), 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), G67Minimap.C_EDGE, false, 1.5)
		draw_rect(Rect2(Vector2(0, 0), Vector2(size.x, 3)), G67Minimap.C_YOU)
		var fc := MGUI.font("caps")
		draw_string(fc, Vector2(size.x - 12, 14), "С", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.9, 0.88, 0.8, 0.8))
