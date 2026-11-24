## Арена FORTUNA 812: три линии турникетов (по 6 секций по 4 м), жёлтые платные зоны, лента чека, касса-щит с бьющимся стеклом.
## Всё — игровые объекты: у секции состояние open / closed / broken, створки-узлы `leaf_l` и `leaf_r`, коллизия закрытой створки (стена для всех),
## индикатор (зелёный / красный / искрит). Тяжёлый удар по закрытой створке — 2 удара ломают; по стеклу кассы — тяжёлый удар или бутылка.
## Босс-приёмы (g67_fortuna.gd) только вызывают методы отсюда.
class_name G67FortunaArena
extends Node3D

signal boss_pinned
signal glass_broken

const LINES_Z := [-174.5, -179.0, -183.5]
const SEC_W := 4.0
const X0 := -12.0
const GATE_HP := 2
const CASH_POS := Vector3(0.0, 0.0, -186.6)
const GLASS_REACH := 2.6
const GATE_REACH := 2.3
const COL_YELLOW := Color(1.0, 0.82, 0.15)
const COL_GREEN := Color(0.25, 1.0, 0.4)
const COL_RED := Color(1.0, 0.18, 0.1)

var game = null
var G = null
var boss = null
var sec: Array = []             # [линия][секция] = {state, hp, t, node, leaf_l, leaf_r, body, light, mat, flash, tell}
var zones: Array = []
var strips: Array = []
var glass: MeshInstance3D = null
var glass_body: StaticBody3D = null
var glass_alive := true
var tablo: Label3D = null
var tablo_t := 0.0
var _hits_seen := {}
var pin_cd := 0.0
var boss_zone_loss := 0.0        # сколько здоровья босс потерял от собственных платных зон (для замера)
var strip_on := false
var zone_dmg_ticks := 0
var coins: Array = []

func build(game_, g_) -> void:
	game = game_
	G = g_
	name = "fortuna_arena"
	sec = []
	for l in 3:
		var row: Array = []
		for i in 6:
			row.append(_make_section(l, i))
		sec.append(row)
	_make_cash()
	var p = game.player
	if p != null and p.combat != null and not p.combat.attack_started.is_connected(_on_attack):
		p.combat.attack_started.connect(_on_attack)

func _make_section(l: int, i: int) -> Dictionary:
	var node := Node3D.new()
	node.name = "gate_%d_%d" % [l, i]
	var cx := X0 + SEC_W * (float(i) + 0.5)
	node.position = Vector3(cx, 0.0, float(LINES_Z[l]))
	add_child(node)
	var leaf_mat := StandardMaterial3D.new()
	var gm_scene: PackedScene = load("res://assets/golda67/podzemka/g67_pz_arena_gate.glb") as PackedScene
	var gm: Node3D = gm_scene.instantiate() as Node3D
	node.add_child(gm)
	var leaf_l: Node3D = gm.find_child("turnstile_gate_l", true, false) as Node3D
	var leaf_r: Node3D = gm.find_child("turnstile_gate_r", true, false) as Node3D
	var ind := MeshInstance3D.new()
	var im := BoxMesh.new()
	im.size = Vector3(0.02, 0.16, 0.05)
	ind.mesh = im
	var imat := StandardMaterial3D.new()
	imat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	imat.albedo_color = COL_GREEN
	ind.material_override = imat
	ind.position = Vector3(-1.64, 0.94, 0.0)
	node.add_child(ind)
	var lt := OmniLight3D.new()
	lt.light_color = COL_GREEN
	lt.light_energy = 0.25
	lt.omni_range = 2.6
	lt.position = Vector3(0, 1.4, 0)
	node.add_child(lt)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(SEC_W - 0.1, 1.7, 0.4)
	cs.shape = bs
	body.add_child(cs)
	body.position = Vector3(0, 0.85, 0)
	body.collision_layer = 9          # 1 — мир, 8 — камера (пружина камеры не уходит в створки)
	node.add_child(body)
	var d := {"state": "open", "hp": GATE_HP, "t": 0.0, "node": node, "leaf_l": leaf_l, "leaf_r": leaf_r, "body": body, "light": lt, "ind": imat, "leaf_mat": leaf_mat, "flash": 0.0, "tell": 0.0, "cs": cs}
	_apply(d)
	return d

func _leaf(mat: StandardMaterial3D, side: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "leaf_l" if side < 0.0 else "leaf_r"
	pivot.position = Vector3(side * 1.7, 0.0, 0.0)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.7, 1.0, 0.08)
	mi.mesh = bm
	mi.material_override = mat
	mi.position = Vector3(-side * 0.85, 0.7, 0.0)
	pivot.add_child(mi)
	return pivot

func _make_cash() -> void:
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3.2, 1.0, 1.0)
	base.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.45, 0.5, 0.42)
	base.material_override = bmat
	base.position = CASH_POS + Vector3(0, 0.5, 0.2)
	add_child(base)
	glass = MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(3.0, 1.4, 0.06)
	glass.mesh = gm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.6, 0.85, 1.0, 0.35)
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmat.metallic = 0.1
	gmat.roughness = 0.05
	glass.material_override = gmat
	glass.position = CASH_POS + Vector3(0, 1.7, 0.75)
	add_child(glass)
	glass_body = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.2, 2.0, 0.5)
	cs.shape = bs
	glass_body.add_child(cs)
	glass_body.position = CASH_POS + Vector3(0, 1.0, 0.6)
	glass_body.collision_layer = 9
	add_child(glass_body)
	tablo = Label3D.new()
	tablo.text = "ТАРИФЫ"
	tablo.font_size = 80
	tablo.pixel_size = 0.006
	tablo.modulate = COL_YELLOW
	tablo.shaded = false
	tablo.position = CASH_POS + Vector3(0, 3.6, 1.0)
	add_child(tablo)

func glass_reset() -> void:
	glass_alive = true
	glass.visible = true
	glass_body.get_child(0).disabled = false

func sec_state(l: int, i: int) -> String:
	return String(sec[l][i]["state"])

func section_at(pos: Vector3) -> Vector2i:
	for l in 3:
		if absf(pos.z - float(LINES_Z[l])) < 1.2:
			var i := int(floor((pos.x - X0) / SEC_W))
			if i >= 0 and i < 6:
				return Vector2i(l, i)
	return Vector2i(-1, -1)

func _apply(d: Dictionary) -> void:
	var st := String(d["state"])
	var closed := st == "closed"
	(d["cs"] as CollisionShape3D).disabled = not closed
	var col := COL_RED if closed else (COL_GREEN if st == "open" else Color(1.0, 0.55, 0.1))
	(d["ind"] as StandardMaterial3D).albedo_color = col
	(d["light"] as OmniLight3D).light_color = col
	(d["leaf_mat"] as StandardMaterial3D).emission = col
	(d["leaf_mat"] as StandardMaterial3D).emission_energy_multiplier = 0.6 if closed else (0.25 if st == "open" else 0.0)
	var tl: Node3D = d["leaf_l"]
	var tr: Node3D = d["leaf_r"]
	var ang_l := 0.0 if closed else (-1.45 if st == "open" else -0.7)
	var ang_r := 0.0 if closed else (1.45 if st == "open" else 1.1)
	tl.rotation.z = 0.0
	tr.rotation.z = 0.0
	if st == "broken":
		tr.rotation.z = -0.85          # левая висит на одной петле
		tl.rotation.z = 0.0
	var tw := (d["node"] as Node3D).create_tween()
	tw.tween_property(tl, "rotation:y", ang_l, 0.25)
	tw.parallel().tween_property(tr, "rotation:y", ang_r, 0.25)

func set_state(l: int, i: int, st: String) -> void:
	var d: Dictionary = sec[l][i]
	if String(d["state"]) == "broken" and st != "broken":
		return
	var was_open := String(d["state"]) != "closed"
	d["state"] = st
	d["t"] = 0.0
	_apply(d)
	if st == "closed" and was_open:
		var gp: Vector3 = (d["node"] as Node3D).global_position + Vector3(0, 0.9, 0)
		game.fx.sparks(gp, Vector3.UP, 10, Color(1.0, 0.85, 0.3), 0.8, 45.0)
		game.shake(0.12)
		_check_pin(l, i)

func _check_pin(l: int, i: int) -> void:
	if boss == null or not is_instance_valid(boss) or pin_cd > 0.0:
		return
	var s := section_at(boss.global_position)
	if s.x == l and s.y == i:
		pin_cd = 4.0
		boss_pinned.emit()
		tablo.text = "ОШИБКА ОПЛАТЫ"
		tablo_t = 2.5

func flash(l: int, sec_t: float) -> void:
	for i in 6:
		(sec[l][i] as Dictionary)["flash"] = sec_t

## Закрыть линию на dur секунд, секция open_idx остаётся открытой (зелёной)
func close_line(l: int, open_idx: int, dur: float) -> void:
	for i in 6:
		var d: Dictionary = sec[l][i]
		if String(d["state"]) == "broken":
			continue
		if i == open_idx:
			set_state(l, i, "open")
		else:
			set_state(l, i, "closed")
			d["t"] = 0.0
			d["hold"] = dur

## Хлопок одной секции с меткой tell секунд (фаза 3)
func clap(l: int, i: int, tell: float, hold: float) -> void:
	var d: Dictionary = sec[l][i]
	if String(d["state"]) != "open":
		return
	d["flash"] = tell
	d["clap_in"] = tell
	d["clap_hold"] = hold

func open_all(l: int) -> void:
	for i in 6:
		if sec_state(l, i) == "closed":
			set_state(l, i, "open")

func break_gate(l: int, i: int) -> void:
	set_state(l, i, "broken")

func damage_gate(l: int, i: int, heavy: bool) -> bool:
	var d: Dictionary = sec[l][i]
	if String(d["state"]) != "closed" or not heavy:
		return false
	d["hp"] = int(d["hp"]) - 1
	game.popup((d["node"] as Node3D).global_position + Vector3(0, 1.9, 0), "ТРЕЩИТ" if int(d["hp"]) > 0 else "СЛОМАНО", Color(1.0, 0.8, 0.3))
	if int(d["hp"]) <= 0:
		set_state(l, i, "broken")
		G.events.append(["gate_broken", l, i])
	return true

func break_glass() -> bool:
	if not glass_alive:
		return false
	glass_alive = false
	glass.visible = false
	glass_body.get_child(0).disabled = true
	game.popup(glass.global_position + Vector3(0, 0.6, 0), "СТЕКЛО!", Color(0.6, 0.9, 1.0))
	glass_broken.emit()
	G.events.append(["glass_broken"])
	return true

## Бутылка Водяры в стекло: место попадания у кассы
func bottle_hit(at: Vector3) -> bool:
	if glass_alive and at.distance_to(glass.global_position) < 1.9:
		return break_glass()
	return false

func _on_attack(a) -> void:
	if not bool(a.heavy):
		return
	await get_tree().create_timer(0.2).timeout
	if game == null or game.player == null or not is_instance_valid(game.player):
		return
	var p = game.player
	var pp: Vector3 = p.global_position
	var fw := Vector3(sin(p.face), 0, cos(p.face))
	for l in 3:
		for i in 6:
			var d: Dictionary = sec[l][i]
			if String(d["state"]) != "closed":
				continue
			var gp: Vector3 = (d["node"] as Node3D).global_position
			var dx := maxf(absf(pp.x - gp.x) - SEC_W * 0.5, 0.0)
			var dz := absf(pp.z - gp.z)
			if sqrt(dx * dx + dz * dz) < GATE_REACH:
				var to := Vector3(gp.x - pp.x, 0.0, gp.z - pp.z)
				to.x = clampf(to.x, -SEC_W * 0.5, SEC_W * 0.5) if dx > 0.0 else 0.0
				if to.length() < 0.4 or fw.dot(to.normalized()) > 0.25:
					if damage_gate(l, i, true):
						return
	if glass_alive and Vector2(pp.x - glass.global_position.x, pp.z - glass.global_position.z).length() < GLASS_REACH and fw.dot((glass.global_position - pp).normalized()) > 0.1:
		break_glass()

## ИИ босса сам выходит из платной зоны за 1–1,5 с (кроме оглушения и зажима)
func _boss_leave(z: Dictionary, dt: float) -> void:
	if not z.has("leave_at") or boss == null or not is_instance_valid(boss) or not bool(z["fine_boss"]):
		return
	z["leave_at"] = float(z["leave_at"]) - dt
	if float(z["leave_at"]) > 0.0 or boss.state == "stun" or boss.state == "dead":
		return
	var c: Vector3 = (z["n"] as Node3D).global_position
	var sz: Vector2 = z["size"]
	var bp: Vector3 = boss.global_position
	var dx := sz.x * 0.5 - absf(bp.x - c.x)
	var dz := sz.y * 0.5 - absf(bp.z - c.z)
	var to := bp
	if dx < dz:
		to.x = c.x + signf(bp.x - c.x if absf(bp.x - c.x) > 0.01 else 1.0) * (sz.x * 0.5 + 0.8)
	else:
		to.z = c.z + signf(bp.z - c.z if absf(bp.z - c.z) > 0.01 else 1.0) * (sz.y * 0.5 + 0.8)
	to.x = clampf(to.x, -11.0, 11.0)
	to.z = clampf(to.z, -187.0, -170.5)
	var tw: Tween = boss.create_tween()
	tw.tween_property(boss, "global_position", to, 0.35)
	z.erase("leave_at")
	z["boss_in"] = 0.0
	z["boss_done"] = true          # из этой зоны босс уже выходил: второй раз она его не штрафует

## Платная зона size = (ширина по x, глубина по z); fade — проявление, active — сколько действует, creep — ползёт к герою, м/с
func add_zone(center: Vector3, size: Vector2, fade: float, active: float, creep := 0.0, fine_boss := true) -> Dictionary:
	var n := Node3D.new()
	add_child(n)
	n.global_position = Vector3(center.x, 0.04, center.z)
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	mi.rotation_degrees = Vector3(-90, 0, 0)
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.albedo_color = Color(COL_YELLOW.r, COL_YELLOW.g, COL_YELLOW.b, 0.0)
	mi.material_override = mt
	n.add_child(mi)
	var lb := Label3D.new()
	lb.text = "ТАРИФ"
	lb.font_size = 96
	lb.pixel_size = 0.008
	lb.modulate = Color(0.1, 0.07, 0.0, 0.9)
	lb.shaded = false
	lb.rotation_degrees = Vector3(-90, 0, 0)
	lb.position = Vector3(0, 0.03, 0)
	n.add_child(lb)
	var z := {"n": n, "size": size, "fade": fade, "t": 0.0, "active": active, "mat": mt, "tick": 0.0, "creep": creep, "label": lb, "boss_tick": 0.0, "fine_boss": fine_boss}
	zones.append(z)
	return z

func add_strip(center: Vector3, yaw: float, width: float, length: float, dur: float) -> Dictionary:
	var n := Node3D.new()
	add_child(n)
	n.global_position = Vector3(center.x, 0.035, center.z)
	n.rotation.y = yaw
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(width, length)
	mi.mesh = qm
	mi.rotation_degrees = Vector3(-90, 0, 0)
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.albedo_color = Color(0.95, 0.95, 0.85, 0.7)
	mi.material_override = mt
	n.add_child(mi)
	var s := {"n": n, "w": width, "l": length, "t": 0.0, "dur": dur}
	strips.append(s)
	return s

func in_zone(z: Dictionary, pos: Vector3) -> bool:
	var c: Vector3 = (z["n"] as Node3D).global_position
	var sz: Vector2 = z["size"]
	return absf(pos.x - c.x) < sz.x * 0.5 and absf(pos.z - c.z) < sz.y * 0.5

func _process(dt: float) -> void:
	if game == null:
		return
	pin_cd = maxf(0.0, pin_cd - dt)
	if tablo_t > 0.0:
		tablo_t -= dt
		if tablo_t <= 0.0:
			tablo.text = "ТАРИФЫ"
	var tt := Time.get_ticks_msec() * 0.001
	for l in 3:
		for i in 6:
			var d: Dictionary = sec[l][i]
			var st := String(d["state"])
			if float(d["flash"]) > 0.0:
				d["flash"] = float(d["flash"]) - dt
				var on := int(tt * 10.0) % 2 == 0
				(d["ind"] as StandardMaterial3D).albedo_color = COL_YELLOW if on else Color(0.3, 0.25, 0.0)
				(d["light"] as OmniLight3D).light_color = COL_YELLOW
				if float(d["flash"]) <= 0.0:
					_apply(d)
			if d.has("clap_in"):
				d["clap_in"] = float(d["clap_in"]) - dt
				if float(d["clap_in"]) <= 0.0:
					var hold := float(d["clap_hold"])
					d.erase("clap_in")
					set_state(l, i, "closed")
					d["hold"] = hold
			if st == "closed" and d.has("hold"):
				d["hold"] = float(d["hold"]) - dt
				if float(d["hold"]) <= 0.0:
					d.erase("hold")
					set_state(l, i, "open")
			elif st == "broken":
				(d["ind"] as StandardMaterial3D).albedo_color = Color(1.0, 0.6, 0.1) if int(tt * 14.0) % 3 == 0 else Color(0.1, 0.05, 0.0)
				if randf() < dt * 1.2:
					game.fx.sparks((d["node"] as Node3D).global_position + Vector3(0.6, 0.8, 0), Vector3.UP, 5, Color(1.0, 0.8, 0.3), 0.5, 30.0)
	var p = game.player
	for z in zones.duplicate():
		z["t"] = float(z["t"]) + dt
		_boss_leave(z, dt)
		var k := clampf(float(z["t"]) / maxf(float(z["fade"]), 0.01), 0.0, 1.0)
		(z["mat"] as StandardMaterial3D).albedo_color.a = 0.55 * k
		if float(z["t"]) >= float(z["fade"]):
			var live := float(z["t"]) - float(z["fade"])
			if float(z["creep"]) > 0.0 and p != null:
				var n: Node3D = z["n"]
				var dirv: Vector3 = p.global_position - n.global_position
				dirv.y = 0.0
				if dirv.length() > 0.2:
					n.global_position += dirv.normalized() * float(z["creep"]) * dt
			z["tick"] = float(z["tick"]) + dt
			if float(z["tick"]) >= 0.5:
				z["tick"] = 0.0
				if p != null and in_zone(z, p.global_position) and float(G.run.get("cert_t", 0.0)) > 0.0:
					G.run["cert_t"] = maxf(0.0, float(G.run["cert_t"]) - 0.5)          # «Справка»: первые секунды в зоне бесплатно
					game.popup(p.global_position + Vector3(0, 2.0, 0), "ПО СПРАВКЕ", COL_YELLOW)
					G.events.append(["zone_cert"])
				elif p != null and in_zone(z, p.global_position):
					var gl := int(G.run.get("golda", 0))
					if gl > 0:
						var take := mini(2, gl)
						G.run["golda"] = gl - take
						game.popup(p.global_position + Vector3(0, 2.0, 0), "-%d" % take, COL_YELLOW)
						G.events.append(["zone_gold", take])
						if gl - take <= 0:
							G.events.append(["zone_broke"])
					else:
						p.take_damage(3.0, (z["n"] as Node3D).global_position, null, {"unblockable": true})
						zone_dmg_ticks += 1
						G.events.append(["zone_dmg"])
				if bool(z["fine_boss"]) and boss != null and is_instance_valid(boss) and in_zone(z, boss.global_position):
					z["boss_in"] = float(z.get("boss_in", 0.0)) + 0.5
					if float(z["boss_in"]) <= 3.0 and not bool(z.get("boss_done", false)):
						var loss: float = boss.max_hp * 0.003
						boss.hp = maxf(1.0, boss.hp - loss)
						boss_zone_loss += loss
						game.popup(boss.global_position + Vector3(0, boss.height + 0.3, 0), "ШТРАФ", Color(1.0, 0.5, 0.2))
						G.events.append(["zone_boss"])
					if not z.has("leave_at"):
						z["leave_at"] = randf_range(1.0, 1.5)
						if randf() < 0.5:
							game.popup(boss.global_position + Vector3(0, boss.height + 0.8, 0), G67Fortuna.LINES["zone_boss"], Color(1.0, 0.92, 0.3))
				else:
					z["boss_in"] = 0.0
					z.erase("leave_at")
			if live >= float(z["active"]):
				(z["n"] as Node3D).queue_free()
				zones.erase(z)
	var on_strip := false
	for s in strips.duplicate():
		s["t"] = float(s["t"]) + dt
		if p != null:
			var n2: Node3D = s["n"]
			var lp: Vector3 = n2.global_transform.affine_inverse() * p.global_position
			if absf(lp.x) < float(s["w"]) * 0.5 and absf(lp.z) < float(s["l"]) * 0.5 and p.is_on_floor() and p.global_position.y < 0.35:
				on_strip = true
				G.events.append(["check_slow"])
		if float(s["t"]) >= float(s["dur"]):
			(s["n"] as Node3D).queue_free()
			strips.erase(s)
	if p != null:
		if on_strip:
			p.slow_mul = 0.55
			strip_on = true
		elif strip_on:
			p.slow_mul = 1.0
			strip_on = false
	for cn in coins.duplicate():
		cn[1] = float(cn[1]) - dt
		if float(cn[1]) <= 0.0:
			(cn[0] as Node3D).queue_free()
			coins.erase(cn)

## Монета лежит на полу 6 с (визуал без урона)
func coin_drop(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.16
	cm.bottom_radius = 0.16
	cm.height = 0.03
	mi.mesh = cm
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(1.0, 0.82, 0.2)
	mt.metallic = 0.8
	mt.roughness = 0.3
	mi.material_override = mt
	add_child(mi)
	mi.global_position = Vector3(clampf(pos.x, -11.5, 11.5), 0.03, clampf(pos.z, -187.5, -170.5))
	coins.append([mi, 6.0])

func clear_all() -> void:
	if game != null and game.player != null:
		game.player.slow_mul = 1.0
	strip_on = false
	for cn in coins:
		if is_instance_valid(cn[0]):
			(cn[0] as Node3D).queue_free()
	coins = []
	for z in zones:
		if is_instance_valid(z["n"]):
			(z["n"] as Node3D).queue_free()
	for s in strips:
		if is_instance_valid(s["n"]):
			(s["n"] as Node3D).queue_free()
	zones = []
	strips = []
	for l in 3:
		for i in 6:
			var d: Dictionary = sec[l][i]
			d["state"] = "open"
			d["hp"] = GATE_HP
			d.erase("hold")
			d.erase("clap_in")
			_apply(d)
	glass_reset()
