## Стиль «Балон VOZDUH» (Пахан): тяжёлое двуручное оружие, широкие махи, цепочка из четырёх лёгких,
## тяжёлый удар завершает цепочку по-разному в зависимости от того, после какого лёгкого нажат.
## Доли hits / step / slam / scrape / drop совпадают с ключами клипов в clips_pahan.gd.
class_name StyleVozduh

static func build() -> StyleData:
	var s := StyleData.new()
	s.id = "vozduh"
	s.title = "Балон VOZDUH"
	s.owner = "pahan"
	s.ready = true
	s.note = "тяжёлый ближний бой: медленный замах, сильный удар, подбросы и удары в землю"
	s.weapon = {"path": "res://assets/models/balon.glb", "side": "r", "opt": {"axis": "y", "from": 98.0, "to": 0.0, "grip": 0.07, "length": 0.56}}
	s.hit_sfx = [
		[["sfx_clang", -6.0, 1.0]],
		[["sfx_clang", -2.0, 0.8], ["sfx_hit_heavy", 0.0, 1.0]],
		[["sfx_clang", -2.0, 0.8], ["sfx_hit_heavy", 0.0, 1.0], ["sfx_crack", 1.0, 1.0]],
	]
	# ---- цепочка лёгких: мах вправо-налево → наотмашь обратно → рывок снизу вверх (подбрасывает) → двумя руками в землю ----
	s.add(AttackData.make({"id": "vz_light1", "kind": "light", "clip": "Light1", "duration": 0.88, "hits": [0.52], "damage": 28.0, "stagger": 14.0, "reach": 2.7, "arc": 2.6,
		"knockback": 4.5, "step": [0.44, 0.64, 4.6], "combo_from": 0.68, "drop": 0.75}))
	s.add(AttackData.make({"id": "vz_light2", "kind": "light", "clip": "Light2", "duration": 0.86, "hits": [0.5], "damage": 30.0, "stagger": 15.0, "reach": 2.7, "arc": 2.6,
		"knockback": 5.0, "step": [0.42, 0.62, 4.6], "combo_from": 0.68, "from": 0.17, "drop": 0.74}))
	s.add(AttackData.make({"id": "vz_upper", "kind": "launcher", "clip": "Upper", "duration": 0.86, "hits": [0.5], "damage": 32.0, "stagger": 18.0, "reach": 2.7, "arc": 2.2,
		"knockback": 3.0, "launch": 6.0, "step": [0.42, 0.56, 4.0], "combo_from": 0.62, "from": 0.12, "scrape": 0.36, "drop": 0.87, "feedback": "vz_launcher"}))
	s.add(AttackData.make({"id": "vz_slam", "kind": "slam", "title": "В ЗЕМЛЮ", "clip": "SlamDown", "duration": 1.0, "hits": [0.57], "damage": 44.0, "stagger": 40.0, "reach": 3.0, "arc": 2.2,
		"knockback": 4.0, "launch": -18.0, "heavy": true, "power": 1, "slam": 0.61, "step": [0.5, 0.6, 3.6], "from": 0.36, "trail_boost": 1.25, "feedback": "vz_slam"}))
	# ---- тяжёлые: с места и после 1, 2, 3 лёгких ----
	s.add(AttackData.make({"id": "vz_overhead", "kind": "heavy", "title": "ОВЕРХЕД", "clip": "Heavy", "duration": 1.05, "hits": [0.57], "damage": 60.0, "stagger": 45.0, "reach": 3.0, "arc": 2.0,
		"knockback": 5.0, "launch": 6.0, "heavy": true, "power": 1, "slam": 0.61, "step": [0.5, 0.6, 4.0], "from": 0.08, "trail_boost": 1.25, "feedback": "vz_heavy",
		"charge": true, "charge_clip": "OverheadCharge", "charge_gain": 0.5, "charged_from": 0.36}))
	s.add(AttackData.make({"id": "vz_nail", "kind": "finisher", "title": "ГВОЗДЬ", "clip": "Nail", "duration": 0.76, "hits": [0.42], "damage": 48.0, "stagger": 40.0, "reach": 2.9, "arc": 1.8,
		"knockback": 3.0, "heavy": true, "power": 1, "stun": 1.5, "step": [0.3, 0.46, 5.0], "from": 0.08, "drop": 0.52, "trail_boost": 1.25, "feedback": "vz_finisher"}))
	s.add(AttackData.make({"id": "vz_fullswing", "kind": "finisher", "title": "ПОЛНЫЙ ЗАМАХ", "clip": "FullSwing", "duration": 0.85, "hits": [0.34], "damage": 55.0, "stagger": 50.0, "reach": 3.2, "arc": 3.6,
		"knockback": 15.0, "launch": 6.5, "heavy": true, "power": 1, "charge": true, "step": [0.14, 0.4, 6.5], "trail_boost": 1.25, "feedback": "vz_finisher"}))
	s.add(AttackData.make({"id": "vz_spin", "kind": "finisher", "title": "НУНЧАКИ", "clip": "Spin", "duration": 1.2, "hits": [0.24, 0.37, 0.5, 0.63, 0.76], "damage": 16.0, "stagger": 10.0, "reach": 3.0, "arc": 6.3,
		"knockback": 3.0, "spin": 3.0, "heavy": true, "power": 1, "last_launch": 6.0, "from": 0.08, "trail_boost": 1.25, "feedback": "vz_finisher"}))
	# ---- тяжёлый → тяжёлый: после удара сверху — прыжок и удар по земле всем весом, бьёт вокруг ----
	s.add(AttackData.make({"id": "vz_quake", "kind": "slam", "title": "ЗЕМЛЯ ДРОЖИТ", "clip": "Smash", "duration": 1.0, "hits": [0.59], "damage": 66.0, "stagger": 70.0, "reach": 3.6, "arc": 6.3,
		"knockback": 7.0, "launch": 5.5, "heavy": true, "power": 2, "slam": 0.6, "from": 0.16, "trail_boost": 1.5, "feedback": "vz_quake"}))
	# ---- после уклонения: балон уже в движении — удар с ходу (клип стартует с from) ----
	s.add(AttackData.make({"id": "vz_roll_swing", "kind": "light", "clip": "RollSwing", "duration": 0.82, "hits": [0.52], "damage": 26.0, "stagger": 20.0, "reach": 2.8, "arc": 2.8,
		"knockback": 6.0, "step": [0.44, 0.64, 5.4], "combo_from": 0.68, "from": 0.33, "drop": 0.75}))
	s.add(AttackData.make({"id": "vz_roll_launch", "kind": "launcher", "title": "С ХОДУ", "clip": "RollUpper", "duration": 0.84, "hits": [0.5], "damage": 34.0, "stagger": 24.0, "reach": 2.8, "arc": 2.2,
		"knockback": 3.0, "launch": 6.5, "heavy": true, "power": 1, "step": [0.42, 0.56, 4.6], "combo_from": 0.62, "from": 0.28, "scrape": 0.36, "drop": 0.87, "feedback": "vz_launcher"}))
	# ---- тяжёлый → подброс: после удара сверху ЛКМ — рывок балоном снизу вверх ----
	s.add(AttackData.make({"id": "vz_rise", "kind": "launcher", "clip": "RiseUpper", "duration": 0.8, "hits": [0.5], "damage": 34.0, "stagger": 22.0, "reach": 2.8, "arc": 2.2,
		"knockback": 3.0, "launch": 6.5, "step": [0.42, 0.56, 4.0], "combo_from": 0.62, "from": 0.22, "scrape": 0.36, "drop": 0.87, "feedback": "vz_launcher"}))
	# ---- ответ на парирование: враг оглушён — полный мах без заряда или гвоздь ----
	s.add(AttackData.make({"id": "vz_parry_heavy", "kind": "finisher", "title": "ОТВЕТКА", "clip": "ParrySwing", "duration": 0.8, "hits": [0.34], "damage": 70.0, "stagger": 70.0, "reach": 3.2, "arc": 3.2,
		"knockback": 14.0, "launch": 6.0, "heavy": true, "power": 2, "step": [0.2, 0.4, 6.0], "from": 0.16, "trail_boost": 1.5, "feedback": "vz_finisher"}))
	s.add(AttackData.make({"id": "vz_parry_light", "kind": "light", "clip": "ParryJab", "duration": 0.7, "hits": [0.42], "damage": 40.0, "stagger": 40.0, "reach": 2.9, "arc": 1.8,
		"knockback": 3.0, "stun": 1.2, "step": [0.3, 0.46, 5.0], "from": 0.14, "drop": 0.52, "combo_from": 0.6, "feedback": "vz_heavy"}))
	# ---- после блока: короткий толчок наотмашь, чтобы отогнать ----
	s.add(AttackData.make({"id": "vz_block_shove", "kind": "light", "clip": "BlockShove", "duration": 0.7, "hits": [0.5], "damage": 22.0, "stagger": 30.0, "reach": 2.6, "arc": 2.8,
		"knockback": 9.0, "step": [0.42, 0.6, 3.0], "from": 0.3, "drop": 0.74, "combo_from": 0.68}))
	# ---- после идеального уклонения («ТАЙМИНГ!»): время на размах уже выиграно ----
	s.add(AttackData.make({"id": "vz_perfect_swing", "kind": "finisher", "title": "ТАЙМИНГ", "clip": "PerfectSwing", "duration": 0.78, "hits": [0.34], "damage": 52.0, "stagger": 50.0, "reach": 3.2, "arc": 3.4,
		"knockback": 12.0, "launch": 5.0, "heavy": true, "power": 1, "step": [0.22, 0.4, 6.5], "from": 0.2, "trail_boost": 1.4, "feedback": "vz_finisher"}))
	s.add(AttackData.make({"id": "vz_perfect_launch", "kind": "launcher", "title": "ТАЙМИНГ", "clip": "PerfectUpper", "duration": 0.78, "hits": [0.5], "damage": 44.0, "stagger": 30.0, "reach": 2.9, "arc": 2.4,
		"knockback": 3.0, "launch": 8.0, "heavy": true, "power": 1, "step": [0.42, 0.56, 5.0], "combo_from": 0.62, "from": 0.3, "scrape": 0.36, "drop": 0.87, "feedback": "vz_launcher"}))
	# ---- с разгона (Ctrl + удар на бегу): вес балона несёт героя ----
	s.add(AttackData.make({"id": "vz_dash_swing", "kind": "light", "title": "С РАЗГОНА", "clip": "DashSwing", "duration": 0.8, "hits": [0.52], "damage": 36.0, "stagger": 28.0, "reach": 3.0, "arc": 2.8,
		"knockback": 10.0, "step": [0.33, 0.66, 9.0], "combo_from": 0.68, "from": 0.3, "drop": 0.75, "cooldown": 1.2, "feedback": "vz_heavy"}))
	s.add(AttackData.make({"id": "vz_dash_slam", "kind": "slam", "title": "С РАЗГОНА", "clip": "DashRam", "duration": 0.95, "hits": [0.59], "damage": 58.0, "stagger": 60.0, "reach": 3.2, "arc": 3.0,
		"knockback": 8.0, "launch": 5.0, "heavy": true, "power": 1, "slam": 0.6, "step": [0.16, 0.56, 8.5], "from": 0.14, "cooldown": 2.0, "trail_boost": 1.4, "feedback": "vz_slam"}))
	# ---- Heat по положению цели: в воздухе — подброс и вбить в землю; оглушена или лежит — добить ударом сверху ----
	s.add(AttackData.make({"id": "vz_heat_air", "kind": "heat", "clip": "HeatUpper", "duration": 0.7, "hits": [0.5], "damage": 40.0, "stagger": 40.0, "reach": 3.4, "arc": 2.8,
		"knockback": 2.0, "launch": 9.0, "heavy": true, "power": 2, "step": [0.3, 0.5, 6.0], "from": 0.22, "combo_from": 0.66, "trail_boost": 1.5}))
	s.add(AttackData.make({"id": "vz_heat_spike", "kind": "heat", "title": "В АСФАЛЬТ", "clip": "HeatSpike", "duration": 0.9, "hits": [0.59], "damage": 75.0, "stagger": 80.0, "reach": 3.6, "arc": 3.0,
		"knockback": 2.0, "launch": -18.0, "heavy": true, "power": 2, "slam": 0.6, "from": 0.16, "trail_boost": 1.5, "feedback": "vz_quake"}))
	s.add(AttackData.make({"id": "vz_heat_finish", "kind": "heat", "title": "ДОБИЛ", "clip": "Finisher", "duration": 1.0, "hits": [0.6], "damage": 95.0, "stagger": 90.0, "reach": 3.2, "arc": 2.6,
		"knockback": 2.0, "launch": 5.0, "heavy": true, "power": 2, "slam": 0.6, "step": [0.12, 0.3, 4.0], "from": 0.06, "trail_boost": 1.5, "feedback": "vz_quake"}))
	# ---- [F] бутылка из комбо: левой рукой, не выпуская балон; тратит запас «Водяры»; цепочка идёт дальше ----
	s.add(AttackData.make({"id": "vz_bottle", "kind": "ranged", "clip": "BottleSnap", "duration": 0.6, "hits": [0.42], "damage": 9.0, "stagger": 22.0, "reach": 12.0, "arc": 1.6,
		"knockback": 2.0, "projectile": "bottle", "ammo": 1, "combo_from": 0.6, "recovery": 0.94, "from": 0.12, "feedback": "bt_hit",
		"extra": {"speed": 17.0, "slow": 2.5, "slow_k": 0.6, "hand": "l", "ammo_style": "bottles"}}))
	# ---- Heat-действие: удар сверху и полный замах с замедлением ----
	s.add(AttackData.make({"id": "vz_heat_smash", "kind": "heat", "clip": "HeatSmash", "duration": 0.92, "hits": [0.59], "damage": 60.0, "stagger": 60.0, "reach": 3.2, "arc": 2.4,
		"knockback": 1.0, "launch": 7.5, "heavy": true, "power": 2, "slam": 0.6, "combo_from": 0.8, "trail_boost": 1.5}))
	s.add(AttackData.make({"id": "vz_heat_swing", "kind": "heat", "clip": "HeatSwing", "duration": 0.85, "hits": [0.34], "damage": 90.0, "stagger": 80.0, "reach": 3.4, "arc": 3.0,
		"knockback": 20.0, "launch": 7.0, "heavy": true, "power": 2, "step": [0.14, 0.4, 6.0], "trail_boost": 1.5}))
	# ---- в прыжке (этап 0: свои начала цепочки; собственные клипы — этап 1) ----
	s.add(AttackData.make({"id": "vz_air_light", "kind": "light", "title": "С ЛЁТА", "clip": "AirSwing", "duration": 0.6, "hits": [0.52], "damage": 24.0, "stagger": 14.0, "reach": 2.7, "arc": 2.6,
		"knockback": 3.0, "launch": 4.0, "from": 0.2, "combo_from": 0.66, "extra": {"hop": 4.0}}))
	s.add(AttackData.make({"id": "vz_air_slam", "kind": "slam", "title": "СВЕРХУ", "clip": "AirAttack", "duration": 0.7, "hits": [0.6], "damage": 40.0, "stagger": 40.0, "reach": 3.0, "arc": 2.4,
		"knockback": 4.0, "launch": -18.0, "heavy": true, "power": 1, "slam": 0.64, "trail_boost": 1.25, "feedback": "vz_slam", "extra": {"hop": 2.5}}))
	# ---- этап 1: пятиударная цепочка ЛКМ, удар по ногам, связка в воздухе ----
	s.add(AttackData.make({"id": "vz_check", "kind": "light", "title": "ПЛЕЧОМ", "clip": "BodyCheck", "duration": 0.72, "hits": [0.5], "damage": 26.0, "stagger": 28.0, "reach": 2.3, "arc": 2.0,
		"knockback": 7.0, "step": [0.34, 0.52, 6.0], "combo_from": 0.66}))
	s.add(AttackData.make({"id": "vz_ohsmash", "kind": "light", "title": "СВЕРХУ ВНИЗ", "clip": "ChainSmash", "duration": 0.86, "hits": [0.52], "damage": 34.0, "stagger": 30.0, "reach": 2.8, "arc": 2.2,
		"knockback": 3.0, "step": [0.4, 0.54, 3.6], "combo_from": 0.7, "slam": 0.56}))
	s.add(AttackData.make({"id": "vz_crush", "kind": "finisher", "title": "ДОДАВИЛ", "clip": "FinalCrush", "duration": 1.0, "hits": [0.58], "damage": 52.0, "stagger": 60.0, "reach": 3.1, "arc": 3.4,
		"knockback": 16.0, "launch": 4.0, "heavy": true, "power": 2, "spin": 1.0, "step": [0.2, 0.56, 4.0], "slam": 0.6, "trail_boost": 1.4, "feedback": "vz_finisher"}))
	s.add(AttackData.make({"id": "vz_sweep", "kind": "heavy", "title": "ПО НОГАМ", "clip": "LowSweep", "duration": 0.9, "hits": [0.5], "damage": 30.0, "stagger": 40.0, "reach": 3.0, "arc": 6.3,
		"knockback": 3.0, "launch": 2.5, "stun": 0.6, "heavy": true, "power": 1, "spin": 1.0, "combo_from": 0.72, "feedback": "vz_launcher", "extra": {"react": "knockdown"}}))
	s.add(AttackData.make({"id": "vz_air_follow", "kind": "light", "title": "ВДОГОНКУ", "clip": "AirFollow", "duration": 0.5, "hits": [0.5], "damage": 22.0, "stagger": 12.0, "reach": 2.9, "arc": 2.8,
		"knockback": 0.5, "launch": 6.5, "from": 0.15, "combo_from": 0.64, "extra": {"hop": 7.5}}))
	s.add(AttackData.make({"id": "vz_air_crush", "kind": "light", "title": "С НЕБА", "clip": "AirCrush", "duration": 0.5, "hits": [0.55], "damage": 26.0, "stagger": 16.0, "reach": 3.0, "arc": 2.8,
		"knockback": 0.5, "launch": 5.5, "combo_from": 0.7, "extra": {"hop": 4.0}}))
	s.add(AttackData.make({"id": "vz_air_finisher", "kind": "slam", "title": "В АСФАЛЬТ С НЕБА", "clip": "AirDrive", "duration": 0.56, "hits": [0.6], "damage": 46.0, "stagger": 50.0, "reach": 3.3, "arc": 3.2,
		"knockback": 4.0, "launch": -18.0, "heavy": true, "power": 2, "slam": 0.64, "trail_boost": 1.3, "feedback": "vz_slam", "extra": {"hop": 2.0}}))
	s.links = {
		"": {"light": "vz_light1", "heavy": "vz_overhead", "throw": "vz_bottle"},
		# в прыжке: мах → удар сверху → добивание с неба
		"air": {"light": "vz_air_light", "heavy": "vz_air_slam"},
		"vz_air_light": {"light": "vz_air_crush", "heavy": "vz_air_slam"},
		"vz_air_follow": {"light": "vz_air_crush", "heavy": "vz_air_finisher"},
		"vz_air_crush": {"light": "vz_air_finisher", "heavy": "vz_air_finisher"},
		# ЛКМ ×5: боковой → обратный → плечом → сверху вниз → додавил; ПКМ после каждого — своя концовка
		"vz_light1": {"light": "vz_light2", "heavy": "vz_upper", "throw": "vz_bottle"},       # Л × Т: подброс
		"vz_light2": {"light": "vz_check", "heavy": "vz_fullswing", "throw": "vz_bottle"},    # Л × Л × Т: полный замах
		"vz_check": {"light": "vz_ohsmash", "heavy": "vz_sweep", "throw": "vz_bottle"},       # после плеча — по ногам
		"vz_ohsmash": {"light": "vz_crush", "heavy": "vz_spin"},
		"vz_sweep": {"light": "vz_upper", "heavy": "vz_quake"},                               # сбил с ног → подброс или удар по земле
		"vz_upper": {"light": "vz_air_follow", "heavy": "vz_spin", "throw": "vz_bottle"},     # подбросил → вдогонку в воздух / вертушка / бутылка
		"vz_bottle": {"light": "vz_light2", "heavy": "vz_nail"},
		"vz_overhead": {"heavy": "vz_quake", "light": "vz_rise"},  # тяжёлый → тяжёлый / тяжёлый → подброс
		"vz_rise": {"light": "vz_slam", "heavy": "vz_spin"},
		"vz_parry_light": {"light": "vz_light2", "heavy": "vz_quake"},
		"vz_block_shove": {"light": "vz_upper", "heavy": "vz_nail"},
		"vz_perfect_launch": {"light": "vz_air_follow", "heavy": "vz_slam"},
		"vz_dash_swing": {"light": "vz_light2", "heavy": "vz_nail"},
		"vz_roll_swing": {"light": "vz_light2", "heavy": "vz_nail"},   # после уклонения цепочка идёт дальше
		"vz_roll_launch": {"light": "vz_air_follow", "heavy": "vz_slam"},    # подбросил с ходу → вбил в землю или вертушка
	}
	s.after_dodge = {"light": "vz_roll_swing", "heavy": "vz_roll_launch"}
	s.after = {
		"parry": {"light": "vz_parry_light", "heavy": "vz_parry_heavy"},
		"perfect": {"light": "vz_perfect_swing", "heavy": "vz_perfect_launch"},
		"block": {"light": "vz_block_shove", "heavy": "vz_block_shove"},
		"dodge": {"light": "vz_roll_swing", "heavy": "vz_roll_launch"},
		"sprint": {"light": "vz_dash_swing", "heavy": "vz_dash_slam"},
	}
	s.heat_ctx = {"air": ["vz_heat_air", "vz_heat_spike"], "stun": ["vz_heat_finish"]}
	s.heat = ["vz_heat_smash", "vz_heat_swing"]
	return s
