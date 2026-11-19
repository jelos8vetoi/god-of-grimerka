## Уборка подъезда: вид сверху на лестничную площадку. Пахан ведёт ТЯГУ-812 (WASD / стрелки): щётка
## всасывает мусор рядом, провода соседей цеплять нельзя — шланг запутается (стоп на 0,8 с и минус к оплате).
## 40 секунд. Стресс — руль дрожит. Оплата — доля убранного минус запутывания.
class_name MLJobPodezd
extends MLJob

const AREA := Rect2(170, 190, 1260, 570)
var pos := Vector2(220, 470)
var vel := Vector2.ZERO
var face := 0.0
var trash: Array = []           # [точка, цвет, размер, собран]
var cables: Array = []          # [[a, b]]
var tangles := 0
var stuck_t := 0.0
var got := 0
var wob := 0.0
var rng := RandomNumberGenerator.new()
var hit_cable := -1
var count_l: Label

func setup(f: Font, sf: SystemFont, stress: int, seed_v: int) -> void:
	base_setup(f, sf, stress, "УБОРКА ПОДЪЕЗДА", "WASD / стрелки — вести ТЯГУ-812. Мусор всасывается сам рядом со щёткой. Провода соседей не цеплять — шланг запутается.", 40.0)
	rng.seed = seed_v
	for k in 46:
		var p := Vector2(rng.randf_range(AREA.position.x + 30, AREA.end.x - 30), rng.randf_range(AREA.position.y + 30, AREA.end.y - 30))
		trash.append([p, [Color(0.6, 0.55, 0.4), Color(0.85, 0.85, 0.8), Color(0.3, 0.55, 0.3), Color(0.8, 0.3, 0.25)][k % 4], rng.randf_range(4, 9), false])
	# провода: от розеток через площадку
	for k in 6:
		var a := Vector2(rng.randf_range(AREA.position.x + 120, AREA.end.x - 120), AREA.position.y if k % 2 == 0 else AREA.end.y)
		var b := a + Vector2(rng.randf_range(-160, 160), rng.randf_range(160, 300) * (1.0 if k % 2 == 0 else -1.0))
		cables.append([a, b])
	count_l = txt(self, "", 26, WHITE, Vector2(1180, 34), serif)

func _process(dt: float) -> void:
	if done:
		return
	if not tick_time(dt):
		_end()
		return
	var inp := Vector2.ZERO
	if bot >= 0.0:
		inp = _bot_dir()
	else:
		inp = Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
		if Input.is_physical_key_pressed(KEY_A):
			inp.x -= 1
		if Input.is_physical_key_pressed(KEY_D):
			inp.x += 1
		if Input.is_physical_key_pressed(KEY_W):
			inp.y -= 1
		if Input.is_physical_key_pressed(KEY_S):
			inp.y += 1
	inp = inp.limit_length(1.0)
	wob += dt * 7.0
	inp = inp.rotated(sin(wob) * 0.35 * stress_k)
	if stuck_t > 0.0:
		stuck_t -= dt
		inp = Vector2.ZERO
	vel = vel.lerp(inp * 290.0, 1.0 - exp(-7.0 * dt))
	pos += vel * dt
	pos = pos.clamp(AREA.position + Vector2(20, 20), AREA.end - Vector2(20, 20))
	if vel.length() > 10.0:
		face = lerp_angle(face, vel.angle(), 1.0 - exp(-10.0 * dt))
	var nozzle := pos + Vector2.from_angle(face) * 26.0
	for t in trash:
		if not t[3] and (t[0] as Vector2).distance_to(nozzle) < 30.0:
			t[3] = true
			got += 1
	hit_cable = -1
	for k in cables.size():
		var c: Array = cables[k]
		if Geometry2D.get_closest_point_to_segment(pos, c[0], c[1]).distance_to(pos) < 16.0:
			hit_cable = k
			if stuck_t <= 0.0:
				tangles += 1
				stuck_t = 0.8
				pos -= vel.normalized() * 22.0
				vel = Vector2.ZERO
	count_l.text = "мусор %d/%d · запутался %d" % [got, trash.size(), tangles]
	if got >= trash.size():
		_end()
	queue_redraw()

## бот: едет к ближайшему мусору; чем хуже бот, тем чаще промахивается и цепляет провода
func _bot_dir() -> Vector2:
	var best := Vector2.ZERO
	var bd := INF
	for t in trash:
		if not t[3]:
			var d := (t[0] as Vector2).distance_to(pos)
			if d < bd:
				bd = d
				best = t[0]
	if bd == INF:
		return Vector2.ZERO
	var dir := (best - pos).normalized()
	# аккуратный бот объезжает провода
	for c in cables:
		var cp := Geometry2D.get_closest_point_to_segment(pos + dir * 30.0, c[0], c[1])
		if cp.distance_to(pos + dir * 30.0) < 26.0 and rng.randf() < bot:
			dir = dir.rotated(PI * 0.5)
	return dir * lerpf(0.45, 1.0, bot)

func _end() -> void:
	var share := float(got) / float(trash.size())
	finish(share * (1.0 - 0.08 * float(tangles)), [], "УБРАНО %d%%%s" % [int(share * 100.0), " · ПРОВОДА: %d" % tangles if tangles > 0 else ""])

func _draw() -> void:
	draw_rect(AREA, Color(0.24, 0.23, 0.21))
	for k in 12:
		draw_line(Vector2(AREA.position.x, AREA.position.y + k * 48.0), Vector2(AREA.end.x, AREA.position.y + k * 48.0), Color(0.2, 0.19, 0.17), 2.0)
	draw_rect(Rect2(AREA.end.x - 220, AREA.position.y, 220, AREA.size.y), Color(0.3, 0.29, 0.27))
	for k in 10:
		draw_line(Vector2(AREA.end.x - 220, AREA.position.y + k * 57.0), Vector2(AREA.end.x, AREA.position.y + k * 57.0), Color(0.16, 0.15, 0.14), 4.0)
	for t in trash:
		if not t[3]:
			draw_circle(t[0], float(t[2]), t[1])
	for k in cables.size():
		var c: Array = cables[k]
		draw_line(c[0], c[1], Color(1.0, 0.85, 0.2) if k == hit_cable else Color(0.08, 0.08, 0.09), 6.0)
		draw_circle(c[0], 8.0, Color(0.55, 0.55, 0.58))
	# пылесос: корпус, шланг, щётка
	var nozzle := pos + Vector2.from_angle(face) * 26.0
	var body := pos - Vector2.from_angle(face) * 34.0
	draw_line(body, nozzle, Color(0.1, 0.1, 0.12), 7.0)
	draw_circle(body, 22.0, Color(0.75, 0.15, 0.15))
	draw_circle(body, 22.0, Color(1, 1, 1), false, 2.0)
	draw_rect(Rect2(nozzle - Vector2(16, 6), Vector2(32, 12)), Color(0.85, 0.85, 0.88))
	draw_arc(nozzle, 30.0, 0, TAU, 24, Color(1, 1, 1, 0.15), 2.0)
	if stuck_t > 0.0:
		draw_string(font, pos + Vector2(-60, -40), "ЗАПУТАЛСЯ!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, RED)
