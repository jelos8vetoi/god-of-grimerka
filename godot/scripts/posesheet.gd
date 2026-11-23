## Проверка анимаций: рендерит персонажей в нужных кадрах и складывает в лист.
##   --posesheet=папка[,кто]                 — лист ключевых поз (pahan, pahan_run, pahan_combat, madk1d, clipper, hater)
##   --posesheet=папка,кто,Клип1,Клип2       — раскадровка клипов: 16 кадров подряд, видно дугу оружия и работу корпуса
## Каждый кадр снят с двух сторон: спереди-сбоку и в профиль. В консоль пишет пропорции модели (доли роста).
extends Node3D

var out := ""
var who := ""
var seq: Array = []
var cam: Camera3D
var pre_shot := Callable()   # (rig, клип, доля) перед каждым кадром — animcheck переключает чехол оружия

const COLS := 8
const CW := 250
const CH := 300
const SETS := {
	"pahan": ["res://assets/models/pahan.glb", 1.85, -1.0, ["Idle:0", "Run:0.25", "Block:0", "Charge:0", "Spin:0.5", "Rage:0.4", "Hit:0.3", "Death:1"]],
	"pahan_run": ["res://assets/models/pahan.glb", 1.85, -1.0, ["Idle:0", "Run:0", "Run:0.125", "Run:0.25", "Run:0.375", "Run:0.5", "Run:0.625", "Run:0.75", "Run:0.875"]],
	"clipper": ["res://assets/models/clipper.glb", 1.8, 1.0, ["Idle:0", "Run:0.25", "Slash:0.32", "Slash:0.52", "Slash:0.72", "Hit:0.3", "Spawn:0.5", "Fly:0.5"]],
	"drey": ["res://assets/models/drey.glb", 2.2, 1.0, ["Idle:0", "Run:0.25", "Punch:0.52", "Throw:0.55", "Stomp:0.62", "Summon:0.5", "Fly:0.5", "DeathA:1"]],
	"hater": ["res://assets/models/hater.glb", 1.75, 1.0, ["Idle:0", "Run:0.25", "Cast:0.4", "Cast:0.6", "Hit:0.3", "Fly:0.5", "DeathA:1", "DeathB:1"]],
	"madk1d": ["res://assets/models/madk1d.glb", 1.68, 1.0, ["Idle:0", "CombatIdle:0", "Walk:0.25", "Sprint:0.25", "Block:0", "Light:0.42", "Heavy:0.55", "Launcher:0.5"]],
	"pahan_combat": ["res://assets/models/pahan.glb", 1.85, -1.0, ["CombatIdle:0", "Walk:0.25", "Sprint:0.25", "Parry:0.2", "PerfectDodge:0.25", "AirAttack:0.6", "Landing:0.2", "Finisher:0.6"]],
}

func _ready() -> void:
	await _scene()
	for k in SETS:
		if who != "" and who != k:
			continue
		await _sheet(k)
	get_tree().quit()

## свет, земля и камера для снимков (общие с animcheck.gd)
func _scene() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.27, 0.33)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.65)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var l := DirectionalLight3D.new()
	l.rotation = Vector3(-0.8, 0.6, 0)
	add_child(l)
	# земля на y=0 — видно, стоит ли персонаж на ногах
	var gm := MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = Vector3(8, 0.02, 8)
	gm.mesh = gb
	gm.position.y = -0.01
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.45, 0.2, 0.2)
	gm.material_override = gmat
	add_child(gm)
	cam = Camera3D.new()
	cam.fov = 35
	add_child(cam)
	cam.make_current()
	await get_tree().process_frame

func _sheet(k: String) -> void:
	var cfg: Array = SETS[k]
	var r := Rig.new()
	add_child(r)
	var poses: Dictionary = Poses.pahan_armed() if k.begins_with("pahan") else (Poses.madk1d() if k == "madk1d" else (Poses.clipper() if k == "clipper" else (Poses.bot() if k == "drey" else Poses.hater())))
	var t0 := Time.get_ticks_msec()
	r.setup(cfg[0], cfg[1], poses, true, cfg[2])
	print("SHEET %s: анимации собраны за %d мс" % [k, Time.get_ticks_msec() - t0])
	if k.begins_with("pahan"):
		r.attach("res://assets/models/balon.glb", "r", {"axis": "y", "from": 98.0, "to": 0.0, "grip": 0.07, "length": 0.56})
	elif k == "clipper":
		r.attach("res://assets/models/katana.glb", "r", {"axis": "z", "from": -48.8, "to": 48.8, "grip": 0.15, "edge": true, "length": 0.62, "part": func(y): return y > 13.0})
		r.attach("res://assets/models/katana.glb", "r", {"bone": "hips", "axis": "z", "from": -37.0, "to": 47.0, "grip": 0.3, "dir": [0.2, -0.35, -0.9], "length": 0.5, "part": func(y): return y < 13.0, "off": [0.17, 0.02, 0.02]})
	elif k != "drey" and k != "madk1d":
		r.attach("res://assets/models/staff.glb", "r", {"axis": "y", "from": 0.0, "to": 97.5, "grip": 0.45, "length": 1.05})
	_proportions(k, r)
	if seq.is_empty():
		await _render(r, cfg[3], "sheet_" + k + ".png")
	else:
		for clip in seq:
			var shots := []
			for i in 16:
				shots.append("%s:%.4f" % [clip, i / 15.0])
			await _render(r, shots, "seq_%s_%s.png" % [k, clip])
	r.queue_free()
	await get_tree().process_frame

## где у модели суставы в позе привязки, в долях роста: x — влево, y — от пола, z — вперёд
func _proportions(k: String, r: Rig) -> void:
	var line := "PROPORTIONS %s:" % k
	for key in ["head", "neck", "rarm", "rfa", "rhand", "hips", "rup", "rleg", "rfoot"]:
		var b: int = r.bone[key]
		if b < 0:
			continue
		var p: Vector3 = r.skel_xf * (r._chain(r.rest_rot, b)[1] as Vector3)
		line += " %s(%.2f %.2f %.2f)" % [key, p.x / r.model_height, (p.y - r.foot_y) / r.model_height, p.z / r.model_height]
	print(line)

func _render(r: Rig, shots: Array, file: String) -> void:
	var rows := int(ceil(shots.size() / float(COLS)))
	var sheet := Image.create(CW * min(COLS, shots.size()), CH * 2 * rows, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		var parts: PackedStringArray = shots[i].split(":")
		var full := "g/" + parts[0]
		if not r.player.has_animation(full):
			continue
		if pre_shot.is_valid():
			pre_shot.call(r, parts[0], float(parts[1]))
		r.player.play(full, 0.0)
		r.player.seek(float(parts[1]) * r.player.get_animation(full).length, true)
		r.player.pause()
		for view in 2:
			var ang := 0.35 if view == 0 else 1.45
			cam.position = Vector3(sin(ang) * 5.0, 1.0, cos(ang) * 5.0)
			cam.look_at(Vector3(0, 0.95, 0))
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var sz := img.get_size()
			var cw := int(sz.y * float(CW) / CH)
			@warning_ignore("integer_division")
			var crop := img.get_region(Rect2i(sz.x / 2 - cw / 2, 0, cw, sz.y))
			crop.convert(Image.FORMAT_RGBA8)
			crop.resize(CW, CH)
			@warning_ignore("integer_division")
			sheet.blit_rect(crop, Rect2i(0, 0, CW, CH), Vector2i((i % COLS) * CW, (i / COLS) * 2 * CH + view * CH))
	sheet.save_png(out.path_join(file))
