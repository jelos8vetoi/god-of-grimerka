class_name G67RunMods
extends RefCounted
## Модификаторы забега «ГОЛДА 67» для боя: тот же интерфейс, что у Endless Survival (game.run_mods — бой зовёт
## incoming, melee_hit, parried, rank…). Здесь — эффекты артефактов, которые срабатывают внутри удара или урона
## (APPROVALS.md, 2.3). Остальные эффекты (урон по состоянию, голда, скорость, перезарядки, СВЭГ) считает
## Golda67._art_tick / apply_fits. Улучшения Survival (rank) в приквеле не действуют — всегда 0.

var G: Golda67

func _init(g67: Golda67) -> void:
	G = g67

func rank(_id: String) -> int:
	return 0

## входящий урон: «Наушники с одним рабочим ухом» −10 %; «ЧЕСНОЧНАЯ АУРА» — враги в 2,5 м бьют на 10 % слабее
## (боссы — вдвое слабее эффект)
func incoming(game) -> float:
	var k := 1.0
	if G.has_art("one_earbud"):
		k *= 0.9
	if G.has_art("garlic_aura"):
		var pp: Vector3 = game.player.global_position
		var best := 1.0
		for e in game.enemies:
			if is_instance_valid(e) and e.alive() and Vector2(e.global_position.x - pp.x, e.global_position.z - pp.z).length() <= 2.5:
				best = minf(best, 0.95 if String(e.boss_id) != "" else 0.9)
		k *= best
	# ДЕДОВСКАЯ КУРТКА: удар, пришедший вскоре после предыдущего, слабее
	var jl := G.fit_lv("ded_jacket")
	if jl > 0 and game.clock - G.jacket_t <= G67Data.JACKET_T:
		k *= 1.0 - float(G67Data.JACKET_K[jl - 1])
	return k

## По кому пришёлся удар: ближайший живой враг к точке контакта
func _target(game, pos: Vector3):
	var best = null
	var bd := 3.0
	for e in game.enemies:
		if is_instance_valid(e) and e.alive():
			var d: float = Vector2(e.global_position.x - pos.x, e.global_position.z - pos.z).length()
			if d < bd:
				bd = d
				best = e
	return best

func consume_swap(_now: float, _hero: String) -> float:
	return 0.0

## «Синяя изолента»: тяжёлые удары +15 % — в пределах общего потолка урона ×2,0
func melee_hit(hit: HitInfo, player, _targets: int) -> void:
	if hit.heavy and G.has_art("blue_tape"):
		var room := G67Data.DMG_CAP_ALL / maxf(1.0, float(player.dmg_mul))
		hit.damage *= minf(1.15, maxf(1.0, room))
	var kl := G.fit_lv("garage_key")
	var fl := G.fit_lv("first_hit")
	if (kl <= 0 or not hit.heavy) and fl <= 0:
		return
	var e = _target(G.game, hit.pos)
	if e == null:
		return
	var boss: bool = String(e.boss_id) != ""
	# ГАРАЖНЫЙ КЛЮЧ: тяжёлые сильнее сбивают равновесие
	if kl > 0 and hit.heavy:
		hit.stagger *= 1.0 + float(G67Data.KEY_K[kl - 1]) * (0.5 if boss else 1.0)
	# ПЕРВЫЙ УДАР: по врагу с полным здоровьем; по боссу — один раз за забег
	if fl > 0 and float(e.hp) >= float(e.max_hp) - 0.01 and not (boss and bool(G.run.get("first_boss", false))):
		if boss:
			G.run["first_boss"] = true
		var room2 := G67Data.DMG_CAP_ALL / maxf(1.0, float(player.dmg_mul))
		hit.damage *= minf(1.0 + float(G67Data.FIRST_K[fl - 1]), maxf(1.0, room2))
		G.events.append(["first_hit"])

## «Грилзы»: парирование оглушает на 50 % дольше
func parry_stun() -> float:
	return 1.5 if G.has_art("grillz") else 1.0

## «ОШЕЙНИК 67»: смертельный удар оставляет 1 здоровье и 2 с неуязвимости — раз за забег
func save_from_death(_game) -> bool:
	if not G.has_art("collar_67") or bool(G.run.get("collar_used", false)):
		return false
	G.run["collar_used"] = true
	G.events.append(["art", "collar_67"])
	G.game.popup(G.game.player.global_position + Vector3(0, 2.2, 0), "ОШЕЙНИК 67", Color(0.4, 0.8, 0.5))
	return true

func parried(_game) -> void:
	pass

func dodged(_game) -> void:
	pass

func duo_started(_game) -> void:
	pass

func tagged(_game, _context: String) -> void:
	pass

func overdrive_ended(_game, _cancelled: bool) -> void:
	pass

func perfect_swap(_game) -> void:
	pass
