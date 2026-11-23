## «ТАПАЙ ХОМЯКОВ» — мини-игра секретной комнаты (PODZEMKA_DESIGN, раздел 4): 45 с, стена нор 3 × 8 (24 норы `hole_NN` модели стены), до трёх хомяков одновременно.
## Попадание +10 × комбо (×1…×5), быстрый рыжий +25, золотой в короне +67 (один-два за игру). Промах по пустой норе или пропуск хомяка сбрасывает комбо.
## Удержание Esc 1,2 с — пропуск; короткое Esc — пауза. Логика (`step`, `tap_hole`, `simulate`) не зависит от отрисовки — бот в проверках.
## 3D: `setup_3d(камера, стена)` — хомяки-модели `sf_hamster` в норах стены (вылез → покрутил носом → нырнул; попадание — сплющился, звёздочки, писк),
## прицел — луч мыши от камеры (или стик + [E]); без `setup_3d` рисуется плоская стена (запасной вид).
class_name G67HamsterGame
extends Control

signal finished(result: Dictionary)

const TIME_TOTAL := 45.0
const COLS := 8
const ROWS := 3
const BASE_SCORE := 10
const FAST_SCORE := 25
const GOLD_SCORE := 67
const GOLD_TIMES := [14.0, 31.0]
const MODEL := "res://assets/golda67/podzemka/sf_hamster.glb"
const PICK_RADIUS := 0.38           # м: насколько близко к норе должен пройти луч прицела

var holes: Array = []                 # Rect2 каждой норы на экране (плоский вид)
var hams: Array = []                  # {hole, age, life, kind, hit, hit_t}
var t_left := TIME_TOTAL
var score := 0
var combo := 1
var best_combo := 1
var hits := 0
var misses := 0
var golds := 0
var resets := 0
var spawn_cd := 0.4
var running := false
var paused := false
var done := false
var hold := 0.0
var rng := RandomNumberGenerator.new()
var headless := false
var cam: Camera3D = null
var hole_pos: Array = []
var models := {}                      # ham (Dictionary) → Node3D
var stars := []                       # [Label3D, t]
var cursor := Vector2(640, 360)
var squeak_pl: AudioStreamPlayer = null
var prev_cam: Camera3D = null
var cam_t := 0.0
var cam_from := Vector3.ZERO
var cam_to := Vector3.ZERO
var extra_nodes: Array = []
var _next_id := 1

func _ready() -> void:
	rng.randomize()
	size = Vector2(1280, 720)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_layout()
	squeak_pl = AudioStreamPlayer.new()
	squeak_pl.stream = synth_squeak()
	squeak_pl.volume_db = -4.0
	add_child(squeak_pl)
	start()

func _layout() -> void:
	holes = []
	var sz := Vector2(1280, 720)
	var cw := 120.0
	var ch := 110.0
	var x0 := (sz.x - float(COLS) * cw) * 0.5
	for r in ROWS:
		for c in COLS:
			holes.append(Rect2(x0 + float(c) * cw + (30.0 if r % 2 == 1 else 0.0) - 15.0, 170.0 + float(r) * 165.0, cw - 20.0, ch))

## Включить 3D-вид: камера наезжает на стену, хомяки-модели появляются из нор wall (`hole_NN`)
func setup_3d(wall: Node3D, parent: Node3D) -> void:
	hole_pos = []
	for i in range(1, 25):
		var h = wall.find_child("hole_%02d" % i, true, false)
		hole_pos.append((h as Node3D).global_position + Vector3(0, 0, 0.1) if h != null else wall.global_position + Vector3(float(i % 8) - 3.5, 1.0 + float(i / 8) * 1.25, 0.1))
	cam = Camera3D.new()
	cam.fov = 62.0
	parent.add_child(cam)
	extra_nodes.append(cam)
	var wc: Vector3 = wall.global_position + Vector3(0.0, 2.25, 0.0)
	cam_to = wc + Vector3(0.0, 0.0, 5.4)
	cam_from = wc + Vector3(0.0, 0.3, 9.5)
	cam.global_position = cam_from
	cam.look_at(wc, Vector3.UP)
	prev_cam = get_viewport().get_camera_3d()
	cam.make_current()
	var lt := OmniLight3D.new()
	lt.light_color = Color(1.0, 0.85, 0.6)
	lt.light_energy = 2.2
	lt.omni_range = 9.0
	parent.add_child(lt)
	lt.global_position = wc + Vector3(0.0, 1.2, 3.5)
	extra_nodes.append(lt)

func start() -> void:
	t_left = TIME_TOTAL
	score = 0
	combo = 1
	best_combo = 1
	hits = 0
	misses = 0
	golds = 0
	resets = 0
	hams = []
	spawn_cd = 0.4
	running = true
	done = false

func _life(t: float) -> float:
	var k := 1.0 - t_left / TIME_TOTAL
	return lerpf(rng.randf_range(0.9, 1.6), rng.randf_range(0.6, 1.0), k)

func _free_holes() -> Array:
	var used := {}
	for h in hams:
		used[int(h["hole"])] = true
	var out: Array = []
	for i in 24:
		if not used.has(i):
			out.append(i)
	return out

func _spawn() -> void:
	var fr := _free_holes()
	if fr.is_empty():
		return
	var elapsed := TIME_TOTAL - t_left
	var kind := "normal"
	for gi in GOLD_TIMES.size():
		if elapsed >= float(GOLD_TIMES[gi]) and golds + _gold_alive() < gi + 1 and _gold_alive() == 0 and golds < gi + 1:
			kind = "gold"
	if kind != "gold" and rng.randf() < 0.14:
		kind = "fast"
	var life := _life(elapsed)
	if kind == "fast":
		life *= 0.7
	elif kind == "gold":
		life = 1.4
	hams.append({"hole": fr[rng.randi() % fr.size()], "age": 0.0, "life": life, "kind": kind, "hit": false, "hit_t": 0.0, "id": _next_id})
	_next_id += 1

func _gold_alive() -> int:
	var n := 0
	for h in hams:
		if String(h["kind"]) == "gold" and not bool(h["hit"]):
			n += 1
	return n

func _reset_combo() -> void:
	if combo > 1:
		resets += 1
	combo = 1

## Один шаг логики: время, появление и уход хомяков
func step(dt: float) -> void:
	if not running or paused or done:
		return
	t_left -= dt
	spawn_cd -= dt
	if spawn_cd <= 0.0 and hams.filter(func(h): return not bool(h["hit"])).size() < 3:
		_spawn()
		spawn_cd = lerpf(0.55, 0.3, 1.0 - t_left / TIME_TOTAL) * rng.randf_range(0.8, 1.2)
	for h in hams.duplicate():
		h["age"] = float(h["age"]) + dt
		if bool(h["hit"]):
			h["hit_t"] = float(h["hit_t"]) + dt
			if float(h["hit_t"]) > 0.45:
				hams.erase(h)
		elif float(h["age"]) > float(h["life"]):
			hams.erase(h)
			misses += 1
			_reset_combo()
	if t_left <= 0.0:
		_end(false)

## Удар по норе idx: попадание или промах по пустой норе
func tap_hole(idx: int) -> bool:
	if not running or paused or done:
		return false
	for h in hams:
		if int(h["hole"]) == idx and not bool(h["hit"]) and float(h["age"]) > 0.12:
			h["hit"] = true
			hits += 1
			var base := BASE_SCORE
			if String(h["kind"]) == "fast":
				base = FAST_SCORE
			elif String(h["kind"]) == "gold":
				base = GOLD_SCORE
				golds += 1
			score += base * combo
			combo = mini(combo + 1, 5)
			best_combo = maxi(best_combo, combo)
			_on_hit(h)
			return true
	_reset_combo()
	return false

func _on_hit(h: Dictionary) -> void:
	if squeak_pl != null and not headless:
		squeak_pl.pitch_scale = 1.4 if String(h["kind"]) == "gold" else rng.randf_range(0.9, 1.25)
		squeak_pl.play()

func tap_at(p: Vector2) -> void:
	if cam != null:
		var o := cam.project_ray_origin(p)
		var d := cam.project_ray_normal(p)
		var best := -1
		var bd := PICK_RADIUS
		for i in hole_pos.size():
			var v: Vector3 = (hole_pos[i] as Vector3) - o
			var dist := (v - d * v.dot(d)).length()
			if dist < bd:
				bd = dist
				best = i
		if best >= 0:
			tap_hole(best)
		elif running and not paused:
			_reset_combo()
		return
	for i in holes.size():
		if (holes[i] as Rect2).grow(10.0).has_point(p):
			tap_hole(i)
			return
	if running and not paused:
		_reset_combo()

func _end(skipped: bool) -> void:
	if done:
		return
	done = true
	running = false
	finished.emit({"score": score, "best_combo": best_combo, "hits": hits, "misses": misses, "golds": golds, "resets": resets, "skipped": skipped})

## Бот: видит хомяка, реагирует через 0,25–0,6 с и бьёт с вероятностью acc (иначе он уйдёт — пропуск, сброс комбо)
func simulate(acc: float, seed_: int = 1) -> Dictionary:
	rng.seed = seed_
	start()
	var react := {}
	var guard := 0
	while running and guard < 2000:
		guard += 1
		step(0.1)
		for h in hams.duplicate():
			if bool(h["hit"]):
				continue
			var hid := int(h["id"])
			if not react.has(hid):
				react[hid] = float(h["age"]) + rng.randf_range(0.25, 0.6)
			if float(h["age"]) >= float(react[hid]) and rng.randf() < acc:
				tap_hole(int(h["hole"]))
				react.erase(hid)
	return {"score": score, "best_combo": best_combo, "hits": hits, "misses": misses, "golds": golds, "resets": resets, "time_left": t_left}

func _process(dt: float) -> void:
	if headless:
		return
	step(dt)
	if cam != null:
		cam_t = minf(cam_t + dt / 0.9, 1.0)
		var k := 1.0 - pow(1.0 - cam_t, 3.0)
		cam.global_position = cam_from.lerp(cam_to, k)
		_update_models(dt)
	var mv := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if mv.length() > 0.2:
		cursor += mv * 700.0 * dt
		cursor = cursor.clamp(Vector2.ZERO, Vector2(1280, 720))
	if Input.is_key_pressed(KEY_ESCAPE) and not done:
		hold += dt
		if hold > 1.2:
			_end(true)
	else:
		hold = 0.0
	queue_redraw()

func _make_model(h: Dictionary) -> Node3D:
	var holder := Node3D.new()
	var ps: PackedScene = load(MODEL) as PackedScene
	var m: Node3D = ps.instantiate() as Node3D
	holder.add_child(m)
	m.rotation.y = PI
	var kind := String(h["kind"])
	if kind != "normal":
		var col := Color(1.0, 0.45, 0.1) if kind == "fast" else Color(1.0, 0.82, 0.2)
		var mt := StandardMaterial3D.new()
		mt.albedo_color = col
		mt.metallic = 0.6 if kind == "gold" else 0.0
		mt.roughness = 0.35
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = mt
	if kind == "gold":
		var crown := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.09
		cm.height = 0.12
		cm.radial_segments = 5
		crown.mesh = cm
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = Color(1.0, 0.9, 0.2)
		cmat.emission_enabled = true
		cmat.emission = Color(1.0, 0.8, 0.1)
		crown.material_override = cmat
		crown.position = Vector3(0, 0.52, 0)
		holder.add_child(crown)
	get_parent_node_3d_safe().add_child(holder)
	extra_nodes.append(holder)
	return holder

func get_parent_node_3d_safe() -> Node3D:
	return cam.get_parent() as Node3D

func _update_models(dt: float) -> void:
	var by_id := {}
	for h in hams:
		by_id[int(h["id"])] = h
		if not models.has(int(h["id"])):
			models[int(h["id"])] = _make_model(h)
	for mid in models.keys():
		var node: Node3D = models[mid]
		if not by_id.has(mid):
			node.queue_free()
			models.erase(mid)
			continue
		var h: Dictionary = by_id[mid]
		var base: Vector3 = hole_pos[int(h["hole"])]
		var age := float(h["age"])
		var life := float(h["life"])
		var up := clampf(age / 0.22, 0.0, 1.0) * clampf((life - age) / 0.2, 0.0, 1.0)
		var s := (0.15 + 0.85 * up) * 1.45
		var wob := 0.0
		if age > 0.35 and not bool(h["hit"]):
			wob = sin(age * 18.0) * 0.18
		node.position = base + Vector3(0.0, -0.30 + 0.42 * up, 0.3 * up)
		node.rotation = Vector3(0.0, wob, wob * 0.6)
		node.scale = Vector3(s, s, s)
		if bool(h["hit"]):
			var ht := float(h["hit_t"])
			node.scale = Vector3(1.35, 0.35, 1.35)
			node.position = base + Vector3(0.0, -0.3, 0.3)
			if ht < 0.05:
				_add_stars(node.position + Vector3(0, 0.5, 0.2))
	for st in stars.duplicate():
		st[1] = float(st[1]) - dt
		(st[0] as Label3D).position.y += dt * 0.5
		if float(st[1]) <= 0.0:
			(st[0] as Label3D).queue_free()
			stars.erase(st)

func _add_stars(pos: Vector3) -> void:
	var lb := Label3D.new()
	lb.text = "* * *"
	lb.font_size = 96
	lb.pixel_size = 0.006
	lb.modulate = Color(1, 1, 0.35)
	lb.outline_size = 12
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.shaded = false
	cam.get_parent().add_child(lb)
	lb.position = pos
	stars.append([lb, 0.45])
	extra_nodes.append(lb)

func _unhandled_input(ev: InputEvent) -> void:
	if headless:
		return
	if ev is InputEventMouseMotion:
		cursor = ev.position
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if done:
			finished.emit({"closed": true})
		else:
			tap_at(get_local_mouse_position())
		accept_event()
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_E:
			if done:
				finished.emit({"closed": true})
			else:
				tap_at(cursor)
			accept_event()
		elif ev.keycode == KEY_ESCAPE and not done:
			paused = not paused

func cleanup() -> void:
	for n in extra_nodes:
		if is_instance_valid(n):
			n.queue_free()
	extra_nodes = []
	if prev_cam != null and is_instance_valid(prev_cam):
		prev_cam.make_current()

func _draw() -> void:
	var f := ThemeDB.fallback_font
	if cam == null:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.16, 0.1, 0.06, 0.96))
		for i in holes.size():
			var r: Rect2 = holes[i]
			draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.55), Vector2(r.size.x, 14)), Color(0.4, 0.26, 0.14))
			draw_set_transform(r.position + Vector2(r.size.x * 0.5, r.size.y * 0.78), 0.0, Vector2(1.0, 0.4))
			draw_circle(Vector2.ZERO, r.size.x * 0.42, Color(0.04, 0.02, 0.02))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for h in hams:
			var r2: Rect2 = holes[int(h["hole"])]
			var k := clampf(float(h["age"]) / 0.25, 0.0, 1.0)
			var fall := clampf((float(h["life"]) - float(h["age"])) / 0.2, 0.0, 1.0)
			var up := k * fall
			var c := r2.position + Vector2(r2.size.x * 0.5, r2.size.y * 0.8 - up * r2.size.y * 0.75)
			var kind := String(h["kind"])
			var col := Color(0.86, 0.62, 0.36) if kind == "normal" else (Color(1.0, 0.45, 0.1) if kind == "fast" else Color(1.0, 0.82, 0.2))
			var squash := 0.45 if bool(h["hit"]) else 1.0
			draw_set_transform(c, 0.0, Vector2(1.0 + (1.0 - squash), squash))
			draw_circle(Vector2.ZERO, 36.0, col)
			draw_circle(Vector2(-22, -28), 12.0, col)
			draw_circle(Vector2(22, -28), 12.0, col)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_arc(cursor, 16.0, 0.0, TAU, 24, Color(1.0, 0.9, 0.3), 3.0)
		draw_circle(cursor, 3.0, Color(1.0, 0.9, 0.3))
	draw_rect(Rect2(40, 24, 1200, 70), Color(0.08, 0.05, 0.03, 0.88))
	draw_string(f, Vector2(70, 72), "ОЧКИ %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1.0, 0.85, 0.3))
	draw_string(f, Vector2(480, 72), "КОМБО ×%d" % combo, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0.5, 1.0, 0.6) if combo > 1 else Color(0.8, 0.8, 0.8))
	draw_string(f, Vector2(900, 72), "ВРЕМЯ %.0f" % maxf(t_left, 0.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1.0, 0.5, 0.4) if t_left < 10.0 else Color.WHITE)
	if paused:
		draw_string(f, Vector2(500, 380), "ПАУЗА (Esc)", HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Color.WHITE)
	if hold > 0.1:
		draw_string(f, Vector2(500, 690), "ПРОПУСК… удерживай Esc", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.8, 0.8, 0.8))
	if done:
		draw_rect(Rect2(340, 190, 600, 340), Color(0.06, 0.04, 0.03, 0.97))
		draw_string(f, Vector2(380, 260), "ИТОГ", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color(1.0, 0.85, 0.3))
		draw_string(f, Vector2(380, 330), "ОЧКИ: %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color.WHITE)
		draw_string(f, Vector2(380, 380), "ЛУЧШЕЕ КОМБО: ×%d" % best_combo, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color.WHITE)
		draw_string(f, Vector2(380, 430), "ПОПАДАНИЙ: %d · ПРОПУЩЕНО: %d" % [hits, misses], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.8, 0.8, 0.8))
		draw_string(f, Vector2(380, 495), "[E] / ЛКМ — закрыть", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.8, 0.8, 0.8))

## Писк при попадании: короткий восходящий свист (синтез)
static func synth_squeak() -> AudioStreamWAV:
	var n := int(0.14 * 22050.0)
	var d := PackedByteArray()
	d.resize(n * 2)
	var ph := 0.0
	for i in n:
		var t := float(i) / float(n)
		ph += TAU * lerpf(1700.0, 2900.0, t) / 22050.0
		var v := sin(ph) * (1.0 - t) * 0.5 + sin(ph * 2.0) * (1.0 - t) * 0.12
		d.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	w.data = d
	return w

## Скрип двери: пила с плавающей высотой и шумом (синтез, ~0,9 с)
static func synth_creak() -> AudioStreamWAV:
	var n := int(0.9 * 22050.0)
	var d := PackedByteArray()
	d.resize(n * 2)
	var ph := 0.0
	var r := RandomNumberGenerator.new()
	r.seed = 4
	for i in n:
		var t := float(i) / float(n)
		var f := 180.0 + 90.0 * sin(t * 23.0) + 120.0 * t
		ph += f / 22050.0
		var saw := fmod(ph, 1.0) * 2.0 - 1.0
		var env := sin(t * PI) * (0.55 + 0.45 * sin(t * 41.0))
		var v := (saw * 0.35 + r.randf_range(-1.0, 1.0) * 0.12) * env
		d.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	w.data = d
	return w
