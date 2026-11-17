## Стиль «Breaker» (madk1d): боевое искусство на брейк-дансе, без оружия. Бьют ноги: удары, подсечки, вращения
## по площади, подброс и удары в воздухе. Поток, Freeze и риск — в breaker.gd.
## Поля extra: hop — прыжок на старте атаки (м/с), inv — короткая неуязвимость на старте (нырок под удар),
## spinny — вращение, во время которого героя легче наказать, freeze / finisher — служебные.
class_name StyleBreaker

static func build() -> StyleData:
	var s := StyleData.new()
	s.id = "breaker"
	s.title = "Breaker"
	s.owner = "madk1d"
	s.ready = true
	s.note = "брейк: удары ногами, подсечки, вращения по площади, Freeze"
	s.color = Color(0.36, 0.82, 1.0)
	s.color_hot = Color(1.0, 0.55, 0.9)
	s.chain_cd = 0.08
	s.roles = {"idle": "CombatIdle", "combat_idle": "CombatIdle"}
	s.hit_sfx = [[["sfx_hit", -3.0, 1.2]], [["sfx_hit_heavy", -3.0, 1.2]], [["sfx_hit_heavy", 0.0, 1.0], ["sfx_crack", -2.0, 1.3]]]
	# ---- ЛКМ: toprock → удар с разворота → footwork (шесть шагов) → подсечка ----
	s.add(AttackData.make({"id": "br_toprock", "kind": "light", "clip": "Toprock", "duration": 0.42, "hits": [0.5], "damage": 10.0, "stagger": 10.0, "reach": 2.2, "arc": 2.2,
		"knockback": 3.0, "step": [0.3, 0.55, 5.0], "combo_from": 0.62}))
	s.add(AttackData.make({"id": "br_round", "kind": "light", "clip": "RoundKick", "duration": 0.44, "hits": [0.5], "damage": 12.0, "stagger": 12.0, "reach": 2.3, "arc": 2.8,
		"knockback": 4.0, "step": [0.3, 0.55, 4.5], "combo_from": 0.64, "from": 0.12}))
	s.add(AttackData.make({"id": "br_sixstep", "kind": "light", "title": "SIX-STEP", "clip": "SixStep", "duration": 0.62, "hits": [0.3, 0.6], "damage": 8.0, "stagger": 12.0, "reach": 2.2, "arc": 6.3,
		"knockback": 2.0, "spin": 0.5, "combo_from": 0.7, "extra": {"inv": 0.18}}))
	s.add(AttackData.make({"id": "br_sweep", "kind": "light", "title": "ПОДСЕЧКА", "clip": "LegSweep", "duration": 0.56, "hits": [0.5], "damage": 14.0, "stagger": 35.0, "reach": 2.5, "arc": 6.3,
		"knockback": 3.0, "launch": 2.5, "stun": 0.6, "spin": 1.0, "combo_from": 0.72, "feedback": "vz_launcher", "extra": {"spinny": true, "react": "knockdown"}}))
	# ---- ПКМ: вертолёт с места; после ударов — мельница, вращение на голове, флэр ----
	s.add(AttackData.make({"id": "br_heli", "kind": "heavy", "title": "ВЕРТОЛЁТ", "clip": "Helicopter", "duration": 0.85, "hits": [0.3, 0.45, 0.6, 0.75], "damage": 7.0, "stagger": 10.0, "reach": 2.5, "arc": 6.3,
		"knockback": 3.0, "spin": 2.0, "heavy": true, "power": 1, "last_launch": 3.0, "combo_from": 0.82, "feedback": "vz_heavy", "extra": {"hop": 5.5, "spinny": true}}))
	s.add(AttackData.make({"id": "br_windmill", "kind": "heavy", "title": "МЕЛЬНИЦА", "clip": "Windmill", "duration": 0.9, "hits": [0.2, 0.4, 0.6, 0.8], "damage": 7.0, "stagger": 12.0, "reach": 2.6, "arc": 6.3,
		"knockback": 2.0, "spin": 2.0, "heavy": true, "power": 1, "combo_from": 0.84, "extra": {"spinny": true, "inv": 0.15}}))
	s.add(AttackData.make({"id": "br_kickup", "kind": "launcher", "title": "ПОДЪЁМ", "clip": "KickUp", "duration": 0.5, "hits": [0.48], "damage": 16.0, "stagger": 20.0, "reach": 2.4, "arc": 2.6,
		"knockback": 2.0, "launch": 7.0, "heavy": true, "power": 1, "combo_from": 0.62, "from": 0.1, "feedback": "vz_launcher"}))
	s.add(AttackData.make({"id": "br_headspin", "kind": "heavy", "title": "HEADSPIN", "clip": "HeadSpin", "duration": 1.0, "hits": [0.42, 0.52, 0.62, 0.72], "damage": 9.0, "stagger": 12.0, "reach": 2.8, "arc": 6.3,
		"knockback": 4.0, "spin": 2.5, "heavy": true, "power": 1, "combo_from": 0.86, "feedback": "vz_heavy", "extra": {"spinny": true}}))
	s.add(AttackData.make({"id": "br_flare", "kind": "finisher", "title": "ФЛЭР", "clip": "Flare", "duration": 0.7, "hits": [0.45], "damage": 22.0, "stagger": 45.0, "reach": 3.2, "arc": 6.3,
		"knockback": 8.0, "launch": 4.0, "spin": 1.0, "heavy": true, "power": 1, "combo_from": 0.8, "feedback": "vz_slam", "extra": {"spinny": true}}))
	# ---- в воздухе: после подброса ----
	s.add(AttackData.make({"id": "br_air1", "kind": "light", "clip": "AirKick", "duration": 0.36, "hits": [0.45], "damage": 12.0, "stagger": 10.0, "reach": 2.6, "arc": 2.8,
		"knockback": 1.0, "launch": 4.5, "combo_from": 0.6, "extra": {"hop": 7.0}}))
	s.add(AttackData.make({"id": "br_air2", "kind": "light", "clip": "AirSpin", "duration": 0.42, "hits": [0.5], "damage": 14.0, "stagger": 12.0, "reach": 2.6, "arc": 6.3,
		"knockback": 1.0, "launch": 4.0, "spin": 1.0, "combo_from": 0.66, "extra": {"hop": 4.0}}))
	s.add(AttackData.make({"id": "br_airdive", "kind": "slam", "title": "ВНИЗ", "clip": "AirDive", "duration": 0.5, "hits": [0.6], "damage": 20.0, "stagger": 30.0, "reach": 2.8, "arc": 3.2,
		"knockback": 4.0, "launch": -18.0, "heavy": true, "power": 1, "slam": 0.85, "feedback": "vz_slam", "extra": {"hop": 2.0}}))
	# ---- Freeze: F в окне комбо любой атаки — застыл в позе; из неё — ответ, подброс или финал ----
	s.add(AttackData.make({"id": "br_freeze", "kind": "freeze", "clip": "FreezePose", "duration": 0.75, "hits": [0.26], "damage": 0.0, "stagger": 0.0, "reach": 0.0, "arc": 0.1,
		"knockback": 0.0, "combo_from": 0.42, "recovery": 0.98, "extra": {"freeze": true}}))
	s.add(AttackData.make({"id": "br_counter", "kind": "light", "title": "ОТВЕТ", "clip": "KickUp", "duration": 0.44, "hits": [0.48], "damage": 24.0, "stagger": 35.0, "reach": 2.6, "arc": 2.8,
		"knockback": 9.0, "combo_from": 0.62, "from": 0.12, "feedback": "vz_heavy"}))
	s.add(AttackData.make({"id": "br_finisher", "kind": "finisher", "title": "BREAKER FINISHER", "clip": "Helicopter", "duration": 1.0, "hits": [0.3, 0.42, 0.54, 0.66, 0.78], "damage": 12.0, "stagger": 25.0, "reach": 3.4, "arc": 6.3,
		"knockback": 6.0, "spin": 3.0, "heavy": true, "power": 2, "last_launch": 6.5, "feedback": "vz_quake", "extra": {"hop": 6.5, "finisher": true}}))
	s.links = {
		"": {"light": "br_toprock", "heavy": "br_heli"},
		"br_toprock": {"light": "br_round", "heavy": "br_windmill", "throw": "br_freeze"},
		"br_round": {"light": "br_sixstep", "heavy": "br_headspin", "throw": "br_freeze"},      # toprock → footwork
		"br_sixstep": {"light": "br_sweep", "heavy": "br_flare", "throw": "br_freeze"},         # six-step → подсечка
		"br_sweep": {"light": "br_toprock", "heavy": "br_kickup", "throw": "br_freeze"},
		"br_heli": {"light": "br_round", "throw": "br_freeze"},
		"br_windmill": {"heavy": "br_kickup", "light": "br_sweep", "throw": "br_freeze"},       # мельница → подброс
		"br_headspin": {"heavy": "br_flare", "light": "br_sweep", "throw": "br_freeze"},        # вращение → удар по площади
		"br_flare": {"throw": "br_freeze", "heavy": "br_kickup"},
		"br_kickup": {"light": "br_air1", "heavy": "br_airdive", "throw": "br_freeze"},         # подброс → в воздух
		"br_air1": {"light": "br_air2", "heavy": "br_airdive"},
		"br_air2": {"heavy": "br_airdive", "light": "br_air1"},
		"br_freeze": {"light": "br_counter", "heavy": "br_kickup", "throw": "br_finisher"},     # freeze → ответ / в воздух / финал
		"br_counter": {"light": "br_round", "heavy": "br_windmill", "throw": "br_freeze"},
	}
	s.after = {"dodge": {"light": "br_counter", "heavy": "br_windmill"}, "perfect": {"light": "br_counter", "heavy": "br_headspin"}, "block": {"light": "br_counter"}}
	return s
