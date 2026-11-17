## Стиль «Скейтборд» (madk1d): быстрый и подвижный. На ногах доска — оружие в руке (цепочки ядра боя),
## с зажатым Ctrl madk1d встаёт на доску: разгон, слайд, прыжок, трюки, удары в воздухе и с приземления (skate.gd).
## Трюки дают заряды: каждый усиливает следующий удар. Не докрутил трюк до земли — падение и потеря зарядов.
class_name StyleSkateboard

static func build() -> StyleData:
	var s := StyleData.new()
	s.id = "skateboard"
	s.title = "Скейтборд"
	s.owner = "madk1d"
	s.ready = true
	s.note = "скорость, трюки и удары доской: на ногах, на ходу и в воздухе"
	s.weapon = {"path": "res://assets/models/skateboard.glb", "side": "r", "opt": {"axis": "x", "from": -48.9, "to": 48.9, "grip": 0.1, "length": 0.56}}
	s.color = Color(0.36, 0.82, 1.0)
	s.color_hot = Color(1.0, 0.9, 0.4)
	s.chain_cd = 0.1
	s.roles = {"idle": "ArmedIdle", "combat_idle": "ArmedIdle", "walk": "SkWalk", "run": "SkRun", "sprint": "SkSprint"}      # с доской в руках — свои шаг и бег
	s.hit_sfx = [[["sfx_hit", -3.0, 1.3]], [["sfx_hit_heavy", -2.0, 1.2]], [["sfx_hit_heavy", 0.0, 1.0], ["sfx_crack", -2.0, 1.2]]]
	# ---- на ногах: два быстрых маха и удар с разворота ----
	s.add(AttackData.make({"id": "sk_swing1", "kind": "light", "clip": "SkTail", "duration": 0.5, "hits": [0.5], "damage": 14.0, "stagger": 12.0, "reach": 2.3, "arc": 2.6,
		"knockback": 3.0, "step": [0.36, 0.6, 5.5], "combo_from": 0.6}))
	s.add(AttackData.make({"id": "sk_swing2", "kind": "light", "clip": "SkNose", "duration": 0.48, "hits": [0.5], "damage": 15.0, "stagger": 13.0, "reach": 2.3, "arc": 2.6,
		"knockback": 3.5, "step": [0.36, 0.6, 5.5], "combo_from": 0.6, "from": 0.14}))
	s.add(AttackData.make({"id": "sk_spin", "kind": "light", "title": "BOARD SPIN", "clip": "SkBoardSpin", "duration": 0.62, "hits": [0.35, 0.6], "damage": 11.0, "stagger": 12.0, "reach": 2.4, "arc": 6.3,
		"knockback": 5.0, "spin": 1.0, "combo_from": 0.7, "from": 0.1}))
	# третий и пятый лёгкие: ногой и доской (два попадания), удар сверху с подскока
	s.add(AttackData.make({"id": "sk_kick", "kind": "light", "clip": "SkKickPush", "duration": 0.6, "hits": [0.28, 0.56], "damage": 9.0, "stagger": 12.0, "reach": 2.4, "arc": 1.8,
		"knockback": 4.0, "step": [0.3, 0.56, 5.0], "combo_from": 0.72, "from": 0.1}))
	s.add(AttackData.make({"id": "sk_slam", "kind": "finisher", "title": "FINAL SLAM", "clip": "SkSlam", "duration": 0.8, "hits": [0.56], "damage": 32.0, "stagger": 45.0, "reach": 2.7, "arc": 2.4,
		"knockback": 5.0, "launch": -16.0, "heavy": true, "power": 1, "slam": 0.56, "step": [0.3, 0.56, 4.5], "from": 0.06, "feedback": "vz_slam"}))
	# ---- трюковые удары на ногах ([F]): попадание даёт заряд трюка, как трюк на доске ----
	s.add(AttackData.make({"id": "sk_kickflip", "kind": "light", "title": "KICKFLIP", "clip": "SkFlipStrike", "duration": 0.6, "hits": [0.58], "damage": 18.0, "stagger": 22.0, "reach": 2.5, "arc": 1.8,
		"knockback": 3.0, "launch": 3.5, "power": 1, "step": [0.4, 0.58, 4.5], "combo_from": 0.7, "from": 0.08, "feedback": "vz_launcher", "extra": {"trick": 1}}))
	s.add(AttackData.make({"id": "sk_shove", "kind": "light", "title": "SHOVE-IT", "clip": "SkShove", "duration": 0.56, "hits": [0.5], "damage": 14.0, "stagger": 35.0, "reach": 2.6, "arc": 6.3,
		"knockback": 3.0, "stun": 0.5, "spin": 1.0, "combo_from": 0.7, "from": 0.08, "extra": {"trick": 1}}))
	s.add(AttackData.make({"id": "sk_ollie", "kind": "heavy", "title": "OLLIE", "clip": "SkOllieStomp", "duration": 0.7, "hits": [0.58], "damage": 24.0, "stagger": 40.0, "reach": 2.8, "arc": 6.3,
		"knockback": 6.0, "launch": 3.0, "heavy": true, "power": 1, "slam": 0.58, "from": 0.06, "feedback": "vz_slam", "extra": {"trick": 1}}))
	# ---- в прыжке ----
	s.add(AttackData.make({"id": "sk_airstrike", "kind": "light", "title": "С ЛЁТА", "clip": "SkAirStrike", "duration": 0.42, "hits": [0.5], "damage": 15.0, "stagger": 18.0, "reach": 2.5, "arc": 2.6,
		"knockback": 4.0, "combo_from": 0.6, "extra": {"hop": 2.5}}))
	s.add(AttackData.make({"id": "sk_airslam", "kind": "slam", "title": "СВЕРХУ", "clip": "SkAirSlam", "duration": 0.5, "hits": [0.55], "damage": 26.0, "stagger": 40.0, "reach": 2.7, "arc": 2.4,
		"knockback": 4.0, "launch": -16.0, "heavy": true, "power": 1, "slam": 0.55, "feedback": "vz_slam"}))
	# ---- тяжёлые: сверху, подброс, подсечка ----
	s.add(AttackData.make({"id": "sk_over", "kind": "heavy", "title": "ДОСКОЙ", "clip": "MOver", "duration": 0.7, "hits": [0.55], "damage": 30.0, "stagger": 35.0, "reach": 2.5, "arc": 2.0,
		"knockback": 5.0, "heavy": true, "power": 1, "step": [0.4, 0.58, 4.0], "from": 0.06, "feedback": "vz_heavy"}))
	s.add(AttackData.make({"id": "sk_launch", "kind": "launcher", "clip": "MUpper", "duration": 0.6, "hits": [0.5], "damage": 20.0, "stagger": 20.0, "reach": 2.4, "arc": 2.2,
		"knockback": 2.0, "launch": 6.5, "heavy": true, "power": 1, "step": [0.36, 0.55, 4.5], "from": 0.1, "combo_from": 0.62, "feedback": "vz_launcher"}))
	s.add(AttackData.make({"id": "sk_sweep", "kind": "finisher", "title": "ПОДСЕЧКА", "clip": "MSweep", "duration": 0.66, "hits": [0.5], "damage": 18.0, "stagger": 40.0, "reach": 2.7, "arc": 6.3,
		"knockback": 4.0, "launch": 2.5, "stun": 0.8, "spin": 1.0, "heavy": true, "power": 1, "from": 0.08, "feedback": "vz_finisher"}))
	# ---- с доски и после трюков ----
	s.add(AttackData.make({"id": "sk_dash", "kind": "light", "title": "С РАЗГОНА", "clip": "MSwing1", "duration": 0.46, "hits": [0.5], "damage": 22.0, "stagger": 25.0, "reach": 2.6, "arc": 2.8,
		"knockback": 8.0, "step": [0.3, 0.7, 9.0], "combo_from": 0.62, "from": 0.3, "feedback": "vz_heavy"}))
	s.add(AttackData.make({"id": "sk_counter", "kind": "light", "title": "ОТВЕТ", "clip": "MSwing2", "duration": 0.46, "hits": [0.5], "damage": 26.0, "stagger": 30.0, "reach": 2.5, "arc": 2.8,
		"knockback": 8.0, "step": [0.3, 0.6, 7.0], "combo_from": 0.62, "from": 0.25, "feedback": "vz_heavy"}))
	# ---- воздействия езды (их наносит skate.gd) ----
	s.add(AttackData.make({"id": "sk_slide", "kind": "skate", "clip": "SkateSlide", "hits": [0.0], "damage": 14.0, "stagger": 25.0, "reach": 1.2, "arc": 6.3, "knockback": 3.0, "launch": 2.0, "feedback": "hit_light"}))
	s.add(AttackData.make({"id": "sk_air", "kind": "skate", "clip": "SkateAir", "duration": 0.35, "hits": [0.35], "damage": 16.0, "stagger": 18.0, "reach": 2.3, "arc": 2.6, "knockback": 5.0, "launch": 3.0, "power": 1, "feedback": "vz_launcher"}))
	s.add(AttackData.make({"id": "sk_land", "kind": "skate", "title": "ПРИЗЕМЛИЛСЯ", "clip": "SkateDive", "hits": [0.0], "damage": 22.0, "stagger": 40.0, "reach": 3.0, "arc": 6.3, "knockback": 7.0, "launch": 4.0, "heavy": true, "power": 1, "feedback": "vz_slam"}))
	s.add(AttackData.make({"id": "sk_spin360", "kind": "skate", "title": "360", "clip": "SkateRide", "duration": 0.45, "hits": [0.5], "damage": 18.0, "stagger": 22.0, "reach": 2.4, "arc": 6.3, "knockback": 6.0, "power": 1, "cooldown": 0.9, "feedback": "vz_heavy"}))
	s.links = {
		# ЛКМ ×5: хвостом → носом → ногой и доской → доска вокруг себя → FINAL SLAM; F — трюковой удар
		"": {"light": "sk_swing1", "heavy": "sk_over", "throw": "sk_kickflip"},
		"sk_swing1": {"light": "sk_swing2", "heavy": "sk_launch", "throw": "sk_kickflip"},
		"sk_swing2": {"light": "sk_kick", "heavy": "sk_sweep", "throw": "sk_shove"},
		"sk_kick": {"light": "sk_spin", "heavy": "sk_ollie", "throw": "sk_shove"},
		"sk_spin": {"light": "sk_slam", "heavy": "sk_over", "throw": "sk_kickflip"},
		"sk_launch": {"light": "sk_swing2", "heavy": "sk_over", "throw": "sk_kickflip"},      # подброс → KICKFLIP по подброшенному
		"sk_kickflip": {"light": "sk_swing2", "heavy": "sk_ollie", "throw": "sk_shove"},      # трюк × удар доской
		"sk_shove": {"light": "sk_kick", "heavy": "sk_launch"},
		"sk_dash": {"light": "sk_swing2", "heavy": "sk_sweep", "throw": "sk_kickflip"},
		"sk_counter": {"light": "sk_spin", "heavy": "sk_launch", "throw": "sk_shove"},
		# в прыжке: удар с лёта → удар сверху вниз
		"air": {"light": "sk_airstrike", "heavy": "sk_airslam"},
		"sk_airstrike": {"light": "sk_airstrike", "heavy": "sk_airslam"},
	}
	s.after = {"dodge": {"light": "sk_counter", "heavy": "sk_kickflip"}, "perfect": {"light": "sk_counter", "heavy": "sk_spin"}}
	return s

## езда и трюки
const RIDE := {"vmax": 9.8, "accel": 16.0, "coast": 5.0, "steer": 3.4, "steer_slide": 5.5, "grip": 11.0, "grip_slide": 2.0, "slide_drag": 7.0,
	"ollie": 7.2, "deck": 0.11, "bail": 0.85, "charge_mul": 0.25, "max_charges": 3}
## трюки: длительность (с), заряды за успех, вращение доски [вокруг продольной оси, вокруг вертикали] в оборотах
const TRICKS := {
	"kickflip": {"title": "KICKFLIP", "t": 0.36, "gain": 1, "roll": 1.0, "yaw": 0.0},
	"heelflip": {"title": "HEELFLIP", "t": 0.36, "gain": 1, "roll": -1.0, "yaw": 0.0},
	"shoveit": {"title": "SHOVE-IT", "t": 0.32, "gain": 1, "roll": 0.0, "yaw": 0.5},
	"flip360": {"title": "360 FLIP", "t": 0.54, "gain": 2, "roll": 1.0, "yaw": 1.0},
	"boardspin": {"title": "BOARD SPIN", "t": 0.45, "gain": 1, "roll": 0.0, "yaw": 1.0},
}
