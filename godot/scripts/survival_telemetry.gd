extends RefCounted
## One run, one HP ledger. Only living enemy instances have per-instance state.

const DIRECTORY := "user://survival_reports"
var directory := DIRECTORY
var elapsed := 0.0
var heroes := {}
var attacks := {}
var enemies := {}
var bosses := {}
var environment := {}
var resources := {}
var unclassified_damage := 0.0
var _live := {}
var _saved := false
var last_knockout := {}

func _row(table: Dictionary, id: String, initial: Dictionary) -> Dictionary:
	if not table.has(id):
		table[id] = initial
	return table[id]

func _inc(row: Dictionary, field: String, amount := 1.0) -> void:
	row[field] = row.get(field, 0) + amount

func _hero(id: String) -> Dictionary:
	return _row(heroes, id, {"active_seconds": 0.0, "style_seconds": {}})

func tick(delta: float, hero: String, style: String) -> void:
	elapsed += delta
	var row := _hero(hero)
	_inc(row, "active_seconds", delta)
	_inc(row["style_seconds"], style, delta)

func team_event(hero: String, key: String) -> void:
	_inc(_hero(hero), key)

func expend(resource: String, amount: float) -> void:
	_inc(resources, resource, amount)

func _enemy_key(enemy) -> String:
	if enemy.boss_id != "":
		return "boss:" + enemy.boss_id
	return enemy.kind + (":elite" if enemy.survival_elite else "")

func _enemy(key: String) -> Dictionary:
	return _row(enemies, key, {"abilities": {}})

func _phase(boss: String, index: int) -> Dictionary:
	var row := _row(bosses, boss, {"phases": {}, "abilities": {}})
	return _row(row["phases"], str(index), {})

func spawn(enemy) -> void:
	var id: int = enemy.get_instance_id()
	_live[id] = {"start": elapsed, "phase_start": elapsed, "phase": 0,
		"boss": enemy.boss_id, "key": "", "targets_seen": {}, "fighting": false}
	enemy.tree_exiting.connect(_remove.bind(id, enemy), CONNECT_ONE_SHOT)

func boss_ready(enemy) -> void:
	var row: Dictionary = _live.get(enemy.get_instance_id(), {})
	if not row.is_empty():
		row["fighting"] = true
		row["phase_start"] = elapsed

func phase_change(enemy, next: int) -> void:
	var row: Dictionary = _live.get(enemy.get_instance_id(), {})
	if not row.is_empty() and row["fighting"]:
		_close_phase(row)
		row["phase"] = next
		row["phase_start"] = elapsed

func _close_phase(row: Dictionary) -> void:
	var seconds: float = elapsed - row["phase_start"]
	_inc(_phase(row["boss"], row["phase"]), "seconds", seconds)
	_inc(bosses[row["boss"]], "fight_seconds", seconds)

func _remove(id: int, enemy) -> void:
	if not _live.has(id):
		return
	_live[id]["key"] = _enemy_key(enemy)
	_close_enemy(id)

func _close_enemy(id: int) -> void:
	var row: Dictionary = _live[id]
	_inc(_enemy(row["key"]), "observed_lifetime_seconds", elapsed - row["start"])
	_inc(_enemy(row["key"]), "instances")
	if row["boss"] != "" and row["fighting"]:
		_close_phase(row)
	_live.erase(id)

func enemy_defeated(enemy) -> void:
	var id: int = enemy.get_instance_id()
	_inc(_enemy(_enemy_key(enemy)), "defeated")
	if _live.has(id):
		_remove(id, enemy)

func _attack(hero: String, style: String, id: String) -> Dictionary:
	return _row(attacks, "%s/%s/%s" % [hero, style, id], {
		"id": id, "hero": hero, "style": style, "uses": 0, "hits": 0,
		"unique_targets": 0, "targets": {}, "survival_effects": {}})

func use(hero: String, style: String, id: String) -> void:
	_inc(_attack(hero, style, id), "uses")

func outgoing(enemy, hp_lost: float, applied: float, hit: HitInfo, raw_id: String, raw_hero: String, raw_damage: float) -> void:
	var target := _enemy_key(enemy)
	_inc(_enemy(target), "damage_received", hp_lost)
	if enemy.boss_id != "":
		_inc(_phase(enemy.boss_id, enemy.phase), "damage_received", hp_lost)
	var hero := raw_hero
	var id := raw_id
	var style := "system"
	var ordinary := raw_damage
	var staged := raw_damage
	if hit != null:
		hero = hit.telemetry_hero
		if hero == "" and is_instance_valid(hit.source):
			hero = str(hit.source.get("hero"))
		id = hit.telemetry_id if hit.telemetry_id != "" else hit.attack_id
		style = hit.telemetry_style if hit.telemetry_style != "" else (hit.style_id if hit.style_id != "" else "team")
		staged = hit.damage
		ordinary = staged if hit.telemetry_ordinary < 0.0 else hit.telemetry_ordinary
	if hero not in ["pahan", "madk1d"] or id == "":
		if id == "":
			unclassified_damage += hp_lost
		else:
			_inc(_row(environment, id, {}), "enemy_hp_lost", hp_lost)
		return
	var row := _attack(hero, style, id)
	var original: AttackData = Styles.by_id(style).attack(id) if Styles.ORDER.has(style) else null
	if original != null:
		_inc(row, "weapon_base_damage", original.damage)
		_inc(row, "weapon_base_samples")
	_inc(row, "ordinary_damage", ordinary)
	_inc(row, "post_survival_damage", staged)
	_inc(row, "post_target_damage", applied)
	_inc(row, "actual_hp_lost", hp_lost)
	_inc(row, "hits")
	_inc(row["targets"], target)
	_inc(_hero(hero), "damage_dealt", hp_lost)
	if hit != null:
		_inc(row, "stagger_requested", hit.stagger)
		if original != null and is_instance_valid(hit.source):
			var p = hit.source
			var flags := _row(row, "ordinary_effects", {})
			if p.rage > 0.0:
				_inc(flags, "rage")
			if p.flow.bonus() > 1.0:
				_inc(flags, "perfect_swap")
			if p.game.tag.bonus() > 1.0:
				_inc(flags, "tag")
			if p._style_bonus(original) > 1.0:
				_inc(flags, "style_resource")
		for effect in hit.telemetry_effects:
			_inc(row["survival_effects"], effect)
	var state: Dictionary = _live.get(enemy.get_instance_id(), {})
	if not state.is_empty():
		var key := "%s/%s/%s" % [hero, style, id]
		if not state["targets_seen"].has(key):
			state["targets_seen"][key] = true
			_inc(row, "unique_targets")

func source(enemy, fallback := "environment", use_override := true) -> Dictionary:
	if not is_instance_valid(enemy):
		return {"key": "", "move": fallback, "boss": "", "phase": 0}
	if use_override and not enemy.telemetry_override.is_empty():
		return enemy.telemetry_override
	return {"key": _enemy_key(enemy), "move": enemy.telemetry_move,
		"boss": enemy.boss_id, "phase": enemy.telemetry_phase}

func control(hero: String, style: String, id: String, target, amount: float) -> void:
	var row := _attack(hero, style, id)
	_inc(row, "control_contacts")
	_inc(row, "stagger_requested", amount)
	_inc(_row(row, "control_targets", {}), _enemy_key(target))

func _ability(context: Dictionary) -> Dictionary:
	if context["key"] == "":
		return _row(environment, context["move"], {})
	if context["boss"] != "":
		_phase(context["boss"], context["phase"])
		return _row(bosses[context["boss"]]["abilities"], context["move"], {"phases": {}})
	return _row(_enemy(context["key"])["abilities"], context["move"], {})

func hostile_use(enemy, move: String) -> void:
	var context := source(enemy, "environment", false)
	context["move"] = move
	var row := _ability(context)
	_inc(row, "uses")
	if context["boss"] != "":
		_inc(_row(row["phases"], str(context["phase"]), {}), "uses")

func incoming(hero: String, context: Dictionary, hp_lost: float, raw: float, ordinary: float, post_survival: float, down: bool) -> void:
	var row := _hero(hero)
	_inc(row, "damage_taken", hp_lost)
	_inc(row, "incoming_raw", raw)
	_inc(row, "incoming_ordinary", ordinary)
	_inc(row, "incoming_post_survival", post_survival)
	var ability := _ability(context)
	_inc(ability, "hits")
	_inc(ability, "damage_dealt", hp_lost)
	if context["key"] != "":
		_inc(_enemy(context["key"]), "damage_dealt", hp_lost)
		_inc(_enemy(context["key"]), "hits")
	if context["boss"] != "":
		var phase := _phase(context["boss"], context["phase"])
		_inc(phase, "damage_dealt", hp_lost)
		var ability_phase := _row(ability["phases"], str(context["phase"]), {})
		_inc(ability_phase, "hits")
		_inc(ability_phase, "damage_dealt", hp_lost)
	if down:
		last_knockout = context.duplicate()
		_inc(row, "knockouts")
		var reason := "%s/%s" % [context["key"], context["move"]]
		_inc(_row(row, "knockout_causes", {}), reason)

func save(game, outcome: String, survival: Dictionary) -> String:
	if _saved:
		return ""
	_saved = true
	for enemy in game.enemies:
		if is_instance_valid(enemy):
			_remove(enemy.get_instance_id(), enemy)
	var report := {"schema": 1, "outcome": outcome, "active_seconds": elapsed,
		"created_utc": Time.get_datetime_string_from_system(true), "heroes": heroes, "attacks": attacks,
		"terminal_source": last_knockout if outcome == "defeat" else {}, "enemy_hp_scale": game.diff_hp,
		"balance_revision": FileAccess.get_sha256("res://scripts/balance.gd"),
		"enemies": enemies, "bosses": bosses, "environment": environment, "resources": resources,
		"unclassified_enemy_hp_lost": unclassified_damage, "survival": survival}
	if directory.is_empty():
		return ""
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_warning("Could not create Survival telemetry directory")
		return ""
	var name := "survival_%d_%d_%d.json" % [int(Time.get_unix_time_from_system()), OS.get_process_id(), Time.get_ticks_usec()]
	var path := directory.path_join(name)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file != null:
		var written := file.store_string(JSON.stringify(report, "\t"))
		file.close()
		if written and DirAccess.rename_absolute(path + ".tmp", path) == OK:
			return path
	push_warning("Could not write Survival telemetry")
	return ""
