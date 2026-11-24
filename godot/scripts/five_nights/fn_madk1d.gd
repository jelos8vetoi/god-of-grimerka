## MADK1D — ползает по вентиляции. Узел шахт (CAM 7) → левая шахта или верхняя → решётка у офиса.
## Его слышно: скребётся слева внизу (левая шахта) или над головой (верхняя), у решётки — стук и шёпот «Пахан…».
## Закрыта заслонка той шахты, где он, — постоит и уползёт назад. Закрыта не та — пролезет.
## Может перелезть из шахты в шахту (слышно, как звук переходит) — поэтому заслонку закрывают по звуку, а не заранее.
class_name FNMadk1d
extends FNEnemy

var duct_t := 0.0                # сколько ползёт по этой шахте
var duct_need := 0.0

## в шахте он не ждёт удачного броска: ползёт DUCT_SEC и выходит к решётке (или перелезает) — звук не тянется минутами
func tick(st, dt: float) -> void:
	if level > 0 and not entered and spot.begins_with("duct_") and queued == "":
		duct_t += dt
		if duct_t >= duct_need:
			_move(st)
		return
	super.tick(st, dt)

func go(st, to: String, why := "") -> void:
	super.go(st, to, why)
	if spot == to and to.begins_with("duct_"):
		duct_t = 0.0
		var D: Array = FNData.DUCT_SEC
		duct_need = lerpf(float(D[0]), float(D[1]), clampf(float(level - 1) / 19.0, 0.0, 1.0)) * st.rng.randf_range(0.85, 1.2) * (0.6 if why == "switch" else 1.0)

func _move(st) -> void:
	match spot:
		"vent":
			if st.t < rest_until - float(FNData.DUCT_SEC[0]):
				return                            # передышка: в шахту не лезет, пока не подойдёт срок (в шахте не ждёт минутами)
			# лезет той шахтой, чью заслонку ты закрываешь реже (с 5-го уровня); слышно его по-прежнему
			var p_left := 0.5
			if level >= 5:
				p_left = clampf(0.5 + 0.9 * (float(st.habit("seal_t")) - float(st.habit("seal_l"))), 0.15, 0.85)
				if absf(p_left - 0.5) > 0.1:
					st.emit("adapt", {"e": id, "how": "duct", "to": "l" if p_left > 0.5 else "t"})
			go(st, "duct_l" if st.rng.randf() < p_left else "duct_t")
		"duct_l", "duct_t":
			# перелезть в другую шахту — чаще на высоких уровнях
			if st.rng.randf() < 0.16 + float(level) * 0.01:
				go(st, "duct_t" if spot == "duct_l" else "duct_l", "switch")
			else:
				go(st, "vent_l" if spot == "duct_l" else "vent_t")
		_:
			go(st, "vent")

func _retreat(st) -> void:
	go(st, "vent", "retreat")
	move_t = _interval(st) * 1.4
