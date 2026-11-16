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
	s.add(AttackData.make({"id": "vz_slam", "kind": "slam", "title": "В ЗЕМЛЮ", "clip": "Heavy", "duration": 1.0, "hits": [0.57], "damage": 44.0, "stagger": 40.0, "reach": 3.0, "arc": 2.2,
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
	s.add(AttackData.make({"id": "vz_roll_swing", "kind": "light", "clip": "Light1", "duration": 0.82, "hits": [0.52], "damage": 26.0, "stagger": 20.0, "reach": 2.8, "arc": 2.8,
		"knockback": 6.0, "step": [0.44, 0.64, 5.4], "combo_from": 0.68, "from": 0.33, "drop": 0.75}))
	s.add(AttackData.make({"id": "vz_roll_launch", "kind": "launcher", "title": "С ХОДУ", "clip": "Upper", "duration": 0.84, "hits": [0.5], "damage": 34.0, "stagger": 24.0, "reach": 2.8, "arc": 2.2,
		"knockback": 3.0, "launch": 6.5, "heavy": true, "power": 1, "step": [0.42, 0.56, 4.6], "combo_from": 0.62, "from": 0.28, "scrape": 0.36, "drop": 0.87, "feedback": "vz_launcher"}))
	# ---- Heat-действие: удар сверху и полный замах с замедлением ----
	s.add(AttackData.make({"id": "vz_heat_smash", "kind": "heat", "clip": "Smash", "duration": 0.92, "hits": [0.59], "damage": 60.0, "stagger": 60.0, "reach": 3.2, "arc": 2.4,
		"knockback": 1.0, "launch": 7.5, "heavy": true, "power": 2, "slam": 0.6, "combo_from": 0.8, "trail_boost": 1.5}))
	s.add(AttackData.make({"id": "vz_heat_swing", "kind": "heat", "clip": "FullSwing", "duration": 0.85, "hits": [0.34], "damage": 90.0, "stagger": 80.0, "reach": 3.4, "arc": 3.0,
		"knockback": 20.0, "launch": 7.0, "heavy": true, "power": 2, "step": [0.14, 0.4, 6.0], "trail_boost": 1.5}))
	s.links = {
		"": {"light": "vz_light1", "heavy": "vz_overhead"},
		"vz_light1": {"light": "vz_light2", "heavy": "vz_nail"},
		"vz_light2": {"light": "vz_upper", "heavy": "vz_fullswing"},
		"vz_upper": {"light": "vz_slam", "heavy": "vz_spin"},
		"vz_overhead": {"heavy": "vz_quake"},                     # тяжёлый → тяжёлый
		"vz_roll_swing": {"light": "vz_light2", "heavy": "vz_nail"},   # после уклонения цепочка идёт дальше
		"vz_roll_launch": {"light": "vz_slam", "heavy": "vz_spin"},    # подбросил с ходу → вбил в землю или вертушка
	}
	s.after_dodge = {"light": "vz_roll_swing", "heavy": "vz_roll_launch"}
	s.heat = ["vz_heat_smash", "vz_heat_swing"]
	return s
