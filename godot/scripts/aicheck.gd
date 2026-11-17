## Проверка ИИ врагов и боссов (enemy_ai.gd, boss_moves.gd, player_read.gd): -- --aicheck=<папка>, с --resolution 1280x720.
## 1) данные: у восьми типов есть приёмы, связки ведут на существующие, у каждого бьющего — метка или своя зона;
## 2) каждый приём каждого моба: замах с меткой, урон внутри зоны и нет урона за её краем (ближний бой), отдых после;
## 3) честность в толпе: ближних атакующих ≤ 2, удары разных врагов не в одно мгновение, герой не стоит в оглушении
##    дольше секунды подряд; роли (фланг, ожидание, прикрытие стрелка); предел призыва фермера;
## 4) чтение игрока: блок → пробивающий удар BOT, стоит без ударов → контра CLIPPER, повтор удара → стойка MOD;
## 5) каждый приём каждой фазы девяти боссов: прошёл без ошибок, опасность видна раньше урона, фазы различаются;
##    адаптация босса (воздух, спина, блок, дистанция); 6) кадр с толпой и снарядами.
## Снимки — ai_<тип>.png (середина замаха), boss_<id>.png. В конце «AICHECK ok» или «AICHECK ОШИБОК: n».
extends Node

var game
var out := ""
var cam: Camera3D
var slow := 1.0
var fails := 0
var started := false
var frame_n := 0
var P
const KINDS := ["bot", "clipper", "hater", "troll", "ghost", "lawyer", "mod", "farmer"]

func _ready() -> void:
	cam = Camera3D.new()
	game.add_child(cam)
	DirAccess.make_dir_recursive_absolute(out)

func owns_camera() -> bool:
	return false

func hide_hud() -> bool:
	return false

func frame(_dt: float) -> void:
	frame_n += 1
	if not started and frame_n > 3:
		started = true
		_run()

func ok(c: bool, msg: String) -> void:
	print(("AI ok: " if c else "AI ОШИБКА: ") + msg)
	if not c:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func clear(keep = null) -> void:
	for en in game.enemies:
		if is_instance_valid(en) and en != keep:
			en.queue_free()
	game.enemies = [keep] if keep != null and is_instance_valid(keep) else []
	for b in game.bolts:
		if is_instance_valid(b["n"]):
			b["n"].queue_free()
	game.bolts = []
	for z in game.zones:
		if is_instance_valid(z["n"]):
			z["n"].queue_free()
	game.zones = []
	await frames(3)

func stage() -> void:
	game.ch = 0
	game._load_chapter(false)
	game.over = false
	game.banner_t = 0.0
	game.dlg_box.visible = false
	P = game.player
	P.global_position = Vector3(0, 0.05, 4.0)
	P.face = PI
	P.velocity = Vector3.ZERO
	P.state = "move"
	P.auto_input = {}
	game.tag.auto_assist = false
	game.buddy.wait = 999.0
	await clear()
	game.mode = "fight"
	game.pending = []
	game.waves = []

func reset_player(at: Vector3) -> void:
	P.global_position = at
	P.velocity = Vector3.ZERO
	P.state = "move"
	P.inv = 0.0
	P.max_hp = 1.0e6
	P.hp = 1.0e6
	P.slow_t = 0.0

func shot(name: String, at: Vector3) -> void:
	cam.global_position = at + Vector3(0.01, 10.0, 7.0)
	cam.look_at(at, Vector3.UP)
	cam.fov = 60.0
	cam.make_current()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name))
	cam.clear_current(true)

## Один приём моба: метка, урон внутри / вне зоны, отдых
func one_move(kind: String, id: String) -> void:
	var m: Dictionary = EnemyAI.MOVES[kind][id]
	var act: String = m["act"]
	var e = game._make_enemy(kind, "", Vector3(0, 0.05, 0))
	e.cool = 999.0
	await frames(70)                     # появился
	e.global_position = Vector3(0, 0.05, 0)      # пока появлялся, мог отойти
	e.velocity = Vector3.ZERO
	var d: float = clampf((float(m.get("min", 0.0)) + minf(float(m.get("max", 4.0)), 6.0)) * 0.5, 1.4, 6.0)
	if act in ["melee", "lunge"]:
		d = minf(d, float(m.get("r", 2.0)) - 0.4)
	reset_player(Vector3(0, 0.05, d))
	e.face = 0.0
	e.state = "chase"
	var hp0: float = P.hp
	var z0: int = game.zones.size()
	var b0: int = game.bolts.size()
	e._start_move(EnemyAI.move_of(e, id))
	await frames(2)
	var warned: bool = e.tell.visible or e.ring.visible
	var w0: float = float(e.cfg["wind"])
	var dmg_t := -1
	var warn_t := 0 if warned else -1
	for i in 260:
		if e.state == "wind":
			e.face = 0.0              # смотрит на героя (герой стоит прямо перед ним)
		await get_tree().physics_frame
		if warn_t < 0 and (e.tell.visible or e.ring.visible or game.zones.size() > z0 or game.bolts.size() > b0 or e.state == "charge"):
			warn_t = i
		if dmg_t < 0 and P.hp < hp0:
			dmg_t = i
		if not is_instance_valid(e) or (e.state == "chase" and i > 40):
			break
	var hits: bool = act in ["melee", "lunge", "slam", "charge", "shoot", "zone", "ring", "repel"] and float(m.get("dmg", 1.0)) + float(m.get("dmg_abs", 0.0)) > 0.0 and not m.has("then") and not bool(m.get("from_sides", false))
	ok(w0 >= 0.28 or act == "blink", "%s/%s: замах %.2f с" % [kind, id, w0])
	if hits:
		ok(warn_t >= 0 and (dmg_t < 0 or dmg_t > warn_t + 8), "%s/%s: метка до урона (метка кадр %d, урон кадр %d)" % [kind, id, warn_t, dmg_t])
		if act in ["melee", "lunge", "slam", "repel"]:
			ok(dmg_t >= 0, "%s/%s: герой в зоне получил урон" % [kind, id])
	if is_instance_valid(e):
		e.queue_free()
	await clear()

## Ближний удар за краем метки не попадает
func edge_case(kind: String, id: String) -> void:
	var m: Dictionary = EnemyAI.MOVES[kind][id]
	var e = game._make_enemy(kind, "", Vector3(0, 0.05, 0))
	e.cool = 999.0
	await frames(70)
	e.global_position = Vector3(0, 0.05, 0)
	e.velocity = Vector3.ZERO
	var shape: Array = EnemyAI.tell_of(e, EnemyAI.move_of(e, id))
	reset_player(Vector3(0, 0.05, float(shape[0]) + 0.6))
	e.face = 0.0
	var hp0: float = P.hp
	e._start_move(EnemyAI.move_of(e, id))
	for i in 160:
		if e.state == "wind":
			e.face = 0.0
		await get_tree().physics_frame
		if e.state == "chase":
			break
	ok(P.hp == hp0, "%s/%s: за краем метки (%.1f м) — без урона" % [kind, id, float(shape[0])])
	e.queue_free()
	await clear()

func _run() -> void:
	await stage()
	# ---- 0. портал появления — там, где враг (раньше рисовался в центре арены) ----
	var sp = game._make_enemy("bot", "", Vector3(7.0, 0.05, -6.0))
	ok(sp.born_at.distance_to(Vector3(7.0, 0.05, -6.0)) < 0.01, "портал появления под врагом, а не в центре арены (%s)" % str(sp.born_at))
	sp.queue_free()
	await clear()
	# ---- 1. данные ----
	for k in KINDS:
		ok(EnemyAI.MOVES.has(k) and (EnemyAI.MOVES[k] as Dictionary).size() >= 5, "%s: приёмов %d" % [k, (EnemyAI.MOVES.get(k, {}) as Dictionary).size()])
		for id in EnemyAI.MOVES.get(k, {}):
			var m: Dictionary = EnemyAI.MOVES[k][id]
			if m.has("then"):
				ok(EnemyAI.MOVES[k].has(String(m["then"])), "%s/%s: связка ведёт на «%s»" % [k, id, m["then"]])
			var probe := {"act": m["act"]}
			probe.merge(m)
			var shape: Array = EnemyAI.tell_of(null, probe)
			var own: bool = String(m["act"]) in ["zone", "blink", "clones"] or bool(m.get("from_sides", false))
			ok(not shape.is_empty() or own, "%s/%s: у удара есть метка" % [k, id])
	# ---- 2. каждый приём каждого моба ----
	for k in KINDS:
		var first := true
		for id in EnemyAI.MOVES[k]:
			await one_move(k, id)
			if first:
				first = false
		# снимок середины замаха основного приёма
		var e = game._make_enemy(k, "", Vector3(0, 0.05, 0))
		e.cool = 999.0
		await frames(70)
		reset_player(Vector3(0, 0.05, 2.0))
		var main_id: String = (EnemyAI.MOVES[k] as Dictionary).keys()[0]
		e._start_move(EnemyAI.move_of(e, main_id))
		e.cfg["wind"] = 50.0
		e.t = 25.0
		await frames(3)
		await shot("ai_%s.png" % k, Vector3(0, 0, 1.0))
		e.queue_free()
		await clear()
	for it in [["bot", "jab"], ["bot", "haymaker"], ["clipper", "counter"], ["troll", "slam"], ["mod", "punch"], ["ghost", "touch"]]:
		await edge_case(it[0], it[1])
	# ---- 3. толпа: честность ----
	var crowd: Array = []
	reset_player(Vector3(0, 0.05, 0))
	for i in 6:
		var a := TAU * i / 6.0
		crowd.append(game._make_enemy(["bot", "bot", "clipper", "bot", "mod", "troll"][i], "", Vector3(sin(a) * 5.0, 0.05, cos(a) * 5.0)))
	crowd.append(game._make_enemy("hater", "", Vector3(0, 0.05, -9.0)))
	await frames(70)
	var max_att := 0
	var min_gap := 99.0
	var hurt_run := 0.0
	var hurt_max := 0.0
	var roles := {}
	var hp_prev: float = P.hp
	var hits_n := 0
	var was := {}
	var strikes: Array = []
	for i in 60 * 15:
		await get_tree().physics_frame
		for en in crowd:
			if is_instance_valid(en) and not en.cfg.has("ranged"):
				var id: int = en.get_instance_id()
				if String(was.get(id, "")) == "wind" and en.state != "wind" and en.state in ["recover", "charge", "chase"]:
					strikes.append([i / 60.0, id])
				was[id] = String(en.state)
		var att: int = game.melee_attackers()
		max_att = max(max_att, att)
		if P.hp < hp_prev:
			hits_n += 1
		hp_prev = P.hp
		hurt_run = hurt_run + 1.0 / 60.0 if P.state == "hurt" else 0.0
		hurt_max = maxf(hurt_max, hurt_run)
		if i % 30 == 0:
			for en in crowd:
				if is_instance_valid(en):
					roles[String(en.role)] = int(roles.get(String(en.role), 0)) + 1
	ok(max_att <= 2, "толпа: ближних атакующих одновременно ≤ 2 (было %d)" % max_att)
	ok(hits_n > 3, "толпа: враги действительно бьют (%d попаданий за 15 с)" % hits_n)
	for k in strikes.size():
		for j in range(k + 1, strikes.size()):
			if int(strikes[j][1]) != int(strikes[k][1]):
				min_gap = minf(min_gap, float(strikes[j][0]) - float(strikes[k][0]))
	ok(strikes.size() >= 4 and min_gap >= 0.2, "толпа: удары разных врагов не в одно мгновение (ударов %d, ближе всего %.2f с)" % [strikes.size(), min_gap])
	ok(hurt_max <= 1.0, "толпа: в оглушении подряд не дольше 1 с (%.2f)" % hurt_max)
	ok(roles.has("flank") or roles.has("hold"), "толпа: роли — %s" % str(roles))
	ok(roles.has("guard"), "толпа: MOD прикрывает стрелка")
	await clear()
	# ---- 3б. предел призыва ----
	var fm = game._make_enemy("farmer", "", Vector3(0, 0.05, -8.0))
	await frames(70)
	reset_player(Vector3(0, 0.05, 2.0))
	for i in 6:
		fm.state = "chase"
		fm._start_move(EnemyAI.move_of(fm, "summon"))
		await frames(80)
		fm.move_cd = {}
	ok(EnemyAI.summoned_alive(fm) <= int(EnemyAI.TUNE["summon_cap"]), "фермер: призванных живых ≤ %d (%d)" % [int(EnemyAI.TUNE["summon_cap"]), EnemyAI.summoned_alive(fm)])
	await clear()
	# ---- 4. чтение игрока ----
	var R = game.read
	var b = game._make_enemy("bot", "", Vector3(0, 0.05, 0))
	await frames(70)
	reset_player(Vector3(0, 0.05, 1.8))
	R.block_streak = 2.0
	var nb := 0
	for i in 40:
		b.move_cd = {}
		var pk: Dictionary = EnemyAI.pick(b, 1.8)
		if String(pk.get("id", "")) == "breaker":
			nb += 1
	ok(nb >= 15, "игрок держит блок — BOT чаще пробивает (%d из 40)" % nb)
	R.block_streak = 0.0
	b.queue_free()
	var c = game._make_enemy("clipper", "", Vector3(0, 0.05, 0))
	await frames(70)
	R.idle_front = 2.0
	var nc := 0
	for i in 40:
		c.move_cd = {}
		if String(EnemyAI.pick(c, 1.8).get("id", "")) == "counter":
			nc += 1
	ok(nc >= 15, "игрок стоит без ударов — CLIPPER контратакует (%d из 40)" % nc)
	R.idle_front = 0.0
	c.queue_free()
	var md = game._make_enemy("mod", "", Vector3(0, 0.05, 0))
	await frames(70)
	R.same_hits = 6
	var nm := 0
	for i in 40:
		md.move_cd = {}
		if String(EnemyAI.pick(md, 2.0).get("id", "")) == "wall":
			nm += 1
	ok(nm >= 10, "игрок повторяет удар — MOD встаёт в стойку (%d из 40)" % nm)
	R.same_hits = 0
	await clear()
	# ---- 5. боссы ----
	var bosses: Dictionary = game.story["BOSS"]
	for bid in bosses:
		var raw: Array = bosses[bid]["phases"]
		var bn = game._make_enemy("", String(bid), Vector3(0, 0.05, -2.0))
		bn.special_cd = 999.0
		await frames(80)
		var phs: Array = bn.boss["phases"]
		ok(phs.size() == raw.size(), "%s: фаз столько же, сколько в story.json (%d)" % [bosses[bid]["n"], raw.size()])
		for ph in phs.size():
			var cur: Array = phs[ph]
			if ph > 0:
				var prev: Array = phs[ph - 1]
				var diff := 0
				for mvn in cur:
					if not prev.has(mvn):
						diff += 1
				ok(diff >= 1, "%s: фаза %d отличается от прошлой (%d новых приёмов)" % [bosses[bid]["n"], ph + 1, diff])
			for mvn in cur:
				await boss_move(bn, String(bid), ph, String(mvn))
		if bn != null and is_instance_valid(bn):
			bn.phase = phs.size() - 1
			bn.state = "chase"
			BossMoves.start(bn, String(phs[phs.size() - 1][phs[phs.size() - 1].size() - 1]))
			await frames(40)
			await shot("boss_%s.png" % bid, Vector3(0, 0, 0))
			bn.queue_free()
		await clear()
	# ---- 5б. адаптация ----
	var ab = game._make_enemy("", "golem", Vector3(0, 0.05, -2.0))
	await frames(80)
	var seen := {}
	for fact in [["air", 0.8, "anti_air"], ["behind", 0.9, "turn_strike"], ["block_streak", 2.0, "guard_break"], ["close", 0.95, "close_burst"]]:
		R.air = 0.0
		R.behind = 0.0
		R.block_streak = 0.0
		R.close = 0.5
		R.set(String(fact[0]), float(fact[1]))
		var got := 0
		for i in 60:
			ab.counter_at = 0.0
			if BossMoves.adapt(ab) == String(fact[2]):
				got += 1
		ok(got >= 8 and got <= 40, "босс отвечает на «%s» приёмом %s иногда, а не всегда (%d из 60)" % [fact[0], fact[2], got])
	R.air = 0.0
	R.behind = 0.0
	R.block_streak = 0.0
	R.close = 0.5
	ab.counter_at = 0.0
	ab.counter_at = ab.age + 100.0
	ok(BossMoves.adapt(ab) == "", "после ответа — перерыв (не подряд)")
	await clear()
	# ---- 6. кадр: толпа и снаряды ----
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	reset_player(Vector3(0, 0.05, 0))
	for i in 9:
		var a := TAU * i / 9.0
		game._make_enemy(KINDS[i % KINDS.size()], "", Vector3(sin(a) * 7.0, 0.05, cos(a) * 7.0))
	await frames(70)
	for i in 40:
		game.spawn_bolt(Vector3(randf_range(-8, 8), 1.0, -12.0), Vector3(0, 0, 4.0), 1.0, null, i % 3 == 0, Color(0.4, 1.0, 0.55), {"turn": 0.8})
	var times: Array = []
	var t0 := Time.get_ticks_usec()
	for i in 240:
		P.inv = 9.0
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append((now - t0) / 1000.0)
		t0 = now
	times.sort()
	var avg := 0.0
	for x in times:
		avg += float(x)
	avg /= times.size()
	var p95: float = times[int(times.size() * 0.95)]
	print("AI кадр: 9 врагов с ИИ + снаряды — среднее %.2f мс, 95%% %.2f мс" % [avg, p95])
	ok(p95 < 33.3, "кадр с толпой и снарядами: 95-й процентиль < 33 мс (%.2f)" % p95)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	print("AICHECK ok" if fails == 0 else "AICHECK ОШИБОК: %d" % fails)
	get_tree().quit()

## Один приём босса: без ошибок, опасность видна раньше урона
func boss_move(bn, bid: String, ph: int, move: String) -> void:
	if not is_instance_valid(bn):
		return
	reset_player(Vector3(0, 0.05, 3.0))
	bn.global_position = Vector3(0, 0.05, -2.0)
	bn.phase = ph
	bn.state = "chase"
	bn.t = 0.0
	bn.cool = 999.0
	bn.hp = bn.max_hp
	var hp0: float = P.hp
	var z0: int = game.zones.size()
	var b0: int = game.bolts.size()
	var l0: int = game.lobs.size()
	var n0: int = game.enemies.size()
	if BossMoves.is_new(move):
		BossMoves.start(bn, move)
	else:
		bn.move = move
		bn._wind(String(bn.cfg["clip"]), 0.6)
	var warn_t := -1
	var dmg_t := -1
	for i in 60 * 11:
		await get_tree().physics_frame
		if not is_instance_valid(bn):
			break
		if warn_t < 0 and (bn.tell.visible or bn.ring.visible or game.zones.size() > z0 or game.bolts.size() > b0 or game.lobs.size() > l0 or bn.state == "charge" or game.enemies.size() > n0):
			warn_t = i
		if dmg_t < 0 and P.hp < hp0:
			dmg_t = i
		P.inv = 0.0 if P.state != "hurt" else P.inv
		if bn.state == "chase" and game.zones.is_empty() and game.bolts.is_empty() and i > 30:
			break
		if bn.state in ["recover"] and i > 30 and game.zones.is_empty():
			bn.state = "chase"
	ok(dmg_t < 0 or (warn_t >= 0 and dmg_t >= warn_t + 6), "%s ф%d %s: опасность видна раньше урона (метка %d, урон %d)" % [bid, ph + 1, move, warn_t, dmg_t])
	await clear(bn)
