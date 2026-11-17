## Стиль «Электрогитара» (madk1d): гитара — оружие ближнего боя (держит за гриф, бьёт корпусом) и дальнего
## (звуковые волны). F — игра на гитаре: POWER CHORD, после подброса — AIR RIFF; ритм, дисторшн и звук — guitar.gd.
## Поля extra: sound — звук способности, wave — вид волны, air_only — бьёт только тех, кто в воздухе,
## bars — сколько делений ритма нужно (и тратится).
class_name StyleGuitar

static func build() -> StyleData:
	var s := StyleData.new()
	s.id = "guitar"
	s.title = "Электрогитара"
	s.owner = "madk1d"
	s.ready = true
	s.note = "ритм и звук: удары корпусом и грифом, звуковые волны, дисторшн"
	s.weapon = {"path": "res://assets/models/guitar.glb", "side": "r", "opt": {"axis": "x", "from": 48.95, "to": -48.95, "grip": 0.28, "length": 0.62}}
	s.color = Color(0.7, 0.9, 1.0)
	s.color_hot = Color(1.0, 0.85, 0.4)
	s.chain_cd = 0.1
	s.roles = {"idle": "ArmedIdle", "combat_idle": "ArmedIdle"}
	s.hit_sfx = [[["sfx_hit", -3.0, 0.9]], [["sfx_hit_heavy", -2.0, 0.9]], [["sfx_hit_heavy", 0.0, 0.8], ["sfx_crack", -2.0, 1.0]]]
	# ---- физические удары ----
	s.add(AttackData.make({"id": "gt_body", "kind": "light", "clip": "MSwing1", "duration": 0.52, "hits": [0.5], "damage": 16.0, "stagger": 14.0, "reach": 2.5, "arc": 2.6,
		"knockback": 3.5, "step": [0.36, 0.6, 5.0], "combo_from": 0.72}))
	s.add(AttackData.make({"id": "gt_neck", "kind": "light", "clip": "MThrust", "duration": 0.5, "hits": [0.48], "damage": 14.0, "stagger": 16.0, "reach": 2.9, "arc": 1.5,
		"knockback": 5.0, "step": [0.34, 0.56, 6.0], "combo_from": 0.72, "from": 0.14}))
	s.add(AttackData.make({"id": "gt_turn", "kind": "light", "clip": "MSpin", "duration": 0.62, "hits": [0.35, 0.6], "damage": 12.0, "stagger": 12.0, "reach": 2.6, "arc": 6.3,
		"knockback": 5.0, "spin": 1.0, "combo_from": 0.7, "from": 0.1}))
	s.add(AttackData.make({"id": "gt_slam", "kind": "heavy", "title": "В ПОЛ", "clip": "MOver", "duration": 0.8, "hits": [0.55], "damage": 34.0, "stagger": 40.0, "reach": 2.7, "arc": 2.0,
		"knockback": 5.0, "launch": -18.0, "heavy": true, "power": 1, "slam": 0.58, "step": [0.4, 0.58, 4.0], "from": 0.06, "combo_from": 0.8, "feedback": "vz_slam"}))
	s.add(AttackData.make({"id": "gt_launch", "kind": "launcher", "clip": "MUpper", "duration": 0.62, "hits": [0.5], "damage": 20.0, "stagger": 20.0, "reach": 2.5, "arc": 2.2,
		"knockback": 2.0, "launch": 7.0, "heavy": true, "power": 1, "step": [0.36, 0.55, 4.5], "from": 0.1, "combo_from": 0.6, "feedback": "vz_launcher"}))
	s.add(AttackData.make({"id": "gt_spin", "kind": "finisher", "title": "GUITAR SPIN", "clip": "MSpin", "duration": 0.95, "hits": [0.25, 0.4, 0.55, 0.7], "damage": 9.0, "stagger": 10.0, "reach": 2.7, "arc": 6.3,
		"knockback": 3.0, "spin": 2.0, "heavy": true, "power": 1, "last_launch": 4.0, "from": 0.08, "combo_from": 0.78, "feedback": "vz_finisher"}))
	s.add(AttackData.make({"id": "gt_counter", "kind": "light", "title": "ОТВЕТ", "clip": "MSwing2", "duration": 0.46, "hits": [0.5], "damage": 26.0, "stagger": 30.0, "reach": 2.6, "arc": 2.8,
		"knockback": 8.0, "step": [0.3, 0.6, 7.0], "combo_from": 0.62, "from": 0.25, "feedback": "vz_heavy"}))
	s.add(AttackData.make({"id": "gt_dash", "kind": "light", "title": "С РАЗГОНА", "clip": "MThrust", "duration": 0.46, "hits": [0.48], "damage": 22.0, "stagger": 25.0, "reach": 3.0, "arc": 1.8,
		"knockback": 9.0, "step": [0.22, 0.6, 9.0], "combo_from": 0.62, "from": 0.2, "cooldown": 1.0, "feedback": "vz_heavy"}))
	s.add(AttackData.make({"id": "gt_jump", "kind": "slam", "title": "С ПРЫЖКА", "clip": "MFinal", "duration": 0.85, "hits": [0.62], "damage": 36.0, "stagger": 45.0, "reach": 3.0, "arc": 3.0,
		"knockback": 6.0, "launch": 4.0, "heavy": true, "power": 1, "slam": 0.62, "step": [0.2, 0.6, 7.0], "from": 0.12, "cooldown": 2.0, "feedback": "vz_slam"}))
	# ---- музыкальные способности ----
	s.add(AttackData.make({"id": "gt_chord", "kind": "ranged", "title": "POWER CHORD", "clip": "MStrum", "duration": 0.5, "hits": [0.4], "damage": 22.0, "stagger": 30.0, "reach": 8.0, "arc": 0.9,
		"knockback": 9.0, "power": 1, "cooldown": 1.2, "combo_from": 0.62, "from": 0.1, "feedback": "tg_shot", "extra": {"sound": "chord", "wave": "cone"}}))
	s.add(AttackData.make({"id": "gt_feedback", "kind": "ranged", "title": "FEEDBACK", "clip": "MStrum", "duration": 0.6, "hits": [0.4], "damage": 10.0, "stagger": 55.0, "reach": 4.5, "arc": 6.3,
		"knockback": 10.0, "heavy": true, "power": 1, "cooldown": 2.5, "combo_from": 0.6, "from": 0.1, "feedback": "tg_shot", "extra": {"sound": "feedback", "wave": "ring"}}))
	for i in 2:
		s.add(AttackData.make({"id": "gt_airriff%d" % (i + 1), "kind": "ranged", "title": "AIR RIFF", "clip": "MStrum", "duration": 0.42, "hits": [0.4], "damage": 14.0, "stagger": 15.0, "reach": 9.0, "arc": 1.6,
			"knockback": 1.0, "launch": 5.5, "power": 1, "combo_from": 0.6, "from": 0.12, "feedback": "vz_launcher", "extra": {"sound": "airriff", "wave": "up", "air_only": true}}))
	s.add(AttackData.make({"id": "gt_final", "kind": "finisher", "title": "FINAL TRACK", "clip": "MFinal", "duration": 1.1, "hits": [0.62], "damage": 60.0, "stagger": 80.0, "reach": 4.6, "arc": 6.3,
		"knockback": 12.0, "launch": 6.0, "heavy": true, "power": 2, "slam": 0.62, "from": 0.06, "feedback": "tg_burst", "extra": {"sound": "final", "wave": "final", "bars": 4}}))
	s.links = {
		"": {"light": "gt_body", "heavy": "gt_slam", "throw": "gt_chord"},
		"gt_body": {"light": "gt_neck", "heavy": "gt_launch", "throw": "gt_chord"},      # удар → POWER CHORD
		"gt_neck": {"light": "gt_turn", "heavy": "gt_spin", "throw": "gt_chord"},
		"gt_turn": {"heavy": "gt_slam", "throw": "gt_chord"},
		"gt_launch": {"light": "gt_body", "heavy": "gt_slam", "throw": "gt_airriff1"},    # подброс → AIR RIFF
		"gt_airriff1": {"throw": "gt_airriff2", "heavy": "gt_slam", "light": "gt_body"}, # AIR RIFF → ещё → вбить в пол
		"gt_airriff2": {"heavy": "gt_slam", "light": "gt_body"},
		"gt_spin": {"heavy": "gt_final", "throw": "gt_chord"},
		"gt_slam": {"throw": "gt_chord"},                                                # Guitar Spin → FINAL TRACK
		"gt_chord": {"light": "gt_body", "heavy": "gt_feedback"},
		"gt_feedback": {"light": "gt_launch", "heavy": "gt_slam"},                       # FEEDBACK → подброс
		"gt_counter": {"light": "gt_turn", "heavy": "gt_launch", "throw": "gt_chord"},
		"gt_dash": {"light": "gt_neck", "heavy": "gt_spin", "throw": "gt_chord"},
	}
	s.after = {
		"dodge": {"light": "gt_counter", "heavy": "gt_feedback"},
		"perfect": {"light": "gt_counter", "heavy": "gt_feedback"},
		"block": {"light": "gt_counter", "heavy": "gt_feedback"},
		"sprint": {"light": "gt_dash", "heavy": "gt_jump"},
	}
	return s
