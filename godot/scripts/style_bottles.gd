## Стиль «Водяра» (Пахан): быстрый, техничный, подвижный. В руках две бутылки.
## Бутылкой можно и бить, и бросать. Что выйдет по ЛКМ, решает дистанция до ближайшего врага:
##   вплотную (CLOSE м)  — удары бутылкой (начало графа "close");
##   издалека            — броски (начало графа "");
##   в прыжке            — бросок сверху (начало графа "air").
## ПКМ — удержание: прицел с траекторией, отпустил — усиленный бросок; вплотную — бросок в упор.
## F — бросок из любой точки связки (наотмашь, двумя руками): так удары переходят в броски.
## Бросок бьёт слабо, но мочит (замедляет), сбивает равновесие и прерывает слабые замахи. Запас ограничен и
## восстанавливается сам; удары бутылкой запас не тратят.
## Поля extra: count — сколько бутылок, fan — разлёт, both — бросают обе руки по очереди, hand: "l" — левая,
## ricochet — сколько раз бутылка отскочит к следующему врагу, last_drop — множитель урона по оглушённому,
## draw — на какой доле клипа рука достаёт следующую бутылку из кармана, arc_up — навес.
class_name StyleBottles

const CLOSE := 2.6

static func build() -> StyleData:
	var s := StyleData.new()
	s.id = "bottles"
	s.title = "Водяра"
	s.owner = "pahan"
	s.ready = true
	s.note = "дистанция и ближний бой: броски, удары бутылкой, замедление"
	s.ammo_max = 6
	s.ammo_regen = 3.0            # одна бутылка за 3 с
	s.charge_clip = "BottleAim"
	s.charge_max = 1.0
	s.chain_cd = 0.2
	s.color = Color(0.55, 0.82, 1.0)
	s.color_hot = Color(0.75, 0.92, 1.0)
	s.roles = {"idle": "BottleIdle", "combat_idle": "BottleIdle", "idle_var": "BtIdleVar"}
	s.close_range = CLOSE
	# ---------------- броски ----------------
	var quick := {"kind": "ranged", "clip": "BottleThrow", "duration": 0.62, "hits": [0.4], "damage": 9.0, "stagger": 22.0, "reach": 14.0, "arc": 1.6,
		"knockback": 2.0, "projectile": "bottle", "ammo": 1, "combo_from": 0.6, "recovery": 0.92, "feedback": "bt_hit",
		"extra": {"speed": 17.0, "slow": 2.5, "slow_k": 0.6, "draw": 0.84}}
	var mk := func(id: String, o: Dictionary, ex := {}) -> void:
		var d := quick.duplicate(true)
		d["id"] = id
		for k in o:
			d[k] = o[k]
		for k in ex:
			d["extra"][k] = ex[k]
		s.add(AttackData.make(d))
	mk.call("bt_quick", {})
	mk.call("bt_side", {"title": "СБОКУ", "clip": "BtSideThrow", "duration": 0.6, "damage": 10.0}, {"speed": 19.0})
	mk.call("bt_over", {"title": "НАВЕСОМ", "clip": "BtOverThrow", "duration": 0.66, "hits": [0.42], "damage": 12.0, "stagger": 30.0, "reach": 16.0}, {"speed": 13.0, "arc_up": 1.0})
	# двумя руками: две бутылки — в двух врагов или обе в одного (DOUBLE SPLASH)
	mk.call("bt_double", {"title": "ДВОЙНОЙ ВСПЛЕСК", "clip": "BtDoubleThrow", "duration": 0.7, "ammo": 2, "stagger": 26.0, "arc": 2.4, "recovery": 0.96}, {"speed": 18.0, "count": 2, "fan": 0.12, "both": true, "splash": 1.8, "draw": 0.86})
	# веер (BOTTLE STORM): три бутылки по трём целям в широком секторе; завершает серию
	mk.call("bt_fan", {"title": "ВЕЕР", "clip": "BtStorm", "duration": 0.82, "ammo": 3, "arc": 2.6, "damage": 8.0, "recovery": 0.98}, {"speed": 16.0, "count": 3, "fan": 0.3, "both": true, "draw": 0.88})
	mk.call("bt_backhand", {"title": "НАОТМАШЬ", "clip": "BtBackhand", "duration": 0.54, "hits": [0.38], "stagger": 24.0}, {"speed": 18.0})
	# низом, с рикошетом: бутылка отскакивает от врага к следующему
	mk.call("bt_rico", {"title": "РИКОШЕТ", "clip": "BtRicoThrow", "duration": 0.7, "hits": [0.42], "damage": 11.0, "stagger": 24.0, "recovery": 0.95}, {"speed": 20.0, "ricochet": 3, "draw": 0.86})
	mk.call("bt_run", {"title": "НА БЕГУ", "clip": "BtRunThrow", "duration": 0.56, "stagger": 24.0, "step": [0.0, 0.9, 5.6]}, {})
	mk.call("bt_jump", {"title": "В ПРЫЖКЕ", "clip": "BtJumpThrow", "duration": 0.5, "hits": [0.45], "damage": 11.0, "stagger": 28.0}, {"speed": 19.0, "hop": 3.0, "draw": 0.86})
	mk.call("bt_slide", {"title": "В СКОЛЬЖЕНИИ", "clip": "BtSlideThrow", "duration": 0.66, "hits": [0.45], "stagger": 26.0, "step": [0.0, 0.7, 7.5]}, {"speed": 19.0, "draw": 0.88})
	mk.call("bt_close", {"title": "В УПОР", "clip": "BtCloseThrow", "duration": 0.56, "hits": [0.3], "damage": 14.0, "stagger": 40.0, "knockback": 7.0, "reach": 5.0, "combo_from": 0.55}, {"speed": 22.0, "splash": 1.6})
	mk.call("bt_roll", {"clip": "BtRollThrow", "duration": 0.5, "from": 0.2, "stagger": 28.0}, {})
	# усиленный: прицел удержанием, летит быстрее, оглушает, всплеск мочит соседей; по оглушённому — LAST DROP
	s.add(AttackData.make({"id": "bt_power", "kind": "ranged", "title": "ОБЛИЛ", "clip": "BottleThrowHeavy", "duration": 0.7, "hits": [0.36], "damage": 16.0, "stagger": 45.0, "reach": 16.0, "arc": 1.4,
		"knockback": 4.0, "stun": 0.9, "heavy": true, "power": 1, "projectile": "bottle", "ammo": 1, "charge": true, "charge_gain": 0.6, "recovery": 0.95, "feedback": "bt_power",
		"extra": {"speed": 21.0, "slow": 3.5, "slow_k": 0.5, "splash": 2.2, "last_drop": 2.5, "draw": 0.86}}))
	# ---------------- удары бутылкой: запас не тратят ----------------
	var hit := {"kind": "light", "damage": 12.0, "stagger": 16.0, "reach": 2.2, "arc": 2.2, "knockback": 2.5, "combo_from": 0.6, "feedback": "bt_hit"}
	var mh := func(id: String, o: Dictionary) -> void:
		var d := hit.duplicate(true)
		d["id"] = id
		for k in o:
			d[k] = o[k]
		s.add(AttackData.make(d))
	mh.call("bt_jab", {"clip": "BtJab", "duration": 0.42, "hits": [0.4], "step": [0.2, 0.42, 5.0]})
	mh.call("bt_rev", {"clip": "BtReverse", "duration": 0.44, "hits": [0.42], "damage": 13.0, "arc": 2.8, "step": [0.2, 0.44, 4.0]})
	mh.call("bt_dsmash", {"title": "С ДВУХ РУК", "clip": "BtDoubleSmash", "duration": 0.52, "hits": [0.45], "damage": 18.0, "stagger": 30.0, "stun": 0.5, "step": [0.25, 0.46, 4.5]})
	mh.call("bt_spinback", {"title": "С РАЗВОРОТА", "clip": "BtSpinBack", "duration": 0.58, "hits": [0.55], "damage": 16.0, "stagger": 26.0, "arc": 6.3, "reach": 2.4, "knockback": 5.0, "spin": 1.0, "combo_from": 0.7})
	mh.call("bt_crush", {"kind": "finisher", "title": "ДВОЙНОЙ УДАР", "clip": "BtCrush", "duration": 0.7, "hits": [0.5], "damage": 26.0, "stagger": 50.0, "knockback": 4.0, "stun": 0.9, "heavy": true, "power": 1, "step": [0.28, 0.5, 4.0], "feedback": "bt_power"})
	mh.call("bt_elbow", {"title": "ЛОКТЕМ", "clip": "BtElbow", "duration": 0.4, "hits": [0.4], "damage": 11.0, "stagger": 28.0, "reach": 1.9, "step": [0.18, 0.42, 5.5]})
	mh.call("bt_air", {"title": "СВЕРХУ", "clip": "BtAirMelee", "duration": 0.46, "hits": [0.5], "damage": 16.0, "stagger": 26.0, "reach": 2.6, "launch": -14.0, "extra": {"hop": 1.5}})
	s.links = {
		# издалека: быстрый → сбоку → навесом → веер; ПКМ — усиленный; F — наотмашь
		"": {"light": "bt_quick", "heavy": "bt_power", "throw": "bt_backhand"},
		"bt_quick": {"light": "bt_side", "heavy": "bt_double", "throw": "bt_backhand"},        # бросок × бросок; ПКМ — двойной
		"bt_side": {"light": "bt_over", "heavy": "bt_rico", "throw": "bt_backhand"},           # ПКМ — рикошет
		"bt_over": {"light": "bt_fan", "heavy": "bt_power", "throw": "bt_double"},
		"bt_backhand": {"light": "bt_jab", "heavy": "bt_power", "throw": "bt_side"},           # бросок × удар
		"bt_double": {"heavy": "bt_power", "light": "bt_jab"},                                 # двойной × усиленный
		"bt_rico": {"light": "bt_quick", "heavy": "bt_power"},
		"bt_run": {"light": "bt_side", "heavy": "bt_double", "throw": "bt_backhand"},
		"bt_roll": {"light": "bt_side", "heavy": "bt_double", "throw": "bt_backhand"},
		"bt_slide": {"light": "bt_jab", "heavy": "bt_double", "throw": "bt_backhand"},
		# вплотную: тычок → наотмашь → с двух рук → с разворота → двойной удар
		"close": {"light": "bt_jab", "heavy": "bt_close", "throw": "bt_backhand"},
		"bt_jab": {"light": "bt_rev", "heavy": "bt_elbow", "throw": "bt_backhand"},            # CLOSE QUARTERS: тычок → локтем → наотмашь → в упор
		"bt_elbow": {"light": "bt_rev", "heavy": "bt_close", "throw": "bt_close"},
		"bt_rev": {"light": "bt_dsmash", "heavy": "bt_close", "throw": "bt_close"},
		"bt_dsmash": {"light": "bt_spinback", "heavy": "bt_power", "throw": "bt_double"},
		"bt_spinback": {"light": "bt_crush", "heavy": "bt_power", "throw": "bt_double"},
		"bt_close": {"light": "bt_jab", "heavy": "bt_power", "throw": "bt_backhand"},
		# в прыжке: бросок сверху → удар бутылкой сверху
		"air": {"light": "bt_jump", "heavy": "bt_jump", "throw": "bt_jump"},
		"bt_jump": {"light": "bt_air", "heavy": "bt_air", "throw": "bt_jump"},
	}
	s.after_dodge = {"light": "bt_roll", "heavy": "bt_slide"}
	s.after = {
		"dodge": {"light": "bt_roll", "heavy": "bt_slide"},
		"perfect": {"light": "bt_double", "heavy": "bt_power"},      # точное уклонение × двойной
		"sprint": {"light": "bt_run", "heavy": "bt_slide"},
		"parry": {"light": "bt_jab", "heavy": "bt_close"},
		"block": {"light": "bt_elbow", "heavy": "bt_close"},
	}
	return s
