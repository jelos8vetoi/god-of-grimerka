extends RefCounted
## Spawn times are in active, unscaled seconds. All pressure settings have safe bounds.

const MAX_ALIVE := 9
const MAX_BODIES := 12 # Includes dying enemies until their existing animation frees them.
const MAX_RANGED := 2
const SAFE_DISTANCE := 6.0
const BOSS_ORDER := ["courier", "golem", "hype", "dislike", "major", "strike", "botlord", "ghostv", "algo"]
const EVENTS := ["surge", "elite", "hazard"]
const EVENT_NAMES := {"surge": "ШТУРМ", "elite": "ЭЛИТНОЕ ПОДКРЕПЛЕНИЕ", "hazard": "ОПАСНАЯ ЗОНА"}
const RECIPES := [
	{"kinds": ["bot"], "cost": 1, "after": 0.0},
	{"kinds": ["bot", "bot"], "cost": 2, "after": 8.0},
	{"kinds": ["clipper", "bot"], "cost": 3, "after": 18.0},
	{"kinds": ["bot", "hater"], "cost": 3, "after": 35.0},
	{"kinds": ["mod", "clipper"], "cost": 5, "after": 75.0},
	{"kinds": ["ghost", "bot", "hater"], "cost": 6, "after": 120.0},
	{"kinds": ["troll", "clipper", "bot"], "cost": 7, "after": 180.0},
	{"kinds": ["mod", "lawyer", "clipper"], "cost": 8, "after": 240.0},
]

var threat_half_time := 210.0
var opening_interval := 5.0
var minimum_interval := 1.8
var max_health_bonus := 0.25
var max_speed_bonus := 0.08
var elapsed := 0.0
var threat := 0.0
var queue: Array = []
var rng := RandomNumberGenerator.new()
var next_boss := 300.0
var boss_interval := 150.0
var boss_index := 0
var bosses_defeated := 0
var events_completed := 0
var next_event := 75.0
var event_interval := 60.0
var event_kind := ""
var _event_index := 0
var _event_end := 0.0
var _event_action := 0.0
var _boss_notice := false
var _next_group := 1.2
var _next_spawn := 0.0
var _clearance := BoxShape3D.new()

func pressure_at(seconds: float) -> float:
	var t := maxf(0.0, seconds)
	return t / (t + maxf(1.0, threat_half_time))

func advance(real_delta: float) -> void:
	elapsed += real_delta
	threat = pressure_at(elapsed)

func tick(game) -> void:
	var seconds := elapsed
	var alive := 0
	var bodies := 0
	var ranged := 0
	var elites := 0
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		bodies += 1
		# Portal arrivals already reserve a slot, even before alive() makes them targetable.
		if enemy.state != "dead":
			alive += 1
			if enemy.cfg.has("ranged"):
				ranged += 1
			elites += int(enemy.survival_elite)
	if is_instance_valid(game.boss_e):
		if game.boss_e.state == "dead":
			_finish_boss(game)
		else:
			return
	if seconds >= next_boss:
		if not _boss_notice:
			_boss_notice = true
			queue.clear()
			_end_event(game, false)
			game.toast("БОСС ПРИБЛИЖАЕТСЯ · зачисти арену")
		if alive <= 1 and bodies < MAX_BODIES and seconds >= _next_spawn:
			_next_spawn = seconds + 0.4
			var pos := _find_position(game, true)
			if pos != Vector3.INF:
				_start_boss(game, pos)
		return
	_tick_event(game)
	if alive >= mini(MAX_ALIVE, game.MAX_ALIVE) or bodies >= MAX_BODIES:
		return
	if event_kind in ["surge", "elite"] and elapsed >= _event_action:
		_event_action = elapsed + 1.0
		if event_kind == "surge" or elites == 0:
			var event_pos := _find_position(game)
			if event_pos != Vector3.INF:
				_spawn_regular(game, "clipper" if event_kind == "elite" else "bot", event_pos, event_kind == "elite")
				_next_spawn = elapsed + 0.8
				_event_action = elapsed + (INF if event_kind == "elite" else 3.5)
				return
	if queue.is_empty():
		if seconds < _next_group:
			return
		_queue_group(seconds, ranged)
	if seconds < _next_spawn:
		return
	var kind: String = queue.front()
	if _is_ranged(kind) and ranged >= MAX_RANGED:
		return
	_next_spawn = seconds + 0.25
	var pos := _find_position(game)
	if pos == Vector3.INF:
		return
	var elite := elites == 0 and seconds >= 60.0 and kind in ["bot", "clipper", "mod"] and rng.randf() < 0.08
	_spawn_regular(game, kind, pos, elite)
	queue.pop_front()
	_next_spawn = seconds + 0.65
	if queue.is_empty():
		_next_group = seconds + lerpf(maxf(0.8, opening_interval), clampf(minimum_interval, 0.8, maxf(0.8, opening_interval)), threat)

func _spawn_regular(game, kind: String, pos: Vector3, elite: bool) -> void:
	var enemy = game._make_enemy(kind, "", pos, true)
	enemy.max_hp *= 1.0 + clampf(max_health_bonus, 0.0, 0.3) * threat
	enemy.cfg["speed"] *= 1.0 + clampf(max_speed_bonus, 0.0, 0.1) * threat
	if elite:
		enemy.survival_elite = true
		enemy.max_hp *= 1.2
		enemy.cfg["speed"] *= 1.05
		var badge := Label3D.new()
		badge.name = "EliteBadge"
		badge.text = "◆ ЭЛИТА"
		badge.modulate = Color(1.0, 0.78, 0.32)
		badge.font_size = 27
		badge.pixel_size = 0.008
		badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		badge.position.y = enemy.height + 0.8
		enemy.add_child(badge)
	enemy.hp = enemy.max_hp

func _start_boss(game, pos: Vector3) -> void:
	var id: String = BOSS_ORDER[boss_index]
	boss_index = (boss_index + 1) % BOSS_ORDER.size()
	game.boss_e = game._make_enemy("", id, pos, true)
	var info: Dictionary = game.boss_e.boss
	game.boss_name.text = "%s — %s" % [info["n"], info["sub"]]
	game.banner(info["n"], info["sub"], Color(info["c"]), 3.2)
	game.toast_t = 0.0      # «БОСС ПРИБЛИЖАЕТСЯ» больше не нужна: босс уже здесь, под его полосой она только мешала

func _finish_boss(game) -> void:
	var boss = game.boss_e
	game.clear_survival_hazards(boss)
	for enemy in game.enemies:
		if is_instance_valid(enemy) and enemy.survival_reinforcement:
			game.clear_survival_hazards(enemy)
			enemy.queue_free()
	game.boss_e = null
	next_boss = elapsed + maxf(15.0, boss_interval)
	next_event = maxf(next_event, elapsed + 20.0)
	_next_group = elapsed + 4.0
	_boss_notice = false

func _tick_event(game) -> void:
	if event_kind == "" and elapsed >= next_event and next_boss - elapsed >= 22.0:
		event_kind = EVENTS[_event_index]
		_event_index = (_event_index + 1) % EVENTS.size()
		_event_end = elapsed + 16.0
		_event_action = elapsed
		game.toast("СОБЫТИЕ · " + EVENT_NAMES[event_kind])
	if event_kind == "":
		return
	if elapsed >= _event_end:
		_end_event(game, true)
		return
	if event_kind == "hazard" and elapsed >= _event_action:
		_event_action = elapsed + 5.0
		if game.zones.any(func(zone): return zone.get("survival_event", false)):
			return
		var p: Vector3 = game.player.global_position
		var pos := Vector3(clampf(p.x, -10.0, 10.0), 0.05, clampf(p.z, -10.0, 10.0))
		game.telegraph(pos, 2.4, 2.0, 10.0, null, {"survival_event": true, "col": Color(1.0, 0.58, 0.16)})

func _end_event(game, reward: bool) -> void:
	if event_kind == "":
		return
	game.clear_survival_hazards(null)
	event_kind = ""
	next_event = elapsed + maxf(20.0, event_interval)
	if reward:
		events_completed += 1
		game.player.swag = minf(100.0, game.player.swag + 10.0)
		game.toast("СОБЫТИЕ ЗАВЕРШЕНО · +10 СВЭГ")

func forecast(game) -> String:
	if is_instance_valid(game.boss_e) and game.boss_e.state != "dead":
		return "БОЙ С БОССОМ"
	if elapsed >= next_boss:
		return "БОСС · ждёт зачистки арены"
	if event_kind != "":
		return "%s · %d с" % [EVENT_NAMES[event_kind], ceili(maxf(0.0, _event_end - elapsed))]
	if next_event + 22.0 > next_boss:
		return "БОСС ЧЕРЕЗ %d с" % ceili(next_boss - elapsed) if is_finite(next_boss) else ""
	return "%s ЧЕРЕЗ %d с" % [EVENT_NAMES[EVENTS[_event_index]], ceili(maxf(0.0, next_event - elapsed))] if is_finite(next_event) else ""

func stop(game) -> void:
	queue.clear()
	_end_event(game, false)

func reinforcement_position(game, preferred: Vector3) -> Vector3:
	var active := 0
	var bodies := 0
	for enemy in game.enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			bodies += 1
			active += int(enemy.state != "dead")
	var limit := 4 if is_instance_valid(game.boss_e) else MAX_ALIVE
	if active >= limit or bodies >= MAX_BODIES or (not is_instance_valid(game.boss_e) and elapsed >= next_boss):
		return Vector3.INF
	# Telegraphs belonging to these abilities already announce the reinforcement.
	if absf(preferred.x) <= 10.0 and absf(preferred.z) <= 10.0 and can_spawn_at(game, preferred, false, 3.5):
		return preferred
	return _find_position(game)

func _queue_group(seconds: float, ranged: int) -> void:
	var budget := roundi(2.0 + 8.0 * threat)
	var candidates: Array = []
	for recipe in RECIPES:
		if recipe["after"] > seconds or recipe["cost"] > budget:
			continue
		if ranged >= MAX_RANGED and (recipe["kinds"] as Array).any(_is_ranged):
			continue
		candidates.append(recipe)
	# Pick from the most dangerous unlocked recipes, while keeping variety.
	var index := rng.randi_range(maxi(0, candidates.size() - 3), candidates.size() - 1)
	queue.assign(candidates[index]["kinds"])

func _is_ranged(kind: String) -> bool:
	return kind == "hater" or kind == "lawyer"

func _find_position(game, large := false) -> Vector3:
	# Stay inside the lamps, snow banks and dumpsters. The physics check additionally
	# rejects collisions with other bodies and solid geometry added to this arena.
	for attempt in 20:
		var pos := Vector3(rng.randf_range(-10.0, 10.0), 0.05, rng.randf_range(-10.0, 10.0))
		if can_spawn_at(game, pos, large):
			return pos
	return Vector3.INF

func can_spawn_at(game, pos: Vector3, large := false, safe_distance := SAFE_DISTANCE) -> bool:
	if not game.in_arena(pos, 1.0):
		return false
	var offset: Vector3 = pos - game.player.global_position
	if Vector2(offset.x, offset.z).length_squared() < safe_distance * safe_distance:
		return false
	offset = pos - game.buddy.global_position
	if Vector2(offset.x, offset.z).length_squared() < 4.0:
		return false
	for enemy in game.enemies:
		if is_instance_valid(enemy) and pos.distance_squared_to(enemy.global_position) < 1.5 * 1.5:
			return false
	# A conservative box around even the largest ordinary enemy. Bottom stays above floor.
	_clearance.size = Vector3(2.1, 4.8, 2.1) if large else Vector3(1.3, 2.5, 1.3)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _clearance
	query.transform.origin = pos + Vector3.UP * _clearance.size.y * 0.5
	return game.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
